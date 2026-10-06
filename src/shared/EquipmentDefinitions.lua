-- Starter items are available to their role. Future owned loot belongs in the
-- server inventory; never accept a client-supplied model or stat value.
export type Item = {
	Id: string, Name: string, Role: string, Slot: string, Asset: string,
	Description: string, ArmorRating: number?, Offhand: string?,
}

local items: {[string]: Item} = {
	iron_mace = { Id = "iron_mace", Name = "Iron Mace", Role = "Tank", Slot = "Weapon", Asset = "IronMace", Offhand = "WardenShield", Description = "A flanged iron mace and warden's shield. Hold the line." },
	acolyte_scepter = { Id = "acolyte_scepter", Name = "Acolyte Scepter", Role = "Healer", Slot = "Weapon", Asset = "AcolyteScepter", Description = "A brass halo and restoration stone for the field medic." },
	iron_sword = { Id = "iron_sword", Name = "Iron Sword", Role = "Damage", Slot = "Weapon", Asset = "IronSword", Description = "A ridged iron blade with a leather grip. Strike hard." },
	apprentice_staff = { Id = "apprentice_staff", Name = "Apprentice Staff", Role = "Controller", Slot = "Weapon", Asset = "ApprenticeStaff", Description = "Crooked ash and a blue focus crystal. Restrain and interrupt." },
	march_warden_plate = { Id = "march_warden_plate", Name = "March-Warden Plate", Role = "Tank", Slot = "Armor", Asset = "MarchWardenPlate", ArmorRating = 24, Description = "Heavy plate, a leather belt, and reinforced shoulder guards." },
	field_medic_leathers = { Id = "field_medic_leathers", Name = "Field Medic's Leathers", Role = "Healer", Slot = "Armor", Asset = "FieldMedicLeathers", ArmorRating = 12, Description = "Light armor for a healer travelling with the party." },
	roadworn_brigandine = { Id = "roadworn_brigandine", Name = "Roadworn Brigandine", Role = "Damage", Slot = "Armor", Asset = "RoadwornBrigandine", ArmorRating = 15, Description = "Road-tested protection for the front of an exchange." },
	march_surveyor_coat = { Id = "march_surveyor_coat", Name = "March-Surveyor's Coat", Role = "Controller", Slot = "Armor", Asset = "MarchSurveyorCoat", ArmorRating = 13, Description = "A reinforced field coat for the march's surveyors." },
}

return {
	Items = items,
	Slots = { "Weapon", "Armor" },
	RoleItems = {
		Tank = { Weapon = "iron_mace", Armor = "march_warden_plate" },
		Healer = { Weapon = "acolyte_scepter", Armor = "field_medic_leathers" },
		Damage = { Weapon = "iron_sword", Armor = "roadworn_brigandine" },
		Controller = { Weapon = "apprentice_staff", Armor = "march_surveyor_coat" },
	},
}
