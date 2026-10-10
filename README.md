# Pool of Radiance

The source of SSI's Pool of Radiance for DOS, version 1.3, with fixes. `./build.sh` builds `START.EXE` and `GAME.OVR`
into `obj/`; `./package.sh <version>` zips them for release.

## Building

`./build.sh` needs DOSBox-X 2025.02.01 or later on the PATH, and the DOS toolchains in `drive_c/` at the repository root
or in the folder `TOOLS` names: the Turbo Pascal folder that `build/toolchain` names (`TP6-1991`; `TP50` where the file
is absent, as in v1.1 and v1.2), `TASM/` and `EXEPACK/`. DOSBox-X runs `build/build.bat`, which leaves the tools' output
in `build/logs/`. `./build.sh --install` also copies the two files into `drive_c/POOLRAD`, keeping SSI's originals in
`drive_c/POOLRAD/SSI` the first time.

## Releases and CI

CI (`.forgejo/workflows/build.yml`) builds every push to main and every pull request. Alongside,
`.forgejo/scripts/reproduce.sh` rebuilds each SSI release this repository reproduces (v1.1, v1.2 and v1.3, with their
SHA-256 in `.forgejo/ssi-releases.txt`) from its tag and requires SSI's exact bytes. A pushed `v*` tag is built, zipped
with `package.sh` and attached to the tag's Forgejo release by `.forgejo/scripts/release.sh`; running the workflow by
hand with a tag does the same for a tag that predates the workflow.

## The combined data files

The game's data is split by the floppy disk it shipped on: `ECL1.DAX` to `ECL8.DAX` hold the scripts, `MON1CHA.DAX` to
`MON8CHA.DAX` the monsters, and so on, and the game read only the current disk's file. At startup, before the
introduction, the game gathers each kind into one file (`ECL.DAX`, `MONCHA.DAX` and so on, fourteen in all) and then
reads those in place of the per-disk files. None of the game's data is in this repository or its releases: the
combined files are built from the player's own copy.

The first start builds all fourteen, which takes a little while, once. A full screen shows the file being built and its
step, how many of the fourteen are finished with a bar and the time left, and a row for each kind with a cell for each
per-disk file. The bottom line says "Please wait, constructing data files..." and shows each step, and every step goes
to `DATABLD.LOG` in the game folder. When a kind could not be built, its row turns red and the screen waits for Enter;
when the game folder cannot be written at all, the screen says so in place of the progress, and nothing is built. Later
starts check the combined files and go straight on. A combined file is built again when it is missing, cut short or of
another version, or when the per-disk files it lists are no longer there with the sizes it lists. The original files are
only read. A kind whose file cannot be built (the game folder cannot be written, say) is read from its per-disk files as
before, and `DATABLD.LOG` says why.

Each combined file ends with three blocks of its own: the size and CRC-32 of every original file it was built from, the
blocks that two disks held under one number with different contents (stored under a spare number), and the format
version with the CRC-32 of the whole file. Each file is written under a temporary name, read back and checked against
that CRC-32, and only then renamed into place. The game uses a combined file only when it is whole, of its version, and
the original files are there with the sizes it lists.
