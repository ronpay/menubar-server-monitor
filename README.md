# menubar-server-monitor

A small macOS menu bar app for keeping an eye on your servers.

Requires macOS 14+ and Swift 5.9.

## Build

Release build as a `.app` bundle:

```sh
./scripts/build-app.sh
```

Debug build:

```sh
./scripts/build-app.sh debug
```

The bundle is written to `build/ServerMonitor.app`. Launch it with:

```sh
open build/ServerMonitor.app
```

