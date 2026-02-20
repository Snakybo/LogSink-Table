-- LogManager, an addon to configure log levels for addons.
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

local L = LibStub("AceLocale-3.0"):NewLocale("LogSinkTable", "enUS", true)

if not L then
	return
end

L["Time"] = true
L["Level"] = true
L["Addon"] = true
L["Message"] = true
L["Log Viewer"] = true
L["Processed %d entries and found %d matches in %.2fms"] = true
L["Search more..."] = true
L["Go to live"] = true
L["No new entries"] = true
