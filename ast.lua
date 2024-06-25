local inspect = require("inspect")
----------------------------------------------------
-- HELPER
----------------------------------------------------
local helper = {}

function helper.is_parenthesis_open(token)
  return token.type == "symbol" and token.data:sub(1, 1) == "("
end

function helper.is_parenthesis_close(token)
  return token.type == "symbol" and token.data:sub(#token.data) == ")"
end

function helper.is_scope_end(token)
  return token.type == "keyword" and token.data == "end"
end

function helper.is_function_identifier(node, token)
  return token.type == "ident" and node.body.arguments == nil
end

function helper.is_function_argument(node, token)
  return node.body.arguments == nil and helper.is_parenthesis_open(token)
end

----------------------------------------------------
-- NODE
----------------------------------------------------

local Node = {
  type = "",
  body = {}
}

Node.__index = Node

function Node:new(type, body)
  local n = setmetatable({}, self)

  n.type = type or self.type
  n.body = body or self.body

  return n
end

local FunctionNode = Node:new("function", { identifier = "", arguments = nil, is_local = false })
local LocalNode = Node:new("local", { identifiers = {} })

----------------------------------------------------

function hargs(parent, get)
  parent.body.arguments = {}

  while true do
    local token = get()

    if token.type == "ident" then
      table.insert(parent.body.arguments, token.data)
    end

    if token.data == ")" then
      break
    end
  end
end

function hfunc(is_local, get, look)
  local node = FunctionNode:new()
  node.body.is_local = is_local

  while true do
    local token = get()

    if token.type == "ident" and node.body.arguments == nil then
      node.body.identifier = token.data
    end

    if token.type == "symbol" and token.data == "(" and node.body.arguments == nil then
      hargs(node, get)
    end

    if token.type == "symbol" and token.data == "()" and node.body.arguments == nil then
      node.body.arguments = {}
    end

    if token.type == "keyword" and token.data == "end" then
      break
    end
  end

  return node
end

function handle_scope()

end

----------------------------------------------------
-- PARSE
----------------------------------------------------

function Parse(tokens)
  local root = Node:new("root")

  local pos = 1
  local index = 1

  local function look(delta)
    delta = delta or 0
    return tokens[pos + delta]
  end

  local function get()
    pos = pos + 1
    return look(-1)
  end

  --   local function pushNode(node)
  --     table.insert(root.body, node)
  --     index = pos
  --   end


  local cases = {
    ["ident"] = function() end,
    ["keyword"] = {
      ["function"] = function(parent)
        local node = FunctionNode:new()
        node.body.is_local = look(-1) == "local"

        while true do
          local token = get()

          if helper.is_function_identifier(node, token) then
            node.body.identifier = token.data
          end

          if helper.is_function_argument(node, token) then
            node.body.arguments = {}
            while not helper.is_parenthesis_close(token) do
              token = get()

              if token.type == "ident" then
                table.insert(node.body.arguments, token.data)
              end
            end
          end

          if helper.is_scope_end(token) then
            break
          end
        end

        table.insert(parent.body, node)
      end,
      ["local"] = function()

      end
    }
  }



  while true do
    local token = get()
    local type, data = token.type, token.data


    if cases[type][data] then
      cases[type][data](root)
    end
    --     if type == "keyword" then
    --       if data == "function" then
    --         pushNode(hfunc(false, get, look))
    --       end

    --       if data == "local" then
    --         if look().data == "function" then
    --           pushNode(hfunc(true, get, look))
    --         else
    --         end
    --       end
    --     end


    pos = pos + 1
    if pos > #tokens then
      break
    end
  end

  return root
end

----------------------------------------------------

return Parse
