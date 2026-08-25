local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Scanner = {}
local Database, Movement, Config
local knownPrompts, cachedPrompts, scannedEntries = {}, {}, {}
local connections = {}
local lastFullScan = 0

local function containsBlacklistedWord(text)
    local normalized = string.lower(tostring(text or ""))
    for _, word in ipairs(Database.EnvironmentBlacklist) do
        if string.find(normalized, word, 1, true) then return true end
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
    for attributeName, attributeValue in pairs(instance:GetAttributes()) do
        values[#values + 1] = attributeName
        values[#values + 1] = attributeValue
    end
    for _, tag in ipairs(CollectionService:GetTags(instance)) do values[#values + 1] = tag end
end

local function appearanceContainer(prompt, model)
    if model then
        local promptCount = 0
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then
                promptCount += 1
                if promptCount > 1 then break end
            end
        end
        if promptCount <= 1 then return model end
    end
    return resolvePart(prompt, model) or prompt.Parent
end

local function forEachAppearanceColor(container, callback)
    local function inspect(instance)
        if instance:IsA("BasePart") and instance.Transparency < 0.95 then
            callback(instance.Color)
        elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
            callback(instance.Color)
        elseif instance:IsA("Fire") then
            callback(instance.Color)
            callback(instance.SecondaryColor)
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
            for _, keypoint in ipairs(instance.Color.Keypoints) do callback(keypoint.Value) end
        end
    end

    inspect(container)
    for _, descendant in ipairs(container:GetDescendants()) do inspect(descendant) end
end

local function isWarmFlameColor(color)
    return color.R >= 0.65 and color.R > color.B * 1.35 and color.R > color.G * 1.04
end

local function looksLikeEternalFlame(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local warmColors = 0
    forEachAppearanceColor(container, function(color)
        if isWarmFlameColor(color) then warmColors += 1 end
    end)
    return warmColors > 0
end

local function looksLikeCurruptaine(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local purple, colored = 0, 0
    local candidates = container:IsA("BasePart") and { container } or container:GetDescendants()
    for _, instance in ipairs(candidates) do
        if instance:IsA("BasePart") and instance.Transparency < 0.95 then
            local color = instance.Color
            colored += 1
            if color.B > color.G * 1.25 and color.R > color.G * 1.05 then purple += 1 end
        end
    end
    return colored > 0 and purple / colored >= 0.45
end

local function looksLikeNullItem(prompt, model)
    if not isCollectionInteraction(prompt) then return false end
    local container = appearanceContainer(prompt, model)
    if not container then return false end
    local grayscale, colored, vivid = 0, 0, 0
    forEachAppearanceColor(container, function(color)
        local highest = math.max(color.R, color.G, color.B)
        local lowest = math.min(color.R, color.G, color.B)
        colored += 1
        if highest - lowest <= 0.12 and (color.R + color.G + color.B) / 3 <= 0.68 then
            grayscale += 1
        elseif highest >= 0.55 and highest - lowest >= 0.28 then
            vivid += 1
        end
    end)
    return colored > 0 and vivid == 0 and grayscale / colored >= 0.4
end

function Scanner.Identify(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled or isBlacklisted(prompt) then
        return nil, nil, nil
    end
    local model = prompt:FindFirstAncestorOfClass("Model")
    local part = resolvePart(prompt, model)
    if not part then return nil, nil, nil end

    local name, biome = Database.Classify({ prompt.ObjectText, prompt.ActionText })
    if name then return name, biome, part end
    if not isCollectionInteraction(prompt) then return nil, nil, nil end

    local values = {}
    appendMetadata(values, prompt)
    local current = prompt.Parent
    while current and current ~= Workspace and current ~= game do
        appendMetadata(values, current)
        if current == model then break end
        current = current.Parent
    end

    -- Only inspect the prompt's physical item. Scanning the full enclosing model
    -- mixes metadata when several spawned materials share one container.
    appendMetadata(values, part)
    for _, descendant in ipairs(part:GetDescendants()) do
        appendMetadata(values, descendant)
    end

    name, biome = Database.Classify(values)
    if name then return name, biome, part end
    if looksLikeEternalFlame(prompt, model) then return "Eternal Flame", "Hell", part end
    if looksLikeCurruptaine(prompt, model) then return "Curruptaine", "Corruption", part end
    if looksLikeNullItem(prompt, model) then return "NULL?", "Null", part end
    return nil, nil, nil
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
