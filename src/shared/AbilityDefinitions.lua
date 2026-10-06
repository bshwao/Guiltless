-- Four readable starter abilities per role. All effects are resolved on the server.
return {
	DefaultRole = "Damage",
	Roles = {
		Tank = {
			Weapon = "Iron Mace",
			Armor = "March-Warden Plate",
			ArmorRating = 24,
			Tint = Color3.fromRGB(105, 119, 127),
			Abilities = {
				{ Id = "shield_bash", Key = "1", Name = "Shield Bash", Description = "Strike and briefly stun a nearby foe.", Cooldown = 6, Kind = "damage", Range = 11, Damage = 15, Stun = 1.2 },
				{ Id = "taunt", Key = "2", Name = "Call the Line", Description = "Force a nearby enemy to face you.", Cooldown = 12, Kind = "taunt", Range = 18, Duration = 5 },
				{ Id = "brace", Key = "3", Name = "Brace", Description = "Brace against the next exchange.", Cooldown = 14, Kind = "guard", Duration = 5 },
				{ Id = "guard_cut", Key = "4", Name = "Mace Strike", Description = "A slow, heavy mace blow.", Cooldown = 1.2, AnimationDuration = 0.7, Kind = "damage", Range = 12, Damage = 24 },
			},
		},
		Healer = {
			Weapon = "Acolyte Scepter",
			Armor = "Field Medic's Leathers",
			ArmorRating = 12,
			Tint = Color3.fromRGB(107, 135, 95),
			Abilities = {
				{ Id = "mend", Key = "1", Name = "Mend", Description = "Restore health to the most wounded ally nearby.", Cooldown = 5, Kind = "heal", Range = 55, Healing = 32, Visual = "pulse" },
				{ Id = "cinderbolt", Key = "2", Name = "Cinderbolt", Description = "A small, focused spell against one nearby foe.", Cooldown = 5, Kind = "damage", Range = 28, Damage = 12, Visual = "bolt" },
				{ Id = "renewing_word", Key = "3", Name = "Renewing Word", Description = "Restore a little health to your nearby party.", Cooldown = 14, Kind = "group_heal", Range = 35, Healing = 18, Visual = "pulse" },
				{ Id = "staff_strike", Key = "4", Name = "Staff Strike", Description = "A close-range staff blow.", Cooldown = 3, Kind = "damage", Range = 10, Damage = 8 },
			},
		},
		Damage = {
			Weapon = "Iron Sword",
			Armor = "Roadworn Brigandine",
			ArmorRating = 15,
			Tint = Color3.fromRGB(153, 84, 61),
			Abilities = {
				{ Id = "heavy_cut", Key = "1", Name = "Heavy Cut", Description = "A committed strike against one nearby foe.", Cooldown = 5, Kind = "damage", Range = 12, Damage = 24 },
				{ Id = "sweeping_edge", Key = "2", Name = "Sweeping Edge", Description = "A broad blow that can catch several foes.", Cooldown = 9, Kind = "area_damage", Range = 12, Damage = 13 },
				{ Id = "rend", Key = "3", Name = "Rend", Description = "Wound a nearby foe and interrupt its action.", Cooldown = 12, Kind = "damage", Range = 13, Damage = 16, Interrupt = 2 },
				{ Id = "quick_strike", Key = "4", Name = "Quick Strike", Description = "A fast, light sword strike.", Cooldown = 0.3, AnimationDuration = 0.28, Kind = "damage", Range = 11, Damage = 9 },
			},
		},
		Controller = {
			Weapon = "Apprentice Staff",
			Armor = "March-Surveyor's Coat",
			ArmorRating = 13,
			Tint = Color3.fromRGB(124, 105, 151),
			Abilities = {
				{ Id = "interrupt", Key = "1", Name = "Break the Chant", Description = "Deal light damage and interrupt a nearby foe.", Cooldown = 8, Kind = "damage", Range = 24, Damage = 8, Interrupt = 3, Visual = "bolt" },
				{ Id = "snare", Key = "2", Name = "Snare", Description = "Root a nearby foe briefly.", Cooldown = 10, Kind = "control", Range = 22, Duration = 3, Visual = "bolt" },
				{ Id = "sleep", Key = "3", Name = "Dull the Senses", Description = "Stun a nearby foe briefly.", Cooldown = 15, Kind = "control", Range = 18, Duration = 2.4, Visual = "bolt" },
				{ Id = "thorn_bolt", Key = "4", Name = "Thorn Bolt", Description = "Send a rough, low-magic bolt at one foe.", Cooldown = 3, Kind = "damage", Range = 28, Damage = 10, Visual = "bolt" },
			},
		},
	},
}
