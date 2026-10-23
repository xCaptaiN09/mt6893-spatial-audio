# Optional channel diagnostic

This folder is for troubleshooting and is not included in the flashable release.
The installed module's Action button already provides a normal-playback report.

To run this separate 24-second 7.1.4 sequence with ADB:

```sh
adb push tools/diagnostics /sdcard/Download/mt6893-spatial-diagnostic
adb shell
su
sh /sdcard/Download/mt6893-spatial-diagnostic/height-test.sh
```

Keep MT6893 Spatial Audio installed, one headphone route connected, Spatial Audio
selected and other audio paused. Use a low comfortable media volume. The client
changes no global sound setting or system volume and saves its report to Download.

The diagnostic and installed module have separate checksums. Missing or changed
runtime files fail verification. Only an installer-only `customize.sh` removed
after installation is tolerated. Rebuild from the repository root after editing
the diagnostic so its separate checksum list is regenerated.
