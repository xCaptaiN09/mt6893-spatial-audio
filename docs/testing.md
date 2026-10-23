# Testing notes

Device: Realme X7 Max / MT6893 running the ColorOS port `PMX110_17.0.0.128`.
System SDK 37; vendor VNDK 31; 32-bit MediaTek audio service; KernelSU-Next legacy
and Magic Mount-rs 4.0.12-941. Actual kernel 4.19.325; uname 5.10.246 is spoofed.

| Evidence | Result | Scope |
|---|---|---|
| v0.6 report, 2026-10-23 12:19 IST | All mounted hashes and labels match; native stereo true; OPlus effect enabled and engine processing advances | USB stereo YouTube Music playback |
| v0.8 height report, 2026-10-23 14:21 IST | Active 7.1.4 source, 3.5 mm route, enabled effect, processing counter 128→512; 1,152,000 frames submitted and played | Integration evidence; its doubled-radius tuning is rejected for this package |
| Listening feedback | Original v0.6 tuning preferred; increasing radius degraded the result | One listener and headphone setup |
| v1.0.0 packaging | Exact v0.6 profiles restored; installer upgrade and host release checks run before delivery | Not a fresh phone playback result |

The selected tuning has no extra radius or changed angles. Direction and
outside-the-head perception remain listener-dependent. No cause has been
established for weak front/side distinction. Stereo songs do not contain
independent top/rear channels. The USB Audio Fix remains a separate module.

Complete Original/off A/B, Bluetooth, all players, reconnects and other ROM/device
builds are not covered by these captures. The native off guard is retained and
was inspected; this is not a promise that every transition has been phone-tested.
The first 1.0.0 phone check should cover install/reboot, both available connectors,
Spatial Audio/Original switching, reconnect and normal song playback.

Raw device logs are deliberately omitted from the repository. Relevant original
filenames: `spatial-activation-20261023-121920.txt` and
`spatial-radius-height-20261023-142127.txt`.

If headphone detection or sound fails, disable only this Spatial Audio module and
reboot. Keep Magic Mount and USB Audio Fix enabled. Save the module Action report
and installer output before changing anything else.
