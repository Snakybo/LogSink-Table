--- @class Addon
local Addon = select(2, ...)

--- @class BufferReader
--- @field public SetBuffer fun(self: BufferReader, buffer: LibLog-1.0.LogMessage[])

--- @class Buffer
--- @field private all LibLog-1.0.LogMessage[]
--- @field private readers ChunkedBufferReader[]
--- @field private mock boolean
local Buffer = {
	all = {},
	readers = {},
	mock = false
}

--- @param message LibLog-1.0.LogMessage
function Buffer:Add(message)
	if self.mock then
		return
	end

	table.insert(self.all, message)
end

--- @param buffer LibLog-1.0.LogMessage[]
function Buffer:SetBuffer(buffer)
	self.all = buffer

	for i = 1, #self.readers do
		self.readers[i]:SetBuffer(buffer)
	end
end

--- @param count? integer
function Buffer:GenerateMockData(count)
	local result = {}

	if count == nil or count == 0 then
		if self.mock then
			self:SetBuffer(result)
			self.mock = false

			LogSinkTable:LogInfo("Cleared mock-mode")
		end

		return
	end

	local addons = {
		"MyAddon", "MyAddon-Core", "MyAddon-UI", "Cyber", "Cyber-Backend",
		"QuestHelper", "DBM-Core", "DBM-Raid", "Details", "Details-TinyThreat",
		"WeakAuras", "WeakAurasOptions", "BigWigs", "Auctioneer", "Gatherer",
		"Bartender4", "OmniCC", "Recount", "Bagnon", "HealBot"
	}

	local charNames = {
		"Arthas", "Khadgar", "Jaina", "Thrall", "Sylvanas", "Illidan", "Anduin",
		"Uther", "Baine", "Tyrande", "Malfurion", "Guldan", "Hellscream", "Varian",
		"Magni", "Brann", "Valeera", "Rexxar", "Liadrin", "Teron"
	}

	local realms = {
		"Frostmourne", "Silvermoon", "Illidan", "Area 52", "Stormrage", "Kazzak",
		"Tarren Mill", "Draenor", "Ragnaros", "Tichondrius", "Zul'jin", "Mal'Ganis",
		"Sargeras", "Proudmoore", "Hyjal", "Benediction", "Faerlina", "Whitemane",
		"Gehennas", "Firemaw"
	}

	--- @generic T
	--- @param tbl T[]
	--- @return T
	local function Randomize(tbl)
		return tbl[math.random(1, #tbl)]
	end

	local BUDGET_MS = 33

	local remaining = count
	local lastUpdateMessage = 0

	self.mockFrame = self.mockFrame or CreateFrame("Frame")
	self.mockFrame:SetScript("OnUpdate", function()
		local start = debugprofilestop()

		while (debugprofilestop() - start < BUDGET_MS and remaining > 0) do
			--- @type LibLog-1.0.LogMessage
			local entry = {
				message = "",
				addon = Randomize(addons),
				level = math.random(1, 6),
				time = time() - (count - remaining),
				sequenceId = 1,
				properties = {}
			}

			if math.random() > 0.5 then
				entry.properties.charName = Randomize(charNames)
				entry.message = entry.message .. "My name is " .. entry.properties.charName .. " "
			end

			if math.random() > 0.5 then
				entry.properties.realmName = Randomize(realms)
				entry.message = entry.message .. "My realm is " .. entry.properties.realmName .. " "
			end

			if math.random() > 0.5 then
				entry.properties.health = math.random(0, 1000)
			end

			if math.random() > 0.5 then
				entry.properties.mana = math.random(0, 500)
			end

			if math.random() > 0.5 then
				local partySize = math.random(1, 5)
				local party = {}

				while #party < partySize do
					local value = Randomize(charNames)

					if not tContains(party, value) then
						table.insert(party, value)
					end
				end

				entry.properties.party = party
			end

			if #entry.message == 0 then
				entry.message = "Message " .. (count - remaining) .. " out of " .. count
			else
				entry.message = entry.message:trim()
			end

			table.insert(result, 1, entry)
			remaining = remaining - 1
		end

		if remaining <= 0 then
			self.mockFrame:Hide()
			self.mock = true
			self:SetBuffer(result)

			LogSinkTable:LogInfo("Generated {count} mock log entries", count)
		elseif debugprofilestop() - lastUpdateMessage > 2500 then
			lastUpdateMessage = debugprofilestop()
			local progress = (1 - (remaining / count)) * 100
			LogSinkTable:LogInfo("Generating {count} mock log entries, {progress}% complete", count, progress)
		end
	end)
	self.mockFrame:Show()
end

function Buffer:IsMockModeEnabled()
	return self.mock
end

--- @param reader BufferReader
--- @return boolean
function LogSinkTable:RegisterBufferReader(reader)
	if not tContains(Buffer.readers, reader) then
		reader:SetBuffer(Buffer.all)
		table.insert(Buffer.readers, reader)
		return true
	end

	return false
end

--- @param reader BufferReader
--- @return boolean
function LogSinkTable:UnregisterBufferReader(reader)
	for i = #Buffer.readers, 1, -1 do
		if Buffer.readers[i] == reader then
			table.remove(Buffer.readers, i)
			return true
		end
	end

	return false
end

Addon.Buffer = Buffer
