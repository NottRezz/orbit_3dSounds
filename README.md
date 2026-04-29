# orbit_sounds

Versatile 3D positional audio system for FiveM. Built on the Web Audio API with full HRTF head-related transfer function panning — position, direction, pitch, reverb, and occlusion all update in real-time from the gameplay camera.

---

## How It Works

| System | Detail |
|---|---|
| **Listener** | Syncs to gameplay camera position + rotation every 50ms — works in 1st and 3rd person |
| **Orientation** | Full pitch + yaw from camera rotation — sounds above/below are correctly positioned |
| **Distance model** | Inverse rolloff via Web Audio `PannerNode` with configurable ref/max distance |
| **Occlusion** | Raycast from camera to each sound source every 180ms — volume dims behind walls |
| **Reverb** | Optional per-sound room reverb via a generated impulse response convolver |
| **Compressor** | Master `DynamicsCompressorNode` prevents clipping when many sounds overlap |
| **Fade** | Built-in fade-in on play and fade-out on stop via `AudioParam` scheduling |

---

## Installation

1. Drop `orbit_sounds` into your `resources` directory.
2. Add to `server.cfg`:
   ```
   ensure orbit_sounds
   ```

---

## Test Command

```
/soundtest
```
Plays a 440 Hz sine wave with room reverb at `(-104.82, -984.57, 114.14)` for 4 seconds. Walk toward the coords and look around — volume, stereo panning, and vertical position all respond to your camera.

```
/soundtest <url>
```
Streams an audio file at the same coords.

---

## Client API

Available directly within the resource or via `exports['orbit_sounds']`.

### `PlaySoundAtCoords(soundId, audioUrl, coords, options)`
Play an audio file at a world position.

```lua
PlaySoundAtCoords('fire_loop', 'nui://orbit_sounds/ui/sounds/fire.ogg', vector3(100.0, 200.0, 30.0), {
    volume        = 1.0,
    loop          = true,
    maxDistance   = 200,
    refDistance   = 10,
    rolloffFactor = 1.5,
    reverb        = true,
    reverbMix     = 0.25,
    fadeIn        = 0.5,
})
```

### `PlayOscillatorAtCoords(soundId, coords, options)`
Play a synthesized tone — no audio file required.

```lua
PlayOscillatorAtCoords('alarm', vector3(100.0, 200.0, 30.0), {
    oscFrequency = 880,
    oscType      = 'square',   -- sine | square | sawtooth | triangle
    oscDuration  = 5.0,
    loop         = false,
    volume       = 0.8,
    reverb       = true,
})
```

### `StopSound(soundId)`
Stop a sound immediately.
```lua
StopSound('fire_loop')
```

### `StopSoundFade(soundId, duration)`
Fade a sound out then stop it. `duration` defaults to `0.4` seconds.
```lua
StopSoundFade('fire_loop', 1.0)
```

### `StopAllSounds()`
Stop every active sound immediately.
```lua
StopAllSounds()
```

### `UpdateSoundPosition(soundId, coords)`
Move a live sound source. Call each frame for sounds attached to moving entities.
```lua
UpdateSoundPosition('engine_hum', GetEntityCoords(vehicle))
```

### `UpdateSoundVolume(soundId, volume)`
Change volume on a playing sound without restarting it.
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

```lua
exports['orbit_sounds']:PlaySoundAtCoords(soundId, url, coords, options)
exports['orbit_sounds']:PlayOscillatorAtCoords(soundId, coords, options)
exports['orbit_sounds']:StopSound(soundId)
exports['orbit_sounds']:StopSoundFade(soundId, duration)
exports['orbit_sounds']:StopAllSounds()
exports['orbit_sounds']:UpdateSoundPosition(soundId, coords)
exports['orbit_sounds']:UpdateSoundVolume(soundId, volume)
exports['orbit_sounds']:SetSoundLoop(soundId, loop)
```

---

## Server API

### Client → Server (relay to all/one)
```lua
-- All players hear it at world coords
TriggerServerEvent('orbit_sounds:playGlobal', soundId, audioUrl, coords, options)

-- All players, oscillator
TriggerServerEvent('orbit_sounds:playOscillatorGlobal', soundId, coords, options)

-- Specific player (server ID)
TriggerServerEvent('orbit_sounds:playToPlayer', targetSrc, soundId, audioUrl, coords, options)

-- Stop globally
TriggerServerEvent('orbit_sounds:stopGlobal', soundId)

-- Fade stop globally
TriggerServerEvent('orbit_sounds:stopAllGlobal')

-- Move a live source globally
TriggerServerEvent('orbit_sounds:updatePositionGlobal', soundId, coords)
```

### Server-side exports
```lua
exports['orbit_sounds']:PlaySoundGlobal(soundId, audioUrl, coords, options)
exports['orbit_sounds']:PlayOscillatorGlobal(soundId, coords, options)
exports['orbit_sounds']:PlaySoundToPlayer(targetSrc, soundId, audioUrl, coords, options)
exports['orbit_sounds']:StopSoundGlobal(soundId)
exports['orbit_sounds']:StopAllGlobal()
exports['orbit_sounds']:UpdateSoundPositionGlobal(soundId, coords)
```

---

## Options Reference

### Shared
| Key | Type | Default | Description |
|---|---|---|---|
| `volume` | number | `1.0` | Master gain (0.0 – 1.0+) |
| `loop` | boolean | `false` | Loop playback |
| `fadeIn` | number | `0` | Fade-in duration in seconds |
| `maxDistance` | number | `150` | Max audible range in GTA units |
| `refDistance` | number | `8` | Distance where attenuation begins |
| `rolloffFactor` | number | `1.5` | Steepness of volume dropoff |
| `distanceModel` | string | `'inverse'` | `inverse` \| `linear` \| `exponential` |
| `reverb` | boolean | `false` | Route through shared room reverb bus |
| `reverbMix` | number | `0.22` | Reverb send level (0.0 – 1.0) |
| `noOcclusion` | boolean | `false` | Disable raycast occlusion for this sound |

### Directional Source Cone
| Key | Type | Default | Description |
|---|---|---|---|
| `coneInnerAngle` | number | — | Degrees of full-volume cone |
| `coneOuterAngle` | number | `360` | Degrees of outer cone |
| `coneOuterGain` | number | `0.15` | Volume outside outer cone |

### File Sounds Only
| Key | Type | Default | Description |
|---|---|---|---|
| `playbackRate` | number | `1.0` | Playback speed multiplier |
| `offset` | number | `0` | Start offset in seconds |

### Oscillator Only
| Key | Type | Default | Description |
|---|---|---|---|
| `oscFrequency` | number | `440` | Frequency in Hz |
| `oscType` | string | `'sine'` | `sine` \| `square` \| `sawtooth` \| `triangle` |
| `oscDuration` | number | `2.0` | Auto-stop after N seconds |

---

## Config (`client/main.lua`)

Tune these at the top of the client script:

```lua
local Config = {
    listenerTickMs   = 50,   -- camera sync rate (ms) — lower = more responsive HRTF
    occlusionTickMs  = 180,  -- raycast cycle rate (ms)
    occlusionEnabled = true,
    listenerIdleMs   = 500,
    listenerPosEps   = 0.0025,
    listenerRotEps   = 0.05,
    occlusionMinGain = 0.10, -- volume floor when fully behind a wall
    occlusionSmooth  = 0.25, -- lerp factor per cycle toward target (0.0–1.0)
    occlusionFlags   = 1 + 16 + 256, -- raycast: world + buildings + vegetation
    occlusionBudget  = 4,
    occlusionMaxDist = 220.0,
    occlusionGainEps = 0.01,
}
```

---

## Bundling Audio Files

Place `.ogg` or `.mp3` files in `ui/sounds/` and reference them with the `nui://` scheme:

```lua
'nui://orbit_sounds/ui/sounds/my_sound.ogg'
```

OGG Vorbis is recommended for FiveM NUI compatibility.

---

## Integration Example (Superpower Script)

```lua
local SOUND_ID = 'ability_hum_' .. GetPlayerServerId(PlayerId())

-- On activation
exports['orbit_sounds']:PlayOscillatorAtCoords(SOUND_ID, GetEntityCoords(ped), {
    oscFrequency = 220,
    oscType      = 'sine',
    loop         = true,
    volume       = 0.7,
    reverb       = true,
    reverbMix    = 0.35,
    fadeIn       = 0.6,
    maxDistance  = 80,
    refDistance  = 5,
})

-- Track entity position each frame while ability is active
CreateThread(function()
    while abilityActive do
        exports['orbit_sounds']:UpdateSoundPosition(SOUND_ID, GetEntityCoords(ped))
        Wait(0)
    end
    exports['orbit_sounds']:StopSoundFade(SOUND_ID, 0.8)
end)
```
