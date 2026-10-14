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

## Data Files

The game's data is split by the floppy disk it shipped on: `ECL1.DAX` to `ECL8.DAX` hold the scripts, `MON1CHA.DAX` to `MON8CHA.DAX` the monsters, and so on, and the game read only the current disk's file. At startup the game gathers each set of files and aggregates them into one: `ECL.DAX`, `MONCHA.DAX`, etc. The aggregated files are used by the game first, in place of the per-disk versions.

This keeps game data out of this repository, while allowing that same data to be patched by the aggregation process.

The build only occurs once, unless a subsequent update is made. At 3000 cycles (in DOSBox or DOSBox-X) it takes roughly 49 seconds to create the aggregate files. There's a full screen showing the status of the build, and progress is logged to `DATABLD.LOG` in the game folder.

If the aggregate files can't be created the game will continue after issuing a warning; the only impact is that quest and other data fixes won't be in effect.
