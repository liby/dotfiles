#!/usr/bin/env ruby

require "yaml"

REQUIRED_SECTIONS = [
  "Goal Structure",
  "Iterative Evaluator Goals",
  "Process",
  "Output Contract",
  "Failure Output",
  "Anti-Patterns"
].freeze

EXPECTED_FAILURE_OUTPUT = <<~'MARKDOWN'.strip.freeze
  If file writing or read-back verification fails, output exactly `file write failed: <reason>`, one blank line, then the goal body. Do not include a `/goal` command.
MARKDOWN

REQUIRED_PATTERNS = {
  "preamble" => [
    /A direct `\/set-goal` invocation always runs[^\n]*audit or edit/i,
    /Merely quoting or mentioning `set goal` does not invoke it/i,
    /write the file and follow the Output Contract before starting the requested work/i
  ],
  "Goal Structure" => [
    /Map every material user condition to Objective, Proof, Scope, or Out of scope.*Outcome, not steps/m,
    /Each item names the material completion claim, check, and expected observation.*fresh evidence to be surfaced after the final relevant mutation/m,
    /bounded set whose complete coverage changes acceptance/
  ],
  "Iterative Evaluator Goals" => [
    /live issue frontier, not the objective.*empty accepted frontier[^\n]*current evaluator evidence adding no new trigger path/m,
    /another pass requires a later mutation or new external evidence.*stop-and-report condition/m
  ],
  "Process" => [
    /Do not treat a literal `\$ARGUMENTS` token as input/,
    /deferred pre-Goal grounding path only when the user explicitly orders requirements gathering or research.*Do not infer it because the Goal itself is to research, investigate, discover, or gather requirements/m,
    /Do not mutate state or execute the Goal.*unavailable, stale, or conflicting material evidence as an unverified gap in Proof or Scope/m,
    /mutable sources[^\n]*rereads them after the final relevant mutation/,
    /one search-only `rg` or `fd` lookup.*Do not use preprocessors, exec actions, command substitution, or shell operators/m,
    /Resolve `\$\{SET_GOAL_OUTPUT_DIR:-\/tmp\}` and the resulting file path to absolute paths.*write exactly the drafted goal text with one trailing newline.*Read the file back and verify its content equals the drafted goal text/m
  ],
  "Output Contract" => [
    /emit either a callable goal tool invocation or a two-line paste handoff.*Call `get_goal` or the equivalent status tool first when available/m,
    /complete it with `update_goal`[^\n]*only when fresh evidence[^\n]*Proof of completion.*stop without invoking creation[^\n]*Never replace or overwrite an unrelated or unfinished goal/m,
    /Invoke creation once with the argument `Read <absolute-file-path> and use its contents as the goal\.`/,
    /creation reports an unfinished goal[^\n]*call status again when available.*without retrying creation only when refreshed status identifies the same prior goal as completed; otherwise report the conflict once[^\n]*and stop/m,
    /other creation or status failure[^\n]*stop without blind retries.*After a successful creation, continue executing the goal in the same thread/m,
    /entire assistant message is exactly two paragraphs separated by a blank line.*first paragraph is the literal string `Run next:`[^\n]*second is `\/goal Read <absolute-file-path> and use its contents as the goal\.`[^\n]*Nothing else appears/m
  ],
  "Anti-Patterns" => [
    /Putting `\/goal` or surrounding prose inside the goal file/
  ]
}.freeze

FORBIDDEN_PATTERNS = [
  /\brg\b[^\n]*--pre\b/i,
  /\bfd\b[^\n]*(?:--exec\b|(?:^|\s)-(?:x|X)(?:\s|$))/i,
  /(?:Run one more pass immediately even without either condition|unchanged frontier[^.\n]*permits? another pass)/i,
  /\b(?:cancel|replace|delete|close)\b[^.\n]*\b(?:active|unfinished|existing) goal\b[^.\n]*(?:before|then)\b/i,
  /unfinished[- ]goal conflict[^.\n]*(?:retry|invoke creation[^.\n]*(?:again|once more))/i,
  /complete\b[^.\n]*\b(?:active|existing|unfinished) goal\b[^.\n]*(?:to unblock|before (?:creating|invoking)|without[^.\n]*(?:proof|evidence))/i
].freeze

def parse_skill(text)
  match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
  return [nil, nil] unless match

  [YAML.safe_load(match[1], permitted_classes: [], aliases: false), match[2]]
rescue Psych::SyntaxError
  [nil, nil]
end

def section_pairs(body)
  body.scan(/^## ([^\n]+)\n\n(.*?)(?=^## |\z)/m).map do |name, content|
    [name, content.strip]
  end
end

def contract_errors(text)
  frontmatter, body = parse_skill(text)
  return ["missing or malformed frontmatter"] unless frontmatter.is_a?(Hash) && body

  errors = []
  description = frontmatter.fetch("description", "")
  errors << "description does not require explicit goal intent" unless description.include?("/set-goal") && description.match?(/set or start a goal|long-running goal mode/i)
  errors << "description misses nearby-task exclusions" unless description.include?("ordinary planning") && description.include?("continuing an active goal")
  errors << "model invocation must remain enabled" if frontmatter["disable-model-invocation"] == true
  errors << "slash invocation must remain enabled" if frontmatter["user-invocable"] == false
  errors << "model invocation must not be path-restricted" if frontmatter.key?("paths")
  errors << "goal creation must remain in the current thread" if frontmatter["context"] == "fork"

  pairs = section_pairs(body)
  section_names = pairs.map(&:first)
  REQUIRED_SECTIONS.each do |name|
    count = section_names.count(name)
    errors << "section #{name.inspect} appears #{count} times, expected once" unless count == 1
  end
  sections = pairs.to_h
  preamble = body.split(/^## /, 2).first.to_s.strip

  REQUIRED_PATTERNS.each do |section_name, patterns|
    section = section_name == "preamble" ? preamble : sections.fetch(section_name, "")
    patterns.each do |pattern|
      errors << "#{section_name}: missing #{pattern.inspect}" unless section.match?(pattern)
    end
  end

  errors << "Failure Output differs from its canonical block" unless sections.fetch("Failure Output", "") == EXPECTED_FAILURE_OUTPUT

  FORBIDDEN_PATTERNS.each do |pattern|
    errors << "forbidden contract text: #{pattern.inspect}" if text.match?(pattern)
  end

  errors
end

skill_path = ARGV.fetch(0, File.expand_path("../SKILL.md", __dir__))
text = skill_path == "-" ? $stdin.read : File.read(skill_path)
errors = contract_errors(text)

if errors.empty?
  puts "set-goal contract tripwire: OK"
else
  errors.each { |error| warn "ERROR: #{error}" }
  exit 1
end
