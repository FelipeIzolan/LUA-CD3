local node = { type = '', body = {} }
node.__index = node

function node:new(type, body)
  local n = setmetatable({}, self)

  n.type = type or self.type
  n.body = body or self.body

  return n
end

function Parse(tokens)
  local root = node:new('root')
  local parent = nil
  local index = 0

  return root
end

return Parse
