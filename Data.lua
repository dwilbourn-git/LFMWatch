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
    tank = "tank",
    healer = "healer", heals = "healer", heal = "healer",
    dps = "dps", dd = "dps",
}
Data.ROLE_ORDER = { "tank", "healer", "dps" }

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
Data.INSTANCES = {
    { "Ragefire Chasm", "dungeon", { "rfc" } },
    { "Hall of Thanes", "dungeon", { "hot", "halls of thanes" } },
    { "Wailing Caverns", "dungeon", { "wc" } },
    { "Ruins of Lordaeron", "dungeon", { "rol" } },
    { "The Deadmines", "dungeon", { "dm", "vc" } },
    { "Shadowfang Keep", "dungeon", { "sfk" } },
    { "Blackfathom Deeps", "dungeon", { "bfd" } },
    { "The Stockade", "dungeon", { "stocks", "stockades" } },
    { "Excavation Site: Wetlands", "dungeon", { "excavation", "exca" } },
    { "City of Dalaran", "dungeon", { "dalaran", "dala" } },
    { "Gnomeregan", "dungeon", { "gnomer" } },
    { "Razorfen Kraul", "dungeon", { "rfk" } },
    { "Scarlet Monastery: Graveyard", "dungeon", { "sm gy", "smgy", "gy", "sm", "scarlet monastery" } },
    { "Scarlet Monastery: Library", "dungeon", { "sm lib", "smlib", "lib", "sm", "scarlet monastery" } },
    { "Scarlet Monastery: Armory", "dungeon", { "sm arm", "smarm", "armory", "sm", "scarlet monastery" } },
    { "Scarlet Monastery: Cathedral", "dungeon", { "sm cath", "smcath", "cath", "sm", "scarlet monastery" } },
    { "Razorfen Downs", "dungeon", { "rfd" } },
    { "Uldaman", "dungeon", { "ulda", "uld" } },
    { "Zul'Farrak", "dungeon", { "zf", "zulfarrak" } },
    { "The Drowned City", "dungeon", {} },
    { "Krol'dok Stronghold", "dungeon", { "kroldok" } },
    { "Alcaz Prison", "dungeon", { "alcaz" } },
    { "Blackmaw Hold", "dungeon", { "blackmaw" } },
    { "Shaper's Terrace", "dungeon", { "shapers terrace" } },
    { "Sunken Temple", "dungeon", { "st", "sunken" } },
    { "Scholomance", "dungeon", { "scholo" } },
    { "Maraudon", "dungeon", { "mara" } },
    { "Dire Maul: East", "dungeon", { "dme", "dm east", "dire maul" } },
    { "Dire Maul: West", "dungeon", { "dmw", "dm west", "dire maul" } },
    { "Dire Maul: North", "dungeon", { "dmn", "dm north", "tribute", "dire maul" } },
    { "Stratholme: Living", "dungeon", { "strat live", "strat living", "strat", "stratholme" } },
    { "Stratholme: Undead", "dungeon", { "strat ud", "strat undead", "strat", "stratholme" } },
    { "Blackrock Depths", "dungeon", { "brd" } },
    { "Lower Blackrock Spire", "dungeon", { "lbrs" } },
    { "Upper Blackrock Spire", "dungeon", { "ubrs" } },

    { "Molten Core", "raid", { "mc" } },
    { "Onyxia's Lair", "raid", { "ony", "onyxia" } },
    { "Blackwing Lair", "raid", { "bwl" } },
    { "Zul'Gurub", "raid", { "zg", "zulgurub" } },
    { "Ruins of Ahn'Qiraj", "raid", { "aq20" } },
    { "Temple of Ahn'Qiraj", "raid", { "aq40" } },
    { "Naxxramas", "raid", { "naxx" } },
}
