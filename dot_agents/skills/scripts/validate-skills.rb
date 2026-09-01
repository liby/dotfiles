#!/usr/bin/env ruby
# Static validator for local agent skills. Default mode is offline.

require "json"
require "open3"
require "optparse"
require "pathname"
require "set"
require "shellwords"
require "timeout"
require "yaml"

options = { smoke: false }
OptionParser.new do |opts|
  opts.on("--smoke", "Run local CLI contract and shell syntax checks") { options[:smoke] = true }
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
  "compatibility",
  "argument-hint",
  "arguments",
  "disable-model-invocation",
  "user-invocable",
  "allowed-tools",
  "disallowed-tools",
  "model",
  "effort",
  "context",
  "background",
  "agent",
  "hooks",
  "paths",
  "shell",
  "license",
  "metadata"
].freeze

# This is the reviewed local overlay contract, not a floating upstream default.
# A global-tool bump must update this record, the skill, and its provenance in
# one review before static validation can pass.
ORACLE_REVIEWED_CONTRACT = {
  version: "0.18.0",
  github_repo: "https://github.com/steipete/oracle",
  github_path: "skills/oracle",
  tree_sha: "26cca2ea90a18f55ea56bddd7e5fb318a67f466c",
  browser_model: "gpt-5.6-sol",
  browser_target: "GPT-5.6 Sol",
  browser_effort: "pro"
}.freeze

# Keep this list to CLI skills whose instructions depend on current CLI
# behavior, and give every entry an output regex naming the depended-on flags
# or route; an entry that only proves the command exits 0 asserts nothing.
CLI_SMOKE_COMMANDS = [
  ["gh skill install help", %w[gh skill install --help], /(?=.*--agent)(?=.*--allow-hidden-dirs)(?=.*--dir)(?=.*--from-local)(?=.*--scope)/m],
  ["gh skill update help", %w[gh skill update --help], /(?=.*gh skill update \[<skill>\.\.\.\])(?=.*--all)(?=.*--dir)(?=.*--dry-run)/m],
  ["gh pr merge head guard help", %w[gh pr merge --help], /--match-head-commit/],
  ["glab mr update safe input help", %w[glab mr update --help], /(?=.*--description-file)(?=.*--yes)/m],
  ["glab mr approve head guard help", %w[glab mr approve --help], /--sha/],
  ["glab mr merge head guard help", %w[glab mr merge --help], /(?=.*--sha)(?=.*--auto-merge=false)/m],
  [
    "oracle latest-model Pro browser dry run",
    [
      "oracle",
      "--engine", "browser",
      "--browser-attach-running",
      "--browser-model-strategy", "select",
      "--model", ORACLE_REVIEWED_CONTRACT.fetch(:browser_model),
      "--browser-thinking-time", ORACLE_REVIEWED_CONTRACT.fetch(:browser_effort),
      "--dry-run", "summary",
      "--files-report",
      "--prompt", "Validate the Oracle skill CLI contract.",
      "--file", root.join("oracle/SKILL.md").to_s
    ],
    Regexp.new(
      "\\[preview\\] Oracle \\(#{Regexp.escape(ORACLE_REVIEWED_CONTRACT.fetch(:version))}\\) " \
      "browser mode \\(target=#{Regexp.escape(ORACLE_REVIEWED_CONTRACT.fetch(:browser_target))}; " \
      "requested=#{Regexp.escape(ORACLE_REVIEWED_CONTRACT.fetch(:browser_model))}\\)"
    )
  ]
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

# Oracle's executable is upgraded from the global-tools manifest, while its
# locally overlaid skill must be reviewed rather than overwritten from upstream.
# Pin the release, upstream tree, documented root command, and dry-run route as
# one contract so a dependency-only bump or prose/runtime split cannot pass.
dev_tools_manifest = repo.join(".github/dev-tools/package.json")
oracle_skill = root.join("oracle/SKILL.md")
if dev_tools_manifest.exist? != oracle_skill.exist?
  missing_path = dev_tools_manifest.exist? ? oracle_skill : dev_tools_manifest
  errors << "#{rel(missing_path, repo)}: missing half of the reviewed Oracle CLI/skill contract"
elsif dev_tools_manifest.exist?
  begin
    manifest = JSON.parse(dev_tools_manifest.read)
    oracle_version = manifest.dig("devDependencies", "@steipete/oracle")
    if oracle_version == ORACLE_REVIEWED_CONTRACT.fetch(:version)
      oracle_frontmatter, oracle_text = parse_skill(oracle_skill)
      if oracle_frontmatter.is_a?(Hash)
        metadata = oracle_frontmatter["metadata"].is_a?(Hash) ? oracle_frontmatter["metadata"] : {}
        expected_metadata = {
          "github-repo" => ORACLE_REVIEWED_CONTRACT.fetch(:github_repo),
          "github-path" => ORACLE_REVIEWED_CONTRACT.fetch(:github_path),
          "github-ref" => "refs/tags/v#{ORACLE_REVIEWED_CONTRACT.fetch(:version)}",
          "github-tree-sha" => ORACLE_REVIEWED_CONTRACT.fetch(:tree_sha)
        }
        expected_metadata.each do |field, expected|
          actual = metadata[field]
          next if actual == expected

          errors << "#{rel(oracle_skill, repo)}: #{field} #{actual.inspect} does not match reviewed Oracle contract #{expected.inspect}"
        end
      end

      default_section = oracle_text[/^## Default:.*?(?=^## |\z)/m]
      root_commands = default_section.to_s.scan(/```bash\n(.*?)\n```/m).flatten
      if root_commands.length != 1
        errors << "#{rel(oracle_skill, repo)}: Default section must contain exactly one bash root command"
      else
        begin
          command_tokens = Shellwords.split(root_commands.first.gsub(/\\\n/, " "))
          errors << "#{rel(oracle_skill, repo)}: Oracle default command must invoke oracle" unless command_tokens.first == "oracle"

          expected_options = {
            "--engine" => "browser",
            "--browser-attach-running" => true,
            "--browser-model-strategy" => "select",
            "--model" => ORACLE_REVIEWED_CONTRACT.fetch(:browser_model),
            "--browser-thinking-time" => ORACLE_REVIEWED_CONTRACT.fetch(:browser_effort),
            "--slug" => "<3-5 words>",
            "-p" => "<task>",
            "--file" => "<path-or-glob>"
          }

          parsed_options = {}
          invalid_option_set = false
          index = 1
          while index < command_tokens.length
            option = command_tokens[index]
            expected = expected_options[option]
            if expected.nil? || parsed_options.key?(option)
              invalid_option_set = true
              break
            end

            if expected == true
              parsed_options[option] = true
              index += 1
            else
              parsed_options[option] = command_tokens[index + 1]
              index += 2
            end
          end

          if invalid_option_set || parsed_options != expected_options
            errors << "#{rel(oracle_skill, repo)}: Oracle default command options must exactly match the reviewed contract"
          end
        rescue ArgumentError => e
          errors << "#{rel(oracle_skill, repo)}: cannot parse Oracle default command (#{e.message})"
        end
      end
    else
      errors << "#{rel(dev_tools_manifest, repo)}: @steipete/oracle #{oracle_version.inspect} does not match reviewed contract #{ORACLE_REVIEWED_CONTRACT.fetch(:version).inspect}"
    end
  rescue JSON::ParserError => e
    errors << "#{rel(dev_tools_manifest, repo)}: malformed JSON (#{e.message})"
  end
end

# For an encrypted-only source skill, the deployed plaintext is the only
# validatable copy; absent (e.g. CI, no GPG) it is skipped silently. Other
# deployed entries are unmanaged (see .github/CONCEPTS.md) and get no checks.
encrypted_names.each do |dir_name|
  deployed = File.join(DEPLOYED_ROOT, dir_name, "SKILL.md")
  skill_files << deployed if File.exist?(deployed)
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
  dir_name = File.basename(File.dirname(path))
  errors << "#{label}: missing name" if name.empty?
  errors << "#{label}: name #{name.inspect} does not match directory #{dir_name.inspect}" unless name.empty? || name == dir_name
  errors << "#{label}: name exceeds 64 chars" if name.length > 64
  errors << "#{label}: missing description" if desc.empty?
  errors << "#{label}: description exceeds 1024 chars" if desc.length > 1024
  errors << "#{label}: description contains XML angle brackets" if desc.match?(/[<>]/)

  frontmatter.each_key do |field|
    warnings << "#{label}: unknown Claude Code frontmatter field #{field.inspect}" unless CLAUDE_CODE_FIELDS.include?(field)
  end
  errors << "#{label}: argument-hint must be a string" if frontmatter.key?("argument-hint") && !frontmatter["argument-hint"].is_a?(String)
  errors << "#{label}: compatibility must be a string of 1 to 500 chars" if frontmatter.key?("compatibility") && (!frontmatter["compatibility"].is_a?(String) || frontmatter["compatibility"].empty? || frontmatter["compatibility"].length > 500)
  errors << "#{label}: context must be fork when set" if frontmatter.key?("context") && frontmatter["context"] != "fork"
  errors << "#{label}: shell must be bash or powershell when set" if frontmatter.key?("shell") && !%w[bash powershell].include?(frontmatter["shell"].to_s)
  %w[disable-model-invocation user-invocable].each do |field|
    errors << "#{label}: #{field} must be boolean" if frontmatter.key?(field) && ![true, false].include?(frontmatter[field])
  end
  raw_tools = frontmatter["allowed-tools"]
  valid_allowed_tools = raw_tools.nil? || raw_tools.is_a?(String) || (raw_tools.is_a?(Array) && raw_tools.all? { |tool| tool.is_a?(String) })
  errors << "#{label}: allowed-tools must be a string or an array of strings" unless valid_allowed_tools

  text.scan(/\[[^\]]+\]\(([^)#][^)]+)\)/).flatten.each do |target|
    next if target.match?(/\A[a-z][a-z0-9+.-]*:/i) || target.start_with?("#")
    target = target.split(/\s+/, 2).first if target.start_with?("<")
    resolved = File.expand_path(target.delete_prefix("<").delete_suffix(">"), File.dirname(path))
    errors << "#{label}: missing linked file #{target}" unless File.exist?(resolved)
  end
end

# Catches retired-skill leftovers: each smoke label starts with the skill name.
CLI_SMOKE_COMMANDS.each do |smoke_label, _command, _expected_output|
  skill = smoke_label.split(/\s+/).first
  warnings << "CLI_SMOKE_COMMANDS: #{smoke_label.inspect} does not match any known skill" unless source_names.include?(skill)
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
    # exit codes: 0 allow, 4 raw secret, 5 ambiguous
    smoke_cases = {
      ".ENV.production" => 4,
      ".secrets/plain.toml" => 4,
      "identity.pem" => 5,
      ".secrets/seed.asc" => 0,
      "encrypted_private_dot_env.asc" => 0,
      ".env.age" => 0,
      "certificate.crt" => 0,
      ".ssh/config" => 0,
      ".ssh/id_ed25519.pub" => 0,
      "src/app.ts" => 0
    }
    %w[bash zsh].each do |shell|
      unless system("which", shell, out: File::NULL, err: File::NULL)
        warnings << "smoke: #{shell} not found, skipped _lib.sh runtime smoke"
        next
      end
      smoke_cases.each do |entry, expected|
        cmd = "source #{lib.to_s.shellescape} && " \
              "printf '%s\\0' #{entry.shellescape} | validate_path_file_nul /dev/stdin"
        _out, _err, status = Open3.capture3(shell, "-c", cmd)
        next if status.exitstatus == expected
        errors << "#{rel(lib.to_s, repo)}: #{shell} smoke #{entry.inspect} exited #{status.exitstatus}, expected #{expected}"
      end
    end
  end

  CLI_SMOKE_COMMANDS.each do |label, command, expected_output|
    unless system("which", command.first, out: File::NULL, err: File::NULL)
      errors << "smoke: #{command.first} not found, skipped #{label}"
      next
    end
    begin
      out, _err, status = Timeout.timeout(10) { Open3.capture3(*command) }
      if !status.success?
        errors << "smoke: #{label} exited #{status.exitstatus}"
      elsif !out.match?(expected_output)
        errors << "smoke: #{label} did not report the reviewed route"
      end
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
