-- State.lua
-- June 2014

local addon, ns = ...
local Hekili = _G[ addon ]

local auras = ns.auras
local class = ns.class
local formatKey = ns.formatKey
local getSpecializationID = ns.getSpecializationID
local round, roundUp = ns.round, ns.roundUp
local safeMin, safeMax = ns.safeMin, ns.safeMax
local tCopy = ns.tableCopy


local tInsert = table.insert
local tSort = table.sort
local tWipe = table.wipe


local PTR = ns.PTR


-- This will be our environment table for local functions.
local state = ns.state

state.iteration = 0

state.PTR = PTR

state.now = 0
state.offset = 0
state.delay = 0
state.latency = 0

state.arena = false
state.bg = false

state.mainhand_speed = 0
state.offhand_speed = 0

state.min_targets = 0
state.max_targets = 0

state.action = {}
state.active_dot = {}
state.args = {}
state.artifact = {}
state.aura = {}
state.buff = {}
state.auras = auras
state.cooldown = {}
state.item_cd = {}
state.debuff = {}
state.dot = {}
state.equipped = {}
state.glyph = {}
state.perk = {}
state.pet = {
    fake_pet = {
        name = "Mary-Kate Olsen",
        expires = 0,
        permanent = false,
    }
}
state.player = {
    lastcast = 'none',
    lastgcd = 'none',
    lastoffgcd = 'none',
    casttime = 0,
    updated = true,
    channeling = false,
    channel_start = 0,
    channel_end = 0,
    channel_spell = nil
}
state.prev = {
    meta = 'castsAll'
}
state.prev_gcd = {
    meta = 'castsOn'
}
state.prev_off_gcd = {
    meta = 'castsOff'
}
state.predictions = {}
state.predictionsOff = {}
state.predictionsOn = {}
state.purge = {}
state.race = {}
state.script = {}
state.set_bonus = {}
state.settings = {}
state.spec = {}
state.stance = {}
state.stat = {}
state.swings = {
    mh_actual = GetTime(),
    mh_speed = UnitAttackSpeed( 'player' ) > 0 and UnitAttackSpeed( 'player' ) or 2.6,
    mh_projected = GetTime() + 2.6,
    oh_actual = GetTime() + 1.3,
    oh_speed = select( 2, UnitAttackSpeed( 'player' ) ) or 2.6,
    oh_projected = GetTime() + 3.9
}
state.talent = {}
state.target = {
    debuff = state.debuff,
    dot = state.dot,
    health = {},
    updated = true
}
state.toggle = {}
state.totem = {}


state.trinket = {
    t1 = {
        slot = 't1',
        
        cooldown = {
            slot = 't1'
        },
        has_cooldown = {
            slot = 't1'
        },
        
        stacking_stat = {
            slot = 't1'
        },
        has_stacking_stat = {
            slot = 't1'
        },
        
        stat = {
            slot = 't1'
        },
        has_stat = {
            slot = 't1'
        }
    },
    
    t2 = {
        slot = 't2',
        
        cooldown = {
            slot = 't2',
        },
        has_cooldown = {
            slot = 't2',
        },
        
        stacking_stat = {
            slot = 't2'
        },
        has_stacking_stat = {
            slot = 't2'
        },
        
        stat = {
            slot = 't2'
        },
        has_stat = {
            slot = 't2',
        },
    },
    
    any = {},
    
    cooldown = {
    },
    has_cooldown = {
    },
    
    stacking_stat = {
    },
    has_stacking_stat = {
    },
    
    stat = {
    },
    has_stat = {
    }
}
state.trinket.proc = state.trinket.stat

state.using_apl = setmetatable( {}, {
    __index = function( t, k )
        return false
    end
} )


state.role = setmetatable( {}, {
    __index = function( t, k )
        return false
    end
} )

local mt_no_trinket_cooldown = {
}

local mt_no_trinket_stacking_stat = {
}

local mt_no_trinket_stat = {
}


local mt_no_trinket = {
    __index = function( t, k )
        if k:sub(1,4) == 'has_' then
            return false
        elseif k == 'down' then
            return true
        end
        
        return false
    end
}

local no_trinket = setmetatable( {
    slot = 'none',
    cooldown = setmetatable( {}, mt_no_trinket_cooldown ),
    stacking_stat = setmetatable( {}, mt_no_trinket_stacking_stat ),
    stat = setmetatable( {}, mt_no_trinket_stat )
}, mt_no_trinket )


state.trinket.stat.any = state.trinket.any


local mt_trinket_any = {
    __index = function( t, k )
        return state.trinket.t1[ k ] or state.trinket.t2[ k ]
    end
}

setmetatable( state.trinket.any, mt_trinket_any )

local mt_trinket_any_stacking_stat = {
    __index = function( t, k )
        if state.trinket.t1.has_stacking_stat[k] then return state.trinket.t1
            elseif state.trinket.t2.has_stacking_stat[k] then return state.trinket.t2 end
        return no_trinket
    end
}

setmetatable( state.trinket.stacking_stat, mt_trinket_any_stacking_stat )

local mt_trinket_any_stat = {
    __index = function( t, k )
        --[[ if k == 'any' then
        return ( state.trinket.has_stat[ 
    end ]]
        
        if state.trinket.t1.has_stat[k] then return state.trinket.t1
            elseif state.trinket.t2.has_stat[k] then return state.trinket.t2 end
        return no_trinket
    end
}

setmetatable( state.trinket.stat, mt_trinket_any_stat )


local mt_trinket = {
    __index = function( t, k )
        if k == 'up' or k == 'ticking' or k == 'active' then
            return class.trinkets[ t.id ].buff and state.buff[ class.trinkets[ t.id ].buff ].up or false
        elseif k == 'react' or k == 'stack' or k == 'stacks' then
            return class.trinkets[ t.id ].buff and state.buff[ class.trinkets[ t.id ].buff ][k] or 0
        elseif k == 'remains' then
            return class.trinkets[ t.id ].buff and state.buff[ class.trinkets[ t.id ].buff ].remains or 0
        end
        return false
    end
}

setmetatable( state.trinket.t1, mt_trinket )
setmetatable( state.trinket.t2, mt_trinket )


local mt_trinket_cooldown = {
    __index = function(t, k)
        if k == 'duration' or k == 'expires' then
            -- Refresh the ID in case we changed specs and ability is spec dependent.
            local start, duration = GetItemCooldown( state.trinket[ t.slot ].id )
            
            t.duration = duration or 0
            t.expires = start and ( start + duration ) or 0
            
            return t[k]
            
        elseif k == 'remains' then
            return max( 0, t.expires - ( state.query_time ) )
            
        elseif k == 'up' then
            return t.remains == 0
            
        elseif k == 'down' then
            return t.remains > 0
            
        end
        
        -- return error( "UNK: " .. k )
        
    end
}

setmetatable( state.trinket.t1.cooldown, mt_trinket_cooldown )
setmetatable( state.trinket.t2.cooldown, mt_trinket_cooldown )


local mt_trinket_has_stacking_stat = {
    __index = function( t, k )
        local trinket = state.trinket[ t.slot ].id
        
        if trinket == 0 then return false end
        
        if k == 'any' then return class.trinkets[ trinket ].stacking_stat ~= nil end
        
        if k == 'ms' then k = 'multistrike' end
        
        return class.trinkets[ trinket ].stacking_stat == k
    end
}

setmetatable( state.trinket.t1.has_stacking_stat, mt_trinket_has_stacking_stat )
setmetatable( state.trinket.t2.has_stacking_stat, mt_trinket_has_stacking_stat )


local mt_trinket_has_stat = {
    __index = function( t, k )
        local trinket = state.trinket[ t.slot ].id
        
        if trinket == 0 then return false end
        
        if k == 'any' then return class.trinkets[ trinket ].stat ~= nil end
        
        if k == 'ms' then k = 'multistrike' end
        
        return class.trinkets[ trinket ].stat == k
    end
}

setmetatable( state.trinket.t1.has_stat, mt_trinket_has_stat )
setmetatable( state.trinket.t2.has_stat, mt_trinket_has_stat )


local mt_trinkets_has_stat = {
    __index = function( t, k )
        if k == 'ms' then k = 'multistrike' end
        
        if k == 'any' then
            return class.trinkets[ state.trinket.t1.id ].stat ~= nil or class.trinkets[ state.trinket.t2.id ].stat ~= nil
        end
        
        return class.trinkets[ state.trinket.t1.id ].stat == k or class.trinkets[ state.trinket.t2.id ].stat == k
    end
}

setmetatable( state.trinket.has_stat, mt_trinkets_has_stat )


local mt_trinkets_has_stacking_stat = {
    __index = function( t, k )
        if k == 'ms' then k = 'multistrike' end
        
        if k == 'any' then
            return class.trinkets[ state.trinket.t1.id ].stacking_stat ~= nil or class.trinkets[ state.trinket.t2.id ].stacking_stat ~= nil
        end
        
        return class.trinkets[ state.trinket.t1.id ].stacking_stat == k or class.trinkets[ state.trinket.t2.id ].stacking_stat == k
    end
}

setmetatable( state.trinket.has_stacking_stat, mt_trinkets_has_stacking_stat )


state.max = safeMax
state.min = safeMin
state.floor = math.floor
state.print = print

state.GetItemCount = GetItemCount
state.GetTotemInfo = GetTotemInfo
state.IsUsableSpell = IsUsableSpell
state.UnitBuff = UnitBuff
state.UnitDebuff = UnitDebuff
state.floor = math.floor
state.abs = math.abs
state.tinsert = table.insert

state.boss = false
state.combat = 0
state.faction = UnitFactionGroup( 'player' )
state.race[ formatKey( UnitRace('player') ) ] = true

state.class = ns.class
state.targets = ns.targets

state._G = 0


-- Place an ability on cooldown in the simulated game state.
local function setCooldown( action, duration )

    --[[ if action == 'use_item' then
        local item = state.args.name or state.args.ModName or "no_item"
        local cd = state.cooldown.use_item.items[ item ]
        cd.duration = duration
        cd.expires = state.query_time + duration
    else ]]
        state.cooldown[ action ] = state.cooldown[ action ] or {}
        -- state.cooldown[ action ].start = state.query_time
        state.cooldown[ action ].duration = duration
        state.cooldown[ action ].expires = state.query_time + duration
    --[[ end ]]
    
end
state.setCooldown = setCooldown


local function spendCharges( action, charges )
    if class.abilities[ action ].charges and charges > 0 then
        state.cooldown[ action ] = state.cooldown[ action ] or {}
        
        if state.cooldown[ action ].next_charge <= state.query_time then
            state.cooldown[ action ].recharge_began = state.query_time
            state.cooldown[ action ].next_charge = state.query_time + class.abilities[ action ].recharge
            state.cooldown[ action ].recharge = class.abilities[ action ].recharge
        end
        
        state.cooldown[ action ].charge = max( 0, state.cooldown[ action ].charge - charges )
        
        if state.cooldown[ action ].charge == 0 then
            state.cooldown[ action ].duration = class.abilities[ action ].recharge
            state.cooldown[ action ].expires = state.cooldown[ action ].next_charge
        else
            state.cooldown[ action ].duration = 0
            state.cooldown[ action ].expires = 0
        end
    end
end
state.spendCharges = spendCharges


local function gainCharges( action, charges )
    
    if class.abilities[ action ].charges then
        state.cooldown[ action ].charge = min( class.abilities[ action ].charges, state.cooldown[ action ].charge + charges )
        
        -- resolve cooldown state.
        if state.cooldown[ action ].charge > 0 then
            state.cooldown[ action ].duration = 0
            state.cooldown[ action ].expires = 0
        end
        
        if state.cooldown[ action ].charge == class.abilities[ action ].charges then
            state.cooldown[ action ].next_charge = 0
            state.cooldown[ action ].recharge = 0
            state.cooldown[ action ].recharge_began = 0
        end
    end
    
end
state.gainCharges = gainCharges


function state.gainChargeTime( action, time )
    
    local ability = class.abilities[ action ]
    
    if not ability or not ability.charges then return end
    
    local cooldown = state.cooldown[ action ]
    
    if cooldown.charge == ability.charges then return end
    
    if cooldown.next_charge < state.now + state.offset + time then
        cooldown.charge = min( ability.charges, cooldown.charge + 1 )
        
        -- We have a charge, reset cooldown.
        cooldown.duration = 0
        cooldown.expires = 0
    end
    
    
    if cooldown.charge == ability.charges then
        cooldown.next_charge = 0
        cooldown.recharge = 0
        cooldown.recharge_began = 0
    else
        cooldown.recharge_began = cooldown.next_charge
        cooldown.next_charge = cooldown.next_charge + ability.recharge
        cooldown.recharge = cooldown.next_charge - ( state.time + time )
    end
    
end

--[[
function state.spendChargeTime( action, time )
    
    local ability = class.abilities[ action ]
    
    if not ability or not ability.charges then return end
    
    local cooldown = state.cooldown[ action ]
    
    if cooldown.charges_fractional == 0 then return end
    
    local charges_before = cooldown.charges_fractional
    local charges_after = cooldown.charges_fractional - ( time / cooldown.recharge_time )
    
    if floor( charges_after ) < floor( charges_before ) then
        -- We reduced our number of charges.
        cooldown.charge = 
        
        if cooldown.next_charge < state.now + state.offset + time then
            cooldown.charge = min( ability.charges, cooldown.charge + 1 )
            
            -- We have a charge, reset cooldown.
            cooldown.duration = 0
            cooldown.expires = 0
        end
        
        
        if cooldown.charge == ability.charges then
            cooldown.next_charge = 0
            cooldown.recharge = 0
            cooldown.recharge_began = 0
        else
            cooldown.recharge_began = cooldown.next_charge
            cooldown.next_charge = cooldown.next_charge + ability.recharge
            cooldown.recharge = cooldown.next_charge - ( state.time + time )
        end
        
    end ]]


-- Apply a buff to the current game state.
local function applyBuff( aura, duration, stacks, value )
    
    if state.cycle then
        if duration == 0 then state.active_dot[ aura ] = state.active_dot[ aura ] - 1
        else state.active_dot[ aura ] = state.active_dot[ aura ] + 1 end
        return
    end
    
    if not state.buff[ aura ] then return end
    if not duration then duration = class.auras[ aura ].duration or 15 end
    
    if duration == 0 then
        state.buff[ aura ].expires = 0
        state.buff[ aura ].count = 0
        state.buff[ aura ].v1 = 0
        state.buff[ aura ].applied = 0
        state.buff[ aura ].caster = 'unknown'
        
        state.active_dot[ aura ] = max( 0, state.active_dot[ aura ] - 1 )
        
    else
        if not state.buff[ aura ].up then state.active_dot[ aura ] = state.active_dot[ aura ] + 1 end
        
        state.buff[ aura ] = state.buff[ aura ] or {}
        state.buff[ aura ].expires = state.query_time + ( duration or class.auras[ aura ].duration )
        state.buff[ aura ].applied = state.query_time
        state.buff[ aura ].count = stacks or 1
        state.buff[ aura ].v1 = value or 0
        state.buff[ aura ].caster = 'player'
    end
    
    if aura == 'heroism' or aura == 'time_warp' or aura == 'ancient_hysteria' then
        applyBuff( 'bloodlust', duration, stacks, value )
    elseif aura ~= 'potion' and class.auras[ aura ].id == class.auras.potion.id then
        applyBuff( 'potion', duration, stacks, value )
    end
    
end
state.applyBuff = applyBuff


local function removeBuff( aura )
    
    applyBuff( aura, 0 )
    
end
state.removeBuff = removeBuff


-- Apply stacks of a buff to the current game state.
-- Wraps around Buff() to check for an existing buff.
local function addStack( aura, duration, stacks, value )
    
    local max_stack = ( class.auras[ aura ] and class.auras[ aura ].max_stack ) and class.auras[ aura ].max_stack or 1
    
    if state.buff[ aura ].remains > 0 then
        applyBuff( aura, duration, min( max_stack, state.buff[ aura ].count + stacks ), value )
    else
        applyBuff( aura, duration, min( max_stack, stacks ), value )
    end
    
end
state.addStack = addStack


local function removeStack( aura, stacks )
    
    stacks = stacks or 1
    
    if state.buff[ aura ].count > stacks then
        state.buff[ aura ].count = max( 1, state.buff[ aura ].count - stacks )
    else
        removeBuff( aura )
    end
end
state.removeStack = removeStack


-- Add a debuff to the simulated game state.
-- Needs to actually use 'unit' !
local function applyDebuff( unit, aura, duration, stacks, value )
    
    if state.cycle then
        if duration == 0 then state.active_dot[ aura ] = state.active_dot[ aura ] - 1
    else state.active_dot[ aura ] = state.active_dot[ aura ] + 1 end
        return
    end

    if not duration then duration = class.auras[ aura ].duration or 15 end
    
    if duration == 0 then
        state.debuff[ aura ].expires = 0
        state.debuff[ aura ].count = 0
        state.debuff[ aura ].value = 0
        state.debuff[ aura ].applied = 0
        state.debuff[ aura ].unit = unit
        
        state.active_dot[ aura ] = max( 0, state.active_dot[ aura ] - 1 )
    else
        if state.debuff[ aura ].down then state.active_dot[ aura ] = state.active_dot[ aura ] + 1 end
        
        state.debuff[ aura ] = state.debuff[ aura ] or {}
        state.debuff[ aura ].expires = state.query_time + duration
        state.debuff[ aura ].count = stacks or 1
        state.debuff[ aura ].value = value or 0
        state.debuff[ aura ].applied = state.now
        state.debuff[ aura ].unit = unit or 'target'
    end
    
end
state.applyDebuff = applyDebuff


local function removeDebuff( unit, aura )    
    applyDebuff( unit, aura, 0 )        
end
state.removeDebuff = removeDebuff


local function setStance( stance )
    for k in pairs( state.stance ) do
        state.stance[ k ] = false
    end
    state.stance[ stance ] = true
end
state.setStance = setStance


local function interrupt()
    state.target.casting = false
    state.removeDebuff( 'target', 'casting' )
end
state.interrupt = interrupt


local function summonPet( name, duration )
    
    state.pet[ name ] = rawget( state.pet, name ) or {}
    state.pet[ name ].name = name
    state.pet[ name ].expires = state.query_time + ( duration or 3600 )
    
end
state.summonPet = summonPet


local function dismissPet( name )

    state.pet[ name ] = rawget( state.pet, name ) or {}
    state.pet[ name ].name = name
    state.pet[ name ].expires = 0

end
state.dismissPet = dismissPet


local function summonTotem( name, elem, duration )
    
    state.totem[ elem ] = rawget( state.totem, elem ) or {}
    state.totem[ elem ].name = name
    state.totem[ elem ].expires = state.query_time + duration
    
    state.pet[ elem ] = rawget( state.pet, elem ) or {}
    state.pet[ elem ].name = name
    state.pet[ elem ].expires = state.query_time + duration
    
    state.pet[ name ] = rawget( state.pet, name ) or {}
    state.pet[ name ].name = name
    state.pet[ name ].expires = state.query_time + duration
    
end
state.summonTotem = summonTotem


-- Useful for things like leap/charge/etc.
local function setDistance( minimum, maximum )
    state.target.minR = minimum or 5
    state.target.maxR = maximum or minimum or 5
end
state.setDistance = setDistance


-- For tracking if we are currently channeling.
function state.channelSpell( name, start, duration )
    if name then
        local ability = class.abilities[ name ]

        if ability then
            state.player.channelSpell = name
            state.player.channelStart = start or state.query_time
            state.player.channelEnd   = state.player.channelStart + ( duration or ability.cast )
        end
    end
end

function state.stopChanneling( reset )

    if not reset then
        local spell = state.player.channelSpell
        local ability = spell and class.abilities[ spell ]

        if ability and ability.breakchannel then ability.breakchannel() end
    end

    state.player.channelSpell = nil
    state.player.channelStart = 0
    state.player.channelEnd   = 0
end

-- See mt_state for 'isChanneling'.





-- Spell Targets, so I don't have to convert it in APLs any more.
state.spell_targets = setmetatable( {}, {
    __index = function( t, k )
        local ability = class.abilities[ k ]

        if ability and ability.max_targets then
            return min( ability.max_targets, state.active_enemies )

        end

        return active_enemies
    end 
} )


-- Resource Modeling!
local events = {}
local remains = {}

local function resourceModelSort( a, b )
    return b == nil or ( a.next < b.next )
end


local FORECAST_DURATION = 7.5

local function forecastResources( resource )

    -- Forecasts the next 10s of resources.
    local models = class.regenModel

    table.wipe( events )
    table.wipe( remains )

    local now = state.now + state.offset

    if resource then
        local r = state[ resource ]

        -- We account for haste here so that we don't computer lots of extraneous future resource gains in Bloodlust/high haste situations.
        remains[ resource ] = FORECAST_DURATION * state.haste

        table.wipe( r.times )
        table.wipe( r.values )
        r.forecast[1] = r.forecast[1] or {}
        r.forecast[1].t = now
        r.forecast[1].v = r.actual
        r.fcount = 1
    else
        for k, v in pairs( class.resources ) do
            local r = state[ k ]
            remains[ k ] = FORECAST_DURATION * state.haste

            table.wipe( r.times )
            table.wipe( r.values )
            r.forecast[1] = r.forecast[1] or {}
            r.forecast[1].t = now
            r.forecast[1].v = r.actual
            state[ k ].fcount = 1
        end
    end

    if models then
        for k, v in pairs( models ) do
            if  ( not resource    or v.resource == resource ) and
                ( not v.spec      or state.spec[ v.spec ] ) and
                ( not v.equip     or state.equipped[ v.equip ] ) and 
                ( not v.talent    or state.talent[ v.talent ].enabled ) and
                ( not v.aura      or state[ v.debuff and 'debuff' or 'buff' ][ v.aura ].remains > 0 ) and
                ( not v.set_bonus or state.set_bonus[ v.set_bonus ] > 0 ) and
                ( not v.setting   or state.settings[ v.setting ] ) then

                local r = state[ v.resource ]

                local l = v.last()
                local i = ( type( v.interval ) == 'number' and v.interval or ( type( v.interval ) == 'function' and v.interval( now, r.actual ) or ( type( v.interval ) == 'string' and state[ v.interval ] or 0 ) ) )

                v.next = l + i
                v.name = k

                if v.next >= 0 then
                    table.insert( events, v )
                end
            end
        end
    end

    tSort( events, resourceModelSort )

    local finish = now + FORECAST_DURATION * state.haste

    local prev = now
    local iter = 0

    while( #events > 0 and now <= finish and iter < 20 ) do
        local e = events[1]
        local r = state[ e.resource ]
        iter = iter + 1

        if e.next > finish or not r then
            table.remove( events, 1 )

        else
            now = e.next
            local bonus = r.regen * ( now - prev )

            if ( e.stop and e.stop( r.forecast[ r.fcount ].v ) ) or ( e.aura and state[ e.debuff and 'debuff' or 'buff' ][ e.aura ].expires < now ) then
                table.remove( events, 1 )
               
                local v = max( 0, min( r.max, r.forecast[ r.fcount ].v + bonus ) )
                local idx

                if r.forecast[ r.fcount ].t == now then
                    -- Reuse the last one.
                    idx = r.fcount
                else
                    idx = r.fcount + 1
                end

                r.forecast[ idx ] = r.forecast[ idx ] or {}
                r.forecast[ idx ].t = now
                r.forecast[ idx ].v = v
                r.fcount = idx
            else
                prev = now

                local val = r.fcount > 0 and r.forecast[ r.fcount ].v or r.actual

                local v = max( 0, min( r.max, val + bonus + ( type( e.value ) == 'number' and e.value or e.value( now ) ) ) )
                local idx

                if r.forecast[ r.fcount ].t == now then
                    -- Reuse the last one.
                    idx = r.fcount
                else
                    idx = r.fcount + 1
                end

                r.forecast[ idx ] = r.forecast[ idx ] or {}
                r.forecast[ idx ].t = now
                r.forecast[ idx ].v = v
                r.fcount = idx

                -- interval() takes the last tick and the current value to remember the next step.
                local step = type( e.interval ) == 'number' and e.interval or ( type( e.interval ) == 'function' and e.interval( now, val ) or ( type( e.interval ) == 'string' and state[ e.interval ] or 0 ) )

                remains[ e.resource ] = finish - e.next
                e.next = e.next + step

                if e.next > finish or step < 0 then
                    table.remove( events, 1 )
                end
            end
        end

        if #events > 1 then tSort( events, resourceModelSort ) end
    end

    for k, v in pairs( remains ) do
        local r = state[ k ]
        local val = r.fcount > 0 and r.forecast[ r.fcount ].v or r.actual
        local idx = r.fcount + 1

        r.forecast[ idx ] = r.forecast[ idx ] or {}
        r.forecast[ idx ].t = finish
        r.forecast[ idx ].v = min( r.max, val + ( v * r.regen ) )
        r.fcount = idx
    end

end
ns.forecastResources = forecastResources


local function gain( amount, resource, overcap )

    -- 080217:  Update actual value to reflect current value + change, this means the forecasted values are used (and then need updated).
    if overcap then state[ resource ].actual = state[ resource ].current + amount
    else state[ resource ].actual = min( state[ resource ].max, state[ resource ].current + amount ) end

    if amount ~= 0 and resource ~= "health" then forecastResources( resource ) end

    ns.callHook( 'gain', amount, resource, overcap )

end
state.gain = gain


local function spend( amount, resource )
    
    -- 080217:  Update actual value to reflect current value + change, this means the forecasted values are used (and then need updated).
    state[ resource ].actual = max( 0, state[ resource ].actual - amount )
    if amount ~= 0 and resource ~= "health" then forecastResources( resource ) end
    
    ns.callHook( 'spend', amount, resource )

end
state.spend = spend


do
    -- Rechecking System
    -- Setup on a per-ability basis, this gives the prediction engine a head's up that the ability may become ready in a short time.

    state.recheckTimes = {}

    local lastRecheckAbility = nil
    local lastRecheckTime = 0

    function state.recheck( ability, ... )
        local args = select( "#", ... )

        if ability == lastRecheckAbility and state.query_time == lastRecheckTime then
            return
        end

        local times = state.recheckTimes
        tWipe( times )

        lastRecheckAbility = ability
        lastRecheckTime = state.query_time

        -- Hekili:Print( "Recheck given " .. args .. " args for " .. ability .. "." )
        -- print( ... )

        tInsert( times, 0.01 + state.gcd * 0.5 )

        for i = 1, args do
            local t = select( i, ... )

            if type( t ) == 'number' and t > 0 then
                tInsert( times, 0.01 + t )
            else
                -- Hekili:Print( "Arg " .. ( t and t or "(nil)" ) .. " was <= 0." )
            end
        end

        tSort( times )
    end

end



--------------------------------------
-- UGLY METATABLES BELOW THIS POINT --
--------------------------------------
ns.metatables = {}
local metafunctions = {
    action = {},
    active_dot = {},
    buff = {},
    cooldown = {},
    debuff = {},
    default_action = {},
    default_aura = {},
    default_cooldown = {},
    default_debuff = {},
    default_glyph = {},
    default_pet = {},
    default_totem = {},
    glyph = {},
    perk = {},
    pet = {},
    resource = {},
    set_bonus = {},
    settings = {},
    spec = {},
    stance = {},
    stat = {},
    state = {},
    talent = {},
    target = {},
    target_health = {},
    toggle = {},
    totem = {},
}

ns.addMetaFunction = function( t, k, func )
    
    if metafunctions[ t ] then
        metafunctions[ t ][ k ] = setfenv( func, state )
        return
    end
    
    ns.Error( "addMetaFunction() - no such table '" .. t .. "' for key '" .. k .. "'." )
    
end


-- Returns false instead of nil when a key is not found.
local mt_false = {
    __index = function(t, k)
        return false
    end
}
ns.metatables.mt_false = mt_false


-- Gives calculated values for some state options in order to emulate SimC syntax.
local mt_state = {
    __index = function(t, k)

        if metafunctions.state[ k ] then
            return metafunctions.state[ k ]()
            
        -- First, any values that don't reference an ability or aura.
        elseif k == 'this_action' or k == 'current_action' then
            return 'wait'

        elseif k == 'delay' then
            return 0

        elseif k == 'cycle' then
            return false

        elseif k == 'cast_start' then
            return 0

        elseif k == 'channeling' then
            return t.player.channelSpell ~= nil and t.player.channelEnd > t.query_time

        elseif k == 'channel' then
            return t.channeling and t.player.channelSpell or nil
            
        elseif k == 'ranged' then
            return false
            
        elseif k == 'wait_for_gcd' then 
            -- For specs that have to weave a lot of off GCD stuff.
            -- i.e., Frost DK.
            return false

        elseif k == 'query_time' then
            return t.now + t.offset + t.delay
            
        elseif k == 'time_to_die' then
            return max( 5, ns.getTTD( 'target' ) - ( t.offset + t.delay ) )
            
        elseif k == 'moving' then
            return ( GetUnitSpeed('player') > 0 )
            
        elseif k == 'group' then
            return IsInGroup()
            
        elseif k == 'group_members' then
            return max( 1, GetNumGroupMembers() )
            
        elseif k == 'level' then
            return ( UnitLevel('player') or MAX_PLAYER_LEVEL )
            
        elseif k == 'active' then
            return false
            
        elseif k == 'active_enemies' then
            -- The above is not needed as the nameplate target system will add missing enemies.
            t[k] = ns.getNumberTargets()
            
            if t.min_targets > 0 then t[k] = max( t.min_targets, t[k] ) end
            if t.max_targets > 0 then t[k] = min( t.max_targets, t[k] ) end
            
            t[k] = max( 1, t[k] )
            
            return t[k]
            
        elseif k == 'my_enemies' then
            -- The above is not needed as the nameplate target system will add missing enemies.
            t[k] = ns.numTargets()
            
            if t.min_targets > 0 then t[k] = max( t.min_targets, t[k] ) end
            if t.max_targets > 0 then t[k] = min( t.max_targets, t[k] ) end
            
            t[k] = max( 1, t[k] )
            
            return t[k]
            
        elseif k == 'true_active_enemies' then
            t[k] = max( 1, ns.getNumberTargets() )
            return t[k]
            
        elseif k == 'true_my_enemies' then
            t[k] = max( 1, ns.numTargets() )
            return t[k]
            
        elseif k == 'haste' or k == 'spell_haste' then
            return ( 1 / ( 1 + t.stat.spell_haste ) )
            
        elseif k == 'melee_haste' then
            return ( 1 / ( 1 + t.stat.melee_haste ) )
            
        elseif k == 'mastery_value' then
            return ( GetMastery() / 100 )
            
        elseif k == 'miss_react' then
            return false
            
        elseif k == 'cooldown_react' or k == 'cooldown_up' then
            return t.cooldown[ t.this_action ].remains == 0
            
        elseif k == 'cast_delay' then return 0

        elseif k == 'in_flight' then return t.action[ t.this_action ].in_flight
            
        elseif k == 'single' then
            return t.toggle.mode == 0 or ( t.toggle.mode == 3 and active_enemies == 1 )
            
        elseif k == 'cleave' or k == 'auto' then
            return t.toggle.mode == 3
            
        elseif k == 'aoe' then
            return t.toggle.mode == 2
            
        elseif type(k) == 'string' and k:sub(1, 16) == 'incoming_damage_' then
            local remains = k:sub(17)
            local time = remains:match("^(%d+)[m]?s")
            
            if not time then
                return 0
                -- error("ERR: " .. remains)
            end
            
            time = tonumber( time )
            
            if time > 100 then
                t.k = ns.damageInLast( time / 1000 )
            else
                t.k = ns.damageInLast( min( 15, time ) )
            end
            
            table.insert( t.purge, k )
            return t.k
            
        elseif k:sub(1, 14) == 'incoming_heal_' then
            local remains = k:sub(15)
            local time = remains:match("^(%d+)[m]?s")
            
            if not time then
                return 0
                -- error("ERR: " .. remains) 
            end
            
            time = tonumber( time )
            
            if time > 100 then
                t.k = ns.healingInLast( time / 1000 )
            else
                t.k = ns.healingInLast( min( 15, time ) )
            end
            
            table.insert( t.purge, k )
            return t.k
            
        end


        -- The next block are values that reference an ability.
        local action = t.this_action
        local ability = class.abilities[ action ]

        if k == 'time' then
            -- Calculate time in combat.
            if t.combat == 0 and t.false_start == 0 then
                if ability and ability.passive then return 0 end
                return t.offset
            end
            return t.now + ( t.offset or 0 ) - ( t.combat > 0 and t.combat or t.false_start ) + ( ( t.combat > 0 or t.false_start ) and t.delay or 0 )
            
            -- These are all action-related keywords, use 'this_action' to reference the relevant action.
        elseif k == 'cast_time' then
            return ability and ability.cast or 0
            
        elseif k == 'execute_time' then
            return max( t.gcd, ability and ability.cast or 0 )
            
        elseif k == 'gcd' then
            local gcdType = ability and ability.gcdType or "spell"

            if gcdType == 'totem' then return 1.0 end
            return max( 0.75, 1.5 * t.haste )
            
        elseif k == 'travel_time' then 
            local v = ability.velocity or 0
            if v > 0 then
                return t.target.maxR / v
            end
            return 0
        
        elseif k == 'charges' then
            return t.cooldown[ action ].charges
            
        elseif k == 'charges_fractional' then
            return t.cooldown[ action ].charges_fractional
            
        elseif k == 'max_charges' then
            return ability and ability.charges or 1
            
        elseif k == 'recharge' then
            -- TODO: Recheck what value SimC would use for recharge if an ability doesn't have charges.
            return t.cooldown[ action ].recharge
            
        elseif k == 'recharge_time' then
            -- TODO: Recheck what value SimC would use for recharge if an ability doesn't have charges.
            return t.cooldown[ action ].recharge_time
            
        elseif k == 'cast_regen' then
            return max( t.gcd, ability.cast or 0 ) * state[ ability.spend_type or class.primaryResource ].regen
            
        elseif k == 'prowling' then
            return t.buff.prowl.up or ( t.buff.cat_form.up and t.buff.shadowform.up )

        end
            

        -- Buffs, debuffs...
        local aura_name = ability.aura or t.this_action
        local aura = class.auras[ aura_name ]
        
        local app = t.buff[ aura_name ].up and t.buff[ aura_name ] or t.debuff[ aura_name ]

        if k == 'duration' then            
            return aura and aura.duration or 30
            
        elseif k == 'refreshable' then
            if app then return app.remains < 0.3 * app.duration end
            return false
            
        elseif k == 'ticking' then
            if app then return app.up end
            return false
            
        elseif k == 'ticks' then
            if app then return ( app.duration or 30 ) / ( app.tick_time or ( 3 * t.haste ) ) end
            return 10
            
        elseif k == 'ticks_remain' then
            if app then return ( app.remains / ( app.tick_time or ( 3 * t.haste ) ) ) end
            return 0

        elseif k == 'tick_time_remains' then
            if app then return ( app.remains % ( app.tick_time or ( 3 * t.haste ) ) ) end
            return 0
            
        elseif k == 'remains' then
            if app then return app.remains end
            return 0
            
        elseif k == 'tick_time' then
            if app then return ( app.up and ( aura.tick_time or ( 3 * t.haste ) ) or 0 ) end
            return 0

        elseif k == 'duration' then
            if app then return app.duration or 30 end
            if aura then return aura.duration or 30 end
            return 0

        end


        -- Check if this is a resource table pre-init.
        for i, key in pairs( class.resources ) do
            if k == key then
                return nil
            end
        end


        if t.variable[k] ~= nil then return t.variable[k] end
        if t.settings[k] ~= nil then return t.settings[k] end
        if t.toggle[k] ~= nil then return t.toggle[k] end
        
        return k
        
    end,
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end
}
ns.metatables.mt_state = mt_state


local mt_spec = {
    __index = function(t, k)
        return false
    end
}
ns.metatables.mt_spec = mt_spec


local mt_stat = {
    __index = function(t, k)
        if k == 'strength' then
            return UnitStat('player', 1)
            
        elseif k == 'agility' then
            return UnitStat('player', 2)
            
        elseif k == 'stamina' then
            return UnitStat('player', 3)
            
        elseif k == 'intellect' then
            return UnitStat('player', 4)
            
        elseif k == 'spirit' then
            return UnitStat('player', 5)
            
        elseif k == 'health' then
            return UnitHealth('player')
            
        elseif k == 'maximum_health' then
            return UnitHealthMax('player')

        elseif k == 'health_pct' then
            return UnitHealth( 'player' ) / UnitHealthMax( 'player' )
            
        elseif k == 'mana' then
            return Hekili.State.mana and Hekili.State.mana.current or 0
            
        elseif k == 'maximum_mana' then
            return Hekili.State.mana and Hekili.State.mana.max or 0
            
        elseif k == 'rage' then
            return Hekili.State.rage and Hekili.State.rage.current or 0
            
        elseif k == 'maximum_rage' then
            return Hekili.State.rage and Hekili.State.rage.max or 0
            
        elseif k == 'energy' then
            return Hekili.State.energy and Hekili.State.energy.current or 0
            
        elseif k == 'maximum_energy' then
            return Hekili.State.energy and Hekili.State.energy.max or 0
            
        elseif k == 'focus' then
            return Hekili.State.focus and Hekili.State.focus.current or 0
            
        elseif k == 'maximum_focus' then
            return Hekili.State.focus and Hekili.State.focus.max or 0
            
        elseif k == 'runic' or k == 'runic_power' then
            return Hekili.State.runic_power and Hekili.State.runic_power.current or 0
            
        elseif k == 'maximum_runic' or k == 'maximum_runic_power' then
            return Hekili.State.runic_power and Hekili.State.runic_power.max or 0
            
        elseif k == 'spell_power' then
            return GetSpellBonusDamage(7)
            
        elseif k == 'mp5' then
            return t.mana and Hekili.State.mana.regen or 0
            
        elseif k == 'attack_power' then
            return UnitAttackPower('player')
            
        elseif k == 'crit_rating' then
            return GetCombatRating(CR_CRIT_MELEE)
            
        elseif k == 'haste_rating' then
            return GetCombatRating(CR_HASTE_MELEE)
            
        elseif k == 'weapon_dps' then
            return -- error("NYI")
            
        elseif k == 'weapon_speed' then
            return -- error("NYI")
            
        elseif k == 'weapon_offhand_dps' then
            return -- error("NYI")
            -- return OffhandHasWeapon()
            
        elseif k == 'weapon_offhand_speed' then
            return -- error("NYI")
            
        elseif k == 'armor' then
            return -- error("NYI")
            
        elseif k == 'bonus_armor' then
            return UnitArmor('player')
            
        elseif k == 'resilience_rating' then
            return GetCombatRating(CR_CRIT_TAKEN_SPELL)
            
        elseif k == 'mastery_rating' then
            return GetCombatRating(CR_MASTERY)
            
        elseif k == 'mastery_value' then
            return GetMasteryEffect()
            
        elseif k == 'multistrike_rating' then
            return GetCombatRating(CR_MULTISTRIKE)
            
        elseif k == 'multistrike_pct' then
            return GetMultistrike()
            
        elseif k == 'mod_haste_pct' then
            return 0
            
        elseif k == 'spell_haste' then
            return ( UnitSpellHaste('player') + ( t.mod_haste_pct or 0 ) ) / 100
            
        elseif k == 'melee_haste' then
            return ( GetMeleeHaste('player') + ( t.mod_haste_pct or 0 ) ) / 100
            
        elseif k == 'haste' then
            return t.spell_haste or t.melee_haste
            
        elseif k == 'mod_crit_pct' then
            return 0
            
        elseif k == 'crit' then
            return ( GetCritChance( 'player' ) + ( t.mod_crit_pct or 0 ) )
            
        end
        
        -- Hekili:Error( "Unknown state.stat key: '" .. k .. "'." )
        return
    end
}
ns.metatables.mt_stat = mt_stat


-- Table of default handlers for specific pets/totems.
local mt_default_pet = {
    __index = function(t, k)
        --[[ if rawget( t, "permanent" ) then
            if k == 'up' or k == 'exists' then
                return UnitExists( 'pet' ) and ( not UnitIsDead( 'pet' ) )

            elseif k == 'alive' then
                return not UnitIsDead( 'pet' )

            elseif k == 'dead' then
                return UnitIsDead( 'pet' )

            elseif k == 'remains' then
                return 3600

            elseif k == 'down' then
                return not UnitExists( 'pet' ) or UnitIsDead( 'pet' )

            end
        end ]]

        if k == 'expires' then            
            local present, name, start, duration

            for i = 1, 5 do
                present, name, start, duration = GetTotemInfo( i )
            
                if present and name == class.abilities[ t.key ].name then
                    t.expires = start + duration
                    return t.expires
                end
            end

            t.expires = 0            
            return t[ k ]
            
        elseif k == 'remains' then
            return max( 0, t.expires - ( state.query_time ) )
            
        elseif k == 'up' or k == 'active' or k == 'alive' then
            return ( t.expires >= ( state.query_time ) )
            
        elseif k == 'down' then
            return ( t.expires < ( state.query_time ) )
            
        end
        
        return -- error("UNK: " .. k)
        
    end
}
ns.metatables.mt_default_pet = mt_default_pet


-- Table of pet data.
local mt_pets = {
    __index = function(t, k)
        -- Should probably add all totems, but holding off for now.
        for id, pet in pairs( t ) do
            if type( pet ) == 'table' and pet[ k ] then
                return pet[ k ]
            end
        end

        if k == 'up' or k == 'exists' then
            return UnitExists( 'pet' ) and ( not UnitIsDead( 'pet' ) )
            
        elseif k == 'alive' then
            return UnitExists( 'pet' ) and not UnitIsDead( 'pet' )
            
        elseif k == 'dead' then
            return UnitExists( 'pet' ) and UnitIsDead( 'pet' )
            
        end
        
        return t.fake_pet
        
    end,

    __newindex = function(t, k, v)
        if type(v) == 'table' then
            rawset( t, k, setmetatable( v, mt_default_pet ) )
        else
            rawset( t, k, v )
        end
    end
    
}
ns.metatables.mt_pets = mt_pets


local mt_stances = {
    __index = function( t, k )
        if not class.stances[ k ] or not GetShapeshiftForm() then return false
        elseif GetShapeshiftForm() < 1 then return false
            elseif not select( 5, GetShapeshiftFormInfo( GetShapeshiftForm() ) ) == class.stances[k] then return false end
        rawset(t, k, select( 5, GetShapeshiftFormInfo( GetShapeshiftForm() ) ) == class.stances[k] )
        return t[k]
    end
}
ns.metatables.mt_stances = mt_stances

-- Table of supported toggles (via keybinding).
-- Need to add a commandline interface for these, but for some reason, I keep neglecting that.
local mt_toggle = {
    __index = function(t, k)
        if metafunctions.toggle[ k ] then
            return metafunctions.toggle[ k ]()
            
        elseif k == 'cooldowns' then
            return ( Hekili.DB.profile.Cooldowns or ( Hekili.DB.profile.BloodlustCooldowns and state.buff.bloodlust.up ) ) or false

        elseif k == 'artifact' then
            return ( Hekili.DB.profile.Artifact or ( Hekili.DB.profile.CooldownArtifact and state.toggle.cooldowns ) ) or false
            
        elseif k == 'potions' then
            return Hekili.DB.profile.Potions or false
            
        elseif k == 'hardcasts' then
            return Hekili.DB.profile.Hardcasts or false
            
        elseif k == 'interrupts' then
            return Hekili.DB.profile.Interrupts or false
            
        elseif k == 'one' then
            return Hekili.DB.profile.Toggle_1 or false
            
        elseif k == 'two' then
            return Hekili.DB.profile.Toggle_2 or false
            
        elseif k == 'three' then
            return Hekili.DB.profile.Toggle_3 or false
            
        elseif k == 'four' then
            return Hekili.DB.profile.Toggle_4 or false
            
        elseif k == 'five' then
            return Hekili.DB.profile.Toggle_5 or false
            
        elseif k == 'mode' then
            return Hekili.DB.profile['Mode Status']
            
        else
            if Hekili.DB.profile[ 'Toggle State: '.. k ] ~= nil then
                return Hekili.DB.profile[ 'Toggle State: '..k ]
            end
            
            -- check custom names
            for i = 1, 5 do
                if k == Hekili.DB.profile['Toggle '..i..' Name'] then
                    return Hekili.DB.profile['Toggle_'..i] or false
                end
            end
            
            return
            
        end
    end
}
ns.metatables.mt_toggle = mt_toggle


local mt_settings = {
    __index = function(t, k)
        if metafunctions.settings[ k ] then
            return metafunctions.settings[ k ]()
        elseif Hekili.DB.profile[ 'Class Option: '..k ] ~= nil then
            return Hekili.DB.profile[ 'Class Option: '..k ]
        elseif Hekili.DB.profile.trinkets[ state.this_action ] ~= nil then
            if class.itemsInAPL[ state.spec.key ] and class.itemsInAPL[ state.spec.key ][ state.this_action ] then return false end
            return Hekili.DB.profile.trinkets[ state.this_action ][ k ]
        end
        
        return
    end
}
ns.metatables.mt_settings = mt_settings


-- Table of target attributes. Needs to be expanded.
-- Needs review.
local mt_target = {
    __index = function(t, k)
        if k == 'level' then
            return UnitLevel('target') or UnitLevel('player')
            
        elseif k == 'unit' then
            if state.args.cycle_target then return UnitGUID( 'target' ) .. 'c' or 'cycle'
                elseif state.args.target then return UnitGUID( 'target' ) .. '+' .. state.args.target or 'unknown' end
            return UnitGUID( 'target' ) or 'unknown'
            
        elseif k == 'time_to_die' then
            return max( 5, ns.getTTD( 'target' ) - ( state.offset + state.delay ) )
            
        elseif k == 'health_current' then
            return ( UnitHealth('target') > 0 and UnitHealth('target') or 50000 )
            
        elseif k == 'health_max' then
            return ( UnitHealthMax('target') > 0 and UnitHealthMax('target') or 50000 )
            
        elseif k == 'health_pct' or k == 'health_percent' then
            -- TBD: should health_pct use our time offset and TTD calculation to predict health?
            -- Currently deciding not to, as predicting that you can use something that you can't is
            -- probably worse than saying you can't use something that you can. Right?
            return t.health_max ~= 0 and ( 100 * ( t.health_current / t.health_max ) ) or 0
            
        elseif k == 'adds' then
            -- Need to return # of active targets minus 1.
            return max(0, ns.numTargets() - 1)
            
        elseif k == 'distance' then
            -- Need to identify a couple of spells to roughly get the distance to an enemy.
            -- We'd probably use IsSpellInRange() on an individual action instead, so maybe not.
            return ( t.minR + t.maxR ) / 2
            
        elseif k == 'moving' then
            return GetUnitSpeed( 'target' ) > 0
            
        elseif k == 'exists' then
            return UnitExists( 'target' )
            
        elseif k == 'casting' then
            if UnitName("target") and UnitCanAttack("player", "target") and UnitHealth("target") > 0 then
                local _, _, _, _, _, endCast, _, _, notInterruptible = UnitCastingInfo("target")
                
                if endCast ~= nil and not notInterruptible then
                    t.cast_end = endCast / 1000
                    return (endCast / 1000) > state.query_time
                end
                
                _, _, _, _, _, endCast, _, notInterruptible = UnitChannelInfo("target")
                
                if endCast ~= nil and not notInterruptible then
                    t.cast_end = endCast / 1000
                    return (endCast / 1000) > state.query_time
                end
            end
            return false
            
        elseif k == 'in_range' then
            local ability = state.this_action and class.abilities[ state.this_action ]
            
            if ability then
                return ( not state.target.exists or LibStub( "SpellRange-1.0" ).IsSpellInRange( ability.id, 'target' ) )
            end
            
            return true
            
        elseif k == 'is_demon' then
            return UnitCreatureType( 'target' ) == PET_TYPE_DEMON
            
        elseif k == 'is_undead' then
            return UnitCreatureType( 'target' ) == BATTLE_PET_NAME_4
            
        elseif k:sub(1, 6) == 'within' then
            local maxR = k:match( "^within(%d+)$" )
            
            if not maxR then
                -- error("UNK: " .. k)
                return false
            end
            
            return ( t.maxR <= tonumber( maxR ) )
            
        elseif k:sub(1, 7) == 'outside' then
            local minR = k:match( "^outside(%d+)$" )
            
            if not minR then
                -- error("UNK: " .. k)
                return false
            end
            
            return ( t.minR > tonumber( minR ) )
            
        elseif k:sub(1, 5) == 'range' then
            local minR, maxR = k:match( "^range(%d+)to(%d+)$" )
            
            if not minR or not maxR then
                return false
                -- error("UNK: " .. k)
            end 
            
            return ( t.minR >= tonumber( minR ) and t.maxR <= tonumber( maxR ) )
            
        elseif k == 'minR' then
            local minR = LibStub( "LibRangeCheck-2.0" ):GetRange( 'target' )
            if minR then
                rawset( t, k, minR )
                return t[k]
            end
            return 5
            
        elseif k == 'maxR' then
            local maxR = select( 2, LibStub( "LibRangeCheck-2.0" ):GetRange( 'target' ) )
            if maxR then
                rawset( t, k, maxR )
                return t[k]
            end
            return 10
            
        end
        
        return
        
    end
}
ns.metatables.mt_target = mt_target


local mt_target_health = {
    __index = function(t, k)
        if k == 'current' or k == 'actual' then
            return UnitCanAttack('player', 'target') and UnitHealth('target') or 0
            
        elseif k == 'max' then
            return UnitCanAttack('player', 'target') and UnitHealthMax('target') or 0
            
        elseif k == 'pct' or k == 'percent' then
            return t.max ~= 0 and ( 100 * t.current / t.max ) or 100
        end
    end
}
ns.metatables.mt_target_health = mt_target_health



local cd_meta_functions = {}

function ns.addCooldownMetaFunction( ability, key, func )
    if not state.cooldown[ ability ] then state.cooldown[ ability ] = { key = ability } end
    if not rawget( state.cooldown[ ability ], 'meta' ) then state.cooldown[ ability ].meta = {} end
    state.cooldown[ ability ].meta[ key ] = setfenv( func, state )
end


-- Table of default handlers for specific ability cooldowns.
local mt_default_cooldown = {
    __index = function(t, k)

        if rawget( t, 'meta' ) and t.meta[ k ] then
            return t.meta[ k ]()
        end

        local ability = t.key and class.abilities[ t.key ]
        local GetSpellCooldown = _G.GetSpellCooldown
        local profile = Hekili.DB.profile
        local id = ability.id

        if ability and ability.item then
            GetSpellCooldown = _G.GetItemCooldown
            id = ability.item
        end
        
        if k == 'duration' or k == 'expires' or k == 'next_charge' or k == 'charge' or k == 'recharge_began' then
            -- Refresh the ID in case we changed specs and ability is spec dependent.
            t.id = ability.id
            
            local start, duration = GetSpellCooldown( id )
            local true_duration = duration
            
            --[[ if class.abilities[ t.key ].toggle and not state.toggle[ class.abilities[ t.key ].toggle ] then
                start = state.now
                duration = 0
            end ]]
            
            if t.key == 'ascendance' and state.buff.ascendance.up then
                start = state.buff.ascendance.expires - class.auras.ascendance.duration
                duration = class.abilities[ 'ascendance' ].cooldown
                
            elseif t.key == 'potion' then
                local itemName = state.args.ModName or state.args.name or class.potion
                local potion = class.potions[ itemName ]

                if state.toggle.potions and potion and GetItemCount( potion.item ) > 0 then
                    start, duration = GetItemCooldown( potion.item )
                    
                else
                    start = state.now
                    duration = 0
                    
                end
                
            elseif not ns.isKnown( t.id ) then
                start = state.now
                duration = 0
            
            end
            
            t.duration = duration or 0
            t.expires = start and ( start + duration ) or 0
            t.true_duration = true_duration
            t.true_expires = start and ( start + true_duration ) or 0
            
            if class.abilities[ t.key ].charges then
                local charges, maxCharges, start, duration = GetSpellCharges( t.id )
                
                --[[ if class.abilities[ t.key ].toggle and not state.toggle[ class.abilities[ t.key ].toggle ] then
                    charges = 1
                    maxCharges = 1
                    start = state.now
                    duration = 0
                end ]]
                
                t.charge = charges or 1
                t.recharge = duration or class.abilities[ t.key ].recharge
                
                if charges and charges < maxCharges then
                    t.next_charge = start + duration
                else
                    t.next_charge = 0
                end
                t.recharge_began = start or t.expires - t.duration
                
            else
                t.charge = t.expires < state.query_time and 1 or 0
                t.next_charge = t.expires > state.query_time and t.expires or 0
                t.recharge_began = t.expires - t.duration
            end
            
            return t[k]
            
        elseif k == 'charges' then
            return floor( t.charges_fractional )
            
        elseif k == 'charges_max' then
            return class.abilities[ t.key ].charges
            
        elseif k == 'recharge' then
            return class.abilities[ t.key ].recharge
            
        elseif k == 'time_to_max_charges' then
            return ( class.abilities[ t.key ].charges - t.charges_fractional ) * class.abilities[ t.key ].recharge
            
        elseif k == 'remains' then
            
            if t.key == 'global_cooldown' then
                return max( 0, t.expires - state.query_time )
            end
            
            -- If the ability is toggled off in the profile, we may want to fake its CD.
            if ns.isKnown( t.key ) then
                if profile.blacklist[ t.key ] then
                    return ability.elem.cooldown
                end

                local toggle = profile.toggles[ t.key ]

                if not toggle or toggle == 'default' then toggle = ability.toggle end

                if toggle and not state.toggle[ toggle ] then
                    return ability.elem.cooldown
                end
            end
            
            local bonus_cdr = 0
            bonus_cdr = ns.callHook( "cooldown_recovery", bonus_cdr ) or bonus_cdr
            
            return max( 0, t.expires - state.query_time - bonus_cdr )
            
        elseif k == 'true_remains' then
            return max( 0, t.true_expires - state.query_time )
            
            --[[ if t.key == 'global_cooldown' then return remains end
            return max( class.abilities[ t.key ].gcdType ~= 'off' and state.cooldown.global_cooldown.remains or 0, remains ) ]]
            
        elseif k == 'charges_fractional' then
            if not ns.isKnown( t.key ) then return 1
            elseif class.abilities[ t.key ].charges then 
                if t.charge < class.abilities[ t.key ].charges then
                    return min( class.abilities[ t.key ].charges, t.charge + ( max( 0, state.query_time - t.recharge_began ) / t.recharge ) )
                    -- return t.charges + ( 1 - ( class.abilities[ t.key ].recharge - t.recharge_time ) / class.abilities[ t.key ].recharge )
                end
                return t.charge
            end
            return t.remains > 0 and 0 or 1
            
        elseif k == 'recharge_time' then
            if class.abilities[ t.key ].charges then
                if t.next_charge > ( state.query_time ) then
                    return ( t.next_charge - ( state.query_time ) )
                else
                    return 0
                end
            end
            return t.remains
            
        elseif k == 'up' or k == 'ready' then            
            return ( t.remains == 0 )
            
        end
        
        return
        
    end
}
ns.metatables.mt_default_cooldown = mt_default_cooldown


-- Table for gathering cooldown information. Some abilities with odd behavior are getting embedded here.
-- Probably need a better system that I can keep in the class modules.
-- Needs review.
local mt_cooldowns = {
    -- The action doesn't exist in our table so check the real game state, -- and copy it so we don't have to use the API next time.
    __index = function(t, k)
        if not class.abilities[ k ] then
            -- error( "UNK: " .. k )
            return
        end
        
        local ability = class.abilities[ k ].id
        
        local success, start, duration = pcall( GetSpellCooldown, ability )
        if not success then
            error( "FAIL: " .. k )
            return nil
        end
        
        if k == 'ascendance' and state.buff.ascendance.up then
            start = state.buff.ascendance.expires - class.auras[k].duration
            duration = class.abilities[k].cooldown
            
        elseif k == 'potion' then
            local itemName = state.args.ModName or state.args.name or class.potion
            local potion = class.potions[ itemName ]
            
            if state.toggle.potions and potion and GetItemCount( potion.item ) > 0 then
                start, duration = GetItemCooldown( potion.item )
                
            else
                start = state.now
                duration = 0
                
            end

        elseif not ns.isKnown( ability ) then
            start = state.now
            duration = 0
        end
        
        if start then
            t[k] = {
                key = k, name = class.abilities[ k ].name, id = ability, duration = duration, expires = (start + duration)
            }
        else
            t[k] = {
                key = k, name = class.abilities[ k ].name, id = ability, duration = 0, expires = 0
            }
        end
        
        if class.abilities[ k ].charges then
            local charges, maxCharges, start, duration = GetSpellCharges( t[k].id )
            t[ k ].charge = charge or 1
            if charges then
                if start + duration < state.query_time then
                    t[ k ].charge = t[ k ].charge + 1
                    if t[ k ].charge < class.abilities[ k ].charges then
                        t[ k ].next_charge = t[ k ].next_charge + class.abilities[ k ].cooldown
                    else
                        t[ k ].next_charge = 0
                    end
                else
                    t[ k ].next_charge = charges < class.abilities[ k ].charges and ( start + duration ) or 0
                end
            else
                t[ k ].next_charge = 0
            end
        else
            t[ k ].charge = t[ k ].expires < state.query_time and 1 or 0
            t[ k ].next_charge = t[ k ].expires
        end
        
        return t[k]
    end, 
    __newindex = function(t, k, v)
        rawset( t, k, setmetatable( v, mt_default_cooldown ) )
    end
}
ns.metatables.mt_cooldowns = mt_cooldowns


local mt_dot = {
    __index = function(t, k)
        if class.auras[k] and class.auras[k].friendly then
            return state.buff[k]
        end
        return state.debuff[k]
    end,
}
ns.metatables.mt_dot = mt_dot


local mt_prev_lookup = {
    __index = function( t, k )
        local idx = t.index
        
        if t.meta == 'castsAll' then
            -- Check predictions first.
            if state.predictions[ idx ] then return state.predictions[ idx ] == k end
            -- There isn't a prediction for that entry yet, go back to actual collected data.
            if state.player.queued_ability then
                if idx == #state.predictions + 1 then
                    return state.player.queued_ability
                end
                return ns.castsAll[ idx - #state.predictions + 1 ]
            end
            return ns.castsAll[ idx - #state.predictions ] == k
            
        elseif t.meta == 'castsOn' then
            -- Check predictions first.
            if state.predictionsOn[ idx ] then return state.predictionsOn[ idx ] == k end
            -- There isn't a prediction for that entry yet, go back to actual collected data.
            if state.player.queued_ability and state.player.queued_gcd then
                if idx == np + 1 then
                    return state.player.queued_ability
                end
                return ns.castsOn[ idx - #state.predictionsOn + 1 ]
            end
            return ns.castsOn[ idx - #state.predictionsOn ] == k
            
        end
        
        -- castsOff
        if state.predictionsOff[ idx ] then return state.predictionsOff[ idx ] == k end
        if state.player.queued_ability and state.player.queued_off then
            if idx == np + 1 then
                return state.player.queued_ability
            end
            return ns.castsOff[ idx - #state.predictionsOff + 1 ]
        end
        return ns.castsOff[ idx - #state.predictionsOff ] == k
        
    end
}

local prev_lookup = setmetatable( {
    index = 1,
    meta = 'castsAll'
}, mt_prev_lookup )


local mt_prev = {
    __index = function( t, k )
        if type( k ) == 'number' then
            -- This is a SimulationCraft 7.1.5 or later indexed lookup, we support up to #5.
            if k < 1 or k > 5 then return false end
            prev_lookup.meta = t.meta -- Which data to use? castsAll, castsOn (GCD), castsOff (offGCD)?
            prev_lookup.index = k
            return prev_lookup
        end
        
        if k == t.last then
            return true
        end
        
        return false
    end
}
ns.metatables.mt_prev = mt_prev


local resource_meta_functions = {}

function ns.addResourceMetaFunction( name, f )
    resource_meta_functions[ name ] = f
end


function ns.timeToResource( t, amount )

    if not amount or amount > t.max then return 3600
    elseif t.current >= amount then return 0 end

    if t.forecast and t.fcount > 0 then
        local q = state.query_time
        local index, slice

        if t.times[ amount ] then return t.times[ amount ] - q end

        if t.regen == 0 then
            for i = 1, t.fcount do
                local v = t.forecast[ i ]
                if v.v >= amount then
                    t.times[ amount ] = v.t
                    return max( 0, t.times[ amount ] - q )
                end
            end
            t.times[ amount ] = q + 3600
            return max( 0, t.times[ amount ] - q )
        end

        for i = 1, t.fcount do
            local slice = t.forecast[ i ]
            local after = t.forecast[ i + 1 ]
            
            if slice.v >= amount then
                t.times[ amount ] = slice.t
                return max( 0, t.times[ amount ] - q )

            elseif after and after.v >= amount then
                -- Our next slice will have enough resources.  Check to see if we'd regen enough in-between.
                local time_diff = after.t - slice.t
                local deficit = amount - slice.v
                local regen_time = deficit / t.regen

                if regen_time < time_diff then
                    t.times[ amount ] = ( slice.t + regen_time )
                else
                    t.times[ amount ] = after.t
                end
                return max( 0, t.times[ amount ] - q )
            end
        end
        t.times[ amount ] = q + 3600
        return max( 0, t.times[ amount ] - q )
    end

    -- This wasn't a modeled resource,, just look at regen time.
    if t.regen <= 0 then return 3600 end
    return max( 0, ( amount - t.current ) / t.regen )

end


local mt_resource = {
    __index = function(t, k)

        if resource_meta_functions[ k ] then
            local result = resource_meta_functions[ k ]( t )
        
            if result then
                return result
            end
        end
        
        if k == 'pct' or k == 'percent' then
            return 100 * ( t.current / t.max )
            
        elseif k == 'deficit_pct' or k == 'deficit_percent' then
            return 100 - t.pct
            
        elseif k == 'current' then
            -- If this is a modeled resource, use our lookup system.
            if t.forecast and t.fcount > 0 then
                local q = state.query_time
                local index, slice

                if t.values[ q ] then return t.values[ q ] end

                for i = 1, t.fcount do
                    local v = t.forecast[ i ]
                    if v.t <= q then
                        index = i
                        slice = v
                    else
                        break
                    end
                end

                -- We have a slice.
                if index and slice then
                    t.values[ q ] = max( 0, min( t.max, slice.v + ( ( state.query_time - slice.t ) * t.regen ) ) )
                    return t.values[ q ]
                end
            end

            -- No forecast.
            if t.regen ~= 0 then
                return max( 0, min( t.max, t.actual + ( t.regen * state.delay ) ) )
            end

            return t.actual
            
        elseif k == 'deficit' then
            return t.max - t.current
            
        elseif k == 'max_nonproc' then
            return t.max -- need to accommodate buffs that increase mana, etc.
            
        elseif k == 'time_to_max' then
            return ns.timeToResource( t, t.max )
            
        elseif k:sub(1, 8) == 'time_to_' then
            local amount = k:sub(9)
            amount = tonumber(amount)

            if not amount then return 3600 end

            return ns.timeToResource( t, amount )

        elseif k == 'regen' then
            return t.active_regen

        elseif k == 'model' then
            return

        elseif k == 'onAdvance' then
            return
            
        end
        
    end
}
ns.metatables.mt_resource = mt_resource


local default_buff_values = {
    count = 0,
    expires = 0,
    applied = 0,
    duration = 15,
    caster = 'nobody',
    timeMod = 1,
    v1 = 0,
    v2 = 0,
    v3 = 0,
    unit = 'player'
}


function ns.addBuffMetaFunction( aura, key, func )
    if not class.auras[ aura ] then return end
    if not rawget( state.buff[ aura ], 'meta' ) then state.buff[ aura ].meta = {} end
    state.buff[ aura ].meta[ key ] = setfenv( func, state )
end


-- Table of default handlers for auras (buffs, debuffs).
local mt_default_buff = {
    __index = function(t, k)
        if rawget( t, 'meta' ) and t.meta[ k ] then
            return t.meta[ k ]()

        elseif k == 'name' or k == 'count' or k == 'duration' or k == 'expires' or k == 'applied' or k == 'caster' or k == 'id' or k == 'timeMod' or k == 'v1' or k == 'v2' or k == 'v3' or k == 'unit' then            
            if class.auras[ t.key ].elem.feign then
                class.auras[ t.key ].feign()
                return t[ k ]
            end
            
            local real = auras.player.buff[ t.key ] or auras.target.buff[ t.key ]
            
            if real then
                t.name = real.name
                t.count = real.count
                t.duration = real.duration
                t.expires = real.expires
                t.applied = max( 0, real.expires - real.duration )
                t.caster = real.caster
                t.id = real.id or class.auras[ t.key ].id
                t.timeMod = real.timeMod
                t.v1 = real.v1
                t.v2 = real.v2
                t.v3 = real.v3
                
                t.unit = real.unit
            else
                for attr, a_val in pairs( default_buff_values ) do
                    t[ attr ] = class.auras[ t.key ] and class.auras[ t.key ][ attr ] or a_val
                end
            end
            
            return t[k]
            
        elseif k == 'up' or k == 'ticking' then
            return t.count > 0 and t.expires >= state.query_time

        elseif k == 'i_up' then
            return ( t.count > 0 and t.expires >= state.query_time ) and 1 or 0
            
        elseif k == 'down' then
            return t.count == 0 or t.expires < state.query_time 
            
        elseif k == 'remains' then
            if t.expires > ( state.query_time ) then
                return ( t.expires - ( state.query_time ) )
            else
                return 0                
            end
            
        elseif k == 'refreshable' then
            return t.remains < 0.3 * t.duration
            
        elseif k == 'cooldown_remains' then
            return state.cooldown[ t.key ] and state.cooldown[ t.key ].remains or 0
            
        elseif k == 'max_stack' then
            return class.auras[ t.key ].max_stack or 1
            
        elseif k == 'mine' then
            return t.caster == 'player'
            
        elseif k == 'stack' or k == 'stacks' or k == 'react' then
            if t.up then return ( t.count ) else return 0 end
            
        elseif k == 'stack_pct' then
            if t.up then return ( 100 * t.count / t.max_stack ) else return 0 end

        elseif k == 'ticks_remain' then
            if t.up then return math.ceil( t.remains / t.tick_time ) else return 0 end
        
        else
            if class.auras[ t.key ] and class.auras[ t.key ][ k ] ~= nil then
                return class.auras[ t.key ][ k ]
            end
        end
        
        error("UNK: " .. k)
        
    end,

    newindex = function( t, k, v )
        -- Prevent a fixed value from being entered if it is calculated by a meta function.
        if t.meta and t.meta[ k ] then
            return
        end
        t[ k ] = v
    end
}
ns.metatables.mt_default_buff = mt_default_buff


local unknown_buff = setmetatable( {
    key = 'unknown_buff',
    count = 0,
    duration = 0,
    expires = 0,
    applied = 0,
    caster = 'nobody',
    timeMod = 1,
    v1 = 0,
    v2 = 0,
    v3 = 0
}, mt_default_buff )


-- This will currently accept any key and make an honest effort to find the buff on the player.
-- Unfortunately, that means a buff.dog_farts.up check will actually get a return value.

-- Fullscan definitely needs revamping, but it works for now.
local mt_buffs = {
    -- The action doesn't exist in our table so check the real game state, -- and copy it so we don't have to use the API next time.
    __index = function(t, k)
        
        if k == '__scanned' then
            return false
        end
        
        local class_aura = class.auras[ k ]
        
        if not class_aura then
            return unknown_buff
        end
        
        if class_aura.elem.feign then
            t[k] = {
                key = k,
                name = class_aura.name
            }
            class_aura.feign()
            return t[k]
        end
        
        local real = auras.player.buff[ k ] or auras.target.buff[ k ]
        
        t[ k ] = {
            key = k,
            name = class_aura.name
        }
        
        local buff = t[ k ]
        
        if real then
            buff.name = real.name
            buff.count = real.count
            buff.duration = real.duration
            buff.expires = real.expires
            buff.applied = max( 0, real.expires - real.duration )
            buff.caster = real.caster
            buff.id = real.id
            buff.timeMod = real.timeMod
            buff.v1 = real.v1
            buff.v2 = real.v2
            buff.v3 = real.v3
            
            buff.unit = real.unit
            
        else
            buff.name = class_aura.name or "No Name"
            buff.count = 0
            buff.duration = class_aura.duration or 30
            buff.expires = 0
            buff.applied = 0
            buff.caster = 'nobody'
            buff.id = nil
            buff.timeMod = 1
            buff.v1 = 0
            buff.v2 = 0
            buff.v3 = 0
            
            buff.unit = class_aura.unit or 'player'
        end
        
        return t[k]
        
    end,
    
    __newindex = function(t, k, v)
        rawset( t, k, setmetatable( v, mt_default_buff ) )
    end
}
ns.metatables.mt_buffs = mt_buffs


-- The empty glyph table.
local null_glyph = {
    enabled = false
}
ns.metatables.null_glyph = null_glyph


-- Table for checking if a glyph is active.
-- If the value wasn't specifically added by the addon, then it returns an empty glyph.
local mt_glyphs = {
    __index = function(t, k)
        return ( null_glyph )
    end
}
ns.metatables.mt_glyphs = mt_glyphs


-- Table for checking if a talent is active. Conveniently reuses the glyph metatable.
-- If the value wasn't specifically added by the addon, then it returns an empty glyph.
local mt_talents = {
    __index = function(t, k)
        return ( null_glyph )
    end
}
ns.metatables.mt_talents = mt_talents


local mt_default_trait = {
    __index = function( t, k )
        if k == 'enabled' then
            return t.rank and t.rank > 0
        elseif k == 'disabled' then
            return not t.rank or t.rank == 0
        end
    end
}


local mt_artifact_traits = {
    __index = function( t, k )
        return t.no_trait
    end,
    
    __newindex = function( t, k, v )
        rawset( t, k, setmetatable( v, mt_default_trait ) )
        return t.k
    end
}

setmetatable( state.artifact, mt_artifact_traits )
state.artifact.no_trait = { rank = 0 }
-- rawset( state.artifact, no_trait, setmetatable( {}, mt_default_trait ) )


local mt_perks = {
    __index = function(t, k)
        return ( null_glyph )
    end
}
ns.metatables.mt_perks = mt_perks


-- Table for counting active dots.
local mt_active_dot = {
    __index = function(t, k)
        if class.auras[ k ] then
            t[k] = ns.numDebuffs( class.auras[ k ].id )
            return t[k]
            
        else
            return 0
            
        end
    end
}
ns.metatables.mt_active_dot = mt_active_dot


-- Table of default handlers for a totem. Under-implemented at the moment.
-- Needs review.
local mt_default_totem = {
    __index = function(t, k)
        if k == 'expires' then
            local _, name, start, duration = GetTotemInfo( t.totem )
            
            t.name = name
            t.expires = ( start or 0 ) + ( duration or 0 )
            
            return t[ k ]
            
        elseif k == 'up' or k == 'active' then
            return ( t.expires > ( state.query_time ) )
            
        elseif k == 'remains' then
            if t.expires > ( state.query_time ) then
                return ( t.expires - ( state.query_time ) )
            else
                return 0
            end
            
        end
        
        error("UNK: " .. k)
    end
}
Hekili.mt_default_totem = mt_default_totem


-- Table of totems. Currently Shaman-centric.
-- Needs review.
local mt_totem = {
    __index = function(t, k)
        if k == 'fire' then
            local _, name, start, duration = GetTotemInfo(1)
            
            t[k] = {
            key = k, totem = 1, name = name, expires = (start + duration) or 0, }
            return t[k]
            
        elseif k == 'earth' then
            local _, name, start, duration = GetTotemInfo(2)
            
            t[k] = {
            key = k, totem = 2, name = name, expires = (start + duration) or 0, }
            return t[k]
            
        elseif k == 'water' then
            local _, name, start, duration = GetTotemInfo(3)
            
            t[k] = {
            key = k, totem = 3, name = name, expires = (start + duration) or 0, }
            return t[k]
            
        elseif k == 'air' then
            local _, name, start, duration = GetTotemInfo(4)
            
            t[k] = {
            key = k, totem = 4, name = name, expires = (start + duration) or 0, }
            return t[k]
        end
        
        error( "UNK: " .. k )
        
        end, __newindex = function(t, k, v)
        rawset( t, k, setmetatable( v, mt_default_totem ) )
    end
}
ns.metatables.mt_totem = mt_totem


local mt_variable = {
    __index = function( t, k )
        local id = rawget( t, "_" .. k )
        
        if id then
            local value = ns.checkScript( 'A', id )
            return value
        end
        
        return
    end
}
ns.metatables.mt_variable = mt_Variable

state.variable = setmetatable( {}, mt_variable )


-- Table of set bonuses. Some string manipulation to honor the SimC syntax.
-- Currently returns 1 for true, 0 for false to be consistent with SimC conditionals.
-- Won't catch fake set names. Should revise.
local mt_set_bonuses = {
    __index = function(t, k)
        if type(k) == 'number' then return 0 end
        
        if ( not class.artifacts[ k ] ) and ( state.bg or state.arena ) then return 0 end
        
        local set, pieces, class = k:match("^(.-)_"), tonumber( k:match("_(%d+)pc") ), k:match("pc(.-)$")
        
        if not pieces or not set then
            -- This wasn't a tier set bonus.
            return 0
            
        else
            if class then set = set .. class end
            
            if not t[set] then
                return 0
            end
            
            return t[set] >= pieces and 1 or 0
        end
        
        return 0
        
    end
}
ns.metatables.mt_set_bonuses = mt_set_bonuses


local mt_equipped = {
    __index = function(t, k)
        if not class.artifacts[ k ] and ( state.bg or state.arena ) then return false end
        return state.set_bonus[k] > 0
    end
}
ns.metatables.mt_equipped = mt_equipped


local default_debuff_values = {
    count = 0,
    expires = 0,
    applied = 0,
    duration = 15,
    caster = 'nobody',
    timeMod = 1,
    v1 = 0,
    v2 = 0,
    v3 = 0,
    unit = 'target'
}


-- Table of default handlers for debuffs.
-- Needs review.
local mt_default_debuff = {
    __index = function(t, k)
        local class_aura = class.auras[ t.key ]
        
        if k == 'name' or k == 'count' or k == 'expires' or k == 'applied' or k == 'duration' or k == 'caster' or k == 'timeMod' or k == 'v1' or k == 'v2' or k == 'v3' or k == 'unit' then
            
            if class_aura and class_aura.elem.feign then
                class_aura.feign()
                return t[ k ]
            end
            
            local real = auras.target.debuff[ t.key ] or auras.player.debuff[ t.key ]
            
            if real then
                t.name = real.name
                t.count = real.count
                t.duration = real.duration
                t.expires = real.expires
                t.applied = max( 0, real.expires - real.duration )
                t.caster = real.caster
                t.id = real.id
                t.timeMod = real.timeMod
                t.v1 = real.v1
                t.v2 = real.v2
                t.v3 = real.v3
                
                t.unit = real.unit
            else
                for attr, a_val in pairs( default_debuff_values ) do
                    t[ attr ] = class.auras[ t.key ] and class.auras[ t.key ][ attr ] or a_val
                end
            end
            
            return t[ k ]
            
        elseif k == 'up' then
            return ( t.count > 0 and t.expires >= state.query_time )


        elseif k == 'i_up' then
            return ( t.count > 0 and t.expires >= state.query_time ) and 1 or 0

        elseif k == 'down' then
            return ( t.count == 0 or t.expires < state.query_time )
            
        elseif k == 'remains' then
            if t.expires > state.query_time then
                return ( t.expires - state.query_time )
                
            end
            return 0
            
        elseif k == 'refreshable' then
            return t.remains < 0.3 * ( class_aura and class_aura.duration or 30 )
            
        elseif k == 'stack' or k == 'react' then
            if t.up then return ( t.count ) else return 0 end
            
        elseif k == 'stack_pct' then
            if t.up then
                if class_aura then class_aura.max_stack = max( class_aura.max_stack or 1, t.count ) end
                return ( 100 * t.count / class_aura and class_aura.max_stack or t.count )
            end 
            
            return 0

        elseif k == 'pmultiplier' then
            -- Persistent modifier, used by Druids.
            return ns.getModifier( class_aura.id, state.target.unit )
            
        elseif k == 'ticking' then
            return t.up

        elseif k == 'ticks_remain' then
            if not class_aura.tick_time then return t.remains end
            return floor( t.remains / class_aura.tick_time )       

        elseif k == 'tick_time_remains' then
            if not class_aura.tick_time then return t.remains end
            return t.remains % class_aura.tick_time
        
        else
            if class_aura and class_aura[ k ] ~= nil then
                return class_aura[ k ]
            end
        end
        
        -- error ("UNK: " .. k)
    end
}
ns.metatables.mt_default_debuff = mt_default_debuff


local unknown_debuff = setmetatable( {
    count = 0,
    expires = 0,
    timeMod = 1,
    v1 = 0,
    v2 = 0,
    v3 = 0
}, mt_default_debuff )


-- Table of debuffs applied to the target by the player.
-- Needs review.
local mt_debuffs = {
    -- The debuff/ doesn't exist in our table so check the real game state, -- and copy it so we don't have to use the API next time.
    __index = function(t, k)
        
        local class_aura = class.auras[ k ]
        
        t[k] = {
            key = k,
            name = class_aura and class_aura.name or k
        }
        
        if class_aura and class_aura.feign then
            class_aura.feign()
            return t[k]
        end
        
        local real = auras.target.debuff[ k ] or auras.player.debuff[ k ]
        local debuff = t[k]
        
        for key, value in pairs( real or default_debuff_values ) do
            debuff[ key ] = value
        end
        
        return t[k]
    end, 
    
    __newindex = function(t, k, v)
        rawset( t, k, setmetatable( v, mt_default_debuff ) )
    end
}
ns.metatables.mt_debuffs = mt_debuffs


-- Table of default handlers for actions.
-- Needs review.
local mt_default_action = {
    __index = function(t, k)

        local aura = class.abilities[ t.action ].aura or t.action

        if k == 'enabled' then
            return ns.isKnown( t.action )            

        elseif k == 'gcd' then
            if t.gcdType == 'offGCD' then return 0
            elseif t.gcdType == 'spell' then return max( 0.75, 1.5 * state.haste )
                -- This needs a class/spec check to confirm GCD is reduced by haste.
            elseif t.gcdType == 'melee' then return max( 0.75, 1.5 * state.haste )
            elseif t.gcdType == 'totem' then return 1
            else return 1.5 end
            
        elseif k == 'execute_time' then
            return max( t.gcd, t.cast_time )
            
        elseif k == 'charges' then
            return class.abilities[ t.action ].charges and state.cooldown[ t.action ].charges or 0
            
        elseif k == 'charges_fractional' then
            return state.cooldown[ t.action ].charges_fractional
            
        elseif k == 'recharge_time' then
            return class.abilities[ t.action ].recharge and state.cooldown[ t.action ].recharge or 0
            
        elseif k == 'max_charges' then
            return class.abilities[ t.action ].charges or 0

        elseif k == 'time_to_max_charges' then
            return ( class.abilities[ t.action ].charges - state.cooldown[ t.action ].charges_fractional ) * class.abilities[ t.action ].recharge
            
        elseif k == 'ready_time' then
            return ns.isUsable( t.action ) and ns.timeToReady( t.action ) or 999
            
        elseif k == 'ready' then
            return ns.isUsable( t.action ) and ns.isReady( t.action )
            
        elseif k == 'cast_time' then
            return class.abilities[ t.action ].cast
            
        elseif k == 'cooldown' then
            return class.abilities[ t.action ].cooldown
            
        elseif k == 'ticking' then
            return ( state.dot[ aura ].ticking )
            
        elseif k == 'ticks' then
            return math.ceil( state.dot[ aura ].duration / ( class.auras[ aura ].tick_time or ( 3 * state.haste ) ) )
            
        elseif k == 'ticks_remain' then
            return math.ceil( state.dot[ aura ].remains / ( class.auras[ aura ].tick_time or ( 3 * state.haste ) ) )
            
        elseif k == 'remains' then
            return ( state.dot[ aura ].remains )

        elseif k == 'tick_time' then
            return class.auras[ aura ].tick_time or ( 3 * state.haste )
            
        --[[ elseif k == 'tick_time' then
            if IsWatchedDoT( t.action ) then
                return ( GetWatchedDoT( t.action ).tick_time * state.haste )
            end
            return 0
            
        elseif k == 'tick_damage' then
            if IsWatchedDoT( t.action ) then
                return select(2, GetWatchedDoT( t.action ).handler() )
            end
            return 0 ]]
            
        elseif k == 'travel_time' then
            -- NYI: maybe capture the last travel time for the spell and use that?
            local v = class.abilities[ t.action ].velocity

            if v and v > 0 then return state.target.maxR / v end
            return 0
            
        elseif k == 'miss_react' then
            return false
            
        elseif k == 'cooldown_react' then
            return false
            
        elseif k == 'cast_delay' then
            return 0
            
        elseif k == 'cast_regen' then
            return floor( max( t.gcd, t.cast_time ) * state[ class.primaryResource ].regen )

        elseif k == 'cost' then
            local a = class.abilities[ t.action ].spend
            if type( a ) == 'function' then a = a() end
            return a

        elseif k == 'in_flight' then
            for i, spell in pairs( ns.spells_in_flight ) do
                if spell.key == t.action then
                    return true
                end
            end
            return false
            
        else
            local val = class.abilities[ t.action ][ k ]

            if val then
                if type( val ) == 'function' then return val() end
                return val
            end

            return 0
            
        end
        
        return 0
    end
}
ns.metatables.mt_default_action = mt_default_action


-- mt_actions: provides action information for display/priority queue/action criteria.
-- NYI.
local mt_actions = {
    __index = function(t, k)
        local action = class.abilities[ k ]
        
        -- Need a null_action table.
        if not action then return nil end
        
        t[k] = {
            action = k,
            name = action.name,
            base_cast = action.elem.cast,
            gcdType = action.gcdType
        }
        
        return ( t[k] )
        end, __newindex = function(t, k, v)
        rawset( t, k, setmetatable( v, mt_default_action ) )
    end
}
ns.metatables.mt_actions = mt_actions



-- mt_swings: used for projecting weapon swing-based resource gains.
local mt_swings = {
    __index = function( t, k )
        if k == 'mainhand' then
            return t.mh_pseudo and t.mh_pseudo or t.mh_actual
            
        elseif k == 'offhand' then
            return t.oh_pseudo and t.oh_pseudo or t.oh_actual
            
        elseif k == 'mainhand_speed' then
            return t.mh_pseudo_speed and t.mh_pseudo_speed or t.mh_speed
            
        elseif k == 'offhand_speed' then
            return t.oh_pseudo_speed and t.oh_pseudo_speed or t.oh_speed
            
        end
    end
}


local mt_aura = {
    __index = function( t, k )
        return rawget( state.buff, k ) or rawget( state.debuff, k )
    end
}


setmetatable( state, mt_state )
setmetatable( state.action, mt_actions )
setmetatable( state.active_dot, mt_active_dot )
-- setmetatable( state.artifact, mt_talents )
setmetatable( state.aura, mt_aura )
setmetatable( state.buff, mt_buffs )
setmetatable( state.cooldown, mt_cooldowns )
setmetatable( state.debuff, mt_debuffs )
setmetatable( state.dot, mt_dot )
setmetatable( state.equipped, mt_equipped )
setmetatable( state.glyph, mt_glyphs )
setmetatable( state.perk, mt_perks )
setmetatable( state.pet, mt_pets )
setmetatable( state.pet.fake_pet, mt_default_pet )
setmetatable( state.prev, mt_prev )
setmetatable( state.prev_gcd, mt_prev )
setmetatable( state.prev_off_gcd, mt_prev )
setmetatable( state.race, mt_false )
setmetatable( state.set_bonus, mt_set_bonuses )
setmetatable( state.settings, mt_settings )
setmetatable( state.spec, mt_spec )
setmetatable( state.stance, mt_stances )
setmetatable( state.stat, mt_stat )
setmetatable( state.swings, mt_swings )
setmetatable( state.talent, mt_talents )
setmetatable( state.target, mt_target )
setmetatable( state.target.health, mt_target_health )
setmetatable( state.toggle, mt_toggle )
setmetatable( state.totem, mt_totem )


-- 04072017: Let's go ahead and cache aura information to reduce overhead.
local autoAuraKey = setmetatable( {}, {
    __index = function( t, k )
        local aura_name = GetSpellInfo( k )
        
        if not aura_name then return end

        local name

        if class.auras[ aura_name ] then
            local i = 1

            while( true ) do
                local new = aura_name .. ' ' .. i

                if not class.auras[ new ] then
                    name = new
                    break
                end

                i = i + 1
            end
        end
        name = name or aura_name

        local key = formatKey( aura_name )
        
        if class.auras[ key ] then
            local i = 1
            
            while ( true ) do 
                local new = key .. '_' .. i
                
                if not class.auras[ new ] then
                    key = new
                    break
                end
                
                i = i + 1
            end
        end

        -- Store the aura and save the key if we can.
        if ns.addAura then
            ns.addAura( key, k, 'name', name )
            t[k] = key
        end
        
        return t[k]
    end
} )


local function scrapeUnitAuras( unit )
    
    local db = ns.auras[ unit ]
    
    for k,v in pairs( db.buff ) do
        v.name = nil
        v.count = 0
        v.expires = 0
        v.applied = 0
        v.duration = class.auras[ k ] and class.auras[ k ].duration or v.duration
        v.caster = 'nobody'
        v.timeMod = 1
        v.v1 = 0
        v.v2 = 0
        v.v3 = 0
        v.unit = unit
    end
    
    for k,v in pairs( db.debuff ) do
        v.name = nil
        v.count = 0
        v.expires = 0
        v.applied = 0
        v.duration = class.auras[ k ] and class.auras[ k ].duration or v.duration
        v.caster = 'nobody'
        v.timeMod = 1
        v.v1 = 0
        v.v2 = 0
        v.v3 = 0
        v.unit = unit
    end
    
    if not UnitExists( unit ) then return end
    
    local i = 1
    while ( true ) do
        local name, _, _, count, _, duration, expires, caster, _, _, spellID, _, _, _, _, timeMod, v1, v2, v3 = UnitBuff( unit, i, "PLAYER" )
        if not name then break end
        
        local key = class.auras[ spellID ] and class.auras[ spellID ].key
        -- if not key then key = class.auras[ name ] and class.auras[ name ].key end
        if not key then key = autoAuraKey[ spellID ] end
        
        if key then 
            db.buff[ key ] = db.buff[ key ] or {}
            local buff = db.buff[ key ]
            
            if expires == 0 then
                expires = GetTime() + 3600
                duration = 7200
            end
            
            buff.key = key
            buff.id = spellID
            buff.name = name
            buff.count = count > 0 and count or 1
            buff.expires = expires
            buff.duration = duration
            buff.applied = expires - duration
            buff.caster = caster
            buff.timeMod = timeMod
            buff.v1 = v1
            buff.v2 = v2
            buff.v3 = v3
            
            buff.unit = unit
        end
        
        i = i + 1
    end
    
    i = 1
    while ( true ) do
        local name, _, _, count, _, duration, expires, caster, _, _, spellID, _, _, _, _, timeMod, v1, v2, v3 = UnitDebuff( unit, i, "PLAYER" )
        if not name then break end
        
        local key = class.auras[ spellID ] and class.auras[ spellID ].key
        -- if not key then key = class.auras[ name ] and class.auras[ name ].key end
        if not key then key = autoAuraKey[ spellID ] end
        
        if key then 
            db.debuff[ key ] = db.debuff[ key ] or {}
            local debuff = db.debuff[ key ]
            
            if expires == 0 then
                expires = GetTime() + 3600
                duration = 7200
            end
            
            debuff.key = key
            debuff.id = spellID
            debuff.name = name
            debuff.count = count > 0 and count or 1
            debuff.expires = expires
            debuff.duration = duration
            debuff.applied = expires - duration
            debuff.caster = caster
            debuff.timeMod = timeMod
            debuff.v1 = v1
            debuff.v2 = v2
            debuff.v3 = v3
            
            debuff.unit = unit
        end
        
        i = i + 1
    end
    
end


--[[ local function modelResources( time )

    if time <= 0 then return end

    -- essential tables
    local models = class.regenModel

    -- Identify which resource events are actually relevant to us.
    table.wipe( events )
    table.wipe( remains )

    for k, v in pairs( class.resources ) do
        remains[ k ] = time
        table.wipe( state[ k ].times )
        table.wipe( state[ k ].values )
    end

    for k, v in pairs( models ) do
        if  ( not v.spec or state.spec[ v.spec ] ) and
            ( not v.equip or state.equipped[ v.equip ] ) and 
            ( not v.talent or state.talent[ v.talent ].enabled ) and 
            ( not v.aura or state.buff[ v.aura ].up ) and 
            ( not v.setting or state.settings[ v.setting ] ) then

            local r = state[ v.resource ]
            
            v.next = v.last() + ( type( v.interval ) == 'number' and v.interval or ( type( v.interval ) == 'function' and v.interval( 0, r.actual ) or ( type( v.interval ) == 'string' and state[ v.interval ] or 0 ) ) )
            v.name = k

            if v.next >= 0 then
                table.insert( events, v )
            end
        end
    end

    -- Sort the table in chronological order.
    tSort( events, resourceModelSort )

    -- Start from time = 0; currently assuming modelResource() will be called after the clock is advanced.

    local now = state.now + state.offset
    local finish = now + time

    local prev = now
    local iter = 0

    while( #events > 0 and now <= finish and iter < 20 ) do
        local e = events[1]
        local r = state[ e.resource ]
        iter = iter + 1

        if e.next > finish or not r then
            table.remove( events, 1 )
        
        else
            now = e.next

            -- Stop value checks current resource amount level.
            if ( e.stop and e.stop( r.actual ) ) or ( e.aura and state.buff[ e.aura ].expires < now ) then
                -- if resource == 'runes' then -- print( 'stop', time ) end
                table.remove( events, 1 )

            else
                local bonus = r.regen * ( now - prev )
                prev = now

                -- If a function, e.value takes the delay value (to ascertain if a buff expired, typically).
                -- if resource == 'runes' then -- print( 'at', time, 'go from', val ) end
                if e.fire then e.fire( now )
                else
                    r.actual = max( 0, min( r.max, r.actual + bonus + ( type( e.value ) == 'number' and e.value or e.value( now ) ) ) )
                end

                -- interval() takes the last tick and the current value to remember the next step.
                local step = type( e.interval ) == 'number' and e.interval or ( type( e.interval ) == 'function' and e.interval( time, r.actual ) or ( type( e.interval ) == 'string' and state[ e.interval ] or 0 ) )

                remains[ e.resource ] = finish - e.next

                e.next = e.next + step
                if e.next > finish or step < 0 then
                    table.remove( events, 1 )
                end
            end
        end

        if #events > 1 then tSort( events, resourceModelSort ) end
    end

    -- Regen any remaining resources.
    for k, v in pairs( remains ) do
        local r = state[ k ]

        if r.regen and r.regen > 0 then
            r.actual = min( r.max, r.actual + ( v * r.regen ) )
        end

        table.wipe( r.times )
        table.wipe( r.values )
    end
end ]]


function state.putTrinketsOnCD( val )
    val = val or 10

    for k, _ in pairs( class.items ) do
        setCooldown( k, max( val, state.cooldown[ k ].remains ) )
    end
end


function state.reset( dispID )
    
    state.now = GetTime()
    state.offset = 0
    state.delay = 0
    state.cast_start = 0
    state.false_start = 0
    
    local _, zone = GetInstanceInfo()
    
    state.bg = zone == 'pvp'
    state.arena = zone == 'arena'
    
    state.min_targets = 0
    state.max_targets = 0
    
    state.active_enemies = nil
    state.my_enemies = nil
    state.true_active_enemies = nil
    state.true_my_enemies = nil
    
    state.latency = select( 4, GetNetStats() ) / 1000
    
    local spells_in_flight = ns.spells_in_flight
    
    for i = #spells_in_flight, 1, -1 do
        if spells_in_flight[i].time < state.now then
            table.remove( spells_in_flight, i )
        else
            break
        end
    end
    
    local display = dispID and Hekili.DB.profile.displays[ dispID ]
    
    if display then
        local mode = Hekili.DB.profile['Mode Status'] or 0
        
        -- 0 = single
        -- 2 = cleave
        -- 2 = aoe
        -- 3 = auto
        if display.displayType == 'a' then -- Primary
            if mode == 0 then
                state.min_targets = 0
                state.max_targets = 1
            elseif mode == 2 then
                state.min_targets = display.simpleAOE or 2
                state.max_targets = 0
            end
            
        elseif display.displayType == 'b' then -- Single-Target
            state.min_targets = 0
            state.max_targets = 1
            
        elseif display.displayType == 'c' then -- AOE
            state.min_targets = ( display.simpleAOE or 2 )
            state.max_targets = 0
            
        elseif display.displayType == 'd' then -- Auto
            -- do nothing
            
        elseif display.displayType == 'z' then -- Custom, old style.
            if mode == 0 then
                if display.minST > 0 then state.min_targets = display.minST end
                if display.maxST > 0 then state.max_targets = display.maxST end
            elseif mode == 2 then
                if display.minAE > 0 then state.min_targets = display.minAE end
                if display.maxAE > 0 then state.max_targets = display.maxAE end
            elseif mode == 3 then
                if display.minAuto > 0 then state.min_targets = display.minAuto end
                if display.maxAuto > 0 then state.max_targets = display.maxAuto end
            end
        end
        
        state.rangefilter = display.rangeType == 'xclude'
    else
        state.rangefilter = false
    end
    
    for i = #state.purge, 1, -1 do
        state[ state.purge[ i ] ] = nil
        table.remove( state.purge, i )
    end
    
    for k in pairs( state.args ) do
        state.args[ k ] = nil
    end
    
    for k in pairs( state.variable ) do
        state.variable[ k ] = nil
    end
    
    for k in pairs( state.active_dot ) do
        state.active_dot[ k ] = nil
    end
    
    for k in pairs( state.stat ) do
        state.stat[ k ] = nil
    end
    
    if state.target.updated then
        scrapeUnitAuras( 'target' )
        state.target.updated = false
    end
    
    if state.player.updated then
        scrapeUnitAuras( 'player' )
        state.player.updated = false
    end
    
    
    for k, v in pairs( state.buff ) do
        for attr in pairs( default_buff_values ) do
            v[ attr ] = nil
        end
    end
    
    for k, v in pairs( state.cooldown ) do
        v.duration = nil
        v.expires = nil
        v.charge = nil
        v.next_charge = nil
        v.recharge_began = nil
        v.recharge_duration = nil
        v.true_expires = nil
        v.true_remains = nil
    end
    
    state.trinket.t1.cooldown.duration = nil
    state.trinket.t1.cooldown.expires = nil
    state.trinket.t2.cooldown.duration = nil
    state.trinket.t2.cooldown.expires = nil
    
    for k, v in pairs( state.debuff ) do
        for attr in pairs( default_debuff_values ) do
            v[ attr ] = nil            
        end
    end
    
    state.pet.exists = nil
    for k, v in pairs( state.pet ) do
        if type(v) == 'table' and k ~= 'fake_pet' then v.expires = nil end
    end
    -- rawset( state.pet, 'exists', UnitExists( 'pet' ) )
    
    for k in pairs( state.stance ) do
        state.stance[ k ] = nil
    end
    
    for k in pairs( state.totem ) do
        state.totem[ k ].expires = nil
    end

    for k, v in pairs( state.pet ) do
        if type(v) == 'table' then
            state.pet[ k ].expires = 0
        end
    end
    
    state.target.health.actual = nil
    state.target.health.current = nil
    state.target.health.max = nil
    
    state.tanking = state.role.tank and ( UnitExists( 'targettarget' ) and UnitGUID( 'targettarget' ) == state.GUID and not UnitIsFriend( 'player', 'target' ) )
    
    -- range checks
    state.target.minR = nil
    state.target.maxR = nil
    state.target.distance = nil
    
    state.prev.last = state.player.lastcast
    state.prev_gcd.last = state.player.lastgcd
    state.prev_off_gcd.last = state.player.lastoffgcd
    
    for i = 1, 5 do
        state.predictions[i] = nil
        state.predictionsOn[i] = nil
        state.predictionsOff[i] = nil
    end
    
    -- interrupts
    state.target.casting = nil
    state.target.cast_end = nil
    
    for k, power in pairs( class.resources ) do

        local res = state[ k ]
        
        res.actual = UnitPower( 'player', ns.getResourceID( k ) )
        res.max = UnitPowerMax( 'player', ns.getResourceID( k ) )
        res.last_tick = rawget( res, 'last_tick' ) or 0
        res.tick_rate = rawget( res, 'tick_rate' ) or 0.1

        if power == SPELL_POWER_MANA then 
            local inactive, active = GetManaRegen()

            res.active_regen = active or 0
            res.inactive_regen = inactive or 0

        elseif power == UnitPowerType( 'player' ) then
            local inactive, active = GetPowerRegen()

            res.active_regen = active or 0
            res.inactive_regen = inactive or 0

        else
            res.active_regen = res.active_regen or 0
            res.inactive_regen = res.inactive_regen or 0

        end

        if res.reset then res.reset() end

    end

    forecastResources()
   
    state.health = rawget( state, 'health' ) or setmetatable( { resource = 'health' }, mt_resource )
    state.health.actual = UnitHealth( 'player' )
    state.health.max = UnitHealthMax( 'player' )
    state.health.regen = 0

    state.mainhand_speed = state.swings.mh_speed
    state.offhand_speed = state.swings.oh_speed
    
    state.nextMH = state.swings.mh_projected
    state.nextOH = state.swings.oh_projected
    
    -- Special case spells that suck.
    if class.abilities[ 'ascendance' ] and state.buff.ascendance.up then
        setCooldown( 'ascendance', state.buff.ascendance.remains + 165 )
    end
    
    local cast_time, casting = 0, nil

    local spellcast, _, _, _, startCast, endCast = UnitCastingInfo('player')
    if endCast ~= nil then
        state.cast_start = startCast / 1000
        cast_time = ( endCast / 1000 ) - GetTime()
        casting = formatKey( spellcast )
    end

    state.stopChanneling( true )

    local spellcast, _, _, _, startCast, endCast = UnitChannelInfo('player')
    if endCast ~= nil then
        state.cast_start = startCast / 1000
        cast_time = ( endCast / 1000 ) - GetTime()
        casting = formatKey( spellcast )

        state.channelSpell( casting, startCast / 1000, ( endCast - startCast ) / 1000 )
        applyBuff( "casting", cast_time )
    end

    ns.callHook( "reset_precast" )
    
    if cast_time and casting and not class.resetCastExclusions[ casting ] then

        local ability = class.abilities[ casting ]
        
        -- print( format( "Advancing %.2f to cast %s.", cast_time, casting ) )
        state.advance( cast_time )
        
        if ability then 
            
            if not ability.channeled then
                -- Put the action on cooldown. (It's slightly premature, but addresses CD resets like Echo of the Elements.)
                if ability.charges and ability.recharge > 0 then
                    state.spendCharges( casting, 1 )
                else
                    state.setCooldown( casting, ability.cooldown )
                end
                
                -- Perform the action.
                ns.runHandler( casting )
                
                ns.spendResources( casting )
                
            elseif ability.postchannel then
                ability.postchannel()
                
            end
        end
        
    end

    for _, aura in pairs( class.incapacitates ) do
        if state.buff[ aura ].up then
            -- print( format( "Advancing %.2f due to incapacitate from %s.", state.buff[ aura ].remains, aura ) )
            state.advance( state.buff[ aura ].remains )
        end
    end
    
    -- Delay to end of GCD.
    local delay = state.cooldown.global_cooldown.remains
    
    delay = ns.callHook( "reset_postcast", delay )
    
    if delay > 0 then
        state.advance( delay )
    end
    
end


function state.advance( time )
    
    -- print( format( "Advance %.2f at %.2f + %.2f.", time, state.now, state.offset ) )

    if time <= 0 then
        return
    end
    
    time = ns.callHook( 'advance', time ) or time
    -- time = roundUp( time, 3 )
    
    state.delay = 0
    
    if state.player.queued_ability then
        local saved_offset = state.offset
        local lands = max( state.now + 0.01, state.player.queued_lands )
        
        if lands > state.query_time and lands <= state.query_time + time then
            state.offset = lands - state.query_time
            ns.runHandler( state.player.queued_ability, true )
        end
        
        state.offset = saved_offset
    end
    
    local projected = ns.spells_in_flight
    
    if projected and #projected > 0 then
        local saved_offset = state.offset
        
        for i = #projected, 1, -1 do
            local proj = projected[i]
            
            if proj.time > state.query_time and proj.time <= state.query_time + time then
                state.offset = proj.time - state.query_time
                ns.runHandler( proj.spell, true )
            else
                break
            end
        end
        
        state.offset = saved_offset
    end

    if not class.regenModel then
        for k in pairs( class.resources ) do
            local resource = state[ k ]

            local override = ns.callHook( 'advance_resource_regen', false, k, time )

            if not override and resource.regen and resource.regen ~= 0 then
                resource.actual = min( resource.max, max( 0, resource.actual + ( resource.regen * time ) ) )
            end
        end
    end

    -- forecastResources()

    state.offset = state.offset + time

    local bonus_cdr = 0 -- ns.callHook( 'advance_bonus_cdr', 0 )
    
    for k, cd in pairs( state.cooldown ) do
        if ns.isKnown( k ) then
            if bonus_cdr > 0 then
                if cd.next_charge > 0 then
                    cd.next_charge = cd.next_charge - bonus_cdr
                end
                cd.expires = max( 0, cd.expires - bonus_cdr )
                cd.true_expires = max( 0, cd.expires - bonus_cdr )
            end
            
            while class.abilities[ k ].charges and cd.next_charge > 0 and cd.next_charge < state.now + state.offset do 
                -- if class.abilities[ k ].charges and cd.next_charge > 0 and cd.next_charge < state.now + state.offset then
                cd.charge = cd.charge + 1
                if cd.charge < class.abilities[ k ].charges then
                    cd.recharge_began = cd.next_charge
                    cd.next_charge = cd.next_charge + class.abilities[ k ].recharge
                else 
                    cd.next_charge = 0
                end
            end
        end
    end
    
    ns.callHook( 'advance_end', time )
    
end


ns.resourceType = function( ability )
    
    local action = class.abilities[ ability ]
    
    if not action then return end
    
    if action.spend ~= nil then
        if type( action.spend ) == 'number' then
            return action.spend_type or class.primaryResource
            
        elseif type( action.spend ) == 'function' then
            return select( 2, action.spend() )
            
        end
    end
    
    return nil
    
end


ns.spendResources = function( ability )
    
    local action = class.abilities[ ability ]
    
    if not action then return end
    
    -- First, spend resources.
    if action.spend ~= nil then
        local cost, resource
        
        if type( action.spend ) == 'number' then
            cost = action.spend
            resource = action.spend_type or class.primaryResource
        elseif type( action.spend ) == 'function' then
            cost, resource = action.spend()
        end
        
        if cost > 0 and cost < 1 then
            cost = ( cost * state[ resource ].max )
        end

        if cost ~= 0 then
            state.spend( cost, resource )            
        end
    end

end


ns.isKnown = function( sID, notoggle )
    
    if type(sID) ~= 'number' then sID = class.abilities[ sID ] and class.abilities[ sID ].id or nil end

    if not sID then
        return false -- no ability

    elseif sID < 0 then
        return true

    end

    local ability = class.abilities[ sID ]
    
    if not ability then
        ns.Error( "isKnown() - " .. sID .. " not found in abilities table." )
        return false
    end

    local profile = Hekili.DB.profile

    if ability.spec and not state.spec[ ability.spec ] then
        return false
    end

    if ability.nospec and state.spec[ ability.nospec ] then
        return false
    end

    --[[ if not notoggle then
        local pToggle = Hekili.DB.profile.toggles[ ability.key ]

        if ( not pToggle or pToggle == 'default' ) and ( ability.toggle and not state.toggle[ ability.toggle ]  ) then return false
        elseif ( pToggle and pToggle ~= 'none' ) and not state.toggle[ pToggle ] then return false end
    end ]]

    if ability.talent and not state.talent[ ability.talent ].enabled then
        return false
    end

    if ability.notalent and state.talent[ ability.notalent ].enabled then
        return false
    end

    if ability.trait and not state.artifact[ ability.trait ].enabled then
        return false
    end

    if ability.equipped and not state.equipped[ ability.equipped ] then
        return false
    end

    if ability.item and not state.equipped[ ability.item ] then
        return false
    end

    if ability.buff and not state.buff[ ability.buff ].up then
        return false
    end

    if ability.nobuff and state.buff[ ability.nobuff ].up then
        return false
    end

    if ability.known ~= nil then
        if type( ability.known ) == 'number' then
            return IsPlayerSpell( ability.known )
        end
        return ability.known()
    end

    return ( ability.item and true ) or IsPlayerSpell( sID ) or IsSpellKnown( sID ) or IsSpellKnown( sID, true )
    
end


-- Filter out non-resource driven issues with abilities.
-- Unusable abilities are treated as on CD unless overridden.
ns.isUsable = function( spell )

    local ability = class.abilities[ spell ]    
    if not ability then return true end

    local profile = Hekili.DB.profile

    if ability.item and not state.equipped[ ability.item ] then
        return false
    end

    if state.rangefilter and UnitExists( 'target' ) and LibStub( "SpellRange-1.0" ).IsSpellInRange( ability.id, 'target' ) == 0 then
        return false
    end

    if ability.form and not state.buff[ ability.form ].up then
        return false
    end

    if profile.blacklist and profile.blacklist[ ability.key ] then
        return false
    end

    local toggle = profile.toggles[ ability.key ]

    if not toggle or toggle == 'default' then toggle = ability.toggle end

    if toggle and not state.toggle[ toggle ] then
        return false
    end
    
    if ability.usable ~= nil then
        if type( ability.usable ) == 'number' then 
            return IsUsableSpell( ability.usable )
        elseif type( ability.usable ) == 'function' then
            return ability.usable()
        end
    end
    
    return true
    
end


ns.hasRequiredResources = function( ability )
    
    local action = class.abilities[ ability ]
    
    if not action then return end
    
    -- First, spend resources.
    if action.spend and action.spend ~= 0 then
        local spend, resource
        
        if type( action.spend ) == 'number' then
            spend = action.spend
            resource = action.spend_type or class.primaryResource
        elseif type( action.spend ) == 'function' then
            spend, resource = action.spend()
        end
        
        if resource == 'focus' or resource == 'energy' then
            -- Thought: We'll already delay CD based on time to get energy/focus.
            -- So let's leave it alone.
            return true
            
        elseif resource == 'holy_power' and state.equipped.liadrins_fury_unleashed and ( state.buff.crusade.up or state.buff.avenging_wrath.up ) then
            -- Holy Power is a time-regen resource during AW/Crusade, if you have the legendary ring.
            return true
        end
        
        if spend > 0 and spend < 1 then
            spend = ( spend * state[ resource ].max )
        end
        
        if spend > 0 then
            return ( state[ resource ].current >= spend )
        end
    end
    
    return true
    
end


local power_tick_rate = 0.115


local cacheTTR = {}
local TTRtime = 0


-- Needs to be expanded to handle energy regen before Rogue, Monk, Druid will work.
function ns.timeToReady( action, pool )

    local now = state.now + state.offset
    
    -- Need to ignore the wait for this part.
    local wait = state.cooldown[ action ].remains
    local ability = class.abilities[ action ]

    if ability.gcdType ~= 'off' then
        wait = max( wait, state.cooldown.global_cooldown.remains )
    end
    
    wait = ns.callHook( "timeToReady", wait, action )
    
    local spend, resource
    
    if ability.spend then
        if type( ability.spend ) == 'number' then
            spend = ability.spend
            resource = ability.spend_type or class.primaryResource
        elseif type( ability.spend ) == 'function' then
            spend, resource = ability.spend()
        end
        
        spend = ns.callHook( 'timeToReady_spend', spend )
    end

    -- For special cases where we want to pool more of a resource than is required for usage.
    if not pool and ability.ready and type( ability.ready ) == 'number' then
        spend = ability.ready
    end

    if spend and resource and spend > 0 and spend < 0 then
        spend = spend * state[ resource ].max
    end

    -- Okay, so we don't have enough of the resource.
    if resource and spend > state[ resource ].current then
        wait = max( wait, state[ resource ][ 'time_to_' .. spend ] or 0 )
        wait = ceil( wait * 100 ) / 100 -- round to the hundredth.
    end
    
    -- If ready is a function, it returns time.
    -- Ignore this if we are just checking pool_resources.
    if not pool then
        if  ability.ready and type( ability.ready ) == 'function' then
            wait = max( wait, ability.ready() )
        end

        if state.script.entry then
            wait = ns.checkTimeScript( state.script.entry, wait, spend, resource ) or wait
        end
    end

    -- cacheTTR[ action ] = wait
    return wait   
end


ns.isReady = function( action )
    
    local ability = class.abilities[ action ]
    
    if ability.spend then
        local spend, resource
        
        if type( ability.spend ) == 'number' then
            spend = ability.spend
            resource = ability.spend_type or class.primaryResource
        elseif type( ability.spend ) == 'function' then
            spend, resource = ability.spend()
        end
        
        if resource == 'focus' or resource == 'energy' or state.script.entry then
            return ns.timeToReady( action ) <= state.delay
        end
        
    end
    
    return ns.hasRequiredResources( action ) and state.cooldown[ action ].remains <= state.delay
end


function ns.isReadyNow( action )
    
    local a = class.abilities[ action ]
    local clash = Hekili.DB.profile.clashes[ action ] or 0

    if not a then return false end

    if state.cooldown[ action ].remains - clash > 0 then return false end

    local wait = ns.callHook( "timeToReady", 0, action )

    if wait and wait > 0 then return false end

    if a.ready and type( a.ready ) == 'function' and a.ready() > 0 then return false end

    if a.spend and a.spend ~= 0 then
        local spend, resource

        if type( a.spend ) == 'number' then
            spend = a.spend
            resource = a.spend_type or class.primaryResource

        elseif type( a.spend ) == 'function' then
            spend, resource = a.spend()

        end

        if a.ready and type( a.ready ) == 'number' then
            spend = a.ready
        end

        if spend > 0 and spend < 1 then
            spend = ( spend * state[ resource ].max )
        end

        if spend > 0 then
            return state[ resource ].current >= spend 
        end
    end

    return true
end



ns.clashOffset = function( action )
    
    local clash = Hekili.DB.profile.clashes[ action ] or Hekili.DB.profile.Clash
    return ns.callHook( "clash", clash, action )
    
end


for k, v in pairs( state ) do
    ns.commitKey( k )
end

ns.attr = { "serenity", "active", "active_enemies", "my_enemies", "active_flame_shock", "adds", "agility", "air", "armor", "attack_power", "bonus_armor", "cast_delay", "cast_time", "casting", "cooldown_react", "cooldown_remains", "cooldown_up", "crit_rating", "deficit", "distance", "down", "duration", "earth", "enabled", "energy", "execute_time", "fire", "five", "focus", "four", "gcd", "hardcasts", "haste", "haste_rating", "health", "health_max", "health_pct", "intellect", "level", "mana", "mastery_rating", "mastery_value", "max_nonproc", "max_stack", "maximum_energy", "maximum_focus", "maximum_health", "maximum_mana", "maximum_rage", "maximum_runic", "melee_haste", "miss_react", "moving", "mp5", "multistrike_pct", "multistrike_rating", "one", "pct", "rage", "react", "regen", "remains", "remains", "resilience_rating", "runic", "seal", "spell_haste", "spell_power", "spirit", "stack", "stack_pct", "stacks", "stamina", "strength", "this_action", "three", "tick_damage", "tick_dmg", "tick_time", "ticking", "ticks", "ticks_remain", "time", "time_to_die", "time_to_max", "travel_time", "two", "up", "water", "weapon_dps", "weapon_offhand_dps", "weapon_offhand_speed", "weapon_speed", "single", "aoe", "cleave", "percent", "last_judgment_target", "unit", "ready" }
