--- @class Addon
local Addon = select(2, ...)

--- @class TableFrameUI.TableCell : Button
--- @field public Text FontString
--- @field public data LibLog-1.0.LogMessage
--- @field public config ColumnConfig

--- @class TableFrameUI.TableRow : Frame
--- @field public cells TableFrameUI.TableCell[]
--- @field public Highlight Texture

--- @class TableFrameUI.TableRowHeader : Frame
--- @field public Text FontString

--- @class TableFrameUI.Table : Frame
--- @field public onScroll? fun(position: number, direction: integer)
--- @field public dataProvider DataProviderMixin
--- @field public scrollBar MinimalScrollBar
--- @field public scrollBox WowScrollBoxList
--- @field private columns ColumnConfig[]
local Table = {}

local ROW_HEIGHT = 22

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
	local visualizer = Addon.TableFrame:GetColumnVisualizer(config.key)

	if visualizer ~= nil and visualizer.get ~= nil then
		return visualizer.get(entry)
	end

	return GetRawValue(config, entry)
end

--- @param parent Frame
--- @param columns ColumnConfig[]
--- @return TableFrameUI.Table
function Table.Create(parent, columns)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Table)
	result.columns = columns
	result:Init()

	return result
end

function Table:UpdateColumns()
	self.scrollBox:Rebuild(true)
end

--- @param column integer
function Table:ResizeColumn(column)
	self.scrollBox:ForEachFrame(function(frame)
		local config = self.columns[column]
		local cell = frame.cells[column]

		if cell ~= nil then
			cell:SetWidth(config.width)
		end
	end)
end

--- @private
function Table:Init()
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

		if not l.isHeader and r.isHeader then
			return false
		end

		if l.time == r.time then
			return l.sequenceId < r.sequenceId
		end

		return l.time < r.time
	end, true)

    self.scrollBox:SetDataProvider(self.dataProvider)
end

--- @private
--- @param frame TableFrameUI.TableRowHeader
function Table:SetupHeaderRow(frame)
	frame.Text:SetText(Addon.L["Click to search further back..."])

	frame:SetScript("OnClick", function() self:HeaderRow_OnClick() end)
end

--- @private
--- @param frame TableFrameUI.TableRow
--- @param entry LibLog-1.0.LogMessage
function Table:SetupRow(frame, entry)
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
					self:LogRow_OnClick(cell.data)
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
function Table:ScrollBox_OnScroll(_, scrollPercentage)
	if self.onScroll ~= nil then
		self.onScroll(scrollPercentage, scrollPercentage <= 0 and -1 or scrollPercentage >= 1 and 1 or 0)
	end
end

--- @private
function Table:HeaderRow_OnClick()
	if self.onScroll ~= nil then
		self.onScroll(0, -1)
	end
end

--- @private
--- @param frame TableFrameUI.TableRow
function Table:LogRow_OnEnter(frame)
	frame.Highlight:Show()
end

--- @private
--- @param frame TableFrameUI.TableRow
function Table:LogRow_OnLeave(frame)
	frame.Highlight:Hide()
end

--- @private
--- @param entry LibLog-1.0.LogMessage
function Table:LogRow_OnClick(entry)
	Addon.InspectorFrame:Open(entry)
end

--- @private
--- @param frame TableFrameUI.TableCell
--- @param button string
function Table:LogCell_OnMouseUp(frame, button)
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

			Addon.TableFrame:AppendQueryString(filter)
		end)
		addFilter:SetEnabled(type(value) ~= "nil" and type(value) ~= "table")

		local addExclude = root:CreateButton(Addon.L["Exclude value"], function()
			local filter = frame.config.key .. " ~= "

			if type(value) == "string" then
				filter = filter .. '"' .. value .. '"'
			else
				filter = filter .. value
			end

			Addon.TableFrame:AppendQueryString(filter)
		end)
		addExclude:SetEnabled(type(value) ~= "nil" and type(value) ~= "table")
	end)
end

--- @class TableFrame
local TableFrame = Addon.TableFrame
TableFrame.UI.Table = Table
