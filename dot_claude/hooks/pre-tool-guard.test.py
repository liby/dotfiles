#!/usr/bin/python3 -I
"""Exercise the real PreToolUse entrypoint with inert commands and synthetic files."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HOOK = Path(__file__).with_name('executable_pre-tool-guard.py')
INSPECTION_ERROR = 'PreToolUse guard could not inspect this input; normal permission checks still apply.\n'


class GuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = tempfile.TemporaryDirectory()
        cls.addClassCleanup(fixture.cleanup)
        cls.test_root = Path(fixture.name)
        cls.test_home = cls.test_root / 'home'
        for relative in (
            '.ssh/config.d',
            '.ssh/directory.pub',
            '.ssh/keys',
            '.ssh/known_hosts.backup',
            'project',
        ):
            (cls.test_home / relative).mkdir(parents=True, exist_ok=True)
        for relative in (
            '.ssh/allowed_signers',
            '.ssh/config',
            '.ssh/config.d/nested.pub',
            '.ssh/config.d/private',
            '.ssh/config.work',
            '.ssh/directory.pub/private',
            '.ssh/id.pub',
            '.ssh/keys/nested.pub',
            '.ssh/known_hosts.backup/private',
            '.ssh/known_hosts.old',
            '.ssh/private',
            'project/file.txt',
        ):
            (cls.test_home / relative).touch()
        for relative, target in (
            ('.ssh/deceptive.pub', '.ssh/private'),
            ('project-link', 'project'),
            ('project/key-link', '.ssh/private'),
            ('project/public-link', '.ssh/id.pub'),
            ('project/ssh-link', '.ssh'),
        ):
            (cls.test_home / relative).symlink_to(cls.test_home / target)

    def assert_event(self, event, expected_rc, reason=''):
        result = subprocess.run(
            ['/usr/bin/python3', '-I', str(HOOK)],
            input=json.dumps(event), text=True, capture_output=True,
            cwd=self.test_home,
            env={'HOME': str(self.test_home), 'PATH': os.environ['PATH']},
            timeout=10,
        )
        self.assertEqual(result.returncode, expected_rc, result.stderr)
        if expected_rc == 1:
            self.assertEqual(result.stdout, '')
            self.assertEqual(result.stderr, INSPECTION_ERROR)
            return
        self.assertEqual(result.stderr, '')
        if expected_rc == 0:
            self.assertEqual(result.stdout, '')
            return
        output = json.loads(result.stdout)['hookSpecificOutput']
        self.assertEqual(output['hookEventName'], 'PreToolUse')
        self.assertEqual(output['permissionDecision'], 'deny')
        self.assertTrue(output['permissionDecisionReason'].startswith('DENIED: '))
        if reason:
            self.assertIn(reason, output['permissionDecisionReason'])

    def test_secret_commands(self):
        cases = [
            # Env dump commands
            (2, 'printenv'),
            (2, 'printenv HOME'),
            (2, 'env'),
            (2, 'env | grep HOME'),
            (2, 'declare -xp'),
            (2, 'export -p'),
            (2, 'export'),
            (2, 'export | wc -l'),
            (0, 'export FOO=bar'),
            (0, 'export FOO'),
            (0, 'printf "%s" "export"'),
            (2, 'set'),
            (2, 'set | grep FOO'),
            (0, 'set -e'),
            (2, 'set 2>/dev/null'),
            (2, 'typeset -x'),
            (0, 'declare -p GUARD_PROBE'),
            (0, 'declare -f'),
            (0, 'declare "$FLAGS"'),
            (0, './scripts/export'),
            (0, 'env set'),
            (0, 'command set'),
            (0, 'env FOO=bar some-command'),
            (2, 'env -0'),
            (2, 'env -i'),
            (2, 'env -'),
            (2, 'env NAME="$VALUE"'),
            (0, 'env NAME="$VALUE" some-command'),
            # .env files
            (2, 'cat .env'),
            (2, 'cat .env.local'),
            (2, 'cat .env.production'),
            (2, 'cat /path/to/.env'),
            (2, 'cat ./project/.env'),
            (2, 'tar czf backup.tgz .env'),
            (2, 'sed -n 1,5p .env'),
            (2, 'cat ".env"'),
            (2, 'cat .env; echo done'),
            (2, 'rg E2B_API_KEY .env.local'),
            (2, 'rg secret .env'),
            (2, 'rg -n foo /path/to/.env'),
            (2, 'rg API_KEY .env.production'),
            (2, 'rg -f .env README.md'),
            (2, 'grep --file=.env README.md'),
            (2, 'rg .env -e secret'),
            (2, 'rg -nf .env README.md'),
            (2, 'rg secret -- .env'),
            (2, 'rg secret -g .env src'),
            (2, 'rg secret -g=.env src'),
            (2, 'grep secret --include=.env src'),
            (0, 'rg -n "bucket|role" src -g "*.ts" | rg -v ".env"'),
            (0, 'rg .env README.md'),
            (0, 'grep -e .env README.md'),
            (0, 'rg secret src -g "!.env"'),
            (0, 'rg --files -g ".env*"'),
            (2, 'ag pattern .env'),
            (2, 'ack token .env.staging'),
            (0, 'cat .env.example'),
            (0, 'cat .env.sample'),
            (0, 'cat .env.template'),
            (0, 'cat .env.age'),
            (2, 'cat .env .env.example'),
            (2, 'cat .env.example .env'),
            (0, "grep -E 'process\\.env\\.\\w+' cli.js"),
            (0, 'grep "process.env.ANTHROPIC_API_KEY" cli.js'),
            (0, 'rg process.env cli.js'),
            (0, 'rg "process.env.E2B_API_KEY" cli.js'),
            (0, "grep -r 'CLAUDE_CODE_' node_modules/"),
            # Sensitive files
            (2, 'cat ~/.npmrc'),
            (2, 'cat /etc/ssl/private.key'),
            (2, 'cat key.pem'),
            (2, 'cat auth.json'),
            (2, 'cat ~/.zsh_history'),
            (2, 'cat ~/.zprofile'),
            (2, 'cat ~/.gnupg/private-keys-v1.d/foo.key'),
            (0, 'cat key.pem.pub'),
            (0, 'cat key.key.pub'),
            (2, 'cat private.key public.key.pub'),
            (2, 'cat public.key.pub private.key'),
            (0, "grep '.pem.config' file.js"),
            (0, "grep '.key.serialize()' cli.js"),
            (0, "grep 'auth.json.parse' cli.js"),
            # ~/.ssh: private material blocked, client config and public keys readable
            (2, 'cat ~/.ssh/deploy-key'),
            (2, 'head "$HOME/.ssh/server.pem"'),
            (2, 'cat ~/.ssh/config ~/.ssh/deploy-key'),
            (2, 'cat .ssh/id_ed25519'),
            (0, 'cat .ssh/id_ed25519.pub'),
            (0, 'cat .ssh/config'),
            (0, 'cat ~/.ssh/id_rsa.pub'),
            (0, 'cat ~/.ssh/config'),
            (0, 'cat ~/.ssh/config.work'),
            (0, 'cat ~/.ssh/allowed_signers'),
            (0, 'grep github ~/.ssh/known_hosts'),
            (0, 'echo $(cat ~/.ssh/id_rsa.pub)'),
            (0, 'ssh -i ~/.ssh/deploy-key example.test'),
            (2, 'cat ~/.ssh/config.backup/private'),
            (2, 'cat .ssh/known_hosts.backup/private'),
            (2, 'cat ~/.ssh/directory.pub/private'),
            (0, 'cat ~/.ssh/keys/nested.pub'),
            (0, 'cat ~/.ssh/config.backup/nested.pub'),
            # curl verbose
            (2, 'curl -v https://example.com'),
            (2, 'curl --verbose https://example.com'),
            (2, 'curl -sv https://example.test'),
            (2, 'curl --trace - https://example.test'),
            (2, 'curl --trace=- https://example.test'),
            (2, 'curl --trace-ascii - https://example.test'),
            (2, 'curl --trace-ascii=- https://example.test'),
            (0, 'curl https://example.com'),
            (0, 'curl -s https://example.test'),
            (0, 'curl --trace-time https://example.test'),
            # Credential-fetching commands
            (2, 'gh auth token'),
            (2, 'gh auth status --show-token'),
            (2, 'gh auth status -t'),
            (2, 'gh auth status --show-token=false'),
            (2, 'gh auth status -t --show-token=false'),
            (2, 'gh auth status -at'),
            (2, 'gh auth status -th example.test'),
            (0, 'gh auth status'),
            (0, 'gh auth status --hostname example.test'),
            (0, 'gh auth status --hostname -t'),
            (0, "gh auth status --template '-t' --json hosts"),
            (0, 'gh auth status -- -t'),
            (0, 'printf "%s" "gh auth status --show-token"'),
            (0, "printf '%s' '|' gh auth status -t"),
            (2, 'printf done | gh auth status -at'),
            (2, 'gh auth status -t # --help'),
            (2, 'gh auth status -t > --show-token=false'),
            (0, 'gh auth status > -t'),
            # Compound commands and static words
            (0, 'grep foo log; rm .env'),
            (2, 'cd foo && cat .env'),
            (0, 'grep .env file; echo ok'),
            (2, 'grep foo .env; echo ok'),
            (2, 'echo ok && cat ~/.ssh/id_rsa'),
            (2, 'test -e .env || cat .env'),
            (2, 'cd foo && env'),
            (2, 'echo hi; printenv'),
            (2, 'true; env'),
            (2, 'true && export'),
            (2, 'true; set'),
            (0, 'echo "foo;bar baz"'),
            (0, 'echo foo\\;bar'),
            (0, "echo 'foo;bar'"),
            (2, 'cat \\\n  .env'),
            (2, 'cat \\\n  auth.json'),
            (2, 'ca\\\nt .env'),
            (0, 'cat \\\n  .env.example'),
            (0, 'printf "%s" "hello\\\nworld"'),
            (0, 'printf "%s" "hello\nworld"'),
            (2, 'cat "\\\n.env"'),
            (2, "printf '%s' file\\ #1; env"),
            (2, "printf '%s' file\\)#1; env"),
            (2, 'printf "%s" file\\\n#1; env'),
            (2, "printf '%s' 'file '#1; env"),
            (2, 'printf "%s" "file "#1; env'),
            (0, "printf '%s' file #1; env"),
            (0, 'printf "%s" file \\\n#1; env'),
            (0, 'printf "%s" file; # comment; env'),
            (2, '# a comment ending in a backslash \\\nenv'),
            (0, '# a comment ending in a backslash \\\necho safe'),
            # Command substitution ($() and backticks)
            (2, 'echo $(cat .env)'),
            (2, 'echo $(rg secret .env)'),
            (2, 'rg "$(rg secret .env)" README.md'),
            (2, 'echo $(cat auth.json)'),
            (2, 'result=$(cat .env.production)'),
            (2, 'echo `cat .env`'),
            (2, 'echo `cat ~/.ssh/id_rsa`'),
            # Sensitive signatures also match heredoc data
            (2, 'cat <<EOF\ncat .env\nEOF'),
            (2, 'git commit -m "$(cat <<\'EOF\'\ndocs mention cat .env here\nEOF\n)"'),
            (0, 'cat <<EOF\nhello world\nEOF'),
            (2, 'cat .env <<EOF\nsome body\nEOF'),
            (2, "rg '<<TOKEN' src/\ncat .env\nTOKEN"),
            (2, 'echo "<<EOF is the marker"\ncat .env\nEOF'),
            (2, "cat <<EOF\ntext with an unmatched apostrophe: '\nEOF\nenv"),
            # echo/printf referencing secret variables
            (2, 'echo "$API_KEY"'),
            (2, 'echo "$GITHUB_TOKEN"'),
            (2, 'echo $MY_SECRET'),
            (2, 'printf "%s" "$DB_PASSWORD"'),
            (2, 'echo "${ANTHROPIC_API_KEY}"'),
            (2, 'echo "${value:-$API_KEY}"'),
            (0, 'echo "hello"'),
            (0, 'echo "$HOME"'),
            (0, 'printf "%s\\n" "$USER"'),
            (2, 'printf "%s" "\\$API_KEY"'),
            (0, "printf '%s' '$'API_KEY"),
            # Sensitive signatures do not depend on parsing native Zsh
            (2, 'repeat 2 do cat .env; done'),
            (2, 'repeat 2 cat .env'),
            (2, 'repeat 2 rg secret .env'),
            (2, '{ printf ready; } always { cat .env; }'),
            # Sensitive signatures also match literal examples and comments
            (2, "printf '%s' 'gh auth token'"),
            (2, "printf '%s' 'printenv'"),
            (2, 'python3 <<\'PY\'\nprint("cat .env")\nPY'),
            (2, 'python3 - <<\'PY\'\n# cat .env\nprint("done")\nPY'),
            (2, 'python3 -c \'print("done")\' \'cat .env\''),
            (2, "printf '%s' 'rg secret .env'"),
            (2, 'rg secret README.md # rg secret .env'),
            # Normal clients consume their own credential inputs
            (0, 'node --env-file=.env.local app.js'),
            (0, 'dotenvx run -f .env -- bun test'),
            (0, 'npm --userconfig ~/.npmrc install'),
            (2, 'GH_HOST=github.test /opt/homebrew/bin/gh auth status -t'),
            (0, "env -S 'client arguments'"),
        ]
        for expected, command in cases:
            with self.subTest(command=command):
                self.assert_event({'tool_input': {'command': command}}, expected)

    def test_command_policy(self):
        cases = [
            # find -> fd
            (2, 'find . -name "*.tmp"'),
            (2, 'echo x && find / -type f'),
            (0, 'fd -H voyageai site-packages'),
            (0, 'echo "find me a file"'),
            # dev/start/serve
            (2, 'npm run dev'),
            (2, 'pnpm dev'),
            (2, 'npm --prefix web run dev'),
            (2, 'pnpm --filter web dev'),
            (2, 'pnpm -w dev'),
            (2, 'pnpm --workspace-root dev'),
            (2, 'npm -w web run dev'),
            (2, 'yarn --cwd web start'),
            (2, 'bun run --silent serve'),
            (2, 'NODE_ENV=development npm run dev'),
            (2, 'env NODE_ENV=development npm run dev'),
            (2, 'command npm run dev'),
            (2, 'command -- npm run dev'),
            (2, 'env -i PATH="$PATH" npm run dev'),
            (2, 'env -u NODE_ENV npm run dev'),
            (2, 'env -u -- - - npm run dev'),
            (2, 'exec pnpm dev'),
            (2, 'cd web && npm run "dev"'),
            (2, 'npm \\\nrun dev'),
            (0, 'npm run build'),
            (0, 'command -v npm'),
            (0, 'command -V npm'),
            (0, 'env -u dev npm test'),
            (0, 'env NODE_ENV=test npm test'),
            (0, 'env -- - npm run dev'),
            (0, 'env GUARD_PROBE=x - npm run dev'),
            (0, "rg 'npm run dev' README.md"),
            (0, "printf '%s\\n' 'npm run dev'"),
            (0, 'git commit -m "document npm run dev"'),
            (0, 'npm --prefix dev run build'),
            (0, 'pnpm --filter dev test'),
            (0, 'pnpm -w build'),
            (0, 'npm -w dev run build'),
            (0, 'pnpm -C dev run build'),
            # Common execution prefixes
            (2, 'nohup npm run dev > /tmp/dev.log 2>&1 &'),
            (2, 'nohup -- pnpm dev'),
            (2, 'env NODE_ENV=development nohup pnpm dev'),
            (0, './scripts/exec npm run dev'),
            # comments and literal hash words
            (2, "echo done # don't edit\nnpm run dev"),
            (2, 'echo done # "unfinished quote\nyarn start'),
            (2, '# comment ending in a backslash \\\npnpm serve'),
            (0, "echo done # don't edit\nnpm run build"),
            (0, 'echo done; # npm run dev'),
            (0, "rg pattern . # 'a\\|b' --include=x -rn"),
            (2, "echo done # don't edit\nrg -rn pattern ."),
            (2, 'echo file\\ #literal; npm run dev'),
            (2, 'echo file\\)#literal; yarn start'),
            (2, 'echo ""#literal; pnpm serve'),
            (2, "echo ''#literal; npm run dev"),
            (2, 'echo "#literal"; npm run dev'),
            (2, 'echo \\#literal; npm run dev'),
            (2, 'echo file\\\n#literal; npm run dev'),
            (0, 'echo file \\\n# npm run dev'),
            (0, 'echo ""#literal; npm run build'),
            # rg clustered -r (--replace) misuse
            (2, 'rg -rn "full_resync" retl_asset.py'),
            (2, 'rg -Hrn pattern .'),
            (2, 'rg "quoted pattern" -rn file.py'),
            (2, 'cd /tmp && rg -rn foo'),
            (2, "rg -r '' -n pattern file.py"),
            (2, 'echo building\nrg -rn foo src/'),
            (2, 'rg \\\n-rn pattern .'),
            # rg legitimate usage
            (0, 'rg -n foo file.py'),
            (0, 'rg -A3 -B2 pattern src/'),
            (0, 'rg --replace n full_resync file.py'),
            (0, 'rg -e -rn file.py'),
            (0, 'rg -- -rn file.py'),
            (0, 'rg -g "*.ts" MIN_ORDER src/'),
            # rg token outside command position
            (0, 'grep -e rg -rn dot_claude/CLAUDE.md'),
            (0, 'grep -rn pattern dir/'),
            (0, 'rg foo src/ | sort -rn | head'),
            # quoted mentions and heredocs
            (0, "echo 'rg -rn is misparsed as replace'"),
            (0, 'git commit -m "fix hook\n\nmention rg -rn in body"'),
            (0, 'cat <<EOF\nrg -rn foo\nEOF'),
            (0, 'cat <<EOF\nplain body text\nEOF'),
            (0, 'cat <<EOF\nbody\nEOF\nrg -rn foo src/'),
            (0, 'rg -e "-rn" file.py'),
            (2, "rg '<<TOKEN' src/\nfind . -name x\nTOKEN"),
            (0, 'git commit -m "$(cat <<\'EOF\'\nfix hook\nrg -rn foo mentioned\nEOF\n)"'),
            # rg --include
            (2, 'rg --include="*.ts" MIN_ORDER src/'),
            (2, 'rg pattern src --include "*.py"'),
            # rg BRE alternation
            (2, "rg 'a\\|b' src/"),
            (2, 'rg "a\\|b" src/'),
            (2, 'rg "a\\\\|b" src/'),
            (2, "rg -e 'foo\\|bar' ."),
            (2, "rg -- '-a\\|b' ."),
            (0, 'rg a\\|b src/'),
            (0, "rg 'a|b' src/"),
            (0, "rg '\\\\|' file.txt"),
            (0, 'rg -F "a\\|b" src/'),
            (0, "rg 'a\\|b' -F ."),
            (0, "rg --fixed-strings 'a\\|b' src/"),
            (2, "rg -F 'a\\|b' . ; rg 'x\\|y' ."),
            (0, "grep 'a\\|b' file"),
            (0, "git commit -m 'fix rg a\\|b usage'"),
            (0, "rg 'foo' src | grep 'a\\|b'"),
            # Native token and argument boundaries
            (2, 'env "FOO=$BAR" npm run dev'),
            (2, 'env FOO="$BAR" npm run dev'),
            (0, 'env "${NAME}"=value npm run dev'),
            (0, 'git commit -m "fix; find bug"'),
            (2, '> output npm run dev'),
            (2, 'nohup >output 2>&1 npm run dev'),
            (2, "rg '-rn' x ."),
            (0, "printf '%s' '|' npm run dev"),
            (2, "printf '%s' '|' ; npm run dev"),
            (0, "printf '%s' '{' npm run dev"),
            # Complex shell execution stays outside precise policy checks
            (0, "sh -c 'npm run dev'"),
            (0, "eval 'rg -rn pattern README.md'"),
            (0, 'if true; then npm run dev; fi'),
            (0, 'echo $(find . -name x)'),
            (0, "bash <<'EOF'\nrg -rn pattern .\nEOF"),
            (2, 'cat <<EOF | rg -rn pattern README.md\nbody\nEOF'),
        ]
        for expected, command in cases:
            with self.subTest(command=command):
                self.assert_event({'tool_input': {'command': command}}, expected)

    def test_file_tools(self):
        cases = [
            # ~/.ssh: private material blocked, client config and public keys readable
            (2, '/Users/me/.ssh/deploy-key', 'Read'),
            (0, '/Users/me/.ssh/id_ed25519.pub', 'Read'),
            (0, '/Users/me/.ssh/config.work', 'Read'),
            (0, '/Users/me/.zshrc', 'Read'),
            (2, str(self.test_home / '.ssh/config.d/private'), 'Read'),
            (2, str(self.test_home / '.ssh/known_hosts.backup/private'), 'Read'),
            (0, str(self.test_home / '.ssh/config.work'), 'Read'),
            (0, str(self.test_home / '.ssh/keys/nested.pub'), 'Read'),
            (2, str(self.test_home / 'project/key-link'), 'Read'),
            (2, 'key-link', 'Read'),
            (2, 'ssh-link/private', 'Read'),
            (2, str(self.test_home / '.ssh/deceptive.pub'), 'Read'),
            (2, str(self.test_home / '.ssh/config.d'), 'Read'),
            (2, str(self.test_home / '.ssh/directory.pub'), 'Read'),
            (0, 'public-link', 'Read'),
            (0, 'file.txt', 'Read'),
            (2, 'key-link', 'Edit'),
            (0, 'public-link', 'Edit'),
            (0, '~/.ssh/new.pub', 'Write'),
            (0, '~/.ssh/config.new', 'Write'),
            (0, 'new-file.txt', 'Write'),
            (2, 'ssh-link/new-private', 'Write'),
        ]
        for expected, path, tool in cases:
            with self.subTest(path=path, tool=tool):
                self.assert_event({
                    'tool_name': tool, 'cwd': str(self.test_home / 'project'),
                    'tool_input': {'file_path': path},
                }, expected)

    def test_grep_scope(self):
        cases = [
            # Grep SSH scope uses cwd and canonical metadata
            (2, str(self.test_home / '.ssh/private'), str(self.test_home / 'project'), ''),
            (2, str(self.test_home / '.ssh'), str(self.test_home / 'project'), ''),
            (2, str(self.test_home), str(self.test_home / 'project'), '*.js'),
            (2, str(self.test_root), str(self.test_home / 'project'), '!**/.ssh/**'),
            (2, '/', str(self.test_home / 'project'), ''),
            (2, '.ssh', str(self.test_home), ''),
            (2, '../.ssh/private', str(self.test_home / 'project'), ''),
            (2, '', str(self.test_home), ''),
            (2, '', '', ''),
            (2, 'project/ssh-link', str(self.test_home), ''),
            (2, 'project/key-link', str(self.test_home), ''),
            (2, '.ssh/deceptive.pub', str(self.test_home), ''),
            (2, '.ssh/config.d', str(self.test_home), ''),
            (2, '.ssh/config.d/private', str(self.test_home), ''),
            (2, '.ssh/known_hosts.backup/private', str(self.test_home), ''),
            (2, '.ssh/known_hosts.backup', str(self.test_home), ''),
            (2, '.ssh/directory.pub', str(self.test_home), ''),
            (2, '.ssh/directory.pub/private', str(self.test_home), ''),
            (0, '~/.ssh/id.pub', str(self.test_home / 'project'), ''),
            (0, '.ssh/config', str(self.test_home), ''),
            (0, '.ssh/config.work', str(self.test_home), ''),
            (0, '.ssh/allowed_signers', str(self.test_home), ''),
            (0, '.ssh/known_hosts.old', str(self.test_home), ''),
            (0, '.ssh/keys/nested.pub', str(self.test_home), ''),
            (0, '.ssh/config.d/nested.pub', str(self.test_home), ''),
            (0, str(self.test_home / 'project'), str(self.test_home), ''),
            (0, 'file.txt', str(self.test_home / 'project'), ''),
            (0, '', str(self.test_home / 'project'), ''),
            (0, 'project-link', str(self.test_home), ''),
        ]
        if (self.test_home / '.SSH').is_dir():
            cases.append((2, '.SSH/private', str(self.test_home), ''))
        for expected, path, cwd, glob in cases:
            with self.subTest(path=path, cwd=cwd, glob=glob):
                event = {'tool_name': 'Grep', 'cwd': cwd, 'tool_input': {'pattern': 'synthetic'}}
                if path:
                    event['tool_input']['path'] = path
                if glob:
                    event['tool_input']['glob'] = glob
                self.assert_event(event, expected, 'Narrow the search')

    def test_lexer_error_does_not_echo_input(self):
        self.assert_event({'tool_input': {'command': "printf $'\\0'"}}, 1)


if __name__ == '__main__':
    unittest.main()
