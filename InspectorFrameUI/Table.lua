--- @class Addon
local Addon = select(2, ...)

--- @class InspectorFrameUI.ElementData
--- @field public key string
--- @field public value unknown
--- @field public keyWidth? number
--- @field public height? number

--- @class InspectorFrameUI.TableRow : Frame
--- @field public Key FontString
--- @field public Value FontString

--- @class InspectorFrameUI.Table : Frame
--- @field public dataProvider DataProviderMixin
--- @field public scrollBar MinimalScrollBar
--- @field public scrollBox WowScrollBoxList
local Table = {}

local COLOR_SCHEME = {
	["table"] = "ff808080",
	["tableKey"] = "ffffa64d",
	["string"] = "fffff9b0",
	["number"] = "ff38ff70",
	["boolean"] = "ff99ff00",
	["nil"] = "ffff77ff"
}

local ROW_HEIGHT = 22

--- @param data LibLog-1.0.LogMessage
--- @param prefix? string
--- @param result? InspectorFrameUI.ElementData[]
--- @return InspectorFrameUI.ElementData[]
local function FlattenData(data, prefix, result)
	result = result or {}
	prefix = prefix and (prefix .. ".") or ""

	for k, v in pairs(data) do
		local path = string.gsub(prefix .. tostring(k), "^properties%.", "")

		if type(v) == "table" then
			FlattenData(v, path, result)
		elseif type(v) == "nil" then
			-- ignore nils
		else
			table.insert(result, {
				key = path,
				value = v
			})
		end
	end

	return result
end

--- @param string unknown
--- @param color string
--- @return string
local function Colorize(string, color)
	return "|c" .. color .. tostring(string) .. "|r"
end

--- @param value unknown
--- @return string
local function Serialize(value)
	return Colorize(value, COLOR_SCHEME[type(value)] or COLOR_SCHEME["string"])
end

--- @param parent Frame
--- @return InspectorFrameUI.Table
function Table.Create(parent)
	local base = CreateFrame("Frame", nil, parent)

	local result = Mixin(base, Table)
	result:Init()

	return result
end

--- @param data LibLog-1.0.LogMessage
function Table:SetData(data)
	local flattened = FlattenData(data)

	local width = self.scrollBox:GetWidth()

	for i = 1, #flattened do
		local item = flattened[i]

		self.measureText:SetWidth(0)
		self.measureText:SetText(item.key)
		item.keyWidth = min(width * 0.4, self.measureText:GetStringWidth())

		self.measureText:SetWidth(width - item.keyWidth)
		self.measureText:SetText(tostring(item.value))

		local height = self.measureText:GetStringHeight()
		item.height = ceil(height / ROW_HEIGHT) * ROW_HEIGHT
	end

	self.dataProvider:Flush()
	self.dataProvider:InsertTable(flattened)
end

--- @private
function Table:Init()
	self.scrollBar = CreateFrame("EventFrame", nil, self, "MinimalScrollBar")
    self.scrollBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, 0)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 0)

	self.scrollBox = CreateFrame("Frame", "sb", self, "WowScrollBoxList")
    self.scrollBox:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    self.scrollBox:SetPoint("BOTTOMRIGHT", self.scrollBar, "BOTTOMLEFT", -5, 0)

	self.measureText = self:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	self.measureText:Hide()

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtentCalculator(function(...) return self:GetRowHeight(...) end)
	view:SetElementInitializer("LogInspectorRowTemplate", function(...) self:SetupRow(...) end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)

	self.dataProvider = CreateDataProvider()
	self.dataProvider:SetSortComparator(function(l, r)
		return l.key < r.key
	end, true)

    self.scrollBox:SetDataProvider(self.dataProvider)
end

--- @private
--- @param index integer
function Table:GetRowHeight(index)
	return self.dataProvider:Find(index).height
end

--- @private
--- @param frame InspectorFrameUI.TableRow
--- @param data InspectorFrameUI.ElementData
function Table:SetupRow(frame, data)
	frame.Key:SetWidth(data.keyWidth)
	frame.Key:SetText(data.key)

	frame.Value:SetText(Serialize(data.value))

	frame:SetScript("OnMouseDown", function(_, button) self:Row_OnMouseDown(frame, button, data) end)
end

--- @param frame InspectorFrameUI.TableRow
--- @param button string
--- @param data InspectorFrameUI.ElementData
function Table:Row_OnMouseDown(frame, button, data)
	if button ~= "RightButton" then
		return
	end

	MenuUtil.CreateContextMenu(frame, function(owner, root)
		root:CreateButton(Addon.L["Copy key"], function()
			StaticPopup_Show("LOGSINK_COPY_TEXT", nil, nil, tostring(data.key))
		end)

		root:CreateButton(Addon.L["Copy value"], function()
			StaticPopup_Show("LOGSINK_COPY_TEXT", nil, nil, tostring(data.value))
		end)

		root:CreateButton(Addon.L["Add filter"], function()
			local filter = data.key .. " = "

			if type(data.value) == "string" then
				filter = filter .. '"' .. data.value .. '"'
			else
				filter = filter .. tostring(data.value)
			end

			Addon.TableFrame:AppendQueryString(filter)
		end)

		root:CreateButton(Addon.L["Exclude value"], function()
			local filter = data.key .. " ~= "

			if type(data.value) == "string" then
				filter = filter .. '"' .. data.value .. '"'
			else
				filter = filter .. tostring(data.value)
			end

			Addon.TableFrame:AppendQueryString(filter)
		end)
	end)
end

--- @class InspectorFrame
local InspectorFrame = Addon.InspectorFrame
InspectorFrame.UI.Table = Table
