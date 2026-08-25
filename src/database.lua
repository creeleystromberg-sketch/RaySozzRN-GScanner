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
    "memory match", "ready", "roll", "potion", "speedpotion", "luckypotion",
    "hastepotion", "fortunepotion", "coin", "rune", "chest", "candy",
}

-- These can also appear only in attributes or CollectionService tags while the
-- visible prompt says merely "Pick up".
Database.PickupBlacklist = {
    "potion", "elixir", "tonic", "coin", "rune", "chest", "candy",
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
        { "bottle", 15 }, { "rainy", 12 }, { "rain", 8 },
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
        { "piece of star", 140 }, { "starfall", 15 },
        { "meteor", 25 }, { "comet", 25 }, { "star", 12 },
    },
    ["Feather Vial"] = {
        { "feather vial", 140 }, { "feather", 60 }, { "vial", 15 }, { "heaven", 10 },
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

local function normalizeWords(value)
    local normalized = string.lower(tostring(value or ""))
    normalized = string.gsub(normalized, "[^%w]+", " ")
    normalized = string.gsub(normalized, "%s+", " ")
    normalized = string.gsub(normalized, "^%s+", "")
    return string.gsub(normalized, "%s+$", "")
end

function Database.Classify(values)
    local scores = {}
    for material in pairs(Database.Materials) do scores[material] = 0 end

    local seenValues = {}

    for _, value in ipairs(values or {}) do
        local text = normalizeWords(value)
        if text ~= "" and not seenValues[text] then
            seenValues[text] = true
            local words = " " .. text .. " "
            local compactText = string.gsub(text, " ", "")
            for material, signatures in pairs(rules) do
                for _, signature in ipairs(signatures) do
                    local signatureWords = normalizeWords(signature[1])
                    local matched = string.find(words, " " .. signatureWords .. " ", 1, true) ~= nil
                    if not matched and string.find(signatureWords, " ", 1, true) then
                        local compactSignature = string.gsub(signatureWords, " ", "")
                        matched = compactSignature ~= "" and string.find(compactText, compactSignature, 1, true) ~= nil
                    end
                    if matched then
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
    -- Generic words such as "bottle", biome names and effect names are useful
    -- supporting evidence, but must never identify an item on their own.
    if not bestName or bestScore < 50 then return nil, nil, 0 end
    return bestName, Database.Materials[bestName].Biome, bestScore
end

function Database.Match(text)
    local name, biome = Database.Classify({ text })
    return name, biome
end

return Database
