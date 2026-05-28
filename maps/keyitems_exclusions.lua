return {
	excluded = S{
		-- Non-player KIs
		347, -- Dynamis Debugger
		811, -- Replay Debugger
		619, -- All-You-Can-Ride Pass
		
		-- Unknown fishing flags
		1980, -- Spiffy Synth. (4)
		1981, -- Spiffy Synth. (5)
		1991, -- Spiffy Synth. (7)
		1999, -- Spiffy Synth. (7)
		2006, -- Spiffy Synth. (6)
		2007, -- Spiffy Synth. (7)
		2015, -- Spiffy Synth. (7)
		2022, -- Spiffy Synth. (6)
		2023, -- Spiffy Synth. (7)
		2030, -- Spiffy Synth. (6)
		2031, -- Spiffy Synth. (7)
		2047, -- Spiffy Synth. (7)
		
		-- Magical Maps
		1866, -- map of Leujaoam Sanctum
		1867, -- map of the Training Grounds
		1868, -- map of Lebros Cavern
		1869, -- map of Ilrusi Atoll
		1870, -- map of Periqia
		1871, -- map of Nyzul Isle
		1873, --map of the Colosseum
		
		1875, -- map of Zhayolm Remnants
		1876, -- map of Arrapago Remnants
		1877, -- map of Bhaflau Remnants
		1878, -- map of Silver Sea Remnants
		
		1880, -- map of Everbloom Hollow
		1882, -- map of Ruhotz Silvermines
		1884, -- map of Ghoyu's Reverie
		
		2302, -- map of Rala Waterways [U]
		2303, -- map of Yorcia Weald [U]
		2304, -- map of Cirdas Caverns [U]
		2305, -- map of Outer Ra'Kaznar [U]
		
		-- Active Effects
		-- Mog Enhancements
		512, -- Moghancement: Fire
		513, -- Moghancement: Ice
		514, -- Moghancement: Wind
		515, -- Moghancement: Earth
		516, -- Moghancement: Lightning
		517, -- Moghancement: Water
		518, -- Moghancement: Light
		519, -- Moghancement: Dark
		520, -- Moghancement: Experience
		521, -- Moghancement: Gardening
		522, -- Moghancement: Desynthesis
		523, -- Moghancement: Fishing
		524, -- Moghancement: Woodworking
		525, -- Moghancement: Smithing
		526, -- Moghancement: Goldsmithing
		527, -- Moghancement: Clothcraft
		528, -- Moghancement: Leathercraft
		529, -- Moghancement: Bonecraft
		530, -- Moghancement: Alchemy
		531, -- Moghancement: Cooking
		532, -- Moghancement: Conquest
		533, -- Moghancement: Region
		534, -- Moghancement: Fishing
		535, -- Moghancement: San. Conquest
		536, -- Moghancement: Bas. Conquest
		537, -- Moghancement: Win. Conquest
		538, -- Moghancement: Money
		539, -- Moghancement: Campaign
		540, -- Moghancement: Money II
		541, -- Moghancement: Skill Gains
		542, -- Moghancement: Bounty
		543, -- Moghancement: Mandragora Mania
		544, -- Moglification: Fishing
		545, -- Moglification: Woodworking
		546, -- Moglification: Smithing
		547, -- Moglification: Goldsmithing
		548, -- Moglification: Clothcraft
		549, -- Moglification: Leathercraft
		550, -- Moglification: Bonecraft
		551, -- Moglification: Alchemy
		552, -- Moglification: Cooking
		553, -- Mega Moglification: Fishing
		554, -- Mega Moglification: Woodwork.
		555, -- Mega Moglification: Smithing
		556, -- Mega Moglification: Goldsmith.
		557, -- Mega Moglification: Clothcraft
		558, -- Mega Moglification: Leathrcrft.
		559, -- Mega Moglification: Bonecraft
		560, -- Mega Moglification: Alchemy
		561, -- Mega Moglification: Cooking
		562, -- Moglification: Experience Boost
		563, -- Moglification: Capacity Boost
		564, -- Moglification: Synergy Skill Gains
		565, -- Moglification: Furnace Duration
		566, -- Moglification: Resist Death
		567, -- Moglification: A.M.A.N. Trove

		2848, -- Moglification: Resist Sleep
		2849, -- Moglification: Resist Poison
		2850, -- Moglification: Resist Paralysis
		2852, -- Moglification: Resist Silence
		2853, -- Moglification: Resist Petrification
		2854, -- Moglification: Resist Virus
		2855, -- Moglification: Resist Curse

		-- Cheers
		2716, -- Cheer: Lamb
		2717, -- Cheer: Sheep
		2718, -- Cheer: Karakul
		2719, -- Cheer: Ram
		2720, -- Cheer: Sapling
		2721, -- Cheer: G. Fol. Treant
		2722, -- Cheer: R. Fol. Treant
		2723, -- Cheer: Baby Rabbit
		2724, -- Cheer: Rabbit
		2725, -- Cheer: White Rabbit
		2726, -- Cheer: Baby Lizard
		2727, -- Cheer: Lizard
		2728, -- Cheer: Alabaster Lizard
		2729, -- Cheer: Baby Cockatrice
		2730, -- Cheer: Cockatrice
		2731, -- Cheer: Ziz
		2732, -- Cheer: Baby Raptor
		2733, -- Cheer: Raptor
		2734, -- Cheer: Red Raptor
		2735, -- Cheer: Baby Eft
		2736, -- Cheer: Eft
		2737, -- Cheer: Tarichuk
		2738, -- Cheer: Dhalmel Calf
		2739, -- Cheer: Dhalmel
		2740, -- Cheer: Great Dhalmel
		2741, -- Cheer: Sea Monk Larva
		2742, -- Cheer: Sea Monk
		2743, -- Cheer: Blue Sea Monk
		2744, -- Cheer: Uragnite Youngling
		2745, -- Cheer: Uragnite
		2746, -- Cheer: Limascabra
		2747, -- Cheer: Immature Crab
		2748, -- Cheer: Crab
		2749, -- Cheer: Porter Crab
		2750, -- Cheer: Baby Colibri
		2751, -- Cheer: Colibri
		2752, -- Cheer: Toucalibri
		2753, -- Cheer: Coeurl Cub
		2754, -- Cheer: Coeurl
		2755, -- Cheer: Lynx
		2756, -- Cheer: Buffalo Calf
		2757, -- Cheer: Buffalo
		2758, -- Cheer: Mini Slime
		2759, -- Cheer: Slime
		2760, -- Cheer: Clot
		2761, -- Cheer: Hecteyes
		2762, -- Cheer: Tiny Bugard
		2763, -- Cheer: Bugard
		2764, -- Cheer: Abyssobugard
		2765, -- Cheer: Baby Adamantoise
		2766, -- Cheer: Adamantoise
		2767, -- Cheer: Great Adamantoise
		2768, -- Cheer: White Adamantoise
		2769, -- Cheer: Ferromantoise
		2770, -- Cheer: Great Ferromantoise
		2771, -- Cheer: Cluster
		2772, -- Cheer: Bomb
		2773, -- Cheer: Djinn
		2774, -- Cheer: Snoll
		2775, -- Cheer: Behemoth Cub
		2776, -- Cheer: Behemoth
		2777, -- Cheer: King Behemoth
		2778, -- Cheer: Elasmoth
		2779, -- Cheer: Skormoth
		2780, -- Cheer: Dragon Hatchling
		2781, -- Cheer: Wyvern
		2782, -- Cheer: Blue Wyvern
		2783, -- Cheer: Green Wyvern
		2784, -- Cheer: Abyssal Wyrm
		2785, -- Cheer: Lunar Wyrm
		2786, -- Cheer: Blazing Wyrm
		2787, -- Cheer: Pequetender
		2788, -- Cheer: Sabotender
		2789, -- Cheer: Jumbotender

		3202, -- Cheer: Mandragora Sproutling
		3203, -- Cheer: Mandragora
		3204, -- Cheer: Elder Mandragora
		3205, -- Cheer: Lycopodium
		3206, -- Cheer: Ake-Ome
		3207, -- Cheer: Adenium
		3208, -- Cheer: Elder Adenium
		3209, -- Cheer: Korrigan
		3210, -- Cheer: Pachypodium
		3211, -- Cheer: Citrullus
		
		-- Voidwatch
		366, -- crimson stratum abyssite
		367, -- crimson stratum abyssite II
		368, -- crimson stratum abyssite III
		369, -- crimson stratum abyssite IV
		370, -- indigo stratum abyssite
		371, -- indigo stratum abyssite II
		372, -- indigo stratum abyssite III
		373, -- indigo stratum abyssite IV
		374, -- jade stratum abyssite
		375, -- jade stratum abyssite II
		376, -- jade stratum abyssite III
		377, -- jade stratum abyssite IV
		
		1444, -- white stratum abyssite
		1445, -- white stratum abyssite II
		1446, -- white stratum abyssite III
		1447, -- ashen stratum abyssite
		1448, -- ashen stratum abyssite II
		1449, -- ashen stratum abyssite III
		1450, -- white stratum abyssite IV
		1451, -- white stratum abyssite V
		1452, -- white stratum abyssite VI
		
		1539, -- voidstone
		1540, -- voidstone
		1541, -- voidstone
		1542, -- voidstone
		1543, -- voidstone
		1544, -- voidstone
		
		1556, -- beguiling petrifact
		1557, -- seductive petrifact
		1558, -- maddening petrifact
		
		1805, -- void cluster
		
		2048, -- Voidwatch alarum
		
		2060, -- hyacinth stratum abyssite
		2062, -- amber stratum abyssite
		
		2065, -- Kupofried's corundum
		2066, -- Kupofried's corundum
		2067, -- Kupofried's corundum
		
		-- Abyssea
		1271, -- traverser stone
		1272, -- traverser stone
		1273, -- traverser stone
		1274, -- traverser stone
		1275, -- traverser stone
		1276, -- traverser stone

		1459, -- fragrant treant petal
		1460, -- fetid rafflesia stalk
		1461, -- decaying morbol tooth
		1462, -- turbid slime oil
		1463, -- venomous peiste claw
		1464, -- tattered hippogryph wing
		1465, -- cracked wivre horn
		1466, -- mucid Ahriman eyeball
		1467, -- twisted Tonberry crown
		1468, -- veinous hecteyes eyelid
		1469, -- torn bat wing
		1470, -- gory scorpion claw
		1471, -- mossy adamantoise shell
		1472, -- fat-lined cockatrice skin
		1473, -- sodden sandworm husk
		1474, -- luxuriant manticore mane
		1475, -- sticky gnat wing
		1476, -- overgrown mandragora flower
		1477, -- chipped sandworm tooth
		1478, -- marbled mutton chop
		1479, -- bloodied saber tooth
		1480, -- blood-smeared Gigas helm
		1481, -- glittering pixie choker
		1482, -- dented Gigas shield
		1483, -- warped Gigas armband
		1484, -- severed Gigas collar
		1485, -- pellucid fly eye
		1486, -- shimmering pixie pinion
		1487, -- smoldering crab shell
		1488, -- venomous wamoura feeler
		1489, -- bulbous crawler cocoon
		1490, -- distended chigoe abdomen
		1491, -- mucid worm segment
		1492, -- shriveled hecteyes stalk
		1493, -- blotched doomed tongue
		1494, -- cracked skeleton clavicle
		1495, -- writhing ghost finger
		1496, -- rusted hound collar
		1497, -- hollow dragon eye
		1498, -- bloodstained bugard fang
		1499, -- gnarled lizard nail
		1500, -- molted peiste skin
		1501, -- jagged apkallu beak
		1502, -- clipped bird wing
		1503, -- bloodied bat fur
		1504, -- glistening orobon liver
		1505, -- doffed Poroggo hat
		1506, -- scalding ironclad spike
		1507, -- blazing cluster soul
		1508, -- ingrown taurus nail
		1509, -- ossified gargouille hand
		1510, -- imbrued vampyr fang
		1511, -- glossy sea monk sucker
		1512, -- shimmering pugil scale
		1513, -- decayed dvergr tooth
		1514, -- pulsating soulflayer beard
		1515, -- chipped imp's olifant
		1516, -- warped smilodon choker
		1517, -- malodorous marid fur
		1518, -- broken iron giant spike
		1519, -- rusted chariot gear
		1520, -- steaming cerberus tongue
		1521, -- bloodied dragon ear
		1522, -- resplendent roc quill
		1523, -- warped iron giant nail
		1524, -- dented chariot shield
		1525, -- torn khimaira wing
		1526, -- begrimed dragon hide
		1527, -- decaying diremite fang
		1528, -- shattered iron giant chain
		1529, -- warped chariot plate
		1530, -- venomous hydra fang
		1531, -- vacant bugard eye
		1532, -- variegated uragnite shell
		1533, -- battle trophy: 1st echelon
		1534, -- battle trophy: 2nd echelon
		1535, -- battle trophy: 3rd echelon
		1536, -- battle trophy: 4th echelon
		1537, -- battle trophy: 5th echelon
		1538, -- crimson traverser stone

		1559, -- vat of martello fuel
		1560, -- fuel reservoir
		1561, -- empty fuel vat
		1562, -- cracked fuel reservoir
		1563, -- vial of lambent potion
		1564, -- clear demilune abyssite
		1565, -- colorful demilune abyssite
		1566, -- scarlet demilune abyssite
		1567, -- azure demilune abyssite
		1568, -- viridian demilune abyssite
		1569, -- anti-Abyssean grenade #01
		1570, -- anti-Abyssean grenade #02
		1571, -- anti-Abyssean grenade #03
		1572, -- rainbow pearl
		1573, -- chipped wind cluster
		1574, -- piece of dried ebony lumber
		1575, -- Captain Rashid's linkpearl
		1576, -- Captain Argus's linkpearl
		1577, -- Captain Helga's linkpearl
		1578, -- seal of the resistance
		1579, -- sunbeam fragment
		1580, -- Lugarhoo's eyeball
		1581, -- vial of purification agent (blk.)
		1582, -- vial of purification agent (brz.)
		1583, -- vial of purification agent (slv.)
		1584, -- vial of purification agent (gld.)
		1585, -- black-labeled vial
		1586, -- bronze-labeled vial
		1587, -- silver-labeled vial
		1588, -- gold-labeled vial
		1589, -- rainbow-colored linkpearl
		1590, -- grey abyssite
		1591, -- ripe starfruit
		1592, -- vial of flower-wower fertilizer
		1593, -- Tahrongi tree nut
		1594, -- bucket of compound compost
		1595, -- cup of Tahrongi cactus water
		1596, -- hastily scrawled poster
		1597, -- bloodied arrow
		1598, -- crimson bloodstone

		1600, -- pinch of moist Dangruf sulfur
		1601, -- Naji's gauger plate
		1602, -- Naji's linkpearl

		1609, -- torn recipe page
		1610, -- mineral gauge for dummies
		1611, -- tube of alchemical fertilizer
		1612, -- large memory fragment
		1613, -- large memory fragment
		1614, -- pulse martello repair pack
		1615, -- clone ward reinforcement pack
		1616, -- pack of outpost repair tools
		1617, -- Parradamo supply pack
		1618, -- Parradamo supply pack
		1619, -- Parradamo supply pack
		1620, -- Parradamo supply pack
		1621, -- Parradamo supply pack
		1622, -- gasponia stamen
		1623, -- rockhopper
		1624, -- phial of counteragent
		1625, -- damaged stewpot
		1626, -- Naruru's stewpot
		1627, -- magicked hempen sack
		1628, -- magicked flaxen sack
		1629, -- paralysis trap fluid
		1630, -- paralysis trap fluid bottle
		1631, -- weakening trap fluid
		1632, -- weakening trap fluid bottle
		1633, -- Iron Eater's pearlsack
		1635, -- medical supply chest
		1636, -- woodworker's belt
		1637, -- espionage pearlsack
		1638, -- chipped linkshell
		1639, -- grimy linkshell
		1640, -- cracked linkshell
		1641, -- pocket supply pack
		1642, -- standard supply pack
		1643, -- hefty supply pack
		1644, -- pack of molten slag
		1645, -- letter of receipt
		1646, -- smudged letter
		1647, -- yellow linkpearl
		1648, -- jester's hat
		1649, -- jade demilune abyssite
		1650, -- sapphire demilune abyssite
		1651, -- crimson demilune abyssite
		1652, -- emerald demilune abyssite
		1653, -- vermillion demilune abyssite
		1654, -- indigo demilune abyssite

		1702, -- EX-01 martello core
		1703, -- EX-02 martello core
		1704, -- EX-03 martello core
		1705, -- EX-04 martello core
		1706, -- EX-05 martello core
		1707, -- EX-06 martello core
		1708, -- EX-07 martello core

		1711, -- silver pocket watch
		1712, -- elegant gemstone
		1713, -- wivre egg
		1714, -- wivre egg
		1715, -- wivre egg
		1716, -- torch coal
		1717, -- subniveal mines
		1718, -- piece of sodden oak lumber
		1719, -- sodden linen cloth
		1720, -- dhorme khimaira's mane
		1721, -- Imperial pearl

		1733, -- pinch of pixie dust
		1734, -- wedding invitation
		1735, -- snoll reflector
		1736, -- frosted snoll reflector
		1737, -- experiment cheat sheet

		1758, -- frostbloom
		1759, -- frostbloom
		1760, -- frostbloom
		1761, -- moon pendant
		1762, -- wyvern egg
		1763, -- wyvern egg shell
		1764, -- Waugyl's claw
		1765, -- bottle of military ink
		1766, -- military ink package
		
		-- Mog Gardens
		2390, -- kaleidoscopic clam
		2391, -- glass pendulum
		
		2990 -- Chacharoon's sack of supplies
	},
	hidden = S{
		-- old events no longer playable
		3136, -- sheet of Shadow Lord tunes
		3181, -- tentacle touching ticket
		-- Crafting Shields
		1982, -- alchemist's argentum tome
		1983, -- alchemist's aurum tome
		1989, -- carpenter's argentum tome
		1990, -- carpenter's aurum tome
		1997, -- blacksmith's argentum tome
		1998, -- blacksmith's aurum tome
		2004, -- goldsmith's argentum tome
		2005, -- goldsmith's aurum tome
		2013, -- weaver's argentum tome
		2014, -- weaver's aurum tome
		2020, -- tanner's argentum tome
		2021, -- tanner's aurum tome
		2028, -- boneworker's argentum tome
		2029, -- boneworker's aurum tome
		2045, -- culinarian's argentum tome
		2046, -- culinarian's aurum tome
	},
}