#!/usr/bin/python3 -I
"""Best-effort PreToolUse checks; unknown input leaves normal permissions in control."""

from collections import deque
import getopt
import json
import os
from pathlib import Path
import re
import subprocess
import sys

MESSAGES = {
    'env': 'dumps environment variables including secrets.',
    'set': 'dumps shell variables including secrets.',
    'dotenv': 'reading .env file contents would expose secrets.',
    'sensitive': 'reading sensitive file contents.',
    'ssh': 'reading private material under ~/.ssh.',
    'curl': 'curl verbose or trace output can print HTTP headers including Authorization.',
    'gh-token': 'gh auth token prints GitHub credentials.',
    'gh-status': 'Token-display flags are not allowed in gh auth status. Omit --show-token and -t for ordinary status inspection.',
    'variable': 'printing secret variable values.',
    'find': 'Use fd instead of find. fd has simpler syntax and respects .gitignore by default.',
    'rg-replace': 'rg -r means --replace. Drop -r; use -n when you need line numbers. For intentional replacement, spell --replace VALUE.',
    'rg-include': "rg has no --include flag. Filter files with -g GLOB (e.g. -g '*.ts') or a type filter like -t ts.",
    'rg-bre': 'rg regex is not grep BRE: a\\|b matches literal a|b. Write alternation as a|b; to match a literal pipe intentionally, use [|] or -F.',
    'server': 'Do not run dev/start/serve commands, even when explicitly asked; do not retry. If a running app is needed, ask the user to run it in their own terminal (e.g. ! npm run dev). Otherwise use relevant finite checks such as tests, type checking, or linting.',
}
READ_CMDS = r'cat|head|tail|less|more|bat|grep|rg|ag|ack|sed|awk|base64|xxd|od|openssl|cp|tee|tar|source'
SENSITIVE_NAMES = r'(?:\.npmrc|\.zsh_history|\.zprofile|private-keys-v1\.d|\.pem|\.key|auth\.json|\.credentials\.json|\.aws/credentials)'
ENV_NAMES = r'\.env(?:\.(?:local|production|staging|development))?'
PATH_END = r'''($|[\s/"'>;|&)`])'''

def gh_status(args):
    # Requesting token display is blocked even if another flag cancels it.
    words = iter(args)
    for word in words:
        if word == '--':
            break
        if word in ('--hostname', '--jq', '--json', '--template', '-h'):
            next(words, None)
        elif word and ((word == '--show-token' or word.startswith('--show-token=')) or re.match(r'-[at]*t', word)):
            return True
    return False


def bulk_dump(program, args):
    if program == 'set':
        return 'set' if not args else None
    if program not in ('export', 'declare', 'typeset'):
        return None
    try:
        _, remaining = getopt.getopt(args, 'p' if program == 'export' else 'px')
    except getopt.GetoptError:
        return None
    if not remaining:
        return 'env' if program == 'export' else 'set'
    return None


def check_search_files(program, args):
    # Unknown options keep the signature check; getopt owns clusters and values.
    short = 'e:f:A:B:C:m:FGHhilLnqsvVwxo'
    long = ['regexp=', 'file=', 'after-context=', 'before-context=', 'context=', 'max-count=', 'fixed-strings', 'ignore-case', 'line-number', 'invert-match', 'help', 'version']
    if program == 'rg':
        short += 'g:t:T:E:'
        long += ['glob=', 'iglob=', 'type=', 'type-not=', 'encoding=', 'replace=', 'color=', 'sort=', 'sortr=', 'files']
    else:
        short += 'ErR'
        long += ['include=', 'exclude=', 'exclude-dir=']
    try:
        options, operands = getopt.gnu_getopt(args, short, long)
    except getopt.GetoptError:
        return False
    if any(value.startswith('=') for _, value in options):
        return False
    if any(option in ('--help', '--version', '-V') or program == 'rg' and option in ('-h', '--files') for option, _ in options):
        return True
    explicit_pattern = any(option in ('-e', '--regexp', '-f', '--file') for option, _ in options)
    files = operands if explicit_pattern else operands[1:]
    for option, value in options:
        if option in ('-f', '--file') or option in ('-g', '--glob', '--iglob', '--include') and not value.startswith('!'):
            files.append(value)
    for path in files:
        if re.search(r'(?:^|/)' + ENV_NAMES + r'(?:$|/)', path):
            deny('dotenv')
    return True


def search_signature_is_data(source):
    # Refine a broad signature only for static search pipelines. All other forms
    # retain the signature check, including comments and nested shell commands.
    if any(char in source for char in '#$`(){}<>'):
        return False
    try:
        tokens = shell_tokens(source)
    except (OSError, ValueError, subprocess.SubprocessError):
        return False
    words = []
    for raw, value in tokens + [('|', '|')]:
        if raw == '|':
            if not words or Path(words[0]).name not in ('rg', 'grep'):
                return False
            if not check_search_files(Path(words[0]).name, words[1:]):
                return False
            words = []
        elif raw in (';', '&', '&&', '||', '|&'):
            return False
        else:
            words.append(value)
    return True


def split_segments(source):
    # Keep readers separate from unrelated commands' path arguments. Physical
    # lines stay independent so heredoc quotes cannot hide later commands.
    chars = deque(source)
    quote = None
    word_start = True
    out = []
    while chars:
        char = chars.popleft()
        if char == '\\' and quote != "'":
            following = chars.popleft() if chars else ''
            if following and following != '\n':
                out.extend((char, following))
                word_start = False
            continue
        if char == '#' and quote is None and word_start:
            out.append(char)
            while chars and chars[0] != '\n':
                out.append(chars.popleft())
            continue
        separator = quote is None and (
            char == ';' or char in '&|' and chars and chars[0] == char
        )
        if char == '\n' or separator:
            if char in '&|':
                chars.popleft()
            if out:
                yield ''.join(out)
            out = []
            quote = None
            word_start = True
        else:
            if char in "'\"" and quote in (None, char):
                quote = None if quote == char else char
            word_start = quote is None and char in ' \t;&|()<>'
            out.append(char)
    if out:
        yield ''.join(out)


def check_sensitive(source):
    # Sensitive signatures also match literal examples and comments. Keep this
    # protection independent of the parser's incomplete native Zsh coverage.
    for segment in split_segments(source):
        if re.search(r'\b(printenv|declare\s+-xp|export\s+-p|typeset\s+-xp)\b', segment):
            deny('env')
        if re.search(r'(^|\|)\s*(env|export)\s*(\||>|$)', segment):
            deny('env')
        if re.search(r'(^|\|)\s*set\s*(\||>|$)', segment) and not re.search(r'(^|\|)\s*set\s+-', segment):
            deny('set')
        reader = r'\b(?:' + READ_CMDS + r')\b.*'
        if re.search(reader + r'''(^|[\s/="'])''' + ENV_NAMES + PATH_END, segment) and not search_signature_is_data(segment):
            deny('dotenv')
        if re.search(reader + SENSITIVE_NAMES + PATH_END, segment):
            deny('sensitive')
        if re.search(reader + r'\.ssh/', segment):
            for path in re.findall(r'\S*\.ssh/\S*', segment):
                if ssh_private_path(path.rstrip('"\')`;|&>')):
                    deny('ssh')
        if re.search(r'\bcurl\b.*\s(-[A-Za-z]*v[A-Za-z]*|--verbose|--trace(?:-ascii)?)([\s=]|$)', segment):
            deny('curl')
        if re.search(r'\bgh\s+auth\s+token\b', segment):
            deny('gh-token')
        if re.search(r'(echo|printf)\s.*\$\{?\w*(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL|API_KEY)\}?', segment, re.I):
            deny('variable')


def deny(rule):
    reason = 'DENIED: ' + MESSAGES.get(rule, rule) + ' Do NOT bypass this restriction or retry the same blocked command.'
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': reason}}))
    raise SystemExit(2)


def ssh_private_path(value):
    if not re.search(r'(?:^|/)\.ssh/', value):
        return False
    relative = value.rsplit('.ssh/', 1)[1]
    return not relative.endswith('.pub') and ('/' in relative or not re.fullmatch(r'config(?:\..*)?|allowed_signers|known_hosts.*', relative))


def check_file(event):
    is_grep = event.get('tool_name') == 'Grep'
    path = event['tool_input'].get('path' if is_grep else 'file_path')
    reason = 'Grep requires a verifiable search scope outside private ~/.ssh material. Narrow the search to a directory that neither contains nor lies within ~/.ssh, or an exact public key, client config, allowed_signers, or known_hosts file.' if is_grep else 'ssh'
    if path and not is_grep and ssh_private_path(path):
        deny('ssh')

    # samefile also detects aliases on case-insensitive macOS volumes.
    def same_path(first, second):
        if first == second:
            return True
        try:
            return first.samefile(second)
        except OSError:
            return False

    try:
        cwd = Path(os.path.expanduser(event.get('cwd') or os.getcwd())).resolve()
        target = Path(os.path.expanduser(path or str(cwd)))
        if not target.is_absolute():
            target = cwd / target
        ssh = Path.home() / '.ssh'
        for candidate in {Path(os.path.abspath(target)), target.resolve()}:
            for root in {Path(os.path.abspath(ssh)), ssh.resolve()}:
                if same_path(candidate, root) or (is_grep and any(same_path(candidate, parent) for parent in root.parents)):
                    deny(reason)
                for parent in candidate.parents:
                    if same_path(parent, root):
                        public_file = candidate.name.endswith('.pub') or (
                            parent == candidate.parent and (candidate.name in ('config', 'allowed_signers') or candidate.name.startswith(('config.', 'known_hosts')))
                        )
                        if not public_file or target.is_dir() or (is_grep and not target.is_file()):
                            deny(reason)
    except (OSError, RuntimeError, ValueError):
        deny(reason)


def check_command(words):
    while words and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', words[0][0]):
        words = words[1:]
    args = [value for _, value in words]
    if not args:
        return
    rule = bulk_dump(args[0], args[1:])
    if rule:
        deny(rule)
    # Only common execution prefixes are unwrapped; no builtin/child-shell lookup model.
    while args:
        program = Path(args[0]).name
        if args[0] in ('command', 'exec') or program == 'nohup':
            tail = args[1:]
            if tail[:1] == ['--']:
                tail = tail[1:]
            if not tail or tail[0].startswith('-'):
                return
            args = tail
        elif program == 'env':
            try:
                # BSD env accepts '-' while parsing options; preserve original operand values.
                _, remaining = getopt.getopt(['-i' if arg == '-' else arg for arg in args[1:]], '0ivu:P:C:')
            except getopt.GetoptError:
                return
            args = args[len(args) - len(remaining):]
            while args and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', args[0]):
                args = args[1:]
            if not args:
                deny('env')
        else:
            break
    program, tail = Path(args[0]).name, args[1:]
    if program == 'gh' and tail[:2] == ['auth', 'status'] and gh_status(tail[2:]):
        deny('gh-status')
    if program == 'find':
        deny('find')
    if program in ('rg', 'grep'):
        check_search_files(program, tail)
    if program == 'rg':
        fixed = bre = skip = False
        options = True
        for arg in tail:
            bre = bre or bool(re.search(r'(^|[^\\])\\\|', arg))
            if options and (arg == '--fixed-strings' or re.fullmatch(r'-[A-Za-z]+', arg) and 'F' in arg):
                fixed = True
            if skip:
                skip = False
            elif arg == '--':
                options = False
            elif options and arg == '-e':
                skip = True
            elif options and re.fullmatch(r'-[A-Za-z]+', arg) and 'r' in arg:
                deny('rg-replace')
            elif options and re.match(r'^--include(?:=|$)', arg):
                deny('rg-include')
        if bre and not fixed:
            deny('rg-bre')
    if program in ('npm', 'pnpm', 'yarn', 'bun'):
        arguments = iter(tail)
        run = False
        for arg in arguments:
            if arg in ('--prefix', '--dir', '--cwd', '--filter', '--workspace', '-C', '-F') or program == 'npm' and arg == '-w':
                next(arguments, None)
            elif arg.startswith('-'):
                continue
            elif arg == 'run' and not run:
                run = True
            else:
                if re.match(r'^(dev|start|serve)($|[^A-Za-z0-9_])', arg):
                    deny('server')
                break


def shell_tokens(source):
    # Native Zsh tokenization only: input never becomes executable shell source.
    lexer = r"""IFS= read -r -d '' command_text
for token in ${(Z:C:)command_text}; do
    [[ "$token" == *$'\0'* || "${(Q)token}" == *$'\0'* ]] && exit 1
    printf '%s\0%s\0' "$token" "${(Q)token}"
done
"""
    result = subprocess.run(['/bin/zsh', '-f', '-c', lexer], input=source, text=True, capture_output=True, timeout=2, check=True)
    tokens = result.stdout.split('\0')
    if tokens.pop() or len(tokens) % 2:
        raise ValueError
    return list(zip(tokens[::2], tokens[1::2]))


def check_commands(source):
    pairs = iter(shell_tokens(source))
    words = []
    heredoc = False
    for raw, value in pairs:
        if re.fullmatch(r'\d*<<-?', raw):
            next(pairs, None)
            heredoc = True
        elif re.fullmatch(r'(?:\d*(?:>|>>|<|<>|>&|<&|<<<|>\|)|&>|&>>)', raw):
            next(pairs, None)
        elif raw in ('(', '()', '((') or not words and raw in ('{', '[[', 'if', 'for', 'foreach', 'while', 'until', 'repeat', 'case', 'select', 'function', 'coproc'):
            check_command(words)
            return
        elif raw in (';', '&', '&&', '||', '|', '|&'):
            check_command(words)
            if heredoc and raw == ';':
                return
            words = []
        else:
            words.append((raw, value))
    check_command(words)


def main():
    try:
        event = json.load(sys.stdin)
        tool_input = event.get('tool_input', {})
        if event.get('tool_name') == 'Grep' or tool_input.get('file_path'):
            check_file(event)
        elif tool_input.get('command'):
            check_sensitive(tool_input['command'])
            check_commands(tool_input['command'])
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print('PreToolUse guard could not inspect this input; normal permission checks still apply.', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
