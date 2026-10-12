# Phase 0 architecture

This is the project skeleton described in [Project Guiltless](https://docs.google.com/document/d/1_N24lajNkNWsoCHNuVbE9u3gMLcZ_2SuMHXowHuV8EI/edit). It uses plain modules and an empty baseplate. Combat begins in Phase 1.

| Source | Roblox location | Responsibility |
| --- | --- | --- |
| `src/shared/defs` | `ReplicatedStorage.Shared.defs` | Frozen definitions and protocol constants |
| `src/shared/types` | `ReplicatedStorage.Shared.types` | Exported Luau types |
| `src/shared/utils` | `ReplicatedStorage.Shared.utils` | Small shared utilities and boundary validation |
| `src/server/services` | `ServerScriptService.Server.services` | Server authority and service lifecycles |
| `src/client/controllers` | `StarterPlayerScripts.Client.controllers` | Client input and network handling |
| `src/client/UI` | `StarterPlayerScripts.Client.UI` | Local presentation |
| `Packages` | `ReplicatedStorage.Packages` | Wally shared packages |
| `ServerPackages` | `ServerStorage.ServerPackages` | Wally server packages |

Bootstrap scripts start their modules explicitly. Services and controllers return cleanup functions. There is no framework, global service locator, or automatic module loader.

Every shared module starts with `--!strict`; Phase 0 uses it on client and server code too. Keep external payloads typed as `unknown` until validation has rebuilt them into a known shape. Never trust a client-supplied Player identity or authoritative gameplay value.

## Handshake

Rojo creates `ReplicatedStorage.Remotes.Handshake` as a `RemoteEvent`. The client connects `OnClientEvent`, generates a nonce, and sends `{ version, nonce }`. The server validates the protocol and nonce, enforces a per-player one-second interval, and sends `{ version, nonce, message }` with `FireClient`. The controller validates the reply and matches its outstanding nonce before displaying **Connected**. A five-second timeout offers retry; `R` and the HUD button send another request. Disconnecting a player clears server bookkeeping.

The protocol constants in `src/shared/defs/Network.luau` are public contract data. Future services should keep decisions, resources, and persistent data on the server. Add features one service/controller at a time and keep damage math separate and pure when Phase 1 begins.
