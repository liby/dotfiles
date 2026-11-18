local filter = {}

function filter.tags_match(seg, env)
  local input = env.engine.context.input
  return seg:has_tag("abc") and seg.start == 0 and seg._end == #input
    and input:match("^u[a-z][a-z]+$") ~= nil
end

function filter.func(translation, env)
  if not translation.exhausted then
    for cand in translation:iter() do
      yield(cand)
    end
    return
  end

  local context = env.engine.context
  local corrected = context.input:gsub("^u(.)", "%1u")
  env.pinyin = env.pinyin or Component.Translator(env.engine, "swapped_initial", "script_translator")
  local matches = env.pinyin:query(corrected, context.composition:back())
  if not matches then return end

  for cand in matches:iter() do
    if cand._end < #corrected then break end
    -- A full-length match can still contain abbreviated syllables. The spelling hint is the dictionary reading.
    if cand.type == "phrase" and cand.comment:gsub(" ", "") == corrected then
      cand.comment = ""
      yield(cand)
    end
  end
end

return filter
