local c = require("component")
local s = require("shell")
local e = require("event")
local p = require("perm")
local t = require("tty")
local nw = require("network")
local cp = require("computer")
local sha = require("sha2")
local m = c.modem
local gpu = c.gpu

if not c.isAvailable("modem") then print("`modem' not available"); return end

local args, opt = s.parse(...)
if args[1] == "maketoken" then
  local f = io.open((os.getenv("HOME") or "") .. "/token", "w")
  f:write(m.address)
  f:close()
  return
end
if #args < 3 then print("Useage: chat connect [IP] [password] [name?]\nor chat host [roomName] [password]\nor chat token [token] [password]\nor chat maketoken"); return end



local w,h = gpu.getResolution()
local pass =  sha.sha3_256(args[3])
local conn = {}
local adr, name
local host = false
if args[1] == "host" then
  name = args[2]
  host = true
elseif args[1] == "connect" then
  adr = nw.getAdr(args[2])
  if adr == nil then print("Wrong IP") return end
elseif args[1] == "token" then
  local f = io.open(require("shell").resolve(args[2]))
  adr = f:read()
  f:close()
else
  print("Useage: chat connect [IP] [password] [name?]\nor chat host [roomName] [password]\nor chat token [token] [password]\nor chat maketoken")
  return
end

m.open(89)

t.clear()
local function del(tab, txt)
    for i = 1, #tab do
        if tab[i].adr == txt then table.remove(tab, i);return true end
    end
    return false
end
local function check(tab, txt)
    for i = 1, #tab do
        if tab[i].adr == txt then return true end
    end
    return false
end
local function send(txt)
    for i = 1, #conn do
        m.send(conn[i].adr, 89, txt)
    end
end
local function getName(adr)
    for i = 1, #conn do
        if conn[i].adr == adr then return conn[i].name end
    end
    return false
end
local function getAdr(name)
    for i = 1, #conn do
        if conn[i].name == name then return conn[i].adr end
    end
    return false
end
local function rename(name, new)
    for i = 1, #conn do
        if conn[i].name == name then conn[i].name = new;return true end
    end
    return false
end
local function addLine(txt)
    local ent = math.ceil(string.len(txt)/w)
    local to = {}
    to[#to+1] = string.sub(txt, 1, w)
    for i = 1, ent do
        to[#to+1] = string.sub(txt, w*i+1, w*i*2)
    end
    gpu.copy(1, 1, w, h-1, 0, 0)
    gpu.fill(1, h/ent, w, ent, " ")
    for i = 1, #to do
        gpu.set(1, h-ent+i-1, to[i])
    end
end
local function addLine2(txt)
    local ent = math.ceil(string.len(txt)/w)
    local to = {}
    to[#to+1] = string.sub(txt, 1, w)
    for i = 1, ent do
        to[#to+1] = string.sub(txt, w*i+1, w*i*2)
    end
    gpu.copy(1, ent, w, h-1, 0, ent*-1)
    gpu.fill(1, h-ent, w, ent, " ")
    for i = 1, #to do
        gpu.set(1, h-ent+i-1, to[i])
    end
  end
local function res(...)
    local arg = {...}
    if host then
        local b = p.split(arg[6], " ")
        if b[1] == "connect" then
            if b[2] == pass then
                m.send(arg[3], 89, true, name)
                if not check(conn, arg[3]) then
                    conn[#conn+1] = {}
                    conn[#conn].adr = arg[3]
                    conn[#conn].name = b[3]
                    send(conn[#conn].name .. " connected")
                    addLine2(conn[#conn].name .. " connected")
                end
            else
                m.send(arg[3], 89, false, "invalid password")
            end
        elseif check(conn, arg[3]) and b[1] == "disconnect" then
            send(getName(arg[3]) .. " disconnected")
            addLine2(getName(arg[3]) .. " disconnected")
            del(conn, arg[3])
        elseif check(conn, arg[3]) then
            send("<" .. getName(arg[3]) .. "> " .. arg[6])
            addLine2("<" .. getName(arg[3]) .. "> " .. arg[6])
        end
    else
        if arg[2] ~= arg[3] then addLine2(arg[6]) end
    end
end

if not host then
    m.send(adr, 89, "connect " .. sha.sha3_256(args[3]) .. " " .. (args[4] or os.getenv("PCNAME")))
    local h = {e.pull(5, "modem_message")}
    if #h > 5 then 
        if h[6] == false then print("Connecting error\n" .. h[7]);m.close(89);return end
    else
        print("Timed out");m.close(89);return
    end
end
e.listen("modem_message", res)

while true do
    if not host then
        t.setCursor(1, h)
        local txt = io.read()
        if type(txt) == "string" then
            gpu.copy(1,1,w,h-1,0,math.ceil(string.len(txt)/w))
            gpu.fill(1, h, w, 1, " ")
            m.send(adr, 89, txt)
        else m.send(adr, 89, "disconnect");break end
    else
        t.setCursor(1, h)
        local txt = io.read()
        if type(txt) == "string" then
            if string.sub(txt, 1, 1) == "/" then
                local d = p.split(txt, " ")
                if d[1] == "/kick" and #d == 2 then
                    m.send(getAdr(d[2]), 89, "You was kicked")
                    del(conn, getAdr(d[2]))
                    send(d[2] .. " kicked")
                    addLine(d[2] .. " kicked")
                elseif d[1] == "/rename" and #d == 3 then
                    rename(d[2], d[3])
                    send(d[2] .. " renamed to " .. d[3])
                    addLine(d[2] .. " renamed to " .. d[3])
                end
                gpu.fill(1, h, w, 1, " ")
            else
                send("<" .. name .. "> " .. txt)
                addLine("<" .. name .. "> " .. txt)
                gpu.fill(1, h, w, 1, " ")
            end
        else send("Host closed connection");break end
    end
end

e.ignore("modem_message", res)
m.close(89)