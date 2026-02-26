--- @class Addon
local Addon = select(2, ...)

--- @class InspectorFrame
--- @field public onClose fun()
--- @field private selected? LibLog-1.0.LogMessage
local InspectorFrame = {}
InspectorFrame.UI = {}

--- @param data LibLog-1.0.LogMessage
function InspectorFrame:Open(data)
	if self.frame == nil then
		self:CreateWindow()
	end

	self.selected = data

	self.header:SetText(data.message)
	self.table:SetData(data)
	self.focus:SetVisible(false)
	self.frame:Show()
end

--- @param data LibLog-1.0.LogMessage
--- @return boolean
function InspectorFrame:IsSelected(data)
	return data == self.selected
end

--- @param focused boolean
function InspectorFrame:SetIsFocused(focused)
	if self.frame == nil then
		return
	end

	self.focus:SetVisible(not focused)
end

--- @return LibLog-1.0.LogMessage?
function InspectorFrame:GetSelected()
	return self.selected
end

--- @private
function InspectorFrame:CreateWindow()
	self:CreateFrame()
	self:CreateContentContainer()

	self.header = InspectorFrame.UI.Header.Create(self.container)
	self.header:SetPoint("TOPLEFT", self.container, "TOPLEFT", 1, -1)
	self.header:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", 1, -1)
	self.header:SetHeight(80)

	self.focus = InspectorFrame.UI.Focus.Create(self.container)
	self.focus:SetPoint("TOPLEFT", self.container, "BOTTOMLEFT", 0, 20)
	self.focus:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT")
	self.focus.onClick = function() self:Focus_OnClick() end

	self.table = InspectorFrame.UI.Table.Create(self.container)
	self.table:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -10)
	self.table:SetPoint("BOTTOMRIGHT", self.focus, "TOPRIGHT", 0, 10)
end

--- @private
function InspectorFrame:CreateFrame()
	local parent = Addon.TableFrame.frame

	self.frame = CreateFrame("Frame", "LogSinkInspectorFrame", parent, "DefaultPanelFlatTemplate")
	self.frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
	self.frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0)
	self.frame:SetWidth(400)
	self.frame:SetFrameStrata("HIGH")

	self.frame.CloseButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButtonDefaultAnchors")
	self.frame.CloseButton:SetScript("OnClick", function() self:Frame_CloseButton_OnClick() end)

	self.frame.TitleContainer.TitleText:SetText(Addon.L["Log Inspector"])
end

--- @private
function InspectorFrame:CreateContentContainer()
	local INSET_LEFT = 12
	local INSET_RIGHT = -10
	local INSET_TOP = -27
	local INSET_BOTTOM = 8

	self.container = CreateFrame("Frame", nil, self.frame)
	self.container:SetPoint("TOPLEFT", self.frame, "TOPLEFT", INSET_LEFT, INSET_TOP)
	self.container:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
end

--- @private
function InspectorFrame:Frame_CloseButton_OnClick()
	self.table:SetData(nil)
	self.selected = nil

	self.frame:Hide()

	if self.onClose ~= nil then
		self.onClose()
	end
end

--- @private
function InspectorFrame:Frame_OnUpdate()
	if Addon.TableFrame:IsAutoScrolling() then
		return
	end

	self.focus:SetFocusing(false)
	self.frame:SetScript("OnUpdate", nil)
end

--- @private
function InspectorFrame:Focus_OnClick()
	Addon.TableFrame:AutoScrollTo(self.selected)

	self.focus:SetFocusing(true)
	self.frame:SetScript("OnUpdate", function() self:Frame_OnUpdate() end)
end

Addon.InspectorFrame = InspectorFrame
