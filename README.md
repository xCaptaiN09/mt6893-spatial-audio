# MT6893 Spatial Audio

Spatial Audio integration for wired and USB headphones on the supported
**Realme X7 Max ColorOS port**.

Maintained by **[xCaptaiN09](https://github.com/xCaptaiN09)** — Muhammed Dilshad A.

## What it does

- Registers the OPlus Spatializer and its dedicated wired/USB output.
- Repairs the supported ROM's Settings activation path and requests native stereo support.
- Uses the original headphone tuning preferred in v0.6, with no extra radius or angle changes.
- Includes an **Action** button that saves a status report during normal playback.

## Compatibility

Supported base: Realme X7 Max / MT6893, ColorOS port `PMX110_17.0.0.128`,
system SDK 37, vendor VNDK 31 and a 32-bit MediaTek audio service.
KernelSU-Next and **Magic Mount-rs 4.0.12** were used for validation.

The installer checks exact library hashes, audio configurations and labels.
A matching chipset or a Spatial Audio menu alone does not establish compatibility.
Other ROMs, AOSP builds and Nord 2 installations have not been validated.

## Installation

1. If an earlier **Spatializer test module** is installed, remove it and reboot first.
2. Download [mt6893-spatial-audio-v1.0.0.zip](releases/mt6893-spatial-audio-v1.0.0.zip).
3. Install it in **KernelSU-Next → Modules**, then reboot.
4. Keep **Magic Mount-rs** and the separate working **MT6893 USB Audio Fix** enabled.
5. Connect headphones and choose **Spatial Audio** in **Sound effect settings**.

The release uses the ID `mt6893-spatial-audio`. The old development module used
`mt6893-spatializer-test`; both must not remain installed together. Future releases
with the new ID can update in place. Do not bypass installer build/hash conflicts.

Select **Original** to use the existing native off path. To undo, disable or remove
this module and reboot. Remove it before changing ROM builds.

## Status

Play a song with Spatial Audio selected, then press **Action**. A report is saved
to Download. Registration or an enabled switch alone does not prove processing.

The audio payload retains the phone-tested v0.6 implementation. See
[testing notes](docs/testing.md) for the exact evidence and remaining coverage.
The optional channel diagnostic lives under `tools/diagnostics/` and is not
installed with the release.

## Build and verify

Python 3.10+ is sufficient. No Python dependencies or network download are required.

```sh
python tools/build.py
python tools/verify.py
cd releases
sha256sum -c SHA256SUMS
```

ZIP entry order and metadata are fixed. Rebuild the ZIP and checksum after editing
package files. Development and diagnostic reproduction is described in
[technical notes](docs/technical-notes.md).

## Repository

| Folder | Purpose |
|---|---|
| `module/` | Installed audio payload, installer, Action, required guards and notices |
| `tools/` | Build/verification scripts and optional development diagnostics |
| `docs/` | Selected tuning, patch records and summarized testing evidence |
| `releases/` | Installable module ZIP and SHA-256 checksum |

The effect libraries and profiles come from a pinned OnePlus 12R dump. The phone's
own policy extension is copied and patched only during installation. Source and
ownership are recorded in [SOURCES.txt](module/SOURCES.txt) and [NOTICE](NOTICE).
The MIT license covers project-authored code/documentation, not OEM assets.
