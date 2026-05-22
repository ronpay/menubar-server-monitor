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

## Release

Push a `v*` tag to trigger the `Release` workflow, which builds a `.app`, packages a DMG, and publishes a GitHub release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The DMG is ad-hoc signed (not notarized), so first launch requires right-click → Open.

