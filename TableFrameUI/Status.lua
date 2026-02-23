--- @class Addon
local Addon = select(2, ...)

--- @class TableFrameUI.Status : Frame
--- @field public onLiveButtonClick? fun()
--- @field private text FontString
--- @field private status string
--- @field private liveButton Button
--- @field private temporaryStatusTimer? FunctionContainer
local Status = {}

local TEMPORARY_TEXT_DURATION = 3

--- @param parent Frame
--- @return TableFrameUI.Status
function Status.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Status)
	result:Init()

	return result
end

function Status:SetText(text)
	self.status = text

	if self.temporaryStatusTimer == nil then
		self.text:SetText(text)
	end
end

--- @param text string
function Status:SetTemporaryText(text)
	if self.temporaryStatusTimer ~= nil then
		self.temporaryStatusTimer:Cancel()
	end

	self.text:SetText(text)
	self.temporaryStatusTimer = C_Timer.NewTimer(TEMPORARY_TEXT_DURATION, function()
		self.text:SetText(self.status)
		self.temporaryStatusTimer = nil
	end)
end

--- @param show boolean
function Status:ShowLiveButton(show)
	if show then
		self.liveButton:Show()
	else
		self.liveButton:Hide()
	end
end

--- @private
function Status:Init()
	self.text = self:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT")
	self.text:SetPoint("BOTTOMRIGHT", self, "BOTTOM")
	self.text:SetJustifyH("LEFT")
	self.text:SetWordWrap(false)
	self.text:SetNonSpaceWrap(false)

	self.liveButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.liveButton:SetPoint("TOPLEFT", self, "TOPRIGHT", -120, 0)
	self.liveButton:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
	self.liveButton:SetText(Addon.L["Go to live"])
	self.liveButton:Hide()
	self.liveButton:SetScript("OnClick", function() self:LiveButton_OnClick() end)

	return self
end

--- @private
function Status:LiveButton_OnClick()
	if self.onLiveButtonClick ~= nil then
		self.onLiveButtonClick()
	end
end

--- @class TableFrame
local TableFrame = Addon.TableFrame
TableFrame.UI.Status = Status
