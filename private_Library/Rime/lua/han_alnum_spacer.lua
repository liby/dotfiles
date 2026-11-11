-- Spaces across separate commits; rime-ice's cn_en_spacer spaces the inside of one candidate.
-- The commit history records candidates, text committed through the engine, and unmodified
-- printable keys passed through. It cannot see the host's text, so a caret moved without ending
-- the input session leaves a stale entry.

local kNoop = 2

local function char_class(code)
  if not code then
    return nil
  end
  if (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A)
      or (code >= 0x61 and code <= 0x7A) or (code >= 0x2160 and code <= 0x2188) then
    return "alnum"
  end
  if (code >= 0x3400 and code <= 0x4DBF) or (code >= 0x4E00 and code <= 0x9FFF)
      or (code >= 0xF900 and code <= 0xFAFF) or (code >= 0x20000 and code <= 0x3FFFF) then
    return "han"
  end
  return nil
end

local function needs_space(before, after)
  local a, b = char_class(before), char_class(after)
  return a ~= nil and b ~= nil and a ~= b
end

local function last_code(text)
  local last
  for _, code in utf8.codes(text) do
    last = code
  end
  return last
end

-- Keys that move the caret or act on the host's text end the run the history describes, with any
-- modifier: librime itself forgets the history only on a bare Return or BackSpace.
local caret_keys = {
  Left = true, Right = true, Up = true, Down = true, Home = true, End = true,
  Page_Up = true, Page_Down = true, Tab = true, Escape = true,
  Return = true, BackSpace = true,
}

local processor = {}

function processor.init(env)
  local context = env.engine.context
  local committed = false
  -- When the client ends the input session (focus moves to another field or app, or another input
  -- source is selected), Squirrel sends the raw input to the app itself and clears the composition,
  -- so only update_notifier fires and the history no longer describes the text before the caret.
  -- Escape or BackSpace emptying the input also clears without a commit; forgetting the history
  -- there costs at most one space.
  env.commit_connection = context.commit_notifier:connect(function()
    committed = true
  end)
  env.update_connection = context.update_notifier:connect(function(ctx)
    if ctx.input == "" and not committed then
      ctx.commit_history:clear()
    end
    committed = false
  end)
end

function processor.fini(env)
  env.commit_connection:disconnect()
  env.update_connection:disconnect()
end

function processor.func(key, env)
  if key:release() then
    return kNoop
  end
  local context = env.engine.context
  local history = context.commit_history
  local previous = last_code(history:latest_text())

  if context:is_composing() then
    -- Return commits the raw input instead of a candidate, so the filter never sees it.
    if key:repr() == "Return" and needs_space(previous, context.input:byte()) then
      env.engine:commit_text(" ")
    end
    return kNoop
  end

  if key:ctrl() or key:super() or caret_keys[key:repr():match("[^+]+$")] then
    history:clear()
    return kNoop
  end

  -- Digits, and letters typed with Caps Lock on, reach the app without a candidate for the filter
  -- to space.
  local code = key.keycode
  if (key:caps() or (code >= 0x30 and code <= 0x39)) and needs_space(previous, code) then
    env.engine:commit_text(" ")
  end
  return kNoop
end

local filter = {}

function filter.func(translation, env)
  local previous = last_code(env.engine.context.commit_history:latest_text())
  for cand in translation:iter() do
    if cand.start == 0 and needs_space(previous, utf8.codepoint(cand.text)) then
      yield(cand:to_shadow_candidate(cand.type, " " .. cand.text, cand.comment))
    else
      yield(cand)
    end
  end
end

return { processor = processor, filter = filter }
