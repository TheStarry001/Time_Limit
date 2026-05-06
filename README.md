# Game Bandwidth Limiter

A parental control tool that throttles game network bandwidth by schedule, using Windows NetQosPolicy.

## Quick Start

1. Open PowerShell **as Administrator**
2. Navigate to the script directory
3. Run the install script:

```powershell
.\install_task.ps1
```

`game_limit.ps1` will now run automatically in the background on every system startup.

## Configuration — config.json

All rules live in `config.json`. The script reloads it every 60 seconds — no restart needed.

```json
{
  "rules": [
    {
      "name": "Delta Force",
      "exe": "delta_force_launcher.exe",
      "path": "E:\\Delta Force\\launcher\\delta_force_launcher.exe",
      "schedule": [
        { "repeat": "daily", "start": "21:00", "end": "22:00", "speed_kbps": 50 }
      ]
    }
  ]
}
```

### Rule Fields

| Field | Description |
|------|------|
| `name` | Rule name, used for logging and QoS policy identifier |
| `exe` | Process name to match for throttling |
| `path` | Full game path (informational only) |
| `schedule` | Array of time windows for throttling |

### Schedule Fields

| Field | Description | Values |
|------|------|--------|
| `repeat` | Repeat mode | `"daily"` / `"weekday"` (Mon–Fri) / `"weekend"` (Sat–Sun) |
| `start` | Start time | `HH:mm` format (e.g. `"21:00"`) |
| `end` | End time | `HH:mm` format (e.g. `"22:00"`) |
| `speed_kbps` | Bandwidth cap | In kbps; set to `0` to block network entirely |

### Adding a New Game

Add a new rule to the `rules` array in `config.json`. It takes effect within 60 seconds:

```json
{
  "name": "Genshin Impact",
  "exe": "GenshinImpact.exe",
  "path": "D:\\Games\\Genshin Impact\\GenshinImpact.exe",
  "schedule": [
    { "repeat": "weekday", "start": "19:00", "end": "20:00", "speed_kbps": 100 },
    { "repeat": "weekend", "start": "14:00", "end": "16:00", "speed_kbps": 200 }
  ]
}
```

## Uninstall

Run as **Administrator**:

```powershell
.\uninstall.ps1
```

This removes all QoS throttle policies and deletes the startup task.

## Files

| File | Purpose |
|------|------|
| `config.json` | Rule config — edit anytime, takes effect within 60s |
| `game_limit.ps1` | Main monitor — loops, reads config, enforces throttling |
| `install_task.ps1` | Registers the startup scheduled task |
| `uninstall.ps1` | Removes all throttle policies and the scheduled task |
| `limit_log.txt` | Runtime log (auto-generated) |
