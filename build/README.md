# The `build/` directory

This directory travels with the source for each release. Like `src/`, every Git tag includes its own copy. That
means checking out a tag gives you both the source and the build configuration used for that version. With the
original compilers and build steps, SSI's v1.1, v1.2, and v1.3 can all be rebuilt byte for byte.

CI reproduction jobs and releases made from older tags check out the matching `src/` and `build/` directories
together. The scripts that orchestrate those builds live in [`scripts/`](../scripts/) and always come from the
current version of the repository.

## What's here

- **[`build.bat`](build.bat)** runs the DOS portion of the build. [`scripts/build.sh`](../scripts/build.sh) starts
  DOSBox-X and runs this file from `E:\SRC`, with Turbo Pascal mounted on `D:`, the repository on `E:`, TASM on
  `F:`, and EXEPACK on `G:`. It assembles the sound driver (plus the trace variant used by the tests), compiles
  `FIXMAIN.PAS`, renames the overlay to `GAME.OVR`, packs `START.EXE` with EXEPACK, and compiles `POOLCFG.PAS` when
  that source file is present. Generated files go into `obj/`.
- **[`toolchain`](toolchain)** records the compilers and libraries used by this version, one `name=value` pair per
  line:
  - `compiler` selects the Turbo Pascal directory under the DOS toolchains (`TOOLS`), such as `TP6-1991`. Versions
    without a `toolchain` file, including SSI's v1.1 and v1.2, use `TP50`.
  - `fpc`, `fpc_bootstrap`, and `sdl3` identify the Free Pascal source (branch and commit), the released compiler
    used to bootstrap it, and the SDL3 release used by the native ports.
    [`scripts/fpc-setup.sh`](../scripts/fpc-setup.sh) and [`scripts/sdl3-setup.sh`](../scripts/sdl3-setup.sh) read
    these values.
- **`logs/`** contains output from the most recent build: DOSBox-X output; assembler, compiler, and packer logs
  (`TASM.OUT`, `TPC.OUT`, `PACK.OUT`, and `TPCCFG.OUT`); and unit-test compilation logs under `logs/tests/`. Git
  does not track this directory. [`scripts/build.sh`](../scripts/build.sh) reads the logs when reporting errors.

## Building by hand

For a manual build inside DOSBox, use [`scripts/BUILD.BAT`](../scripts/BUILD.BAT). Despite the similar name, it is
separate from this directory's `build.bat`: it locates the compilers itself and explains each step as it runs.
See the [compilation guide](../docs/COMPILING.md) for full instructions.
