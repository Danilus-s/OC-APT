local text = require("text")
local sql = require("mysql")
local sha = require("sha2")
local nw = require("network")

local conn = ""
local pass

while true do
    if conn ~= "" then
        io.write("\27[32m[" .. conn .. "] mysql>\27[m")
    else
        io.write("\27[32mmysql>\27[m")
    end
    local inp = io.read()
    if type(inp) ~= "string" then break end
    if inp == "exit" then break
    elseif inp == "connect" then
        io.write("Address>")
        local adr = nw.getAdr(io.read())
        if adr == nil then print("Wrong IP") return end
        io.write("Password>")
        pass = io.read()
        local re = sql.send(adr, "CONNECT " .. sha.sha3_256(pass))
        if re == true then
            conn = adr
            print("Connection successful")
        else
            print("Connection not successful")
        end
    elseif inp == "reconnect" then
        local re = sql.send(conn, "CONNECT " .. sha.sha3_256(pass))
        if re == true then
            print("Connection successful")
        else
            print("Connection not successful")
        end
    elseif inp == "close" then
        if conn ~= "" then sql.send(conn, "DISCONNECT"); conn = "" end
    else
        if conn ~= "" then 
            local re = sql.send(conn, inp) 
            print(tostring(re))
        else print("Connection not established")
        end
    end
end