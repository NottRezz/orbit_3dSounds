-- ─── Config ───────────────────────────────────────────────────────────────────
local Config = {
    listenerTickMs    = 50,   -- camera sync interval (ms) — keep at 50 for smooth HRTF
    occlusionTickMs   = 180,  -- raycast cycle interval (ms)
    occlusionEnabled  = true,
    occlusionMinGain  = 0.10, -- volume when fully behind a wall
    occlusionSmooth   = 0.25, -- lerp factor toward target per cycle (0.0–1.0)
    occlusionFlags    = 1 + 16 + 256, -- static world + buildings + vegetation
}

-- ─── State ────────────────────────────────────────────────────────────────────
local activeSounds   = {} -- [soundId] = { url, coords, options, occlusionGain }

-- ─── NUI Bridge ───────────────────────────────────────────────────────────────
local function NUI(type, data)
    SendNUIMessage({ type = type, d = data })
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function ResolveCoords(coords)
    if type(coords) == 'vector3' then
        return { x = coords.x, y = coords.y, z = coords.z }
    end
    return coords
end

-- ─── Listener Tick ────────────────────────────────────────────────────────────
-- Uses camera position + rotation, not ped heading.
-- Camera position gives correct listener location in both 1st and 3rd person.
-- Pitch drives vertical HRTF (sound above/below) for full 3D immersion.
CreateThread(function()
    while true do
        local camPos = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2) -- (pitch, roll, yaw)
        NUI('updateListener', {
            x     = camPos.x,
            y     = camPos.y,
            z     = camPos.z,
            pitch = camRot.x,  -- negative = looking up
            yaw   = -camRot.z, -- negate: camRot.z is CCW, listener expects CW
        })
        Wait(Config.listenerTickMs)
    end
end)

-- ─── Occlusion Tick ───────────────────────────────────────────────────────────
-- Fires raycasts from camera to each active sound source.
-- Sends a per-sound gain (0.10–1.0) to NUI which applies it to a separate
-- occlusionGain node, independent of user-set volume.
if Config.occlusionEnabled then
    CreateThread(function()
        local ped = PlayerPedId()
        while true do
            Wait(Config.occlusionTickMs)
            ped = PlayerPedId()

            local origin = GetEntityCoords(ped)
            local handles = {}

            -- Fire all raycasts in one pass (async batch)
            for soundId, sound in pairs(activeSounds) do
                if not sound.is2D and not sound.options.noOcclusion then
                    local c = sound.coords
                    handles[soundId] = StartShapeTestRay(
                        origin.x, origin.y, origin.z,
                        c.x, c.y, c.z,
                        Config.occlusionFlags, ped, 0
                    )
                end
            end

            Wait(0) -- yield one frame for raycasts to settle

            for soundId, handle in pairs(handles) do
                local sound = activeSounds[soundId]
                if sound then
                    local _, hit = GetShapeTestResult(handle)
                    local target = (hit == 1) and Config.occlusionMinGain or 1.0
                    local current = sound.occlusionGain or 1.0
                    -- Smooth lerp toward target
                    local next = current + (target - current) * Config.occlusionSmooth
                    sound.occlusionGain = next
                    NUI('updateOcclusion', { id = soundId, gain = next })
                end
            end
        end
    end)
end

-- ─── Core API ─────────────────────────────────────────────────────────────────

---Play an audio file at a world position.
---@param soundId  string   Unique ID — reusing an ID stops the previous instance
---@param audioUrl string?  URL: `nui://orbit_sounds/ui/sounds/file.ogg` or https://... (nil for oscillators)
---@param coords   vector3
---@param options  table    See README for full options list
function PlaySoundAtCoords(soundId, audioUrl, coords, options)
    options = options or {}
    local c = ResolveCoords(coords)
    activeSounds[soundId] = {
        url          = audioUrl,
        coords       = c,
        options      = options,
        occlusionGain = 1.0,
    }
    NUI('playSound', {
        id      = soundId,
        url     = audioUrl,
        x       = c.x,
        y       = c.y,
        z       = c.z,
        options = options,
    })
end

---Play a synthesized tone at a world position — no audio file required.
---@param soundId string
---@param coords  vector3
---@param options table  oscFrequency, oscType, oscDuration, loop, reverb, volume, ...
function PlayOscillatorAtCoords(soundId, coords, options)
    options = options or {}
    options.isOscillator = true
    PlaySoundAtCoords(soundId, nil, coords, options)
end

---Play a non-spatialized sound with no world position (UI sounds, ability cues, etc.).
---@param soundId  string
---@param audioUrl string?  nil for oscillator
---@param options  table    volume, loop, fadeIn, playbackRate, offset, isOscillator, oscFrequency, oscType, oscDuration
function PlaySound2D(soundId, audioUrl, options)
    options = options or {}
    activeSounds[soundId] = { options = options, is2D = true }
    NUI('play2D', { id = soundId, url = audioUrl, options = options })
end

---Stop a sound immediately.
---@param soundId string
function StopSound(soundId)
    activeSounds[soundId] = nil
    NUI('stopSound', { id = soundId })
end

---Fade a sound out then stop it.
---@param soundId  string
---@param duration number  Seconds (default 0.4)
function StopSoundFade(soundId, duration)
    activeSounds[soundId] = nil
    NUI('stopSoundFade', { id = soundId, duration = duration or 0.4 })
end

---Stop every active sound immediately.
function StopAllSounds()
    activeSounds = {}
    NUI('stopAll', {})
end

---Move a live sound source to new world coords (use in a tick for moving entities).
---@param soundId string
---@param coords  vector3
function UpdateSoundPosition(soundId, coords)
    local c = ResolveCoords(coords)
    if activeSounds[soundId] then activeSounds[soundId].coords = c end
    NUI('updateSoundPosition', { id = soundId, x = c.x, y = c.y, z = c.z })
end

---Change the master volume of a playing sound (0.0–1.0+).
---@param soundId string
---@param volume  number
function UpdateSoundVolume(soundId, volume)
    NUI('updateSoundVolume', { id = soundId, volume = volume })
end

---Toggle looping on a playing sound.
---@param soundId string
---@param loop    boolean
function SetSoundLoop(soundId, loop)
    NUI('setSoundLoop', { id = soundId, loop = loop })
end

-- ─── Exports ──────────────────────────────────────────────────────────────────
exports('PlaySound2D',            PlaySound2D)
exports('PlaySoundAtCoords',      PlaySoundAtCoords)
exports('PlayOscillatorAtCoords', PlayOscillatorAtCoords)
exports('StopSound',              StopSound)
exports('StopSoundFade',          StopSoundFade)
exports('StopAllSounds',          StopAllSounds)
exports('UpdateSoundPosition',    UpdateSoundPosition)
exports('UpdateSoundVolume',      UpdateSoundVolume)
exports('SetSoundLoop',           SetSoundLoop)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────
-- NUI fires this when a non-looping sound ends naturally
RegisterNUICallback('soundEnded', function(data, cb)
    activeSounds[data.id] = nil
    cb({})
end)

-- ─── Net Events ───────────────────────────────────────────────────────────────
RegisterNetEvent('orbit_sounds:play2D',              function(id, url, opts)         PlaySound2D(id, url, opts) end)
RegisterNetEvent('orbit_sounds:playLocal',           function(id, url, coords, opts) PlaySoundAtCoords(id, url, coords, opts) end)
RegisterNetEvent('orbit_sounds:playOscillatorLocal', function(id, coords, opts)       PlayOscillatorAtCoords(id, coords, opts) end)
RegisterNetEvent('orbit_sounds:stopSound',           function(id)                     StopSound(id) end)
RegisterNetEvent('orbit_sounds:stopSoundFade',       function(id, dur)                StopSoundFade(id, dur) end)
RegisterNetEvent('orbit_sounds:stopAll',             function()                       StopAllSounds() end)
RegisterNetEvent('orbit_sounds:updatePosition',      function(id, coords)             UpdateSoundPosition(id, coords) end)

-- ─── Test Command ─────────────────────────────────────────────────────────────
-- /soundtest            → 440 Hz beep with room reverb (no file required)
-- /soundtest <url>      → stream audio file at test coords
RegisterCommand('soundtest', function(_, args)
    local testCoords = vector3(-104.82, -984.57, 114.14)
    local soundId    = 'orbit_soundtest'
    StopSound(soundId)

    if args[1] then
        PlaySoundAtCoords(soundId, args[1], testCoords, {
            volume      = 1.0,
            loop        = false,
            maxDistance = 300,
            refDistance = 12,
            reverb      = true,
            fadeIn      = 0.3,
        })
        print(('[orbit_sounds] File test: %s'):format(args[1]))
    else
        PlayOscillatorAtCoords(soundId, testCoords, {
            oscFrequency = 440,
            oscType      = 'sine',
            oscDuration  = 4.0,
            volume       = 1.0,
            maxDistance  = 300,
            refDistance  = 12,
            reverb       = true,
            reverbMix    = 0.30,
            fadeIn       = 0.2,
        })
        print('[orbit_sounds] Oscillator test (440 Hz, 4s, reverb on)')
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('~b~[Orbit Sounds]~w~ Test sound at ~y~(-104.82, -984.57, 114.14)~w~. Walk towards it to hear 3D attenuation.')
    EndTextCommandThefeedPostTicker(false, false)
end, false)

print('[orbit_sounds] Client ready.')
