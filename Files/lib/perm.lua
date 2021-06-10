local sha = require ("sha2")
local perm = {}

function perm.getUsr(comName)
  local file = io.open("/etc/perm")
  local f
  local tmp = {}
  repeat
   f = file:read("*l")
   if f ~= nil then tmp = perm.split(f, ":") else break end
  until tostring(tmp[1]) == comName
  file:close()
  if f == nil then tmp[2] = "user" end
  --if tmp[2] == "*" then tmp[2]="" end
  local ret = false
  
  local nv = os.getenv("USER")
  if tmp[2] == "root" then
    if nv == "root" then ret = true end
  elseif tmp[2] == "user" then
    ret = true
  end
  return ret
end

function perm.getPerm(user)
  local file = io.open("/etc/sys/passwd")
  local f
  local tmp = {}
  repeat
    f = file:read("*l")
    if f ~= nil then tmp = perm.split(f, ":") else break end
  until tostring(tmp[1]) == user
  file:close()
  if f == nil then return "guest" end
  
  return tmp[1]
end


function perm.getUser(user)
  local f = ""
  local data = {}
  local file = io.open("/etc/sys/passwd")
  repeat
      f = file:read("*l")
      if f ~= nil then data = perm.split(f, ":") else break end
  until data[1] == user
  file:close()
   if data[1] == "user" then data[3] = "/home" elseif data[1] == "root" then data[3] = "/root" end
  if f ~= nil then return data else return nil end
end

function perm.split (inputstr, sep)
  if inputstr == nil then return "" end
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

function perm.save(path)
  local f
  local file = io.open("/etc/checkfile")
  repeat
      f = file:read("*l")
      if f == nil then break end
  until f == path
  file:close()
  if f ~= nil then return true else return false end
end

function perm.check()
  local b = false
  for c in io.lines("/etc/checkfile") do
    local txt = ""
    if not require("filesystem").exists(c) then print("File `" .. c .. "' not found!"); b = true; require("computer").beep(700, 0.3); goto skip end
    for t in io.lines(c) do
      txt = txt .. t .. "\n"
    end

    local needL

    local prof = {}
    for l in io.lines("/etc/sys/sums") do
        prof[#prof + 1] = l
        if string.find(l, c) ~= nil then
            needL = #prof
        end
    end
    local sum = perm.split(prof[needL], ":")[2]
    if sum ~= sha.md5(txt) then
      print("File `" .. c .. "' modified!")
      require("computer").beep(700, 0.3)
      b = true
    end
    ::skip::
  end
  if b then
    io.write("\nEnd")
    io.read()
  end
end

return perm