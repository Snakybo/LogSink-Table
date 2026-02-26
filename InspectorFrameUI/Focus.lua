--- @class Addon
local Addon = select(2, ...)

--- @class InspectorFrameUI.Focus : Frame
--- @field public onClick? fun()
--- @field private button Button
local Focus = {}

--- @param parent Frame
--- @return InspectorFrameUI.Focus
function Focus.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Focus)
	result:Init()

	return result
end

--- @param visible boolean
function Focus:SetVisible(visible)
	if visible then
		self.button:Show()
	else
		self.button:Hide()
	end
end

--- @param focusing boolean
function Focus:SetFocusing(focusing)
	self.button:SetText(focusing and Addon.L["Focusing..."] or Addon.L["Focus"])
	self.button:SetEnabled(not focusing)
end

--- @private
function Focus:Init()
	self.button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.button:SetPoint("TOP", self, "TOP")
	self.button:SetPoint("BOTTOM", self, "BOTTOM")
	self.button:SetWidth(120)
	self.button:SetText(Addon.L["Focus"])
	self.button:SetScript("OnClick", function() self:Button_OnClick() end)
	self.button:Hide()

	return self
end

--- @private
function Focus:Button_OnClick()
	if self.onClick ~= nil then
		self.onClick()
	end
end

--- @class InspectorFrame
local InspectorFrame = Addon.InspectorFrame
InspectorFrame.UI.Focus = Focus
