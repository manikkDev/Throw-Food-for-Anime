--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/foods.json (throw, land, accent)
-- Regenerate: python tools/gen_food_feel.py
-- How each food is thrown, the sound it lands with, its own colour (from its icon: tints its
-- trail and aroma), a Signature dish's landing accent.

export type Feel = { throw: string, land: string, color: string, accent: string? }

local FoodFeel: { [string]: Feel } = {
	boar_roast = { throw = "heave", land = "sizzle", color = "FF985A", accent = "quake" },
	captains_curry = { throw = "heave", land = "splash", color = "FF4227", accent = "spirit" },
	choco_robot = { throw = "pitch", land = "soft", color = "FF9F66" },
	clover_cake = { throw = "heave", land = "plate", color = "6CFF57" },
	cold_soba = { throw = "heave", land = "plate", color = "FF4126" },
	crab_hot_pot = { throw = "heave", land = "splash", color = "FF5F73", accent = "water" },
	cream_mochi = { throw = "pitch", land = "soft", color = "4FE9FF", accent = "magic" },
	crepe = { throw = "pitch", land = "soft", color = "FF9E63" },
	detective_cake = { throw = "heave", land = "plate", color = "FF5469", accent = "wind" },
	devil_ice_cream = { throw = "pitch", land = "soft", color = "FF6679", accent = "ice" },
	double_cherry = { throw = "pitch", land = "soft", color = "FF5E47" },
	elixir = { throw = "pitch", land = "glass", color = "7966FF", accent = "magic" },
	exam_sushi = { throw = "heave", land = "plate", color = "FF735F" },
	flame_bento = { throw = "heave", land = "plate", color = "FFE2A8", accent = "fire" },
	floor_boss_stew = { throw = "heave", land = "splash", color = "3D86FF", accent = "shatter" },
	flying_cabbage = { throw = "heave", land = "bowl", color = "FF9759" },
	god_pudding = { throw = "heave", land = "bowl", color = "FFC564" },
	healing_pasta = { throw = "heave", land = "plate", color = "FF8E4A", accent = "gold" },
	hermit_bean = { throw = "pitch", land = "soft", color = "FFC25D" },
	hero_banana = { throw = "spin", land = "soft", color = "E8FF48" },
	hero_katsudon = { throw = "heave", land = "bowl", color = "2CFF47" },
	hero_udon = { throw = "heave", land = "bowl", color = "FF7966" },
	hunter_burger = { throw = "pitch", land = "soft", color = "FF9A5D" },
	isekai_apple = { throw = "pitch", land = "soft", color = "FF7966" },
	jam_toast = { throw = "spin", land = "soft", color = "FF9F66" },
	kimbap = { throw = "heave", land = "plate", color = "FFE2A8" },
	kintsuba = { throw = "pitch", land = "soft", color = "FF9F66" },
	legend_ramen = { throw = "heave", land = "bowl", color = "FF7826", accent = "steam" },
	mapo_tofu = { throw = "heave", land = "sizzle", color = "FF8840", accent = "blast" },
	margherita = { throw = "spin", land = "plate", color = "FF9556" },
	meat_on_bone = { throw = "pitch", land = "soft", color = "FF7826" },
	meatball_pot = { throw = "heave", land = "splash", color = "FFE2A8" },
	officers_ham = { throw = "heave", land = "plate", color = "FF62EB", accent = "wind" },
	ohagi = { throw = "pitch", land = "soft", color = "FFE2A8" },
	onigiri = { throw = "pitch", land = "soft", color = "FFE2A8" },
	potato_chips = { throw = "pitch", land = "soft", color = "FF7826" },
	rank_one_steak = { throw = "heave", land = "sizzle", color = "FF985B", accent = "gold" },
	red_apple = { throw = "pitch", land = "soft", color = "FF6679" },
	rice_cakes = { throw = "heave", land = "bowl", color = "FFE2A8" },
	saiyan_feast = { throw = "heave", land = "plate", color = "FF9A5E", accent = "electric" },
	scout_bread = { throw = "pitch", land = "soft", color = "FFC25C" },
	sea_takoyaki = { throw = "heave", land = "plate", color = "FF985A" },
	sheep_feast = { throw = "heave", land = "plate", color = "FF8C47", accent = "wind" },
	soul_candy = { throw = "pitch", land = "soft", color = "68FF52" },
	steamed_potato = { throw = "pitch", land = "soft", color = "FFC666" },
	strawberry_daifuku = { throw = "pitch", land = "soft", color = "FFE2A8" },
	striker_gyoza = { throw = "heave", land = "plate", color = "FF985B" },
	swirl_fruit = { throw = "pitch", land = "soft", color = "9F66FF", accent = "dark" },
	tatoes = { throw = "heave", land = "soft", color = "E844FF" },
	tempura_bowl = { throw = "heave", land = "bowl", color = "FFB130" },
	tricolor_dango = { throw = "spin", land = "soft", color = "FF66C6" },
}

return FoodFeel
