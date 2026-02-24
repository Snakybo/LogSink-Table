--- @class FilterOption
--- @field public lhs FilterValue
--- @field public operator FilterOperator
--- @field public rhs FilterValue|FilterValue[]

--- @class FilterValue
--- @field public value string|number
--- @field public type TokenType

--- @class TimeValue
--- @field public value string|number
--- @field public scale? string
--- @field public isAbsolute? boolean

--- @class TimeOption
--- @field public since? TimeValue
--- @field public until? TimeValue

--- @class Token
--- @field public value string|Token[]
--- @field public type TokenType
--- @field public startIndex integer
--- @field public endIndex? integer

--- @class FilterConfiguration
--- @field public timeframe? TimeOption
--- @field public compounds FilterOption[][]

local LibLog = LibStub("LibLog-1.0")

--- @class Addon
local Addon = select(2, ...)

--- @class QueryParser
local QueryParser = {}

--- @enum TokenType
local TokenType = {
	Whitespace = "whitespace",
	Number = "number",
	Boolean = "boolean",
	String = "string",
	Property = "property",
	Nil = "nil",
	Operator = "operator",
	Table = "table",
	Comma = "comma",
	Keyword = "keyword",
	Time = "time"
}

--- @enum FilterOperator
local FilterOperator = {
	EQ = "=",
	NOT_EQ = "~=",
	LT = "<",
	LTE = "<=",
	GT = ">",
	GTE = ">=",
	IN = "IN",
	NOT_IN = "NOT IN",
	LIKE = "LIKE",
	NOT_LIKE = "NOT LIKE"
}

--- @type table<string, integer>
local TimeframeScales = {
	second = 1,
	seconds = 1,
	minute = 60,
	minutes = 60,
	hour = 3600,
	hours = 3600,
	day = 86400,
	days = 86400
}

local OR = "OR"
local AND = "AND"
local SINCE = "SINCE"
local UNTIL = "UNTIL"
local NOT = "NOT"
local NIL = "NIL"
local AGO = "ago"
local LEVEL = "level"
local TRUE = "true"
local FALSE = "false"

--- @type table<string, boolean>
local operatorsCache = {}
for _, operator in pairs(FilterOperator) do
	operatorsCache[operator] = true
end

--- @param value string
--- @return string
local function CompilePattern(value)
	local pattern = value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	pattern = pattern:gsub("%%%.%%%*", ".*")
	return "^" .. pattern .. "$"
end

--- @param value string
--- @return integer|string
local function TranslateLevel(value)
	for level, label in pairs(LibLog.labels) do
		if label == value then
			return level
		end
	end

	return tonumber(value) or value
end

--- @param token Token
--- @param attributeToken? Token
--- @param operatorToken? Token
local function SanitizeTokenValue(token, attributeToken, operatorToken)
	if attributeToken ~= nil and attributeToken.type == TokenType.Property and attributeToken.value == LEVEL then
		return TranslateLevel(token.type == TokenType.String and token.value:sub(2, -2) or token.value)
	end

	if operatorToken ~= nil and (operatorToken.value == FilterOperator.LIKE or operatorToken.value == FilterOperator.NOT_LIKE) then
		return CompilePattern(token.value:sub(2, -2))
	end

	if token.type == TokenType.String then
		return token.value:sub(2, -2)
	elseif token.type == TokenType.Number then
		return tonumber(token.value)
	elseif token.type == TokenType.Boolean then
		return token.value == "true"
	end

	if token.type == TokenType.Keyword or token.type == TokenType.Operator then
		return token.value:upper()
	end

	return token.value
end

--- @param filter string
--- @param ignoreVisualTokens? boolean
--- @param depth? integer
--- @return Token[] tokens The created tokens
--- @return string? error If set, the tokenization process encountered an error and could not be fully completed
function QueryParser:Tokenize(filter, ignoreVisualTokens, depth)
	local keywords = {
		SINCE = true,
		UNTIL = true,
		AND = true,
		OR = true
	}

	local operators = {
		IN = true,
		LIKE = true,
		NOT = true
	}

	local visualTokens = {
		[TokenType.Whitespace] = true,
		[TokenType.Comma] = true
	}

	--- @type Token[]
	local result = {}
	local cursor = 1

	depth = depth or 1

	--- @return Token?
	local function GetPreviousNonVisualToken()
		for i = #result, 1, -1 do
			if not visualTokens[result[i].type] then
				return result[i]
			end
		end

		return nil
	end

	while cursor <= #filter do
		local char = filter:sub(cursor, cursor)

		--- @type Token
		local token

		if char == " " then
			local _, whitespaceEnd = filter:find("^%s+", cursor)

			token = {
				type = TokenType.Whitespace,
				value = filter:sub(cursor, whitespaceEnd),
				startIndex = cursor,
				endIndex = whitespaceEnd
			}
		elseif char == '"' or char == "'" then
			local _, endIndex = filter:find('^%b' .. char .. char, cursor)
			if endIndex == nil then
				return result, "cannot find end of string"
			end

			token = {
				type = TokenType.String,
				value = filter:sub(cursor, endIndex),
				startIndex = cursor,
				endIndex = endIndex
			}
		elseif char == "{" then
			if depth > 1 then
				return result, "cannot nest tables"
			end

			local _, endIndex = filter:find('^%b{}', cursor)
			if endIndex == nil then
				return result, "cannot find end of table"
			end

			local innerTokens, innerErr = self:Tokenize(filter:sub(cursor + 1, endIndex - 1), ignoreVisualTokens, depth + 1)
			if innerErr ~= nil then
				return result, "cannot parse table: " .. innerErr
			end

			for _, inner in ipairs(innerTokens) do
				inner.startIndex = cursor + inner.startIndex
				inner.endIndex = cursor + inner.endIndex
			end

			if not ignoreVisualTokens then
				table.insert(innerTokens, 1, {
					type = TokenType.Table,
					value = "{",
					startIndex = cursor,
					endIndex = cursor
				})

				table.insert(innerTokens, {
					type = TokenType.Table,
					value = "}",
					startIndex = endIndex,
					endIndex = endIndex
				})
			end

			token = {
				type = TokenType.Table,
				value = innerTokens,
				startIndex = cursor,
				endIndex = endIndex
			}
		elseif char == "," then
			token = {
				type = TokenType.Comma,
				value = ",",
				startIndex = cursor,
				endIndex = cursor
			}
		elseif char:match("%d") or (char == "-" and filter:sub(cursor + 1, cursor + 1):match("%d")) then
			local _, endIndex = filter:find('^[%-%d%.%:]+', cursor)

			token = {
				type = TokenType.Number,
				value = filter:sub(cursor, endIndex),
				startIndex = cursor,
				endIndex = endIndex
			}

			local previous = GetPreviousNonVisualToken()

			if previous ~= nil and previous.type == TokenType.Keyword then
				local upper = previous.value:upper()

				if upper == SINCE or upper == UNTIL then
					token.type = TokenType.Time
				end
			end
		elseif char:match("[%a%_]") then
			local _, endIndex = filter:find('^[%a%.%d%:%_]+', cursor)

			token = {
				type = TokenType.Property,
				value = filter:sub(cursor, endIndex),
				startIndex = cursor,
				endIndex = endIndex
			}

			local lower = token.value:lower()
			local upper = token.value:upper()
			local previous = GetPreviousNonVisualToken()

			if keywords[upper] then
				token.type = TokenType.Keyword
			elseif operators[upper] then
				token.type = TokenType.Operator
			elseif lower == TRUE or lower == FALSE then
				token.type = TokenType.Boolean
			elseif previous ~= nil and previous.type == TokenType.Time and (TimeframeScales[lower] or lower == AGO) then
				token.type = TokenType.Time
			elseif upper == NIL then
				token.type = TokenType.Nil
			elseif tonumber(token.value) ~= nil then
				token.type = TokenType.Number
			end
		else
			local _, endIndex = filter:find('^[^%s%w"\'{}]+', cursor)
			if endIndex ~= nil then
				token = {
					type = TokenType.Operator,
					value = filter:sub(cursor, endIndex),
					startIndex = cursor,
					endIndex = endIndex
				}
			end
		end

		if token ~= nil then
			if not ignoreVisualTokens or not visualTokens[token.type] then
				table.insert(result, token)
			end

			cursor = token.endIndex + 1
		else
			cursor = cursor + 1
		end
	end

	return result
end

--- @param tokens Token[]
--- @return FilterConfiguration|string
function QueryParser:ParseTokens(tokens)
	--- @type FilterConfiguration
	local result = {
		compounds = {}
	}

	if tokens == nil or #tokens == 0 then
		return result
	end

	local current = 1

	--- @type FilterOption?
	local active

	table.insert(result.compounds, {})

	while current <= #tokens do
		local token = tokens[current]

		if token.type == TokenType.Keyword then
			local upper = token.value:upper()

			if upper == OR then
				active = nil
				table.insert(result.compounds, {})
			elseif upper == AND then
				active = nil
			elseif upper == SINCE or upper == UNTIL then
				local key = upper:lower()

				local valueToken = tokens[current + 1]
				local scaleToken = tokens[current + 2]
				local agoToken = tokens[current + 3]
				local step = 1

				--- @type TimeValue?
				local timeframe

				if valueToken ~= nil and valueToken.type == TokenType.Time and scaleToken ~= nil and scaleToken.type == TokenType.Time then
					timeframe = {
						value = tonumber(valueToken.value),
						scale = scaleToken.value
					}

					step = (agoToken ~= nil and agoToken.type == TokenType.Time) and 3 or 2
				elseif valueToken ~= nil and valueToken.type == TokenType.Time then
					timeframe = {
						value = valueToken.value,
						isAbsolute = true
					}
				end

				if timeframe == nil or timeframe.value == nil then
					return "unable to parse time restrictor"
				elseif tonumber(timeframe.value) and tonumber(timeframe.value) <= 0 then
					return "invalid time value: " .. tostring(timeframe.value)
				elseif TimeframeScales[timeframe.scale] == nil and not timeframe.isAbsolute then
					return "invalid time scale: " .. tostring(timeframe.scale)
				end

				result.timeframe = result.timeframe or {}
				result.timeframe[key] = timeframe

				current = current + step
			else
				return "Unknown keyword: " .. upper
			end
		else
			if active ~= nil then
				return "unfinished compound, did you forget AND/OR?"
			end

			local operatorToken = tokens[current + 1]
			local valueToken = tokens[current + 2]
			local step = 2

			if operatorToken ~= nil and operatorToken.value == NOT then
				operatorToken.endIndex = valueToken.endIndex
				operatorToken.value = operatorToken.value .. " " .. valueToken.value

				valueToken = tokens[current + 3]
				step = 3
			end

			if operatorToken == nil then
				return "cannot parse operator"
			elseif not operatorsCache[operatorToken.value] then
				return "invalid operator: " .. operatorToken.value
			elseif valueToken == nil then
				return "cannot parse value"
			elseif (operatorToken.value == FilterOperator.IN or operatorToken.value == FilterOperator.NOT_IN) and
				   valueToken.type ~= TokenType.Table and valueToken.type ~= TokenType.Property then
				return "[NOT] IN can only be used when the right-hand side is a table or property"
			elseif (operatorToken.value == FilterOperator.LIKE or operatorToken.value == FilterOperator.NOT_LIKE) and
				   valueToken.type ~= TokenType.String and valueToken.type ~= TokenType.Property then
				return "[NOT] LIKE can only be used when the right-hand side is a string or property"
			end

			active = {
				lhs = {
					value = SanitizeTokenValue(token),
					type = token.type
				},
				operator = operatorToken.value,
				rhs = nil
			}

			if valueToken.type ~= TokenType.Table then
				active.rhs = {
					value = SanitizeTokenValue(valueToken, token, operatorToken),
					type = valueToken.type
				}
			else
				active.rhs = {}

				for _, value in ipairs(valueToken.value) do
					table.insert(active.rhs, {
						value = SanitizeTokenValue(value, token, operatorToken),
						type = value.type
					})
				end
			end

			table.insert(result.compounds[#result.compounds], active)

			current = current + step
		end

		current = current + 1
	end

	for i = #result.compounds, 1, -1 do
		if #result.compounds[i] == 0 then
			table.remove(result.compounds, i)
		end
	end

	return result
end

--- @param filter? string
--- @return FilterConfiguration|string
function QueryParser:ParseString(filter)
	--- @type FilterConfiguration
	local result = {
		compounds = {}
	}

	if filter == nil or #filter == 0 then
		return result
	end

	local tokens, error = self:Tokenize(filter, true)
	if error ~= nil then
		return error
	end

	return self:ParseTokens(tokens)
end

function QueryParser:TestSuite()
	--- @type LibLog-1.0.LogMessage
	local entry = {
		message = "My character name is Arthas on realm Frostmourne",
		template = "My character name is {charName} on realm {realmName}",
		addon = "MyAddon",
		level = LibLog.LogLevel.INFO,
		time = time() - (15 * 60),
		sequenceId = 1,
		properties = {
			charName = "Arthas",
			realmName = "Frostmourne",
			health = 15,
			mana = 20,
			alive = true,
			party = {
				"Arthas",
				"Khadgar"
			}
		}
	}

	--- @param text string
	--- @param expected boolean
	local function Test(text, expected)
		local config = self:ParseString(text)

		if type(config) == "string" then
			error("|cffffff00" .. text .. "|r |cffff0000FAIL:|r " .. config, 2)
			return
		end

		local filter = LogSinkTable:CreateFilterFromConfig(config)
		local result = filter:Evaluate(entry)

		if result ~= expected then
			error("|cffffff00" .. text .. "|r |cffff0000FAIL:|r expected " .. tostring(expected) .. " but got " .. tostring(result), 2)
		else
			print("|cffffff00" .. text .. "|r |cff00ff00PASS")
		end

	end

	--- @param text string
	--- @param expected boolean
	local function TestError(text, expected)
		local config = self:ParseString(text)

		if expected and type(config) == "string" then
			print("|cffffff00" .. text .. "|r |cffff0000FAIL:|r expected valid filter but got: " .. config)
		elseif expected then
			print("|cffffff00" .. text .. "|r |cff00ff00PASS")
		elseif not expected and type(config) == "string" then
			print("|cffffff00" .. text .. "|r |cff00ff00PASS:|r " .. config)
		else
			error("|cffffff00" .. text .. "|r |cffff0000FAIL:|r expected error but got valid filter")
		end
	end

	--- @param seconds integer
	--- @return string
	local function GetAbsoluteTime(seconds)
		local result = date("*t", time() - seconds)
		return string.format("%02d:%02d:%02d", result.hour, result.min, result.sec)
	end

	-- test all logic operators
	Test('charName = "Arthas"', true)
	Test("charName = 'Arthas'", true)
	Test('charName = realmName', false)
	Test('charName ~= "Arthas"', false)
	Test("charName ~= 'Arthas'", false)
	Test('charName ~= realmName', true)
	Test('health < 10', false)
	Test('health < mana', true)
	Test('health <= 15', true)
	Test('health <= mana', true)
	Test('health > 10', true)
	Test('health > mana', false)
	Test('health >= 15', true)
	Test('health >= mana', false)
	Test('charName IN { "Arthas" }', true)
	Test("charName IN { 'Arthas' }", true)
	Test('charName IN { "Khadgar", "Thrall" }', false)
	Test('charName IN party', true)
	Test('charName IN raid', false)
	Test('nil IN party', false)
	Test('raid IN { "Arthas" }', false)
	Test('raid IN party', false)
	Test('health IN { 10, 15, 30 }', true)
	Test('health IN { 10, health, 30 }', true)
	Test('health IN   { 10, health, 30, "str" }', true)
	Test('charName NOT IN { "Arthas" }', false)
	Test('charName NOT IN { "Khadgar", "Thrall" }', true)
	Test('charName NOT IN party', false)
	Test('charName NOT IN raid', false)
	Test('nil NOT IN party', false)
	Test('raid NOT IN { "Arthas" }', false)
	Test('raid NOT IN party', false)
	Test('health NOT IN { 10, 15, 30 }', false)
	Test('health NOT IN { 10, health, 30 }', false)
	Test('charName LIKE "Art.*"', true)
	Test('charName LIKE mana', false)
	Test('charName LIKE ".*thas"', true)
	Test('charName LIKE ".*ghar"', false)
	Test('charName NOT LIKE "Art.*"', false)
	Test('charName NOT LIKE mana', false)
	Test('charName NOT LIKE ".*thas"', false)
	Test('charName NOT LIKE ".*ghar"', true)
	Test('minutes = 60', false)
	Test('SINCE 360 seconds ago', false)
	Test('SINCE 1 minute ago', false)
	Test('SINCE 1 hour ago', true)
	Test('SINCE ' .. GetAbsoluteTime(1200), true) -- 20 minutes ago in wall-time
	Test('SINCE ' .. GetAbsoluteTime(300), false) -- 5 minutes ago in wall-time
	Test('SINCE ' .. GetAbsoluteTime(-300), true) -- 5 minutes ahead in wall-time
	Test('SINCE ' .. GetAbsoluteTime(82800), true) -- 23 hours ago in wall-time
	Test('UNTIL 14 minutes ago', true)
	Test('UNTIL ' .. GetAbsoluteTime(1200), false) -- 20 minutes ago in wall-time
	Test('UNTIL ' .. GetAbsoluteTime(300), true) -- 5 minutes ago in wall-time
	Test('UNTIL ' .. GetAbsoluteTime(-300), false) -- 5 minutes ahead in wall-time
	Test('UNTIL ' .. GetAbsoluteTime(82800), false) -- 23 hours ahead in wall-time
	Test('SINCE 1 hour ago UNTIL 10 minutes ago', true)
	Test('SINCE ' .. GetAbsoluteTime(1200) .. ' UNTIL ' .. GetAbsoluteTime(300), true) -- 20 minutes ago in wall-time to 5 minutes ago in wall-time
	Test('level = 3', true)
	Test('level = "INF"', true)
	Test('level > 2', true)
	Test('level = "WRN"', false)
	Test('level <= "WRN"', true)
	Test('charName = nil', false)
	Test('charName ~= nil', true)
	Test('charName > 24', false)
	Test('alive = true', true)
	Test('alive ~= true', false)
	Test('alive = false', false)
	Test('charName = party.1', true)
	Test('charName = party.2', false)
	Test('charName = party', false)

	-- test for non-perfectly structured or malformed inputs
	TestError('charName="Arthas"', true)
	TestError('mana=14', true)
	TestError('health IN {15,"Arthas",\'arthas\',name,mana}', true)
	TestError('charName="Arthas', false)
	TestError('charName IN { "Arthas" ', false)
	TestError('charName IN { "Arthas }', false)
	TestError('charName % 15', false)
	TestError('charName invalid 15', false)
	TestError('charName = ""', true)
	TestError('charName 15', false)
	TestError('charName = ', false)
	TestError('charName = AND charName ~= "Khadgar"', false)
	TestError('charName IN 15', false)
	TestError('charName IN mana', true)
	TestError('charName IN "Arthas"', false)
	TestError('charName IN nil', false)
	TestError('charName LIKE 15', false)
	TestError('charName LIKE { "Arthas" }', false)
	TestError('SINCE', false)
	TestError('SINCE charName = "Arthas"', false)
	TestError('SINCE -5 minutes ago', false)
	TestError('SINCE 10 xyz ago', false)
	TestError('SINCE 10 minutes', true)
	TestError('AND AND AND AND', true)
	TestError('OR OR OR OR', true)
	TestError('\\', false)
	TestError('test', false)
	TestError('some random text', false)
	TestError('more. complex, random; text, how does it do?', false)
	TestError('IN', false)
	TestError(' ', true)
	TestError('1', false)

	print("|cff00ff00== ALL TESTS PASSED ==")
end

--- @param filter string
--- @param ignoreVisualTokens? boolean
--- @return Token[] tokens The created tokens
--- @return string? error If set, the tokenization process encountered an error and could not be fully completed
function LogSinkTable:Tokenize(filter, ignoreVisualTokens)
	return QueryParser:Tokenize(filter, ignoreVisualTokens)
end

Addon.QueryParser = QueryParser
Addon.TokenType = TokenType
Addon.FilterOperator = FilterOperator
Addon.TimeframeScales = TimeframeScales
