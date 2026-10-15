# Pool of Radiance

Reverse engineered source of SSI's Pool of Radiance for DOS, version v1.3, with fixes 

Each version (v1.1, v1.2, and v1.3) reproduce the released version byte for byte.

## AI Usage

Claude Code from Anthropic, Codex from OpenAI, and Qwen3-Next-Coder with the Pi coding agent were used for this project.

## Building

To build you'll need:
- Turbo Pascal 5.0 for v1.1 and v1.2
- Turbo Pascal 6.0 (1991 RTL) for v1.3
- DOSBox or DOSBox-X

`./build.sh` builds `obj/START.EXE` and `obj/GAME.OVR` and reports the code, data and overlay sizes. `./build.sh --install` also copies them into `drive_c/POOLRAD` to play.

## Tests

`./build.sh --test` builds the game, then compiles and runs the unit tests in `tests/` under the same Turbo Pascal in DOSBox-X. A test is a small program (`tests/tstats.pas`, say) that uses the units it tests and `TestKit`, and calls `TestKit.Start`, the `Check` routines and `TestKit.Done`; each appends its results to `obj/tests/TEST.LOG`, and the build fails if a check fails or a test program does not compile or finish. CI runs the tests on every push and pull request.

Unit tests cover logic that needs no screen, keyboard or game data. Behaviour (screens, menus, combat) is checked by replaying scenarios in the GoldBox emulator harness (goldbox-player) against a build from before a change.

## Data Files

The game's data is split by the floppy disk it shipped on: `ECL1.DAX` to `ECL8.DAX` hold the scripts, `MON1CHA.DAX` to `MON8CHA.DAX` the monsters, and so on, and the game read only the current disk's file. At startup the game gathers each set of files and aggregates them into one: `ECL.DAX`, `MONCHA.DAX`, etc. The aggregated files are used by the game first, in place of the per-disk versions.

This keeps game data out of this repository, while allowing that same data to be patched by the aggregation process.

The build only occurs once, unless a subsequent update is made. At 3000 cycles (in DOSBox or DOSBox-X) it takes roughly 49 seconds to create the aggregate files. There's a full screen showing the status of the build, and progress is logged to `DATABLD.LOG` in the game folder.

If the aggregate files can't be created the game will continue after issuing a warning; the only impact is that quest and other data fixes won't be in effect.
