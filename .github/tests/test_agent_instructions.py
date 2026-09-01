import re
import tomllib
import unittest
from collections import Counter
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).parents[2]
AGENTS = ROOT / "AGENTS.md"
CONCEPTS = ROOT / ".github" / "CONCEPTS.md"
INSTRUCTION_FILES = (
    AGENTS,
    CONCEPTS,
    ROOT / ".claude" / "rules" / "claude-code-settings.md",
)
CLAUDE_SETTINGS_TEMPLATE = ROOT / ".chezmoitemplates" / "claude" / "settings.json"
CLAUDE_OUTPUT_STYLE = ROOT / "dot_claude" / "output-styles" / "natural-technical-writing.md"

ROUTE_EXPECTATIONS = {
    "Repository validation": (
        "`.github/workflows/**`",
        "`.github/tests/**`",
        "(.github/CONCEPTS.md#repository-validation)",
    ),
    "Bootstrap and packages": (
        "`Brewfile`",
        "`.chezmoiexternal.toml`",
        "`.chezmoiscripts/**`",
        "(.github/CONCEPTS.md#bootstrap)",
        "(.github/CONCEPTS.md#package-and-tool-ownership)",
    ),
    "GitLab CLI": (
        "`.chezmoiscripts/run_onchange_after_05-configure-glab.sh`",
        "glab's live configuration",
        "(.github/CONCEPTS.md#gitlab-cli-configuration)",
    ),
    "Codex": (
        "`.chezmoitemplates/codex/**`",
        "`dot_codex/**`",
        "`~/.codex/config.toml`",
        "bundled Browser cache",
        "(.github/CONCEPTS.md#codex-configuration)",
    ),
    "Claude Code": (
        "`.chezmoitemplates/claude/**`",
        "`dot_claude/**`",
        "`~/.claude/settings.json`",
        "(.claude/rules/claude-code-settings.md)",
    ),
    "Pi": (
        "`.chezmoitemplates/pi/**`",
        "`private_dot_pi/**`",
        "`~/.pi/agent/**`",
        "(.github/CONCEPTS.md#pi-configuration)",
    ),
    "Managed skills": (
        "`dot_agents/skills/**`",
        "`~/.agents/skills/**`",
        "`write-skill`",
        "(.github/CONCEPTS.md#managed-skill-registry)",
    ),
    "Credentials": (
        "`.secrets/**`",
        "any source that invokes `envchain`",
        "(.github/CONCEPTS.md#identity-and-encrypted-data)",
        "(.github/CONCEPTS.md#credential-backed-features)",
        "(#encrypted-files)",
    ),
}

CREDENTIAL_KEYS = {
    "claude-gateway": {
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_VERTEX_BASE_URL",
        "ANTHROPIC_VERTEX_PROJECT_ID",
        "CLAUDE_CODE_SKIP_VERTEX_AUTH",
        "CLAUDE_CODE_USE_VERTEX",
    },
    "context7": {"CONTEXT7_API_KEY"},
    "pi": {"RC_GATEWAY_API_KEY"},
}

CREDENTIAL_CONSUMERS = {
    "claude-gateway": {
        "dot_zsh/functions/claude": (
            "gateway_namespace=claude-gateway",
            'envchain "$gateway_namespace" claude "$@"',
        ),
    },
    "context7": {
        ".chezmoitemplates/codex/config.toml": (
            'command = "/opt/homebrew/bin/envchain"',
            'args = ["context7", "npx", "-y", "@upstash/context7-mcp"]',
        ),
        "dot_claude/CLAUDE.md": ("envchain context7",),
    },
    "pi": {
        "private_dot_pi/private_agent/private_models.json.tmpl": (
            "!envchain pi sh -c",
            "RC_GATEWAY_API_KEY",
        ),
    },
}


def heading_anchors(markdown):
    anchors = set()
    counts = {}
    in_fence = False
    for line in markdown.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*$", line)
        if not match:
            continue
        text = re.sub(r"<[^>]+>", "", match.group(1)).lower()
        text = re.sub(r"[^\w\- ]", "", text)
        base = re.sub(r"\s+", "-", text.strip())
        count = counts.get(base, 0)
        counts[base] = count + 1
        anchors.add(base if count == 0 else f"{base}-{count}")
    return anchors


class MarkdownLinkTest(unittest.TestCase):
    def test_local_links_and_anchors_resolve(self):
        checked = 0
        for source in INSTRUCTION_FILES:
            markdown = source.read_text()
            for target in re.findall(r"(?<!!)\[[^]]+\]\(([^)]+)\)", markdown):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target):
                    continue
                path_text, separator, fragment = target.partition("#")
                target_path = source if not path_text else source.parent / unquote(path_text)
                target_path = target_path.resolve()
                self.assertTrue(
                    target_path.exists(),
                    f"{source.relative_to(ROOT)}: missing link target {target}",
                )
                if separator and fragment:
                    self.assertTrue(target_path.is_file(), target)
                    self.assertIn(
                        fragment,
                        heading_anchors(target_path.read_text()),
                        f"{source.relative_to(ROOT)}: missing anchor {target}",
                    )
                checked += 1
        self.assertGreater(checked, 0)


class MaintenanceRouteTest(unittest.TestCase):
    def test_safety_owners_have_pre_action_routes(self):
        markdown = AGENTS.read_text()
        self.assertIn(
            "Before inspecting, changing, or running a matching surface",
            markdown,
        )
        matches = re.findall(r"^- \*\*([^*]+)\*\*: (.+)$", markdown, re.MULTILINE)
        counts = Counter(label for label, _ in matches)
        routes = dict(matches)
        for label, snippets in ROUTE_EXPECTATIONS.items():
            with self.subTest(route=label):
                self.assertEqual(counts[label], 1)
                for snippet in snippets:
                    self.assertIn(snippet, routes[label])


class CredentialContractTest(unittest.TestCase):
    def test_documented_contract_matches_consumers(self):
        markdown = CONCEPTS.read_text()
        match = re.search(
            r"### Credential-backed features\n.*?```toml\n(.*?)\n```",
            markdown,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        contract = tomllib.loads(match.group(1))
        self.assertEqual(
            {namespace: set(values) for namespace, values in contract.items()},
            CREDENTIAL_KEYS,
        )

        section = markdown[match.start():]
        for namespace, consumers in CREDENTIAL_CONSUMERS.items():
            with self.subTest(namespace=namespace):
                self.assertIn(namespace, contract)
            for relative_path, tokens in consumers.items():
                path = ROOT / relative_path
                with self.subTest(namespace=namespace, consumer=relative_path):
                    self.assertTrue(path.is_file())
                    self.assertIn(f"({Path('../') / relative_path})", section)
                    content = path.read_text()
                    for token in tokens:
                        self.assertIn(token, content)


class ClaudeOutputStyleContractTest(unittest.TestCase):
    def test_managed_settings_select_output_style_with_coding_instructions(self):
        template = CLAUDE_SETTINGS_TEMPLATE.read_text()
        style = CLAUDE_OUTPUT_STYLE.read_text()
        self.assertTrue(style.startswith("---\n"))
        _, frontmatter, _ = style.split("---\n", 2)
        name = re.search(r"(?m)^name: (.+)$", frontmatter)
        self.assertIsNotNone(name)
        selected_styles = re.findall(r'"outputStyle": "([^"]+)"', template)
        self.assertEqual(selected_styles, [name.group(1)])
        self.assertRegex(frontmatter, r"(?m)^keep-coding-instructions: true$")


if __name__ == "__main__":
    unittest.main()
