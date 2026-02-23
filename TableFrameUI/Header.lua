--- @class Addon
local Addon = select(2, ...)

--- @class TableFrameUI.HeaderButton : Button
--- @field public highlight Texture
--- @field public text FontString
--- @field public resizer TableFrameUI.HeaderButtonResizer
--- @field public column integer
--- @field public config ColumnConfig

--- @class TableFrameUI.HeaderButtonResizer : Frame
--- @field public background Texture

--- @class TableFrameUI.Header : Frame
--- @field public onColumnsReset? fun()
--- @field public onColumnResized? fun(column: integer)
--- @field private columns ColumnConfig[]
--- @field private buttons TableFrameUI.HeaderButton[]
local Header = {}

local MIN_COLUMN_WIDTH = 50

StaticPopupDialogs["LOGSINK_ADD_COLUMN"] = {
    text = Addon.L["Enter the property key"],
    button1 = ADD,
    button2 = CANCEL,
    hasEditBox = true,
	editBoxInstructions = Addon.L["e.g. health, mana"],
	OnShow = function(self)
		self:GetButton1():Disable()
	end,
    OnAccept = function(self)
        local key = self.EditBox:GetText()

		if #key > 0 then
            Addon.TableFrame:AddColumn(key, self.column)
			return false
        end

		return true
    end,
	EditBoxOnTextChanged = function(self)
		local key = self:GetText()

		if #key == 0 then
			self:GetParent():GetButton1():Disable()
		else
			self:GetParent():GetButton1():Enable()
		end
	end,
	EditBoxOnEnterPressed = function(self)
		StaticPopup_OnClick(self:GetParent(), 1)
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    timeout = 0,
    whileDead = true
}

--- @param parent Frame
--- @param columns ColumnConfig[]
--- @return TableFrameUI.Header
function Header.Create(parent, columns)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Header)
	result.columns = columns
	result:Init()

	return result
end

--- @private
function Header:Init()
	self.buttons = {}

	self:UpdateColumns()

	return self
end

function Header:UpdateColumns()
	for i = 1, #self.columns do
		local config = self.columns[i]
		local button = self.buttons[i]
		local visualizer = Addon.TableFrame:GetColumnVisualizer(config.key)

		if button == nil then
			--- @type TableFrameUI.HeaderButton
			button = CreateFrame("Button", nil, self)
			button:RegisterForClicks("RightButtonUp")
			button:SetHeight(24)

			button.highlight = button:CreateTexture(nil, "OVERLAY")
			button.highlight:SetAllPoints()
			button.highlight:SetColorTexture(1, 1, 1, 0.1)
			button.highlight:Hide()

			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 4, 0)
			button.text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 0)
			button.text:SetJustifyH("LEFT")

			button:SetScript("OnEnter", function(...) self:HeaderButton_OnEnter(...) end)
			button:SetScript("OnLeave", function(...) self:HeaderButton_OnLeave(...) end)
			button:SetScript("OnMouseUp", function(...) self:HeaderButton_OnMouseUp(...) end)

			self:CreateResizer(button)

			self.buttons[i] = button
		end

		button:SetWidth(config.width or Addon.TableFrame.DEFAULT_COLUMN_WIDTH)
		button:ClearAllPoints()
		button:Show()

		button.column = i
		button.config = config
		button.text:SetText(visualizer ~= nil and visualizer.name or config.key)
		button.resizer:Show()

		if i == 1 then
			button:SetPoint("LEFT", self, "LEFT", 0, 0)
		else
			button:SetPoint("LEFT", self.buttons[i - 1], "RIGHT", 0, 0)
		end

		if i == #self.columns then
			button:SetPoint("RIGHT", self, "RIGHT", 0, 0)

			button.resizer:Hide()
		end
	end

	for i = #self.columns + 1, #self.buttons do
		self.buttons[i]:Hide()
	end
end

--- @private
--- @param button TableFrameUI.HeaderButton
function Header:CreateResizer(button)
	local EPSILON = 0.001

	local isResizing = false
	local isHovering = false

	--- @type number
	local startX

	--- @type number
	local startWidth

	--- @type number
	local lastWidth

	local function OnEnter()
		isHovering = true

		button.resizer.background:Show()
	end

	local function OnLeave()
		isHovering = false

		if not isResizing then
			button.resizer.background:Hide()
		end
	end

	local function OnMouseDown()
		isResizing = true

		button.resizer.background:Show()

		startX = GetCursorPosition()
		startWidth = button:GetWidth()
		lastWidth = startWidth
	end

	local function OnMouseUp()
		isResizing = false

		if not isHovering then
			button.resizer.background:Hide()
		end
	end

	local function OnUpdate()
		if not isResizing then
			return
		end

		--- @type TableFrameUI.HeaderButton
		local lastButton

		for i = #self.buttons, 1, -1 do
			if self.buttons[i]:IsShown() then
				lastButton = self.buttons[i]
				break
			end
		end

		local x = GetCursorPosition()
		local delta = (x - startX) / UIParent:GetEffectiveScale()
		local width = max(MIN_COLUMN_WIDTH, startWidth + delta)

		-- local lastButtonWidth = lastButton:GetWidth() - width - lastWidth
		-- if lastButtonWidth < MIN_COLUMN_WIDTH then
		-- 	width = width + (lastButtonWidth - MIN_COLUMN_WIDTH)
		-- end

		local pxDelta = width - lastWidth
		local lastButtonWidth = lastButton:GetWidth() - pxDelta

		if lastButtonWidth < MIN_COLUMN_WIDTH then
			local remain = lastButtonWidth - MIN_COLUMN_WIDTH
			width = width + remain
		end

		if abs(width - lastWidth) >= EPSILON then
			lastWidth = width

			button.config.width = width
			button:SetWidth(width or Addon.TableFrame.DEFAULT_COLUMN_WIDTH)

			if self.onColumnResized ~= nil then
				self.onColumnResized(button.column)
			end
		end
	end

	button.resizer = CreateFrame("Frame", nil, button)
	button.resizer:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	button.resizer:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	button.resizer:SetWidth(6)
	button.resizer:EnableMouse(true)
	button.resizer:SetScript("OnEnter", OnEnter)
	button.resizer:SetScript("OnLeave", OnLeave)
	button.resizer:SetScript("OnMouseDown", OnMouseDown)
	button.resizer:SetScript("OnMouseUp",OnMouseUp)
	button.resizer:SetScript("OnUpdate", OnUpdate)

	button.resizer.background = button.resizer:CreateTexture(nil, "OVERLAY")
	button.resizer.background:SetAllPoints()
	button.resizer.background:SetColorTexture(0, 0, 0, 0.3)
	button.resizer.background:Hide()
end

--- @private
--- @param frame TableFrameUI.HeaderButton
function Header:HeaderButton_OnEnter(frame)
	frame.highlight:Show()
end

--- @private
--- @param frame TableFrameUI.HeaderButton
function Header:HeaderButton_OnLeave(frame)
	frame.highlight:Hide()
end

--- @private
--- @param frame TableFrameUI.HeaderButton
--- @param button string
function Header:HeaderButton_OnMouseUp(frame, button)
	if button ~= "RightButton" then
		return
	end

	MenuUtil.CreateContextMenu(frame, function(owner, root)
		root:CreateButton(Addon.L["Add column..."], function()
			local dialog = StaticPopup_Show("LOGSINK_ADD_COLUMN")

			if dialog ~= nil then
				dialog.column = frame.column
			end
		end)

		local remove = root:CreateButton(Addon.L["Remove column"], function()
			Addon.TableFrame:RemoveColumn(frame.config.key)
		end)
		remove:SetEnabled(#self.columns > 1)

		root:CreateButton(Addon.L["Reset columns"], function()
			Addon.TableFrame:ResetColumns()
		end)

		local moveLeft = root:CreateButton(Addon.L["Move left"], function()
			Addon.TableFrame:ReorderColumn(frame.config.key, frame.column - 1)
		end)
		moveLeft:SetEnabled(frame.column > 1)

		local moveRight = root:CreateButton(Addon.L["Move right"], function()
			Addon.TableFrame:ReorderColumn(frame.config.key, frame.column + 1)
		end)
		moveRight:SetEnabled(frame.column < #self.columns)
	end)
end

--- @class TableFrame
local TableFrame = Addon.TableFrame
TableFrame.UI.Header = Header
