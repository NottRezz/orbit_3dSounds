# orbit_sounds

Versatile 3D positional audio system for FiveM. Built on the Web Audio API with HRTF panning — volume and stereo position update in real-time based on player distance and heading.

---

## Installation

1. Drop the `orbit_sounds` folder into your `resources` directory.
2. Add to `server.cfg`:
   ```
   ensure orbit_sounds
   ```

---

## Test Command

```
/soundtest
```
Plays a 440 Hz sine tone at `(-104.82, -984.57, 114.14)` for 3 seconds. Walk toward or away from the coords to hear the 3D attenuation.

```
/soundtest https://example.com/mysound.ogg
```
Same coords, but streams an audio file instead.

---

## Client API

These functions are available directly in the same resource or via `exports`.

### `PlaySoundAtCoords(soundId, audioUrl, coords, options)`
Play an audio file at a world position.

```lua
PlaySoundAtCoords('explosion_loop', 'nui://orbit_sounds/ui/sounds/explosion.ogg', vector3(100.0, 200.0, 30.0), {
    volume       = 1.0,
    loop         = true,
    maxDistance  = 200,
    refDistance  = 10,
    rolloffFactor = 1.2,
})
```

### `PlayOscillatorAtCoords(soundId, coords, options)`
Play a generated tone — no audio file required. Great for testing or sci-fi effects.

```lua
PlayOscillatorAtCoords('alarm', vector3(100.0, 200.0, 30.0), {
    oscFrequency = 880,
    oscType      = 'square',  -- sine | square | sawtooth | triangle
    oscDuration  = 5.0,
    loop         = false,
    volume       = 0.8,
    maxDistance  = 150,
})
```

### `StopSound(soundId)`
Stop a specific sound by its ID.
```lua
StopSound('explosion_loop')
```

### `StopAllSounds()`
Stop every active sound immediately.
```lua
StopAllSounds()
```

### `UpdateSoundPosition(soundId, coords)`
Move a live sound source to new world coords. Use this for sounds attached to moving entities.
```lua
UpdateSoundPosition('engine_hum', GetEntityCoords(vehicle))
```

### `UpdateSoundVolume(soundId, volume)`
Change the volume of a playing sound without restarting it.
```lua
UpdateSoundVolume('engine_hum', 0.3)
```

### `SetSoundLoop(soundId, loop)`
Toggle looping on a playing sound.
```lua
SetSoundLoop('engine_hum', false)
```

---

## Client Exports

Call these from another resource:

```lua
exports['orbit_sounds']:PlaySoundAtCoords(soundId, url, coords, options)
exports['orbit_sounds']:PlayOscillatorAtCoords(soundId, coords, options)
exports['orbit_sounds']:StopSound(soundId)
exports['orbit_sounds']:StopAllSounds()
exports['orbit_sounds']:UpdateSoundPosition(soundId, coords)
exports['orbit_sounds']:UpdateSoundVolume(soundId, volume)
exports['orbit_sounds']:SetSoundLoop(soundId, loop)
```

---

## Server API

### Trigger from a client (relayed to all)
```lua
-- Play globally (all players hear it)
TriggerServerEvent('orbit_sounds:playGlobal', soundId, audioUrl, coords, options)

-- Play oscillator globally
TriggerServerEvent('orbit_sounds:playOscillatorGlobal', soundId, coords, options)

-- Stop a sound globally
TriggerServerEvent('orbit_sounds:stopGlobal', soundId)

-- Stop all sounds globally
TriggerServerEvent('orbit_sounds:stopAllGlobal')

-- Update a moving source globally
TriggerServerEvent('orbit_sounds:updatePositionGlobal', soundId, coords)
```

### Server-side exports
```lua
-- All players
exports['orbit_sounds']:PlaySoundGlobal(soundId, audioUrl, coords, options)
exports['orbit_sounds']:PlayOscillatorGlobal(soundId, coords, options)
exports['orbit_sounds']:StopSoundGlobal(soundId)
exports['orbit_sounds']:StopAllGlobal()
exports['orbit_sounds']:UpdateSoundPositionGlobal(soundId, coords)

-- Specific player (pass player server ID)
exports['orbit_sounds']:PlaySoundToPlayer(targetSrc, soundId, audioUrl, coords, options)
```

---

## Options Reference

| Key | Type | Default | Description |
|---|---|---|---|
| `volume` | number | `1.0` | Master gain (0.0 – 1.0+) |
| `loop` | boolean | `false` | Loop the sound |
| `maxDistance` | number | `150` | Max audible distance in GTA units |
| `refDistance` | number | `8` | Distance at which attenuation begins |
| `rolloffFactor` | number | `1.2` | How fast volume drops past refDistance |
| `playbackRate` | number | `1.0` | Playback speed (file sounds only) |
| `offset` | number | `0` | Start offset in seconds (file sounds only) |
| `oscFrequency` | number | `440` | Tone frequency in Hz (oscillator only) |
| `oscType` | string | `'sine'` | Waveform: `sine` `square` `sawtooth` `triangle` |
| `oscDuration` | number | `2.0` | Auto-stop after N seconds (oscillator only) |

---

## Bundling Audio Files

Place `.ogg` or `.mp3` files in `ui/sounds/` and reference them with the `nui://` scheme:

```lua
'nui://orbit_sounds/ui/sounds/my_sound.ogg'
```

OGG Vorbis is recommended for best FiveM NUI compatibility.

---

## Integration Example (Superpower Script)

```lua
-- On ability activation: play a looping hum at the player's position
local function StartAbilitySound(ped)
    local id = 'ability_hum_' .. GetPlayerServerId(PlayerId())
    exports['orbit_sounds']:PlayOscillatorAtCoords(id, GetEntityCoords(ped), {
        oscFrequency = 220,
        oscType      = 'sine',
        loop         = true,
        volume       = 0.6,
        maxDistance  = 80,
        refDistance  = 5,
    })
end

-- Track position every frame while active
CreateThread(function()
    while abilityActive do
        exports['orbit_sounds']:UpdateSoundPosition('ability_hum_' .. ..., GetEntityCoords(ped))
        Wait(0)
    end
    exports['orbit_sounds']:StopSound('ability_hum_' .. ...)
end)
```
