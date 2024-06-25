-- MIT License
--
-- Copyright (c) 2018 LoganDark
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local function lookupify(src, list)
  list = list or {}

  if type(src) == 'string' then
    for i = 1, src:len() do
      list[src:sub(i, i)] = true
    end
  elseif type(src) == 'table' then
    for i = 1, #src do
      list[src[i]] = true
    end
  end

  return list
end

local base_ident = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
local base_digits = '0123456789'
local base_operators = '+-*/^%#'

local chars = {
  whitespace = lookupify(' \n\t\r'),
  validEscapes = lookupify('abfnrtv"\'\\'),
  ident = lookupify(
    base_ident .. base_digits,
    {
      start = lookupify(base_ident),
    }
  ),

  digits = lookupify(
    base_digits,
    {
      hex = lookupify(base_digits .. 'abcdefABCDEF')
    }
  ),

  symbols = lookupify(
    base_operators .. ',{}[]();.:', {
      equality = lookupify('~=><'),
      operators = lookupify(base_operators)
    }
  )
}

local keywords = {
  structure = lookupify({
    'and', 'break', 'do', 'else', 'elseif', 'end', 'for', 'function',
    'goto', 'if', 'in', 'local', 'not', 'or', 'repeat', 'return', 'then',
    'until', 'while', '<const>'
  }),

  values = lookupify({
    'true', 'false', 'nil'
  })
}

return function(text)
  local pos = 1
  local start = 1
  local tokens = {}

  local function look(delta)
    delta = pos + (delta or 0)

    return text:sub(delta, delta)
  end

  local function get()
    pos = pos + 1
    return look(-1)
  end

  local function getDataLevel()
    local num = 0

    while look(num) == '=' do
      num = num + 1
    end

    if look(num) == '[' then
      pos = pos + num + 1

      return num
    end
  end

  local function getCurrentTokenData()
    return text:sub(start, pos - 1)
  end

  local currentLineLength = 0
  local lineoffset = 0

  local function pushToken(type, data)
    data = data or getCurrentTokenData()

    local token = {
      type = type,
      data = data,
      posFirst = start - lineoffset,
      posLast = pos - 1 - lineoffset
    }

    if token.data ~= '' or token.type == "newline" then
      table.insert(tokens, token)
    end

    currentLineLength = currentLineLength + data:len()
    start = pos

    return token
  end

  local function newline(push)
    while look() == "\n" do
      get()
    end

    start = pos

    if push then
      pushToken('newline')
    end

    lineoffset = lineoffset + currentLineLength
    currentLineLength = 0
  end

  local function getData(level, type)
    while true do
      local char = get()

      if char == '' then
        return
      elseif char == '\n' then
        pos = pos - 1
        pushToken(type)
        newline()
      elseif char == ']' then
        local valid = true

        for _ = 1, level do
          if look() == '=' then
            pos = pos + 1
          else
            valid = false
            break
          end
        end

        if valid and look() == ']' then
          pos = pos - level - 1

          return
        end
      end
    end
  end

  local function chompWhitespace()
    while true do
      local char = look()

      if char == '\n' then
        newline(true)
      elseif chars.whitespace[char] then
        get()
      else
        break
      end
    end

    start = pos
  end

  local function chompComment()
    while true do
      local char = look()

      if char == "-" and look(1) == '-' then
        local is_block_comment = look(2) == "[" and look(3) == "["
        while true do
          local c = look()

          if (is_block_comment and c == "]" and look(-1) == "]") or (not is_block_comment and look(1) == '\n') then
            get()
            newline()
            break
          end

          get()
        end
      else
        break
      end
    end
  end

  while true do
    chompWhitespace()
    chompComment()

    local char = get()

    if char == '' then
      break
    elseif char == '\'' or char == '"' then
      pushToken('string_start')

      while true do
        local char2 = get()

        if char2 == '\\' then
          pos = pos - 1
          pushToken('string')
          get()

          local char3 = get()

          if chars.digits[char3] then
            for _ = 1, 2 do
              if chars.digits[look()] then
                pos = pos + 1
              end
            end
          elseif char3 == 'x' then
            if chars.digits.hex[look()] and chars.digits.hex[look(1)] then
              pos = pos + 2
            else
              pushToken('unidentified')
            end
          elseif char3 == '\n' then
            pos = pos - 1
            pushToken('escape')
            newline()
          elseif not chars.validEscapes[char3] then
            pushToken('unidentified')
          end

          pushToken('escape')
        elseif char2 == '\n' then
          pos = pos - 1
          pushToken('string')
          newline()
          break
        elseif char2 == char or char2 == '' then
          pos = pos - 1
          pushToken('string')
          get()

          break
        end
      end

      pushToken('string_end')
    elseif chars.ident.start[char] then
      while chars.ident[look()] do
        pos = pos + 1
      end

      local word = getCurrentTokenData()

      if keywords.structure[word] then
        pushToken('keyword')
      elseif keywords.values[word] then
        pushToken('value')
      else
        pushToken('ident')
      end
    elseif chars.digits[char] or (char == '.' and chars.digits[look()]) then
      if char == '0' and look() == 'x' then
        pos = pos + 1

        while chars.digits.hex[look()] do
          pos = pos + 1
        end
      else
        while chars.digits[look()] do
          pos = pos + 1
        end

        if look() == '.' then
          pos = pos + 1

          while chars.digits[look()] do
            pos = pos + 1
          end
        end

        if look():lower() == 'e' then
          pos = pos + 1

          if look() == '-' then
            pos = pos + 1
          end

          while chars.digits[look()] do
            pos = pos + 1
          end
        end
      end

      pushToken('number')
    elseif char == '[' then
      local level = getDataLevel()

      if level then
        pushToken('string_start')

        getData(level, 'string')
        pushToken('string')

        pos = pos + level + 2
        pushToken('string_end')
      else
        pushToken('symbol')
      end
    elseif char == '.' then
      if look() == '.' then
        pos = pos + 1

        if look() == '.' then
          pos = pos + 1
        end
      end

      if getCurrentTokenData():len() == 3 then
        pushToken('vararg')
      else
        pushToken('symbol')
      end
    elseif char == ':' and look() == ':' then
      get()

      pushToken('label_start')

      chompWhitespace()

      if chars.ident.start[look()] then
        get()

        while chars.ident[look()] do
          get()
        end

        pushToken('label')

        chompWhitespace()

        if look() == ':' and look(1) == ':' then
          get()
          get()

          pushToken('label_end')
        end
      end
    elseif chars.symbols.equality[char] then
      if look() == '=' then
        pos = pos + 1
      end

      pushToken('operator')
    elseif chars.symbols[char] then
      if chars.symbols.operators[char] then
        if look() == '=' or (char == '/' and look() == '/') then
          pos = pos + 1
        end

        pushToken('operator')
      else
        pushToken('symbol')
      end
    else
      pushToken('unidentified')
    end
  end

  return tokens
end
