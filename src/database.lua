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

-- Captured from the user's live Pickup Inspector reports. Shared bottle/cork
-- assets are intentionally absent: only details unique to a material are used.
local fingerprintRules = {
    { Name = "Curruptaine", Any = { "867619398" } },
    { Name = "NULL?", All = { "17052637850" }, None = { "867619398", "neon" } },
    { Name = "Hour Glass", Any = {
        "103487498368597", "134010476647720", "86908839056700", "139156179732082",
    } },
    { Name = "Eternal Flame", Any = {
        "17404800093", "17404800094", "17404800095", "17404846378",
    } },
    { Name = "Piece of Star", Any = { "17405368318", "6909741538" } },
    { Name = "Rainy Bottle", Any = {
        "17405284614", "17405360386", "17405505478",
    } },
    { Name = "Icicle", Any = { "17413674509" } },
    { Name = "Feather Vial", Any = { "439102658" } },
    { Name = "Wind Essence", Any = { "windb", "windc", "windglow" } },
}

local function valueTokens(values)
    local tokens = {}
    for _, value in ipairs(values or {}) do
        local text = string.lower(tostring(value or ""))
        local compact = string.gsub(text, "[^%w]+", "")
        if text ~= "" then tokens[text] = true end
        if compact ~= "" then tokens[compact] = true end
        for word in string.gmatch(text, "%w+") do tokens[word] = true end
    end
    return tokens
end

local function containsAny(tokens, expected)
    for _, token in ipairs(expected or {}) do
        if tokens[token] then return true end
    end
    return false
end

local function containsAll(tokens, expected)
    for _, token in ipairs(expected or {}) do
        if not tokens[token] then return false end
    end
    return true
end

function Database.MatchFingerprint(values)
    local tokens = valueTokens(values)
    for _, rule in ipairs(fingerprintRules) do
        local anyMatches = not rule.Any or containsAny(tokens, rule.Any)
        local allMatches = not rule.All or containsAll(tokens, rule.All)
        local noneMatches = not rule.None or not containsAny(tokens, rule.None)
        if anyMatches and allMatches and noneMatches then
            return rule.Name, Database.Materials[rule.Name].Biome, 1000
        end
    end
    return nil, nil, 0
end

function Database.IsExcludedPickup(values)
    local tokens = valueTokens(values)
    return tokens.casing == true and tokens.liquid == true and tokens.top == true
end

local function normalizeWords(value)
    local normalized = string.lower(tostring(value or ""))
    normalized = string.gsub(normalized, "[^%w]+", " ")
    normalized = string.gsub(normalized, "%s+", " ")
    normalized = string.gsub(normalized, "^%s+", "")
    return string.gsub(normalized, "%s+$", "")
end

function Database.Classify(values)
    if Database.BroadMode then
        local broadScores = {}
        for material in pairs(Database.Materials) do broadScores[material] = 0 end
        for _, value in ipairs(values or {}) do
            local text = string.lower(tostring(value or ""))
            for material, signatures in pairs(rules) do
                for _, signature in ipairs(signatures) do
                    if string.find(text, string.lower(signature[1]), 1, true) then
                        broadScores[material] += signature[2]
                    end
                end
            end
        end
        local broadName, broadScore = nil, 0
        for material, score in pairs(broadScores) do
            if score > broadScore then broadName, broadScore = material, score end
        end
        if not broadName or broadScore < 10 then return nil, nil, 0 end
        return broadName, Database.Materials[broadName].Biome, broadScore
    end

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
