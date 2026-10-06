# Crownless starter weapons

| Class | Weapon | Evaluated triangles |
|---|---|---:|
| Tank | Iron Mace | 908 |
| Mage / Controller | Apprentice Staff | 624 |
| Healer | Acolyte Scepter | 712 |
| DPS | Iron Sword | 638 |

The Blender file contains the four editable weapons arranged for inspection, a presentation camera, and studio lights. The previous Oathbreaker sword is preserved in a hidden collection and in its original saved file. The Iron Sword refines its ridged blade and wrapped grip with simpler iron fittings and a plain pommel.

Each weapon has an individual FBX and GLB export. These exports contain the weapon meshes and their parent root; they omit presentation lights, cameras, and labels. The export root is at the center of the grip. In Blender coordinates, the weapon length points along +Z; the exports use their format's axis conversion.

Materials use solid colors; no external textures are required. Game-engine material appearance and final character scale need to be checked after import. These exports are visual mesh sources. Ready-to-equip Roblox Tool versions, role equipment UI, combat integration, and armor models are now in `assets/equipment`; see its `README.md` for setup and mesh replacement instructions.
