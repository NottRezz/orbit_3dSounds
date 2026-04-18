local activeSounds = {}

-- ─── NUI Bridge ──────────────────────────────────────────────────────────────
local function NUI(type, data)
    SendNUIMessage({ type = type, d = data })
end

-- ─── Listener Tick (100ms) ───────────────────────────────────────────────────
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        NUI('updateListener', {
            x       = pos.x,
            y       = pos.y,
            z       = pos.z,
            heading = GetEntityHeading(ped)
        })
        Wait(100)
    end
end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function ResolveCoords(coords)
    if type(coords) == 'vector3' then
        return { x = coords.x, y = coords.y, z = coords.z }
    end
    return coords
end

-- ─── Core API ────────────────────────────────────────────────────────────────

---@param soundId    string   Unique identifier for this sound instance
---@param audioUrl   string   URL to audio file (nui://resource/path or https://...)
---@param coords     vector3  World position of the sound source
---@param options    table    Optional: volume, loop, maxDistance, refDistance, rolloffFactor, playbackRate, offset
function PlaySoundAtCoords(soundId, audioUrl, coords, options)
    options = options or {}
    local c = ResolveCoords(coords)
    activeSounds[soundId] = { url = audioUrl, coords = c, options = options }
    NUI('playSound', {
        id      = soundId,
        url     = audioUrl,
        x       = c.x,
        y       = c.y,
        z       = c.z,
        options = options
    })
end

---@param soundId    string   Unique identifier
---@param coords     vector3  World position
---@param options    table    Optional: oscFrequency, oscType, oscDuration, loop, volume, maxDistance
function PlayOscillatorAtCoords(soundId, coords, options)
    options = options or {}
    options.isOscillator = true
    PlaySoundAtCoords(soundId, nil, coords, options)
end

---@param soundId string
function StopSound(soundId)
    activeSounds[soundId] = nil
    NUI('stopSound', { id = soundId })
end

function StopAllSounds()
    activeSounds = {}
    NUI('stopAll', {})
end

---@param soundId string
---@param coords  vector3
function UpdateSoundPosition(soundId, coords)
    local c = ResolveCoords(coords)
    if activeSounds[soundId] then activeSounds[soundId].coords = c end
    NUI('updateSoundPosition', { id = soundId, x = c.x, y = c.y, z = c.z })
end

---@param soundId string
---@param volume  number  0.0 - 1.0+
function UpdateSoundVolume(soundId, volume)
    NUI('updateSoundVolume', { id = soundId, volume = volume })
end

---@param soundId string
---@param loop    boolean
function SetSoundLoop(soundId, loop)
    NUI('setSoundLoop', { id = soundId, loop = loop })
end

-- ─── Exports ─────────────────────────────────────────────────────────────────
exports('PlaySoundAtCoords',    PlaySoundAtCoords)
exports('PlayOscillatorAtCoords', PlayOscillatorAtCoords)
exports('StopSound',            StopSound)
exports('StopAllSounds',        StopAllSounds)
exports('UpdateSoundPosition',  UpdateSoundPosition)
exports('UpdateSoundVolume',    UpdateSoundVolume)
exports('SetSoundLoop',         SetSoundLoop)

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Server → Client: play a sound at coords (locally for this player)
RegisterNetEvent('orbit_sounds:playLocal', function(soundId, audioUrl, coords, options)
    PlaySoundAtCoords(soundId, audioUrl, coords, options)
end)

-- Server → Client: play oscillator at coords
RegisterNetEvent('orbit_sounds:playOscillatorLocal', function(soundId, coords, options)
    PlayOscillatorAtCoords(soundId, coords, options)
end)

-- Server → Client: stop a sound
RegisterNetEvent('orbit_sounds:stopSound', function(soundId)
    StopSound(soundId)
end)

-- Server → Client: stop all sounds
RegisterNetEvent('orbit_sounds:stopAll', function()
    StopAllSounds()
end)

-- Server → Client: update a sound's live position (moving sources)
RegisterNetEvent('orbit_sounds:updatePosition', function(soundId, coords)
    UpdateSoundPosition(soundId, coords)
end)

-- ─── Test Command ─────────────────────────────────────────────────────────────
-- /soundtest            → oscillator beep (no file needed)
-- /soundtest <url>      → play audio file at test coords
RegisterCommand('soundtest', function(source, args)
    local testCoords = vector3(-104.82, -984.57, 114.14)
    local soundId    = 'orbit_soundtest'

    StopSound(soundId) -- stop any previous test

    if args[1] then
        -- File-based test
        PlaySoundAtCoords(soundId, args[1], testCoords, {
            volume      = 1.0,
            loop        = false,
            maxDistance = 250,
            refDistance = 10,
        })
        print(('[orbit_sounds] Playing file test: %s'):format(args[1]))
    else
        -- Oscillator test (440 Hz, 3 s) — no audio file required
        PlayOscillatorAtCoords(soundId, testCoords, {
            oscFrequency = 440,
            oscType      = 'sine',
            oscDuration  = 3.0,
            volume       = 1.0,
            maxDistance  = 250,
            refDistance  = 10,
        })
        print('[orbit_sounds] Playing oscillator test (440 Hz, 3s)')
    end

    -- Notify
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('~b~[Orbit Sounds]~w~ Test sound at ~y~(-104.82, -984.57, 114.14)~w~. Walk towards it!')
    EndTextCommandThefeedPostTicker(false, false)
end, false)

print('[orbit_sounds] Client ready.')
