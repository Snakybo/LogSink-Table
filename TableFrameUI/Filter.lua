--- @class Addon
local Addon = select(2, ...)

--- @class TableFrameUI.Filter : Frame
--- @field public onQueryStringChanged? fun(query: string)
--- @field private editBox SearchBoxTemplate
--- @field private textContainer Frame
--- @field private cursor Texture
--- @field private cursorBlinkGroup AnimationGroup
--- @field private cursorShowAnim Alpha
--- @field private cursorHideAnim Alpha
--- @field private text FontString
--- @field private measureText FontString
local Filter = {}

local COLOR_SCHEME = {
	[Addon.TokenType.Keyword] = "ffD67113",
	[Addon.TokenType.Property] = "ff80ffff",
	[Addon.TokenType.String] = "ff1fff1f",
	[Addon.TokenType.Number] = "ffffd100",
	[Addon.TokenType.Boolean] = "ffffb86c",
	[Addon.TokenType.Operator] = "ffffffff",
	[Addon.TokenType.Time] = "ffff79c6",
	[Addon.TokenType.Nil] = "ffff5555",
	[Addon.TokenType.Table] = "ffbb86fc",
	[Addon.TokenType.Comma] = "ff888888"
}

--- @param tokens Token[]
--- @return string
local function Colorize(tokens)
	--- @type string[]
	local result = {}

	for i = 1, #tokens do
		local token = tokens[i]
		local color = COLOR_SCHEME[token.type]

		if token.type == Addon.TokenType.Table and type(token.value) == "table" then
			table.insert(result, Colorize(token.value))
		else
			local value = tostring(token.value)

			if color ~= nil then
				table.insert(result, "|c" .. color .. value .. "|r")
			else
				table.insert(result, value)
			end
		end
	end

	return table.concat(result, "")
end

--- @param parent Frame
--- @return TableFrameUI.Filter
function Filter.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Filter)
	result:Init()

	return result
end

--- @param text string
function Filter:SetText(text)
	self.editBox:SetText(text)
	self:EditBox_OnEnterPressed()
end

--- @return string
function Filter:GetText()
	return self.editBox:GetText()
end

--- @private
function Filter:Init()
	self.editBox = CreateFrame("EditBox", nil, self, "SearchBoxTemplate") --[[@as SearchBoxTemplate]]
	self.editBox:SetPoint("TOPLEFT", self, "TOPLEFT", 5, 0)
	self.editBox:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
	self.editBox:SetText(LogSinkTableDB.currentFilter or "")
	self.editBox:SetTextColor(0, 0, 0, 0)
	self.editBox:SetCursorPosition(0)
	self.editBox:SetHistoryLines(20)
	self.editBox:SetScript("OnEnterPressed", function() self:EditBox_OnEnterPressed() end)
	self.editBox:SetScript("OnTextChanged", function() self:EditBox_OnTextChanged() end)
	self.editBox:SetScript("OnCursorChanged", function(_, x) self:EditBox_OnCursorChanged(x) end)
	self.editBox:SetScript("OnEditFocusGained", function() self:EditBox_OnEditFocusGained() end)
	self.editBox:SetScript("OnEditFocusLost", function() self:EditBox_OnEditFocusLost() end)
	self.editBox.Instructions:SetText(Addon.L["Search logs"])
	self.editBox.clearButton:HookScript("OnClick", function() self:EditBox_ClearButton_OnClick() end)
	self.editBoxInsetL, self.editBoxInsetR = self.editBox:GetTextInsets()

	self.textContainer = CreateFrame("Frame", nil, self.editBox)
	self.textContainer:SetPoint("TOPLEFT", self.editBox, "TOPLEFT", self.editBoxInsetL, 0)
	self.textContainer:SetPoint("BOTTOMRIGHT", self.editBox, "BOTTOMRIGHT", self.editBoxInsetR - 6, 0)
	self.textContainer:SetClipsChildren(true)

	self.cursor = self.textContainer:CreateTexture(nil, "OVERLAY")
	self.cursor:SetSize(2, 15)
	self.cursor:SetColorTexture(1, 1, 1, 1)
	self.cursor:Hide()

	self.cursorBlinkGroup = self.cursor:CreateAnimationGroup()
	self.cursorBlinkGroup:SetLooping("REPEAT")

	self.cursorShowAnim = self.cursorBlinkGroup:CreateAnimation("Alpha")
	self.cursorShowAnim:SetFromAlpha(1)
	self.cursorShowAnim:SetToAlpha(1)
	self.cursorShowAnim:SetDuration(0.5)
	self.cursorShowAnim:SetOrder(1)

	self.cursorHideAnim = self.cursorBlinkGroup:CreateAnimation("Alpha")
	self.cursorHideAnim:SetFromAlpha(0)
	self.cursorHideAnim:SetToAlpha(0)
	self.cursorHideAnim:SetDuration(0.5)
	self.cursorHideAnim:SetOrder(2)

	self.text = self.textContainer:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	self.text:SetAllPoints(self.textContainer)
	self.text:SetJustifyH("LEFT")
	self.text:SetWordWrap(false)
	self.text:SetNonSpaceWrap(false)
	self.text:SetWidth(10000)

	self.measureText = self.textContainer:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	self.measureText:SetShadowOffset(0, 0)
	self.measureText:Hide()

	self:SyncEditBox()

	return self
end

--- @private
function Filter:SyncEditBox()
	local text = self.editBox:GetText()
	local tokens = Addon.QueryParser:Tokenize(text)

	local colorized = Colorize(tokens)
	local last = tokens[#tokens]

	if last == nil then
		self.text:SetText(text)
	else
		if last.endIndex < #text then
			colorized = colorized .. text:sub(last.endIndex + 1)
		end

		self.text:SetText(colorized)
	end
end

--- @private
function Filter:EditBox_OnEnterPressed()
	local text = self.editBox:GetText()

	if text ~= LogSinkTableDB.currentFilter then
		if #text > 0 then
			self.editBox:AddHistoryLine(text)
		end

		LogSinkTableDB.currentFilter = text

		if self.onQueryStringChanged ~= nil then
			self.onQueryStringChanged(text)
		end
	end

	self.editBox:ClearFocus()
end

--- @private
function Filter:EditBox_OnTextChanged()
	SearchBoxTemplate_OnTextChanged(self.editBox)

	self:SyncEditBox()
end

--- @private
--- @param x number
function Filter:EditBox_OnCursorChanged(x)
	local text = self.editBox:GetText()
	local pos = self.editBox:GetCursorPosition()

	self.cursor:SetPoint("TOPLEFT", self.editBox, "TOPLEFT", self.editBoxInsetL + x, -3)

	local widthToCursor = 0
	if pos > 0 then
		self.measureText:SetText(text:sub(1, pos))
		widthToCursor = self.measureText:GetStringWidth() - x
	end

	-- TODO: this has some pixel-shifting when scrolling through the text.. solve somehow
	local offset = self.editBoxInsetL - widthToCursor

	self.text:SetPoint("TOPLEFT", self.editBox, "TOPLEFT", offset, 0)
	self.text:SetPoint("BOTTOMRIGHT", self.editBox, "BOTTOMRIGHT", 0, 0)

	self.cursorBlinkGroup:Stop()
	self.cursorBlinkGroup:Play()
end

--- @private
function Filter:EditBox_OnEditFocusGained()
	SearchBoxTemplate_OnEditFocusGained(self.editBox)

	self.cursor:Show();
	self.cursorBlinkGroup:Play()
end

--- @private
function Filter:EditBox_OnEditFocusLost()
	SearchBoxTemplate_OnEditFocusLost(self.editBox)

	self.cursor:Hide();
	self.cursorBlinkGroup:Stop()
end

--- @private
function Filter:EditBox_ClearButton_OnClick()
	self:EditBox_OnEnterPressed()
end

--- @class TableFrame
local TableFrame = Addon.TableFrame
TableFrame.UI.Filter = Filter
