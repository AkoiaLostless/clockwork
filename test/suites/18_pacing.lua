-- ------------------------------------------------------ the model's pace --
-- cw/frame.lua runs the model every tm.modelEvery seconds, or on the next
-- frame after a packet or command marks it dirty; the frames between draw
-- its last answer. The other suites run it every frame (fixtures/load.lua),
-- so this one sets the pace back to the addon's own and puts it back after.
do
    local tm = require('cw.state')
    api.resetSwallowed()
    petOut(PET + 520, MOB + 520)
    tm.modelEvery = 0.1
    world.icons, world.timers = { 300 }, { 0 }
    advance(1) handlers['d3d_present']()
    check('pace: the model ran', tm.predManeuvers, 'Fi1')

    world.icons, world.timers = { 300, 301 }, { 0, 0 }
    advance(0.05) handlers['d3d_present']()
    check('pace: a frame inside the interval keeps the last answer', tm.predManeuvers, 'Fi1')
    advance(0.06) handlers['d3d_present']()
    check('pace: the interval up, it runs again', tm.predManeuvers, 'Fi1/Ic1')

    -- a packet we read marks it dirty: the next frame runs, clock or no clock
    world.icons, world.timers = { 300, 301, 302 }, { 0, 0, 0 }
    handlers['d3d_present']()
    check('pace: no packet, no clock, no run', tm.predManeuvers, 'Fi1/Ic1')
    handlers['packet_in']({ id = 0x061, injected = false, data = ('\0'):rep(0x60) })
    handlers['d3d_present']()
    check('pace: a stats packet runs it on the next frame', tm.predManeuvers, 'Fi1/Ic1/Wi1')

    -- ...and so does a command
    world.icons, world.timers = { 300 }, { 0 }
    handlers['d3d_present']()
    check('pace: still waiting', tm.predManeuvers, 'Fi1/Ic1/Wi1')
    handlers['command']({ command = '/notours' })
    handlers['d3d_present']()
    check('pace: a command runs it on the next frame', tm.predManeuvers, 'Fi1')

    -- an injected packet, or one we do not read, does not
    world.icons, world.timers = { 301 }, { 0 }
    handlers['packet_in']({ id = 0x061, injected = true, data = ('\0'):rep(0x60) })
    handlers['packet_in']({ id = 0x00D, injected = false, data = ('\0'):rep(0x60) })
    handlers['d3d_present']()
    check('pace: injected or unread packets wait for the clock', tm.predManeuvers, 'Fi1')
    advance(0.1) handlers['d3d_present']()
    check('pace: ...which comes round', tm.predManeuvers, 'Ic1')

    -- the maneuvers are read once a frame and shared inside it; outside a
    -- frame every ask reads afresh
    check('pace: not inside a frame between frames', tm.inFrame, false)
    world.icons, world.timers = { 302, 302 }, { 0, 0 }
    check('pace: a read outside a frame is live', #api.activeManeuvers(), 2)
    local frameBefore = tm.frameId
    handlers['d3d_present']()
    check('pace: every present numbers a frame', tm.frameId, frameBefore + 1)

    tm.modelEvery = 0
    world.icons, world.timers = nil, nil
    advance(1) handlers['d3d_present']()

    -- the target's slot: a mob id carries its entity index in the low bits,
    -- and that slot is the one found
    local was = { world.mobIndex, world.mobId }
    world.mobIndex, world.mobId = 0x123, 0x01021123
    tm.petTarget, tm.mobIndex, tm.mobIndexFor, tm.mobScanAt = 0x01021123, nil, nil, nil
    check('slot: found from the id itself', tm.mobSlot(), 0x123)
    -- an id whose low bits do not name its slot is still found by the walk
    world.mobIndex, world.mobId = 0x045, 0x01021999
    tm.petTarget, tm.mobIndex, tm.mobIndexFor, tm.mobScanAt = 0x01021999, nil, nil, nil
    check('slot: the walk is the fallback', tm.mobSlot(), 0x045)
    world.mobIndex, world.mobId = was[1], was[2]
    tm.petTarget, tm.mobIndex, tm.mobIndexFor, tm.mobScanAt = 0, nil, nil, nil
    check('pace: no native read failed', api.swallowed(), 0)
end
