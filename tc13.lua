-- TLAPKA COMMANDER v. tc13
-- Dual Panel File Manager for CC: Tweaked
-- Norton / Midnight Commander style
-- Keyboard + Mouse + Advanced Monitor Touch support
-- "CCTweaked - TirithCommander tc13 - 20251214_1725.lua"
--
-- https://pastebin.com/Y2mpi03p 
--
-- CC Command:  pastebin get Y2mpi03p tc.lua
--
-- verze tc5.lua  - 20251213_2005 - repaired draw both left/right panels
--       tc6.lua  - 20251213_2215 - switching view type with "v" key list/detail
--       tc8.lua  - 20251213_2240 - přidání HOME/END, PAGE UP/DOWN a v do ovládání
--                                  aktualizovaná nápověda    
--       tc10.lua - 20251214_0010 - virtual devices <EnderModem>, <ModemDevices>
--                  - added goBack in virtual directory from list of devices back to root of FS
--                  - added sorting by:  name, filetype, date, size
--                    system items - folders, virtual directories (devices) will be alwaysFirst
--
--       tc11.lua - 20251214_0250 - 
--       tc12.lua - 20251214_0650 - added color themes
--                                - configurable control keys
--                                - dialogs "confirmDialog(title, text)"
--                                - file operations: F5 - Copy
--                                                   F6 - Move
--                                                   F8 - Delete
--                                - new menu:
--                                    "TAB Switch | v View | s Sort | r Reverse | d DirsFirst |""
--                                    "F1 Help | F2 Export | F3 View | F4 Edit |""
--                                    "F5 Copy | F6 Move | F8 Delete | F9 Tree | F10 Quit"
--                                - config file "~/.tc.cfg"
--       tc12.lua - 20251214_0650 - BUGS
--       tc13.lua - 20251214_1540 - Savior9O9 Fixed swinecode

-- ==================================================
--      keysCfg = {
--          COPY   = keys.f5,
--          MOVE   = keys.f6,
--          DELETE = keys.f8,
--          ...
--        }
--        


-- ==================================================
-- Configuration
-- ==================================================

-- === Color Schemes ===
local themes = {
  norton = {
    BG=colors.black, PANEL=colors.black, TEXT=colors.lightGray,
    DIR=colors.lightBlue, ACTIVE=colors.blue,
    HEADER=colors.gray, MENU_BG=colors.blue, MENU_FG=colors.white,
    STATUS_BG=colors.gray, STATUS_FG=colors.black,
    DIALOG_BG=colors.gray, DIALOG_FG=colors.black,
    DIVIDER=colors.gray
  },
  midnight = {
    BG=colors.black, PANEL=colors.black, TEXT=colors.white,
    DIR=colors.cyan, ACTIVE=colors.gray,
    HEADER=colors.blue, MENU_BG=colors.black, MENU_FG=colors.cyan,
    STATUS_BG=colors.black, STATUS_FG=colors.white,
    DIALOG_BG=colors.blue, DIALOG_FG=colors.white,
    DIVIDER=colors.lightGray
  }
}

local currentTheme = "norton"
local T = themes[currentTheme]

-- === Key bindings (configurable) ===
local keysCfg = {
  HELP    = keys.f1,
  EXPORT  = keys.f2,
  VIEW    = keys.f3,
  EDIT    = keys.f4,
  COPY    = keys.f5,
  MOVE    = keys.f6,
  DELETE  = keys.f8,
  TREE    = keys.f9,
  QUIT    = keys.f10
}

local SCREEN_COLS, SCREEN_ROWS = term.getSize()

-- ==================================================
local SCREEN_COLS, SCREEN_ROWS = term.getSize()

local COL_BG        = T.BG
local COL_PANEL     = T.PANEL
local COL_TEXT      = T.TEXT
local COL_DIR       = T.DIR
local COL_ACTIVE    = T.ACTIVE
local COL_HEADER    = T.HEADER
local COL_MENU_BG   = T.MENU_BG
local COL_MENU_FG   = T.MENU_FG
local COL_STATUS_BG = T.STATUS_BG
local COL_STATUS_FG = T.STATUS_FG
local COL_DIALOG_BG = T.DIALOG_BG
local COL_DIALOG_FG = T.DIALOG_FG
local COL_DIVIDER   = T.DIVIDER 

-- ==================================================
-- Layout
-- ==================================================
local termW, termH = SCREEN_COLS, SCREEN_ROWS
local panelW = math.floor((termW - 1) / 2)
local dividerX = panelW + 1
local panelH = termH - 4

-- ==================================================
-- State
-- ==================================================
local panels = {
  { x = 1,            path = "/", files = {}, selected = 1, scroll = 0,
    virtualMode = false, vType = nil, pType = nil,
    viewMode = "list", sortBy = "name", sortAsc = true, dirsFirst = true },

  { x = dividerX+1,   path = "/", files = {}, selected = 1, scroll = 0,
    virtualMode = false, vType = nil, pType = nil,
    viewMode = "list", sortBy = "name", sortAsc = true, dirsFirst = true }
}

local activePanel = 1
local message = "Ready"
local viewOverlay = nil
local treeOverlay = nil
local helpOverlay = nil

-- ==================================================
-- Utilities
-- ==================================================
local function active() return panels[activePanel] end
local function inactive() return panels[activePanel==1 and 2 or 1] end

-- ==================================================
-- ==================================================
-- Peripheral plugin system
-- ==================================================
local peripheralPlugins = {}

-- plugin registration
local function registerPeripheral(typeName, handler)
  peripheralPlugins[typeName] = handler
end

-- default generic plugin
registerPeripheral("_default", function(name)
  return {
    "Peripheral: " .. name,
    "Type: " .. tostring(peripheral.getType(name)),
    "Methods:" ,
    unpack(peripheral.getMethods(name) or {})
  }
end)

-- example: modem plugin
registerPeripheral("modem", function(name)
  local info = {
    "Peripheral: " .. name,
    "Type: modem"
  }
  if peripheral.call(name, "isWireless") ~= nil then
    table.insert(info, "Wireless: " .. tostring(peripheral.call(name, "isWireless")))
  end
  return info
end)

local function getPeripheralInfo(name)
  local t = peripheral.getType(name)
  local plugin = peripheralPlugins[t] or peripheralPlugins["_default"]
  return plugin(name)
end

-- ==================================================
-- Peripheral helpers
-- ==================================================
local function listPeripheralTypes()
  local map = {}
  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    map[t] = map[t] or {}
    table.insert(map[t], name)
  end
  return map
end
-- ==================================================
-- sort files
-- ==================================================
local function sortFiles(panel)
  table.sort(panel.files, function(a, b)
    -- safety guards
    if not a then return true end
    if not b then return false end

    -- always keep parent first
    if a.name == ".." then return true end
    if b.name == ".." then return false end

    local av, bv

    if panel.sortBy == "name" then
      message = message .. "sort by Name["
      av = tostring(a.name):lower()
      bv = tostring(b.name):lower()
    elseif panel.sortBy == "type" then
      message = "sort by type["
      av = a.isDir and "0" or "1"
      bv = b.isDir and "0" or "1"
    elseif panel.sortBy == "size" then
      message = "sort by Size["
      av = tonumber(a.size) or 0
      bv = tonumber(b.size) or 0
    elseif panel.sortBy == "date" then
      message = "sort by Date["
      av = tonumber(a.date) or 0
      bv = tonumber(b.date) or 0
    end
  if panel.sortAsc then 
    message = message .. string.char(30) .. "]"
  else 
    message = message .. string.char(31) .. "]"
  end

    if av == bv then
      return tostring(a.name):lower() < tostring(b.name):lower()
    end

    return panel.sortAsc and (av < bv) or (av > bv)
  end)
end


-- ==================================================
-- Read Directory / Virtual FS
-- ==================================================
local function readDir(panel)
  local list = {}

  if panel.virtualMode then
    table.insert(list, { name = "..", isDir = true })

    if panel.vType == "peripheral_root" then
      for t,_ in pairs(listPeripheralTypes()) do
        table.insert(list, { name = t, isDir = true, virtual = true, vType = "peripheral_type", pType = t })
      end
    elseif panel.vType == "peripheral_type" then
      for _, name in ipairs(listPeripheralTypes()[panel.pType] or {}) do
        table.insert(list, { name = name, isDir = false, virtual = true, vType = "peripheral_item" })
      end
    end

    panel.files = list
    sortFiles(panel)
    return
  end

  if panel.path ~= "/" then
    table.insert(list, { name = "..", isDir = true })
  else
    table.insert(list, { name = "<Peripherals>", isDir = true, virtual = true, vType = "peripheral_root" })
  end

  for _, f in ipairs(fs.list(panel.path)) do
    local full = fs.combine(panel.path, f)
    table.insert(list, {
      name = f,
      isDir = fs.isDir(full),
      size = fs.isDir(full) and 0 or fs.getSize(full),
      date = fs.getLastModified and fs.getLastModified(full) or 0
    })
  end

  panel.files = list
  sortFiles(panel)
end

-- ==================================================
-- Drawing
-- ==================================================
local function sortIndicator(p)
  local arrow = p.sortAsc and "^" or "ˇ"
  return string.format("[%s%s]", p.sortBy:sub(1,1):upper(), arrow)
end
-- ==================================================
-- ==================================================
local function drawMenu()
  term.setBackgroundColor(COL_MENU_BG)
  term.setTextColor(COL_MENU_FG)
  term.setCursorPos(1,1)
  term.write(string.rep(" ", SCREEN_COLS))
  term.setCursorPos(1,1)
  term.write(" TAB Switch | v View | s Sort | r Reverse | d DirsFirst | F1 Help | F2 Export | F3 View | F4 Edit | F5 Copy | F6 Move | F8 Delete | F9 Tree | F10 Quit ")
end
-- ==================================================
-- ==================================================
local function drawDivider()
  term.setBackgroundColor(COL_BG)
  term.setTextColor(COL_DIVIDER)
  for y=2,termH-1 do
    term.setCursorPos(dividerX, y)
    term.write(string.char(149))
  end
end
-- ==================================================
-- ==================================================
local function drawPanels()
  for i=1,2 do
    local p = panels[i]
    local activeP = (i==activePanel)

    term.setCursorPos(p.x,2)
    term.setBackgroundColor(COL_HEADER)
    term.setTextColor(colors.black)
    local title = (p.virtualMode and "<VFS>" or p.path)
    local hdr = title .. " " .. sortIndicator(p)
    term.write(string.sub(hdr .. string.rep(" ", panelW),1,panelW))

    for y=1,panelH do
      local idx = y + p.scroll
      term.setCursorPos(p.x, y+2)

      if idx==p.selected and activeP and not viewOverlay then
        term.setBackgroundColor(COL_ACTIVE)
        term.setTextColor(colors.white)
      else
        term.setBackgroundColor(COL_PANEL)
        term.setTextColor(COL_TEXT)
      end

      term.write(string.rep(" ", SCREEN_COLS))
      term.setCursorPos(p.x, y+2)

      local e = p.files[idx]
      if e then
        if e.isDir then term.setTextColor(COL_DIR) end
        if p.viewMode == "list" then
          term.write(string.sub(e.name,1,panelW))
        else
          local info
          if e.virtual and e.vType == "peripheral_item" then
            info = string.format("%-16s %-10s", e.name, peripheral.getType(e.name) or "?")
          else
            local typ = e.isDir and "<DIR>" or "<FILE>"
            info = string.format("%-16s %-6s %6s", e.name, typ, e.size or "-")
          end
          term.write(string.sub(info,1,panelW))
        end
      end
    end
  end
end
-- ==================================================
-- ==================================================
local function drawStatus()
  term.setCursorPos(1,termH)
  term.setBackgroundColor(COL_STATUS_BG)
  term.setTextColor(COL_STATUS_FG)
  term.write(string.rep(" ", SCREEN_COLS))
  term.setCursorPos(1,termH)
  message = message .. panels[1].sortBy
  if panels[activePanel].sortAsc then message = message .. string.char( 30 ) .. string.char(32)
  else message = message .. string.char( 31 ) .. string.char(32)
  message = message ..
  term.write(message)
  end
end

-- ==================================================
-- ==================================================
local function drawOverlay()
  local overlay = viewOverlay or treeOverlay or helpOverlay
  if not overlay then return end

  local p = inactive()
  term.setBackgroundColor(COL_DIALOG_BG)
  term.setTextColor(COL_DIALOG_FG)

  for y = 3, termH - 2 do
    term.setCursorPos(p.x, y)
    term.write(string.rep(" ", panelW))
  end

  local yPos = 4
  for _, line in ipairs(overlay) do
    if yPos >= termH - 1 then break end
    term.setCursorPos(p.x + 1, yPos)
    term.write(string.sub(line, 1, panelW - 2))
    yPos = yPos + 1
  end
end

-- ==================================================
-- ==================================================
local function redraw()
  term.setBackgroundColor(COL_BG)
  term.clear()
  drawMenu()
  drawPanels()
  drawDivider()
  drawOverlay()
  drawStatus()
end

-- ==================================================

-- Tree view (ASCII +-|)
-- ==================================================
local function buildTreeAscii(path, prefix, lines, depth)
  if depth > 6 then 
    return 
  end
  local list
  local ok = pcall(function() list = fs.list(path) end)
  if not ok then return end

  for i,name in ipairs(list) do
    local full = fs.combine(path,name)
    local isLast = (i == #list)
    local branch = isLast and "+-" or "+-"
    table.insert(lines, prefix .. branch .. name)
    if fs.isDir(full) then
      local newPrefix = prefix .. (isLast and "  " or "| ")
      buildTreeAscii(full, newPrefix, lines, depth+1)
    end
  end
end

local function showTreeFromSelected()
  local p = active()
  local e = p.files[p.selected]
  if not e or not e.isDir or p.virtualMode then return end
  local root = fs.combine(p.path, e.name)
  local lines = {"Tree: " .. root, ""}
  buildTreeAscii(root, "", lines, 0)
  treeOverlay = lines
end

-- ==================================================
local function buildTree(path, prefix, lines, depth)
  if depth > 4 then return end
  local list
  local ok = pcall(function() list = fs.list(path) end)
  if not ok then return end

  for i,name in ipairs(list) do
    local full = fs.combine(path,name)
    local isLast = (i == #list)
    local branch = isLast and "L¦" or "+¦"
    table.insert(lines, prefix .. branch .. name)
    if fs.isDir(full) then
      local newPrefix = prefix .. (isLast and "  " or "- ")
      buildTree(full, newPrefix, lines, depth+1)
    end
  end
end

local function showTree()
  local p = active()
  local root = p.virtualMode and "<VIRTUAL>" or p.path
  local lines = {"Tree: " .. root, ""}

  if not p.virtualMode then
    buildTree(p.path, "", lines, 0)
  else
    table.insert(lines, "(Tree not available for virtual FS)")
  end

  treeOverlay = lines
end

-- ==================================================
-- ==================================================
-- Help
-- ==================================================
local function showHelp()
  helpOverlay = {
    "Help / Key bindings",
    "",
    "TAB        Switch panel",
    "ENTER      Open directory",
    "ESC        Parent directory",
    "V          Toggle list/detail",
    "S          Change sort key",
    "R          Reverse sort",
    "D          Toggle dirs first",
    "F1         Help",
    "F2         Export panel",
    "F3         View info",
    "F4         Edit file",
    "F9         Tree view",
    "F10        Quit"
  }
end

-- ==================================================
-- ==================================================
-- File operations dialogs
-- ==================================================
local function confirmDialog(title, text)
  local p = inactive()
  local lines = {title, "", text, "", "ENTER = OK / ESC = Cancel"}
  helpOverlay = lines
  while true do
    local e,k = os.pullEvent("key")
    if k==keys.enter then helpOverlay=nil return true
    elseif k==keys.escape then helpOverlay=nil return false end
  end
end

local function copyFile()
  local srcP = active()
  local dstP = inactive()
  local e = srcP.files[srcP.selected]
  if not e or e.isDir then return end
  local src = fs.combine(srcP.path, e.name)
  local dst = fs.combine(dstP.path, e.name)
  if confirmDialog("Copy", src .. " -> " .. dst) then
    fs.copy(src, dst)
    readDir(dstP)
    message = "Copied"
  end
end

local function moveFile()
  local srcP = active()
  local dstP = inactive()
  local e = srcP.files[srcP.selected]
  if not e or e.isDir then return end
  local src = fs.combine(srcP.path, e.name)
  local dst = fs.combine(dstP.path, e.name)
  if confirmDialog("Move", src .. " -> " .. dst) then
    fs.move(src, dst)
    readDir(srcP); readDir(dstP)
    message = "Moved"
  end
end

local function deleteFile()
  local p = active()
  local e = p.files[p.selected]
  if not e then return end
  local target = fs.combine(p.path, e.name)
  if confirmDialog("Delete", target) then
    fs.delete(target)
    readDir(p)
    message = "Deleted"
  end
end

-- ==================================================
-- Operations
-- ==================================================
local function goUp(panel)
  if panel.virtualMode then
    panel.virtualMode=false
    panel.vType=nil
    panel.path="/"
  else
    panel.path = fs.getDir(panel.path)
    if panel.path=="" then panel.path="/" end
  end
  panel.selected=1; panel.scroll=0
  readDir(panel)
end

local function enter(panel)
  local e = panel.files[panel.selected]
  if not e then return end

  if e.name==".." then goUp(panel); return end

  if e.virtual then
    panel.virtualMode=true
    panel.vType=e.vType
    panel.pType=e.pType
    panel.selected=1; panel.scroll=0
    readDir(panel)
    return
  end

  if e.isDir then
    panel.path = fs.combine(panel.path,e.name)
    panel.selected=1; panel.scroll=0
    readDir(panel)
  end
end

local function viewItem()
  local p = active()
  local e = p.files[p.selected]
  if not e then return end

  local info = {
    "Name: "..e.name,
    "Type: "..(e.isDir and "Directory" or "File")
  }

  if e.virtual and e.vType=="peripheral_item" then
    local info = getPeripheralInfo(e.name)
    for _,line in ipairs(info) do table.insert(infoOut,line) end
  
  else
    table.insert(info,"Size: "..tostring(e.size or "-"))
    table.insert(info,"Date: "..tostring(e.date or "-"))
  end

  viewOverlay = info
end

-- ==================================================
-- Input
-- ==================================================
local function handleKey(k)
  local p = active()

  if viewOverlay or treeOverlay or helpOverlay then
    if k==keys.escape then viewOverlay=nil; treeOverlay=nil; helpOverlay=nil end
    return
  end

  if k==keys.tab then activePanel = activePanel==1 and 2 or 1
  elseif k==keys.v then p.viewMode = (p.viewMode=="list") and "detail" or "list"
  elseif k==keys.s then
    local nextSort = { name="type", type="size", size="date", date="name" }
    p.sortBy = nextSort[p.sortBy]
    readDir(p)
  elseif k==keys.r then p.sortAsc = not p.sortAsc; sortFiles(p)
  elseif k==keys.d then p.dirsFirst = not p.dirsFirst; sortFiles(p)
  elseif k==keysCfg.HELP then showHelp()()
  elseif k==keysCfg.EXPORT then
    local fname = "tc-export_"..os.date("%Y%m%d").."_"..string.gsub(p.path,"/","_")..".txt"
    local h = fs.open(fname,"w")
    if p.viewMode=="tree" then
      local tmp={}; buildTreeAscii(p.path,"",tmp,0); for _,l in ipairs(tmp) do h.writeLine(l) end
    else
      for _,e in ipairs(p.files) do h.writeLine(e.name) end
    end
    h.close(); message="Exported to "..fname
  elseif k==keysCfg.EDIT then
    local e = p.files[p.selected]
    if e and not e.isDir then
      term.clear(); shell.run("edit", fs.combine(p.path,e.name)); readDir(p)
    end
  elseif k==keysCfg.COPY then copyFile()
  elseif k==keysCfg.MOVE then moveFile()
  elseif k==keysCfg.DELETE then deleteFile()
  elseif k==keysCfg.TREE then showTreeFromSelected()()
  elseif k==keys.escape then goUp(p)
  elseif k==keys.up then p.selected=math.max(1,p.selected-1); if p.selected<=p.scroll then p.scroll=p.scroll-1 end
  elseif k==keys.down then p.selected=math.min(#p.files,p.selected+1); if p.selected>p.scroll+panelH then p.scroll=p.scroll+1 end
  elseif k==keys.home then p.selected=1; p.scroll=0
  elseif k==keys['end'] then p.selected=#p.files; p.scroll=math.max(0,#p.files-panelH)
  elseif k==keys.pageUp then p.selected=math.max(1,p.selected-panelH); p.scroll=math.max(0,p.scroll-panelH)
  elseif k==keys.pageDown then p.selected=math.min(#p.files,p.selected+panelH); p.scroll=math.min(math.max(0,#p.files-panelH),p.scroll+panelH)
  elseif k==keys.enter then enter(p)
  elseif k==keysCfg.VIEW then viewItem()()
  elseif k==keysCfg.QUIT then term.clear(); error("Exit") term.clear(); error("Exit") end
end

local function handlePointer(btn,x,y)
  for i=1,2 do
    local p=panels[i]
    if x>=p.x and x<p.x+panelW and y>=3 and y<3+panelH then
      activePanel=i
      local idx=y-2+p.scroll
      if p.files[idx] then
        p.selected=idx
        if btn==1 then enter(p) end
      end
    end
  end
end

-- ==================================================
-- Main
-- ==================================================
readDir(panels[1])
readDir(panels[2])
redraw()

while true do
  local e,a,b,c = os.pullEvent()
  if e=="key" then handleKey(a)
  elseif e=="mouse_click" then handlePointer(a,b,c)
  elseif e=="monitor_touch" then handlePointer(1,b,c) end
  redraw()
end
