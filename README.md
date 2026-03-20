# sc-plugins-arm64

64-bit ARM (aarch64) builds of the SuperCollider community UGen plugins distributed by [schollz/supercollider-plugins](https://github.com/schollz/supercollider-plugins).

## The problem

The norns community distributes ~68 SuperCollider UGen plugins as pre-compiled **32-bit ARM** binaries targeting the Raspberry Pi CM3. These `.so` files crash with ELFCLASS32 errors on any 64-bit ARM system.

## Who this is for

**Anyone running SuperCollider on 64-bit ARM Linux.** Specifically:

- **Norns on Ableton Move** ([move-everything-norns](https://github.com/djhardrich/move-everything-norns)) — the Move runs aarch64 and previously had to strip all community plugins, breaking scripts like twins, amenbreak, pedalboard, and krill.

- **Raspberry Pi 5 norns** — the Pi 5's BCM2712 cannot boot a 32-bit kernel at all. If norns ever runs on Pi 5, it will need 64-bit plugins. This repo provides them.

- **DIY norns shield on 64-bit Pi OS** — Raspberry Pi Foundation now ships 64-bit as the default OS. A fresh norns shield setup on 64-bit Pi OS will have broken community plugins without this.

- **Any aarch64 Linux SBC** — Pine64, Orange Pi, or any ARM64 board running SuperCollider has the same 32-bit plugin gap.

## What's included

68 UGen `.so` files across 10 plugin collections:

| Collection | UGens | What it is | Source |
|---|---|---|---|
| **PortedPlugins** | 34 | Analog tape, drums, filters, oscillators, waveshapers | [madskjeldgaard/portedplugins](https://github.com/madskjeldgaard/portedplugins) |
| **mi-UGens** | 12 | Mutable Instruments clones (Braids, Plaits, Rings, Clouds, Elements, Warps, Tides, Omi, Mu, Verb, Grids, Ripples) | [v7b1/mi-UGens](https://github.com/v7b1/mi-UGens) |
| **f0plugins** | 15 | Retro chip sound emulators (SID 6581, NES, Atari 2600, AY-8910, Pokey, and more) | [redFrik/f0plugins](https://github.com/redFrik/f0plugins) |
| **SuperBuf** | 1 | Enhanced buffer playback | [esluyter/super-bufrd](https://github.com/esluyter/super-bufrd) |
| **IBufWr** | 1 | Interpolating buffer writer | [tremblap/IBufWr](https://github.com/tremblap/IBufWr) |
| **XPlayBuf** | 1 | Extended buffer player | [elgiano/XPlayBuf](https://github.com/elgiano/XPlayBuf) |
| **NasalDemons** | 1 | Undefined behavior UGen | [elgiano/NasalDemons](https://github.com/elgiano/NasalDemons) |
| **CDSkip** | 1 | CD skip effect | [nhthn/supercollider-cd-skip](https://github.com/nhthn/supercollider-cd-skip) |
| **PulsePTR** | 1 | Polynomial transition region pulse | [robbielyman/pulseptr](https://github.com/robbielyman/pulseptr) |
| **TrianglePTR** | 1 | Polynomial transition region triangle | [robbielyman/triangleptr](https://github.com/robbielyman/triangleptr) |

## Install via maiden (norns)

In maiden's matron REPL:

```
;install https://github.com/seajaysec/sc-plugins-arm64
```

Then load **sc-plugins-arm64** from SELECT. It will detect your architecture, download the 64-bit binaries, and install them. Restart norns when prompted.

## Install manually

Download the latest release and extract to your SuperCollider extensions directory:

```bash
curl -fsSL https://github.com/seajaysec/sc-plugins-arm64/releases/latest/download/sc-plugins-arm64.tar.gz \
    -o /tmp/sc-plugins-arm64.tar.gz
tar xzf /tmp/sc-plugins-arm64.tar.gz -C ~/.local/share/SuperCollider/
rm /tmp/sc-plugins-arm64.tar.gz
```

Restart SuperCollider to load the plugins.

## Build from source

Run on any Debian-based aarch64 system with `supercollider-server` installed:

```bash
git clone https://github.com/seajaysec/sc-plugins-arm64.git
cd sc-plugins-arm64
sh build.sh
```

The script will:
1. Install build dependencies (`gcc`, `g++`, `cmake`, `make`, `git`, `libsndfile1-dev`)
2. Auto-detect your installed SuperCollider version and clone matching headers
3. Build all 10 plugin collections with cmake
4. Install `.so` files to `~/.local/share/SuperCollider/Extensions/`
5. Clean up build dependencies and source trees

### Build options

| Environment variable | Default | Description |
|---|---|---|
| `SC_PLUGINS_JOBS` | `3` | Parallel build jobs. Lower this on low-memory devices. |
| `SC_PLUGINS_INSTALL_DIR` | `~/.local/share/SuperCollider/Extensions` | Override install path |
| `SC_PLUGINS_KEEP_DEPS` | `0` | Set to `1` to keep build dependencies after build |
| `SC_PLUGINS_KEEP_SRC` | `0` | Set to `1` to keep source/build trees after build |

### Build time

On a quad-core Cortex-A72 @ 1.5GHz with 2GB RAM (Ableton Move / Raspberry Pi 4): **~20-40 minutes**.

The build uses `-j3` by default with automatic fallback to `-j1` if a build fails (OOM protection for 2GB devices). Adjust `SC_PLUGINS_JOBS` if needed.

### Build quirks handled automatically

- **cmake 4.x compatibility** — older plugin CMakeLists.txt files are handled via `CMAKE_POLICY_VERSION_MINIMUM`
- **PortedPlugins / DaisySP** — `#ifdef __arm__` guards for 32-bit VFP intrinsics are correctly excluded on aarch64; if compilation fails anyway, a patch is applied and the build retries
- **IBufWr** — requires C++20 (flag passed automatically)
- **SuperBuf / IBufWr** — no cmake install target (files are copied manually)
- **f0plugins** — overrides `CMAKE_INSTALL_PREFIX` (detected and handled via manual copy fallback)

## Creating a release tarball

After building, create a distributable tarball:

```bash
tar czf sc-plugins-arm64.tar.gz \
    -C ~/.local/share/SuperCollider Extensions/
```

The tarball contains `Extensions/` at the root. Extract with `-C ~/.local/share/SuperCollider/`.

## Relationship to schollz/supercollider-plugins

[schollz/supercollider-plugins](https://github.com/schollz/supercollider-plugins) bundles the same 10 collections as pre-compiled 32-bit ARM binaries. This repo is a **64-bit counterpart** — same plugins, compiled for aarch64. The two are not in conflict; use whichever matches your architecture.

Some norns scripts (e.g., amenbreak) auto-install schollz's 32-bit bundle on first run. On 64-bit systems, these will be overwritten or stripped — install the 64-bit versions from this repo instead.

## License

Each plugin collection retains its original license. See the source repositories linked above for details.

## AI Assistance Disclaimer

This project was developed with AI assistance (Claude). All builds, testing, and verification were performed on physical hardware (Ableton Move, aarch64). AI-assisted content may contain errors — validate before production use.
