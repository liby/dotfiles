-- Guesses go right after the first candidate, so a real pinyin sentence still commits with the
-- first key.

local min_length = 6
local max_guesses = 3
local dictionaries = { "en_dicts/en_ext.dict.yaml", "en_dicts/en.dict.yaml" }

-- One string per bucket, not a table per word: tens of thousands of live tables made every
-- keystroke several milliseconds slower.
local words

local function load_words()
  words = {}
  local seen = {}
  local root = rime_api.get_user_data_dir()
  for _, name in ipairs(dictionaries) do
    local file = io.open(root .. "/" .. name, "r")
    if file then
      local in_body = false
      for line in file:lines() do
        if in_body then
          local text, code = line:match("^([^\t#][^\t]*)\t([^\t]+)")
          if text then
            code = code:lower():gsub("[^a-z]", "")
            if #code >= 2 and not seen[code] then
              seen[code] = true
              local first = code:sub(1, 1)
              words[first] = words[first] or {}
              words[first][#code] = words[first][#code] or {}
              table.insert(words[first][#code], code .. "\t" .. text .. "\n")
            end
          end
        elseif line == "..." then
          in_body = true
        end
      end
      file:close()
    end
  end
  for _, by_length in pairs(words) do
    for length, lines in pairs(by_length) do
      by_length[length] = table.concat(lines)
    end
  end
end

local function distance(a, b, limit)
  local la, lb = #a, #b
  local rows = {}
  for i = 0, la do
    rows[i] = { [0] = i }
  end
  for j = 1, lb do
    rows[0][j] = j
  end
  for i = 1, la do
    local row_min = rows[i][0]
    for j = 1, lb do
      local cost = a:byte(i) == b:byte(j) and 0 or 1
      local d = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)
      if i > 1 and j > 1 and a:byte(i) == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
        d = math.min(d, rows[i - 2][j - 2] + 1)
      end
      rows[i][j] = d
      if d < row_min then
        row_min = d
      end
    end
    if row_min > limit then
      return nil
    end
  end
  local d = rows[la][lb]
  return d <= limit and d or nil
end

local function guesses_for(input)
  local code = input:lower()
  local limit = #code >= 9 and 2 or 1
  local by_length = words[code:sub(1, 1)]
  if not by_length then
    return {}
  end
  local found = {}
  for length = #code - limit, #code + limit do
    for wcode, text in (by_length[length] or ""):gmatch("([^\t]*)\t([^\n]*)\n") do
      local d = wcode ~= code and distance(code, wcode, limit)
      if d then
        table.insert(found, { text = text, distance = d, order = #found })
      end
    end
  end
  table.sort(found, function(x, y)
    if x.distance ~= y.distance then
      return x.distance < y.distance
    end
    return x.order < y.order
  end)
  local texts = {}
  for i = 1, math.min(max_guesses, #found) do
    local text = found[i].text
    if input:match("^%u") then
      text = text:sub(1, 1):upper() .. text:sub(2)
    end
    texts[i] = text
  end
  return texts
end

local filter = {}

function filter.init(env)
  if not words then
    load_words()
  end
end

local function yield_guesses(input, start, _end, guessed)
  for _, text in ipairs(guesses_for(input)) do
    guessed[text] = true
    yield(Candidate("english_guess", start, _end, text, ""))
  end
end

function filter.func(translation, env)
  local context = env.engine.context
  local input = context.input
  -- Once the first segment is confirmed, the translation covers only the rest of the input.
  local guessable = #input >= min_length and input:match("^%a+$") ~= nil
    and context.composition:back().start == 0
  local first_done, guessed = false, {}
  for cand in translation:iter() do
    if not first_done then
      first_done = true
      yield(cand)
      if guessable and (cand.type == "sentence" or cand._end < #input) then
        yield_guesses(input, 0, #input, guessed)
      end
    elseif not guessed[cand.text] then
      yield(cand)
    end
  end
  -- Input that no pinyin syllable can start, such as `vesrion`, translates to nothing.
  if not first_done and guessable then
    yield_guesses(input, 0, #input, guessed)
  end
end

return filter
