#!/system/bin/sh
# One direct multichannel stream; no global state mutation.
[ "$(id -u)" = 0 ] || { echo "Run su first."; exit 1; }
DIAGDIR="${0%/*}"
MODPATH=/data/adb/modules/mt6893-spatial-audio
[ -f "$MODPATH/module.prop" ] || { echo "Install MT6893 Spatial Audio first."; exit 1; }
grep -qx 'id=mt6893-spatial-audio' "$MODPATH/module.prop" || exit 1
(cd "$DIAGDIR" && sha256sum -c SHA256SUMS >/dev/null) || { echo "Diagnostic checksum failed."; exit 1; }
. "$MODPATH/config.sh"
[ ! -e "$MODPATH/disable" ] && [ ! -e "$MODPATH/remove" ] || { echo "Enable this module and reboot first."; exit 1; }
check_build /proc/1/root && check_activation_framework /proc/1/root || { echo "$FAIL_REASON"; exit 1; }
# customize.sh is needed only during installation and can be removed afterward.
# If absent, exclude only its root entry; every runtime entry remains required.
verify_installed_payload() (
  cd "$MODPATH" || exit 1
  if [ ! -e customize.sh ] && [ ! -L customize.sh ]; then
    sed '/  customize\.sh$/d' SHA256SUMS | sha256sum -c - >/dev/null
  else
    sha256sum -c SHA256SUMS >/dev/null
  fi
)
verify_installed_payload || { echo "Installed module payload checksum failed."; exit 1; }
audio_pid=$(pidof audioserver)
case "$audio_pid" in ''|*[!0-9]*) echo "Expected one audioserver process."; exit 1 ;; esac
while read -r expected target; do
  [ "$(file_sha "/proc/$audio_pid/root$target")" = "$expected" ] || { echo "Live file differs: $target. Reboot after installation."; exit 1; }
done < "$MODPATH/LIVE-SHA256SUMS"
umask 077
work=$(mktemp -d /data/local/tmp/mt6893-spatial-height.XXXXXX) || exit 1
mkdir -p /sdcard/Download || exit 1
report="/sdcard/Download/mt6893-spatial-height-$(date +%Y%m%d-%H%M%S).txt"
player=''
snapshot_pids=''
log_start=$(date '+%m-%d %H:%M:%S.000')
finish() {
  saved_rc=$?
  trap - EXIT INT TERM
  if [ -n "$player" ]; then kill "$player" 2>/dev/null; wait "$player" 2>/dev/null; fi
  for p in $snapshot_pids; do wait "$p" 2>/dev/null; done
  {
    echo "MT6893 Spatial Audio channel check; exit=$saved_rc; $(date)"
    echo "No global settings, policy flags, system volume or module files changed."
    echo "=== Installed module ==="
    cat "$MODPATH/module.prop"
    echo "=== Player ==="
    cat "$work/player.txt"
    for service in audio media.audio_flinger media.audio_policy; do
      echo "=== DURING playback: $service ==="
      cat "$work/$service.txt"
    done
    echo "=== Messages since test start ==="
    timeout -k 1 8 logcat -b main -b system -d -v threadtime -T "$log_start" \
      -s 'OplusEffectSpatializer:V' 'OplusEffectContext:V' 'oplus_spat_audiox:V' 'AudioPolicyManagerExtImpl:V' 'Spatializer:V' 'AudioFlinger:I' '*:S'
    echo "Logcat exit: $?"
  } > "$report" 2>&1 || { echo "Could not save the playback report."; exit 1; }
  echo "Report: $report"
  echo "Report whether every labelled channel is audible and note any distortion."
  case "$work" in /data/local/tmp/mt6893-spatial-height.*) rm -rf "$work" ;; esac
  exit "$saved_rc"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "MT6893 Spatial Audio | 24-second 7.1.4 check"
echo "Keep one headphone connected and Spatial Audio selected. Original v0.6 tuning is selected."
echo "Pause other audio and use a low comfortable media volume."
echo "No temporary activation or Settings changes are used."
CLASSPATH="$DIAGDIR/playback/probe.jar" /system/bin/app_process /system/bin SpatialPlaybackProbe "$work" > "$work/player.txt" 2>&1 &
player=$!
previous=''
captured=0
ticks=0
while kill -0 "$player" 2>/dev/null; do
  label=$(cat "$work/channel.txt" 2>/dev/null)
  if [ -n "$label" ] && [ "$label" != "$previous" ]; then echo "$label"; previous="$label"; fi
  if [ "$captured" = 0 ] && [ "$(cat "$work/phase.txt" 2>/dev/null)" = AUTO ]; then
    # Independent finite dumps in parallel, while the 24-second stream is active.
    for service in audio media.audio_flinger media.audio_policy; do
      (echo "Started: $(date); phase=$(cat "$work/phase.txt" 2>/dev/null)";
       timeout -k 1 6 dumpsys "$service";
       echo "Dump exit=$?; ended phase=$(cat "$work/phase.txt" 2>/dev/null)") > "$work/$service.txt" 2>&1 &
      snapshot_pids="$snapshot_pids $!"
    done
    captured=1
  fi
  ticks=$((ticks+1))
  [ "$ticks" -lt 65 ] || { echo "Playback timed out; stopping its private client."; exit 2; }
  sleep 1
done
wait "$player"
player_rc=$?
player=''
cat "$work/player.txt" | tail -n 4
[ "$player_rc" = 0 ] && [ "$(cat "$work/phase.txt" 2>/dev/null)" = DONE ] || exit 2
[ "$captured" = 1 ] || { echo "Active playback snapshot was not captured."; exit 2; }
echo "Stream completed. This alone does not establish improved localization."
exit 0
