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
--- @field public key string
--- @field public width? integer

--- @class ColumnVisualizer
--- @field public name string
--- @field public get? fun(entry: LibLog-1.0.LogMessage): unknown

local LibLog = LibStub("LibLog-1.0")

--- @class Addon
local Addon = select(2, ...)

--- @class TableFrame
--- @field private autoScrollTarget? LibLog-1.0.LogMessage
local TableFrame = {}
TableFrame.UI = {}
TableFrame.DEFAULT_COLUMN_WIDTH = 100

--- @type ColumnConfig[]
local COLUMN_DEFAULTS = {
	{
		key = "time",
		width = 60
	},
	{
		key = "level",
		width = 50
	},
	{
		key = "addon",
		width = 125
	},
	{
		key = "message",
		width = 200
	}
}

local COLUMN_VISUALIZERS = {
	["time"] = {
		name = Addon.L["Time"],
		--- @param entry LibLog-1.0.LogMessage
		get = function(entry)
			return date("%H:%M:%S", entry.time)
		end
	},
	["level"] = {
		name = Addon.L["Level"],
		--- @param entry LibLog-1.0.LogMessage
		get = function(entry)
			return LibLog.labels[entry.level]
		end
	},
	["addon"] = {
		name = Addon.L["Addon"]
	},
	["message"] = {
		name = Addon.L["Message"]
	}
}

local SCROLL_THROTTLE = 0.3

--- @type ColumnConfig[]
TableFrame.columns = CopyTable(COLUMN_DEFAULTS)

function TableFrame:Open()
	if self:IsOpen() then
		return
	end

	if self.frame == nil then
		self:CreateWindow()
	end

	self.bufferReader = LogSinkTable:CreateChunkedBufferReader()
	self.bufferReader.onBufferSet = function() self:BufferReader_OnBufferSet() end
	self.bufferReader.onMessageAdded = function() self:BufferReader_OnMessageAdded() end

	self:UpdateQueryString(LogSinkTableDB.currentFilter)
	self.frame:Show()
end

function TableFrame:IsOpen()
	return self.frame ~= nil and self.frame:IsVisible()
end

--- @param data LibLog-1.0.LogMessage
function TableFrame:AutoScrollTo(data)
	if self.table.scrollBox:ScrollToElementData(data, ScrollBoxConstants.AlignNearest, 0, ScrollBoxConstants.NoScrollInterpolation) ~= nil then
		LogSinkTable:LogVerbose("Found entry in dataset, auto-scrolling")

		self.autoScrollTarget = nil
		return
	end

	LogSinkTable:LogVerbose("Did not find entry in dataset, enabling auto-scroll")
	self.autoScrollTarget = data
end

function TableFrame:IsAutoScrolling()
	return self.autoScrollTarget ~= nil
end

--- @param key string
--- @param after? integer
function TableFrame:AddColumn(key, after)
	if self:HasColumn(key) then
		return
	end

	if after ~= nil then
		after = after + 1
	else
		after = #self.columns
	end

	--- @type ColumnConfig
	local column

	for _, v in ipairs(COLUMN_DEFAULTS) do
		if key == v.key then
			column = CopyTable(v)
		end
	end

	column = column or {
		name = key,
		key = key,
		width = TableFrame.DEFAULT_COLUMN_WIDTH
	}

	table.insert(self.columns, after, column)

	self.header:UpdateColumns()
	self.table:UpdateColumns()
end

--- @param key string
function TableFrame:RemoveColumn(key)
	local contains, position = self:HasColumn(key)

	if contains then
		table.remove(self.columns, position)

		self.header:UpdateColumns()
		self.table:UpdateColumns()
	end
end

--- @param key string
--- @param position integer
function TableFrame:ReorderColumn(key, position)
	local contains, originalPosition = self:HasColumn(key)

	if contains then
		local column = table.remove(self.columns, originalPosition)
		table.insert(self.columns, position, column)

		self.header:UpdateColumns()
		self.table:UpdateColumns()
	end
end

--- @param key string
--- @return boolean contains
--- @return integer? position
function TableFrame:HasColumn(key)
	for i = 1, #self.columns do
		if key == self.columns[i].key then
			return true, i
		end
	end

	return false
end

function TableFrame:ResetColumns()
	wipe(self.columns)

	for _, v in ipairs(COLUMN_DEFAULTS) do
		table.insert(self.columns, v)
	end

	self.header:UpdateColumns()
	self.table:UpdateColumns()
end

--- @param text string
function TableFrame:AppendQueryString(text)
	local fullText = self.filter:GetText()
	local tokens = Addon.QueryParser:Tokenize(fullText)

	for _, token in ipairs(tokens) do
		if token.type == Addon.TokenType.Property then
			text = "AND " .. text
			break
		end
	end

	if #tokens > 0 and tokens[#tokens].type ~= Addon.TokenType.Whitespace then
		text = " " .. text
	end

	self.filter:SetText(fullText .. text)
end

--- @param key string
--- @return ColumnVisualizer?
function TableFrame:GetColumnVisualizer(key)
	return COLUMN_VISUALIZERS[key]
end

--- @private
function TableFrame:CreateWindow()
	if LogSinkTableDB.columns ~= nil then
		self.columns = LogSinkTableDB.columns
	else
		LogSinkTableDB.columns = self.columns
	end

	self:CreateFrame()
	self:CreateContentContainer()

	self.filter = TableFrame.UI.Filter.Create(self.container)
	self.filter:SetPoint("TOPLEFT", self.container, "TOPLEFT")
	self.filter:SetPoint("BOTTOMRIGHT", self.container, "TOPRIGHT", 0, -20)
	self.filter.onQueryStringChanged = function(...) self:Filter_OnQueryStringChanged(...) end

	self.header = TableFrame.UI.Header.Create(self.container, self.columns)
	self.header:SetPoint("TOPLEFT", self.filter, "BOTTOMLEFT", 0, -10)
	self.header:SetPoint("TOPRIGHT", self.filter, "BOTTOMRIGHT", 0, -10)
	self.header:SetHeight(24)
	self.header.onColumnResized = function(...) self:Header_OnColumnsResized(...) end

	self.status = TableFrame.UI.Status.Create(self.container)
	self.status:SetPoint("TOPLEFT", self.container, "BOTTOMLEFT", 0, 20)
	self.status:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT")
	self.status.onLiveButtonClick = function() self:Status_OnLiveButtonClick() end

	self.table = TableFrame.UI.Table.Create(self.container, self.columns)
	self.table:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, 0)
	self.table:SetPoint("BOTTOMRIGHT", self.status, "TOPRIGHT")
	self.table.onScroll = function(...) self:Table_OnScroll(...) end
	self.table.onClick = function() self:Table_OnClick() end
end

--- @private
function TableFrame:CreateFrame()
	self.frame = CreateFrame("Frame", "LogSinkTableFrame", UIParent, "DefaultPanelFlatTemplate")
	self.frame:SetSize(800, 500)
	self.frame:SetPoint("CENTER")
	self.frame:SetFrameStrata("HIGH")
	self.frame:SetMovable(true)
	self.frame:SetResizable(true)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:EnableMouse(true)
	self.frame:SetResizeBounds(400, 300)
	self.frame:SetScript("OnDragStart", self.frame.StartMoving)
	self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
	self.frame:SetScript("OnUpdate", function() self:Frame_OnUpdate() end)

	self.frame.CloseButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButtonDefaultAnchors")
	self.frame.CloseButton:SetScript("OnClick", function() self:Frame_CloseButton_OnClick() end)

	self.frame.TitleContainer.TitleText:SetText(Addon.L["Log Viewer"])

	self:CreateFrameResizers()
end

--- @private
function TableFrame:CreateFrameResizers()
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
function TableFrame:CreateContentContainer()
	local INSET_LEFT = 12
	local INSET_RIGHT = -10
	local INSET_TOP = -27
	local INSET_BOTTOM = 8

	self.container = CreateFrame("Frame", nil, self.frame)
	self.container:SetPoint("TOPLEFT", self.frame, "TOPLEFT", INSET_LEFT, INSET_TOP)
	self.container:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
end

--- @private
function TableFrame:UpdateSearchButtonVisibility()
	local visible = not self.table.scrollBar:HasScrollableExtent() and self.bufferReader:HasPreviousLogs() and not self.hasFilterError

	if visible and not self.searchButtonVisible then
		self.table.dataProvider:Insert({
			isHeader = true
		})
	elseif not visible and self.searchButtonVisible then
		self.table.dataProvider:RemoveByPredicate(function(element)
			return element.isHeader
		end)
	end

	self.searchButtonVisible = visible
end

--- @private
function TableFrame:UpdateTailButtonVisibility()
	self.status:ShowLiveButton(not self.tail and not self.hasFilterError)
end

--- @private
function TableFrame:InitializeTable()
	if self.isMidUpdate then
		return
	end

	self.isMidUpdate = true
	self.table.dataProvider:Flush()

	if not self.hasFilterError then
		local chunk, scanned, elapsedMs = self.bufferReader:Load()
		self.status:SetTemporaryText(Addon.L["Processed %d entries and found %d matches in %.2fms"]:format(scanned, #chunk, elapsedMs))
		self.status:SetText(Addon.L["Processed %d out of %d entries"]:format(self.bufferReader:GetNumProcessed()))
		self.lastScrollTime = GetTime()
		self.tail = true
		self.searchButtonVisible = false
		self.hasMessagesPending = false
		self.autoScrollTarget = nil
		self.table.dataProvider:InsertTable(chunk)
	end

	self:UpdateTailButtonVisibility()
	self:UpdateSearchButtonVisibility()

	self.table.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
	self.isMidUpdate = false
end

--- @private
--- @param direction integer
function TableFrame:LoadTableChunk(direction)
	if self.isMidUpdate then
		return
	end

	self.isMidUpdate = true

	if not self.hasFilterError then
		local chunk, scanned, elapsedMs
		local fromTail = self.tail and direction > 0

		if direction > 0 then
			chunk, scanned, elapsedMs = self.bufferReader:LoadNext()
			local index = self.table.dataProvider:GetSize()

			self.tail = not self.bufferReader:HasNextLogs()

			if #chunk > 0 then
				self.table.dataProvider:InsertTable(chunk)

				if self.tail then
					self.table.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
				else
					self.table.scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignEnd, 0, ScrollBoxConstants.NoScrollInterpolation)
				end
			end

		else
			chunk, scanned, elapsedMs = self.bufferReader:LoadPrevious()

			self.tail = false

			if #chunk > 0 then
				self.table.dataProvider:InsertTable(chunk)
				self.table.scrollBox:ScrollToElementDataIndex(#chunk, ScrollBoxConstants.AlignBegin, 0, ScrollBoxConstants.NoScrollInterpolation)
			end
		end

		if not fromTail and chunk ~= nil and scanned ~= nil and elapsedMs ~= nil then
			self.status:SetTemporaryText(Addon.L["Processed %d entries and found %d matches in %.2fms"]:format(scanned, #chunk, elapsedMs))
			self.status:SetText(Addon.L["Processed %d out of %d entries"]:format(self.bufferReader:GetNumProcessed()))
		end
	end

	self:UpdateTailButtonVisibility()
	self:UpdateSearchButtonVisibility()

	self.isMidUpdate = false
end

--- @private
--- @param text? string
function TableFrame:UpdateQueryString(text)
	self.hasFilterError = false

	if text ~= nil then
		local filter = LogSinkTable:CreateFilterFromString(text)

		if type(filter) == "string" then
			self.hasFilterError = true
			self.status:SetText("|cffff0000" .. Addon.L["Filter error: %s"]:format(filter))
		else
			self.bufferReader:SetFilter(filter)
			self.status:SetText("")
		end
	else
		self.bufferReader:SetFilter(nil)
		self.status:SetText("")
	end

	self:InitializeTable()
end

--- @private
function TableFrame:BufferReader_OnBufferSet()
	self:UpdateQueryString(LogSinkTableDB.currentFilter)
end

--- @private
function TableFrame:BufferReader_OnMessageAdded()
	if self.tail then
		self.hasMessagesPending = true
	end

	self.status:SetText(Addon.L["Processed %d out of %d entries"]:format(self.bufferReader:GetNumProcessed()))
end

--- @private
function TableFrame:Frame_OnUpdate()
	if self:IsAutoScrolling() then
		self.hasMessagesPending = false
		self.wantsScroll = 0

		local target = self.autoScrollTarget --[[@as LibLog-1.0.LogMessage]]
		local first = self.table.dataProvider:Find(1)
		local last = self.table.dataProvider:Find(self.table.dataProvider:GetSize())

		local firstNil = first == nil or first.isHeader
		local lastNil = last == nil or last.isHeader

		if firstNil or target.time < first.time or (target.time == first.time and target.sequenceId < first.sequenceId) then
			if not self.bufferReader:HasPreviousLogs() then
				LogSinkTable:LogVerbose("No previous logs found, cancelling auto-scroll")

				self.autoScrollTarget = nil
			else
				LogSinkTable:LogVerbose("Auto-scrolling to previous page")

				self:LoadTableChunk(-1)
				self:AutoScrollTo(target)
			end
		elseif lastNil or target.time > last.time or (target.time == last.time and target.sequenceId > last.sequenceId) then
			if not self.bufferReader:HasNextLogs() then
				LogSinkTable:LogVerbose("No next logs found, cancelling auto-scroll")

				self.autoScrollTarget = nil
			else
				LogSinkTable:LogVerbose("Auto-scrolling to next page")

				self:LoadTableChunk(1)
				self:AutoScrollTo(target)
			end
		else
			LogSinkTable:LogVerbose("No match found, cancelling auto-scroll")

			self.autoScrollTarget = nil
		end
	end

	if self.hasMessagesPending then
		self:LoadTableChunk(1)
		self.hasMessagesPending = false
	end

	if self.wantsScroll ~= 0 then
		local now = GetTime()

		if now >= (self.lastScrollTime or 0) + SCROLL_THROTTLE then
			self:LoadTableChunk(self.wantsScroll)
			self.lastScrollTime = now
		end

		self.wantsScroll = 0
	end
end

--- @private
function TableFrame:Frame_CloseButton_OnClick()
	self.autoScrollTarget = nil
	self.hasFilterError = false
	self.hasMessagesPending = false
	self.isMidUpdate = false
	self.wantsScroll = 0

	self.bufferReader:Dispose()
	self.bufferReader = nil

	self.table.dataProvider:Flush()

	self.frame:Hide()
end

--- @private
--- @param text string
function TableFrame:Filter_OnQueryStringChanged(text)
	self:UpdateQueryString(text)
end

--- @private
--- @param column integer
function TableFrame:Header_OnColumnsResized(column)
	self.table:ResizeColumn(column)
end

--- @private
function TableFrame:Status_OnLiveButtonClick()
	self:InitializeTable()
end

--- @private
--- @param position number
--- @param direction integer
function TableFrame:Table_OnScroll(position, direction)
	if self.isMidUpdate then
		return
	end

	if position < 1 and self.table.scrollBar:HasScrollableExtent() then
		self.tail = false
		self:UpdateTailButtonVisibility()
	end

	self.wantsScroll = direction
end

--- @private
function TableFrame:Table_OnClick()
	self.autoScrollTarget = nil
end

Addon.TableFrame = TableFrame
