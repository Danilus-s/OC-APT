local c = require("component")
local perm = require("perm")
local text = require("text")
local term = require("term")
local event = require("event")
local modem = c.modem

if not require("perm").getUsr("modem") then io.write("\27[31mPermission denied\27[m\n");return end

local adr = modem.address
adr = string.sub(adr, 1, 4)
local ports = {}

local data = {
    "\27[33mopen\27[m>  -  -  -   opens ports",
    "\27[33mclose\27[m> -  -  -   closes the ports",
    "\27[33mopened\27[m>   -  -   print all open ports",
    "\27[33msend\27[m>  -  -  -   sends a message",
    "\27[33mbroadcast OR bc\27[m> broadcast to port",
    "\27[33mget\27[m>   -  -  -   receive a modem message",
    "\27[33mclear OR cls\27[m>    clear the screen",
    "\27[33maddress OR adr\27[m>  print modem address",
    "\27[33mping-bc\27[m>  -  -   broadcast and receive",
    "\27[33mping-s\27[m>   -  -   send and receive",
    "\27[33mstrength-get OR str-g\27[m> print signal strength",
    "\27[33mstrength-set OR str-s\27[m> set signal strength",

    "\27[33mexit\27[m>  -  -  -   exit the program"
}

while true do
    io.write("\27[33m[" .. adr .. "] modem>>\27[m")
    local inp = io.read()
    if type(inp) ~= "string" then break end
    inp = string.lower(text.trim(inp))
    if inp == "exit" then break
    elseif inp == "open" then
        io.write("  Open port>>")
        local p = {}
        p = perm.split(io.read(), " ")
        for n = 1, #p do
            local st, res = modem.open(tonumber(p[n]))
            if st then
                io.write("   " ..p[n] .. ": Port opened\n")
            else
                io.write("   " ..p[n] .. ": Port not opened> ".. res .. "\n")
            end
        end
    elseif inp == "close" then
        io.write("  Close port>>")
        local p = perm.split(io.read(), " ")
        for n = 1, #p do
            local st, res = modem.close(tonumber(p[n]))
            if st then
                io.write("   " .. p[n] .. ": Port closed\n")
            else
                io.write("   " .. p[n] .. ": Port not closed> ".. res .. "\n")
            end
        end
    elseif inp == "opened" then
        io.write("  From .. To>>")
        local m = perm.split(io.read(), " ")
        local p = {}
        for n = 1, #m do p[n] = tonumber(m[n]) end
        if #m == 2 then
            for c = p[1], p[2] do
                if modem.isOpen(c) then io.write("   " .. c .. "\n") end
            end 
        end
    elseif inp == "send" then
        io.write("  Address>>")
        local addr = text.trim(io.read())
        io.write("  Port>>")
        local por = tonumber(text.trim(io.read()))
        io.write("  Message>>")
        local mes = io.read()
        if modem.send(addr, por, mes) then io.write("   Success\n") else io.write("   Failure\n") end
    elseif inp == "broadcast" or inp == "bc" then
        io.write("  Port>>")
        local por = perm.split(text.trim(io.read()), " ")
        io.write("  Message>>")
        local mes = io.read()
        for n = 1, #por do
            if modem.broadcast(tonumber(por[n]), mes) then io.write("   ".. por[n] .."> success\n") else io.write("   ".. por[n] .."> failure\n") end
        end
    elseif inp == "ping-bc" then
        io.write("  Port>>")
        local por = perm.split(text.trim(io.read()), " ")
        io.write("  Message>>")
        local mes = io.read()
        for n = 1, #por do
            if modem.broadcast(tonumber(por[n]), mes) then io.write("   ".. por[n] .."> success\n") else io.write("   ".. por[n] .."> failure\n") end
        end
        ::ret::
        local a = table.pack(event.pull())
        if #a > 2 then if a[2] == a[3] then goto ret end end
        if a[1] == "modem_message" then  
            io.write("   From> " .. a[3] .. "\n   Port> " .. a[4] .. "\n   Distance> " .. a[5] .. "\n   Message> " .. tostring(a[6]) .. "\n\n")
        elseif a[1] == "interrupted" then
            io.write("   Interrupted\n") 
        else
            goto ret
        end
    elseif inp == "ping-s" then
        io.write("  Address>>")
        local addr = text.trim(io.read())
        io.write("  Port>>")
        local por = tonumber(text.trim(io.read()))
        io.write("  Message>>")
        local mes = io.read()
        if modem.send(addr, por, mes) then io.write("   Success\n\n") else io.write("   Failure\n\n") end
        ::ret2::
        local a = table.pack(event.pull())
        if a[1] == "modem_message" then  
            io.write("   From> " .. a[3] .. "\n   Port> " .. a[4] .. "\n   Distance> " .. a[5] .. "\n   Message> " .. tostring(a[6]) .. "\n\n")
        elseif a[1] == "interrupted" then
            io.write("   Interrupted\n") 
        else
            goto ret2
        end
    elseif inp == "get" then
        --io.write("  Time out>>")
        --local to = tonumber(text.trim(io.read()))
        repeat
            local a = table.pack(event.pull())
            if a ~= {} then 
                if a[1] == "modem_message" then io.write("   From> " .. a[3] .. "\n   Port> " .. a[4] .. "\n   Distance> " .. a[5] .. "\n   Message> " .. a[6] .. "\n\n")  end
            else
                io.write("   Time out\n\n")
            end
        until a[1] == "interrupted"
    elseif inp == "strength-get" or inp == "str-g" then
        if modem.isWireless == true then io.write("  Signal strength is> " .. modem.getStrength() .. "\n") else io.write("  Modem is not wireless\n") end
    elseif inp == "strength-set" or inp == "str-s" then
        if modem.isWireless == true  then 
            io.write("  Set>>")
            local str = tonumber(text.trim(io.read()))
            if modem.setStrength(str) then io.write("   Success\n") else io.write("   Failure\n") end
        else io.write("  Modem is not wireless\n") end
    elseif inp == "help" or inp == "?" then
        for n = 1, #data do
            io.write("  " .. data[n] .. "\n")
        end
    elseif inp == "clear" or inp == "cls" then
        term.clear()
    elseif inp == "address" or inp == "adr" then
        io.write("  Modem address is> " .. modem.address .. "\n")
    else io.write("  " .. inp .. "> not found\n  Type `help' or `?'\n")
    end
end