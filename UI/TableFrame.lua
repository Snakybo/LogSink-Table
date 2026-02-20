--- @class Addon
local Addon = select(2, ...)

--- @class TableFrame : Frame
local TableFrame = {}

function TableFrame.Create(parent)
	local base = CreateFrame("Frame", nil, parent)
	base:SetPoint("TOPLEFT", parent, "TOPLEFT")
	base:SetPoint("BOTTOMRIGHT", parent, "BOTTOMR", 0, -20)

	local result = Mixin(base, FilterFrame)
	result:Init()

	return result
end

--- @private
function TableFrame:CreateScrollBox()
	self.scrollBar = CreateFrame("EventFrame", nil, self.container, "MinimalScrollBar")
    self.scrollBar:SetPoint("TOPRIGHT", self.filter, "BOTTOMRIGHT", -10, -10)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -10, 10)

	self.scrollBox = CreateFrame("Frame", nil, self.container, "WowScrollBoxList")
    self.scrollBox:SetPoint("TOPLEFT", self.filter, "BOTTOMLEFT", 0, -10)
    self.scrollBox:SetPoint("BOTTOMRIGHT", self.scrollBar, "BOTTOMLEFT", 0, 0)
	self.scrollBox:RegisterCallback("OnScroll", function(_, _, isAtEnd)
        -- if not self.isUpdatingInternal then
        --     self.bufferReader.tail = isAtEnd
        -- end

        -- Logic for LoadPrevious / LoadNext
        local scrollPercentage = self.scrollBox:GetScrollPercentage()
        if scrollPercentage <= 0 then
            --self:HandlePagination("LoadPrevious")
        elseif scrollPercentage >= 1 and not self.bufferReader.tail then
           -- self:HandlePagination("LoadNext")
        end
    end)

	local view = CreateScrollBoxListLinearView()
	-- view:SetElementExtent(ROW_HEIGHT)
	-- view:SetElementFactory(function(factory)
    --     factory:Register("LogTableRowTemplate", function(frame, elementData)
    --         self:CreateScrollBoxRow(frame, elementData)
    --     end)
    -- end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)

	local function Initializer(button, data)
		local playerName = data.PlayerName
		local playerClass = data.PlayerClass
		button:SetScript("OnClick", function()
			print(playerName .. ": " .. playerClass)
		end)
		button:SetText(playerName)
	end


	view:SetElementInitializer("LogTableRowTemplate", function(button, data)
		self:CreateScrollBoxRow(button, data)
	end)

	self.dataProvider = CreateDataProvider()
    self.scrollBox:SetDataProvider(self.dataProvider)
end

--- @private
function Window:CreateScrollBoxRow(frame, logEntry)
	for i, colConfig in ipairs(self.columns) do
		if not frame.cells[i] then
			frame.cells[i] = CreateFrame("Frame", nil, frame, "LogTableCellTemplate")
		end

		local cell = frame.cells[i]
		cell:Show()

		-- Positioning logic
		if i == 1 then
			cell:SetPoint("LEFT", frame, "LEFT", 0, 0)
		else
			cell:SetPoint("LEFT", frame.cells[i-1], "RIGHT", 0, 0)
		end

		-- Width Sync
		if colConfig.width then
		cell:SetWidth(colConfig.width)
		end

		-- Data Population
		local value = colConfig.get and colConfig.get(logEntry) or logEntry[colConfig.key]
		cell.Text:SetText(tostring(value or ""))
	end

	-- Hide any extra cells if columns were deleted
	for i = #self.columns + 1, #frame.cells do
		frame.cells[i]:Hide()
	end

	frame:SetScript("OnEnter", function() frame.Highlight:Show() end)
	frame:SetScript("OnLeave", function() frame.Highlight:Hide() end)

	frame:SetScript("OnClick", function()
		-- Built-in Blizzard Debug Tool for deep inspection
		UIParentLoadAddOn("Blizzard_DebugTools")
		DisplayTableInspectorWindow(logEntry)
	end)
end
