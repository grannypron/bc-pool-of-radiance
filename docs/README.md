# Pool of Radiance documentation

This directory contains build instructions, release notes, implementation history, and text mockups for the port's user interfaces.

## Documents

| File | Purpose |
| --- | --- |
| [`README.md`](README.md) | Index of the documentation in this directory. |
| [`COMPILING.md`](COMPILING.md) | Instructions for building, testing, and running the native Windows, macOS, and Linux ports and the DOS version, including toolchain setup and troubleshooting. |
| [`CHANGELOG.md`](CHANGELOG.md) | Player-facing release notes: new features, gameplay and interface changes, fixes, and compatibility information. |
| [`DETAILED-CHANGES.md`](DETAILED-CHANGES.md) | Developer-facing change history with implementation details, issue and commit references, data fixes, refactors, tests, and tooling changes. |

## Screen mockups

[`screen-mocks/`](screen-mocks/) contains plain-text specifications for game and setup-program screens. In addition to an ASCII layout, most files document colors, available commands, and keyboard shortcuts. They are design and implementation references rather than screenshots.

### Character and game screens

| File | Purpose |
| --- | --- |
| [`change-class.txt`](screen-mocks/change-class.txt) | Dual-class selection, eligibility, confirmation, and post-change character-display states. |
| [`f1-help.txt`](screen-mocks/f1-help.txt) | F1 command-key help overlay. |
| [`info-cleric.txt`](screen-mocks/info-cleric.txt) | Cleric information page showing turn-undead results by creature type. |
| [`info-kill-count.txt`](screen-mocks/info-kill-count.txt) | Character information page listing kills by creature type. |
| [`info-saving-throws.txt`](screen-mocks/info-saving-throws.txt) | Character information page showing the five saving-throw values. |
| [`info-stats.txt`](screen-mocks/info-stats.txt) | Character game-statistics page for kills, damage, healing, loot, spells, deaths, and related totals. |
| [`info-thief.txt`](screen-mocks/info-thief.txt) | Thief-skills breakdown showing race, Dexterity, level, and total modifiers. |
| [`load-save-game.txt`](screen-mocks/load-save-game.txt) | Load/save slot browser with save names, locations, dates, times, paging, and commands. |
| [`training-hall.txt`](screen-mocks/training-hall.txt) | Training Hall party-management menu, including character actions, save/load, settings, and dual-class access. |

### Journal screens

| File | Purpose |
| --- | --- |
| [`jrnl-entries.txt`](screen-mocks/jrnl-entries.txt) | Journal entry browser with proclamation list, selected entry text, and navigation commands. |
| [`jrnl-quests.txt`](screen-mocks/jrnl-quests.txt) | Quest-tracking page listing journal references, objectives, and completion status. |

### In-game settings screens

| File | Purpose |
| --- | --- |
| [`settings-game.txt`](screen-mocks/settings-game.txt) | Game, portrait, music, sound, Quick Mode, combat-log, and companion-tool settings page. |
| [`settings-paths.txt`](screen-mocks/settings-paths.txt) | Data and save paths for Pool of Radiance and the later games in the series. |
| [`settings-system.txt`](screen-mocks/settings-system.txt) | Read-only system information page for video, sound, version, data, memory, and EMS status. |

### Spell screens

| File | Purpose |
| --- | --- |
| [`spell-cast.txt`](screen-mocks/spell-cast.txt) | Paginated spell-casting list and its commands. |
| [`spell-memorize.txt`](screen-mocks/spell-memorize.txt) | Paginated spell-memorization list and its commands. |
| [`spell-page.txt`](screen-mocks/spell-page.txt) | Full spell-information page with caster, range, area, duration, save, casting time, and description. |
| [`spell-scribe.txt`](screen-mocks/spell-scribe.txt) | Paginated scroll-scribing list and its commands. |

### POOLCFG setup screens

| File | Purpose |
| --- | --- |
| [`poolcfg-main.txt`](screen-mocks/poolcfg-main.txt) | POOLCFG main menu and configuration-file status panel. |
| [`poolcfg-hardware.txt`](screen-mocks/poolcfg-hardware.txt) | Hardware configuration for video, sound device, and introduction mode. |
| [`poolcfg-settings.txt`](screen-mocks/poolcfg-settings.txt) | Game-settings editor, contextual About panel, defaults, and controls. |
| [`poolcfg-paths.txt`](screen-mocks/poolcfg-paths.txt) | Data/save path editor, validation behavior, editing controls, and error states. |
| [`poolcfg-notice.txt`](screen-mocks/poolcfg-notice.txt) | Startup notice shown when `POOL.CFG` is missing or damaged. |
| [`poolcfg-exit.txt`](screen-mocks/poolcfg-exit.txt) | Unsaved-changes prompt and its save, discard, and cancel actions. |
