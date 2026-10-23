#!/system/bin/sh
# Read-only status capture. No setting changes, service restart or private probe.
MODDIR="${0%/*}"
MODPATH="$MODDIR"
. "$MODDIR/config.sh"
[ "$(id -u)" = 0 ] || { echo "Run this Action with root access."; exit 1; }
umask 077
stamp=$(date +%Y%m%d-%H%M%S)
report="/sdcard/Download/mt6893-spatial-audio-$stamp.txt"
work=$(mktemp -d /data/local/tmp/mt6893-spatial-status.XXXXXX) || exit 1
trap 'rm -f "$work/audio.txt" "$work/flinger.txt" "$work/policy.txt" "$work/all-contexts.txt"; rmdir "$work" 2>/dev/null' EXIT
mkdir -p /sdcard/Download || exit 1
cat "$MODDIR/FILE-CONTEXTS" "$MODDIR/COPIED-FILE-CONTEXTS" > "$work/all-contexts.txt" || { echo "Installed context record is missing; reinstall this module."; exit 1; }
echo "MT6893 Spatial Audio | Status"
echo "Collecting service reports (up to 10 seconds each)..."
timeout 10 dumpsys audio > "$work/audio.txt" 2>&1
audio_rc=$?
timeout 10 dumpsys media.audio_flinger > "$work/flinger.txt" 2>&1
flinger_rc=$?
timeout 10 dumpsys media.audio_policy > "$work/policy.txt" 2>&1
policy_rc=$?
{
  echo "MT6893 Spatial Audio 1.0.0 | Original headphone tuning"
  echo "Captured: $(date)"
  echo "SDK: $(getprop ro.build.version.sdk); VNDK: $(getprop ro.vndk.version)"
  echo "Stereo request: $(getprop ro.audio.stereo_spatialization_enabled)"
  if check_activation_framework /proc/1/root; then echo "Activation framework guard: MATCH"; else echo "Activation framework guard: $FAIL_REASON"; fi
  echo "Audio server PID(s): $(pidof audioserver)"
  echo "MediaTek audio service PID(s): $(pidof android.hardware.audio.service.mediatek)"
  if check_build /proc/1/root; then echo "Build guard: MATCH"; else echo "Build guard: $FAIL_REASON"; fi
  echo ""
  echo "=== Expected file mounts in init namespace ==="
  bad=0
  while read -r expected target; do
    actual=$(file_sha "/proc/1/root$target")
    if [ "$actual" = "$expected" ]; then echo "MATCH $target"; else echo "MISMATCH $target: $actual"; bad=$((bad+1)); fi
  done < "$MODDIR/LIVE-SHA256SUMS"
  echo "Mount mismatches: $bad"
  echo ""
  echo "=== SELinux and mounted file/directory labels ==="
  getenforce
  for namespace_root in /proc/1/root $(for p in $(pidof audioserver); do echo "/proc/$p/root"; done); do
    echo "Namespace: $namespace_root"
    context_bad=0
    while read -r expected_context target; do
      actual_context=$(file_context "$namespace_root$target")
      if [ "$actual_context" = "$expected_context" ]; then
        echo "CONTEXT MATCH $target: $actual_context"
      else
        echo "CONTEXT MISMATCH $target: $actual_context; expected $expected_context"
        context_bad=$((context_bad+1))
      fi
    done < "$work/all-contexts.txt"
    echo "Context mismatches: $context_bad"
  done
  echo ""
  echo "=== Actual audio HAL process visibility ==="
  for p in $(pidof android.hardware.audio.service.mediatek); do
    echo "PID $p executable: $(readlink "/proc/$p/exe")"
    for path in /odm/lib/soundfx/liboplus_spatializer.so /odm/lib/liboplus_spat_audiox.so /odm/lib/libspstdc.so /odm/etc/spatializer/HP_MUSIC_DIGITAL.bin; do
      echo "$(file_sha "/proc/$p/root$path") $path"
    done
    grep -E 'liboplus_spat|libspstdc|libstdc[+][+]|libc[+][+]|libutils' "/proc/$p/maps"
  done
  echo ""
  echo "=== Registration evidence ==="
  grep -inE 'de4d6aaf|ccd4cf09|Oplus Spatializer|spatializer|mCapableSpatLevel|supports binaural|mSpatOutput' "$work/flinger.txt" "$work/policy.txt" "$work/audio.txt"
  echo ""
  echo "=== Dedicated wired/USB output evidence ==="
  selected_policy=$(sed -n 's/^[[:space:]]*Config source: //p' "$work/policy.txt")
  echo "Selected policy: $selected_policy"
  if is_supported_policy "$selected_policy"; then
    echo "Selected filename is covered by this module."
    for p in $(pidof audioserver); do
      echo "Audioserver $p selected-policy file checksum: $(file_sha "/proc/$p/root$selected_policy")"
    done
  else
    echo "Selected policy is not covered or the dump failed."
  fi
  case "$selected_policy" in
    AudioPolicyConfig::setDefault*)
      echo "RECOVERY NEEDED: Android rejected the policy files and loaded its minimal fallback."
      echo "Disable only this Spatial Audio module and reboot; keep the separate USB Audio Fix enabled." ;;
  esac
  if grep -Eq '^[[:space:]]*[0-9]+[.] "mt6893_spatializer";.*AUDIO_OUTPUT_FLAG_SPATIALIZER' "$work/policy.txt"; then
    echo "Parsed dedicated output: PRESENT"
  else
    echo "Parsed dedicated output: MISSING"
  fi
  grep -inE 'mt6893_spatializer|SPATIALIZER|can spatialize|OutputStreamHandle|EffectHandle|mCapableSpatLevel|mSpatLevel|mSpatOutput' "$work/policy.txt" "$work/flinger.txt" "$work/audio.txt"
  echo ""
  echo "=== Audio HAL interfaces ==="
  if command -v lshal >/dev/null 2>&1; then
    timeout 10 lshal 2>&1 | grep -E 'android.hardware.audio[.@]|Interface|Clients'
  fi
  echo ""
  echo "=== AudioService dump (exit $audio_rc) ==="
  cat "$work/audio.txt"
  echo "=== AudioFlinger dump (exit $flinger_rc) ==="
  cat "$work/flinger.txt"
  echo "=== Audio policy dump (exit $policy_rc) ==="
  cat "$work/policy.txt"
  echo "=== Recent Spatializer and effect factory messages ==="
  timeout 10 logcat -b main -b system -d -v threadtime -t 12000 2>&1 | grep -iE 'spatializ|OplusEffectContext|oplus_spat_audiox|libspstdc|EffectsFactory|EffectHal|audio_effects|APM_AudioPolicyManager|AudioFlinger|StreamHalHidl|DeviceHalHidl|HidlUtils|avc:.*(audio|soundfx|spatial|libstdc)'
  echo ""
  echo "=== Recent SELinux policy/configuration denials ==="
  timeout 5 dmesg 2>&1 | grep -iE 'avc:.*(audioserver|audio_policy|vendor_configs_file|hal_audio)' | tail -n 80
  echo ""
  echo "Confirm active source, effect enabled state and processing; an enabled Settings switch alone is insufficient."
} > "$report" 2>&1 || { echo "Could not save the Download report."; exit 1; }
echo ""
echo "Report saved: $report"
if grep -q 'RECOVERY NEEDED:' "$report"; then
  echo "Android loaded the minimal fallback policy."
  echo "Disable only this Spatial Audio module and reboot now. Send the saved report."
  exit 2
fi
echo ""
if grep -q 'Stereo Spatialization: true' "$work/policy.txt"; then
  echo "Native stereo feature: ENABLED (active processing still needs review)."
elif grep -q 'Stereo Spatialization: false' "$work/policy.txt"; then
  echo "Native stereo feature: STILL DISABLED. The property alone was insufficient."
else
  echo "Native stereo feature: UNKNOWN; see the saved report."
fi
echo "Send $report, captured during song playback with Spatial Audio selected."
echo "Also report whether selecting Original removes the effect and both connectors still work."

