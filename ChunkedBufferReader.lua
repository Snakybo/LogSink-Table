--- @class Addon
local Addon = select(2, ...)

local CHUNK_SIZE = 1000
local SCAN_BUDGET_MS = (1 / 30) * 1000

--- @class ChunkedBufferReader : BufferReader
--- @field public onBufferSet? fun()
--- @field public onMessageAdded? fun()
--- @field private first integer
--- @field private last integer
--- @field private buffer LibLog-1.0.LogMessage[]
--- @field private filter? Filter
local Reader = {
	first = 1,
	last = 1,
	chunkSize = CHUNK_SIZE,
	scanBudgetMs = SCAN_BUDGET_MS
}

function Reader:Dispose()
	self.buffer = nil
	self.filter = nil

	LogSinkTable:UnregisterBufferReader(self)
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer scanned
--- @return integer elapsedMs
function Reader:Load()
	self.first = 1
	self.last = #self.buffer

	return self:LoadImpl(self.last + 1, -1)
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer found
--- @return integer elapsedMs
function Reader:LoadPrevious()
	local result, scanned, elapsedMs = self:LoadImpl(self.first, -1)

	LogSinkTable:WithLogContext({ found = #result, scanned = scanned, first = self.first }, function()
		LogSinkTable:LogVerbose("Loaded previous chunk")
	end)

	return result, scanned, elapsedMs
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer found
--- @return integer elapsedMs
function Reader:LoadNext()
	local result, scanned, elapsedMs = self:LoadImpl(self.last, 1)

	LogSinkTable:WithLogContext({ found = #result, scanned = scanned, last = self.last, count = #self.buffer }, function()
		LogSinkTable:LogVerbose("Loaded next chunk")
	end)

	return result, scanned, elapsedMs
end

--- @return boolean
function Reader:HasNextLogs()
	return self.last < #self.buffer
end

--- @return boolean
function Reader:HasPreviousLogs()
	return self.first > 1
end

--- @param filter? Filter
function Reader:SetFilter(filter)
	self.filter = filter
end

--- @param buffer LibLog-1.0.LogMessage[]
function Reader:SetBuffer(buffer)
	self.buffer = buffer

	if self.onBufferSet ~= nil then
		self.onBufferSet()
	end
end

function Reader:GetNumProcessed()
	return self.last - self.first + 1, #self.buffer
end

function Reader:OnMessageAdded()
	if self.onMessageAdded ~= nil then
		self.onMessageAdded()
	end
end

--- @private
--- @param start integer
--- @param dir number
--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer scanned
--- @return integer elapsedMs
function Reader:LoadImpl(start, dir)
	local now = debugprofilestop()
	local result = {}
	local scanned = 0

	while #result < self.chunkSize and debugprofilestop() - now < self.scanBudgetMs do
		local current = start + ((scanned + 1) * dir)

		if current > #self.buffer or current <= 0 then
			break
		end

		scanned = scanned + 1

		local entry = self.buffer[current]

		if self.filter == nil or self.filter:Evaluate(entry) then
			table.insert(result, entry)
		end
	end

	if dir > 0 then
		self.last = min(#self.buffer, start + scanned)
	else
		self.first = max(1, start - scanned)

		for i = 1, floor(#result / 2) do
			local temp = result[i]
			result[i] = result[#result - i + 1]
			result[#result - i + 1] = temp
		end
	end

	return result, scanned, debugprofilestop() - now
end

--- @return ChunkedBufferReader
function LogSinkTable:CreateChunkedBufferReader()
	local reader = Mixin({}, Reader)
	LogSinkTable:RegisterBufferReader(reader)

	return reader
end
