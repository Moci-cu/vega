SVG frames and physical-hand mapping from https://github.com/saatvik333/wayland-bongocat
(MIT, Saatvik Sharma), revision `9cd36c6b79d9271810054fb4e99793934bbae98b`.
The viewBox is cropped to shared cat bounds. Empty paths, transparent editor
rectangles (Qt renders their rgba fill as black), and embedded reference PNGs
are removed so all animation frames are transparent vectors.

The QML widget is available as **Bongo Cat** in Settings > Bar layout.
One shared, unprivileged Python standard-library helper reads keyboard evdev devices.
It emits only paw bits, never keycodes/text, and does not grab devices or write logs.
It stops when no widget is visible or the shell is locked, and rescans for hotplug
every five seconds. Device access must already be granted by the system.

Check input decoding without accessing keyboards:
`python3 scripts/bongocat-input.py --self-test`
