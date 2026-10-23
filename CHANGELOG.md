# Changelog

## 1.0.0 — 2026-10-23

- Select the original v0.6 tuning; discard the angle/radius experiments.
- Adopt the public name MT6893 Spatial Audio and ID mt6893-spatial-audio; remove the old development module and reboot before migration.
- Keep exact previous profile hashes for conflict verification.
- Keep the phone-tested activation, renderer, routing, labels and stereo support.
- Package source, portable build/verification tools, provenance and device notes.
- Move optional diagnostics and reproduction inputs out of the flashable module.
- Retain source/ownership notices and required installer/runtime checks.

## Earlier development

- **0.8.1:** fix the channel-test check when `customize.sh` is removed after install.
- **0.8:** compare doubled radii; listener preferred the original v0.6 tuning.
- **0.7:** prepare angle-only changes; this build was not phone-tested.
- **0.6:** repair the inspected wired/USB Settings activation gate; USB stereo song
  processing confirmed on the phone.
- **0.5:** correct configuration labels and retain complete routing policies.
- Earlier iterations established loading, initialization, capabilities, private
  support-library identity and effect registration.

These entries summarize recorded iterations. They are not imported Git commits.
