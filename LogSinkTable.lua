-- LogManager, an addon to configure logging levels for addons.
-- Copyright (C) 2026  Kevin Krol
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local AceConsole = LibStub("AceConsole-3.0")
local LibLog = LibStub("LibLog-1.0")

--- @class Addon
local Addon = select(2, ...)
Addon.L = LibStub("AceLocale-3.0"):GetLocale("LogSinkTable")

--- @class LogSinkTable : AceAddon, AceEvent-3.0, LibLog-1.0.Logger
LogSinkTable = LibStub("AceAddon-3.0"):NewAddon("LogSinkTable", "AceEvent-3.0", "LibLog-1.0")

--- @param message LibLog-1.0.LogMessage
local function OnLogReceived(message)
	if message.addon == nil then
		return
	end

	Addon.Buffer:Add(message)
end

--- @param input string
local function HandleChatCommand(input)
	--- @type string[]
	local args = {}
	local start = 1

	while true do
		local arg, next = AceConsole:GetArgs(input, 1, start)
		table.insert(args, arg)

		if next == 1e9 then
			break
		end

		start = next
	end

	if #args == 0 then
		Addon.Window:Open()
	elseif #args >= 1 then
		if args[1] == "test" then
			Addon.QueryParser:TestSuite()
		elseif args[1] == "mock" and tonumber(args[2]) ~= nil then
			Addon.Buffer:GenerateMockData(tonumber(args[2]))
		elseif args[1] == "mock" then
			Addon.Buffer:GenerateMockData(Addon.Buffer:IsMockModeEnabled() and 0 or 5000)
		end
	end
end

function LogSinkTable:OnInitialize()
	--- @class LogSinkTableDB
	--- @field public currentFilter? string
	LogSinkTableDB = LogSinkTableDB or {}

	AceConsole:RegisterChatCommand("logs", HandleChatCommand)

	if LogSinkSavedVariables ~= nil and LogSinkSavedVariables.GetBufferWhenAvailable ~= nil then
		LogSinkSavedVariables:GetBufferWhenAvailable(function(buffer)
			Addon.Buffer:SetBuffer(buffer)
			self:LogVerbose("Restored {count} messages from saved variables", #buffer)
		end)
	end
end

LibLog:RegisterSink(LogSinkTable.name, OnLogReceived)
