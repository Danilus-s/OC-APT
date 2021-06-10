local sha = require("sha2")
local shell = require("shell")
local perm = require("perm")

if not require("perm").getUsr("brutforce") then io.write("\27[31mPermission denied\27[m\n");return end

local target = ""
local done = false
local args, opt = shell.parse(...)
local st = os.time()
local f,s = 32, 126

if #args == 0 then print("Use: brutforce <-p|-o|-c> [filename|passwd] <-n>"); return end

if opt.n then f,s = 48,57 end
if opt.p then
    local vars = {}
    for l in io.lines(shell.resolve(args[1])) do
        vars[#vars+1] = l
    end
    for i = 1, #vars do
        io.write(i .. ". " .. perm.split(vars[i], ":")[1] .. "\n")
    end
    io.write("Choose user: ")
    local n = tonumber(io.read())
    if n > #vars then return end
    target = perm.split(vars[n], ":")[2]
elseif opt.o then
    local file = io.open(shell.resolve(args[1]))
    target = file:read()
    file:close()
elseif opt.c then
    target = args[1]
end

local function tm()
    local full = os.time()-st
    local out = {0,0,0}
    if full > 3600 then 
        out[1] = math.floor(full/3600)
        out[2] = math.fmod(math.floor(full/60), 60)
        out[3] = math.fmod(full, 60)
    elseif full > 60 then
        out[2] = math.floor(full/60)
        out[3] = math.fmod(math.floor(full/60), 60)
    else
        out[3] = full
    end
    print(out[1] .. " h " .. out[2] .. " min " .. out[3] .. " sec")
end

local function ch(rw)
    if done == true then return end
    local txt = ""
    for b = 1, #rw do txt = txt .. string.char(rw[b]) end
    if target == sha.sha3_256(txt) then print("Password is: " .. txt);tm();done = true else print("not: " .. txt) end
end

local function brut()
    local raw = {f}
    while done == false do
        for i = f, s do
            ch(raw)
            raw[#raw] = i
            if raw[#raw] == s then
                for k = 1, #raw do
                    if k == 1 and raw[k] == s then
                        for n = 1, #raw do raw[n] = f end
                        raw[#raw+1] = f
                    elseif raw[k] == s then
                        raw[k] = f
                        raw[k-1] = raw[k-1] + 1
                    end
                end
                
                
                --[[raw[#raw-1] = raw[#raw-1] + 1
                
                if h == #raw then 
                    
                else
                    raw[#raw-1] = raw[#raw-1] + 1
                    if raw[#raw-1] == 126 then end
                end]]
            end
            os.sleep(0)
        end
    end
end

brut()