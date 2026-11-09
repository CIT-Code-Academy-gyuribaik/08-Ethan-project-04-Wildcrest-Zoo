-- Items you can buy in the lobby. "slot" items are cosmetics you equip one of.
return {
	{ id = "flash1", name = "Brighter Flashlight", price = 150, kind = "Flashlight", desc = "A stronger bulb. Lights up more of the dark." },
	{ id = "flash2", name = "Long-Range Flashlight", price = 400, kind = "Flashlight", requires = "flash1", desc = "See monsters before they see you." },
	{ id = "beam_ice", name = "Ice-Blue Beam", price = 100, kind = "Flashlight Skin", slot = "flashSkin", value = "ice", desc = "A cold blue flashlight beam." },
	{ id = "beam_uv", name = "UV Beam", price = 150, kind = "Flashlight Skin", slot = "flashSkin", value = "uv", desc = "An eerie purple glow." },
	{ id = "beam_red", name = "Red Beam", price = 150, kind = "Flashlight Skin", slot = "flashSkin", value = "red", desc = "Like an emergency light." },
	{ id = "skin_agent", name = "SWAT Agent Outfit", price = 250, kind = "Outfit", slot = "skin", value = "agent", desc = "Blend in with Wildcrest's guards." },
	{ id = "skin_director", name = "Director's Suit", price = 300, kind = "Outfit", slot = "skin", value = "director", desc = "Dress like Marsh himself." },
	{ id = "skin_guest", name = "Lost Guest Outfit", price = 350, kind = "Outfit", slot = "skin", value = "guest", desc = "The clothes of a tour guest who never came back..." },
	{ id = "sprinter", name = "Sprinter", price = 300, kind = "Skill", desc = "Your stamina drains 30% slower." },
	{ id = "silent", name = "Silent Steps", price = 400, kind = "Skill", desc = "Monsters hear your footsteps 35% less." },
	{ id = "sixth", name = "Sixth Sense", price = 500, kind = "Skill", desc = "Press R to see monsters through walls for 4 seconds." },
	{ id = "stun", name = "Stun Battery", price = 250, kind = "Skill", desc = "+2 stun gun charges every chapter." },
	{ id = "lifepack", name = "Spare Life", price = 75, kind = "Consumable", consumable = true, max = 5, desc = "+1 life on your NEXT run only (used up). Hold up to 5." },
	{ id = "life", name = "Extra Life", price = 600, kind = "Skill", desc = "+1 life in every chapter." },
}
