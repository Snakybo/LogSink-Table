--- @class Addon
local Addon = select(2, ...)

--- @class StatusFrame : Frame
--- @field public onSearchButtonClick? fun()
--- @field public onLiveButtonClick? fun()
--- @field private text FontString
--- @field private status string
--- @field private searchButton Button
--- @field private liveButton Button
--- @field private temporaryStatusTimer? FunctionContainer
local StatusFrame = {}

local TEMPORARY_TEXT_DURATION = 3

--- @param parent Frame
--- @return StatusFrame
function StatusFrame.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, StatusFrame)
	result:Init()

	return result
end

function StatusFrame:SetText(text)
	self.status = text

	if self.temporaryStatusTimer == nil then
		self.text:SetText(text)
	end
end

--- @param text string
function StatusFrame:SetTemporaryText(text)
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
function StatusFrame:ShowSearchButton(show)
	if show then
		self.searchButton:Show()
	else
		self.searchButton:Hide()
	end
end

--- @param show boolean
function StatusFrame:ShowLiveButton(show)
	if show then
		self.liveButton:Show()
	else
		self.liveButton:Hide()
	end
end

--- @private
function StatusFrame:Init()
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

	self.searchButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.searchButton:SetPoint("TOPLEFT", self.liveButton, "TOPLEFT", -120, 0)
	self.searchButton:SetPoint("BOTTOMRIGHT", self.liveButton, "BOTTOMLEFT", -5, 0)
	self.searchButton:SetText(Addon.L["Search more..."])
	self.searchButton:Hide()
	self.searchButton:SetScript("OnClick", function() self:SearchButton_OnClick() end)

	return self
end

--- @private
function StatusFrame:SearchButton_OnClick()
	if self.onSearchButtonClick ~= nil then
		self.onSearchButtonClick()
	end
end

--- @private
function StatusFrame:LiveButton_OnClick()
	if self.onLiveButtonClick ~= nil then
		self.onLiveButtonClick()
	end
end

Addon.StatusFrame = StatusFrame
