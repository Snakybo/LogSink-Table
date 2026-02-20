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
local SCROLL_THROTTLE = 0.3

--- @type ColumnConfig[]
Window.columns = CopyTable(DEFAULTS)

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
end

--- @param key string
function Window:RemoveColumn(key)
	local contains, position = self:HasColumn(key)

	if contains then
		table.remove(self.columns, position)
	end
end

--- @param key string
--- @param position integer
function Window:ReorderColumn(key, position)
	local contains, originalPosition = self:HasColumn(key)

	if contains then
		local column = table.remove(self.columns, originalPosition)
		table.insert(self.columns, position, column)
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
end

--- @private
function Window:CreateWindow()
	self:CreateFrame()
	self:CreateContentContainer()

	self.filter = Addon.FilterFrame.Create(self.container)
	self.filter:SetPoint("TOPLEFT", self.container, "TOPLEFT")
	self.filter:SetPoint("BOTTOMRIGHT", self.container, "TOPRIGHT", 0, -20)
	self.filter.onQueryStringChanged = function(text)
		self:UpdateQueryString(text)
	end

	self.status = Addon.StatusFrame.Create(self.container)
	self.status:SetPoint("TOPLEFT", self.container, "BOTTOMLEFT", 0, 20)
	self.status:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT")
	self.status.onSearchButtonClick = function()
		self:LoadTableChunk(-1)

		if not self.table.scrollBar:HasScrollableExtent() and self.bufferReader:HasPreviousLogs() then
			self.status:ShowSearchButton(true)
		else
			self.status:ShowSearchButton(false)
		end
	end
	self.status.onLiveButtonClick = function()
		self:LoadTable()

		if not self.table.scrollBar:HasScrollableExtent() and self.bufferReader:HasPreviousLogs() then
			self.status:ShowSearchButton(true)
		else
			self.status:ShowSearchButton(false)
		end
	end

	self.table = Addon.TableFrame.Create(self.container)
	self.table:SetPoint("TOPLEFT", self.filter, "BOTTOMLEFT", 0, -10)
	self.table:SetPoint("BOTTOMRIGHT", self.status, "TOPRIGHT")
	self.table.onScroll = function(position, direction)
		if not self.initialized then
			return
		end

		if position < 1 and self.table.scrollBar:HasScrollableExtent() then
			self.bufferReader.tail = false
			self.status:ShowLiveButton(true)
		elseif position >= 1 and not self.bufferReader:HasNewLogs() then
			self.bufferReader.tail = true
			self.status:ShowLiveButton(false)
		end

		self.scrollDirection = direction
	end
	self.table.columns = self.columns
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
function Window:LoadTable()
	self.initialized = false
	self.table.dataProvider:Flush()

	if not self.hasFilterError then
		local chunk, scanned, elapsedMs = self.bufferReader:Load()
		self.status:SetTemporaryText(Addon.L["Processed %d entries and found %d matches in %.2fms"]:format(scanned, #chunk, elapsedMs))
		self.status:SetText("")

		self.lastScrollTime = GetTime()

		self.table.dataProvider:InsertTable(chunk)

		if not self.table.scrollBar:HasScrollableExtent() and self.bufferReader:HasPreviousLogs() then
			self.status:ShowSearchButton(true)
		else
			self.status:ShowSearchButton(false)
		end

		self.status:ShowLiveButton(false)
	end

	self.initialized = true
	self.scrollDirection = 0

	self.table.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
end

--- @private
--- @param direction integer
function Window:LoadTableChunk(direction)
	if self.hasFilterError then
		return
	end

	local chunk, scanned, elapsedMs

	if direction > 0 then
		chunk, scanned, elapsedMs = self.bufferReader:LoadNext()
		local index = self.table.dataProvider:GetSize()

		if #chunk > 0 then
			self.table.dataProvider:InsertTable(chunk)
			self.table.scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignEnd, 0, ScrollBoxConstants.NoScrollInterpolation)
		end
	else
		chunk, scanned, elapsedMs = self.bufferReader:LoadPrevious()

		if #chunk > 0 then
			self.table.dataProvider:InsertTable(chunk)
			self.table.scrollBox:ScrollToElementDataIndex(#chunk, ScrollBoxConstants.AlignBegin, 0, ScrollBoxConstants.NoScrollInterpolation)
		end
	end

	if chunk ~= nil and scanned ~= nil and elapsedMs ~= nil then
		if scanned > 0 then
			self.status:SetTemporaryText(Addon.L["Processed %d entries and found %d matches in %.2fms"]:format(scanned, #chunk, elapsedMs))
		elseif not self.bufferReader:HasPreviousLogs() then
			self.status:SetTemporaryText(Addon.L["No new entries"])
		end
	end
end

--- @private
--- @param text? string
function Window:UpdateQueryString(text)
	self.hasFilterError = false
	self.initialized = false

	if text ~= nil then
		local filter = LogSinkTable:CreateFilterFromString(text)

		if type(filter) == "string" then
			self.hasFilterError = true
			self.status:SetText("|cffff0000" .. Addon.L["Filter error: %s"]:format(filter))
		else
			self.bufferReader:SetFilter(filter)
		end
	else
		self.bufferReader:SetFilter(nil)
	end

	self:LoadTable()
end

--- @private
function Window:Frame_OnUpdate()
	local now = GetTime()

	if not self.initialized or self.hasFilterError then
		return
	end

	if self.bufferReader.tail and self.bufferReader:HasNewLogs() then
		local chunk = self.bufferReader:LoadNext()

		if #chunk > 0 then
			self.table.dataProvider:InsertTable(chunk)
			self.table.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
		end
	end

	if not self.bufferReader.tail and self.scrollDirection ~= 0 and now >= (self.lastScrollTime or 0) + SCROLL_THROTTLE then
		self:LoadTableChunk(self.scrollDirection)

		self.scrollDirection = 0
		self.lastScrollTime = now
	end
end

--- @private
function Window:Frame_CloseButton_OnClick()
	self.initialized = false

	self.bufferReader:Dispose()
	self.bufferReader = nil

	self.table.dataProvider:Flush()
	self.frame:Hide()
end

Addon.Window = Window
