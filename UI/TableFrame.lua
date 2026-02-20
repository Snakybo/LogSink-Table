--- @class Addon
local Addon = select(2, ...)

--- @class TableFrame : Frame
--- @field public onScroll? fun(position: number, direction: integer)
--- @field public columns ColumnConfig[]
--- @field public dataProvider DataProviderMixin
--- @field public scrollBar MinimalScrollBar
--- @field public scrollBox WowScrollBoxList
local TableFrame = {}

local ROW_HEIGHT = 22
local DEFAULT_COLUMN_WIDTH = 100

function TableFrame.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, TableFrame)
	result:Init()

	return result
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
--- @param entry LibLog-1.0.LogMessage
function TableFrame:CreateScrollBoxRow(frame, entry)
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
			cell:SetWidth(colConfig.width or DEFAULT_COLUMN_WIDTH)
		else
			cell:SetPoint("RIGHT", frame:GetParent(), "RIGHT")
		end

		local value = colConfig.get and colConfig.get(entry) or entry[colConfig.key]
		cell.Text:SetText(tostring(value or ""))
	end

	for i = #self.columns + 1, #frame.cells do
		frame.cells[i]:Hide()
	end

	frame:SetScript("OnEnter", function(...) self:LogRow_OnEnter(...) end)
	frame:SetScript("OnLeave", function(...) self:LogRow_OnLeave(...)  end)
	frame:SetScript("OnClick", function(...) self:LogRow_OnClick(entry) end)
end

--- @private
--- @param scrollPercentage number
function TableFrame:ScrollBox_OnScroll(_, scrollPercentage)
	if self.onScroll ~= nil then
		self.onScroll(scrollPercentage, scrollPercentage <= 0 and -1 or scrollPercentage >= 1 and 1 or 0)
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

--- @param entry LibLog-1.0.LogMessage
function TableFrame:LogRow_OnClick(entry)
	UIParentLoadAddOn("Blizzard_DebugTools")
	DisplayTableInspectorWindow(entry)
end

Addon.TableFrame = TableFrame
