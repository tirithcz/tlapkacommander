-- TLAPKA COMMANDER v. tc9
-- Dual Panel File Manager for CC: Tweaked
-- Norton / Midnight Commander style
-- Keyboard + Mouse + Advanced Monitor Touch support
-- CCTweaked - TirithCommander vers - 20251213_2350.lua
-- verze 20251213-2005 - repaired draw both left/right panels
--       20251213-2215 - switching view type with "v" key list/detail
--       20251213-2240 - přidání HOME/END, PAGE UP/DOWN a v do ovládání
--                       aktualizovaná nápověda    
--       tc10.lua - 20251214_0010 - virtual devices <EnderModem>, <ModemDevices>
--								  - added goBack in virtual directory from list of devices back to root of FS
--								  - added sorting by:  name, filetype, date, size
--								    system items - folders, virtual directories (devices) will be alwaysFirst

-- =====================
-- Configuration (resolution + colors)
-- =====================
local SCREEN_COLS, SCREEN_ROWS = term.getSize()

local COL_BG        = colors.black
local COL_PANEL     = colors.black
local COL_TEXT      = colors.lightGray
local COL_DIR       = colors.lightBlue
local COL_ACTIVE    = colors.blue
local COL_HEADER    = colors.gray
local COL_MENU_BG   = colors.blue
local COL_MENU_FG   = colors.white
local COL_STATUS_BG = colors.gray
local COL_STATUS_FG = colors.black
local COL_DIALOG_BG = colors.gray
local COL_DIALOG_FG = colors.black

-- =====================
-- Layout
-- =====================
local termW, termH = SCREEN_COLS, SCREEN_ROWS
local panelW = math.floor(termW / 2)
local panelH = termH - 4

-- =====================
-- State
-- =====================
local panels = {
	{ x = 1,           path = "/", files = {}, selected = 1, scroll = 0, virtualMode = false },
	{ x = panelW + 1,  path = "/", files = {}, selected = 1, scroll = 0, virtualMode = false }
}

local activePanel = 1
local message = "Ready"
local viewMode = "list" -- list / detail

-- =====================
-- Utilities
-- =====================
local function active()   return panels[activePanel] end
local function inactive() return panels[activePanel == 1 and 2 or 1] end

-- =====================
-- Read Directory / Virtual Folders
-- =====================
local function readDir(panel)
	local list = {}

	if panel.path ~= "/" then
		table.insert(list, { name = "..", isDir = true })
	else
		-- virtuĂˇlnĂ­ adresĂˇ?e pouze v root
		table.insert(list, { name = "<EnderModem devices>", isDir = true, virtual = true, type = "endermodem" })
		table.insert(list, { name = "<ModemDevices>", isDir = true, virtual = true, type = "modem" })
	end

	if not panel.virtualMode then
		for _, f in ipairs(fs.list(panel.path)) do
			table.insert(list, {
				name = f,
				isDir = fs.isDir(fs.combine(panel.path, f))
			})
		end
	end

	table.sort(list, function(a,b)
		if a.isDir ~= b.isDir then return a.isDir end
		return a.name:lower() < b.name:lower()
	end)

	panel.files = list
end

-- =====================
-- Dialogs
-- =====================
local function confirm(text)
	local w, h = 30, 5
	local x = math.floor((termW - w) / 2)
	local y = math.floor((termH - h) / 2)

	term.setBackgroundColor(COL_DIALOG_BG)
	term.setTextColor(COL_DIALOG_FG)

	for i = 0, h do
		term.setCursorPos(x, y + i)
		term.write(string.rep(" ", SCREEN_COLS))
	end

	term.setCursorPos(x + 2, y + 1)
	term.write(text)
	term.setCursorPos(x + 2, y + 3)
	term.write("Y = Yes   N = No")

	while true do
		local _, k = os.pullEvent("key")
		if k == keys.y then return true end
		if k == keys.n or k == keys.escape then return false end
	end
end

local function showHelp()
	local lines = {
		"Tirith Commander",
		"=======================================",
		"TAB        - Switch panel",
		"UP/DN      - Move cursor",
		"HOME/END   - Jump to first/last item",
		"PAGE UP/DN - Jump visible panel height",
		"ENTER      - Open / Run",
		"F3         - View",
		"F4 / 4     - Edit",
		"v          - Toggle List / Detail view",
		"F5         - Copy",
		"F6         - Move",
		"F7         - New directory",
		"F8         - Delete",
		"F10        - Quit",
		"",
		"Mouse / Touch:",
		"Click/Touch - Select & Open",
		"",
		"Press any key..."
	}

	local w = 50
	local h = #lines + 2
	local x = math.floor((termW - w) / 2)
	local y = math.floor((termH - h) / 2)

	term.setBackgroundColor(COL_DIALOG_BG)
	term.setTextColor(COL_DIALOG_FG)

	for i = 0, h do
		term.setCursorPos(x, y + i)
		term.write(string.rep(" ", SCREEN_COLS))
	end

	for i, l in ipairs(lines) do
		term.setCursorPos(x + 2, y + i)
		term.write(l)
	end

	os.pullEvent("key")
end

-- =====================
-- Drawing
-- =====================
local function drawMenu()
	term.setBackgroundColor(COL_MENU_BG)
	term.setTextColor(COL_MENU_FG)
	term.setCursorPos(1, 1)
	term.write(string.rep(" ", SCREEN_COLS))
	term.setCursorPos(1, 1)
	term.write(" F3 View  F4 Edit  F5 Copy  F6 Move  F7 MkDir  F8 Delete  F10 Quit ")
end

local function drawPanels()
	for p = 1, 2 do
		local panel = panels[p]
		local isActive = (p == activePanel)

		term.setCursorPos(panel.x, 2)
		term.setBackgroundColor(COL_HEADER)
		term.setTextColor(colors.black)
		term.write(string.sub(panel.path .. string.rep(" ", panelW), 1, panelW))

		for i = 1, panelH do
			local idx = i + panel.scroll
			term.setCursorPos(panel.x, i + 2)

			if idx == panel.selected and isActive then
				term.setBackgroundColor(COL_ACTIVE)
				term.setTextColor(colors.white)
			else
				term.setBackgroundColor(COL_PANEL)
				term.setTextColor(COL_TEXT)
			end

			term.write(string.rep(" ", SCREEN_COLS))
			term.setCursorPos(panel.x, i + 2)

			local e = panel.files[idx]
			if e then
				if e.isDir then term.setTextColor(COL_DIR) end

				if viewMode == "list" then
					term.write(string.sub(e.name, 1, panelW))
				
				else -- type_view detail start
					local info = e.name
					if not e.virtual then
						local full = fs.combine(panel.path, e.name)
						local typ = e.isDir and "<DIR>" or "<FILE>"
						local size = e.isDir and "-" or tostring(fs.getSize(full))
						local date = fs.getLastModified and tostring(fs.getLastModified(full)) or "-"
						info = string.format("%-20s %-6s %-8s %s", e.name, typ, size, date)
					else
						local typ = e.type or "device"
						info = string.format("%-20s %-10s", e.name, typ)
					end
					term.write(string.sub(info, 1, panelW))
				end -- end type_view detail
			end
		end
	end
end

local function drawStatus()
	term.setCursorPos(1, termH)
	term.setBackgroundColor(COL_STATUS_BG)
	term.setTextColor(COL_STATUS_FG)
	term.write(string.rep(" ", SCREEN_COLS))
	term.setCursorPos(1, termH)
	term.write(message)
end

local function redraw()
	term.setBackgroundColor(COL_BG)
	term.write(string.rep(" ", SCREEN_COLS))
	term.clear()
	drawMenu()
	drawPanels()
	drawStatus()
end

-- =====================
-- File operations
-- =====================
local function openEntry(panel)
	local e = panel.files[panel.selected]
	if not e then return end

	if panel.virtualMode and e.name == ".." then
		panel.virtualMode = false
		panel.path = "/"
		readDir(panel)
		panel.selected = 1
		panel.scroll = 0
		return
	end

	if e.virtual then
		panel.virtualMode = true
		panel.selected = 1
		panel.scroll = 0
		panel.files = {}

		if e.type == "endermodem" then
			local devices = endermodem and endermodem.list() or {}
			for _, d in ipairs(devices) do
				table.insert(panel.files, { name = d, isDir = false })
			end
		elseif e.type == "modem" then
			local devices = peripheral.getNames() or {}
			for _, d in ipairs(devices) do
				table.insert(panel.files, { name = d, isDir = false })
			end
		end
		return
	end

	if e.name == ".." then
		panel.path = fs.getDir(panel.path)
		if panel.path == "" then panel.path = "/" end
		panel.selected = 1
		panel.scroll = 0
		readDir(panel)
		return
	end

	local full = fs.combine(panel.path, e.name)
	if e.isDir then
		panel.path = full
		panel.selected = 1
		panel.scroll = 0
		readDir(panel)
	else
		term.clear()
		term.setCursorPos(1,1)
		shell.run(full)
		redraw()
	end
end

local function editEntry()
	local p = active()
	local e = p.files[p.selected]
	if not e or e.isDir or e.name == ".." then return end
	local full = fs.combine(p.path, e.name)
	term.clear()
	term.setCursorPos(1,1)
	shell.run("edit", full)
	redraw()
end

local function copyOrMove(move)
	local srcP = active()
	local dstP = inactive()
	local e = srcP.files[srcP.selected]
	if not e or e.name == ".." then return end
	if not confirm((move and "Move " or "Copy ") .. e.name .. " ?") then return end
	local src = fs.combine(srcP.path, e.name)
	local dst = fs.combine(dstP.path, e.name)
	if move then fs.move(src, dst) else fs.copy(src, dst) end
	readDir(srcP)
	readDir(dstP)
	message = (move and "Moved " or "Copied ") .. e.name
end

local function deleteEntry()
	local p = active()
	local e = p.files[p.selected]
	if not e or e.name == ".." then return end
	if confirm("Delete " .. e.name .. " ?") then
		fs.delete(fs.combine(p.path, e.name))
		readDir(p)
		message = "Deleted " .. e.name
	end
end

local function makeDir()
	term.setCursorPos(1, termH)
	term.setBackgroundColor(COL_STATUS_BG)
	term.setTextColor(COL_STATUS_FG)
	term.write(string.rep(" ", SCREEN_COLS))
	term.setCursorPos(1, termH)
	term.write("New directory: ")
	local name = read()
	if name and name ~= "" then
		fs.makeDir(fs.combine(active().path, name))
		readDir(active())
		message = "Directory created"
	end
end

-- =====================
-- Input handling
-- =====================
local function handleKey(k)
	local p = active()

	if k == keys.tab then
		activePanel = (activePanel == 1) and 2 or 1
	elseif k == keys.up then
		p.selected = math.max(1, p.selected - 1)
		if p.selected <= p.scroll then p.scroll = math.max(0, p.scroll - 1) end
	elseif k == keys.down then
		p.selected = math.min(#p.files, p.selected + 1)
		if p.selected > p.scroll + panelH then p.scroll = p.scroll + 1 end
	elseif k == keys.home then
		p.selected = 1
		p.scroll = 0
	elseif k == keys['end'] then
		p.selected = #p.files
		p.scroll = math.max(0, #p.files - panelH)
	elseif k == keys.pageUp then
		p.selected = math.max(1, p.selected - panelH)
		p.scroll = math.max(0, p.scroll - panelH)
	elseif k == keys.pageDown then
		p.selected = math.min(#p.files, p.selected + panelH)
		p.scroll = math.min(math.max(0, #p.files - panelH), p.scroll + panelH)
	elseif k == keys.enter then
		openEntry(p)
	elseif k == keys.f4 or k == keys.four then
		editEntry()
	elseif k == keys.f5 then
		copyOrMove(false)
	elseif k == keys.f6 then
		copyOrMove(true)
	elseif k == keys.f7 then
		makeDir()
	elseif k == keys.f8 then
		deleteEntry()
	elseif k == keys.f10 then
		term.clear()
		error("Exit")
	elseif k == keys.v then
		viewMode = (viewMode == "list") and "detail" or "list"
	end
end

local function handlePointer(btn, x, y)
	for i = 1, 2 do
		local panel = panels[i]
		if x >= panel.x and x < panel.x + panelW and y >= 3 and y < 3 + panelH then
			activePanel = i
			local idx = y - 2 + panel.scroll
			if panel.files[idx] then
				panel.selected = idx
				if btn == 1 then openEntry(panel) end
			end
		end
	end
end

-- =====================
-- Main
-- =====================
panels[1].path = "/"
panels[2].path = "/"
readDir(panels[1])
readDir(panels[2])
showHelp()
redraw()

while true do
	local e, a, b, c = os.pullEvent()
	if e == "key" then
		handleKey(a)
	elseif e == "mouse_click" then
		handlePointer(a, b, c)
	elseif e == "monitor_touch" then
		handlePointer(1, b, c)
	end
	redraw()
end
