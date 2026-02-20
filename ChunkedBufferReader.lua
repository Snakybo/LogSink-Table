--- @class Addon
local Addon = select(2, ...)

local CHUNK_SIZE = 100
local SCAN_SIZE = 10000

--- @class ChunkedBufferReader : BufferReader
--- @field public onBufferSet? fun()
--- @field private first integer
--- @field private last integer
--- @field private buffer LibLog-1.0.LogMessage[]
--- @field private filter? Filter
local Reader = {
	tail = true,
	chunkSize = CHUNK_SIZE,
	scanSize = SCAN_SIZE,
}

function Reader:Dispose()
	self.buffer = nil
	self.filter = nil

	LogSinkTable:UnregisterBufferReader(self)
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer scanned
function Reader:Load()
	self.first = 1
	self.last = #self.buffer
	self.tail = true

	return self:LoadImpl(self.last + 1, -1)
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer found
function Reader:LoadPrevious()
	local result, scanned = self:LoadImpl(self.first, -1)

	LogSinkTable:WithLogContext({ found = #result, scanned = scanned, first = self.first }, function()
		LogSinkTable:LogVerbose("Loaded previous chunk")
	end)

	self.tail = false
	return result, scanned
end

--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer found
function Reader:LoadNext()
	local result, scanned = self:LoadImpl(self.last, 1)

	self.tail = self.last == #self.buffer

	LogSinkTable:WithLogContext({ found = #result, scanned = scanned, tail = self.tail, last = self.last, count = #self.buffer }, function()
		LogSinkTable:LogVerbose("Loaded next chunk")
	end)

	return result, scanned
end

--- @return boolean
function Reader:HasNewLogs()
	return self.tail and self.last < #self.buffer
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

--- @private
--- @param start integer
--- @param dir number
--- @return LibLog-1.0.LogMessage[] chunk
--- @return integer scanned
function Reader:LoadImpl(start, dir)
	local result = {}
	local scanned = 0

	for i = 1, self.scanSize do
		local current = start + (i * dir)

		if #result >= self.chunkSize or current > #self.buffer or current <= 0 then
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

	return result, scanned
end

--- @return ChunkedBufferReader
function LogSinkTable:CreateChunkedBufferReader()
	local reader = Mixin({}, Reader)
	LogSinkTable:RegisterBufferReader(reader)

	return reader
end
