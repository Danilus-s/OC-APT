local init
do
  local component_invoke = component.invoke
  local function boot_invoke(address, method, ...)
    local result = table.pack(pcall(component_invoke, address, method, ...))
    if not result[1] then
      return nil, result[2]
    else
      return table.unpack(result, 2, result.n)
    end
  end

  -- backwards compatibility, may remove later
  local eeprom = component.list("eeprom")()
  computer.getBootAddress = function()
    return boot_invoke(eeprom, "getData")
  end
  computer.setBootAddress = function(address)
    return boot_invoke(eeprom, "setData", address)
  end

  do
    local screen = component.list("screen")()
    local gpu = component.list("gpu")()
    if gpu and screen then
      boot_invoke(gpu, "bind", screen)
    end
  end
  local function tryLoadFrom(address)
    local handle, reason = boot_invoke(address, "open", "/init.lua")
    if not handle then
      return nil, reason
    end
    local buffer = ""
    repeat
      local data, reason = boot_invoke(address, "read", handle, math.huge)
      if not data and reason then
        return nil, reason
      end
      buffer = buffer .. (data or "")
    until not data
    boot_invoke(address, "close", handle)
    return load(buffer, "=init")
  end
  local gpu = component.list("gpu")()
  
  if computer.getBootAddress() then
    init = tryLoadFrom(computer.getBootAddress())
  end
  local w,h = boot_invoke(gpu, "getResolution")
  local aut = true
  if init then
    boot_invoke(gpu, "fill", 1,1,w,h," ")
    boot_invoke(gpu, "set", 2,2, math.floor(computer.totalMemory() / 1024) .. "k RAM")
    boot_invoke(gpu, "set", 2,4, computer.getArchitecture())
    local n = 2
    for i,b in pairs(component.list()) do
      boot_invoke(gpu, "set", 2,4+n, i:sub(1,8) .. "@" .. b)
      n = n + 1
    end
    boot_invoke(gpu, "set", w/2-11,h, "Press F1 to enter sutup")
    ::ret::
    local sig = {computer.pullSignal(2)}
    if #sig > 2 then
      if sig[1] == "key_down" then
        if sig[4] == 59 then
          aut = false
        else goto ret
        end
      else
        goto ret
      end
     else computer.beep(1000, 0.2);init()
    end
  else
    boot_invoke(gpu, "fill", 1,1,w,h," ")
    boot_invoke(gpu, "set", 2,2, math.floor(computer.totalMemory() / 1024) .. "k RAM")
    boot_invoke(gpu, "set", 2,4, computer.getArchitecture())
    local n = 2
    for i,b in pairs(component.list()) do
      boot_invoke(gpu, "set", 2,4+n, i:sub(1,8) .. "@" .. b)
      n = n + 1
    end
    boot_invoke(gpu, "set", w/2-15,h-1, "Default boot address not found")
    boot_invoke(gpu, "set", w/2-11,h,   "Press F1 to enter sutup")
    ::ret::
    local sig = {computer.pullSignal()}
    if #sig > 2 then
      if sig[1] == "key_down" then
        if sig[4] == 59 then
          aut = false
        else goto ret
        end
      else
        goto ret
      end
    else computer.shutdown()
    end
  end
  
  boot_invoke(gpu, "fill", 1,1,w,h," ")
  boot_invoke(gpu, "set", 1,1, "Select what to boot:")

  local osList = {}

  local reason
  
  for fs in component.list("filesystem") do
    if component.invoke(fs, "exists", "/init.lua") then
      osList[#osList+1] = fs
      boot_invoke(gpu, "set", 1,#osList+1,tostring(#osList).."."..(fs:sub(1,4)).."@"..component.invoke(fs, "getLabel"))
    end
  end
  boot_invoke(gpu, "set", 1,#osList+2,"Select os:")
  if #osList == 1 and aut == true then
     init, reason = tryLoadFrom(osList[1])
     if not init then boot_invoke(gpu, "set", 1,10,reason) else computer.beep(1000, 0.2);computer.setBootAddress(osList[1]);init() end
  end
  if #osList == 0 then
    error("No OS found")
  end
  while true do
    local sig = {computer.pullSignal()}
    if sig[1] == "key_down" then
      boot_invoke(gpu, "fill", 1,#osList+3,10,1," ")
      if sig[4] >= 2 and sig[4] <= 11 then
        if osList[sig[4]-1] then
          init, reason = tryLoadFrom(osList[sig[4]-1])
          if not init then boot_invoke(gpu, "set", 1,10,reason) else computer.setBootAddress(osList[sig[4]-1]);break end
        else
          boot_invoke(gpu, "set", 1,#osList+3,"Not found!")
        end
      end
    end
  end
  computer.beep(1000, 0.2)
end

init()