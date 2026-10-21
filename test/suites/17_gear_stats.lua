-- ------------------------------------------------- the gear you have on --
-- cw/gear.lua: memory's stat total is for the gear worn at the last 0x061,
-- and no 0x061 follows an equip. The read takes that gear's plain stat lines
-- back out and puts the worn gear's in, so a maneuver set swapped on for the
-- maneuver is seen without opening a menu.
do
    local G = require('cw.gear')

    -- the item text: plain stat lines count, conditional sections do not
    local p = G.parseStats('DEF:20 STR+3 DEX+2 INT-1')
    check('a plain line counts', p.STR, 3)
    check('...each of them', p.DEX, 2)
    check('...a minus too', p.INT, -1)
    p = G.parseStats('DEF:10 AGI+2\nLatent effect: AGI+5')
    check('a latent is left out', p.AGI, 2)
    p = G.parseStats('STR+1 Automaton: STR+5 DEX+5')
    check('an automaton line is the automaton\'s', p.STR, 1)
    check('...all of it', p.DEX, nil)
    p = G.parseStats('VIT+2 Set: VIT+10')
    check('a set bonus is left out', p.VIT, 2)
    p = G.parseStats('All attributes +2 VIT+1')
    check('all attributes adds to each', p.VIT, 3)
    check('...even with no line of its own', p.CHR, 2)
    p = G.parseStats('MND+4 "Cure" potency +5% Ranged Accuracy+5')
    check('other text is ignored', p.MND, 4)
    check('...and nothing else is read', p.AGI == nil and p.STR == nil, true)
    check('no text, no stats', next(G.parseStats(nil)), nil)

    -- the live read
    local m, cfg = api.model(), api.config
    local was, wasStats = cfg.stat_check, world.stats
    petOut(PET + 410, MOB + 410)
    api.timersClear(false)
    cfg.stat_check = {}
    world.itemDesc = { [90001] = 'DEF:5 AGI+2',               -- idle body
                       [90002] = 'DEF:12 AGI+5 DEX+3',        -- Wind body
                       [90003] = 'AGI+4' }                    -- Wind ring
    local IDLE = { [5] = 90001 }
    local WIND = { [5] = 90002, [13] = 90003 }
    world.gear = IDLE
    world.stats = { [3] = 73 }   -- AGI as memory holds it, idle on
    handlers['packet_in']({ id = 0x061, injected = false, data = '' })
    handlers['d3d_present']()
    check('a 0x061 records the gear it came with', m.statBasis == nil, false)
    m = api.model()
    check('...as a refresh', m.statBasis.why, 'refresh')
    check('...with that gear\'s AGI', m.statBasis.gear.AGI, 2)
    check('idle reads memory as it is', api.myStat('Wind'), 73)

    -- the Wind set goes on; memory still says 73
    world.gear = WIND
    check('the swap is seen with no 0x061', api.myStat('Wind'), 73 - 2 + 5 + 4)
    send044({ head = 2, frame = 33, stats = { AGI = 78 } })
    handlers['d3d_present']()
    handlers['command']({ command = '/cw reset' })
    check('...so the check is won', (api.computeCost('Wind')), 15)

    -- the maneuver resolves with the set on: that is the stat it keeps
    api.reconcile('Wind', 0, false)
    m = api.model()
    check('the last use keeps the set\'s stat', m.castStat.Wind, 80)
    world.gear = IDLE
    send044({ head = 2, frame = 33, stats = { AGI = 78 } })
    handlers['d3d_present']()
    check('back in idle, the cost is still the won one', m.cost.Wind, 15)
    check('...from your last use', m.costSource.Wind, 'cast')

    -- a 0x061 while the set is on: memory holds the set's total, and the read
    -- still answers for whatever is worn
    world.gear = WIND
    world.stats = { [3] = 80 }
    handlers['packet_in']({ id = 0x061, injected = false, data = '' })
    handlers['d3d_present']()
    check('a refresh in the set reads the set', api.myStat('Wind'), 80)
    world.gear = IDLE
    check('...and idle off it', api.myStat('Wind'), 73)

    -- a stat the gear does not touch is memory's number
    world.stats = { [3] = 80, [0] = 61 }
    check('a stat no gear moves is left alone', api.myStat('Fire'), 61)

    -- /cw stat now takes the corrected read, no menu needed
    world.gear = WIND
    handlers['command']({ command = '/cw stat wind now' })
    check('now takes the set you have on', cfg.stat_check.Wind, 80)
    handlers['command']({ command = '/cw stat wind off' })

    -- a number you typed still outranks the read
    handlers['command']({ command = '/cw stat wind 70' })
    check('a typed stat outranks the gear read', select(2, api.computeCost('Wind')), 70)
    handlers['command']({ command = '/cw stat wind off' })

    check('no native read failed', api.swallowed(), 0)
    world.gear, world.itemDesc = nil, nil
    cfg.stat_check, world.stats = was, wasStats
    handlers['command']({ command = '/cw reset' })
end
