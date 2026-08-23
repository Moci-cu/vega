# Vega Network Helper

Small on-demand Qt 6 helper for Vega's native Wi-Fi settings page. It talks
directly to NetworkManager over the system D-Bus and exposes a line-delimited
JSON protocol on stdin/stdout.

## Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build --prefix "$HOME/.local"
```

Required build components are Qt 6 Core, DBus, and Network. No npm packages or
background daemon are used.

## Protocol

One request and response per line:

```json
{"id":"1","method":"health","params":{}}
{"id":"1","ok":true,"result":{"available":true,"backend":"NetworkManager D-Bus"}}
```

Supported methods are `health`, `list_profiles`, `create_profile`,
`update_profile`, `delete_profile`, and `activate_profile`. The helper may emit
`{"event":"profiles_changed"}` when NetworkManager reports profile or active
connection changes.

Passwords are accepted only in create/update request bodies. The helper never
calls `GetSecrets`, prints request bodies, or returns a password.
