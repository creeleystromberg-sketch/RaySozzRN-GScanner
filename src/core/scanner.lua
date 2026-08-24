local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Scanner = {}
local player = Players.LocalPlayer

local cachedPrompts = {}
local scannedEntries = {}

local Database = nil
local Movement = nil

function Scanner.Init(deps)
    Database = deps.Database
    Movement = deps.Movement
end

local function containsBlacklistedWord(text)
    local normalized = string.lower(tostring(text or ""))
    for _, word in ipairs(Database.EnvironmentBlacklist) do
        if string.find(normalized, word, 1, true) then
            return true
        end
    end
    return false
end

local function isBlacklisted(instance, prompt)
    if not Database then return false end

    if prompt and (containsBlacklistedWord(prompt.ActionText) or containsBlacklistedWord(prompt.ObjectText)) then
        return true
    end

    local current = instance
    while current and current ~= Workspace and current ~= game do
        if containsBlacklistedWord(current.Name) then return true end
        current = current.Parent
    end

    return false
end

local function resolvePart(prompt, model, matchedInstance)
    if matchedInstance then
        if matchedInstance:IsA("BasePart") then return matchedInstance end
        if matchedInstance:IsA("SpecialMesh") and matchedInstance.Parent and matchedInstance.Parent:IsA("BasePart") then
            return matchedInstance.Parent
        end
    end

    if prompt.Parent and prompt.Parent:IsA("BasePart") then return prompt.Parent end
    if model then return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) end
    return prompt:FindFirstAncestorWhichIsA("BasePart")
end

local function matchText(text, prompt, model, matchedInstance)
    local name, biome = Database.Match(text)
    if not name then return nil, nil, nil end
    return name, biome, resolvePart(prompt, model, matchedInstance)
end

local function matchMetadata(instance, prompt, model)
    if not instance then return nil, nil, nil end

    local name, biome, part = matchText(instance.Name, prompt, model, instance)
    if name then return name, biome, part end

    for attributeName, attributeValue in pairs(instance:GetAttributes()) do
        name, biome, part = matchText(attributeName, prompt, model, instance)
        if name then return name, biome, part end

        name, biome, part = matchText(attributeValue, prompt, model, instance)
        if name then return name, biome, part end
    end

    for _, tag in ipairs(CollectionService:GetTags(instance)) do
        name, biome, part = matchText(tag, prompt, model, instance)
        if name then return name, biome, part end
    end

    return nil, nil, nil
end

function Scanner.Identify(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return nil, nil, nil
    end

    local model = prompt:FindFirstAncestorOfClass("Model")
    if isBlacklisted(prompt.Parent, prompt) then
        return nil, nil, nil
    end

    local name, biome, part = matchText(prompt.ObjectText, prompt, model)
    if name then return name, biome, part end

    name, biome, part = matchText(prompt.ActionText, prompt, model)
    if name then return name, biome, part end

    name, biome, part = matchMetadata(prompt, prompt, model)
    if name then return name, biome, part end

    local current = prompt.Parent
    while current and current ~= Workspace and current ~= game do
        name, biome, part = matchMetadata(current, prompt, model)
        if name then return name, biome, part end
        current = current.Parent
    end

    local modelIsSharedContainer = model and (model.Name == "SpawnedItems" or model.Name == "Workspace")
    if model and not modelIsSharedContainer then
        for _, descendant in ipairs(model:GetDescendants()) do
            name, biome, part = matchMetadata(descendant, prompt, model)
            if name then return name, biome, part end
        end
    elseif prompt.Parent then
        for _, descendant in ipairs(prompt.Parent:GetDescendants()) do
            name, biome, part = matchMetadata(descendant, prompt, model)
            if name then return name, biome, part end
        end
    end

    return nil, nil, nil
end

function Scanner.Scan()
    local root = Movement and Movement.GetRoot()
    if not root then return {} end

    local entries = {}
    local seen = {}

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled then
            local cached = cachedPrompts[descendant]
            if cached and (not cached.part or not cached.part.Parent) then
                cachedPrompts[descendant] = nil
                cached = nil
            end

            local name, biome, part
            if cached then
                name, biome, part = cached.name, cached.biome, cached.part
            else
                name, biome, part = Scanner.Identify(descendant)
                if name and biome and part then
                    cachedPrompts[descendant] = { name = name, biome = biome, part = part }
                end
            end

            if name and biome and part and not seen[descendant] then
                seen[descendant] = true
                table.insert(entries, {
                    prompt = descendant,
                    model = descendant:FindFirstAncestorOfClass("Model") or descendant.Parent,
                    part = part,
                    name = name,
                    biome = biome,
                    distance = (root.Position - part.Position).Magnitude
                })
            end
        end
    end

    for prompt in pairs(cachedPrompts) do
        if not prompt.Parent or not prompt.Enabled then cachedPrompts[prompt] = nil end
    end

    table.sort(entries, function(a, b)
        return a.distance < b.distance
    end)

    scannedEntries = entries
    return entries
end

function Scanner.GetEntries()
    return scannedEntries
end

return Scanner
