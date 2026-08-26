local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Scanner = {}
local Database, Movement, Config
local knownPrompts, cachedPrompts, scannedEntries = {}, {}, {}
local connections = {}
local lastFullScan = 0

local function usesBroadDetection()
    return Config and Config.CalibrationMode == true
end

local function containsBlacklistedWord(text)
    local normalized = string.lower(tostring(text or ""))
    for _, word in ipairs(Database.EnvironmentBlacklist) do
        if string.find(normalized, word, 1, true) then return true end
    end
    return false
end

local function containsExcludedPickup(values)
    for _, value in ipairs(values or {}) do
        local normalized = string.lower(tostring(value or ""))
        local words = " " .. string.gsub(normalized, "[^%w]+", " ") .. " "
        local compact = string.gsub(normalized, "[^%w]+", "")
        for _, word in ipairs(Database.PickupBlacklist or {}) do
            local exactWord = string.find(words, " " .. word .. " ", 1, true) ~= nil
            local consumableName = (word == "potion" or word == "elixir" or word == "tonic")
                and string.find(compact, word, 1, true) ~= nil
            if exactWord or consumableName then return true end
        end
    end
    return false
end

local function isBlacklisted(prompt)
    if containsBlacklistedWord(prompt.ActionText) or containsBlacklistedWord(prompt.ObjectText) then return true end
    local current = prompt.Parent
    while current and current ~= Workspace and current ~= game do
        if containsBlacklistedWord(current.Name) then return true end
        current = current.Parent
    end
    return false
end

local function isCollectionInteraction(prompt)
    local text = string.lower(tostring(prompt.ActionText or ""))
    for _, verb in ipairs({ "collect", "pick", "take", "grab", "obtain", "harvest" }) do
        if string.find(text, verb, 1, true) then return true end
    end
    return false
end

local function resolvePart(prompt, model)
    if prompt.Parent and prompt.Parent:IsA("BasePart") then return prompt.Parent end
    local ancestorPart = prompt:FindFirstAncestorWhichIsA("BasePart")
    if ancestorPart then return ancestorPart end
    if model then return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end

local function appendMetadata(values, instance)
    if not instance then return end
    values[#values + 1] = instance.Name
    if instance:IsA("StringValue") then values[#values + 1] = instance.Value end
    if instance:IsA("MeshPart") then
        values[#values + 1] = instance.MeshId
        values[#values + 1] = instance.TextureID
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Decal") or instance:IsA("Texture") then
        values[#values + 1] = instance.Texture
    end
    for attributeName, attributeValue in pairs(instance:GetAttributes()) do
        values[#values + 1] = attributeName
        values[#values + 1] = attributeValue
    end
    for _, tag in ipairs(CollectionService:GetTags(instance)) do values[#values + 1] = tag end
end

local function appearanceContainer(prompt, model)
    if model then
        local normalizedName = string.lower(string.gsub(model.Name, "[^%w]+", ""))
        local sharedNames = {
            spawneditems = true, items = true, itemspawns = true,
            itemspawn = true, pickups = true, drops = true, map = true,
        }
        local isSharedContainer = sharedNames[normalizedName]
            or string.find(normalizedName, "spawneditems", 1, true) ~= nil
            or string.find(normalizedName, "itemspawns", 1, true) ~= nil
        if isSharedContainer then
            return resolvePart(prompt, model) or prompt.Parent
        end

        local descendants = model:GetDescendants()
        local promptCount = 0
        for _, descendant in ipairs(descendants) do
            if descendant:IsA("ProximityPrompt") then
                promptCount += 1
                if promptCount > 1 then break end
            end
        end
        if promptCount <= 1 and #descendants <= 80 then return model end
    end
    return resolvePart(prompt, model) or prompt.Parent
end

local function connectedItemParts(part)
    if not part or not part:IsA("BasePart") then return {} end
    local ok, connected = pcall(function() return part:GetConnectedParts(true) end)
    if not ok or #connected > 24 then return {} end
    return connected
end

local function forEachLocalInstance(container, callback)
    local seen = {}
    local function inspectTree(root)
        if not root or seen[root] then return end
        seen[root] = true
        callback(root)
        for _, descendant in ipairs(root:GetDescendants()) do
            if not seen[descendant] then
                seen[descendant] = true
                callback(descendant)
            end
        end
    end

    inspectTree(container)
    if container:IsA("BasePart") then
        for _, connected in ipairs(connectedItemParts(container)) do inspectTree(connected) end
    end
end

local function hasNamedDetail(container, exactNames, prefixes)
    local matched = false
    forEachLocalInstance(container, function(instance)
        if matched then return end
        local normalized = string.lower(string.gsub(instance.Name, "[^%w]+", ""))
        if exactNames and exactNames[normalized] then
            matched = true
            return
        end
        for _, prefix in ipairs(prefixes or {}) do
            if string.match(normalized, "^" .. prefix .. "%d+$") then
                matched = true
                return
            end
        end
    end)
    return matched
end

local function forEachAppearanceColor(container, callback)
    local function inspect(instance)
        if instance:IsA("BasePart") and instance.Transparency < 0.95 then
            callback(instance.Color, instance)
        elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
            callback(instance.Color, instance)
        elseif instance:IsA("Fire") then
            callback(instance.Color, instance)
            callback(instance.SecondaryColor, instance)
        elseif instance:IsA("Smoke") then
            callback(instance.Color, instance)
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
            for _, keypoint in ipairs(instance.Color.Keypoints) do callback(keypoint.Value, instance) end
        elseif instance:IsA("Decal") or instance:IsA("Texture") then
            callback(instance.Color3, instance)
        end
    end

    forEachLocalInstance(container, inspect)
end

local function isWarmFlameColor(color)
    return color.R >= 0.65 and color.R - color.G >= 0.16 and color.R > color.B * 1.35
end

local function looksLikeEternalFlame(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local orangeSources, warmSources, coolBlueSources = {}, {}, {}
    forEachAppearanceColor(container, function(color, source)
        local isEffect = source:IsA("Fire") or source:IsA("ParticleEmitter")
            or source:IsA("Trail") or source:IsA("Beam")
            or source:IsA("PointLight") or source:IsA("SpotLight") or source:IsA("SurfaceLight")
            or (source:IsA("BasePart") and source.Material == Enum.Material.Neon)
        local isOrange = isWarmFlameColor(color) and color.G <= 0.62 and color.B <= 0.34
        if isEffect and isWarmFlameColor(color) then warmSources[source] = true end
        if isEffect and isOrange then orangeSources[source] = true end
        if color.B >= 0.32 and color.B > color.R * 1.08 and color.B >= color.G then
            coolBlueSources[source] = true
        end
    end)
    if usesBroadDetection() then
        return next(warmSources) ~= nil and next(coolBlueSources) == nil
    end
    return next(orangeSources) ~= nil and next(coolBlueSources) == nil
end

local function looksLikePieceOfStar(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end

    local yellowSources, coolBlueSources = {}, {}
    local yellowEmitter = false
    local starDetailNames = {
        star = true, stars = true, sparkle = true, sparkles = true,
        starmesh = true, stardecal = true, startexture = true,
        starparticle = true, starparticles = true,
    }
    local namedStarDetail = hasNamedDetail(container, starDetailNames, { "star", "sparkle" })
    forEachAppearanceColor(container, function(color, source)
        if color.R >= 0.62 and color.G >= 0.5 and color.B <= 0.48 then
            yellowSources[source] = true
            if source:IsA("ParticleEmitter") then yellowEmitter = true end
        elseif color.B >= 0.32 and color.B > color.R * 1.08 and color.B >= color.G then
            coolBlueSources[source] = true
        end
    end)
    local yellowCount, blueCount = 0, 0
    for _ in pairs(yellowSources) do yellowCount += 1 end
    for _ in pairs(coolBlueSources) do blueCount += 1 end
    if usesBroadDetection() then
        return namedStarDetail or (blueCount >= 1 and yellowCount >= 1)
    end
    return blueCount >= 1 and (namedStarDetail or yellowCount >= 2 or yellowEmitter)
end

local function looksLikeCurruptaine(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local purple, colored = 0, 0
    forEachLocalInstance(container, function(instance)
        if instance:IsA("BasePart") and instance.Transparency < 0.95 then
            local color = instance.Color
            colored += 1
            if color.B > color.G * 1.25 and color.R > color.G * 1.05 then purple += 1 end
        end
    end)
    return colored > 0 and purple / colored >= 0.45
end

local function looksLikeNullItem(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local namedNull = hasNamedDetail(container, {
        null = true, nullcube = true, voidcube = true,
        glitch = true, glitcheffect = true, glitchparticle = true,
    }, { "null", "glitch" })
    local grayscale, colored, vivid, grayCubes = 0, 0, 0, 0
    local darkEffectSources = {}
    forEachAppearanceColor(container, function(color, source)
        local highest = math.max(color.R, color.G, color.B)
        local lowest = math.min(color.R, color.G, color.B)
        local isGray = highest - lowest <= 0.12 and (color.R + color.G + color.B) / 3 <= 0.68
        colored += 1
        if isGray then
            grayscale += 1
        elseif highest >= 0.55 and highest - lowest >= 0.28 then
            vivid += 1
        end
        if source:IsA("BasePart") and isGray then
            local size = source.Size
            local shortest = math.max(math.min(size.X, size.Y, size.Z), 0.01)
            if math.max(size.X, size.Y, size.Z) / shortest <= 1.4 then grayCubes += 1 end
        end
        local isGlitchEffect = source:IsA("ParticleEmitter") or source:IsA("Trail") or source:IsA("Beam")
        if isGlitchEffect and highest <= 0.28 then darkEffectSources[source] = true end
    end)
    local structuralNull = grayCubes >= 1 and next(darkEffectSources) ~= nil
    if usesBroadDetection() then
        return colored > 0 and vivid == 0 and grayscale / colored >= 0.4
    end
    return colored > 0 and vivid == 0 and grayscale / colored >= 0.4 and (namedNull or structuralNull)
end

local function appearanceFeatures(prompt, model)
    local container = appearanceContainer(prompt, model)
    if not container then return nil end
    local features = {
        cyan = 0, deepBlue = 0, white = 0, gray = 0,
        gold = 0, brown = 0, effects = 0, smoke = 0,
        elongatedBlue = 0, elongatedGold = 0, roundCyan = 0,
    }
    forEachAppearanceColor(container, function(color, source)
        local highest = math.max(color.R, color.G, color.B)
        local lowest = math.min(color.R, color.G, color.B)
        if color.G >= 0.5 and color.B >= 0.5 and color.R <= 0.58 then features.cyan += 1 end
        if color.B >= 0.3 and color.B > color.R * 1.15 and color.B > color.G * 1.03 then features.deepBlue += 1 end
        if lowest >= 0.72 then features.white += 1 end
        if highest - lowest <= 0.13 and highest <= 0.72 then features.gray += 1 end
        if color.R >= 0.56 and color.G >= 0.34 and color.B <= 0.32 then features.gold += 1 end
        if color.R >= 0.18 and color.R <= 0.68 and color.R > color.G * 1.08
            and color.G > color.B * 1.04 then features.brown += 1 end
        if source:IsA("ParticleEmitter") or source:IsA("Smoke") or source:IsA("Trail")
            or source:IsA("Beam") then features.effects += 1 end
        if source:IsA("Smoke") then features.smoke += 1 end
        if source:IsA("BasePart") then
            local size = source.Size
            local shortest = math.max(math.min(size.X, size.Y, size.Z), 0.01)
            local aspect = math.max(size.X, size.Y, size.Z) / shortest
            if aspect >= 2.8 and (color.B >= 0.35 or color.G >= 0.5) then features.elongatedBlue += 1 end
            if aspect >= 2.8 and color.R >= 0.56 and color.G >= 0.34 and color.B <= 0.32 then
                features.elongatedGold += 1
            end
            if aspect <= 1.35 and color.G >= 0.48 and color.B >= 0.48 and color.R <= 0.62 then
                features.roundCyan += 1
            end
        end
    end)
    return features
end

local function looksLikeWindEssence(prompt, model)
    local f = appearanceFeatures(prompt, model)
    return f and f.cyan >= 1 and f.white >= 1 and f.effects >= 1
end

local function looksLikeRainyBottle(prompt, model)
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local f = appearanceFeatures(prompt, model)
    local namedWeather = hasNamedDetail(container, {
        rain = true, rainy = true, cloud = true, storm = true,
        raincloud = true, stormcloud = true, cloudmesh = true,
        rainparticle = true, raineffect = true, cloudparticle = true,
    }, { "rain", "cloud", "storm" })
    local strongCloudShape = f and f.deepBlue >= 2 and f.gray >= 2
    if usesBroadDetection() then
        return f and f.deepBlue >= 1 and f.gray >= 1 and f.effects >= 1
    end
    return f and f.deepBlue >= 1 and f.gray >= 1
        and (f.smoke >= 1 or namedWeather or strongCloudShape)
end

local function looksLikeIcicle(prompt, model)
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local f = appearanceFeatures(prompt, model)
    local namedIce = hasNamedDetail(container, {
        ice = true, icicle = true, iciclemesh = true,
        iceshard = true, icecrystal = true,
    }, { "icicle", "iceshard", "icecrystal" })
    if usesBroadDetection() then
        return f and (f.cyan >= 1 or f.deepBlue >= 1) and f.effects == 0
            and f.gold == 0 and f.brown <= 1
    end
    return f and (namedIce or f.elongatedBlue >= 1) and (f.cyan >= 1 or f.deepBlue >= 1)
        and f.roundCyan == 0 and f.effects == 0 and f.gold == 0 and f.brown <= 1
end

local function looksLikeFeatherVial(prompt, model)
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local f = appearanceFeatures(prompt, model)
    local namedFeather = hasNamedDetail(container, {
        feather = true, feathers = true, plume = true,
        feathermesh = true, featherdecal = true,
    }, { "feather", "plume" })
    if usesBroadDetection() then
        return f and f.gold >= 1 and f.white >= 1 and f.deepBlue == 0 and f.brown <= 1
    end
    return f and f.gold >= 1 and (namedFeather or (f.elongatedGold >= 1 and f.white >= 1))
        and f.deepBlue == 0 and f.brown <= 1
end

local function looksLikeHourGlass(prompt, model)
    local f = appearanceFeatures(prompt, model)
    if usesBroadDetection() then
        return f and f.gold >= 1 and f.brown >= 1 and f.cyan == 0 and f.deepBlue == 0
    end
    return f and f.gold >= 2 and f.brown >= 1 and f.cyan == 0 and f.deepBlue == 0
end

local function collectPromptMetadata(prompt, model, part)
    local values = {}
    appendMetadata(values, prompt)
    local current = prompt.Parent
    while current and current ~= Workspace and current ~= game do
        appendMetadata(values, current)
        if current == model then break end
        current = current.Parent
    end

    appendMetadata(values, part)
    for _, descendant in ipairs(part:GetDescendants()) do appendMetadata(values, descendant) end
    for _, connected in ipairs(connectedItemParts(part)) do
        appendMetadata(values, connected)
        for _, descendant in ipairs(connected:GetDescendants()) do appendMetadata(values, descendant) end
    end

    local localContainer = appearanceContainer(prompt, model)
    if localContainer and localContainer ~= part then
        appendMetadata(values, localContainer)
        for _, descendant in ipairs(localContainer:GetDescendants()) do appendMetadata(values, descendant) end
    end
    return values, localContainer
end

function Scanner.Identify(prompt, allowDisabled)
    if not prompt or not prompt:IsA("ProximityPrompt")
        or (not allowDisabled and not prompt.Enabled) or isBlacklisted(prompt) then
        return nil, nil, nil
    end
    local model = prompt:FindFirstAncestorOfClass("Model")
    local part = resolvePart(prompt, model)
    if not part then return nil, nil, nil end

    local name, biome = Database.Classify({ prompt.ObjectText, prompt.ActionText })
    if name then return name, biome, part end
    if not isCollectionInteraction(prompt) then return nil, nil, nil end

    -- Only inspect the prompt's local item/assembly, never every sibling in a
    -- shared SpawnedItems or Map container.
    local values = collectPromptMetadata(prompt, model, part)
    if containsExcludedPickup(values) then return nil, nil, nil end
    name, biome = Database.Classify(values)
    if name then return name, biome, part end
    if looksLikeEternalFlame(prompt, model) then return "Eternal Flame", "Hell", part end
    if looksLikePieceOfStar(prompt, model) then return "Piece of Star", "Starfall", part end
    if looksLikeCurruptaine(prompt, model) then return "Curruptaine", "Corruption", part end
    if looksLikeWindEssence(prompt, model) then return "Wind Essence", "Windy", part end
    if looksLikeRainyBottle(prompt, model) then return "Rainy Bottle", "Rainy", part end
    if looksLikeIcicle(prompt, model) then return "Icicle", "Snowy", part end
    if looksLikeFeatherVial(prompt, model) then return "Feather Vial", "Heaven", part end
    if looksLikeHourGlass(prompt, model) then return "Hour Glass", "Sandstorm", part end
    if looksLikeNullItem(prompt, model) then return "NULL?", "Null", part end
    return nil, nil, nil
end

local function safePath(instance)
    if not instance then return "<none>" end
    local ok, path = pcall(function() return instance:GetFullName() end)
    return ok and path or instance.Name
end

function Scanner.DescribePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return "No valid ProximityPrompt." end
    local model = prompt:FindFirstAncestorOfClass("Model")
    local part = resolvePart(prompt, model)
    local values, container = {}, nil
    if part then values, container = collectPromptMetadata(prompt, model, part) end
    local detectedName, detectedBiome = Scanner.Identify(prompt, true)
    local lines = {
        "SOL'S TRACKER PICKUP INSPECTOR",
        "ActionText: " .. tostring(prompt.ActionText),
        "ObjectText: " .. tostring(prompt.ObjectText),
        "Prompt: " .. safePath(prompt),
        "Part: " .. safePath(part),
        "Model: " .. safePath(model),
        "Enabled: " .. tostring(prompt.Enabled),
        "Environment blocked: " .. tostring(isBlacklisted(prompt)),
        "Pickup metadata blocked: " .. tostring(containsExcludedPickup(values)),
        "Tracker result: " .. (detectedName and (detectedName .. " (" .. detectedBiome .. ")") or "not classified"),
        "",
        "ANCESTORS:",
    }

    local current, ancestorCount = prompt.Parent, 0
    while current and current ~= game and ancestorCount < 14 do
        lines[#lines + 1] = string.format("- [%s] %s", current.ClassName, current.Name)
        if current == Workspace then break end
        current = current.Parent
        ancestorCount += 1
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "METADATA VALUES:"
    local seenValues = {}
    for _, value in ipairs(values) do
        local text = tostring(value)
        if text ~= "" and not seenValues[text] then
            seenValues[text] = true
            lines[#lines + 1] = "- " .. text
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "LOCAL INSTANCES:"
    local instanceCount = 0
    if container then
        forEachLocalInstance(container, function(instance)
            if instanceCount >= 60 then return end
            if instance:IsA("BasePart") then
                local color = instance.Color
                local assetInfo = ""
                if instance:IsA("MeshPart") then
                    assetInfo = " | Mesh " .. tostring(instance.MeshId) .. " | Texture " .. tostring(instance.TextureID)
                end
                lines[#lines + 1] = string.format(
                    "- [%s] %s | RGB %d,%d,%d | Size %.2f,%.2f,%.2f | %s%s",
                    instance.ClassName, instance.Name,
                    math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5),
                    instance.Size.X, instance.Size.Y, instance.Size.Z, tostring(instance.Material), assetInfo
                )
                instanceCount += 1
            elseif instance:IsA("ParticleEmitter") or instance:IsA("Smoke") or instance:IsA("Fire")
                or instance:IsA("Trail") or instance:IsA("Beam") or instance:IsA("Decal")
                or instance:IsA("Texture") then
                local texture = ""
                if instance:IsA("ParticleEmitter") or instance:IsA("Decal") or instance:IsA("Texture") then
                    texture = " | Texture " .. tostring(instance.Texture)
                end
                lines[#lines + 1] = string.format("- [%s] %s%s", instance.ClassName, instance.Name, texture)
                instanceCount += 1
            end
        end)
    end
    if instanceCount == 0 then lines[#lines + 1] = "- none captured" end
    return table.concat(lines, "\n")
end

function Scanner.IsCollectionPrompt(prompt)
    return prompt and prompt:IsA("ProximityPrompt") and isCollectionInteraction(prompt)
end

local function register(instance)
    if instance:IsA("ProximityPrompt") then
        knownPrompts[instance] = true
        cachedPrompts[instance] = nil
    end
end

function Scanner.FullRescan()
    knownPrompts = {}
    cachedPrompts = {}
    for _, descendant in ipairs(Workspace:GetDescendants()) do register(descendant) end
    lastFullScan = os.clock()
end

function Scanner.Init(deps)
    Database, Movement, Config = deps.Database, deps.Movement, deps.Config
    for _, connection in ipairs(connections) do connection:Disconnect() end
    connections = {
        Workspace.DescendantAdded:Connect(register),
        Workspace.DescendantRemoving:Connect(function(instance)
            if instance:IsA("ProximityPrompt") then
                knownPrompts[instance], cachedPrompts[instance] = nil, nil
            end
        end),
    }
end

function Scanner.Invalidate()
    cachedPrompts = {}
    lastFullScan = 0
end

function Scanner.Scan(forceFull)
    local root = Movement and Movement.GetRoot()
    if not root then return {} end
    local interval = (Config and Config.FullRescanInterval) or 15
    if forceFull or lastFullScan == 0 or os.clock() - lastFullScan >= interval then Scanner.FullRescan() end

    local entries = {}
    for prompt in pairs(knownPrompts) do
        if not prompt.Parent or not prompt.Enabled then
            knownPrompts[prompt], cachedPrompts[prompt] = nil, nil
        else
            local cached = cachedPrompts[prompt]
            if cached and not cached.ignored and (not cached.part or not cached.part.Parent) then cached = nil end
            if not cached then
                local name, biome, part = Scanner.Identify(prompt)
                if name and biome and part then
                    cached = { name = name, biome = biome, part = part }
                else
                    cached = { ignored = true }
                end
                cachedPrompts[prompt] = cached
            end
            if cached and not cached.ignored then
                entries[#entries + 1] = {
                    prompt = prompt,
                    model = prompt:FindFirstAncestorOfClass("Model") or prompt.Parent,
                    part = cached.part,
                    name = cached.name,
                    biome = cached.biome,
                    distance = (root.Position - cached.part.Position).Magnitude,
                }
            end
        end
    end
    table.sort(entries, function(a, b) return a.distance < b.distance end)
    scannedEntries = entries
    return entries
end

function Scanner.GetEntries()
    return scannedEntries
end

function Scanner.Destroy()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    connections = {}
    knownPrompts, cachedPrompts, scannedEntries = {}, {}, {}
end

return Scanner
