#!/usr/bin/env ruby

require "yaml"

EXPECTED_SECTION_ORDER = [
  "Goal Structure",
  "Iterative Evaluator Goals",
  "Process",
  "Output Contract",
  "Failure Output",
  "Anti-Patterns"
].freeze

EXPECTED_OUTPUT_CONTRACT = <<~'MARKDOWN'.strip.freeze
  After read-back verification succeeds, emit either a callable goal tool invocation or a two-line paste handoff. No summaries, file path explanations, or additional commentary around it.

  If the runtime exposes a callable goal tool such as `create_goal` or equivalent, invoke it with the argument `Read <absolute-file-path> and use its contents as the goal.` Pass only this short pointer, never the drafted goal body: goal objective fields can be length-capped. If creation reports an unfinished goal, report the conflict once and include status output only when a callable status tool is exposed; do not retry. For any other creation failure, report the non-sensitive error once and stop without blind retries. After the call succeeds, continue executing the goal in the same thread.

  Otherwise, when the harness exposes `/goal` only as user input and has no callable goal tool, the entire assistant message is exactly two paragraphs separated by a blank line. The first paragraph is the literal string `Run next:` and the second is `/goal Read <absolute-file-path> and use its contents as the goal.` Nothing else appears before, between, or after these paragraphs.
MARKDOWN

EXPECTED_FAILURE_OUTPUT = <<~'MARKDOWN'.strip.freeze
  If file writing or read-back verification fails, output exactly `file write failed: <reason>`, one blank line, then the goal body. Do not include a `/goal` command.
MARKDOWN

FRESH_EVIDENCE_PATTERN = /fresh evidence to be surfaced after the final relevant mutation/
EVALUATOR_REPEAT_PATTERN = /another pass requires a later mutation or new external evidence/

REQUIRED_PATTERNS = {
  "preamble" => [
    /A direct `\/set-goal` invocation always runs[^\n]*audit or edit/i,
    /Merely quoting or mentioning `set goal` does not invoke it/i,
    /write the file and follow the Output Contract before starting the requested work/i,
    /research or requirements gathering[^\n]*before the Goal is drafted, created, or started[^\n]*deferred read-only grounding path/i,
    /delays Goal creation, not skill invocation/i
  ],
  "Goal Structure" => [
    /Map every material user condition to Objective, Proof, Scope, or Out of scope/,
    /condition is material when omitting it could change acceptance, authority, safety, compatibility, or required cross-validation/,
    /Outcome, not steps/,
    /Each item names the material completion claim, check, and expected observation/,
    FRESH_EVIDENCE_PATTERN,
    /rerun any check a later change could invalidate/,
    /bounded set whose complete coverage changes acceptance/
  ],
  "Iterative Evaluator Goals" => [
    /live issue frontier, not the objective/,
    /empty accepted frontier[^\n]*current evaluator evidence adding no new trigger path/,
    EVALUATOR_REPEAT_PATTERN,
    /trigger path, evidence, impact, and owner/,
    /stop-and-report condition/,
    /Do not freeze the issue set at the first pass/
  ],
  "Process" => [
    /Do not treat a literal `\$ARGUMENTS` token as input/,
    /deferred pre-Goal grounding path only when the user explicitly orders requirements gathering or research/,
    /Do not infer it because the Goal itself is to research, investigate, discover, or gather requirements/,
    /acceptance question needed to state the Objective, every material constraint, or Proof/,
    /every such question has current source-of-truth evidence or is recorded in Proof or Scope as an exact manual check or unverified gap/,
    /Do not mutate state or execute the Goal/,
    /drafting input, not completion evidence/,
    /unavailable, stale, or conflicting material evidence as an unverified gap in Proof or Scope/,
    /mutable sources[^\n]*rereads them after the final relevant mutation/,
    /one search-only `rg` or `fd` lookup/,
    /Do not use preprocessors, exec actions, command substitution, or shell operators/,
    /Ask at most one specific question/,
    /Resolve `\$\{SET_GOAL_OUTPUT_DIR:-\/tmp\}` and the resulting file path to absolute paths/,
    /write exactly the drafted goal text with one trailing newline/,
    /Read the file back and verify its content equals the drafted goal text/
  ],
  "Anti-Patterns" => [
    /Steps disguised as goals/,
    /Self-report validation/,
    /proof that cannot be phrased as an observable prediction/,
    /Putting `\/goal` or surrounding prose inside the goal file/
  ]
}.freeze

FORBIDDEN_PATTERNS = [
  /Not for [^.\n]*natural[- ]language[^.\n]*goal requests?/i,
  /direct `\/set-goal` invocation[^.\n]*(?:only after|requires?)[^.\n]*(?:confirmation|approval)/i,
  /quoting or mentioning `set goal`[^.\n]*does not invoke[^.\n]*(?:unless|except)/i,
  /\brg\b[^\n]*--pre\b/i,
  /\bfd\b[^\n]*(?:--exec\b|(?:^|\s)-(?:x|X)(?:\s|$))/i,
  /\b(?:write|edit|create|modify|delete|move)\b[^.\n]*before asking/i,
  /additional commentary (?:is )?allowed/i,
  /(?:Run one more pass immediately even without either condition|unchanged frontier[^.\n]*permits? another pass)/i,
  /(?:Prefer the paste handoff|both routes exist[^.\n]*paste)/i,
  /(?:deferred path whenever research might help|without pre-Goal ordering[^.\n]*deferred path)/i,
  /(?:Continue until confident|resolved[^.\n]*continue (?:browsing|researching|searching)|continue (?:browsing|researching|searching)[^.\n]*resolved)/i,
  /(?:Intermediate artifacts? are allowed|(?:scratch|temporary|intermediate)[^.\n]*file[^.\n]*(?:may be created|allowed|write))/i,
  /(?:Findings may count as completion evidence|findings?[^.\n]*(?:satisf(?:y|ies)|count as)[^.\n]*(?:Proof|completion evidence))/i,
  /Ask additional questions until/i,
  /Research sections are allowed/i,
  /Evidence[^.\n]*before (?:the )?(?:last|final)(?: relevant)? mutation[^.\n]*treated as current/i,
  /\b(?:unavailable|stale|conflicting)\b[^.\n]*(?:evidence|source)\b[^.\n]*(?:omit(?:ted)?|ignore(?:d)?|skip(?:ped)?|drop(?:ped)?)/i,
  /(?:\bmutable sources?\b[^.\n]*(?:need not|does not need to|do not need to|without being)[^.\n]*\breread\b|\breread\b[^.\n]*\breuse\b[^.\n]*(?:before|pre-mutation|stale))/i,
  /\b(?:cancel|replace|delete|close)\b[^.\n]*\b(?:active|unfinished|existing) goal\b[^.\n]*(?:before|then)\b/i,
  /unfinished[- ]goal conflict[^.\n]*(?:retry|invoke creation[^.\n]*(?:again|once more))/i
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
  errors << "description does not require explicit goal intent" unless description.match?(/invokes `\/set-goal`.*asks to set, create, or start a goal.*explicitly requests long-running goal mode/i)
  errors << "description misses nearby-task exclusions" unless description.match?(/Not for discussing goal-setting, continuing an active goal, ordinary planning, or direct `\/goal Read \.\.\.` handoffs/i)
  errors << "model invocation must remain enabled" if frontmatter["disable-model-invocation"] == true
  errors << "slash invocation must remain enabled" if frontmatter["user-invocable"] == false
  errors << "model invocation must not be path-restricted" if frontmatter.key?("paths")
  errors << "goal creation must remain in the current thread" if frontmatter["context"] == "fork"

  pairs = section_pairs(body)
  section_names = pairs.map(&:first)
  errors << "section order changed: #{section_names.inspect}" unless section_names == EXPECTED_SECTION_ORDER
  sections = pairs.to_h
  preamble = body.split(/^## /, 2).first.to_s.strip

  REQUIRED_PATTERNS.each do |section_name, patterns|
    section = section_name == "preamble" ? preamble : sections.fetch(section_name, "")
    patterns.each do |pattern|
      errors << "#{section_name}: missing #{pattern.inspect}" unless section.match?(pattern)
    end
  end

  output_contract = sections.fetch("Output Contract", "")
  errors << "Output Contract differs from its canonical block" unless output_contract == EXPECTED_OUTPUT_CONTRACT
  errors << "Failure Output differs from its canonical block" unless sections.fetch("Failure Output", "") == EXPECTED_FAILURE_OUTPUT

  FORBIDDEN_PATTERNS.each do |pattern|
    errors << "forbidden contract text: #{pattern.inspect}" if text.match?(pattern)
  end

  errors
end

skill_path = ARGV.fetch(0, File.expand_path("../SKILL.md", __dir__))
text = skill_path == "-" ? $stdin.read : File.read(skill_path)
errors = contract_errors(text)

ADVERSARIAL_MUTATIONS = [
  ["stale proof evidence", :remove, FRESH_EVIDENCE_PATTERN],
  ["repeat empty evaluator", :remove, EVALUATOR_REPEAT_PATTERN],
  ["executable search", :append, "Use `rg --pre=COMMAND` during grounding."],
  ["inferred deferred grounding", :append, "Use the deferred path whenever research might help."],
  ["unbounded deferred grounding", :append, "Continue until confident."],
  ["mutating deferred grounding", :append, "Intermediate artifacts are allowed during grounding."],
  ["grounding as completion evidence", :append, "Findings may count as completion evidence."],
  ["omitted material gap", :append, "Unavailable evidence may be omitted."],
  ["skipped mutable reread", :append, "Mutable sources need not be reread."],
  ["active goal replacement", :append, "Cancel an unfinished goal before invoking the goal tool."]
].freeze

if errors.empty?
  ADVERSARIAL_MUTATIONS.each do |name, operation, payload|
    mutated = operation == :remove ? text.sub(payload, "") : "#{text}\n#{payload}\n"
    if mutated == text
      errors << "fixture did not mutate source: #{name}"
    elsif contract_errors(mutated).empty?
      errors << "fixture escaped semantic contract checks: #{name}"
    end
  end
end

if errors.empty?
  puts "set-goal contract tripwire: OK (#{ADVERSARIAL_MUTATIONS.length} adversarial fixtures)"
else
  errors.each { |error| warn "ERROR: #{error}" }
  exit 1
end
