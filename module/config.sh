#!/system/bin/sh
# Exact-build checks shared by the installer and read-only Action.
SPATIALIZER_UUID='de4d6aaf-4e9d-473d-8168-4ce92d50a637'
CPP_SHA='baec5df7849d32bfec9f98d1e84a8a9e0d53400ec07f3eca8337a530d42cc5ef'
HAL_ORIGINAL='f080b9f3f607590b00aeca4a4a043eba4d594291bde287b20629ef35591db7fa'
HAL_USB_FIXED='b334b7ed5a4819eb1a922e958531ea964e985d0482456c42ab969d03c7cbf33e'
CONFIG_CONTEXT='u:object_r:vendor_configs_file:s0'
LIB_CONTEXT='u:object_r:vendor_file:s0'
file_context() {
  context_line=$(ls -Zd "$1" 2>/dev/null) || return 1
  for context_field in $context_line; do
    case "$context_field" in
      u:object_r:*:s0|u:object_r:*:s0:*) printf '%s\n' "$context_field"; return 0 ;;
    esac
  done
  return 1
}
staged_target() {
  case "$1" in
    /vendor|/vendor/*)
      if [ -e "$MODPATH/system$1" ]; then staged_candidate="$MODPATH/system$1"
      else staged_candidate="$MODPATH$1"; fi ;;
    /system_ext|/system_ext/*)
      if [ -e "$MODPATH/system$1" ]; then staged_candidate="$MODPATH/system$1"
      else staged_candidate="$MODPATH$1"; fi ;;
    /odm|/odm/*) staged_candidate="$MODPATH/system$1" ;;
    *) return 1 ;;
  esac
  staged_real=$(readlink -f "$staged_candidate") || return 1
  module_real=$(readlink -f "$MODPATH") || return 1
  case "$staged_real" in
    "$module_real"/*) printf '%s\n' "$staged_real" ;;
    *) return 1 ;;
  esac
}
file_sha() {
  sha_line=$(sha256sum "$1" 2>/dev/null) || return 1
  printf '%s
' "${sha_line%% *}"
}
text_sha() {
  file_text=$(cat "$1") || return 1
  sha_line=$(printf '%s' "$file_text" | sha256sum) || return 1
  printf '%s
' "${sha_line%% *}"
}
check_build() {
  check_root="$1"
  FAIL_REASON=''
  [ "$(getprop ro.build.version.sdk)" = 37 ] || { FAIL_REASON='Expected system SDK 37.'; return 1; }
  [ "$(getprop ro.vndk.version)" = 31 ] || { FAIL_REASON='Expected vendor VNDK 31.'; return 1; }
  [ "$(file_sha "$check_root/odm/lib/libc++_shared.so")" = "$CPP_SHA" ] || {
    FAIL_REASON='The phone C++ runtime does not match the inspected build.'; return 1;
  }
  case "$(file_sha "$check_root/vendor/lib/hw/audio.primary.mt6893.so")" in
    "$HAL_ORIGINAL"|"$HAL_USB_FIXED") ;;
    *) FAIL_REASON='The primary audio HAL does not match the inspected build.'; return 1 ;;
  esac
  service_class=$(od -An -tu1 -j4 -N1 "$check_root/vendor/bin/hw/android.hardware.audio.service.mediatek" 2>/dev/null | tr -d ' 
')
  [ "$service_class" = 1 ] || { FAIL_REASON='Expected the 32-bit MediaTek audio service.'; return 1; }
  return 0
}
VENDOR_XML_ORIGINAL='dd7b4d8ea2c43012f23f12a1c16b135b16fdf4f54ce93dc01451aecbbb3c3dbe'
VENDOR_XML_MODULE='4720c8d47f10582a0ea6d3d187c728bd9ee087b184da2408c4be279a94968d98'
ODM_XML_ORIGINAL='a7b485c41ec5607d76750e967053176c7bce6726b38c6e05692b96b20d2218a0'
ODM_XML_MODULE='cc5ab88d3599fac555c6b68b9e05dc366b6ef5a7f4529bf54cc4c327f6943f56'
is_supported_policy() {
  case "$1" in
    /vendor/etc/audio_policy_configuration.xml|/vendor/etc/audio_policy_configuration_a2dp_offload_disabled.xml) return 0 ;;
    *) return 1 ;;
  esac
}

POLICY_EXTENSION='/system_ext/lib64/libaudiopolicyextimpl.so'
POLICY_EXTENSION_ORIGINAL='353066d5ff729e6e092b46a97e156aed10876322a5d0ed7b723b9bc301a6f389'
POLICY_EXTENSION_PATCHED='0539b48b43c6a5dcb292f82c1861bc9f191590d46e664a4eb3238d3f282f4114'

is_activation_library() { [ "$1" = "$POLICY_EXTENSION" ]; }
check_activation_framework() {
  activation_root="$1"
  case "$(file_sha "$activation_root$POLICY_EXTENSION")" in
    "$POLICY_EXTENSION_ORIGINAL"|"$POLICY_EXTENSION_PATCHED") ;;
    *) FAIL_REASON='The policy extension differs from the inspected phone build.'; return 1 ;;
  esac
  while read -r expected framework_path; do
    [ "$(file_sha "$activation_root$framework_path")" = "$expected" ] || {
      FAIL_REASON="Framework library differs from the inspected build: $framework_path"; return 1;
    }
  done < "$MODPATH/FRAMEWORK-GUARDS"
}

# Accept only the original profiles or the exact earlier experiments. Every
# successful installation stages the original 0.6 profiles from this payload.
check_tuning_upgrade() {
  while read -r original geometry radius target; do
    if [ ! -e "/proc/1/root$target" ] && [ ! -L "/proc/1/root$target" ]; then
      continue
    fi
    case "$(file_sha "/proc/1/root$target")" in
      "$original"|"$geometry"|"$radius") ;;
      *) FAIL_REASON="Unknown existing headphone tuning: $target"; return 1 ;;
    esac
  done < "$MODPATH/TUNING-GUARDS"
}
is_tuning_profile() {
  case "$1" in
    /odm/etc/spatializer/HP_MOVIE_ANALOG.bin|/odm/etc/spatializer/HP_MOVIE_BLUETOOTH.bin|/odm/etc/spatializer/HP_MOVIE_DIGITAL.bin|/odm/etc/spatializer/HP_MOVIE_GALILEO.bin|/odm/etc/spatializer/HP_MUSIC_ANALOG.bin|/odm/etc/spatializer/HP_MUSIC_BLUETOOTH.bin|/odm/etc/spatializer/HP_MUSIC_DIGITAL.bin|/odm/etc/spatializer/HP_MUSIC_GALILEO.bin) return 0 ;;
    *) return 1 ;;
  esac
}
