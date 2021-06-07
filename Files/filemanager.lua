local c = require("component")
local tty = require("tty")
local event = require("event")
local fs = require("filesystem")
local sh = require("sh")
local shell = require("shell")
local transfer = require("tools/transfer")
local term = require("term")
local uni = require("unicode")

--if not require("perm").getUsr("filemanager") then io.write("\27[31mPermission denied\27[m\n");return end

local gpu = c.gpu
local bg = gpu.setBackground
local fg = gpu.setForeground

local w,h = gpu.getResolution()
local work = {x = 2, y = 7, w = w-2, h = h-7}
local cancel = false
local workDir =  os.getenv("HOME") or "/"
local oldSel = 0
local info = {type = 0, from = "", to = ""}
if ... ~= nil then workDir = shell.resolve(...) end

local function Close_Pressed()
    cancel = true
end

local list = {}

local function resolv(path, ext)
    local dir = path
    if dir:find("/") ~= 1 then
        dir = fs.concat(workDir, dir)
    end
    local name = fs.name(path)
    dir = fs[name and "path" or "canonical"](dir)
    local fullname = fs.concat(dir, name or "")

    if not ext then
        return fullname
    elseif name then
        -- search for name in PATH if no dir was given
        -- no dir was given if path has no /
        local search_in = path:find("/") and dir or os.getenv("PATH")
        for search_path in string.gmatch(search_in, "[^:]+") do
        -- resolve search_path because they may be relative
        local search_name = fs.concat(resolv(search_path), name)
        if not fs.exists(search_name) then
            search_name = search_name .. "." .. ext
        end
        -- extensions are provided when the caller is looking for a file
        if fs.exists(search_name) and not fs.isDirectory(search_name) then
            return search_name
        end
        end
    end

    return nil, "file not found"
end

local function updateData()
    local c = 1
    list = {}
    scroll_list.butt = {}
    local dirs = {}
    fg(0xFFFFFF)
    if fs.list(workDir) == "Block" then
        list[1] = {}
        list[1]["name"] = "This directory is blocked"
        list[1]["path"] = "/"
        list[1]["isDir"] = true
        scroll_list["butt"][1] = list[1]
        goto skip
    else
        for d in fs.list(workDir) do
            dirs[#dirs+1] = d
        end
    end
    local dt = {}
    local ft = {}
    for i = 1, #dirs do
        if fs.isDirectory(resolv(dirs[i])) then dt[#dt+1] = dirs[i]
        elseif not fs.isDirectory(resolv(dirs[i])) then ft[#ft+1] = dirs[i] end
    end
    table.sort(dt)
    table.sort(ft)
    dirs = dt
    for i = 1, #ft do
        dirs[#dirs+1] = ft[i]
    end
    if fs.list(workDir) == "Block" then
        list[1] = {}
        list[1]["name"] = "This directory is blocked"
        list[1]["path"] = "/"
        list[1]["isDir"] = true
        scroll_list["butt"][1] = list[1]
    else 
        for d = 1, #dirs do
            list[c] = {}
            list[c]["name"] = fs.name(dirs[d])
            list[c]["path"] = resolv(dirs[d])
            list[c]["isDir"] = fs.isDirectory(resolv(dirs[d]))
            scroll_list["butt"][c] = list[c]
            c = c+1
        end
    end
    ::skip::
end
local function updateList()
    local rawCount
    local max = work.h
    if work.h > #scroll_list.butt then
        rawCount = #scroll_list.butt
    elseif work.h <= #scroll_list.butt then
        rawCount = work.h
        max = #scroll_list.butt - work.h+5
    end
    bg(0x807080)
    gpu.fill(work.x, work.y, work.w, work.h, " ")
    if max ~= work.h then
        bg(0xFFFFFF)
        gpu.fill(work.w+1, work.y+((scroll_list.startPos-2)+#scroll_list.butt / work.h), 1, max, " ")
    end
    bg(0x606060)
    gpu.fill(work.w-2,work.y+work.h,5,5, " ")
    bg(0x807080)
    for d = 1, rawCount do
        if d + scroll_list.startPos - 1 <= #scroll_list.butt then
            if d % 2 == 0 then bg(0x6B6B6B) else bg(0x707070) end
            gpu.fill(work.x, work.y+d-1, work.w-1, 1, " ")
            if scroll_list.butt[d].isDir then fg(0xD49F00) elseif string.sub(scroll_list.butt[d].name, uni.wlen(scroll_list.butt[d].name)-3) == ".lua" then fg(0x00FF00) else fg(0x000000) end
            gpu.set(work.x, work.y+d-1, scroll_list.butt[d + scroll_list.startPos - 1].name)
            --gpu.set(work.x, work.y+d-1, list[d].name)
        end
    end
    fg(0xFFFFFF)
    bg(0x000000)
end
local function select(index)
    updateList()
    bg(0x888888)
    if index ~= 0 then
        gpu.fill(work.x, work.y+index-1, work.w-1, 1, " ")
        if list[index].isDir then fg(0xD49F00) elseif string.sub(list[index].name, uni.wlen(list[index].name)-3) == ".lua" then fg(0x00FF00) else fg(0x000000) end
        gpu.set(work.x, work.y+index-1, scroll_list.butt[scroll_list.startPos + index - 1].name)
    end
end
local function updateDir()
    bg(0x807080)
    fg(0xF0F0F0)
    gpu.fill(11,5,w-11,1, " ")
    gpu.set(12,5,workDir)
    bg(0x000000)
    fg(0x000000)
end
local function updateInfo ()
    bg(0x606060)
    fg(0x88FF88)
    gpu.fill(10,h,w,1," ")
    if info.type ~= 0 then
        if info.type == 1 then
            gpu.set(10,h,"[Copy from: " .. info.from .. " to: " .. info.to .. "]")
        elseif info.type == 2 then
            gpu.set(10,h,"[Move from: " .. info.from .. " to: " .. info.to .. "]")
        end
    end
end
local function startup()
    tty.clear()
    fg(0xFFFFFF)
    bg(0x606060)
    gpu.fill(1,1,w,h, " ")
    bg(0xD27ED6)
    gpu.fill(1,1,w,2, " ")
    gpu.set(2,1,sh.expand("File Manager [ $USER ]"))
    bg(0x807080)
    gpu.fill(1,3,w,1," ")
    gpu.fill(work.x, work.y, work.w, work.h, " ")
    for g = 1, #butt do
        bg(butt[g].bc)
        fg(butt[g].fc)
        gpu.fill(butt[g].bx, butt[g].by, butt[g].bw, butt[g].bh, " ")
        gpu.set(butt[g].bx+butt[g].bw/2-uni.wlen(butt[g].text)/2, butt[g].by+butt[g].bh/2, butt[g].text)
        bg(0x000000)
        fg(0x000000)
    end
end
local function getName()
    term.setCursor(75,h)
    bg(0x606060)
    fg(0x000000)
    return require("text").trim(io.read())
end
local function NewDir_Pressed()
    fs.makeDirectory(workDir .. "/" .. getName())
    startup()
    updateDir()
    updateInfo()
    updateData()
    updateList()
end
local function NewFile_Pressed()
    local file = io.open(workDir .. "/" .. getName(), "w")
    file:write("")
    file:close()
    startup()
    updateDir()
    updateInfo()
    updateData()
    updateList()
end
local function Rename_Pressed()
    transfer.batch({scroll_list.butt[oldSel].path, workDir .. "/" .. getName()}, {cmd = "mv",f = true})
    startup()
    updateDir()
    updateInfo()
    updateData()
    updateList()
end
local function Copy_Pressed()
    if oldSel ~= 0 then
        if not scroll_list.butt[oldSel].isDir then
            info.type = 1
            info.from = scroll_list.butt[oldSel].path
            info.to = workDir
            updateInfo()
        end
    end
end
local function Move_Pressed()
    if oldSel ~= 0 then
        if not scroll_list.butt[oldSel].isDir then
            info.type = 2
            info.from = scroll_list.butt[oldSel].path
            info.to = workDir
            updateInfo()
        end
    end
end
local function Paste_Pressed()
    if info.type == 1 then
        transfer.batch({info.from, info.to}, {cmd = "cp"})
    elseif info.type == 2 then
        transfer.batch({info.from, info.to}, {cmd = "mv",f = true})
    end
    info.type = 0
    info.from = ""
    info.to = ""
    startup()
    updateDir()
    updateInfo()
    updateData()
    updateList()
end
local function Back_Pressed()
    if workDir ~= "/" then
        workDir = string.sub(workDir, 1, uni.wlen(workDir)-uni.wlen(fs.name(workDir))-1)
        if workDir == "" then workDir = "/" end
        scroll_list.startPos = 1
        updateDir()
        updateData()
        updateList()
        fg(0xFFFFFF)
        bg(0x606060)
        gpu.fill(3, h, 5, 1, " ")
        gpu.set(3, h, tostring(#list) .. "|0")
    end
    info.to = workDir
    updateInfo()
end
local function Home_Pressed()
    workDir =  os.getenv("HOME") or "/"
    scroll_list.startPos = 1
    updateDir()
    updateData()
    updateList()
    fg(0xFFFFFF)
    bg(0x606060)
    gpu.fill(3, h, 5, 1, " ")
    gpu.set(3, h, tostring(#list) .. "|0")
    info.to = workDir
    updateInfo()
end
local function Rem_Pressed()
    if oldSel ~= 0 then
        fs.remove(scroll_list.butt[oldSel].path)
        updateDir()
        updateData()
        updateList()
    end
end
local function Edit_Pressed()
    if oldSel ~= 0 then
        bg(0x000000)
        fg(0xFFFFFF)
        shell.execute("/bin/edit.lua " .. list[oldSel].path)
    end
end
local function Run_Pressed()
    if oldSel ~= 0 then
        bg(0x000000)
        fg(0xFFFFFF)
        tty.clear()
        shell.execute(list[oldSel].path)
        io.write("\n\nProgram has ended\nPerss any key to continue...")
        event.pull("key_down")
    end
end
butt = {
    {bx = w-3, by = 1, bw = 5, bh = 2, bc = 0xFF0000, fc = 0x000000, text = "", func = Close_Pressed},
    {bx = 7, by = 5, bw = 3, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "^", func = Back_Pressed},
    {bx = 2, by = 5, bw = 4, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "home", func = Home_Pressed},
    {bx = 1, by = 3, bw = 8, bh = 1, bc = 0x807080, fc = 0xFF0000, text = "remove", func = Rem_Pressed},
    {bx = 9, by = 3, bw = 6, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "edit", func = Edit_Pressed},
    {bx = 15, by = 3, bw = 5, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "run", func = Run_Pressed},
    {bx = 20, by = 3, bw = 6, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "copy", func = Copy_Pressed},
    {bx = 26, by = 3, bw = 6, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "move", func = Move_Pressed},
    {bx = 32, by = 3, bw = 7, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "paste", func = Paste_Pressed},
    {bx = 39, by = 3, bw = 8, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "rename", func = Rename_Pressed},
    {bx = 47, by = 3, bw = 10, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "new file", func = NewFile_Pressed},
    {bx = 57, by = 3, bw = 9, bh = 1, bc = 0x807080, fc = 0xFFFFFF, text = "new dir", func = NewDir_Pressed}
}
scroll_list = {startPos = 1, butt = {}}


startup()
updateData()
updateDir()
updateList()

fg(0xFFFFFF)
bg(0x606060)
gpu.fill(3, h, 5, 1, " ")
gpu.set(3, h, tostring(#list) .. "|0")
while true do
    local n,_,x,y,s = event.pull()
    if n == "touch" then
        for g = 1, #butt do
            if x >= butt[g].bx and x <= butt[g].bx+butt[g].bw and y >= butt[g].by and y <= butt[g].by+butt[g].bh then
                butt[g].func()
                if oldSel ~= 0 and butt[g].func == Edit_Pressed or butt[g].func == Run_Pressed then
                    startup()
                    updateDir()
                    updateData()
                    updateList()
                    oldSel = 0
                end
            end
        end
        local v = #scroll_list.butt-scroll_list.startPos+1
        for b = 1, v do
            if x >= work.x and x < work.x + work.w-1 and y >= work.y + b - 1 and y <= work.y + b -1 then--x >= work.x and x <= work.x+work.w and y >= work.y+b-1 and y <= work.y+b-1 then
                if oldSel ~= b + scroll_list.startPos - 1 then
                    oldSel = b + scroll_list.startPos - 1
                    select(b)
                    fg(0xFFFFFF)
                    bg(0x606060)
                    gpu.fill(3, h, 10, 1, " ")                    
                    if oldSel == 0 then
                        gpu.set(3, h, tostring(#list) .. "|" .. oldSel)
                    elseif not list[oldSel].isDir then
                        local si,txt = fs.size(list[oldSel].path), ""
                        if si > 1024000 then
                            txt = math.ceil(si / 1024000)
                            txt = txt .. " MB"
                        elseif si > 1024 then
                            txt = math.ceil(si / 1024)
                            txt = txt .. " KB"
                        else
                            txt = tostring(si) .. " B"
                        end
                        gpu.set(3, h, tostring(#list) .. "|" .. oldSel .. " > " .. txt)
                    end
                    break
                else
                    oldSel = 0
                    if list[b + scroll_list.startPos - 1].isDir then
                        workDir = list[b + scroll_list.startPos - 1].path
                        scroll_list.startPos = 1
                        updateDir()
                        updateData()
                        updateList()
                        fg(0xFFFFFF)
                        bg(0x606060)
                        gpu.fill(3, h, 5, 1, " ")
                        gpu.set(3, h, tostring(#list) .. "|" .. oldSel)
                        info.to = workDir
                        updateInfo()
                    else
                        bg(0x000000)
                        fg(0xFFFFFF)
                        if string.sub(scroll_list.butt[b + scroll_list.startPos - 1].name, uni.wlen(scroll_list.butt[b + scroll_list.startPos - 1].name)-3) == ".lua" then
                            tty.clear()
                            shell.execute(list[b + scroll_list.startPos - 1].path)
                            io.write("\n\nProgram has ended\nPerss any key to continue...")
                            event.pull("key_down")
                        else
                            shell.execute("/bin/edit.lua " .. list[b + scroll_list.startPos - 1].path)
                        end
                        startup()
                        updateDir()
                        updateData()
                        updateList()
                    end
                    break
                end
            end
        end
    elseif n == "touch" or n == "drag" then
        if x >= work.x + work.w-1 and x <= work.x + work.w-1 and y >= work.y and y <= work.y + work.h-1 and #scroll_list.butt > work.h then
            scroll_list.startPos = y-work.y+1
            local spec = #scroll_list.butt-work.h
            spec = work.h/spec
            scroll_list.startPos = math.floor(scroll_list.startPos/spec)+1
            updateList()
        end
    elseif n == "scroll" then
        if s == -1 and scroll_list.startPos < #scroll_list.butt-work.h then
            if scroll_list.startPos < #scroll_list.butt - work.h + 1 then
                scroll_list.startPos = scroll_list.startPos + 5
            end
        elseif s == 1 then
            if scroll_list.startPos > 1 then
                scroll_list.startPos = scroll_list.startPos - 5
            end
        end
        if scroll_list.startPos > #scroll_list.butt then scroll_list.startPos = #scroll_list.butt end
        if scroll_list.startPos < 1 then scroll_list.startPos = 1 end
        updateList()
        if oldSel ~= 0 and oldSel-scroll_list.startPos > 0 then select(oldSel-scroll_list.startPos+1) end
    end
    if cancel then
        break
    end
end
bg(0x000000)
tty.clear()