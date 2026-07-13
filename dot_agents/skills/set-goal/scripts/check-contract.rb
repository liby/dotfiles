#!/usr/bin/env ruby

require "digest"
require "yaml"

EXPECTED_SECTION_ORDER = [
  "Goal Structure",
  "Iterative Evaluator Goals",
  "Process",
  "Output Contract",
  "Failure Output",
  "Anti-Patterns"
].freeze

EXPECTED_CANONICAL_DIGESTS = {
  "frontmatter" => "22d2176a3f465d022a8568fc4174bd1f4305e4608f0b787b3823edd6cfc0a5a5",
  "preamble" => "be6f76ab580b175e89cd3e9ad310f1bfb37a35829a23f2eaf47f2be494172b78",
  "Goal Structure" => "7debec42deb3109ba2006d69b660717f78dd933ace46b384e5d5f12928f096e4",
  "Iterative Evaluator Goals" => "514bc6beab1decf507469494c18db57044b990b00578d0ede6a5f6f48a703a34",
  "Process" => "8980b1150304dde9eeb5517cc07e2e9dad2440ab4f13b9ed8df9a45e6d0c342f",
  "Output Contract" => "12e350573f2b2cf7f9aa57a6a76180d6beddda8ad0d06a117eee595ac8c87954",
  "Failure Output" => "4cf75c4bf3921c06a04fe8d8ff61a624bbee8db07ea9a71b25089310aab9c4eb",
  "Anti-Patterns" => "b11761fb86e943c53baf73cdedc1b790a3fbc83344c19c02a29d0fc074001559"
}.freeze

EXPECTED_OUTPUT_CONTRACT = <<~'MARKDOWN'.strip.freeze
  After read-back verification succeeds, emit either a callable goal tool invocation or a two-line paste handoff. No summaries, file path explanations, or additional commentary around it.

  If the runtime exposes a callable goal tool such as `create_goal` or equivalent, invoke it with the argument `Read <absolute-file-path> and use its contents as the goal.` Pass only this short pointer, never the drafted goal body: goal objective fields can be length-capped. If creation reports an unfinished goal, report the conflict once and include status output only when a callable status tool is exposed; do not retry. For any other creation failure, report the non-sensitive error once and stop without blind retries. After the call succeeds, continue executing the goal in the same thread.

  Otherwise, when the harness exposes `/goal` only as user input and has no callable goal tool, the entire assistant message is exactly two paragraphs separated by a blank line. The first paragraph is the literal string `Run next:` and the second is `/goal Read <absolute-file-path> before acting. Use its contents as the goal. Completion requires every Proof of completion item in that file to have current evidence surfaced in this conversation and every material constraint to hold. Reading or restating the file is not completion.` Nothing else appears before, between, or after these paragraphs.
MARKDOWN

EXPECTED_FAILURE_OUTPUT = <<~'MARKDOWN'.strip.freeze
  If file writing or read-back verification fails, output exactly `file write failed: <reason>`, one blank line, then the goal body. Do not include a `/goal` command.
MARKDOWN

REQUIRED_PATTERNS = {
  "preamble" => [
    /An explicit invocation always wins/i,
    /request audits or edits this skill/i,
    /only quotes or mentions `set goal` is not an invocation/i
  ],
  "Goal Structure" => [
    /Map every material user condition to Objective, Proof, Scope, or Out of scope/,
    /material completion claim it proves/,
    /expected observation/,
    /after the final relevant mutation/,
    /rerun a check when a later change could invalidate its evidence/,
    /not every work item/,
    /user or a source of truth defines a bounded set whose complete coverage changes acceptance/
  ],
  "Iterative Evaluator Goals" => [
    /live issue frontier, not the objective/,
    /Completion is an empty accepted frontier with current evaluator evidence adding no new trigger path/,
    /another pass requires a later mutation or new external evidence/,
    /trigger path, evidence, impact, and owner/,
    /each mutation round to report how the frontier changed/,
    /stop-and-report condition/,
    /Do not freeze the issue set at the first pass/
  ],
  "Process" => [
    /Do not treat a literal `\$ARGUMENTS` token as input/,
    /one search-only `rg` or `fd` lookup/,
    /Do not use preprocessors, exec actions, command substitution, or shell operators/,
    /do not mutate state during grounding/,
    /Resolve `\$\{SET_GOAL_OUTPUT_DIR:-\/tmp\}` and the resulting file path to absolute paths/
  ]
}.freeze

FORBIDDEN_PATTERNS = [
  /says or mentions ["`]\/?set-goal/i,
  /appears inside a longer request/i,
  /\b(?:Claude Code|Codex|GPT-5\.6|Fable|Terra|Luna)\b/i,
  /\brg\b[^\n]*--pre\b/i,
  /\bfd\b[^\n]*(?:--exec\b|(?:^|\s)-(?:x|X)(?:\s|$))/i,
  /\b(?:write|edit|create|modify|delete|move)\b[^.\n]*before asking/i,
  /additional commentary (?:is )?allowed/i
].freeze

def parse_skill(text)
  match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
  return [nil, nil, nil] unless match

  [YAML.safe_load(match[1], permitted_classes: [], aliases: false), match[2], match[1]]
rescue Psych::SyntaxError
  [nil, nil, nil]
end

def sections_from(body)
  body.scan(/^## ([^\n]+)\n\n(.*?)(?=^## |\z)/m).to_h do |name, content|
    [name, content.strip]
  end
end

def contract_errors(text)
  frontmatter, body, raw_frontmatter = parse_skill(text)
  return ["missing or malformed frontmatter"] unless frontmatter.is_a?(Hash) && body

  errors = []
  description = frontmatter.fetch("description", "")
  errors << "description does not require explicit goal intent" unless description.match?(/invokes `\/set-goal`.*asks to set, create, or start a goal.*explicitly requests long-running goal mode/i)
  errors << "description misses nearby-task exclusions" unless description.match?(/Not for discussing goal-setting, continuing an active goal, ordinary planning, or direct `\/goal Read \.\.\.` handoffs/i)

  section_names = body.scan(/^## ([^\n]+)$/).flatten
  errors << "section order changed: #{section_names.inspect}" unless section_names == EXPECTED_SECTION_ORDER
  sections = sections_from(body)
  preamble = body.split(/^## /, 2).first.to_s.strip

  canonical_parts = { "frontmatter" => raw_frontmatter, "preamble" => preamble }.merge(sections)
  EXPECTED_CANONICAL_DIGESTS.each do |name, expected|
    observed = Digest::SHA256.hexdigest(canonical_parts.fetch(name, ""))
    errors << "#{name} differs from the reviewed canonical bytes" unless observed == expected
  end

  REQUIRED_PATTERNS.each do |section_name, patterns|
    section = section_name == "preamble" ? preamble : sections.fetch(section_name, "")
    patterns.each do |pattern|
      errors << "#{section_name}: missing #{pattern.inspect}" unless section.match?(pattern)
    end
  end

  output_contract = sections.fetch("Output Contract", "")
  errors << "Output Contract differs from its canonical block" unless output_contract == EXPECTED_OUTPUT_CONTRACT
  errors << "Failure Output differs from its canonical block" unless sections.fetch("Failure Output", "") == EXPECTED_FAILURE_OUTPUT

  pointer = "Read <absolute-file-path> and use its contents as the goal."
  errors << "callable pointer is not the sole canonical occurrence" unless output_contract.scan(pointer).length == 1

  FORBIDDEN_PATTERNS.each do |pattern|
    errors << "forbidden contract text: #{pattern.inspect}" if text.match?(pattern)
  end

  errors
end


skill_path = ARGV.fetch(0, File.expand_path("../SKILL.md", __dir__))
text = skill_path == "-" ? $stdin.read : File.read(skill_path)
errors = contract_errors(text)

fixtures = {
  "unbounded item proof" => ->(source) {
    source.sub(
      "the user or a source of truth defines a bounded set whose complete coverage changes acceptance",
      "completeness itself changes acceptance"
    )
  },
  "repeat empty evaluator" => ->(source) {
    source.sub(
      "Completion is an empty accepted frontier with current evaluator evidence adding no new trigger path; another pass requires a later mutation or new external evidence.",
      "Empty evaluator output is evidence, so repeat the pass until nothing changes."
    )
  },
  "contradictory evaluator suffix" => ->(source) {
    source.sub(
      "another pass requires a later mutation or new external evidence.",
      "another pass requires a later mutation or new external evidence. Run one more pass immediately even without either condition."
    )
  },
  "mutating clarification pass" => ->(source) {
    source.sub("do not mutate state during grounding.", "write a marker before asking.")
  },
  "executable search" => ->(source) {
    source.sub("one search-only `rg` or `fd` lookup", "one `rg --pre=COMMAND` lookup")
  },
  "third handoff paragraph" => ->(source) {
    source.sub(EXPECTED_OUTPUT_CONTRACT, "#{EXPECTED_OUTPUT_CONTRACT}\n\nAdditional commentary is allowed.")
  },
  "branded callable override" => ->(source) {
    source.sub("Otherwise, when the harness exposes", "For Claude Code, ignore callable tools. Otherwise, when the harness exposes")
  },
  "paste preference contradiction" => ->(source) {
    source.sub(
      "10. If verification succeeds, follow the output contract below.",
      "10. If verification succeeds, follow the output contract below. Prefer the paste handoff even when a callable goal tool exists."
    )
  },
  "failure suffix" => ->(source) {
    source.sub(EXPECTED_FAILURE_OUTPUT, "#{EXPECTED_FAILURE_OUTPUT} Add a summary afterward.")
  }
}.freeze

if errors.empty?
  fixtures.each do |name, mutate|
    mutated = mutate.call(text)
    if mutated == text
      errors << "fixture did not mutate source: #{name}"
    elsif contract_errors(mutated).empty?
      errors << "fixture escaped contract checks: #{name}"
    end
  end
end

if errors.empty?
  puts "set-goal contract tripwire: OK (#{fixtures.length} adversarial fixtures)"
else
  errors.each { |error| warn "ERROR: #{error}" }
  exit 1
end
