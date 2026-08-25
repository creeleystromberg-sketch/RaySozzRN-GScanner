local Database = {}

Database.Materials = {
    ["Wind Essence"] = { Biome = "Windy" },
    ["Icicle"] = { Biome = "Snowy" },
    ["Rainy Bottle"] = { Biome = "Rainy" },
    ["Hour Glass"] = { Biome = "Sandstorm" },
    ["Eternal Flame"] = { Biome = "Hell" },
    ["Piece of Star"] = { Biome = "Starfall" },
    ["Feather Vial"] = { Biome = "Heaven" },
    ["Curruptaine"] = { Biome = "Corruption" },
    ["NULL?"] = { Biome = "Null" },
}

Database.EnvironmentBlacklist = {
    "quest", "board", "shop", "store", "merchant", "stella", "jake",
    "bank", "cauldron", "altar", "portal", "teleport", "leaderboard",
    "turret", "clover", "four leaf", "luck buff", "offer", "required",
    "requires", "submit", "sacrifice", "talk", "speak", "chat",
    "memory match", "ready", "roll",
}

local rules = {
    ["Wind Essence"] = {
        { "wind essence", 120 }, { "windb", 80 }, { "windc", 80 },
        { "essence", 35 }, { "wind", 8 },
    },
    ["Icicle"] = {
        { "icicle", 120 }, { "snowy", 15 }, { "snow", 10 }, { "ice", 8 },
    },
    ["Rainy Bottle"] = {
        { "rainy bottle", 120 }, { "rain bottle", 100 },
        { "bottle", 35 }, { "rainy", 12 }, { "rain", 8 },
    },
    ["Hour Glass"] = {
        { "hour glass", 120 }, { "hourglass", 120 },
        { "hour", 35 }, { "glass", 30 }, { "sandstorm", 8 }, { "sand", 5 },
    },
    ["Eternal Flame"] = {
        { "eternal flame", 140 }, { "eternal", 65 }, { "flame", 60 },
        { "hell", 12 }, { "fire", 10 },
    },
    ["Piece of Star"] = {
        { "piece of star", 140 }, { "starfall", 40 },
        { "meteor", 35 }, { "comet", 35 }, { "star", 12 },
    },
    ["Feather Vial"] = {
        { "feather vial", 140 }, { "feather", 60 }, { "vial", 50 }, { "heaven", 10 },
    },
    ["Curruptaine"] = {
        { "curruptaine", 160 }, { "corruptaine", 160 }, { "curruptain", 150 },
        { "corruptain", 150 }, { "currupt", 75 }, { "corrupt", 70 },
        { "corruption", 30 }, { "corrupted", 30 },
    },
    ["NULL?"] = {
        { "null?", 140 }, { "null", 70 }, { "void", 25 },
    },
}

function Database.Classify(values)
    local scores = {}
    for material in pairs(Database.Materials) do scores[material] = 0 end

    for _, value in ipairs(values or {}) do
        local text = string.lower(tostring(value or ""))
        if text ~= "" then
            for material, signatures in pairs(rules) do
                for _, signature in ipairs(signatures) do
                    if string.find(text, signature[1], 1, true) then
                        scores[material] += signature[2]
                    end
                end
            end
        end
    end

    local bestName, bestScore = nil, 0
    for material, score in pairs(scores) do
        if score > bestScore then bestName, bestScore = material, score end
    end
    if not bestName or bestScore < 10 then return nil, nil, 0 end
    return bestName, Database.Materials[bestName].Biome, bestScore
end

function Database.Match(text)
    local name, biome = Database.Classify({ text })
    return name, biome
end

return Database
