--- Development of **RCSerializer-3.0**. Modified from **RCSerializer-3.0**
-- The goal of this serializer is to use less space after compressed by LibCompress,
-- but the serialized string has less readability.
--
-- Copyright claim of **AceSerialzier-3.0
--[[
Copyright (c) 2007, Ace3 Development Team

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Redistribution of a stand alone version is strictly prohibited without
      prior written authorization from the Lead of the Ace3 Development Team.
    * Neither the name of the Ace3 Development Team nor the names of its contributors
      may be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

local MAJOR,MINOR = "RCSerializer-3.0", 1
local RCSerializer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not RCSerializer then return end

-- Lua APIs
local strbyte, strchar, gsub, gmatch, format = string.byte, string.char, string.gsub, string.gmatch, string.format
local assert, error, pcall = assert, error, pcall
local type, tostring, tonumber = type, tostring, tonumber
local pairs, ipairs, select, frexp, ldexp = pairs, ipairs, select, math.frexp, math.ldexp
local tconcat = table.concat

-- quick copies of string representations of wonky numbers
local inf = math.huge

local serNaN  -- can't do this in 4.3, see ace3 ticket 268
local serInf, serInfMac = "1.#INF", "inf"
local serNegInf, serNegInfMac = "-1.#INF", "-inf"

-- separator characters for serializer.
-- Should replace these variable by constants for better performance later.
local SEPARATOR_FIRST = '\001'
local SEPARATOR_ESCAPE = '\001' -- Escape character
local SEPARATOR_STRING = '\002'	-- string
local SEPARATOR_NUMBER = '\003' -- Non floating number
local SEPARATOR_FLOAT_MAN = '\004' -- Mantissa part of floating number
local SEPARATOR_FLOAT_EXP = '\005' -- Exponent part of floating number
local SEPARATOR_TABLE_START = '\006' -- Table starts
local SEPARATOR_TABLE_END = '\007' -- Table ends
local SEPARATOR_ARRAY_START = '\008' -- Array starts
local SEPARATOR_ARRAY_END = '\009' -- Array ends
local SEPARATOR_TRUE = '\010' -- true
local SEPARATOR_FALSE = '\011' -- false
local SEPARATOR_NIL = '\012' -- nil
local SEPARATOR_LAST = '\012'

-- Serialization functions
local function SerializeStringHelper(ch)	-- Used by SerializeValue for strings
	local n = strbyte(ch)
	if SEPARATOR_FIRST <= ch and ch <= SEPARATOR_LAST then
		return SEPARATOR_ESCAPE..strchar(n+47)
	else
		return ch
	end
end

local function IsTableArray(t)
	local i = 0
	for _, _ in pairs(t) do
		i = i + 1
		if not t[i] then
			return false
		end
	end
	return true
end


local function SerializeValue(v, res, nres)
	-- We use "^" as a value separator, followed by one byte for type indicator
	local t = type(v)

	if t == "string" then		-- ^S = string (escaped to remove nonprints, "^"s, etc)
		res[nres+1] = SEPARATOR_STRING
		res[nres+2] = gsub(v, ".", SerializeStringHelper)
		nres = nres +2

	elseif t=="number" then	-- ^N = number (just tostring()ed) or ^F (float components)
		local str = tostring(v)
		if tonumber(str) == v  --[[not in 4.3 or str==serNaN]] then
			local oldStr = str
			-- translates just fine, transmit as-is
			res[nres+1] = SEPARATOR_NUMBER
			-- Another optimization. Transform the number with the form "0.7" to "07"
			if str == "0" then
				res[nres+2] = "0"
			else
				str = str:gsub("^(%-?)0*", "%1") -- Not sure if guarantees that no prefix 0, so first remove it
				res[nres+2] = str:gsub("^(%-?)%.", "%10")
			end
			--if oldStr ~= res[nres+2] then print(oldStr, res[nres+2]) end
			nres = nres + 2
		elseif v == inf or v == -inf then
			res[nres+1] = SEPARATOR_NUMBER
			res[nres+2] = v == inf and serInf or serNegInf
			nres = nres + 2
		else
			local m, e = frexp(v)
			res[nres+1] = SEPARATOR_FLOAT_MAN
			res[nres+2] = format("%.0f", m * 2 ^ 53)	-- force mantissa to become integer (it's originally 0.5--0.9999)
			res[nres+3] = SEPARATOR_FLOAT_EXP
			res[nres+4] = tostring(e - 53)
			nres = nres + 4
		end

	elseif t=="table" then	-- ^T...^t = table (list of key,value pairs)
		local isArray = IsTableArray(v)
		if isArray then
			nres=nres+1
			res[nres] = SEPARATOR_ARRAY_START
			for _, v in ipairs(v) do -- Key is not serilaized for array
				nres = SerializeValue(v, res, nres)
			end
			nres=nres+1
			res[nres] = SEPARATOR_ARRAY_END
		else
			nres=nres+1
			res[nres] = SEPARATOR_TABLE_START
			for k,v in pairs(v) do
				nres = SerializeValue(k, res, nres)
				nres = SerializeValue(v, res, nres)
			end
			nres=nres+1
			res[nres] = SEPARATOR_TABLE_END
		end

	elseif t=="boolean" then	-- ^B = true, ^b = false
		nres=nres+1
		if v then
			res[nres] = SEPARATOR_TRUE	-- true
		else
			res[nres] = SEPARATOR_FALSE	-- false
		end

	elseif t=="nil" then		-- ^Z = nil (zero, "N" was taken :P)
		nres=nres+1
		res[nres] = SEPARATOR_NIL

	else
		error(MAJOR..": Cannot serialize a value of type '"..t.."'")	-- can't produce error on right level, this is wildly recursive
	end

	return nres
end



local serializeTbl = { } -- Unlike AceSerializer-3.0, there is no header in the serialized string.

--- Serialize the data passed into the function.
-- Takes a list of values (strings, numbers, booleans, nils, tables)
-- and returns it in serialized form (a string).\\
-- May throw errors on invalid data types.
-- @param ... List of values to serialize
-- @return The data in its serialized form (string)
function RCSerializer:Serialize(...)
	local nres = 0

	for i=1, select("#", ...) do
		local v = select(i, ...)
		nres = SerializeValue(v, serializeTbl, nres)
	end

	return tconcat(serializeTbl, "", 1, nres)
end

-- Deserialization functions
local function DeserializeStringHelper(escape)
	local n = strbyte(escape, 2, 2)
	n = n - 47
	local ch = strchar(n)
	if SEPARATOR_FIRST <= ch and ch <= SEPARATOR_LAST then
		return ch
	else
		error("DeserializeStringHelper got called for '"..escape.."'?!?")  -- can't be reached unless regex is screwed up
	end
end

local function DeserializeNumberHelper(number)
	--[[ not in 4.3 if number == serNaN then
		return 0/0
	else]]if number == serNegInf or number == serNegInfMac then
		return -inf
	elseif number == serInf or number == serInfMac then
		return inf
	else
		if number == "0" then return 0 end
		number = number:gsub("^(%-?)0", "%10.")
		return tonumber(number)
	end
end

-- DeserializeValue: worker function for :Deserialize()
-- It works in two modes:
--   Main (top-level) mode: Deserialize a list of values and return them all
--   Recursive (table) mode: Deserialize only a single value (_may_ of course be another table with lots of subvalues in it)
--
-- The function _always_ works recursively due to having to build a list of values to return
--
-- Callers are expected to pcall(DeserializeValue) to trap errors

local function DeserializeValue(iter, single, ctl, data)
	if not single then
		ctl, data = iter()
	end

	if not ctl then
		error("ilformed data for RCSerializer")
	end

	local res
	if ctl == SEPARATOR_STRING then
		res = gsub(data, SEPARATOR_ESCAPE..".", DeserializeStringHelper)
	elseif ctl == SEPARATOR_NUMBER then
		if data == "END" then -- End of string mark
			return
		end
		res = DeserializeNumberHelper(data)
		if not res then
			error("Invalid serialized number: '"..tostring(data).."'")
		end
	elseif ctl == SEPARATOR_FLOAT_MAN then     -- ^F<mantissa>^f<exponent>
		local ctl2, e = iter()
		if ctl2 ~= SEPARATOR_FLOAT_EXP then
			error("Invalid serialized floating-point number")
		end
		local m = tonumber(data)
		e = tonumber(e)
		if not (m and e) then
			error("Invalid serialized floating-point number, expected mantissa and exponent, got '"..tostring("0."..m).."' and '"..tostring(e).."'")
		end
		res = m*(2^e)
	elseif ctl == SEPARATOR_TRUE then	-- yeah yeah ignore data portion
		res = true
		if data ~= "" then
			error("Unexpected data for RCSerializer after true marker")
		end
	elseif ctl == SEPARATOR_FALSE then   -- yeah yeah ignore data portion
		res = false
		if data ~= "" then
			error("Unexpected data for RCSerializer after false marker")
		end
	elseif ctl == SEPARATOR_NIL then	-- yeah yeah ignore data portion
		res = nil
		if data ~= "" then
			error("Unexpected data for RCSerializer after nil marker")
		end
	elseif ctl == SEPARATOR_TABLE_START then
		-- ignore ^T's data, future extensibility?
		res = {}
		local k,v
		while true do
			ctl, data = iter()
			if ctl == SEPARATOR_TABLE_END then
				if data ~= "" then
					error("Unexpected data for RCSerializer after table end marker")
				end
				break
			end	-- ignore ^t's data
			k = DeserializeValue(iter, true, ctl, data)
			if k==nil then
				error("Invalid RCSerializer table format (no table end marker)")
			end
			ctl, data = iter()
			v = DeserializeValue(iter, true, ctl, data)
			if v == nil then
				error("Invalid RCSerializer table format (no table end marker)")
			end
			res[k] = v
		end
	else
		error("Invalid RCSerializer control code '"..ctl.."'")
	end

	if not single then
		return res, DeserializeValue(iter)
	else
		return res
	end
end

--- Deserializes the data into its original values.
-- Accepts serialized data, ignoring all control characters and whitespace.
-- @param str The serialized data (from :Serialize)
-- @return true followed by a list of values, OR false followed by an error message
function RCSerializer:Deserialize(str)
	local STR_END = SEPARATOR_NUMBER.."END"
	local iter = gmatch(str..STR_END, "([\002-\011])([^\002-\011]*)")
	return pcall(DeserializeValue, iter)
end

----------------------------------------
-- Base library stuff
----------------------------------------

RCSerializer.internals = {	-- for test scripts
	SerializeValue = SerializeValue,
	SerializeStringHelper = SerializeStringHelper,
}

local mixins = {
	"Serialize",
	"Deserialize",
}

RCSerializer.embeds = RCSerializer.embeds or {}

function RCSerializer:Embed(target)
	for k, v in pairs(mixins) do
		target[v] = self[v]
	end
	self.embeds[target] = true
	return target
end

-- Update embeds
for target, v in pairs(RCSerializer.embeds) do
	RCSerializer:Embed(target)
end