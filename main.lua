local lexer = require("lexer")
local ast = require("ast")

function Minify(source)
  local tokens = lexer(source)
end

return Minify
