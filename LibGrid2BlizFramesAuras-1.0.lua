local lib = LibStub:NewLibrary("LibGrid2BlizFramesAuras-1.0", 1)
if not lib then return end

local next = next
local strfind = strfind
local min = math.min
local GetUnitAuras = C_UnitAuras.GetUnitAuras
local GetUnitAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs
local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID

local hooked
local initialized
local callbacks = {}
local unit2frame = {}
local resultTable = {}

-------------------------------------
-- Initialization code
-------------------------------------

local function UpdateCache()
	local function save(frameName)
		local frame = _G[frameName]
		if frame and frame.unit and frame:IsShown()  then
			unit2frame[frame.unit] = frame
		end
	end
	for i = 1, 4 do
		save("CompactPartyFrameMember"..i)
	end
	for i = 1, 40 do
		save("CompactRaidFrame"..i)
	end
end

local function UpdateUnit(frame)
	if initialized then
		local unit = frame.unit
		if unit and not strfind(unit, "^nameplate") then -- skip nameplates
			unit2frame[unit] = frame
			for _, func in next, callbacks do
				func(unit)
			end
		end
	end
end

local function UpdateHooks()
	if not hooked then
		hooksecurefunc("CompactUnitFrame_UpdateAuras", UpdateUnit)
		hooksecurefunc("CompactUnitFrame_SetUnit", UpdateUnit)
		hooked = true
	end
end

local  function Initialize()
	UpdateCache()
	UpdateHooks()
	initialized = true
end

local function Deinitialize()
	wipe(unit2frame)
	initialized = nil
end

-------------------------------------
-- Callbacks registration
-------------------------------------

function lib.RegisterCallback(obj, func)
	if not next(callbacks) then
		Initialize()
	end
	if type(obj)=='table' then
		if type(func)=='string' then
			callbacks[obj] = function(unit) obj[func](obj, "LBF_UNIT_AURA", unit) end
		else
			callbacks[obj] = function(unit) func(obj, "LBF_UNIT_AURA", unit) end
		end
	else
		callbacks[obj] = function(unit) func("LBF_UNIT_AURA", unit) end
	end
end

function lib.UnregisterCallback(obj)
	callbacks[obj] = nil
	if not next(callbacks) then
		Deinitialize()
	end
end

-------------------------------------
-- Methods to Get Auras
-------------------------------------

local function GetAuras(unit, key, filter, max, sortRule, sortDir, onlyIDs, result)
	result = result or resultTable
	wipe(result)
	local frame = unit2frame[unit]
	if frame then
		local aurasFrame = frame[key]
		for i=1, min(#aurasFrame, max or 8) do
			local auraFrame = aurasFrame[i]
			if not auraFrame:IsShown() then break end
			local auraInstanceID = auraFrame.auraInstanceID
			if auraInstanceID then
				result[#result+1] = onlyIDs and auraInstanceID or GetAuraDataByAuraInstanceID(unit, auraInstanceID)
			end
		end
	elseif filter then -- fallback to standard filter
		if onlyIDs then
			return GetUnitAuraInstanceIDs(unit, filter, max or 8, sortRule, sortDir)
		else
			return GetUnitAuras(unit, filter, max or 8, sortRule, sortDir)
		end
	end
	return result
end

function lib.GetUnitBuffs(unit, filter, max, sortRule, sortDir, onlyIDs, result)
	return GetAuras(unit, "buffFrames", filter, max, sortRule, sortDir, onlyIDs, result)
end

function lib.GetUnitDebuffs(unit, filter, max, sortRule, sortDir, onlyIDs, result)
	return GetAuras(unit, "debuffFrames", filter, max, sortRule, sortDir, onlyIDs, result)
end

function lib.GetUnitDefensives(unit, filter, max, sortRule, sortDir, onlyIDs, result)
	result = result or resultTable
	wipe(result)
	local frame = unit2frame[unit]
	if frame then
		local auraFrame = frame.CenterDefensiveBuff
		if auraFrame then
			local auraInstanceID = auraFrame.auraInstanceID
			if auraInstanceID then
				result[1] = onlyIDs and auraInstanceID or GetAuraDataByAuraInstanceID(auraInstanceID)
			end
		end
	elseif filter then
		if onlyIDs then
			return GetUnitAuraInstanceIDs(unit, filter, max or 8, sortRule, sortDir)
		else
			return GetUnitAuras(unit, filter, max or 8, sortRule, sortDir)
		end
	end
	return result
end

function lib.GetUnitAuras(unit, filter, max, sortRule, sortDir, onlyIDs, result)
	if strfind(filter, "EXTERNAL_DEFENSIVE") then
		return lib:GetUnitDefensives(unit, filter, max, sortRule, sortDir, onlyIDs, result)
	elseif strfind(filter, "^HELPFUL")	 then
		return GetAuras(unit, "buffFrames", filter, max, sortRule, sortDir, onlyIDs, result)
	else -- HARMFUL
		return GetAuras(unit, "debuffFrames", filter, max, sortRule, sortDir,onlyIDs, result)
	end
end
