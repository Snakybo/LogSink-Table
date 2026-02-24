--- @class Addon
local Addon = select(2, ...)

--- @class Filter : FilterConfiguration
local FilterTemplate = {
	compounds = {}
}

--- @param frame TimeValue
--- @return integer
local function GetSecondsFromTimeValue(frame)
	if frame.isAbsolute then
		local dateNow = date("*t")
		local hour, min, sec = frame.value:match("(%d+)%:(%d+)%:?(%d*)")
		hour = tonumber(hour)
		min = tonumber(min)
		sec = tonumber(sec)

		local target = (hour * 3600) + (min * 60) + (sec or 0)
		local current = (dateNow.hour * 3600) + (dateNow.min * 60) + dateNow.sec
		local delta = current - target

		if delta < 0 then
			delta = delta + 86400
		end

		return delta
	end

	local scale = Addon.TimeframeScales[frame.scale]
	return frame.value * scale
end

--- @param entry LibLog-1.0.LogMessage
--- @param option FilterValue
--- @return unknown
local function GetOptionValue(entry, option)
	if option.type == Addon.TokenType.Nil then
		return nil
	end

	if option.type == Addon.TokenType.Property then
		return entry[option.value] or entry.properties[option.value]
	end

	return option.value
end

--- @param entry LibLog-1.0.LogMessage
--- @param option FilterValue|FilterValue[]
--- @return FilterValue[]?
local function GetOptionTableValue(entry, option)
	if option.type == Addon.TokenType.Property then
		local result = {}
		local values = GetOptionValue(entry, option)

		if values == nil then
			return nil
		end

		for _, value in pairs(values) do
			table.insert(result, {
				value = value,
				type = type(value) == "number" and Addon.TokenType.Number or Addon.TokenType.String
			})
		end

		return result
	end

	return option
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsEqualTo(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionValue(entry, rhs)

	if left == nil and right == nil then
		return false
	end

	return left == right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsNotEqualTo(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionValue(entry, rhs)

	if left == nil and right == nil then
		return false
	end

	return left ~= right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsLessThan(entry, lhs, rhs)
	local left = tonumber(GetOptionValue(entry, lhs)) or 0
	local right = tonumber(GetOptionValue(entry, rhs)) or -1
	return left < right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsLessThanOrEqualTo(entry, lhs, rhs)
	local left = tonumber(GetOptionValue(entry, lhs)) or 0
	local right = tonumber(GetOptionValue(entry, rhs)) or -1
	return left <= right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsGreaterThan(entry, lhs, rhs)
	local left = tonumber(GetOptionValue(entry, lhs)) or -1
	local right = tonumber(GetOptionValue(entry, rhs)) or 0
	return left > right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue
--- @return boolean
local function IsGreaterThanOrEqualTo(entry, lhs, rhs)
	local left = tonumber(GetOptionValue(entry, lhs)) or -1
	local right = tonumber(GetOptionValue(entry, rhs)) or 0
	return left >= right
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue|FilterValue[]
--- @return boolean
local function IsIn(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionTableValue(entry, rhs)

	if left == nil or right == nil then
		return false
	end

	for _, option in pairs(right) do
		local value = GetOptionValue(entry, option)

		if left == value then
			return true
		end
	end

	return false
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue|FilterValue[]
--- @return boolean
local function IsNotIn(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionTableValue(entry, rhs)

	if left == nil or right == nil then
		return false
	end

	for _, option in pairs(right) do
		local value = GetOptionValue(entry, option)

		if left == value then
			return false
		end
	end

	return true
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue|FilterValue[]
--- @return boolean
local function IsLike(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionValue(entry, rhs)

	if type(left) ~= "string" or type(right) ~= "string" then
		return false
	end

	return string.find(left, right) ~= nil
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param rhs FilterValue|FilterValue[]
--- @return boolean
local function IsNotLike(entry, lhs, rhs)
	local left = GetOptionValue(entry, lhs)
	local right = GetOptionValue(entry, rhs)

	if type(left) ~= "string" or type(right) ~= "string" then
		return false
	end

	return string.find(left, right) == nil
end

--- @param entry LibLog-1.0.LogMessage
--- @param lhs FilterValue
--- @param operator FilterOperator
--- @param rhs FilterValue|FilterValue[]
local function Compare(entry, lhs, operator, rhs)
	local comparators = {
		[Addon.FilterOperator.EQ] = IsEqualTo,
		[Addon.FilterOperator.NOT_EQ] = IsNotEqualTo,
		[Addon.FilterOperator.LT] = IsLessThan,
		[Addon.FilterOperator.LTE] = IsLessThanOrEqualTo,
		[Addon.FilterOperator.GT] = IsGreaterThan,
		[Addon.FilterOperator.GTE] = IsGreaterThanOrEqualTo,
		[Addon.FilterOperator.IN] = IsIn,
		[Addon.FilterOperator.NOT_IN] = IsNotIn,
		[Addon.FilterOperator.LIKE] = IsLike,
		[Addon.FilterOperator.NOT_LIKE] = IsNotLike
	}

	local comparator = comparators[operator]
	if comparator ~= nil then
		return comparator(entry, lhs, rhs)
	end

	return false
end

--- @param entry LibLog-1.0.LogMessage
--- @return boolean
function FilterTemplate:Evaluate(entry)
	if entry == nil then
		return false
	end

	if not self:EvaluateTimeframe(entry) then
		return false
	end

	if #self.compounds > 0 then
		for _, compound in ipairs(self.compounds) do
			if self:EvaluateCompound(entry, compound) then
				return true
			end
		end

		return false
	end

	return true
end

--- @private
--- @param entry LibLog-1.0.LogMessage
--- @return boolean
function FilterTemplate:EvaluateTimeframe(entry)
	if self.timeframe == nil then
		return true
	end

	local delta = time() - entry.time

	if self.timeframe.since ~= nil then
		local seconds = GetSecondsFromTimeValue(self.timeframe.since)

		if abs(delta) > seconds then
			return false
		end
	end

	if self.timeframe["until"] ~= nil then
		local seconds = GetSecondsFromTimeValue(self.timeframe["until"])

		if abs(delta) < seconds then
			return false
		end
	end

	return true
end

--- @private
--- @param entry LibLog-1.0.LogMessage
--- @param compound FilterOption[]
function FilterTemplate:EvaluateCompound(entry, compound)
	for _, option in ipairs(compound) do
		if not Compare(entry, option.lhs, option.operator, option.rhs) then
			return false
		end
	end

	return true
end

--- @param filter? string
--- @return Filter|string
function LogSinkTable:CreateFilterFromString(filter)
	if filter == nil or #filter == 0 then
		return Mixin({}, FilterTemplate)
	end

	local config = Addon.QueryParser:ParseString(filter)
	if type(config) == "string" then
		return config
	end

	return self:CreateFilterFromConfig(config)
end

--- @param tokens Token[]
--- @return Filter|string
function LogSinkTable:CreateFilterFromTokens(tokens)
	if tokens == nil or #tokens == 0 then
		return Mixin({}, FilterTemplate)
	end

	local config = Addon.QueryParser:ParseTokens(tokens)
	if type(config) == "string" then
		return config
	end

	return self:CreateFilterFromConfig(config)
end

--- @param config FilterConfiguration
--- @return Filter
function LogSinkTable:CreateFilterFromConfig(config)
	return Mixin({}, FilterTemplate, config)
end
