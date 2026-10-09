# Pool of Radiance

The source of SSI's Pool of Radiance for DOS, version 1.3, with fixes. `./build.sh` builds `START.EXE` and `GAME.OVR`,
and the data builder `DATABLD.EXE`, into `obj/`; `./package.sh <version>` zips them for release.

## The data builder

The game's data is split by the floppy disk it shipped on: `ECL1.DAX` to `ECL8.DAX` hold the scripts, `MON1CHA.DAX` to
`MON8CHA.DAX` the monsters, and so on, and the game reads only the current disk's file. `DATABLD.EXE` gathers each kind
into one file (`ECL.DAX`, `MONCHA.DAX` and so on) that the game reads in their place. None of the game's data is in this
repository or its releases: the player builds the combined files from their own copy.

To use it, copy `DATABLD.EXE` into the game's folder with the new `START.EXE` and `GAME.OVR`, and run it there once (in
DOSBox, change to that folder and type `DATABLD`). It shows each step and writes them to `DATABLD.LOG`. The original
files are only read. Run it again after installing a new release or changing any of the game's files; it rebuilds only
the files that are out of date. Without the combined files the game reads its original files as before; to go back to
them, delete the files `DATABLD` made.

Each combined file ends with three blocks of its own: the size and CRC-32 of every original file it was built from, the
blocks that two disks held under one number with different contents (stored under a spare number), and the format
version with the CRC-32 of the whole file. The game uses a combined file only when it is whole, of its version, and
the original files are there with the sizes it lists.
