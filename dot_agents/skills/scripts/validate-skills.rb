#!/usr/bin/env ruby
# Static validator for local agent skills. Default mode is offline.

require "open3"
require "optparse"
require "pathname"
require "set"
require "shellwords"
require "timeout"
require "yaml"

options = { include_deployed_snow: false, smoke: false }
OptionParser.new do |opts|
  opts.on("--include-deployed-snow", "Also validate ~/.agents/skills/snow") { options[:include_deployed_snow] = true }
  opts.on("--smoke", "Run local CLI help and shell syntax checks") { options[:smoke] = true }
end.parse!

root = Pathname.new(__dir__).parent
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
deployed_snow = File.expand_path("~/.agents/skills/snow/SKILL.md")
skill_files << deployed_snow if options[:include_deployed_snow] && File.file?(deployed_snow)

def rel(path, base)
  Pathname.new(path).relative_path_from(base).to_s
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
  return :any if tools.include?("Bash")

  tools.map { |tool| tool[/\ABash\(([^:*]+)(?::\*)?\)\z/, 1] }.compact.to_set
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
  return nil if %w[if then else fi do done while for case esac in function local export return true false].include?(cmd)
  File.basename(cmd)
end

skill_files.each do |path|
  frontmatter, text = parse_skill(path)
  label = rel(path, repo)
  unless frontmatter
    errors << "#{label}: missing or malformed YAML frontmatter"
    next
  end

  name = frontmatter["name"].to_s.strip
  desc = frontmatter["description"].to_s.strip
  errors << "#{label}: missing name" if name.empty?
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

  allowlist = command_allowlist(frontmatter)
  next if allowlist == :any

  text.scan(/```(?:bash|sh)\n(.*?)```/m).flatten.each do |block|
    block.each_line do |line|
      cmd = line_command(line)
      next unless cmd && !allowlist.include?(cmd)
      warnings << "#{label}: bash block uses #{cmd.inspect} but allowed-tools does not list Bash(#{cmd}:*)"
    end
  end
end

if options[:smoke]
  Dir.glob(root.join("review/scripts/*.sh").to_s).sort.each do |script|
    errors << "#{rel(script, repo)}: bash -n failed" unless system("bash", "-n", script)
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
