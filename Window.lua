--- @class LogTable
--- @field public columns LogTableColumn[]
--- @field public rows LogTableRow[]

--- @class LogTableColumn
--- @field public width integer

--- @class LogTableRow
--- @field public cells LogTableCell[]
--- @field public color colorRGBA
--- @field public onEnter fun()
--- @field public onLeave fun()
--- @field public onClick fun()

--- @class LogTableCell
--- @field public text string

--- @class ColumnConfig
--- @field public name string
--- @field public key string
--- @field public get? fun(entry: LibLog-1.0.LogMessage): unknown
--- @field public custom? boolean
--- @field public width? integer

--- @class TableCellFrame : Frame
--- @field public Text FontString

--- @class TableRowFrame : Frame
--- @field public cells TableCellFrame[]
--- @field public Highlight Texture

local LibLog = LibStub("LibLog-1.0")

--- @class Addon
local Addon = select(2, ...)

--- @class Window
local Window = {}

--- @type ColumnConfig[]
local DEFAULTS = {
	{
		name = Addon.L["Time"],
		key = "time",
		--- @param entry LibLog-1.0.LogMessage
		get = function(entry)
			return date("%H:%M:%S", entry.time)
		end,
		width = 75
	},
	{
		name = Addon.L["Level"],
		key = "level",
		--- @param entry LibLog-1.0.LogMessage
		get = function(entry)
			return LibLog.labels[entry.level]
		end,
		width = 50
	},
	{
		name = Addon.L["Addon"],
		key = "addon",
		width = 125
	},
	{
		name = Addon.L["Message"],
		key = "message"
	}
}

local COLUMN_MIN_WIDTH = 50
local ROW_HEIGHT = 22
local SCROLL_THROTTLE = 0.3

--- @type ColumnConfig[]
Window.columns = CopyTable(DEFAULTS)

--- @private
--- @param text? string
function Window:UpdateQueryString(text)
	if text ~= nil then
		local filter = LogSinkTable:CreateFilterFromString(text)
		if type(filter) == "string" then
			-- TODO: show error message
			error(filter)
			return
		end

		self.bufferReader:SetFilter(filter)
	else
		self.bufferReader:SetFilter(nil)
	end

	local chunk, scanned = self.bufferReader:Load()
	-- TODO: show scanned + found message

	self.dataProvider:Flush()
	self.dataProvider:InsertTable(chunk)

	self.initialized = true
	self.wantsScroll = 0

	self.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
end

function Window:CreateWindow()
	self:CreateFrame()
	self:CreateContentContainer()

	self.filter = Addon.FilterFrame.Create(self.container)
	self.filter.onQueryStringChanged = function(text)
		self:UpdateQueryString(text)
	end

	self:CreateScrollBox()
end

function Window:ShowDefaultStatus()

end

function Window:ShowScrollStatus(scanned, found)

end

function Window:Open()
	if self:IsOpen() then
		return
	end

	if self.frame == nil then
		self:CreateWindow()
	end

	self.bufferReader = LogSinkTable:CreateChunkedBufferReader()
	self.bufferReader.onBufferSet = function()
		self:UpdateQueryString(LogSinkTableDB.currentFilter)
	end

	self:UpdateQueryString(LogSinkTableDB.currentFilter)
	self.frame:Show()
end

function Window:IsOpen()
	return self.frame ~= nil and self.frame:IsVisible()
end

function Window:RenderTable()
	if not self:IsOpen() then
		return
	end

end

--- @param key string
function Window:AddColumn(key)
	if self:HasColumn(key) then
		return
	end

	--- @type ColumnConfig
	local column

	for _, v in ipairs(DEFAULTS) do
		if key == v.key then
			column = CopyTable(v)
		end
	end

	column = column or {
		name = key,
		key = key,
		custom = true
	}

	table.insert(self.columns, column)

	self:RenderTable()
end

--- @param key string
function Window:RemoveColumn(key)
	local contains, position = self:HasColumn(key)

	if contains then
		table.remove(self.columns, position)

		self:RenderTable()
	end
end

--- @param key string
--- @param position integer
function Window:ReorderColumn(key, position)
	local contains, originalPosition = self:HasColumn(key)

	if contains then
		local column = table.remove(self.columns, originalPosition)
		table.insert(self.columns, position, column)

		self:RenderTable()
	end
end

--- @param key string
--- @return boolean contains
--- @return integer? position
function Window:HasColumn(key)
	for i = 1, #self.columns do
		if key == self.columns[i].key then
			return true, i
		end
	end

	return false
end

function Window:ResetColumns()
	self.columns = CopyTable(DEFAULTS)

	self:RenderTable()
end

--- @private
function Window:CreateFrame()
	self.frame = CreateFrame("Frame", "LogSinkTableFrame", UIParent, "DefaultPanelFlatTemplate")
	self.frame:SetSize(800, 500)
	self.frame:SetPoint("CENTER")
	self.frame:SetFrameStrata("HIGH")
	self.frame:SetMovable(true)
	self.frame:SetResizable(true)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:EnableMouse(true)
	self.frame:SetScript("OnDragStart", self.frame.StartMoving)
	self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
	self.frame:SetResizeBounds(400, 300)
	self.frame:HookScript("OnUpdate", function() self:Frame_OnUpdate() end)

	self.frame.CloseButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButtonDefaultAnchors")
	self.frame.CloseButton:SetScript("OnClick", function() self:Frame_CloseButton_OnClick() end)

	self.frame.TitleContainer.TitleText:SetText(Addon.L["Log Viewer"])

	self:CreateFrameResizers()
end

--- @private
function Window:CreateFrameResizers()
	local function SE_OnMouseDown()
		self.frame:StartSizing("BOTTOMRIGHT")
	end

	local function S_OnMouseDown()
		self.frame:StartSizing("BOTTOM")
	end

	local function E_OnMouseDown()
		self.frame:StartSizing("RIGHT")
	end

	local function OnMouseUp()
		self.frame:StopMovingOrSizing()
	end

	local se = CreateFrame("Frame", nil, self.frame)
	se:SetPoint("BOTTOMRIGHT")
	se:SetWidth(25)
	se:SetHeight(25)
	se:EnableMouse()
	se:SetScript("OnMouseDown", SE_OnMouseDown)
	se:SetScript("OnMouseUp",OnMouseUp)

	local s = CreateFrame("Frame", nil, self.frame)
	s:SetPoint("BOTTOMRIGHT", -25, 0)
	s:SetPoint("BOTTOMLEFT")
	s:SetHeight(25)
	s:EnableMouse(true)
	s:SetScript("OnMouseDown", S_OnMouseDown)
	s:SetScript("OnMouseUp",OnMouseUp)

	local e = CreateFrame("Frame", nil, self.frame)
	e:SetPoint("BOTTOMRIGHT", 0, 25)
	e:SetPoint("TOPRIGHT")
	e:SetWidth(25)
	e:EnableMouse(true)
	e:SetScript("OnMouseDown", E_OnMouseDown)
	e:SetScript("OnMouseUp",OnMouseUp)
end

--- @private
function Window:CreateContentContainer()
	local INSET_LEFT = 12
	local INSET_RIGHT = -7
	local INSET_TOP = -27
	local INSET_BOTTOM = 8

	self.container = CreateFrame("Frame", nil, self.frame)
	self.container:SetPoint("TOPLEFT", self.frame, "TOPLEFT", INSET_LEFT, INSET_TOP)
	self.container:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
end

--- @private
function Window:CreateScrollBox()
	self.scrollBar = CreateFrame("EventFrame", nil, self.container, "MinimalScrollBar")
    self.scrollBar:SetPoint("TOPRIGHT", self.filter, "BOTTOMRIGHT", -10, -10)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -10, 10)

	self.scrollBox = CreateFrame("Frame", nil, self.container, "WowScrollBoxList")
    self.scrollBox:SetPoint("TOPLEFT", self.filter, "BOTTOMLEFT", 0, -10)
    self.scrollBox:SetPoint("BOTTOMRIGHT", self.scrollBar, "BOTTOMLEFT", -10, 0)
	self.scrollBox:RegisterCallback("OnScroll", function(...) self:ScrollBox_OnScroll(...) end)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("LogTableRowTemplate", function(button, data)
		self:CreateScrollBoxRow(button, data)
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)

	self.dataProvider = CreateDataProvider()
	self.dataProvider:SetSortComparator(function(l, r)
		if l.time == r.time then
			return l.sequenceId < r.sequenceId
		end

		return l.time < r.time
	end, true)

    self.scrollBox:SetDataProvider(self.dataProvider)
end

--- @private
--- @param frame TableRowFrame
--- @param logEntry LibLog-1.0.LogMessage
function Window:CreateScrollBoxRow(frame, logEntry)
	local cells = frame.cells

	for i, colConfig in ipairs(self.columns) do
		if not cells[i] then
			cells[i] = CreateFrame("Frame", nil, frame, "LogTableCellTemplate")
		end

		local cell = cells[i]
		cell:Show()

		if i == 1 then
			cell:SetPoint("LEFT", frame, "LEFT", 0, 0)
		else
			cell:SetPoint("LEFT", frame.cells[i - 1], "RIGHT", 0, 0)
		end

		if i < #self.columns then
			cell:SetWidth(colConfig.width or 100)
		else
			cell:SetPoint("RIGHT", frame:GetParent(), "RIGHT")
		end

		local value = colConfig.get and colConfig.get(logEntry) or logEntry[colConfig.key]
		cell.Text:SetText(tostring(value or ""))
	end

	for i = #self.columns + 1, #frame.cells do
		frame.cells[i]:Hide()
	end

	frame:SetScript("OnEnter", function() frame.Highlight:Show() end)
	frame:SetScript("OnLeave", function() frame.Highlight:Hide() end)

	frame:SetScript("OnClick", function()
		UIParentLoadAddOn("Blizzard_DebugTools")
		DisplayTableInspectorWindow(logEntry)
	end)
end

--- @private
function Window:Frame_OnUpdate()
	local now = GetTime()

	if self.bufferReader:HasNewLogs() then
		local chunk = self.bufferReader:LoadNext()

		self.dataProvider:InsertTable(chunk)
		self.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
	end

	if self.wantsScroll ~= 0 and now >= (self.lastScrollTime or 0) + SCROLL_THROTTLE then
		if self.wantsScroll > 0 then
			local chunk, scanned = self.bufferReader:LoadNext()
			local index = self.dataProvider:GetSize()

			if #chunk > 0 then
				self.dataProvider:InsertTable(chunk)
				self.scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignEnd, 0, ScrollBoxConstants.NoScrollInterpolation)
			end
		elseif self.wantsScroll < 0 then
			local chunk, scanned = self.bufferReader:LoadPrevious()

			if #chunk > 0 then
				self.dataProvider:InsertTable(chunk)
				self.scrollBox:ScrollToElementDataIndex(#chunk, ScrollBoxConstants.AlignBegin, 0, ScrollBoxConstants.NoScrollInterpolation)
			end
		end

		self.wantsScroll = 0
		self.lastScrollTime = now
	end
end

--- @private
function Window:Frame_CloseButton_OnClick()
	self.initialized = false

	self.bufferReader:Dispose()
	self.bufferReader = nil

	self.dataProvider:Flush()
	self.frame:Hide()
end

--- @private
--- @param scrollPercentage number
function Window:ScrollBox_OnScroll(_, scrollPercentage)
	local now = GetTime()

	if not self.initialized then
		return
	end

	if scrollPercentage < 1 then
		self.bufferReader.tail = false
	end

	self.wantsScroll = scrollPercentage <= 0 and -1 or scrollPercentage >= 1 and 1 or 0
end

Addon.Window = Window
