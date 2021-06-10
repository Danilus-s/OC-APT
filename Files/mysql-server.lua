local c = require("component")
local fs = require("filesystem")
local shell = require("shell")
local e = require("event")
local sha = require("sha2")
local text = require("text")
local perm = require("perm")
local sql = require("mysql-s")
local tty = require("tty")
local m = c.modem


tty.clear()
if ... == nil then print("Use mysql-server [password] <-p> [pathToDB]");return end
local args, opt = shell.parse(...)
if #args < 1 then print("Use mysql-server [password] <-p> [pathToDB]");return end
fs.makeDirectory("/usr/mysql-db")
local path  = "/usr/mysql-db"
if opt.p then path = args[2] end
local pass = sha.sha3_256(text.trim(args[1]))
local conn = {}

print("MySql server started!")
print("Address: " .. m.address .. "\nPort: 3306\nPath to database's: " .. path .. "\nPassword: " .. pass)

local function checkConn(adr)
    for i = 1, #conn do
        if conn[i] == adr then return true end
    end
    return false
end
local function closeConn(adr)
    local v = conn
    for i = 1, #conn do
        if conn[i] == adr then
            table.remove(conn, i)
            return true
        end
    end
    return false
end

m.open(3306)

while true do
    local reqR = table.pack(e.pull())
    if reqR[1] == "interrupted" then break end
    if reqR[1] == "modem_message" then
        local req = perm.split(reqR[6], " ")
        print("Message received\nFrom: " .. reqR[3] .. "\nMessage: " .. reqR[6])
        if req[1] == "CONNECT" then
            if req[2] == pass then 
                if not checkConn(reqR[3]) then 
                    conn[#conn+1] = reqR[3]
                    m.send(reqR[3], 3306, true)
                    print("User " .. reqR[3] .. " connected")
                else
                    m.send(reqR[3], 3306, true)
                    print("Connecting error for " .. reqR[3] .. " User already connected")
                end 
            else
                m.send(reqR[3], 3306, false)
                print("Connecting error for " .. reqR[3] .. " Invalid password")
            end
        elseif req[1] == "DISCONNECT" then
            if closeConn(reqR[3]) then 
                m.send(reqR[3], 3306, true)
                print("User " .. reqR[3] .. " disconnected")
            else 
                m.send(reqR[3], 3306, false)
                print("Disconnecting error for " .. reqR[3])
            end
        elseif req[1] == "CREATE" then
            if checkConn(reqR[3]) then
                local f = io.open(path .. req[2] .. ".db", "w")
                f:write("")
                f:close()
                m.send(reqR[3], 3306, true)
                print("Database " .. req[2] .. " successfully created")
            else
                m.send(reqR[3], 3306, false)
                print("Database " .. req[2] .. " creation error\nUser not connected")
            end
        elseif req[1] == "GET" then
            if checkConn(reqR[3]) then
                local n = sql.get(path .. req[2] .. ".db", req[2], req[3], req[4])
                if type(n) ~= "boolean" then
                    m.send(reqR[3], 3306, n)
                    print("Send request to " .. reqR[3] .. "\n" .. n)
                else
                    print("Request error\nNot found")
                end
            else
                m.send(reqR[3], 3306, false)
                print("Request error\nUser not connected")
            end
        end
    end
end
print("MySql server stopped")
m.close(3306)