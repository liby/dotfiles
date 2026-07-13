#!/usr/bin/env ruby
# Static validator for local agent skills. Default mode is offline.

require "open3"
require "optparse"
require "pathname"
require "rbconfig"
require "set"
require "shellwords"
require "timeout"
require "yaml"

options = { smoke: false }
OptionParser.new do |opts|
  opts.on("--smoke", "Run local CLI help and shell syntax checks") { options[:smoke] = true }
end.parse!

root = Pathname.new(__dir__).parent
# The script also runs from its deployed copy (~/.agents/skills/scripts), where
# root would be the deployed tree and third-party skills would wrongly get full
# content checks. Ask chezmoi to map root back to its source so both entry
# points behave identically; in the source tree (or without chezmoi) the lookup
# fails and root is already correct.
begin
  source_path, _stderr, status = Open3.capture3("chezmoi", "source-path", root.to_s)
  root = Pathname.new(source_path.strip) if status.success? && !source_path.strip.empty?
rescue Errno::ENOENT
end
repo = root.parent.parent
errors = []
warnings = []

CLAUDE_CODE_FIELDS = Set[
  "name",
  "description",
  "when_to_use",
  "argument-hint",
  "arguments",
  "disable-model-invocation",
  "user-invocable",
  "allowed-tools",
  "disallowed-tools",
  "model",
  "effort",
  "context",
  "agent",
  "hooks",
  "paths",
  "shell",
  "license",
  "metadata"
].freeze

# Keep this list to CLI skills whose instructions depend on current help output.
# The validator checks that the command is installed and that the documented help
# path still returns quickly; it does not prove every flag in the skill body.
CLI_SMOKE_COMMANDS = [
  ["gh skill install help", %w[gh skill install --help]],
  ["glab pipeline help", %w[glab ci list --help]],
  ["snow sql help", %w[snow sql --help]]
].freeze

skill_files = Dir.glob(root.join("*/SKILL.md").to_s).sort
encrypted_names = Dir.glob(root.join("*/encrypted_SKILL.md.asc").to_s).map { |path| File.basename(File.dirname(path)) }.to_set
source_names = skill_files.map { |path| File.basename(File.dirname(path)) }.to_set | encrypted_names
DEPLOYED_ROOT = File.expand_path("~/.agents/skills")

def rel(path, base)
  relative = Pathname.new(path).relative_path_from(base).to_s
  return relative unless relative.start_with?("..")
  path.to_s.sub(/\A#{Regexp.escape(Dir.home)}(?=\/)/, "~")
rescue ArgumentError
  path.to_s
end

def parse_skill(path)
  text = File.read(path)
  match = text.match(/\A---\n(.*?)\n---\n/m)
  return [nil, text] unless match
  [YAML.safe_load(match[1], permitted_classes: [], aliases: false) || {}, text]
end

def command_allowlist(frontmatter)
  raw_tools = frontmatter["allowed-tools"]
  tools = raw_tools.is_a?(String) ? raw_tools.split(/\s+/) : Array(raw_tools)
  return [:any, []] if tools.include?("Bash")

  bash_entries = tools.grep(/\ABash\(/)
  parsed = bash_entries.map { |tool| [tool, tool[/\ABash\(([^:*]+)(?::\*)?\)\z/, 1]] }
  unparseable = parsed.select { |_, cmd| cmd.nil? }.map(&:first)
  [parsed.map(&:last).compact.to_set, unparseable]
end

def line_command(line)
  return nil if line.match?(/\A\s/)
  line = line.strip
  return nil if line.empty? || line.start_with?("#")
  line = line.sub(/\A(?:&&|\|\||;)\s*/, "")
  return File.basename(Regexp.last_match(1)) if line =~ /\A[A-Za-z_][A-Za-z0-9_]*=\$\(([^)\s]+)/

  words = Shellwords.split(line) rescue line.split(/\s+/)
  words.shift while words.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)
  cmd = words.first
  return nil if cmd.nil? || cmd.start_with?("-")
  return nil if cmd.match?(/\A\/[A-Za-z_][A-Za-z0-9_-]*\z/)
  return nil if %w[if then else fi do done while for case esac in function local export return true false].include?(cmd)
  File.basename(cmd)
end

# Deployed pass over ~/.agents/skills (skipped silently when absent, e.g. CI).
# Encrypted sources (snow) are ciphertext in this repo, so the deployed
# plaintext is the only validatable copy; dirs without a SKILL.md (scripts/) are
# not skills. Deployed-only skills get provenance warnings, not content checks.
deployed_names = Set.new
pointer_scan = []
Dir.glob(File.join(DEPLOYED_ROOT, "*/SKILL.md")).sort.each do |path|
  dir_name = File.basename(File.dirname(path))
  deployed_names << dir_name
  if encrypted_names.include?(dir_name)
    skill_files << path
    next
  end
  next if source_names.include?(dir_name)

  frontmatter, = parse_skill(path)
  frontmatter = {} unless frontmatter.is_a?(Hash)
  metadata = frontmatter["metadata"].is_a?(Hash) ? frontmatter["metadata"] : {}
  if metadata.key?("github-repo") || metadata.key?("source") || frontmatter.key?("source")
    warnings << "~/.agents/skills/#{dir_name}: vendored, not backed up in git"
  else
    warnings << "~/.agents/skills/#{dir_name}: unmanaged, no provenance"
  end
  pointer_scan << ["~/.agents/skills/#{dir_name}/SKILL.md", frontmatter]
end

skill_files.each do |path|
  frontmatter, text = parse_skill(path)
  label = rel(path, repo)
  unless frontmatter
    errors << "#{label}: missing or malformed YAML frontmatter"
    next
  end
  pointer_scan << [label, frontmatter]

  name = frontmatter["name"].to_s.strip
  desc = frontmatter["description"].to_s.strip
  dir_name = File.basename(File.dirname(path))
  errors << "#{label}: missing name" if name.empty?
  errors << "#{label}: name #{name.inspect} does not match directory #{dir_name.inspect}" unless name.empty? || name == dir_name
  errors << "#{label}: name exceeds 64 chars" if name.length > 64
  warnings << "#{label}: name uses a reserved Claude term" if name.match?(/(?:claude|anthropic)/i)
  warnings << "#{label}: name contains XML angle brackets" if name.match?(/[<>]/)
  errors << "#{label}: missing description" if desc.empty?
  errors << "#{label}: description exceeds 1024 chars" if desc.length > 1024
  errors << "#{label}: description contains XML angle brackets" if desc.match?(/[<>]/)

  frontmatter.each_key do |field|
    warnings << "#{label}: unknown Claude Code frontmatter field #{field.inspect}" unless CLAUDE_CODE_FIELDS.include?(field)
  end
  errors << "#{label}: argument-hint must be a string" if frontmatter.key?("argument-hint") && !frontmatter["argument-hint"].is_a?(String)
  errors << "#{label}: context must be fork when set" if frontmatter.key?("context") && frontmatter["context"] != "fork"
  errors << "#{label}: shell must be bash or powershell when set" if frontmatter.key?("shell") && !%w[bash powershell].include?(frontmatter["shell"].to_s)
  %w[disable-model-invocation user-invocable].each do |field|
    errors << "#{label}: #{field} must be boolean" if frontmatter.key?(field) && ![true, false].include?(frontmatter[field])
  end

  text.scan(/\[[^\]]+\]\(([^)#][^)]+)\)/).flatten.each do |target|
    next if target.match?(/\A[a-z][a-z0-9+.-]*:/i) || target.start_with?("#")
    target = target.split(/\s+/, 2).first if target.start_with?("<")
    resolved = File.expand_path(target.delete_prefix("<").delete_suffix(">"), File.dirname(path))
    errors << "#{label}: missing linked file #{target}" unless File.exist?(resolved)
  end

  warnings << "#{label}: fixed /tmp JSON path example found; prefer mktemp or direct jq pipe" if text.match?(%r{/tmp/[A-Za-z0-9_.-]+\.json})

  allowlist, unparseable_entries = command_allowlist(frontmatter)
  unparseable_entries.each do |entry|
    warnings << "#{label}: unparseable allowed-tools entry #{entry.inspect}; it silently matches nothing"
  end
  next if allowlist == :any

  text.scan(/```(?:bash|sh)\n(.*?)```/m).flatten.each do |block|
    block.each_line do |line|
      cmd = line_command(line)
      next unless cmd && !allowlist.include?(cmd)
      warnings << "#{label}: bash block uses #{cmd.inspect} but allowed-tools does not list Bash(#{cmd}:*)"
    end
  end
end

# Catches retired-skill leftovers: each smoke label starts with the skill name.
known_names = source_names | deployed_names
CLI_SMOKE_COMMANDS.each do |smoke_label, _command|
  skill = smoke_label.split(/\s+/).first
  warnings << "CLI_SMOKE_COMMANDS: #{smoke_label.inspect} does not match any known skill" unless known_names.include?(skill)
end

# Prompt skills can own small contract tripwires where instruction structure is
# the behavior under test. Run them in normal validation so canonical output
# blocks and known bad variants cannot hide behind valid frontmatter.
Dir.glob(root.join("*/scripts/check-contract.rb").to_s).sort.each do |script|
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, script)
  next if status.success?

  detail = [stdout, stderr].join.lines.map(&:strip).reject(&:empty?).first(8).join(" | ")
  errors << "#{rel(script, repo)}: contract check failed#{detail.empty? ? "" : ": #{detail}"}"
end

# Routing pointers like "(use pm first)" rot silently when the target skill is
# renamed or retired. Deployed-only skills are legitimate targets, so without
# the deployed tree (CI) the known-name set is incomplete and any warning could
# be a false positive; only warn when the deployed tree exists.
if Dir.exist?(DEPLOYED_ROOT)
  pointer_scan.each do |scan_label, frontmatter|
    %w[description when_to_use].each do |field|
      frontmatter[field].to_s.scan(/\(use ([A-Za-z0-9_-]+)(?: first)?\)/).flatten.each do |target|
        warnings << "#{scan_label}: routing pointer to unknown skill #{target.inspect}" unless known_names.include?(target)
      end
    end
  end
end

if options[:smoke]
  Dir.glob(root.join("review/scripts/*.sh").to_s).sort.each do |script|
    errors << "#{rel(script, repo)}: bash -n failed" unless system("bash", "-n", script)
  end

  # _lib.sh has two consumers: the bash-shebang helper scripts source it, and
  # agents source it from their zsh Bash tool. Parse checks (-n) cannot catch
  # the zsh runtime-only failures (read-only $status, tied $path, missing
  # shopt), so exercise it in both shells.
  lib = root.join("review/scripts/_lib.sh")
  if lib.exist?
    smoke = "source #{lib.to_s.shellescape} && is_secret_like_path '.ENV.production' && ! is_secret_like_path 'src/app.ts'"
    %w[bash zsh].each do |shell|
      if system("which", shell, out: File::NULL, err: File::NULL)
        errors << "#{rel(lib.to_s, repo)}: #{shell} runtime smoke failed" unless system(shell, "-c", smoke, out: File::NULL, err: File::NULL)
      else
        warnings << "smoke: #{shell} not found, skipped _lib.sh runtime smoke"
      end
    end
  end

  CLI_SMOKE_COMMANDS.each do |label, command|
    unless system("which", command.first, out: File::NULL, err: File::NULL)
      warnings << "smoke: #{command.first} not found, skipped #{label}"
      next
    end
    begin
      _out, _err, status = Timeout.timeout(10) { Open3.capture3(*command) }
      warnings << "smoke: #{label} exited #{status.exitstatus}" unless status.success?
    rescue Timeout::Error
      errors << "smoke: #{label} timed out after 10s"
    end
  end
end

warnings.uniq.sort.each { |message| warn "WARN: #{message}" }
if errors.empty?
  puts "validate-skills: OK (#{skill_files.length} skill file(s))"
else
  errors.uniq.sort.each { |message| warn "ERROR: #{message}" }
  exit 1
end
