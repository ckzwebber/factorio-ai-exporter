local M = {}

local function is_array(t)
  if type(t) ~= "table" then return false end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

local function escape_string(s)
  s = tostring(s)
  s = s:gsub('\\', '\\\\')
  s = s:gsub('"',  '\\"')
  s = s:gsub('\n', '\\n')
  s = s:gsub('\r', '\\r')
  s = s:gsub('\t', '\\t')
  s = s:gsub('%c', function(c)
    return string.format('\\u%04x', string.byte(c))
  end)
  return '"' .. s .. '"'
end

local function encode(val, depth)
  depth = depth or 0
  local t = type(val)

  if val == nil then
    return 'null'
  elseif t == 'boolean' then
    return val and 'true' or 'false'
  elseif t == 'number' then
    if val ~= val then return 'null' end  -- NaN
    if val == math.huge or val == -math.huge then return 'null' end
    if math.floor(val) == val and math.abs(val) < 1e15 then
      return string.format('%d', val)
    end
    return string.format('%.10g', val)
  elseif t == 'string' then
    return escape_string(val)
  elseif t == 'table' then
    if depth > 64 then return 'null' end
    local parts = {}
    if is_array(val) then
      for _, v in ipairs(val) do
        parts[#parts + 1] = encode(v, depth + 1)
      end
      return '[' .. table.concat(parts, ',') .. ']'
    else
      for k, v in pairs(val) do
        if type(k) == 'string' or type(k) == 'number' then
          parts[#parts + 1] = escape_string(tostring(k)) .. ':' .. encode(v, depth + 1)
        end
      end
      return '{' .. table.concat(parts, ',') .. '}'
    end
  end

  return 'null'
end

function M.encode(val)
  return encode(val)
end

return M
