# Crownless equipment assets

These are the source assets used by the game. Rojo maps the three folders below
into `ReplicatedStorage.Assets`; the original Blender/FBX/GLB files stay in
`assets/starter-weapons`.

| Role | Weapon Tool | Armor model |
| --- | --- | --- |
| Tank | `weapons/IronMace.rbxmx` | `armor/MarchWardenPlate.rbxmx` |
| Healer | `weapons/AcolyteScepter.rbxmx` | `armor/FieldMedicLeathers.rbxmx` |
| Damage | `weapons/IronSword.rbxmx` | `armor/RoadwornBrigandine.rbxmx` |
| Controller | `weapons/ApprenticeStaff.rbxmx` | `armor/MarchSurveyorCoat.rbxmx` |

The Tank's shield is `offhands/WardenShield.rbxmx`. It attaches to the left arm
while the Iron Mace is equipped.

## Use in the game

Sync the complete project, then press **I** or **Gear**. Choose a role and use
the **Equip / Unequip** buttons. Starter items initially equip automatically.
Close Gear to attack with **left click / 4**, or use abilities **1–3**. A held
weapon is required for abilities. Armor grants protection only while worn.
An existing party keeps its assigned combat role; selecting another role changes
the preference for the next party.

The server clones only the current role's Tool into the player's Backpack, uses
`Humanoid:EquipTool()` / `UnequipTools()`, checks every equipment request against
`src/shared/EquipmentDefinitions.lua`, and checks the held Tool before resolving
combat. These starter item choices last for the current server session.

## Edit the source models

The weapon Tools contain a direct child `Handle`, with all visible parts welded
to that Handle. They use Roblox cylinders and wedge geometry derived from the
starter GLBs, keeping their shapes and colors while simplifying small bevels.
They work immediately without uploaded mesh asset IDs. Regenerate them with:

```powershell
python tools/generate_equipment.py
```

To use the original high-detail meshes, import the matching FBX in Studio,
replace the Tool's visible parts with the imported MeshParts, and weld those
MeshParts to its existing Handle. Keep the Handle, Tool name/path, and unanchored,
non-colliding, massless parts. Adjust the Tool's `Grip` if needed. Save the whole
Tool as an `.rbxmx` file over its matching file in `assets/equipment/weapons`.
The imported meshes need valid Roblox asset IDs and experience permissions.
Regenerating the assets overwrites manual model edits.

Armor parts use positions relative to the R6 torso. Shield parts use positions
relative to the left arm. The equipment service creates their body welds at
runtime. Add future item definitions in `EquipmentDefinitions.lua` and source
assets in the matching folder; starter access is currently limited by role.
