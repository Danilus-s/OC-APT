local c = require("component")
local e = require("event")
local s = require("shell")
local fs = require("filesystem")
local t = require("tty")
local p = require("perm")
local perm = require "perm"
local m = c.modem

if not c.isAvailable("modem") then print("'modem' not available"); return end

local args, opt = s.parse(...)
if #args < 2 then print("Use `filesender get|send [filename] [address]'"); return end

local path
local adr
local fi = {}
local cof

local function getFile()
    for l in io.lines(path) do
        fi[#fi+1] = l
    end
    cof = 100/#fi
end

local function send()
    m.open(63)
    getFile()
    if opt.b then 
        m.broadcast(63, "ready ".. cof)
    else
        m.send(adr, 63, "ready ".. cof)
    end
    ::ret::
    local resp = {e.pull(5, "modem_message")}
    if resp[1] ~= "modem_message" then
        print("Timed out")
        return
    elseif resp[2] == resp[3] then goto ret
    elseif resp[6] == true then
        if opt.b then adr = resp[3] end
        io.write("Sending: ")
        local x,y = t.getCursor()
        for i = 1, #fi do
            t.setCursor(x,y)
            io.write(math.floor(cof*i) .. "%")
            m.send(adr, 63, fi[i])
            local re = {e.pull(5, "modem_message")}
            if re[1] ~= "modem_message" then
                print("\nTimed out")
                return
            elseif re[6] ~= true then
                print("\nSending stopped")
                return
            end
        end
        m.send(adr, 63, "done")
        m.close(63)
        print("\nDone")
    end
end

local function get()
    m.open(63)
    ::ret::
    local resp = {e.pull()}
    if resp[1] == "interrupted" then
        print("Interrupted")
        return
    elseif resp[1] == "modem_message" then
        local r = perm.split(resp[6], " ")
        if r[1] == "ready" then
            print("Start receiving files from " .. resp[3])
            cof = r[2]
            goto start
        end
    else goto ret end
    ::start::
    local file = io.open(path, "a")
    m.open(63)
    m.send(resp[3], 63, true)
    io.write("Receiving: ")
    local x,y = t.getCursor()
    local c = 1
    while true do
        local r = {e.pull(5, "modem_message")}
        if #r < 6 then print("\nReceiving abort");break end
        if r[6] == "done" then print("\nDone");break end
        t.setCursor(x,y)
        io.write(math.floor(cof*c) .. "%")
        file:write(r[6] .. "\n")
        m.send(resp[3], 63, true)
        c = c+1
    end
    file:close()
    m.close(63)
end

if args[1] == "get" then
    path = s.resolve(args[2])
    if fs.exists(path) then 
        io.write("File already exists. Overwrite? [Y/n] ")
        local r = io.read()
        if r == "" or string.sub(string.lower(r),1,1) == "y" then
            fs.remove(path)
        else return
        end
    end
    get()
elseif args[1] == "send" then
    path = s.resolve(args[2])
    if not opt.b then adr = args[3] end
    if fs.exists(path) and not fs.isDirectory(path) then
        send()
    else print("File is directory or not found")
        return
    end
else print("Use `filesender get|send [address] [filename]'"); return
end