local Theme = {}

Theme.Colors = {
	orange = Color3.fromRGB(255, 136, 24),
	orangeLight = Color3.fromRGB(255, 184, 90),
	orangeDark = Color3.fromRGB(216, 86, 0),
	charcoal = Color3.fromRGB(20, 20, 20),
	charcoalLight = Color3.fromRGB(38, 38, 38),
	white = Color3.fromRGB(255, 255, 255),
	offWhite = Color3.fromRGB(236, 242, 250),
	black = Color3.fromRGB(0, 0, 0),
}

Theme.TabThemeByName = {
	PLAY = {
		base = Color3.fromRGB(255, 146, 36),
		light = Color3.fromRGB(255, 190, 102),
		dark = Color3.fromRGB(222, 90, 0),
	},
	TRAIN = {
		base = Color3.fromRGB(255, 132, 14),
		light = Color3.fromRGB(255, 176, 84),
		dark = Color3.fromRGB(210, 80, 0),
	},
	REPLAY = {
		base = Color3.fromRGB(244, 248, 255),
		light = Color3.fromRGB(255, 255, 255),
		dark = Color3.fromRGB(255, 206, 143),
		text = Theme.Colors.black,
		stroke = Theme.Colors.orangeDark,
		accent = Theme.Colors.orange,
	},
	TUTORIALS = {
		base = Color3.fromRGB(244, 248, 255),
		light = Color3.fromRGB(255, 255, 255),
		dark = Color3.fromRGB(255, 206, 143),
		text = Theme.Colors.black,
		stroke = Theme.Colors.orangeDark,
		accent = Theme.Colors.orange,
	},
	PARTY = {
		base = Color3.fromRGB(247, 136, 20),
		light = Color3.fromRGB(255, 182, 88),
		dark = Color3.fromRGB(202, 84, 0),
	},
}

return Theme
