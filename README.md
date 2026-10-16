# Project Zomboid Tree Room Fix

Client-side workaround for the `IsoTree.isPlayerInsideARoom()` null-room exception in Project Zomboid 42.21.0. This error can interrupt world rendering when zooming out inside a player-built room.

`isInARoom()` can return true for a player room region even when `getRoom()` returns null. This patch preserves the existing room-boundary calculation when a room exists. Otherwise it uses the game's existing 24-tile camera-distance check. It does not repair room metadata or change save data.

## Install

Download or clone this repository, close the game, and run `Install.cmd`. Keep all files together. The default location is `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid`. Run `Status.cmd` to verify installation. For another location:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Manage-TreeFix.ps1 -Action Install -GameDir "D:\SteamLibrary\steamapps\common\ProjectZomboid"
```

No server-side installation is required. Acceptance by every server or compatibility with other Java transformers is not guaranteed.

## Remove and update

Close the game and run `Remove.cmd` **before updating Project Zomboid**. Steam file verification may leave the added class override in place. The installer refuses unknown original class hashes and existing overrides. Status checks are manual, not automatic at game launch.

The original game archive is never modified. Only `zombie/iso/objects/IsoTree.class` and `.tree-room-null-fix/state.json` are installed. Removal checks the installed class hash before deleting it.

## Validation

Nine cases execute the actual game room/distance method bytecode with isolated dependencies: outdoor behavior, normal room bounds and missing-room distance boundaries. The original method reproduces the exception; the patched method passes with JVM verification enabled. Installation, rollback, incompatible input rejection and preservation of another patch were tested in a temporary directory.

On 2026-10-16, the user reported that the zoom issue was resolved in their multiplayer client. This is one live configuration, not coverage of every server or mod combination.

## Source and dependencies

`src/TreePatcher.java` is the patch generator. `tests/` contains the isolated behavior harness. `patcher.jar` is built from this source; ASM 9.8 dependencies and their BSD license are in `lib/`. No game class files, game archive, logs, saves, or credentials are distributed.

Build and test with a JDK 17+ compiler and the game's Java 25 runtime using `Build-Test.ps1`. The game archive is read locally and never bundled.
