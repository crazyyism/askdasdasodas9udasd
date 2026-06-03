
local function generateQuests()
    local qChain = {
        "TinkerersTrial", "AbyssalAscent", "MagneticWaters", "ExplosiveYields", "GoldenGathering",
        "BiomassBaseline", "RefinedPalette", "TokenHoarder", "SpeedTest", "CrystalCraze",
        "DiamondDepths", "PeakPerformance", "ObsidianObliteration", "CorallineCrush", "OceanicOverlord"
    }
    
    local qData = {
        TinkerersTrial = {
            Goals = {["Freshwater Reef"]=250000, ["Coral Reef"]=250000, ["EquipmentsPurchased"]=3},
            Rewards = {BiomassAmount=500000, Items={["Pearl"]=25}},
            Dialog = {"You rely on raw strength too much. Let us refine your setup.", "Purchase 3 new equipments, and gather 250,000 from the starter reefs."}
        },
        AbyssalAscent = {
            Goals = {["Trash Reef"]=1000000, ["Obsidian Reef"]=500000},
            Rewards = {BiomassAmount=1500000, Items={["Zooplankton"]=15}},
            Dialog = {"We must plunge into the darkest waters.", "Gather from the Trash and Obsidian Reefs. Show me you are not afraid of the dark!"}
        },
        MagneticWaters = {
            Goals = {["Runic Reef"]=2500000, ["AbilitiesCommitted"]=1500},
            Rewards = {BiomassAmount=3500000, Items={["Sea Mine"]=10}},
            Dialog = {"The magic in the Runic Reef is unstable. We need to absorb it.", "Commit 1,500 abilities and pull 2,500,000 algae from those magnetic currents."}
        },
        ExplosiveYields = {
            Goals = {["Sun Reef"]=5000000, ["SeaMinesPopped"]=15},
            Rewards = {BiomassAmount=8000000, Items={["Pearl"]=50}},
            Dialog = {"We need a massive burst of energy. Time to use your explosive arsenal.", "Pop 15 Sea Mines and gather loudly at the Sun Reef!"}
        },
        GoldenGathering = {
            Goals = {["Coral Reef"]=15000000, ["Freshwater Reef"]=10000000},
            Rewards = {BiomassAmount=25000000, Items={["Golden Egg"]=1}},
            Dialog = {"You have proven quite capable. It is time for a golden milestone.", "Gather a massive 25,000,000 total across the softest reefs. I have a very special reward waiting."}
        },
        BiomassBaseline = {
            Goals = {["BiomassTokensGathered"]=250, ["TokensGathered"]=1000, ["Trash Reef"]=35000000},
            Rewards = {BiomassAmount=50000000, Items={["Pearl"]=100}},
            Dialog = {"We cannot forget the foundation of all marine life.", "Focus on gathering Biomass tokens. Pick up 250 of them, and 1,000 tokens overall."}
        },
        RefinedPalette = {
            Goals = {["Coralline Reef"]=75000000, ["Crystal Reef"]=25000000},
            Rewards = {BiomassAmount=100000000, Items={["Sea Mine"]=25}},
            Dialog = {"Your palate is maturing. Let us taste the finest algae this world has.", "Harvest heavily from Coralline and Crystal. No slacking!"}
        },
        TokenHoarder = {
            Goals = {["TokensGathered"]=3500},
            Rewards = {BiomassAmount=250000000, Items={["Pearl"]=250}},
            Dialog = {"Those tokens scattered across the reefs are vital fragments of energy.", "Gather 3,500 tokens of any kind. Keep swimming!"}
        },
        SpeedTest = {
            Goals = {["MaxAlgaePerSecond"]=75000, ["Sun Reef"]=150000000},
            Rewards = {BiomassAmount=500000000, Items={["Zooplankton"]=40}},
            Dialog = {"Endurance is good. Speed is better. Let me see how fast you truly are.", "Reach an Algae/Sec rate of 75,000! Work the Sun Reef to its limit!"}
        },
        CrystalCraze = {
            Goals = {["Crystal Reef"]=500000000},
            Rewards = {BiomassAmount=1000000000, Items={["Fish Feed"]=100}},
            Dialog = {"The crystals... they are resonating. We need exactly 500 Million.", "Do not stop until the Crystal Reef has been thoroughly swept."}
        },
        DiamondDepths = {
            Goals = {["Obsidian Reef"]=1250000000, ["Crystal Reef"]=1250000000, ["AbilitiesCommitted"]=5000},
            Rewards = {BiomassAmount=3500000000, Items={["Diamond Egg"]=1}},
            Dialog = {"A pressure so deep it turns carbon into diamond.", "You are ready for this trial. Over 2.5 Billion total required. Do this, and a Diamond Egg is yours."}
        },
        PeakPerformance = {
            Goals = {["MaxAlgaePerSecond"]=500000, ["Coralline Reef"]=5000000000},
            Rewards = {BiomassAmount=10000000000, Items={["Pearl"]=1000}},
            Dialog = {"A Diamond Egg is not the end. I need you to push your speed to new horizons.", "Hit 500,000 Algae per second. Show me your peak!"}
        },
        ObsidianObliteration = {
            Goals = {["Obsidian Reef"]=12500000000, ["SeaMinesPopped"]=150},
            Rewards = {BiomassAmount=25000000000, Items={["Sea Mine"]=100}},
            Dialog = {"The heat has built up for far too long. We must obliterate the obsidian.", "Shatter the volcanic rock. Pop 150 mines. Do not hold back."}
        },
        CorallineCrush = {
            Goals = {["Coralline Reef"]=25000000000, ["TokensGathered"]=15000},
            Rewards = {BiomassAmount=50000000000, Items={["Pearl"]=2500}},
            Dialog = {"Crush the coralline growth. The ocean must balance itself.", "25 Billion. An absolute unit of a task. It will take time, but I know you can do it."}
        },
        OceanicOverlord = {
            Goals = {["MaxAlgaePerSecond"]=2500000, ["Crystal Reef"]=50000000000, ["AbilitiesCommitted"]=25000},
            Rewards = {BiomassAmount=150000000000, Items={["Mythic Egg"]=1}},
            Dialog = {"This is it. The culmination of your lifetime in these waters.", "I am asking for 50 Billion algae... and speeds exceeding 2.5 Million per second.", "Should you succeed, I will name you the Overlord, and grant you a legendary Mythic Egg."}
        }
    }

    local output = ""
    for _, q in ipairs(qChain) do
        local d = qData[q]
        
        -- Serialize Goals
        local goalsStr = "{\n"
        for k,v in pairs(d.Goals) do
            goalsStr = goalsStr .. string.format("\t\t\t[\"%s\"] = %d,\n", k, v)
        end
        goalsStr = goalsStr .. "\t\t}"
        
        -- Serialize Rewards
        local rewardsStr = "{\n\t\t\tBiomassAmount = " .. d.Rewards.BiomassAmount .. ",\n\t\t\tItems = {"
        for k,v in pairs(d.Rewards.Items) do
            rewardsStr = rewardsStr .. "[\"" .. k .. "\"] = " .. v .. ", "
        end
        rewardsStr = rewardsStr .. "}\n\t\t}"

        local questStr = string.format([[
	["%s"] = {
		Name = "%s",
		Type = "Collect",
		Goals = %s,
		Rewards = %s,
		Giver = "Elder Turtle"
	},
]], q, q:gsub("%u", " %1"):match("^%s*(.-)$"), goalsStr, rewardsStr)

        output = output .. questStr
    end
    
    local dOutput = ""
    for _, q in ipairs(qChain) do
        local d = qData[q]
        local dStr = string.format([[
	%s_Start = {
		Messages = {
			"%s",
			"%s"
		},
		QuestID = "%s"
	},
	%s_InProgress = {
		Messages = {"Come on, keep at it. Don''t give up now!"}
	},
	%s_Complete = {
		Messages = {"Spectacular work as always. Let me prepare your next challenge."},
		FinishQuestID = "%s"
	},
]], q, d.Dialog[1], d.Dialog[2] or "Good luck.", q, q, q, q)
        dOutput = dOutput .. dStr
    end
    
    print("QUEST DEFINITIONS:\n" .. output)
    print("DIALOGUE DEFINITIONS:\n" .. dOutput)
    print("QUEST CHAIN INSERTION:")
    for _,q in ipairs(qChain) do print("\t\"" .. q .. "\",") end
end

generateQuests()

