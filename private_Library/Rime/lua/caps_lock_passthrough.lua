-- rime-ice's speller alphabet includes capitals, so Caps Lock letters would start a composition.
-- librime passes them to the app (good_old_caps_lock) only while a Caps_Lock switch key is bound,
-- and that binding also toggles Rime's English mode on the press macOS uses to switch to ABC.
-- Committing through the engine records the letter in the commit history, which skips keys
-- carrying the Caps Lock modifier.

local kAccepted = 1
local kNoop = 2

local function processor(key, env)
  if key:release() or not key:caps() or key:ctrl() or key:alt() or key:super() then
    return kNoop
  end
  local code = key.keycode
  if code < 0x80 and string.char(code):find("%a") then
    env.engine:commit_text(string.char(code))
    return kAccepted
  end
  return kNoop
end

return processor
