--- @class Addon
local Addon = select(2, ...)

--- @class TableFrameUI.Options : Frame
--- @field public currentSessionOnClick? fun(checked: boolean)
--- @field private currentSession InterfaceOptionsCheckButtonTemplate
local Options = {}

--- @param parent Frame
--- @return TableFrameUI.Options
function Options.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Options)
	result:Init()

	return result
end

--- @private
function Options:Init()
	self.currentSession = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
	self.currentSession:SetPoint("TOPLEFT", self, "TOPLEFT")
	self.currentSession:SetSize(24, 24)
	self.currentSession:SetScript("OnClick", function() self:CurrentSession_OnClick() end)
	self.currentSession:SetChecked(LogSinkTableDB.currentSessionOnly)

	local currentSessionText = self.currentSession:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	currentSessionText:SetPoint("LEFT", self.currentSession, "RIGHT", 3, 0)
	currentSessionText:SetText(Addon.L["Filter to current session"])

	return self
end

--- @private
function Options:CurrentSession_OnClick()
	LogSinkTableDB.currentSessionOnly = self.currentSession:GetChecked()

	if self.currentSessionOnClick ~= nil then
		self.currentSessionOnClick(LogSinkTableDB.currentSessionOnly)
	end
end

--- @class TableFrame
local TableFrame = Addon.TableFrame
TableFrame.UI.Options = Options
