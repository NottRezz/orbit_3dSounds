-- ─── Server Events ───────────────────────────────────────────────────────────

-- Play sound globally (all players hear it at given world coords)
-- TriggerServerEvent('orbit_sounds:playGlobal', soundId, audioUrl, coords, options)
RegisterNetEvent('orbit_sounds:playGlobal', function(soundId, audioUrl, coords, options)
    TriggerClientEvent('orbit_sounds:playLocal', -1, soundId, audioUrl, coords, options)
end)

-- Play oscillator globally (no audio file needed)
-- TriggerServerEvent('orbit_sounds:playOscillatorGlobal', soundId, coords, options)
RegisterNetEvent('orbit_sounds:playOscillatorGlobal', function(soundId, coords, options)
    TriggerClientEvent('orbit_sounds:playOscillatorLocal', -1, soundId, coords, options)
end)

-- Play sound to a specific player
-- TriggerServerEvent('orbit_sounds:playToPlayer', targetSrc, soundId, audioUrl, coords, options)
RegisterNetEvent('orbit_sounds:playToPlayer', function(targetSrc, soundId, audioUrl, coords, options)
    TriggerClientEvent('orbit_sounds:playLocal', tonumber(targetSrc), soundId, audioUrl, coords, options)
end)

-- Stop a sound globally
-- TriggerServerEvent('orbit_sounds:stopGlobal', soundId)
RegisterNetEvent('orbit_sounds:stopGlobal', function(soundId)
    TriggerClientEvent('orbit_sounds:stopSound', -1, soundId)
end)

-- Stop all sounds globally
-- TriggerServerEvent('orbit_sounds:stopAllGlobal')
RegisterNetEvent('orbit_sounds:stopAllGlobal', function()
    TriggerClientEvent('orbit_sounds:stopAll', -1)
end)

-- Update a moving sound source globally
-- TriggerServerEvent('orbit_sounds:updatePositionGlobal', soundId, coords)
RegisterNetEvent('orbit_sounds:updatePositionGlobal', function(soundId, coords)
    TriggerClientEvent('orbit_sounds:updatePosition', -1, soundId, coords)
end)

-- ─── Server-Side Exports ─────────────────────────────────────────────────────
-- For use from other server-side scripts:
--   exports['orbit_sounds']:PlaySoundGlobal(...)
--   exports['orbit_sounds']:PlaySoundToPlayer(...)

exports('PlaySoundGlobal', function(soundId, audioUrl, coords, options)
    TriggerClientEvent('orbit_sounds:playLocal', -1, soundId, audioUrl, coords, options)
end)

exports('PlayOscillatorGlobal', function(soundId, coords, options)
    TriggerClientEvent('orbit_sounds:playOscillatorLocal', -1, soundId, coords, options)
end)

exports('PlaySoundToPlayer', function(targetSrc, soundId, audioUrl, coords, options)
    TriggerClientEvent('orbit_sounds:playLocal', tonumber(targetSrc), soundId, audioUrl, coords, options)
end)

exports('StopSoundGlobal', function(soundId)
    TriggerClientEvent('orbit_sounds:stopSound', -1, soundId)
end)

exports('StopAllGlobal', function()
    TriggerClientEvent('orbit_sounds:stopAll', -1)
end)

exports('UpdateSoundPositionGlobal', function(soundId, coords)
    TriggerClientEvent('orbit_sounds:updatePosition', -1, soundId, coords)
end)

print('[orbit_sounds] Server ready.')
