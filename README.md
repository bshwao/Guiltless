# Crownless

Crownless is a grounded medieval-fantasy Roblox MMO prototype. This Rojo project contains the shared Greyfen hub, its first mine and vault blockout, four furnished buildings, starter dialogue, role kits, and a custom four-role party finder.

## Open in Roblox Studio

1. Open this project folder in VS Code.
2. Install Rojo 7 (`aftman install` is configured here) and the Rojo Studio plugin.
3. Sync the complete `default.project.json` tree. It includes an R6 `StarterCharacter`, compatible avatar cosmetics, and procedural movement/combat animation scripts. R6 is enforced by this source character.
4. Use **Terminal → Run Task → Rojo: Build place file** to create `build/Crownless.rbxlx`, or start **Rojo: Serve** and connect the Studio plugin to `localhost:34872`.
5. Press **Play**. NPC rigs, dialogue prompts, player armor and weapons, the action bar, chat, music, and UI are created by the runtime scripts.

`src/world/CrownlessWorld.model.json` is the editable, static map model. The source currently generates 1,411 map pieces. Open `build/Crownless.rbxlx` for the updated place. `Crownless.rbxl` is an earlier place snapshot; sync/build the project source to load these updates.

**Build note:** Rojo 7.7.1 successfully builds this project. If the global `rojo` shim reports `ERROR home directory not found`, use the installed executable at `%USERPROFILE%\.rokit\tool-storage\rojo-rbx\rojo\7.7.1\rojo.exe` to run the same build or serve command.

## Greyfen

- A continuous stone town wall with a single eastern mine gate, an arrival marker, market square, well, southern bridge, and accessible streets.
- A Wayfarers' Board beside the Guild Hall rather than at the well; its **E** prompt opens the four-role group finder.
- The Guild Hall, Ironwold Inn, Marr's Forge, and Bitterleaf Apothecary have raised floors, entry steps, tables, benches, counters, shelves, jars, a hearth, and forge props.
- Overlapping wall ends and timber corner posts close house seams. Walkable meadow edges, low rolling rises, expanded tree lines, a fallow croft, a broken watch-post, and an abandoned border tollhouse build out the surroundings.
- Tamsin, Hedd, Marr, and Nera are generated from Roblox `HumanoidDescription` avatars as R6 character models, with classic hair accessories, dialogue prompts, and nameplates. Three R6 wooden practice dummies stand outside the southern wall. Their health bars drop when hit, and defeated dummies are replaced after two seconds.
- The east road leads into the Plague Mine drift and a two-phase collapsed-vault boss-room blockout.

## Roles, equipment, and abilities

A party has exactly four roles: **Tank, Healer, Damage, Controller**. The Gear menu lets you equip and unequip your role's weapon and armor, with live item previews. Weapons are real Roblox Tools cloned from `assets/equipment/weapons`; armor and the Tank's shield also have source models under `assets/equipment`. The four exported starter weapons are available as Rojo-ready native-part Tools: Iron Mace, Acolyte Scepter, Iron Sword, and Apprentice Staff. See `assets/equipment/README.md` for editing them or using the original high-detail FBX meshes.

The action bar offers four role abilities; the server validates the held weapon, role, aim direction, target distance, line of sight, cooldown, damage, healing, interrupt, and threat effects. Attacks and spells animate and spend their cooldown even when they miss. Use the practice yard to try damage abilities.

Dungeon enemy spawning, the vault boss encounter, repairs, item durability, corpse recovery, crafting, auction house, and persistent equipment progression still need production implementation. Player data currently keeps its Studio mock profile enabled by default.

## HUD and controls

- **G** or **PARTY** — four-role group finder.
- **I** or **GEAR** — select a role, preview its items, and equip/unequip its weapon or armor.
- **Left click / 4** — basic weapon attack or the Controller's Thorn Bolt, aimed at the mouse pointer.
- **1–3** — use the current role's other abilities.
- **Right mouse drag / mouse wheel** — rotate / zoom the third-person camera. The camera stays outside the player body; the mouse is freely available for the UI.
- **M** or **MAP** — Greyfen map card.
- **O** or **SETTINGS** — music volume, UI scale, and Roblox top-bar visibility.
- **/** or **CHAT** — open the custom panel for Roblox filtered text chat.
- **E** — speak to an NPC or open an interactable board.
- R6 idle, walking/running, jumping, falling, climbing, swimming, and sitting poses blend into attack, spell, shout, and guard animations.
- Your avatar portrait, Roblox display name, saved character level, and XP appear in the header.
- Confirmed damage numbers and rolling DPS float at the hit location. Only health actually removed by the server is counted.

The game hides Roblox's top bar on startup to prevent it covering the HUD. Roblox's `TopbarEnabled` switch also hides Roblox's built-in chat, player list, and backpack. Crownless replaces those entry points with custom chat, party, map, armory, and action-bar UI; **Settings → Roblox top bar** restores the platform bar if desired.

Background music uses [**Medieval Market D**](https://create.roblox.com/store/asset/1847223666/Medieval-Market-d-OL) from the Roblox Creator Store (asset `1847223666`). Players can mute it or adjust volume in **Settings**. Creator Store audio is subject to Roblox asset permissions and availability.

## Regenerate the map and preview

From the project directory:

```powershell
python tools/generate_world.py
python tools/render_world_overview.py
```

The Luau language server uses `sourcemap.json`, generated by the **Luau: Generate Rojo sourcemap** VS Code task. This lets `require(ReplicatedStorage.Shared...)` paths resolve in VS Code.

Before publishing, set the hub Max Players to 40, set `DungeonPlaceId` in `src/shared/GameConfig.lua`, confirm the music asset is usable by this experience, and enable production DataStore settings. Reserved-server launch, guilds, cross-server economy, and audit/rollback tooling are not complete.
