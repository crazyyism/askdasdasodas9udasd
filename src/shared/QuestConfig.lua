local QuestConfig = {}


QuestConfig.QuestGiverName = "Elder Turtle"


QuestConfig.QuestChain = {
    "FreshwaterCleaning",
    "AFavoriteColor",
    "BabySteps",
    "CoralCodependence",
    "Trigonometry",
    "HistoryRepeatsItself",
    "RunicRebel",
    "TakeFlight",
    "MeaninglessLove",
    "PearlsOfTheSea",
    "LightLikeSapphire",
    "AlgaeTrek",
    "CloudedInMystery",
    "SecondToNone",
    "AlgaeTrek2",
    "CoralQuadependence",
    "TherellBeBetterDays",
    "ZooplanktonHarmony",
    "NoobiesFinish",
    "MagmaticSanctuary",
   
    -- Lava Turtle Quests
    "Lava_Ignition",
    "Lava_Eruption",
    "Lava_MoltenCore",
    "Lava_ObsidianHeat",
    "Lava_VolcanicAscension"
}


-- ============================================================
-- DIALOGUE
-- Each quest has _Start, _InProgress, and _Complete dialogue.
-- WelcomeDialogue is the initial greeting (starts FreshwaterCleaning).
-- NoMoreQuests is shown when all quests are finished.
-- ============================================================


QuestConfig.Dialogue = {


    WelcomeDialogue = {
        Messages = {
            "Hello there!",
            "Let me introduce myself first, I am the Elder Turtle!",
            "I see that you have a fishing net and a pouch on you,",
            "You're here to be own a fish hatchery, right?",
            "Well, that's good news, because I used to be a pretty notorious fish hatcherer myself!",
            "If you are willing to follow my demands, I promise you that you will be one of the best in the world!",
            "First off, lets have you collect 200 Algae in the Freshwater Reef,",
            "If you are confused on where that is, it is located on the shorelines of the lake!",
            "Best of luck new adventurer!"
        },
        QuestID = "FreshwaterCleaning"
    },


    FreshwaterCleaning_Complete = {
        Messages = {
            "Great job! You're already getting the hang of this!",
            "Here is a basic egg, you are able to drag it out of your inventory to an empty slot in your aquarium!",
            "Come back when you've hatched your first fish!"
        },
        FinishQuestID = "FreshwaterCleaning"
    },


    FreshwaterCleaning_InProgress = {
        Messages = {
            "Fish are quite fascinating, and if you haven't noticed already, you have one in your inventory!",
            "To hatch it, simply drag it out of your inventory, and you will be able to hatch your first fish!"
        }
    },


    -- Quest 2
    AFavoriteColor_Start = {
        Messages = {
            "Welcome back!",
            "If you haven't noticed already, there are different reefs around the map!",
            "Each one of them has their special trait",
            "For example, the Sun Reef, the one on that little uprise in the lake,",
            "mainly contains orange algae! And although it is much smaller than the Freshwater Reef,",
            "It regrows its algae MUCH faster!",
            "Now, I want you to collect 250 orange algae from ANY reef!",
            "Come back when you're done!"
        },
        QuestID = "AFavoriteColor"
    },
    AFavoriteColor_InProgress = {
        Messages = {
            "Have I told you I love the color orange?",
            "Most of what I like to eat is orange, for example, honey!",
            "Maybe the other turtles would think the same, I know Lava Turtle probably would."
        }
    },
    AFavoriteColor_Complete = {
        Messages = {
            "Thanks for helping me out!",
            "Come back for more quests!"
        },
        FinishQuestID = "AFavoriteColor"
    },


    -- Quest 3
    BabySteps_Start = {
        Messages = {
            "Hello!",
            "I forgot to tell you what I gave you previously!",
            "These are called Zooplankton, they change your fish to a different one.",
            "Zooplankton are able to change your fish into majority of fish in the index!",
            "Some fish are rarer than others, and are listed in different types of rarities.",
            "They include: Rare fish, Epic fish, Legendary fish, and Mythic fish",
            "With mythic fish being the rarest in the game!",
            "Maybe you'll be lucky with your zooplankton and you'll get a really good fish!",
            "They'll be handy for what I want you to do anyway",
            "Now, collect 250 Green, Orange, and Pink algae from anywhere around the map!",
        },
        QuestID = "BabySteps"
    },
    BabySteps_InProgress = {
        Messages = {
            "There are also eggs that you can purchase for pearls! Which I'll introduce later.",
            "Eggs let you hatch rarer fish, but they can also be used to purchase good equipment!"
        }
    },
    BabySteps_Complete = {
        Messages = {
            "Nice job!",
            "I hope that zooplankton gave you something good!",
            "Here is another Zooplankton to use in your collection!"
        },
        FinishQuestID = "BabySteps"
    },


    CoralCodependence_Start = {
        Messages = {
            "Remember I told you that there were many different reefs around the map?",
            "Well it turns out I need all three colors again!",
            "Except, I need you to do it in both freshwater and coral reef.",
            "That's all! Come back when you're done!"
        },
        QuestID = "CoralCodependence"
    },
    CoralCodependence_InProgress = {
        Messages = {
            "If you haven't already, you may want to go get better equippment."
        }
    },
    CoralCodependence_Complete = {
        Messages = {
            "Nice job! You're quite a natural at this!",
            "Talk to me when you're ready!"
        },
        FinishQuestID = "CoralCodependence"
    },


    Trigonometry_Start = {
        Messages = {
            "Did I ever tell you how bad I am at math?",
            "I thought math was supposed to be about putting cookies in a jar",
            "Not whatever this 'Sine' or 'Tangent' stuff is, it drives me CRAZY!!!",
            "Thank goodness I'm not in that suffocating classroom anymore. I barely passed with a C-",
            "That was a long, long, looong time ago, I don't have to deal with my teacher's yapping anymore.",
            "Well, actually, the only thing I DO remember, is that all angles inside of a triangle are equivalent to 180 degrees!",
            "I can't believe thats the ONLY thing I remember from that class.",
            "Oops, I'm off topic! Sorry about that",
            "Collect me 4,000 Algae from the Trash Reef!"
        },
        QuestID = "Trigonometry"
    },
    Trigonometry_InProgress = {
        Messages = {
            "snore zzzzzzz"
        }
    },
    Trigonometry_Complete = {
        Messages = {
            "How's it been?",
            "I sure hope you're ready for whatever math test you have later on.",
            "Anyways,",
            "In a Euclidean space, the sum of angles of a triangle equals a straight angle (180 degrees, π radians, two right angles, or a half-turn). A triangle has three angles, and has one at each vertex, bounded by a pair of adjacent sides.The sum can be computed directly using the definition of angle based on the dot product and trigonometric identities, or more quickly by reducing to the two-dimensional case and using Euler's identity.It was unknown for a long time whether other geometries exist, for which this sum is different. The influence of this problem on mathematics was particularly strong during the 19th century. Ultimately, the answer was proven to be positive: in other spaces (geometries) this sum can be greater or lesser, but it then must depend on the triangle. Its difference from 180° is a case of angular defect and serves as an important distinction for geometric systems. (Wikipedia Contributors. \"Sum of Angles of a Triangle.\" Wikipedia, Wikimedia Foundation, 10 Feb. 2025.)",
            "I'm going back to sleep."
        },
        FinishQuestID = "Trigonometry"
    },


    HistoryRepeatsItself_Start = {
        Messages = {
            "Welcome back!",
            "It's quite rare that I see people here at all. I don't think I've ever told you that.",
            "I take it for granted sometimes, it's never my intention to be so pushy and demanding. I'm just excited, that's all.",
            "...",
            "Sometimes, I question what life is.",
            "What is the point of living if you die anyways?",
            "Is it really certain you live once only? And after you die, what happens?",
            "Was there ever a before, did I live before?",
            "When you die, does your consciousness continue sometime far, far in the future, where maybe,",
            "Your brain structure and consciousness is fully recreated in some kind of manner?",
            "Imagine how long that'd take, you'd probably be witnessing MULTIPLE universal resets before it ever happens again.",
            "This makes me realize how lucky I am to be alive. Don't waste your time and effort to contemplate whether or not there is anything after life.",
            "You'll be stuck in a cycle, and you'll never be able to live fully.",
            "Anyways, back to reality, I need you to collect 3,500 algae from both the Trash Reef and the Sun Reef."
        },
        QuestID = "HistoryRepeatsItself"
    },
    HistoryRepeatsItself_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    HistoryRepeatsItself_Complete = {
        Messages = {
            "Life is something you need to appreciate once in a while",
            "I don't mean to ruin your mood, but your life will end.",
            "It doesn't matter how much you try to resist, how much you do to stop it, you will die.",
            "And yes, people will just tell you to 'live your life' and blah blah blah..",
            "But it's so much harder to say that when you're already raised within boundaries stated to you from birth.",
            "Living is to understand that death is inevitable. When you understand that, you'll learn to cherish what you do.",
            "Anyways, sorry for the existential dialogue, I just wanted to add on that you have 5 more quests until you earn a sapphire egg!",
            "Come back again!"
        },
        FinishQuestID = "HistoryRepeatsItself"
    },


    RunicRebel_Start = {
        Messages = {
            "When walking around the map, you've definitely seen those gates that have a number",
            "That means that you need THAT amount of fish to enter that zone",
            "Unfortunately, that means you'll need 5 fish to do the next quest, so I hope you really got those fish!",
            "I want you to go to the Runic Reef, the reef that isn't a rectangle, or square, wait what is it?",
            "Just go collect 9,000 algae from that reef, maybe that reef can help explain why I saw that weird algae type a bit ago.."
        },
        QuestID = "RunicRebel"
    },
    RunicRebel_InProgress = {
        Messages = {
            "Fish are put into 4 different archetypes, Orange, Pink, Green, and Colorless.",
            "Each corresponding color collects 100% more algae of that type per harvest."
        }
    },
    RunicRebel_Complete = {
        Messages = {
            "Aye, thanks for helping me out man!",
            "I'll be able to examine this algae a bit more closely now!",
            "Well, see you later!"
        },
        FinishQuestID = "RunicRebel"
    },


    TakeFlight_Start = {
        Messages = {
            "You tired of walking huh? I could've guessed given the fact that there's not much transport around the map.",
            "Too bad you're gonna have to keep walking",
            "Unless you purchase that Hydroglider in the Noob Shop!",
            "It's quite handy, you can control where you go based off where you're looking!",
            "Anyways, I'll give you the necessary resources to get it IF you collect 8,000 algae from every single field in the starting area, how's that sound?",
            "Good luck!"
        },
        QuestID = "TakeFlight"
    },
    TakeFlight_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    TakeFlight_Complete = {
        Messages = {
            "Must've been one kind of a walk huh?",
            "Here's your reward!!! Good luck!!"
        },
        FinishQuestID = "TakeFlight"
    },


    MeaninglessLove_Start = {
        Messages = {
            "I remember back in my youth I had bright aspirations of being an athlete, specifically a track runner.",
            "It's the kind of aspiration where it turned into obsession.",
            "Hold on there's a name for this...",
            "Passion? I don't know, probably something like that.",
            "Each and every day I'd hop the fence of my local school's track and practice everything.",
            "Even on days I'm injured, or days where I don't feel in perfect shape,",
            "I'd always find myself almost attracted to the track.",
            "Every stride, every step, it always pushed me further beyond what I believed I could do.",
            "Dreams I have of being the fastest in the school, fastest in the state, fastest in the nation.",
            "It felt like my life had MEANING for once.",
            "Meaning that I've always yearned for.",
            "...",
            "What's that?",
            "Oh yeah, you need a quest from me.",
            "Sorry about that, uhhh just go collect 15,000 algae from these reefs, and have 250 abilities committed total."
        },
        QuestID = "MeaninglessLove"
    },
    MeaninglessLove_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    MeaninglessLove_Complete = {
        Messages = {
            "Congrats!! Mr. Crazyyism is too lazy to give me much dialogue to say here...",
            "Well, here's some fish feed and a Sea Mine to help you out!",
            "See ya around."
        },
        FinishQuestID = "MeaninglessLove"
    },
    PearlsOfTheSea_Start = {
        Messages = {
            "Later on, when you start to advance in this lake, you will encounter different shops around the map.",
            "These shops will require more and more resources to unlock, eventually requiring special materials to purchase.",
            "In this case, one of them is called 'Pearls'. They are a special type of currency that are used to purchase different types of fish and equipments.",
            "Pearls will be very important in the future to progress and become even more powerful!",
            "30,000 Orange Algae from the Freshwater Reef",
            "30,000 Pink Algae from the Freshwater Reef",
            "30,000 Green Algae from the Freshwater Reef",
            "75,000 Algae from the Runic Reef",
            "Along with 300 Total Abilities Committed,",
            "and last but not least,",
            "You must pop a Sea Mine!",
            "I'll see ya soon!"
        },
        QuestID = "PearlsOfTheSea"
    },
    PearlsOfTheSea_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    PearlsOfTheSea_Complete = {
        Messages = {
            "Nice work!!!",
            "Heres a couple of pearls you can use to purchase different resources!",
            "See you soon!"
        },
        FinishQuestID = "PearlsOfTheSea"
    },


    LightLikeSapphire_Start = {
        Messages = {
            "So, you remember how I said that you have 5 more quests until you get a sapphire egg?",
            "Well, you're here now!!",
            "But you don't get it easy of course, you gotta work for it lololol",
            "Hmm let me think of a really big number from 0 - 250,000",
            "Hmmmmmmmmmmmmmmmm...",
            "Yeah so, how about collecting 250,000 algae from the Sun Reef!"
        },
        QuestID = "LightLikeSapphire"
    },
    LightLikeSapphire_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    LightLikeSapphire_Complete = {
        Messages = {
            "Wow, you actually did it, clearly you think this game is quite interesting huh",
            "Well, enjoy your little treat of a sapphire egg. Oh yeah, even though it is an egg I dont suggest you use it on your aquarium",
            "Otherwise, you'll miss out on crafting some pretty overpowered accessories."
        },
        FinishQuestID = "LightLikeSapphire"
    },


    AlgaeTrek_Start = {
        Messages = {
            "Welcome back... Don't know how many times I've said that!",
            "Well, you're quite a natural I see, you've been able to keep up with my demands!",
            "And you've earned your little sapphire egg!",
            "Well, lets see, I'm going to assume you have AT LEAST 10 fish in your aquarium,",
            "Otherwise I feel pretty bad for what I want from you",
            "I want you to collect 75,000 Algae from:",
            "Freshwater, Coral, Trash, Sun, Runic, Coralline, Obsidian, and Crystal Reef!",
            "Good luck!"
        },
        QuestID = "AlgaeTrek"
    },
    AlgaeTrek_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    AlgaeTrek_Complete = {
        Messages = {
            "How was the trek?",
            "You're lucky I didn't give you any tedious tasks... I suppose",
            "Come back when you're ready for the next one."
        },
        FinishQuestID = "AlgaeTrek"
    },
    OutOfTheOrdinary_Start = {
        Messages = {
            "You've probably questioned why theres a singular green algae block in the Obsidian Reef",
            "From what I remember, the obsidian reef wasn't always just pure orange algae,",
            "Back then, it used to be a very colorful reef, in fact, it contained a fourth algae type!",
            "However, the volcano next to it started becoming incredibly active, and it eventually erupted, spewing lava all over the algae.",
            "Now yes, the algae should have burned into a crisp, but hey its Roblox!",
            "The algae all turned orange besides this one green algae block, pretty cool!",
            "Anyways, I have some demands for you, and for the next 10 quests, you'll be on your route to getting your first few legendary fish!"
        },
        QuestID = "OutOfTheOrdinary"
    },
    OutOfTheOrdinary_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    OutOfTheOrdinary_Complete = {
        Messages = {
            "How was the trek?",
            "You're lucky I didn't give you any tedious tasks... I suppose",
            "Come back when you're ready for the next one."
        },
        FinishQuestID = "OutOfTheOrdinary"
    },
	CloudedInMystery_Start = {
        Messages = {
            "You know, there’s a reef that people aren’t even sure how it came to existence?",
            "Located above the runic reefs, and close to the peak of the waterfalls, there lies a reef, known as the Mystic Reef.",
            "The reef is very special, as it contains a new algae type.",
            "Among the three “generic” types of algae, there is an algae type that remains to be the most powerful and resourceful.",
            "People call it the mystic algae, it is white in appearance and appears quite rarely. Only reefs above the 15 fish barrier have mystic algae.",
            "What makes mystic algae so special is that all the algae buffs for every type of algae affect mystic algae!",
            "Let's just say that you have a 50% orange algae boost, it should only affect orange algae",
            "But for the mystic algae, it gets affected by the 50% orange algae! So if you collect 100 algae of the orange algae, you will get 150 algae from the orange algae, and for the mystic algae you will also get 150 from the 100 algae collected!",
            "As a result, the algae is quite rare to find in abundance. Even the mystic reef, which contains mainly mystic algae, only has the mystic algae as singles, and rarely doubles!",
            "Anyway, just go and collect some mystic algae, there are some remnants of mystic algae located in the 15 fish required zone!"
        },
        QuestID = "CloudedInMystery"
    },
    CloudedInMystery_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    CloudedInMystery_Complete = {
        Messages = {
            "Nice job with the collection! I hope it wasn’t too difficult for you to obtain 15 fish,",
            "Eventually there will be ways to obtain mystic algae more effectively, but as of now it won’t be much of a priority.",
            "Come back to me when you are ready for the next quest!"
        },
        FinishQuestID = "CloudedInMystery"
    },
    SecondToNone_Start = {
        Messages = {
            "You’re just 8 quests away! How magnificent is that!",
            "I hope the rewards I’m able to grant you are actually beneficial to your journey haha",
            "You know if you’re tired of my stupid requests you can always talk to other quest givers, theres noobie turtle who gives infinite quests and then there is Lava Turtle, who gives you this pretty cool rune at the end of his questline, allowing you to get this type of harvesting tool.",
        },
        QuestID = "SecondToNone"
    },
    SecondToNone_InProgress = {
        Messages = {
            "get back to work"
        }
    },
    SecondToNone_Complete = {
        Messages = {
            "Did you get those sea mines? Good. They were meant for 'explosive' science experiments!",
            "Take these rewards. We're just getting into the heavy stuff now."
        },
        FinishQuestID = "SecondToNone"
    },
    AlgaeTrek2_Start = {
        Messages = {
            "Oh boy... Have you ever looked at a map and thought, 'I want to be everywhere'?",
            "Well, now you'll be everywhere.",
			"I need you to collect 300,000 algae from literally EVERY reef!",
			"Cry about it lol"
        },
        QuestID = "AlgaeTrek2"
    },
    AlgaeTrek2_InProgress = {
        Messages = {
            "I wasn't joking. Every reef. Go!"
        }
    },
    AlgaeTrek2_Complete = {
        Messages = {
            "Nice job yo!",
            "Truly remarkable."
        },
        FinishQuestID = "AlgaeTrek2"
    },
    CoralQuadependence_Start = {
        Messages = {
			"I remember giving you a quest like this in the past,",
			"It was something like 'Coral Codependence'",
			"Guess what?",
			"Second times the charm!",
			"Go Collect"
        },
        QuestID = "CoralQuadependence"
    },
    CoralQuadependence_InProgress = {
        Messages = {
            "Pink algae. 450,000. Coral and Coralline. Not hard to remember, right?"
        }
    },
    CoralQuadependence_Complete = {
        Messages = {
            "Ah, the pink hue reminds me of my grandmother's favorite shawl.",
            "Beautiful work."
        },
        FinishQuestID = "CoralQuadependence"
    },
    TherellBeBetterDays_Start = {
        Messages = {
            "I had a terrifying dream that the Sun Reef, Ghastly Reef, and Warrior's Reef were completely overtaken by an endless horde of algae!",
            "We must prevent this nightmare from coming true.",
            "Collect 400,000 algae from each of those reefs.",
            "Also, pop 5 sea mines to ensure the coast is clear!"
        },
        QuestID = "TherellBeBetterDays"
    },
    TherellBeBetterDays_InProgress = {
        Messages = {
            "The nightmare lurks! Hurry up and clear those reefs before the algae consumes us all!"
        }
    },
    TherellBeBetterDays_Complete = {
        Messages = {
            "Phew, I can finally sleep peacefully knowing the apocalypse is canceled.",
            "Excellent performance, kid."
        },
        FinishQuestID = "TherellBeBetterDays"
    },
    ZooplanktonHarmony_Start = {
        Messages = {
            "Ah, Zooplankton. Such small, majestic creatures.",
            "We need true harmony between the oldest waters and the freshest streams.",
            "Bring me 500,000 algae from both the Ancient Reef and the Freshwater Reef."
        },
        QuestID = "ZooplanktonHarmony"
    },
    ZooplanktonHarmony_InProgress = {
        Messages = {
            "Harmony takes patience. Go collect that algae from the Ancient and Freshwater reefs."
        }
    },
    ZooplanktonHarmony_Complete = {
        Messages = {
            "Ah, harmony is perfectly restored. You're starting to look like a true professional.",
            "I have very high hopes for you."
        },
        FinishQuestID = "ZooplanktonHarmony"
    },
    NoobiesFinish_Start = {
        Messages = {
            "I see you've grown strong... perhaps even stronger than I ever was.",
            "But a true master never forgets their roots!",
            "Return to the Trash, Crystal, and Freshwater reefs for 600,000 algae each.",
            "Oh, and you must own all the Noobie Shop equipment! Humility is key."
        },
        QuestID = "NoobiesFinish"
    },
    NoobiesFinish_InProgress = {
        Messages = {
            "Don't tell me you forgot to buy the Noobie Shop items..."
        }
    },
    NoobiesFinish_Complete = {
        Messages = {
            "Haha! Sometimes revisiting our humble beginnings reminds us of just how far we've climbed.",
            "You're almost at the finish line."
        },
        FinishQuestID = "NoobiesFinish"
    },
    MagmaticSanctuary_Start = {
        Messages = {
            "This is your final task for me, my young scholar.",
            "The core of the earth is blazing, and the sun shines upon our oldest reefs.",
            "Collect 500,000 algae from Obsidian and Warrior's...",
            "...and 250,000 orange algae from the Sun, Coral, and Ancient Reefs!",
            "Let the fire fuel your spirit, and bring back the ultimate catch!"
        },
        QuestID = "MagmaticSanctuary"
    },
    MagmaticSanctuary_InProgress = {
        Messages = {
            "This is your final test! Let the magma fuel your spirit and collect that algae!"
        }
    },
    MagmaticSanctuary_Complete = {
        Messages = {
            "My friend... you've done it.",
            "You have conquered all of the Elder Turtle's trials.",
            "Carry your title proudly, for you are truly a master of the hatchery!",
            "But the lake is large... perhaps Lava Turtle has something to say."
        },
        FinishQuestID = "MagmaticSanctuary"
    },

    NoMoreQuests = {
        Messages = {
            "You finished all the quests, congratulations!"
        }
    },


   
    -- LAVA TURTLE DIALOGUES
    Lava_Ignition_Start = {
        Messages = {
            "Greetings, traveler. I am the Lava Turtle.",
            "Do you feel the heat beneath this world? The energy surging through the magma?",
            "Only the strongest hatchlings survive the boiling currents.",
            "Prove your mettle. Harvest the molten lands of the Obsidian Reef.",
            "I require 7,500 Algae from the Obsidian Reef, and 50 abilities committed.",
            "Return to me when you are ablaze with success."
        },
        QuestID = "Lava_Ignition"
    },
    Lava_Ignition_InProgress = {
        Messages = {"Do not return until the task is done, the flames demand more."}
    },
    Lava_Ignition_Complete = {
        Messages = {"Impressive start. But this is merely a spark..."},
        FinishQuestID = "Lava_Ignition"
    },


}


-- ============================================================
-- QUESTS
-- ============================================================


QuestConfig.Quests = {
    ["FreshwaterCleaning"] = {
        Name = "Freshwater Cleaning",
        Type = "Collect",
        TargetResource = "Any",
        TargetLocation = "Freshwater Reef",
        GoalAmount = 200,
        Rewards = {
            BiomassAmount = 250,
            Items = {"Basic Egg"}
        },
        Giver = "Elder Turtle"
    },
    ["AFavoriteColor"] = {
        Name = "A Favorite Color",
        Description = "Collect 250 Orange Algae",
        Type = "Collect",
        Goals = {
            ["OrangeAlgae"] = 250
        },
        Rewards = {
            BiomassAmount = 500,
            Items = {"Zooplankton"}
        },
        Giver = "Elder Turtle"
    },
    ["BabySteps"] = {
        Name = "Baby Steps",
        Type = "Collect",
        Goals = {
            ["GreenAlgae"] = 250,
            ["PinkAlgae"] = 250,
            ["OrangeAlgae"] = 250
        },
        Rewards = {
            BiomassAmount = 1000,
            Items = { ["Zooplankton"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["CoralCodependence"] = {
        Name = "Coral Codependence",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef_GreenAlgae"] = 100,
            ["Freshwater Reef_PinkAlgae"] = 100,
            ["Freshwater Reef_OrangeAlgae"] = 100,
            ["Coral Reef_GreenAlgae"] = 100,
            ["Coral Reef_PinkAlgae"] = 100,
            ["Coral Reef_OrangeAlgae"] = 100
        },
        Rewards = {
            BiomassAmount = 3000,
            Items = { ["Zooplankton"] = 2, ["Basic Egg"] = 1, ["Sea Mine"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["Trigonometry"] = {
        Name = "Trigonometry",
        Type = "Collect",
        TargetResource = "Any",
        TargetLocation = "Trash Reef",
        GoalAmount = 4000,
        Rewards = {
            BiomassAmount = 5000,
            Items = { ["Zooplankton"] = 2, ["Basic Egg"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["HistoryRepeatsItself"] = {
        Name = "History Repeats Itself",
        Type = "Collect",
        Goals = {
            ["Trash Reef"] = 4000,
            ["Sun Reef"] = 4000,
            ["FishRequired"] = 5
        },
        Rewards = {
            BiomassAmount = 10000,
            Items = { ["Zooplankton"] = 3, ["Bronze Egg"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["RunicRebel"] = {
        Name = "Runic Rebel",
        Type = "Collect",
        TargetResource = "Any",
        TargetLocation = "Runic Reef",
        GoalAmount = 15000,
        Rewards = {
            BiomassAmount = 20000,
            Items = { ["Zooplankton"] = 5, ["Bronze Egg"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["TakeFlight"] = {
        Name = "Take Flight",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef"] = 10000,
            ["Coral Reef"] = 10000,
            ["Trash Reef"] = 10000,
            ["Sun Reef"] = 10000
        },
        Rewards = {
            BiomassAmount = 25000,
            Items = { ["Zooplankton"] = 5}
        },
        Giver = "Elder Turtle"
    },
    ["MeaninglessLove"] = {
        Name = "Meaningless Love",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef"] = 15000,
            ["Coral Reef"] = 15000,
            ["Trash Reef"] = 15000,
            ["Sun Reef"] = 15000,
            ["Runic Reef"] = 15000,
            ["AbilitiesCommitted"] = 250
        },
        Rewards = {
            BiomassAmount = 40000,
            Items = { ["Fish Feed"] = 25, ["Sea Mine"] = 1 }
        },
        Giver = "Elder Turtle"
    },
    ["PearlsOfTheSea"] = {
        Name = "Pearls of the Sea",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef_OrangeAlgae"] = 50000,
            ["Freshwater Reef_PinkAlgae"] = 15000,
            ["Freshwater Reef_GreenAlgae"] = 20000,
            ["Runic Reef"] = 50000,
            ["AbilitiesCommitted"] = 300,
            ["SeaMinesPopped"] = 1
        },
        Rewards = {
            BiomassAmount = 50000,
            Items = { ["Pearl"] = 20, ["Sea Mine"] = 5 }
        },
        Giver = "Elder Turtle"
    },
    ["LightLikeSapphire"] = {
        Name = "Light Like Sapphire",
        Type = "Collect",
        TargetResource = "Any",
        TargetLocation = "Sun Reef",
        GoalAmount = 100000,
        Rewards = {
            BiomassAmount = 500000,
            Items = { ["Sapphire Egg"] = 1, ["Pearl"] = 15, ["Zooplankton"] = 5 }
        },
        Giver = "Elder Turtle"
    },
    ["AlgaeTrek"] = {
        Name = "Algae Trek",
        Type = "Collect",
        Goals = {
            ["Obsidian Reef"] = 75000,
            ["Freshwater Reef"] = 75000,
            ["Coral Reef"] = 75000,
            ["Trash Reef"] = 75000,
            ["Sun Reef"] = 75000,
            ["Runic Reef"] = 75000,
            ["Crystal Reef"] = 75000,
            ["Coralline Reef"] = 75000
        },
        Rewards = {
            BiomassAmount = 250000,
            Items = { ["Zooplankton"] = 20, ["Sea Mine"] = 3, ["Bronze Egg"] = 1, ["Fertilizer"] = 3 }
        },
        Giver = "Elder Turtle"
    },
    ["CloudedInMystery"] = {
        Name = "CloudedInMystery",
        Type = "Collect",
        Goals = {
            ["MysticAlgae"] = 225000,
            ["Warrior’s Reef"] = 160000,


        },
        Rewards = {
            BiomassAmount = 250000,
            Items = { ["Zooplankton"] = 30, ["Sea Mine"] = 1, ["Pearl"] = 12 }
        },
        Giver = "Elder Turtle"
    },
    ["SecondToNone"] = {
        Name = "SecondToNone",
        Type = "Collect",
        Goals = {
            ["SeaMinesPopped"] = 3,
            ["AbilitiesCommitted"] = 2000,
            ["Ghastly Reef"] = 125000,
            ["Freshwater Reef"] = 275000,
            ["Mystic Reef"] = 100000,


        },
        Rewards = {
            BiomassAmount = 670041,
            Items = { ["Sapphire Egg"] = 1, ["Sea Mine"] = 2, ["Pearl"] = 22, ["Fish Feed"] = 677,  }
        },
        Giver = "Elder Turtle"
    },
    ["AlgaeTrek2"] = {
        Name = "Algae Trek 2",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef"] = 300000,
            ["Coral Reef"] = 300000,
            ["Trash Reef"] = 300000,
            ["Sun Reef"] = 300000,
            ["Runic Reef"] = 300000,
            ["Obsidian Reef"] = 300000,
            ["Crystal Reef"] = 300000,
            ["Coralline Reef"] = 300000,
            ["Warrior’s Reef"] = 300000,
            ["Ghastly Reef"] = 300000,
            ["Mystic Reef"] = 300000
        },
        Rewards = {
            BiomassAmount = 800000,
            Items = { ["Zooplankton"] = 40, ["Sea Mine"] = 5, ["Pearl"] = 25 }
        },
        Giver = "Elder Turtle"
    },
    ["CoralQuadependence"] = {
        Name = "Coral Quadependence",
        Type = "Collect",
        Goals = {
			["Coral Reef_PinkAlgae"] = 450000,
			["Coral Reef_GreenAlgae"] = 200000,
			["Coralline Reef_PinkAlgae"] = 450000,
			["Coralline Reef_OrangeAlgae"] = 300000,
			["Coralline Reef"] = 1000000,
			["Coral Reef"] = 500000,
			["AbilitiesCommitted"] = 5000,
			["FishRequired"] = 12
            
        },
        Rewards = {
            BiomassAmount = 900000,
            Items = { ["Zooplankton"] = 65, ["Sea Mine"] = 3, ["Pearl"] = 30, ["Bronze Egg"] = 5 }
        },
        Giver = "Elder Turtle"
    },
    ["TherellBeBetterDays"] = {
        Name = "There'll Be Better Days",
        Type = "Collect",
        Goals = {
            ["Sun Reef"] = 750000,
            ["Ghastly Reef"] = 900000,
            ["Warrior’s Reef"] = 1000000,
            ["SeaMinesPopped"] = 5
        },
        Rewards = {
            BiomassAmount = 1000000,
            Items = { ["Sapphire Egg"] = 2, ["Zooplankton"] = 60, ["Pearl"] = 40 }
        },
        Giver = "Elder Turtle"
    },
    ["ZooplanktonHarmony"] = {
        Name = "Zooplankton Harmony",
        Type = "Collect",
        Goals = {
            ["Freshwater Reef"] = 500000,
            ["Ancient Reef"] = 500000
        },
        Rewards = {
            BiomassAmount = 1250000,
            Items = { ["Zooplankton"] = 100, ["Sea Mine"] = 10, ["Pearl"] = 50 }
        },
        Giver = "Elder Turtle"
    },
    ["NoobiesFinish"] = {
        Name = "Noobie's Finish",
        Type = "Collect",
        Goals = {
            ["Trash Reef"] = 600000,
            ["Crystal Reef"] = 600000,
            ["Freshwater Reef"] = 600000,
            ["Runic Reef_GreenAlgae"] = 200000,
            ["OwnAllNoobieEquipment"] = 1
        },
        Rewards = {
            BiomassAmount = 1500000,
            Items = { ["Sapphire Egg"] = 3, ["Zooplankton"] = 80, ["Pearl"] = 60 }
        },
        Giver = "Elder Turtle"
    },
    ["MagmaticSanctuary"] = {
        Name = "Magmatic Sancturary",
        Type = "Collect",
        Goals = {
            ["Obsidian Reef"] = 500000,
            ["Warrior’s Reef"] = 500000,
            ["Sun Reef_OrangeAlgae"] = 250000,
            ["Coral Reef_OrangeAlgae"] = 250000,
            ["Ancient Reef_OrangeAlgae"] = 250000
        },
        Rewards = {
            BiomassAmount = 2000000,
            Items = { ["Ruby Egg"] = 1, ["Zooplankton"] = 120, ["Pearl"] = 75, ["Fish Feed"] = 1000 }
        },
        Giver = "Elder Turtle"
    },


    -------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------


    ["Lava_Ignition"] = {
        Name = "Ignition",
        Type = "Collect",
        Goals = {
            ["Obsidian Reef"] = 7500,
            ["AbilitiesCommitted"] = 50
        },
        Rewards = {
            BiomassAmount = 5000
        },
        Giver = "Lava Turtle"
    },
}


function QuestConfig.UpdateNoobieTurtle(completedQuests, fishCount, userId, existingProgress)
    completedQuests = completedQuests or 0
    fishCount = fishCount or 0
    userId = userId or 0


    local multiplier = math.pow(1.25, completedQuests)
   
    local algaeGoal = math.floor(1500 * multiplier)
    local abilityGoal = math.floor(20 * multiplier)
   
    local biomassReward = math.floor(1000 * multiplier)
   
    -- Flat linear scaling instead of exponential so the JSON array doesn't crash the 4.0MB DataStore limit!
    local feedReward = 5 + math.floor(completedQuests * 2)
    local pearlReward = 2 + math.floor(completedQuests * 1.5)


    -- If we have stored progress with pre-locked field keys, use those exactly.
    -- This prevents fishCount changes mid-quest from altering the tracked field(s).
    local selectedFields = nil
    if type(existingProgress) == "table" then
        local locked = {}
        for k, _ in pairs(existingProgress) do
            if k ~= "AbilitiesCommitted" and k ~= "SeaMinesPopped" then
                table.insert(locked, k)
            end
        end
        if #locked > 0 then
            selectedFields = locked
        end
    end


    if not selectedFields then
        -- No locked fields — pick fresh via deterministic RNG
        local rng = Random.new(userId + 12345)
       
        local possibleFields = {"Freshwater Reef", "Coral Reef", "Trash Reef", "Sun Reef"}
        if fishCount >= 5 then table.insert(possibleFields, "Runic Reef") end
        if fishCount >= 10 then table.insert(possibleFields, "Obsidian Reef") end
        if fishCount >= 15 then table.insert(possibleFields, "Coralline Reef") end
       
        -- Determine max reefs for this quest tier
        local maxReefs = 1
        if completedQuests >= 3 then maxReefs = 2 end
        if completedQuests >= 7 then maxReefs = 3 end
        maxReefs = math.min(maxReefs, #possibleFields)


        -- Pick primary field (same deterministic sequence as before)
        local lastField = nil
        local primaryField = possibleFields[1]
        for i = 0, completedQuests do
            local choices = {}
            for _, field in ipairs(possibleFields) do
                if field ~= lastField or #possibleFields <= 1 then
                    table.insert(choices, field)
                end
            end
            primaryField = choices[rng:NextInteger(1, #choices)]
            lastField = primaryField
        end


        -- Determine actual reef count via RNG
        local reefCount = 1
        if maxReefs >= 2 then
            local roll = rng:NextInteger(1, 3)
            if maxReefs == 2 then
                reefCount = (roll <= 1) and 1 or 2
            else
                reefCount = (roll == 1) and 1 or (roll == 2) and 2 or 3
            end
        end


        -- Pick secondary/tertiary fields
        selectedFields = {primaryField}
        if reefCount >= 2 then
            local pool = {}
            for _, f in ipairs(possibleFields) do
                if f ~= primaryField then table.insert(pool, f) end
            end
            local second = pool[rng:NextInteger(1, #pool)]
            table.insert(selectedFields, second)
           
            if reefCount >= 3 and #pool >= 2 then
                local pool2 = {}
                for _, f in ipairs(pool) do
                    if f ~= second then table.insert(pool2, f) end
                end
                if #pool2 > 0 then
                    table.insert(selectedFields, pool2[rng:NextInteger(1, #pool2)])
                end
            end
        end
    end


    -- Split algae goal evenly across all selected fields
    local perFieldGoal = math.floor(algaeGoal / #selectedFields)
    local goals = {["AbilitiesCommitted"] = abilityGoal}
    for _, field in ipairs(selectedFields) do
        goals[field] = perFieldGoal
    end


    -- Build description for dialogue
    local fieldDesc
    if #selectedFields == 1 then
        fieldDesc = string.format("%d Algae from %s", algaeGoal, selectedFields[1])
    elseif #selectedFields == 2 then
        fieldDesc = string.format("%d Algae from %s and %d from %s",
            perFieldGoal, selectedFields[1], perFieldGoal, selectedFields[2])
    else
        fieldDesc = string.format("%d Algae from %s, %d from %s, and %d from %s",
            perFieldGoal, selectedFields[1], perFieldGoal, selectedFields[2], perFieldGoal, selectedFields[3])
    end


    local qConfig = {
        Name = "Noobie Turtle's Challenge #" .. (completedQuests + 1),
        Type = "Collect",
        Goals = goals,
        Rewards = {
            BiomassAmount = biomassReward,
            Items = {
                ["Fish Feed"] = feedReward,
                ["Pearl"] = pearlReward
            }
        },
        Giver = "Noobie Turtle"
    }
    QuestConfig.Quests["NoobieTurtle"] = qConfig


    -- Dialogues
    QuestConfig.Dialogue["NoobieTurtle_Start"] = {
        Messages = {
            "Hello Fish Hatcher-er...",
            "I am Noobie Turtle!!",
            string.format("You have completed %d of my quests!", completedQuests),
            "I'll give you a quest that is randomized each time you get one!",
            "Each time you finish the quest, it gets harder!",
            string.format("Right now, I need %s, and %d abilities committed.", fieldDesc, abilityGoal),
        },
        QuestID = "NoobieTurtle"
    }
    QuestConfig.Dialogue["NoobieTurtle_InProgress"] = {
        Messages = {
            "You’ve completed %d of my quests so far!, but currently you have a quest from me!"
        }
    }
    QuestConfig.Dialogue["NoobieTurtle_Complete"] = {
        Messages = {
            "Here are your rewards! Try me again for a"
        },
        FinishQuestID = "NoobieTurtle"
    }
   
    return qConfig
end


return QuestConfig



