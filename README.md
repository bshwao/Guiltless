# Guiltless

Phase 0: a Rojo project skeleton with a client/server RemoteEvent handshake on a baseplate. The scope follows [Project Guiltless](https://docs.google.com/document/d/1_N24lajNkNWsoCHNuVbE9u3gMLcZ_2SuMHXowHuV8EI/edit). See [ARCHITECTURE.md](ARCHITECTURE.md) for ownership and module layout.

## Setup

Git, Roblox Studio, VS Code, and [Rokit](https://github.com/rojo-rbx/rokit) must be installed. Work on the repository's `dev` branch. From this folder:

```powershell
rokit install
wally install
rojo plugin install
code .
```

Rokit pins Rojo, Wally, StyLua, Selene, and luau-lsp in `rokit.toml`. Accept Rokit's trust prompts for these tool publishers. Install the recommended VS Code extensions when prompted. Wally has no dependencies yet; plain modules are sufficient for Phase 0. Keep `wally.lock` in Git and keep installed package contents out of Git.

## Sync from VS Code

1. Run **Terminal → Run Task → Rojo: Build place** (or `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build.ps1`). This creates `build/Guiltless.rbxlx` and `sourcemap.json`.
2. Open `build/Guiltless.rbxlx` in Roblox Studio.
3. Run **Terminal → Run Task → Rojo: Serve** in VS Code.
4. In Studio's Rojo plugin, connect to `127.0.0.1:34872` and sync the project. Source edits in VS Code now sync into Studio. Stop Play before changing the DataModel layout.
5. Press **F5 / Play**. The HUD should read **Guiltless · Connected** and **Hello from the Guiltless server**. Studio Output should include `[Handshake] Server ready.`, `[Handshake] Replied to ...`, and the client's greeting.
6. Press **R** or click **Retry** to repeat the round trip. Stop the server handshake script and restart Play to verify that the HUD times out instead of claiming a connection.

For a terminal-driven sync server, use `rojo serve default.project.json`. It binds to loopback only. The project enables HttpService for the Rojo connection. Building and syncing are alternative ways to load the same tree; live sync requires the Rojo plugin connection.

## Checks

```powershell
stylua src scripts/StudioSmoke.luau
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Check.ps1
```

The check script runs format, Selene lint, sourcemap generation, and strict Luau analysis against Roblox API definitions. Selene's `roblox.yml` is committed to pin its standard library. The type checker caches the official luau-lsp Roblox definitions in `.tools`; its first run needs network access. Use `scripts/Check.ps1 -RefreshTypes` to update that cache. VS Code generates its own sourcemap and Roblox API types automatically.

For an actual local Studio server/client test on Windows, run the VS Code task **Studio: Test RemoteEvent**, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Smoke.ps1
```

The smoke test uses Studio's [documented command-line task](https://create.roblox.com/docs/studio/command-line-interface) and `StudioTestService` to launch one client. It verifies the production HUD reaches Connected, checks a second reply's nonce, and requires a server-confirmed result. Its test scripts exist only in the in-memory test place. Logs go under `build/`. Studio may update itself on launch; if that interrupts the test, wait for the update and rerun. This checks runtime communication; connecting the Rojo plugin remains the live sync step above.

Build outputs, API caches, and installed packages are ignored. Shared definitions, types, and utilities live under `src/shared`; server services under `src/server/services`; client controllers and UI under `src/client`. There are no gameplay frameworks or combat/story systems in this phase.
