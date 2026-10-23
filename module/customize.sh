#!/system/bin/sh
# The manager extracts this ZIP; this installer writes only inside MODPATH.
ui_print " "
ui_print "MT6893 Spatial Audio | 1.0.0"
ui_print " "
ui_print "[1/3] Checking the supported phone build"
# A new public ID must not coexist with the earlier development module.
legacy_module=/data/adb/modules/mt6893-spatializer-test
[ ! -f "$legacy_module/module.prop" ] || abort "Remove the old Spatializer module and reboot before installing this release. Keep USB Audio Fix and Magic Mount enabled."
. "$MODPATH/config.sh"
check_build /proc/1/root || abort "$FAIL_REASON"
check_activation_framework /proc/1/root || abort "$FAIL_REASON"
check_tuning_upgrade || abort "$FAIL_REASON"
mmrs=/data/adb/modules/magic_mount_rs
[ -f "$mmrs/module.prop" ] && [ ! -e "$mmrs/disable" ] && [ ! -e "$mmrs/remove" ] || abort "Enable Magic Mount-rs first."
grep -Eq '^version=v?4\.0\.12([.-].*)?$' "$mmrs/module.prop" || abort "This release requires Magic Mount-rs 4.0.12. Send the installer output for another version."
[ -d /proc/1/root/odm ] || abort "The ODM partition is unavailable."
# Stop on an unexpected stock label rather than guessing the device's policy.
for config_path in /vendor/etc /odm/etc /vendor/etc/audio_policy_configuration.xml /vendor/etc/audio_policy_configuration_a2dp_offload_disabled.xml; do
  current_context=$(file_context "/proc/1/root$config_path") || abort "Cannot read the SELinux label: $config_path"
  [ "$current_context" = "$CONFIG_CONTEXT" ] || abort "Unexpected configuration label on $config_path: $current_context. Remove the earlier Spatializer module and reboot first."
done
case "$(file_sha /proc/1/root/vendor/etc/audio_effects.xml)" in
  "$VENDOR_XML_ORIGINAL"|"$VENDOR_XML_MODULE") ;;
  *) abort "Vendor effect configuration differs from the inspected build. No changes installed." ;;
esac
case "$(file_sha /proc/1/root/odm/etc/audio_effects.xml)" in
  "$ODM_XML_ORIGINAL"|"$ODM_XML_MODULE") ;;
  *) abort "ODM effect configuration differs from the inspected build. No changes installed." ;;
esac
# The captured policy body is exact; tolerate only final newline-count differences.
while read -r original test policy_path; do
  case "$(text_sha "/proc/1/root$policy_path")" in
    "$original"|"$test") ;;
    *) abort "Policy content differs from the inspected build: $policy_path. No policy installed." ;;
  esac
done < "$MODPATH/POLICY-GUARDS"
active_policy=$(timeout 8 dumpsys media.audio_policy 2>/dev/null | sed -n 's/^[[:space:]]*Config source: //p')
is_supported_policy "$active_policy" || abort "The running service uses another policy or could not be queried: $active_policy"
ui_print "Currently selected: $active_policy"
ui_print "Configuration labels verified."
# A failed 0.1 install may leave extracted files in this module's staging directory.
# Remove only its checksum-identified bundled copy, never the live phone library.
legacy="$MODPATH/system/odm/lib/libstdc++.so"
if [ -e "$legacy" ] || [ -L "$legacy" ]; then
  module_base=$(readlink -f "$MODPATH")
  legacy_real=$(readlink -f "$legacy")
  case "$legacy_real" in
    "$module_base"/*) ;;
    *) abort "Unexpected legacy support path outside module staging." ;;
  esac
  [ "$(file_sha "$legacy")" = '9aa0c1963d0560014a6437b3e865b200e7980a00ba4e3208a3fdee39db455da0' ] || abort "Unknown legacy support file in module staging. Remove the failed module and retry."
  rm -f "$legacy" || abort "Could not clear the old module's staged support copy."
fi
# Do not hide an existing, different engine, plugin, support library or tuning file.
while read -r expected target; do
  case "$target" in */audio_effects.xml) continue ;; esac
  if is_supported_policy "$target" || is_activation_library "$target" || is_tuning_profile "$target"; then continue; fi
  if [ -e "/proc/1/root$target" ] || [ -L "/proc/1/root$target" ]; then
    [ "$(file_sha "/proc/1/root$target")" = "$expected" ] || abort "An existing file conflicts with this module: $target"
  fi
done < "$MODPATH/LIVE-SHA256SUMS"
# ODM precedes vendor in this linker's search path. Refuse an indirect library replacement too.
for name in libspstdc.so liboplus_spat_audiox.so soundfx/liboplus_spatializer.so; do
  if [ -e "/proc/1/root/vendor/lib/$name" ] || [ -L "/proc/1/root/vendor/lib/$name" ]; then
    expected=$(file_sha "$MODPATH/system/odm/lib/$name")
    [ "$(file_sha "/proc/1/root/vendor/lib/$name")" = "$expected" ] || abort "A different vendor library would be shadowed: /vendor/lib/$name"
  fi
done
ui_print "[2/3] Verifying the module payload"
(cd "$MODPATH" && sha256sum -c SHA256SUMS) || abort "Module payload checksum failed."
# Copy and patch only MODPATH. The live /system_ext file is never written.
activation_source="/proc/1/root$POLICY_EXTENSION"
activation_target="$MODPATH/system$POLICY_EXTENSION"
if [ -e "$MODPATH/system_ext" ] && [ ! -e "$MODPATH/system/system_ext" ]; then
  activation_target="$MODPATH$POLICY_EXTENSION"
fi
mkdir -p "${activation_target%/*}" || abort "Cannot create the staged policy-library directory."
activation_real=$(readlink -f "$activation_target") || abort "Cannot resolve the staged policy-library path."
module_real=$(readlink -f "$MODPATH") || abort "Cannot resolve module staging."
case "$activation_real" in "$module_real"/*) ;; *) abort "Policy-library staging escapes the module." ;; esac
[ ! -L "$activation_target" ] || abort "Refusing a staged policy-library symlink."
cp "$activation_source" "$activation_target" || abort "Cannot copy the inspected policy extension."
if [ "$(file_sha "$activation_target")" = "$POLICY_EXTENSION_ORIGINAL" ]; then
  dd if="$MODPATH/patches/settings-wired-branch.bin" of="$activation_target" bs=1 seek=280068 count=4 conv=notrunc 2>/dev/null || abort "Could not patch the staged library."
fi
[ "$(file_sha "$activation_target")" = "$POLICY_EXTENSION_PATCHED" ] || abort "Staged policy-extension checksum mismatch."
# Record the exact labels on the existing phone's system-extension paths.
copied_contexts="$MODPATH/COPIED-FILE-CONTEXTS"
: > "$copied_contexts" || abort "Cannot record original system-extension labels."
while read -r target; do
  original_context=$(file_context "/proc/1/root$target") || abort "Cannot read the original system-extension label: $target"
  printf '%s %s\n' "$original_context" "$target" >> "$copied_contexts" || abort "Cannot record a system-extension label."
done < "$MODPATH/COPY-FILE-CONTEXTS"
ui_print "Verified the patched module copy; original phone library preserved."
ui_print "[3/3] Preparing files and checking every mounted label"
set_perm_recursive "$MODPATH" 0 0 0755 0644
for partition_path in "$MODPATH/system/odm" "$MODPATH/system/vendor" "$MODPATH/vendor"; do
  [ -d "$partition_path" ] || continue
  set_perm_recursive "$partition_path" 0 0 0755 0644 "$LIB_CONTEXT" || abort "Could not prepare library labels."
  [ ! -d "$partition_path/etc" ] || set_perm_recursive "$partition_path/etc" 0 0 0755 0644 "$CONFIG_CONTEXT" || abort "Could not prepare configuration labels."
done
# Preserve every system-extension ancestor's original label too.
while read -r expected_context target; do
  staged=$(staged_target "$target") || abort "Unexpected system-extension staging path: $target"
  if [ -d "$staged" ]; then mode=0755; else mode=0644; fi
  set_perm "$staged" 0 0 "$mode" "$expected_context" || abort "Cannot label staged system extension: $target"
  actual_context=$(file_context "$staged") || abort "Cannot read staged system-extension label: $target"
  [ "$actual_context" = "$expected_context" ] || abort "Staged system-extension label mismatch: $target"
done < "$MODPATH/COPIED-FILE-CONTEXTS"
set_perm "$MODPATH/action.sh" 0 0 0755
# Read back all file AND directory labels. Some managers do not propagate a
# failed chcon status from set_perm_recursive, so its exit code is insufficient.
checked_contexts=0
while read -r expected_context target; do
  staged=$(staged_target "$target") || abort "Unexpected context-manifest path: $target"
  actual_context=$(file_context "$staged") || abort "Cannot read the staged SELinux label: $target"
  [ "$actual_context" = "$expected_context" ] || abort "Staged SELinux label mismatch on $target: $actual_context; expected $expected_context. No changes installed."
  checked_contexts=$((checked_contexts+1))
done < "$MODPATH/FILE-CONTEXTS"
ui_print "Verified $checked_contexts mounted file/directory labels."
ui_print " "
ui_print "Original headphone tuning is staged. Reboot to activate it."
ui_print "Select Spatial Audio in Sound effect settings."
ui_print "Select Original to use Android's existing off path."
ui_print "Play music and press Action to save a status report."
ui_print "Keep USB Audio Fix and Magic Mount enabled."
ui_print "Disable this module and reboot to undo."
