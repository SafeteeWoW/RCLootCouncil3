-- ItemInfo.lua	Fetch the full item info of an item
-- This library should be embeded by the modules that needs this.
-- @author	Safetee
-- Create Date : 12/1/2017 (Dec 1st, 2017)

local MAJOR, MINOR = "RCItemInfo", 1
local RCItemInfo = LibStub:NewLibrary(MAJOR, MINOR)

-- Not considering any library upgrades, because this is a library only used internally in RCLootCouncil and its module

-- Upvalue for better performance
local _G = _G
local C_TimerAfter = C_Timer.After
local CreateFrame = CreateFrame
local error = error
local GetContainerItemInfo = GetContainerItemInfo
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
local GetItemStats = GetItemStats
local ipairs = ipairs
local strmatch = string.match
local UIParent = UIParent

-- Don't use GameTooltip for parsing, because GameTooltip can be hooked by other addons.
local tooltip = CreateFrame("GameTooltip", "RCItemInfo_Tooltip_Parse", nil, "GameTooltipTemplate")
tooltip:UnregisterAllEvents()

local fullItemInfos = {} -- Store the info of item links.
-- Key: Item link/Item id/Item name:
-- values: A table storing the item infos.
RCItemInfo.fullItemInfos = fullItemInfos -- Export for debugging purposes

function RCItemInfo:CacheItem(item)
	if fullItemInfos[item] then return end -- already cached, just return
	local name, link, rarity, ilvl, minLevel, type, subType, stackCount,
equipLoc, texture, sellPrice, typeID, subTypeID, bindType, expacID, itemSetID, isReagent
	= GetItemInfo(item)
	if name then
		-- TODO
	else
		name, type, subType, equipLoc, texture, typeID, subTypeID = GetItemInfoInstant(item)
		if name then

		else
			error(": CacheItem(item): 'item' - must be a valid item link, item name or item id.")
		end
	end
end
