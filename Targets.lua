-- Targets.lua
-- June 2014


local addon, ns = ...
local Hekili = _G[ addon ]

local class = ns.class
local state = ns.state

local targetCount = 0
local targets = {}

local myTargetCount = 0
local myTargets = {}

local nameplates = {}
local addMissingTargets = true

local npCount = 0
local lastNpCount = 0

local formatKey = ns.formatKey
local FeignEvent = ns.FeignEvent
local RegisterEvent = ns.RegisterEvent

local tinsert, tremove = table.insert, table.remove


-- New Nameplate Proximity System
function ns.getNumberTargets()
    local showNPs = GetCVar( 'nameplateShowEnemies' ) == "1"

    for k,v in pairs( nameplates ) do
        nameplates[k] = nil
    end

    npCount = 0

    if showNPs and ( Hekili.DB.profile['Count Nameplate Targets'] ) and not state.ranged then
        local RC = LibStub( "LibRangeCheck-2.0" )

        for i = 1, 80 do
            local unit = 'nameplate'..i

            local _, maxRange = RC:GetRange( unit )

            if maxRange and maxRange <= ( Hekili.DB.profile['Nameplate Detection Range'] or 5 ) and UnitExists( unit ) and ( not UnitIsDead( unit ) ) and UnitCanAttack( 'player', unit ) and UnitInPhase( unit ) and ( UnitIsPVP( 'player' ) or not UnitIsPlayer( unit ) ) then
                nameplates[ UnitGUID( unit ) ] = maxRange
                npCount = npCount + 1
            end
        end

        for i = 1, 5 do
            local unit = 'boss'..i

            local guid = UnitGUID( unit )

            if not nameplates[ guid ] then
                local maxRange = RC:GetRange( unit )

                if maxRange and maxRange <= ( Hekili.DB.profile['Nameplate Detection Range'] or 5 ) and UnitExists( unit ) and ( not UnitIsDead( unit ) ) and UnitCanAttack( 'player', unit ) and UnitInPhase( unit ) and ( UnitIsPVP( 'player' ) or not UnitIsPlayer( unit ) ) then
                    nameplates[ UnitGUID( unit ) ] = maxRange
                    npCount = npCount + 1
                end
            end
        end
    end

    if Hekili.DB.profile['Count Targets by Damage'] or not Hekili.DB.profile['Count Nameplate Targets'] or not showNPs or state.ranged then
        for k,v in pairs( myTargets ) do
            if not nameplates[ k ] then
                nameplates[ k ] = true
                npCount = npCount + 1
            end
        end
    end

    return npCount
end


function ns.recountTargets()
    lastNpCount = npCount

    npCount = ns.getNumberTargets()

    --[[ if lastNpCount ~= npCount then
        ns.forceUpdate()
    end ]]
end


function ns.dumpNameplateInfo()
    return nameplates
end


ns.updateTarget = function( id, time, mine )

    if id == state.GUID then return end

    if time then
        if not targets[ id ] then
            targetCount = targetCount + 1
            targets[ id ] = time
            ns.updatedTargetCount = true
        else
            targets[ id ] = time
        end

        if mine then
            if not myTargets[ id ] then
                myTargetCount = myTargetCount + 1
                myTargets[ id ] = time
                ns.updatedTargetCount = true
            else
                myTargets[ id ] = time
            end
        end

    else
        if targets[ id ] then
            targetCount = max(0, targetCount - 1)
            targets[ id ] = nil
        end

        if myTargets[ id ] then
            myTargetCount = max(0, myTargetCount - 1)
            myTargets[ id ] = nil
        end

        ns.updatedTargetCount = true
    end
end


ns.reportTargets = function()
  for k, v in pairs( targets ) do
    Hekili:Print( "Saw " .. k .. " exactly " .. GetTime() - v .. " seconds ago." )
  end
end


ns.numTargets = function() return targetCount > 0 and targetCount or 1 end
ns.numMyTargets = function() return myTargetCount > 0 and myTargetCount or 1 end
ns.isTarget = function( id ) return targets[ id ] ~= nil end
ns.isMyTarget = function( id ) return myTargets[ id ] ~= nil end


-- MINIONS
local minions = {}

ns.updateMinion = function( id, time )
  minions[ id ] = time
end

ns.isMinion = function( id ) return minions[ id ] ~= nil end


local debuffs = {}
local debuffCount = {}
local debuffMods = {}


function ns.saveDebuffModifier( id, val )
    debuffMods[ id ] = val
end


ns.wipeDebuffs = function()
  for k, _ in pairs( debuffs ) do
    table.wipe( debuffs[ k ] )
    debuffCount[ k ] = 0
  end
end


ns.trackDebuff = function( spell, target, time, application )

  debuffs[ spell ] = debuffs[ spell ] or {}
  debuffCount[ spell ] = debuffCount[ spell ] or 0

  if not time then
    if debuffs[ spell ][ target ] then
      -- Remove it.
      debuffs[ spell ][ target ] = nil
      debuffCount[ spell ] = max( 0, debuffCount[ spell ] - 1 )
    end

  else
    if not debuffs[ spell ][ target ] then
      debuffs[ spell ][ target ] = {}
      debuffCount[ spell ] = debuffCount[ spell ] + 1
    end

    local debuff = debuffs[ spell ][ target ]

    debuff.last_seen = time
    debuff.applied = debuff.applied or time

    if application then
        debuff.pmod = debuffMods[ spell ]
    else
        debuff.pmod = debuff.pmod or 1
    end
  end

end


function ns.getModifier( id, target )

    local debuff = debuffs[ id ]
    if not debuff then return 1 end

    local app = debuff[ target ]
    if not app then return 1 end

    return app.pmod or 1

end


ns.numDebuffs = function( spell ) return debuffCount[ spell ] or 0 end
ns.isWatchedDebuff = function( spell ) return debuffs[ spell ] ~= nil end


ns.eliminateUnit = function( id, force )
  ns.updateMinion( id )
  ns.updateTarget( id )

  ns.TTD[ id ] = nil

  if force then
      for k,v in pairs( debuffs ) do
        ns.trackDebuff( k, id )
      end
  end
end


local incomingDamage = {}
local incomingHealing = {}

ns.storeDamage = function( time, damage, damageType ) table.insert( incomingDamage, { t = time, damage = damage, damageType = damageType } ) end
ns.storeHealing = function( time, healing ) table.insert( incomingHealing, { t = time, healing = healing } ) end

ns.damageInLast = function( t )

  local dmg = 0
  local start = GetTime() - min( t, 15 )

  for k, v in pairs( incomingDamage ) do

    if v.t > start then
      dmg = dmg + v.damage
    end

  end

  return dmg

end


function ns.healingInLast( t )
    local heal = 0
    local start = GetTime() - min( t, 15 )

    for k, v in pairs( incomingHealing ) do
        if v.t > start then
            heal = heal + v.healing
        end
    end

    return heal
end


local TTD = ns.TTD

-- Borrowed TTD linear regression model from 'Nemo' by soulwhip (with permission).
ns.initTTD = function( unit )

    if not unit then return end

    local GUID = UnitGUID( unit )

    TTD[ GUID ] = TTD[ GUID ] or {}
    TTD[ GUID ].n = 1
    TTD[ GUID ].timeSum = GetTime()
    TTD[ GUID ].healthSum = UnitHealth( unit ) or 0
    TTD[ GUID ].timeMean = TTD[ GUID ].timeSum * TTD[ GUID ].timeSum
    TTD[ GUID ].healthMean = TTD[ GUID ].timeSum * TTD[ GUID ].healthSum
    TTD[ GUID ].name = UnitName( unit )
    TTD[ GUID ].sec = state.boss and 300 or 15

end


ns.getTTD = function( unit )

  local GUID = UnitGUID( unit ) or unit

  if not TTD[ GUID ] then return 15 end

  if state.time < 5 then return 15 - state.time end

  return min( 300, TTD[ GUID ].sec or 15 )

end


-- Auditor should clean things up for us.
ns.Audit = function ()

  local now = GetTime()
  local grace = Hekili.DB.profile['Audit Targets']

  for aura, targets in pairs( debuffs ) do
    for unit, entry in pairs( targets ) do
      -- NYI: Check for dot vs. debuff, since debuffs won't 'tick'
      local window = class.auras[ aura ] and class.auras[ aura ].duration or grace
      if now - entry.last_seen > window then
        ns.trackDebuff( aura, unit )
      end
    end
  end

  for whom, when in pairs( targets ) do
    if now - when > grace then
      ns.eliminateUnit( whom )
    end
  end

  for i = #incomingDamage, 1, -1 do
    local instance = incomingDamage[ i ]

    if instance.t < ( now - 15 ) then
      table.remove( incomingDamage, i )
    end
  end

  for i = #incomingHealing, 1, -1 do
    local instance = incomingHealing[ i ]

    if instance.t < ( now - 15 ) then
        table.remove( incomingHealing, i )
    end
  end

  if Hekili.DB.profile.Enabled then
    C_Timer.After( 1, ns.Audit )
  end

end





-- New Target Detection
-- January 2018

-- 1. Nameplate Detection
--    Overall, nameplate detection is really good.  Except when a target's nameplate goes off the screen.  So we need to count other potential targets.
--
-- 2. Damage Detection
--    We need to fine tune this a bit so that we can implement spell_targets.  We will flag targets as being hit by melee damage, spell damage, or ticking
--    damage.

do

    local NPR = LibStub( "LibNameplateRegistry-1.0" )
    local RC  = LibStub( "LibRangeCheck-2.0" )

    local targetCount = 0 
       
    local targetPool = {}
    local recycleBin = {}

    local function newTarget( guid, unit )
        if not guid or targetPool[ guid ] then return end

        local target = tremove( recycleBin ) or {}

        target.guid = guid

        target.lastMelee  = 0  -- last SWING_DAMAGE by you.
        target.lastSpell  = 0  -- last SPELL_DAMAGE by you.
        target.lastTick   = 0  -- last SPELL_PERIODIC_DAMAGE by you.
        target.lastAttack = 0  -- last SWING_DAMAGE by target to a friendly.

        tinsert( targetPool, target )
        return target
    end

    local function expireTarget( guid )
        if not guid then return end

        local target = targetPool[ guid ]

        if not target then return end

        targetPool[ guid ] = nil
        tinsert( recycleBin, target )
    end

    local function updateTarget( guid, unit, melee, spell, tick )
        if not guid and not unit then return end
        guid = guid or UnitGUID( unit )

        local target = targetPool[ guid ] or newTarget( guid, unit ) 

        if melee then target.lastMelee = GetTime() end
        if spell then target.lastSpell = GetTime() end
        if tick  then target.lastTick  = GetTime() end
    end

    local function expireTargets( limit )
        local now = GetTime()

        for guid, data in pairs( targetPool ) do
            local latest = max( data.lastMelee, data.lastSpell, data.lastTick )
            if now - latest > limit then
                expireTarget( GUID )
            end
        end
    end


    local lastCount, lastRange, lastLimit, lastTime = 0, 0, 0, 0

    local function getTargetsWithin( x, limit )
        local now = GetTime()
        limit = limit or 5        

        if x == lastRange and limit == lastLimit and now == lastTime then
            return lastCount
        end

        lastRange = x
        lastLimit = limit
        lastTime  = now
        lastCount = 0

        for guid, data in pairs( targetPool ) do
            local unit = NPR:GetPlateByGUID( guid )

            if unit then
                local _, distance = RC:GetRange( unit )

                if distance <= x then
                    lastCount = lastCount + 1
                end

            elseif limit <= 8 then
                -- If they're in melee, use the last hit.
                if now - data.lastMelee < limit then
                    lastCount = lastCount + 1
                end
            
            else
                -- Try the cached unit vs. GUIDs.
                -- Consider that target changes may happen really quickly, may have to reconsider this.               
            end
        end

        return lastCount
    end

   
    local function GroupMembers( reversed, forceParty )
        local unit = ( not forceParty and IsInRaid() ) and 'raid' or 'party'
        local numGroupMembers = forceParty and GetNumSubgroupMembers() or GetNumGroupMembers()
        local i = reversed and numGroupMembers or ( unit == 'party' and 0 or 1 )

        return function()
            local ret

            if i == 0 and unit == 'party' then
                ret = 'player'
            elseif i <= numGroupMembers and i > 0 then
                ret = unit .. i
            end
            
            i = i + ( reversed and -1 or 1 )
            return ret
        end
    end


end










































