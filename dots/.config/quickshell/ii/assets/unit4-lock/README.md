# Unit-4 lock screen assets

Videos copied from `/home/mocicu/unit-4/quickshell/videos`, with the Unit-4
MIT license included here. Reveal: 1 s; hide: 1.2 s; H.264, 1920x1080.
The original files and cadence are kept so Vega matches Unit-4's motion.
Vega plays the precomputed assets, so no C++ generator or continuous wave
simulation is needed at runtime. The reveal holds its last frame at rest.

Select **Settings > Interface > Lock screen > Unit-4** (ii panel family).
Vega remains the default. Changes apply to the next lock session.
The port uses Vega's WlSessionLock and shared LockContext/PAM, not the original
Unit-4 PanelWindow overlay. Exit playback never authorizes unlock; it only
delays an already authenticated unlock, with a bounded 0.85 s timeout even if
video playback fails. Missing media leaves the password UI usable.

The palette, pixel wave, grid, diamond avatar, sliding panel and wipe are
adapted from Unit-4. Hardware/location labels are not copied as system facts.
Ndot 57 is used when installed, otherwise the configured monospace font.
