-- Config
local Config = {
    listenerTickMs   = 50,   -- camera sync interval while spatial sounds are active
    listenerIdleMs   = 500,  -- idle check interval when no spatial sounds are active
    listenerPosEps   = 0.0025,
    listenerRotEps   = 0.05,

    occlusionTickMs  = 180,  -- raycast cycle interval
    occlusionEnabled = true,
    occlusionMinGain = 0.10,
    occlusionSmooth  = 0.25,
    occlusionFlags   = 1 + 16 + 256, -- static world + buildings + vegetation
    occlusionBudget  = 4,    -- max raycasts per occlusion cycle
    occlusionMaxDist = 220.0,
    occlusionGainEps = 0.01,
}

-- State
local activeSounds = {} -- [soundId] = { url, coords, options, occlusionGain, is2D }
local spatialCount = 0
local occludableList = {}
local occludablePos = {}
local occlusionIndex = 1
local lastListener = nil

-- NUI Bridge
local function NUI(type, data)
    SendNUIMessage({ type = type, d = data })
end

-- Helpers
local function ResolveCoords(coords)
    if type(coords) == 'vector3' then
        return { x = coords.x, y = coords.y, z = coords.z }
    end
    return coords
end

local function IsOccludable(sound)
    return sound and not sound.is2D and not sound.options.noOcclusion
end

local function AddOccludable(soundId)
    if occludablePos[soundId] then return end
    occludableList[#occludableList + 1] = soundId
    occludablePos[soundId] = #occludableList
end

local function RemoveOccludable(soundId)
    local idx = occludablePos[soundId]
    if not idx then return end

    local lastIdx = #occludableList
    local lastId = occludableList[lastIdx]
    occludableList[idx] = lastId
    occludableList[lastIdx] = nil
    occludablePos[soundId] = nil

    if lastId and lastId ~= soundId then
        occludablePos[lastId] = idx
    end

    if occlusionIndex > #occludableList then
        occlusionIndex = 1
    end
end

local function TrackSound(soundId, sound)
    local old = activeSounds[soundId]
    if old then
        if not old.is2D then spatialCount = spatialCount - 1 end
        if IsOccludable(old) then RemoveOccludable(soundId) end
    end

    activeSounds[soundId] = sound

    if not sound.is2D then spatialCount = spatialCount + 1 end
    if IsOccludable(sound) then AddOccludable(soundId) end
end

local function UntrackSound(soundId)
    local old = activeSounds[soundId]
    if not old then return false end

    if not old.is2D then spatialCount = spatialCount - 1 end
    if IsOccludable(old) then RemoveOccludable(soundId) end
    activeSounds[soundId] = nil
    return true
end

local function ListenerChanged(x, y, z, pitch, yaw)
    if not lastListener then return true end
    return math.abs(lastListener.x - x) > Config.listenerPosEps
        or math.abs(lastListener.y - y) > Config.listenerPosEps
        or math.abs(lastListener.z - z) > Config.listenerPosEps
        or math.abs(lastListener.pitch - pitch) > Config.listenerRotEps
        or math.abs(lastListener.yaw - yaw) > Config.listenerRotEps
end

local function SyncListener(force)
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local pitch = camRot.x
    local yaw = -camRot.z

    if not force and not ListenerChanged(camPos.x, camPos.y, camPos.z, pitch, yaw) then
        return
    end

    lastListener = {
        x = camPos.x,
        y = camPos.y,
        z = camPos.z,
        pitch = pitch,
        yaw = yaw,
    }

    NUI('updateListener', lastListener)
end

-- Listener Tick
CreateThread(function()
    while true do
        if spatialCount > 0 then
            SyncListener(false)
            Wait(Config.listenerTickMs)
        else
            Wait(Config.listenerIdleMs)
        end
    end
end)

-- Occlusion Tick
if Config.occlusionEnabled then
    CreateThread(function()
        local ped = PlayerPedId()
        local handles = {}
        local maxDistSq = Config.occlusionMaxDist * Config.occlusionMaxDist

        while true do
            Wait(Config.occlusionTickMs)

            local total = #occludableList
            if total > 0 then
                ped = PlayerPedId()
                local origin = GetEntityCoords(ped)
                local fired = 0
                local visited = 0

                while fired < Config.occlusionBudget and visited < total do
                    if occlusionIndex > total then occlusionIndex = 1 end

                    local soundId = occludableList[occlusionIndex]
                    occlusionIndex = occlusionIndex + 1
                    visited = visited + 1

                    local sound = activeSounds[soundId]
                    if IsOccludable(sound) then
                        local c = sound.coords
                        local dx = origin.x - c.x
                        local dy = origin.y - c.y
                        local dz = origin.z - c.z
                        local distSq = dx * dx + dy * dy + dz * dz

                        if distSq <= maxDistSq then
                            fired = fired + 1
                            handles[soundId] = StartShapeTestRay(
                                origin.x, origin.y, origin.z,
                                c.x, c.y, c.z,
                                Config.occlusionFlags, ped, 0
                            )
                        elseif (sound.occlusionGain or 1.0) < 1.0 then
                            sound.occlusionGain = 1.0
                            NUI('updateOcclusion', { id = soundId, gain = 1.0 })
                        end
                    end
                end

                if fired > 0 then
                    Wait(0)

                    for soundId, handle in pairs(handles) do
                        local sound = activeSounds[soundId]
                        if sound then
                            local _, hit = GetShapeTestResult(handle)
                            local target = (hit == 1) and Config.occlusionMinGain or 1.0
                            local current = sound.occlusionGain or 1.0
                            local next = current + (target - current) * Config.occlusionSmooth

                            if math.abs(next - current) >= Config.occlusionGainEps then
                                sound.occlusionGain = next
                                NUI('updateOcclusion', { id = soundId, gain = next })
                            end
                        end

                        handles[soundId] = nil
                    end
                end
            end
        end
    end)
end

-- Core API

---Play an audio file at a world position.
---@param soundId  string
---@param audioUrl string?
---@param coords   vector3
---@param options  table
function PlaySoundAtCoords(soundId, audioUrl, coords, options)
    options = options or {}
    local c = ResolveCoords(coords)

    SyncListener(true)
    TrackSound(soundId, {
        url = audioUrl,
        coords = c,
        options = options,
        occlusionGain = 1.0,
    })

    NUI('playSound', {
        id = soundId,
        url = audioUrl,
        x = c.x,
        y = c.y,
        z = c.z,
        options = options,
    })
end

---Play a synthesized tone at a world position.
---@param soundId string
---@param coords  vector3
---@param options table
function PlayOscillatorAtCoords(soundId, coords, options)
    options = options or {}
    options.isOscillator = true
    PlaySoundAtCoords(soundId, nil, coords, options)
end

---Play a non-spatialized sound with no world position.
---@param soundId  string
---@param audioUrl string?
---@param options  table
function PlaySound2D(soundId, audioUrl, options)
    options = options or {}
    TrackSound(soundId, { options = options, is2D = true })
    NUI('play2D', { id = soundId, url = audioUrl, options = options })
end

---Stop a sound immediately.
---@param soundId string
function StopSound(soundId)
    UntrackSound(soundId)
    NUI('stopSound', { id = soundId })
end

---Fade a sound out then stop it.
---@param soundId  string
---@param duration number
function StopSoundFade(soundId, duration)
    UntrackSound(soundId)
    NUI('stopSoundFade', { id = soundId, duration = duration or 0.4 })
end

---Stop every active sound immediately.
function StopAllSounds()
    activeSounds = {}
    spatialCount = 0
    occludableList = {}
    occludablePos = {}
    occlusionIndex = 1
    NUI('stopAll', {})
end

---Move a live sound source to new world coords.
---@param soundId string
---@param coords  vector3
function UpdateSoundPosition(soundId, coords)
    local sound = activeSounds[soundId]
    if not sound then return end

    local c = ResolveCoords(coords)
    sound.coords = c
    NUI('updateSoundPosition', { id = soundId, x = c.x, y = c.y, z = c.z })
end

---Change the master volume of a playing sound.
---@param soundId string
---@param volume  number
function UpdateSoundVolume(soundId, volume)
    if not activeSounds[soundId] then return end
    NUI('updateSoundVolume', { id = soundId, volume = volume })
end

---Toggle looping on a playing sound.
---@param soundId string
---@param loop    boolean
function SetSoundLoop(soundId, loop)
    if not activeSounds[soundId] then return end
    NUI('setSoundLoop', { id = soundId, loop = loop })
end

-- Exports
exports('PlaySound2D',            PlaySound2D)
exports('PlaySoundAtCoords',      PlaySoundAtCoords)
exports('PlayOscillatorAtCoords', PlayOscillatorAtCoords)
exports('StopSound',              StopSound)
exports('StopSoundFade',          StopSoundFade)
exports('StopAllSounds',          StopAllSounds)
exports('UpdateSoundPosition',    UpdateSoundPosition)
exports('UpdateSoundVolume',      UpdateSoundVolume)
exports('SetSoundLoop',           SetSoundLoop)

-- NUI Callbacks
RegisterNUICallback('soundEnded', function(data, cb)
    UntrackSound(data.id)
    cb({})
end)

-- Net Events
RegisterNetEvent('orbit_sounds:play2D',              function(id, url, opts)         PlaySound2D(id, url, opts) end)
RegisterNetEvent('orbit_sounds:playLocal',           function(id, url, coords, opts) PlaySoundAtCoords(id, url, coords, opts) end)
RegisterNetEvent('orbit_sounds:playOscillatorLocal', function(id, coords, opts)       PlayOscillatorAtCoords(id, coords, opts) end)
RegisterNetEvent('orbit_sounds:stopSound',           function(id)                     StopSound(id) end)
RegisterNetEvent('orbit_sounds:stopSoundFade',       function(id, dur)                StopSoundFade(id, dur) end)
RegisterNetEvent('orbit_sounds:stopAll',             function()                       StopAllSounds() end)
RegisterNetEvent('orbit_sounds:updatePosition',      function(id, coords)             UpdateSoundPosition(id, coords) end)

-- Test Command
RegisterCommand('soundtest', function(_, args)
    local testCoords = vector3(-104.82, -984.57, 114.14)
    local soundId = 'orbit_soundtest'
    StopSound(soundId)

    if args[1] then
        PlaySoundAtCoords(soundId, args[1], testCoords, {
            volume = 1.0,
            loop = false,
            maxDistance = 300,
            refDistance = 12,
            reverb = true,
            fadeIn = 0.3,
        })
        print(('[orbit_sounds] File test: %s'):format(args[1]))
    else
        PlayOscillatorAtCoords(soundId, testCoords, {
            oscFrequency = 440,
            oscType = 'sine',
            oscDuration = 4.0,
            volume = 1.0,
            maxDistance = 300,
            refDistance = 12,
            reverb = true,
            reverbMix = 0.30,
            fadeIn = 0.2,
        })
        print('[orbit_sounds] Oscillator test (440 Hz, 4s, reverb on)')
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('~b~[Orbit Sounds]~w~ Test sound at ~y~(-104.82, -984.57, 114.14)~w~. Walk towards it to hear 3D attenuation.')
    EndTextCommandThefeedPostTicker(false, false)
end, false)

print('[orbit_sounds] Client ready.')
