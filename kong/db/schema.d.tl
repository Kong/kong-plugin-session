local type TODO = any
local record type_definition_samesite
  type: string
  default: string
  one_of: {string}
end

local record Schema
  define: function(def: type_definition_samesite): TODO
end

return Schema
