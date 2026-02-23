--- @class Addon
local Addon = select(2, ...)

--- @class TableCellFrame : Button
--- @field public Text FontString
--- @field public data LibLog-1.0.LogMessage
--- @field public config ColumnConfig

--- @class TableRowFrame : Frame
--- @field public cells TableCellFrame[]
--- @field public Highlight Texture

--- @class TableRowHeaderFrame : Frame
--- @field public Text FontString

--- @class TableFrame : Frame
--- @field public onScroll? fun(position: number, direction: integer)
--- @field public dataProvider DataProviderMixin
--- @field public scrollBar MinimalScrollBar
--- @field public scrollBox WowScrollBoxList
--- @field private columns ColumnConfig[]
local TableFrame = {}

local ROW_HEIGHT = 22

StaticPopupDialogs["LOGSINK_COPY_TEXT"] = {
    text = Addon.L["Press Ctrl+C to copy"],
    button1 = DONE,
    hasEditBox = true,
	editBoxWidth = 260,
	OnShow = function(self, data)
		self.EditBox:SetText(data)
		self.EditBox:SetCursorPosition(0)
		self.EditBox:HighlightText()
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    timeout = 0,
    whileDead = true
}

--- @param tbl table
--- @param indentChar string
--- @param sepChar string
--- @param indent? string
--- @param escape? boolean
local function Serialize(tbl, indentChar, sepChar, indent, escape)
	indent = indent or ""

	if type(tbl) == "table" then
		local nextIndent = indent .. indentChar
		local lines = {
			"{"
		}

		for k, v in pairs(tbl) do
			local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
			local value = Serialize(v, indentChar, sepChar, nextIndent, true)

			table.insert(lines, string.format("%s%s = %s,", nextIndent, key, value))
		end

		table.insert(lines, indent .. "}")

		return table.concat(lines, sepChar)
	elseif escape and type(tbl) == "string" then
		return string.format("%q", tbl)
	end

	return tostring(tbl or "")
end

--- @param config ColumnConfig
--- @param entry LibLog-1.0.LogMessage
--- @return unknown
local function GetRawValue(config, entry)
	return entry[config.key] or entry.properties[config.key]
end

--- @param config ColumnConfig
--- @param entry LibLog-1.0.LogMessage
--- @return unknown
local function GetValue(config, entry)
	local visualizer = Addon.Window:GetColumnVisualizer(config.key)

	if visualizer ~= nil and visualizer.get ~= nil then
		return visualizer.get(entry)
	end

	return GetRawValue(config, entry)
end

--- @param parent Frame
--- @param columns ColumnConfig[]
--- @return TableFrame
function TableFrame.Create(parent, columns)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, TableFrame)
	result.columns = columns
	result:Init()

	return result
end

function TableFrame:UpdateColumns()
	self.scrollBox:Rebuild(true)
end

--- @param column integer
function TableFrame:ResizeColumn(column)
	self.scrollBox:ForEachFrame(function(frame)
		local config = self.columns[column]
		local cell = frame.cells[column]

		if cell ~= nil then
			cell:SetWidth(config.width)
		end
	end)
end

--- @private
function TableFrame:Init()
	self.scrollBar = CreateFrame("EventFrame", nil, self, "MinimalScrollBar")
    self.scrollBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, 0)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 0)

	self.scrollBox = CreateFrame("Frame", "sb", self, "WowScrollBoxList")
    self.scrollBox:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    self.scrollBox:SetPoint("BOTTOMRIGHT", self.scrollBar, "BOTTOMLEFT", -5, 0)
	self.scrollBox:RegisterCallback("OnScroll", function(...) self:ScrollBox_OnScroll(...) end)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementFactory(function(factory, node)
		if node.sequenceId == nil and node.isHeader then
			factory("LogTableRowHeaderTemplate", function(frame)
				self:SetupHeaderRow(frame)
			end)
		else
			factory("LogTableRowTemplate", function(frame, element)
				self:SetupRow(frame, element)
			end)
		end
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)

	self.dataProvider = CreateDataProvider()
	self.dataProvider:SetSortComparator(function(l, r)
		if l.isHeader and not r.isHeader then
			return true
		end

		if l.time == r.time then
			return l.sequenceId < r.sequenceId
		end

		return l.time < r.time
	end, true)

    self.scrollBox:SetDataProvider(self.dataProvider)
end

--- @private
--- @param frame TableRowHeaderFrame
function TableFrame:SetupHeaderRow(frame)
	frame.Text:SetText(Addon.L["Click to search further back..."])

	frame:SetScript("OnClick", function() self:HeaderRow_OnClick() end)
end

--- @private
--- @param frame TableRowFrame
--- @param entry LibLog-1.0.LogMessage
function TableFrame:SetupRow(frame, entry)
	local cells = frame.cells

	for i, config in ipairs(self.columns) do
		local cell = cells[i]

		if cell == nil then
			cell = CreateFrame("Button", nil, frame, "LogTableCellTemplate")
			cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			cell:SetScript("OnMouseUp", function(...) self:LogCell_OnMouseUp(...) end)
			cell:SetScript("OnEnter", function() self:LogRow_OnEnter(frame) end)
			cell:SetScript("OnLeave", function() self:LogRow_OnLeave(frame)  end)
			cell:SetScript("OnClick", function(_, button)
				if button == "LeftButton" then
					self:LogRow_OnClick(entry)
				end
			end)

			cells[i] = cell
		end

		cell.data = entry
		cell.config = config
		cell:Show()

		if i == 1 then
			cell:SetPoint("LEFT", frame, "LEFT", 0, 0)
		else
			cell:SetPoint("LEFT", frame.cells[i - 1], "RIGHT", 0, 0)
		end

		if i < #self.columns then
			cell:ClearPoint("RIGHT")
			cell:SetWidth(config.width)
		else
			cell:SetPoint("RIGHT", frame:GetParent(), "RIGHT")
		end

		cell.Text:SetText(Serialize(GetValue(config, entry), "", " "))
	end

	for i = #self.columns + 1, #frame.cells do
		frame.cells[i]:Hide()
	end

	frame:SetScript("OnEnter", function(...) self:LogRow_OnEnter(...) end)
	frame:SetScript("OnLeave", function(...) self:LogRow_OnLeave(...)  end)
	frame:SetScript("OnClick", function() self:LogRow_OnClick(entry) end)
end

--- @private
--- @param scrollPercentage number
function TableFrame:ScrollBox_OnScroll(_, scrollPercentage)
	if self.onScroll ~= nil then
		self.onScroll(scrollPercentage, scrollPercentage <= 0 and -1 or scrollPercentage >= 1 and 1 or 0)
	end
end

--- @private
function TableFrame:HeaderRow_OnClick()
	if self.onScroll ~= nil then
		self.onScroll(0, -1)
	end
end

--- @private
--- @param frame TableRowFrame
function TableFrame:LogRow_OnEnter(frame)
	frame.Highlight:Show()
end

--- @private
--- @param frame TableRowFrame
function TableFrame:LogRow_OnLeave(frame)
	frame.Highlight:Hide()
end

--- @private
--- @param entry LibLog-1.0.LogMessage
function TableFrame:LogRow_OnClick(entry)
	UIParentLoadAddOn("Blizzard_DebugTools")
	DisplayTableInspectorWindow(entry)
end

--- @private
--- @param frame TableCellFrame
--- @param button string
function TableFrame:LogCell_OnMouseUp(frame, button)
	if button ~= "RightButton" then
		return
	end

	MenuUtil.CreateContextMenu(frame, function(owner, root)
		local value = GetRawValue(frame.config, frame.data)

		local copyValue = root:CreateButton(Addon.L["Copy value"], function()
			StaticPopup_Show("LOGSINK_COPY_TEXT", nil, nil, frame.Text:GetText())
		end)
		copyValue:SetEnabled(type(value) ~= "nil")

		root:CreateButton(Addon.L["Copy data"], function()
			StaticPopup_Show("LOGSINK_COPY_TEXT",  nil, nil, Serialize(frame.data, "\t", "\n"))
		end)

		local addFilter = root:CreateButton(Addon.L["Add filter"], function()
			local filter = frame.config.key .. " = "

			if type(value) == "string" then
				filter = filter .. '"' .. value .. '"'
			else
				filter = filter .. value
			end

			Addon.Window:AppendQueryString(filter)
		end)
		addFilter:SetEnabled(type(value) ~= "nil" and type(value) ~= "table")

		local addExclude = root:CreateButton(Addon.L["Exclude value"], function()
			local filter = frame.config.key .. " ~= "

			if type(value) == "string" then
				filter = filter .. '"' .. value .. '"'
			else
				filter = filter .. value
			end

			Addon.Window:AppendQueryString(filter)
		end)
		addExclude:SetEnabled(type(value) ~= "nil" and type(value) ~= "table")
	end)
end

Addon.TableFrame = TableFrame
