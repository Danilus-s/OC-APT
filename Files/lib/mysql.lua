local c = require("component")
local e = require("event")
local m = c.modem

local mysql = {}

function mysql.send(adr, req)
    m.open(3306)
    m.send(adr, 3306, req)
    local r = table.pack(e.pull(5, "modem_message"))
    m.close(3306)
    if #r > 2 then return r[6] end
    return false
end


return mysql