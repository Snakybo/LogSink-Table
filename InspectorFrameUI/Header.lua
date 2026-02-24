--- @class Addon
local Addon = select(2, ...)

--- @class InspectorFrameUI.Header : Frame
--- @field private text FontString
local Header = {}

--- @param parent Frame
--- @return InspectorFrameUI.Header
function Header.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Header)
	result:Init()

	return result
end

function Header:SetText(text)
	self.text:SetText(text)
end

--- @private
function Header:Init()
	self.text = self:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4)
	self.text:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -4, 4)
	self.text:SetJustifyH("LEFT")
	self.text:SetJustifyV("TOP")
	self.text:SetWordWrap(true)

	local line = self:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 4, 0)
    line:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -4, 0)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.8)

	return self
end

--- @class InspectorFrame
local InspectorFrame = Addon.InspectorFrame
InspectorFrame.UI.Header = Header
