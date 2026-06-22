local ShopConfig = {}

ShopConfig.Shops = {
	["EggShop"] = {
		ShopName = "Egg Shop",
		
		-- UI Customization
		Theme = {
			BackgroundColor = Color3.fromRGB(25, 30, 45),
			HeaderColor = Color3.fromRGB(35, 45, 70),
			AccentColor = Color3.fromRGB(80, 150, 255),
			TextColor = Color3.fromRGB(255, 255, 255),
			ButtonColor = Color3.fromRGB(45, 180, 100),
			ButtonHoverColor = Color3.fromRGB(60, 210, 120),
			Font = Enum.Font.GothamBold,
			CornerRadius = UDim.new(0, 12),
		},
		Range = 25,
	},
	["NoobShop"] = {
		ShopName = "Noob Shop",
		ShopType = "Equipment",
		Range = 25,
		
		-- UI Customization
		Theme = {
			BackgroundColor = Color3.fromRGB(25, 30, 45),
			HeaderColor = Color3.fromRGB(35, 45, 70),
			AccentColor = Color3.fromRGB(80, 150, 255),
			TextColor = Color3.fromRGB(255, 255, 255),
			ButtonColor = Color3.fromRGB(45, 180, 100),
			ButtonHoverColor = Color3.fromRGB(60, 210, 120),
			Font = Enum.Font.GothamBold,
			CornerRadius = UDim.new(0, 12),
		}
	},
	["ArtifactShop1"] = {
		ShopName = "Artifact Shop",
		ShopType = "Equipment",
		
		-- UI Customization
		Theme = {
			BackgroundColor = Color3.fromRGB(25, 30, 45),
			HeaderColor = Color3.fromRGB(35, 45, 70),
			AccentColor = Color3.fromRGB(80, 150, 255),
			TextColor = Color3.fromRGB(255, 255, 255),
			ButtonColor = Color3.fromRGB(45, 180, 100),
			ButtonHoverColor = Color3.fromRGB(60, 210, 120),
			Font = Enum.Font.GothamBold,
			CornerRadius = UDim.new(0, 12),
		},
		Range = 25,
	},
	["RunicShop"] = {
		ShopName = "Runic Shop",
		ShopType = "Equipment",
		RequiredFish = 5,
		Range = 25,

		-- UI Customization
		Theme = {
			BackgroundColor = Color3.fromRGB(10, 22, 14),
			HeaderColor = Color3.fromRGB(15, 40, 22),
			AccentColor = Color3.fromRGB(50, 200, 90),
			TextColor = Color3.fromRGB(180, 255, 200),
			ButtonColor = Color3.fromRGB(25, 120, 55),
			ButtonHoverColor = Color3.fromRGB(35, 160, 75),
			Font = Enum.Font.GothamBold,
			CornerRadius = UDim.new(0, 12),
		},
	},
	["ZooplanktonMachine"] = {
		ShopName = "Zooplankton Machine",
		Range = 25,
		Theme = {
			BackgroundColor = Color3.fromRGB(20, 40, 50),
			HeaderColor = Color3.fromRGB(30, 55, 70),
			AccentColor = Color3.fromRGB(0, 200, 255),
			TextColor = Color3.fromRGB(200, 255, 255),
			ButtonColor = Color3.fromRGB(0, 150, 200),
			ButtonHoverColor = Color3.fromRGB(0, 180, 240),
			Font = Enum.Font.GothamBold,
			CornerRadius = UDim.new(0, 12),
		}
	},
}

return ShopConfig
