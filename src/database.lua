local Database = {}

Database.Materials = {
    ["Wind Essence"] = { Biome = "Windy", Signatures = {"wind", "essence", "windb", "windc"} },
    ["Icicle"]       = { Biome = "Snowy", Signatures = {"icicle", "snow", "ice"} },
    ["Rainy Bottle"] = { Biome = "Rainy", Signatures = {"rain", "bottle"} },
    ["Hour Glass"]   = { Biome = "Sandstorm", Signatures = {"hour", "glass", "hourglass", "sand"} },
    ["Eternal Flame"]= { Biome = "Hell", Signatures = {"eternal", "flame", "hell", "fire"} },
    ["Piece of Star"]= { Biome = "Starfall", Signatures = {"star", "meteor", "comet"} },
    ["Feather Vial"] = { Biome = "Heaven", Signatures = {"feather", "vial", "heaven"} },
    ["Curruptaine"]  = { Biome = "Corruption", Signatures = {"currupt", "corrupt", "corruptaine"} },
    ["NULL?"]        = { Biome = "Null", Signatures = {"null", "void", "null?"} }
}

Database.EnvironmentBlacklist = {
    "quest", "board", "shop", "store", "merchant", "stella", "jake",
    "bank", "cauldron", "altar", "portal", "teleport", "leaderboard",
    "turret", "clover", "four leaf", "luck buff", "offer", "required",
    "requires", "submit", "sacrifice", "talk", "speak", "chat",
    "memory match", "ready", "roll"
}

function Database.Match(text)
    local low = string.lower(tostring(text or ""))
    if low == "" then return nil, nil end

    if string.find(low, "feather", 1, true) or string.find(low, "vial", 1, true) or string.find(low, "heaven", 1, true) then
        return "Feather Vial", "Heaven"
    elseif string.find(low, "null", 1, true) or string.find(low, "void", 1, true) then
        return "NULL?", "Null"
    elseif string.find(low, "currupt", 1, true) or string.find(low, "corrupt", 1, true) then
        return "Curruptaine", "Corruption"
    elseif string.find(low, "eternal", 1, true) or string.find(low, "flame", 1, true) or string.find(low, "hell", 1, true) then
        return "Eternal Flame", "Hell"
    elseif (string.find(low, "star", 1, true) and not string.find(low, "start", 1, true))
        or string.find(low, "meteor", 1, true) or string.find(low, "comet", 1, true) then
        return "Piece of Star", "Starfall"
    elseif string.find(low, "wind", 1, true) or string.find(low, "essence", 1, true)
        or string.find(low, "windb", 1, true) or string.find(low, "windc", 1, true) then
        return "Wind Essence", "Windy"
    elseif string.find(low, "icicle", 1, true) or string.find(low, "snow", 1, true) or string.find(low, "ice", 1, true) then
        return "Icicle", "Snowy"
    elseif string.find(low, "hour", 1, true) or string.find(low, "glass", 1, true)
        or string.find(low, "hourglass", 1, true) or string.find(low, "sand", 1, true) then
        return "Hour Glass", "Sandstorm"
    elseif string.find(low, "rain", 1, true) or string.find(low, "bottle", 1, true) then
        return "Rainy Bottle", "Rainy"
    end

    return nil, nil
end

return Database
