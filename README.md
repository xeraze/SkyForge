# SkyForge

A set of gameplay systems for Roblox: a S.T.A.L.K.E.R-style inventory, weapons, doors, a timer, announcements, and dialogs. Written in Luau, designed for manual installation into Roblox Studio (no Rojo).

## Systems

| System | Scripts | Description |
|---|---|---|
| **Inventory** | `InventoryClient`, `InventoryServer`, `InventoryCore`, `InventoryConfig` | S.T.A.L.K.E.R Anomaly-style grid: drag and drop, rotation (R), tabs, armor, containers, server-authoritative validation. Integrated with the bottom `SlotsGui` hotbar (slots 1–3, equipping via click and keys 1–4) |
| **Weapons** | `WeaponClient`, `WeaponServer`, `WeaponConfig` | Weapon data, viewmodel, slot switching |
| **Doors** | `DoorServer` | Automatic doors: trigger-based opening, slide/rotation, configured via model attributes |
| **Timer** | `TimerServer`, `Timer`, `TimerConfig` | Game timer with configurable phases |
| **Announcements** | `AnnouncesServer` | Global chat announcements, permissions by group rank and user ID list |
| **Dialogs** | `Lobby/DialogueScript`, `Lobby/DialogueConfig` | NPC dialogue system: typewriter effect, branching, option choices, animations, RU/EN, settings in config |

## Repository structure

```
SkyForge/
├── README.md
├── LICENSE
├── .gitignore
├── ReplicatedStorage/            shared modules and configs
│   ├── InventoryConfig.luau      inventory settings (grid, hotbar, items)
│   ├── InventoryCore.luau        pure inventory logic (validation, capacity)
│   ├── WeaponConfig.luau         weapon stats
│   ├── TimerConfig.luau          timer settings
│   └── Timer.luau                timer logic
├── ServerScriptService/          server scripts
│   ├── InventoryServer.luau      server-authoritative inventory
│   ├── WeaponServer.luau         server-side weapons
│   ├── DoorServer.luau           door logic
│   ├── TimerServer.luau          timer control
│   └── AnnouncesServer.luau      announcement delivery
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── InventoryClient.luau  inventory GUI + SlotsGui hotbar
│       └── WeaponClient.luau     client weapons, viewmodel, hotkeys
└── Lobby/                        lobby dialogue system
    ├── DialogueScript.luau       dialogue engine (animations, typewriter, options)
    └── DialogueConfig.luau       dialogue texts and settings
```

## Installation

1. Open your place in Roblox Studio.
2. Copy each `.luau` file to its path from the structure above (the repository folder mirrors the Studio hierarchy).
3. GUIs (`StarterGui/InventoryGui`, `StarterGui/SlotsGui`, `StarterGui/Messages`, `StarterGui/DialogueGui`) and Remotes are created manually in Studio - the repository contains only the code.
4. Type analysis uses [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) with `globalTypes.d.luau`.

## Notes

- The repository contains only the original system code. Third-party scripts and assets (GUI controllers, sounds, animations, models) are not included and remain the property of their authors.
- Configs (`InventoryConfig`, `WeaponConfig`, `TimerConfig`, `DialogueConfig`) are the only place with meaningful comments: they describe the fields you need to adjust for your game.
- Personal IDs (group, users) are left as `TODO` placeholders - fill in your own before use.

## License

MIT — free to use, including commercially, with copyright notice retained.

Copyright (c) 2026 Arturbek. Code development - Arthas.