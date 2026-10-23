# Technical notes

## Selected tuning

All eight `HP_*.bin` profiles are exact original donor bytes used by v0.6.
`tuning-baseline.json` records their fixed hashes and all three position arrays.
The third array supplies the following directional entries used for the 7.1.4
comparison; its radius values are all 1.0 engine units.

| Position | Direction from straight ahead | Elevation | Radius |
|---|---|---|---|
| Front centre | 0° | 0° | 1.0 |
| Front pair | 45° either side | 0° | 1.0 |
| Side pair | 90° either side | 0° | 1.0 |
| Rear pair | 135° either side | 0° | 1.0 |
| Top front pair | 45° either side | 45° up | 1.0 |
| Top rear pair | 135° either side | 45° up | 1.0 |

The first five-position array uses front radius 0.9 in Music profiles and 0.7
in Movie profiles; other entries use 1.0. The second five-position array uses
1.0 throughout. These are engine values, not verified physical metres.
The experiments in v0.7 and v0.8 are not part of the selected tuning.

## Integration

- The 32-bit effect plugin has three log-format repairs and two existing-helper
  capability-dispatch repairs. No replacement capability list is fabricated.
- The donor support dependency is renamed `libspstdc.so` so the existing phone
  `libstdc++.so` and `libc++_shared.so` remain untouched.
- One Spatializer mix port and four wired/USB route sources are added to both
  inspected policy files, preserving their original bodies and routes.
- The installer checks the phone's exact framework libraries, copies
  `/system_ext/lib64/libaudiopolicyextimpl.so` into module staging and changes the
  four bytes at offset `0x44604` from `b5000037` to `75000037`. Its final hash is
  verified. The original phone library is not distributed or written.
- Configuration/tuning uses `vendor_configs_file`; libraries use `vendor_file`.
  System-extension labels are read from the live phone and copied to staging.
- `ro.audio.stereo_spatialization_enabled=true` requests the existing native path;
  feature flags, source eligibility and routing still apply.

The native enabled/off guard remains intact. No permanent enabled override,
policy-state daemon, primary HAL replacement or SELinux change is included.
`docs/patches.json` records exact bytes/hashes. `TUNING-GUARDS` recognizes exact
previous experiment hashes only to support restoring the original profiles.

## Reproduce libraries

```sh
python tools/reproduce_libraries.py
```

This reruns the included guarded plugin/support patch scripts into a temporary
directory and compares the outputs with the packaged libraries. The engine and
selected tuning have no modifications. To inspect the separate phone-library
patch on a copy you supply, use:

```sh
python tools/reproduction/patch_settings_activation.py ORIGINAL_LIBRARY OUTPUT_COPY
```

## Recompile the optional channel client

The optional diagnostic's checked-in `probe.jar` is precompiled for Android. `tools/diagnostics/playback/BUILD.json`
binds its hash to the included Java source and records the ECJ/R8 tool hashes.
If changing the Java source, supply those exact tool JARs locally:

```sh
python tools/compile_probe.py --ecj /path/to/ecj.jar --r8 /path/to/r8.jar
python tools/build.py
python tools/verify.py
```

Java is needed only for recompilation. The channel client plays one bounded
24-second AUTO stream, drains it and releases its own AudioTrack. It changes no
global policy or sound setting. The shell wrapper captures finite reports during
playback and tolerates a missing installer `customize.sh` after installation.
Missing or changed runtime/client files still fail verification.

## Release package layout

`module/` contains only the installed audio integration, Action, installer,
checksum/build/label guards and required notices. Reproduction inputs/scripts
are under `tools/reproduction/`; patch records are under `docs/patches.json`.
The optional channel client and wrapper are under `tools/diagnostics/` with
their own checksums. None of those development files is flashed by v1.0.0.

The module ID changes to `mt6893-spatial-audio` for this first public release.
Remove the old `mt6893-spatializer-test` module and reboot before installing it.
An installer guard refuses installation while the old module is still present.
The exact former profile hashes remain recognized for conflict checks.
