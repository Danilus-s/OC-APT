local perm = require("perm")
local fs = require("filesystem")

local mysqls = {}

function mysqls.get(db, idN, idV, from)
    if not fs.exists(db) then return false end
    local raw = {}
    for l in io.lines(db) do
        raw[#raw+1] = {}
        raw[#raw+1] = perm.split(l, ":")
    end
    for b = 1, #raw do
        if raw[b][tonumber(idN)] == idV then return raw[b][tonumber(from)] end
    end
    return false
end

function mysqls.set(db, idN, idV, name, new)
    if not fs.exists(db) then
        return false, "Not found DB"
    end
    local raw = {}
    for l in io.lines(db) do
        raw[#raw+1] = {}
        raw[#raw+1] = perm.split(l, ":")
    end
    local old = ""
    local ne = ""
    local need
    for b = 1, #raw do
        if raw[b][tonumber(idN)] == idV then need = b end
    end
    if need == nil then
        return false, "Not found need line"
    end
    for i = 1, #raw[need]-1 do
        if raw[need][i] == name then
            ne = ne ..  new .. ":"
        else
            ne = ne ..  raw[need][i] .. ":"
        end
    end
    if raw[need][#raw] == name then
        ne = ne ..  new
    else
        ne = ne ..  raw[need][#raw[need]]
    end
    local c = 1
    for l in io.lines(db) do
        if raw[c][tonumber(idN)] == idV then 
            old = old .. ne .. "\n"
        else
            old = old .. l .. "\n"
        end
        c = c+1
    end
    local file = io.open(db, "w")
    file:write(old)
    file:close()
    return true
end

return mysqls