-- cw/gear.lua - your stats with the gear you have on NOW, not the gear you had
-- on at the last stat refresh. Exports itemStats, wornStats, markRefresh and
-- liveStat; publishes tm.statBasis.
--
-- The client only learns your stats from a 0x061, and no 0x061 follows an
-- equip, so IPlayer's GetStat + GetStatModifier is the total for whatever was
-- worn when the last one arrived. The equipment slots, on the other hand, are
-- current the moment a swap lands. So the gear worn at each 0x061 is recorded
-- (its stats summed off the item descriptions), and a read takes that gear's
-- share back out of the stale total and puts the worn gear's share in:
--
--   stat now = (GetStat + GetStatModifier) - gear at refresh + gear worn now
--
-- Everything that is not plain gear text - food, buffs, merits, set bonuses,
-- latents - stays inside the stale total and carries over untouched, which is
-- right as long as it has not changed since the refresh. Only the plain stat
-- lines of an item are counted: a latent, a set bonus or an automaton line
-- is conditional, and is left to the stale total.
local D  = require('cw.data')
local PLAYER_STAT_INDEX = D.PLAYER_STAT_INDEX
local tm = require('cw.state')
local U  = require('cw.util')
local safe, player, equippedItemId = U.safe, U.player, U.equippedItemId

local STATS = { 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR' }
local SLOT_COUNT = 16   -- 0 main .. 15 back
-- Labels that are part of an item's plain text rather than a condition on
-- what follows them.
local PLAIN_LABEL = { DEF = true, DMG = true, Delay = true }

-- Where the unconditional part of a description ends: the first `Label:` that
-- is not a plain one - Latent effect:, Set:, Automaton:, Pet:, Avatar:,
-- Wyvern:, Enchantment:, Nighttime:, and so on.
local function plainPart(text)
    local pos = 1
    while true do
        local s, e, label = text:find("(%a[%a '%-]*):", pos)
        if s == nil then return text end
        if not PLAIN_LABEL[label] then return text:sub(1, s - 1) end
        pos = e + 1
    end
end

-- STR+3, INT-2, All attributes +1. Pure string work, so it is tested directly.
local function parseStats(text)
    local out = {}
    if type(text) ~= 'string' or text == '' then return out end
    local plain = plainPart(text)
    local all = tonumber(plain:match('[Aa]ll attributes%s*([+-]%d+)') or '') or 0
    for _, s in ipairs(STATS) do
        local n = all
        -- %f[%u] stops "VIT" matching inside a longer capitalised word
        for v in plain:gmatch('%f[%u]' .. s .. '%s*([+-]%d+)') do n = n + tonumber(v) end
        if n ~= 0 then out[s] = n end
    end
    return out
end

-- Parsed once per item id: the description never changes, and a read on
-- every maneuver and every frame need not walk the text again.
local cache = {}
local function itemStats(id)
    if id == nil or id == 0 then return {} end
    local hit = cache[id]
    if hit ~= nil then return hit end
    local text = safe(function()
        local item = AshitaCore:GetResourceManager():GetItemById(id)
        return item ~= nil and item.Description ~= nil and item.Description[1] or nil
    end, nil)
    local parsed = parseStats(text)
    cache[id] = parsed
    return parsed
end

-- The plain stats of everything worn, summed.
local function wornStats()
    local sum = {}
    for slot = 0, SLOT_COUNT - 1 do
        for s, n in pairs(itemStats(equippedItemId(slot))) do sum[s] = (sum[s] or 0) + n end
    end
    return sum
end

-- The gear the stale total was taken with. nil until the first refresh this
-- addon has seen (or the load-time guess below), and then the read falls back
-- to the stale total alone, as the addon always did.
tm.statBasis = nil

-- A 0x061 just arrived: the total it carries is for the gear on right now.
-- `why` is 'refresh' for the packet, 'load' for the guess made when the addon
-- loads mid-session - that the gear on then is the gear at the last refresh,
-- which holds when you load it standing around in your idle set.
local function markRefresh(why)
    if not U.isLoggedIn() then return end
    tm.statBasis = { gear = wornStats(), why = why or 'refresh', at = os.clock() }
end

-- Your stat with what you have on now. Returns the value, and the stale total
-- it was corrected from (the same number when there is no basis to correct by).
local function liveStat(statName)
    local idx = PLAYER_STAT_INDEX[statName]
    if idx == nil then return nil end
    local stale = safe(function()
        local p = player()
        return p:GetStat(idx) + (p:GetStatModifier(idx) or 0)
    end, nil)
    if stale == nil or tm.statBasis == nil then return stale, stale end
    local was = tm.statBasis.gear[statName] or 0
    local now = wornStats()[statName] or 0
    return stale - was + now, stale
end

return { parseStats = parseStats, itemStats = itemStats, wornStats = wornStats,
         markRefresh = markRefresh, liveStat = liveStat, STATS = STATS }
