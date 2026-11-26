-- LFMWatch default word lists. Data only.
-- Everything here is a first-run default: triggers and ignore words are copied
-- into saved variables once and then edited in /lfw; aliases are applied when
-- an instance is first seen in the journal.

local ADDON, ns = ...

local Data = {}
ns.Data = Data

-- A message must contain one of these (as a whole word or phrase) to count as
-- recruiting.
Data.TRIGGERS = {
    "lfm", "need", "looking for more", "last spot",
    "lf tank", "lf healer", "lf heals", "lf heal", "lf dps", "lf dd",
}
for n = 1, 9 do
    Data.TRIGGERS[#Data.TRIGGERS + 1] = "lf" .. n .. "m"
end

-- Added to the triggers when "Include LFG posts" is on.
Data.LFG_TRIGGERS = { "lfg", "looking for group" }

-- A message containing any of these never matches.
Data.IGNORE = { "wts", "wtb", "selling", "boost" }

-- Role words found in a message, and the role shown for each.
Data.ROLES = {
    tank = "tank", tanks = "tank",
    healer = "healer", healers = "healer", heals = "healer", heal = "healer", healz = "healer",
    dps = "dps", dd = "dps",
}
Data.ROLE_ORDER = { "tank", "healer", "dps" }

-- Class words found in a message, and the class shown for each.
Data.CLASSES = {
    warrior = "WARRIOR", warriors = "WARRIOR",
    paladin = "PALADIN", paladins = "PALADIN", pally = "PALADIN", pallys = "PALADIN", pala = "PALADIN",
    hunter = "HUNTER", hunters = "HUNTER",
    rogue = "ROGUE", rogues = "ROGUE",
    priest = "PRIEST", priests = "PRIEST",
    shaman = "SHAMAN", shamans = "SHAMAN", shammy = "SHAMAN", sham = "SHAMAN",
    mage = "MAGE", mages = "MAGE",
    warlock = "WARLOCK", warlocks = "WARLOCK", lock = "WARLOCK", locks = "WARLOCK",
    druid = "DRUID", druids = "DRUID",
}

-- The roles each class can fill. A role word next to a class word is read as
-- that class's role only when the class can do it ("druid healer"), so
-- "tank, mage, healer" stays three separate seats.
Data.CLASS_ROLES = {
    WARRIOR = { tank = true, dps = true },
    PALADIN = { tank = true, healer = true, dps = true },
    HUNTER = { dps = true },
    ROGUE = { dps = true },
    PRIEST = { healer = true, dps = true },
    SHAMAN = { tank = true, healer = true, dps = true },
    MAGE = { dps = true },
    WARLOCK = { dps = true },
    DRUID = { tank = true, healer = true, dps = true },
}

-- Words next to a class word that give its role.
Data.SPEC_HINTS = { resto = "healer", holy = "healer", prot = "tank" }

-- Roles named after one of these are already in the group ("have tank").
Data.HAVE_WORDS = { have = true, got = true, with = true }

-- Words that put the line back into "asking for" after a HAVE word.
Data.NEED_WORDS = { need = true, needs = true, lf = true, lfm = true, looking = true }

-- From a listed recruiter, with no trigger word: the group is full.
-- After a role word: that role is full ("dps full").
Data.FULL_WORDS = { full = true, filled = true }

-- Built-in dungeons and raids. This client has no Encounter Journal (probed
-- 2026-11-25: zero tiers, Blizzard_EncounterJournal reports WRONG_GAME_TYPE),
-- so the list is shipped here and can be added to by hand in /lfw.
--
-- Dungeon names: the dungeon list of the installed ForeverDungeonJournal
-- addon (names only). Raid names and all abbreviations: general
-- original-Classic knowledge, unverified on WoW Forever. Everything is a
-- default and stays editable.
--
-- Wings of one dungeon share a "Name: Wing" prefix and its general
-- abbreviation ("sm"); a message naming only the general one is reported
-- under the shared name.
-- The fourth field is the level range, lowest to highest. Dungeon ranges are
-- those shown by the ForeverDungeonJournal addon (its Looking For Group
-- ranges); raids are 60.
Data.INSTANCES = {
    { "Ragefire Chasm", "dungeon", { "rfc" }, { 13, 18 } },
    { "Hall of Thanes", "dungeon", { "hot", "halls of thanes" }, { 13, 20 } },
    { "Wailing Caverns", "dungeon", { "wc" }, { 15, 24 } },
    { "Ruins of Lordaeron", "dungeon", { "rol" }, { 15, 22 } },
    { "The Deadmines", "dungeon", { "dm", "vc" }, { 17, 26 } },
    { "Shadowfang Keep", "dungeon", { "sfk" }, { 20, 30 } },
    { "Blackfathom Deeps", "dungeon", { "bfd" }, { 24, 32 } },
    { "The Stockade", "dungeon", { "stocks", "stockades" }, { 24, 32 } },
    { "Excavation Site: Wetlands", "dungeon", { "excavation", "exca" }, { 26, 33 } },
    { "City of Dalaran", "dungeon", { "dalaran", "dala" }, { 28, 35 } },
    { "Gnomeregan", "dungeon", { "gnomer" }, { 29, 38 } },
    { "Razorfen Kraul", "dungeon", { "rfk" }, { 29, 38 } },
    { "Scarlet Monastery: Graveyard", "dungeon", { "sm gy", "smgy", "gy", "sm", "scarlet monastery" }, { 30, 38 } },
    { "Scarlet Monastery: Library", "dungeon", { "sm lib", "smlib", "lib", "sm", "scarlet monastery" }, { 33, 41 } },
    { "Scarlet Monastery: Armory", "dungeon", { "sm arm", "smarm", "armory", "sm", "scarlet monastery" }, { 36, 44 } },
    { "Scarlet Monastery: Cathedral", "dungeon", { "sm cath", "smcath", "cath", "sm", "scarlet monastery" }, { 38, 46 } },
    { "Razorfen Downs", "dungeon", { "rfd" }, { 37, 46 } },
    { "Uldaman", "dungeon", { "ulda", "uld" }, { 41, 51 } },
    { "Zul'Farrak", "dungeon", { "zf", "zulfarrak" }, { 44, 54 } },
    { "The Drowned City", "dungeon", {}, { 35, 42 } },
    { "Krol'dok Stronghold", "dungeon", { "kroldok" }, { 40, 47 } },
    { "Alcaz Prison", "dungeon", { "alcaz" }, { 48, 55 } },
    { "Blackmaw Hold", "dungeon", { "blackmaw" }, { 55, 60 } },
    { "Shaper's Terrace", "dungeon", { "shapers terrace" }, { 58, 60 } },
    { "Sunken Temple", "dungeon", { "st", "sunken" }, { 50, 60 } },
    { "Scholomance", "dungeon", { "scholo" }, { 58, 60 } },
    { "Maraudon", "dungeon", { "mara" }, { 46, 55 } },
    { "Dire Maul: East", "dungeon", { "dme", "dm east", "dire maul" }, { 54, 60 } },
    { "Dire Maul: West", "dungeon", { "dmw", "dm west", "dire maul" }, { 56, 60 } },
    { "Dire Maul: North", "dungeon", { "dmn", "dm north", "tribute", "dire maul" }, { 56, 60 } },
    { "Stratholme: Living", "dungeon", { "strat live", "strat living", "strat", "stratholme" }, { 58, 60 } },
    { "Stratholme: Undead", "dungeon", { "strat ud", "strat undead", "strat", "stratholme" }, { 58, 60 } },
    { "Blackrock Depths", "dungeon", { "brd" }, { 52, 60 } },
    { "Lower Blackrock Spire", "dungeon", { "lbrs" }, { 55, 60 } },
    { "Upper Blackrock Spire", "dungeon", { "ubrs" }, { 59, 60 } },

    { "Molten Core", "raid", { "mc" }, { 60, 60 } },
    { "Onyxia's Lair", "raid", { "ony", "onyxia" }, { 60, 60 } },
    { "Blackwing Lair", "raid", { "bwl" }, { 60, 60 } },
    { "Zul'Gurub", "raid", { "zg", "zulgurub" }, { 60, 60 } },
    { "Ruins of Ahn'Qiraj", "raid", { "aq20" }, { 60, 60 } },
    { "Temple of Ahn'Qiraj", "raid", { "aq40" }, { 60, 60 } },
    { "Naxxramas", "raid", { "naxx" }, { 60, 60 } },
}

-- Names the game's Legacy challenges use for an instance, where they differ
-- from the name above.
Data.LEGACY_NAMES = {
    ["Sunken Temple"] = { "Temple of Atal'Hakkar" },
    ["Stratholme: Living"] = { "Stratholme: Live" },
    ["Stratholme: Undead"] = { "Stratholme: Dead" },
}
