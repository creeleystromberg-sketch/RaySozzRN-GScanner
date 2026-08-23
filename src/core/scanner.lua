local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

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

local function isBlacklisted(instance, prompt)
    if not Database then return false end
    
    if prompt then
        local action = string.lower(tostring(prompt.ActionText or ""))
        local object = string.lower(tostring(prompt.ObjectText or ""))
        for _, word in ipairs(Database.EnvironmentBlacklist) do
            if string.find(action, word, 1, true) or string.find(object, word, 1, true) then
                return true
            end
        end
    end

    local current = instance
    while current and current ~= Workspace and current ~= game do
        local name = string.lower(tostring(current.Name or ""))
        for _, word in ipairs(Database.EnvironmentBlacklist) do
            if string.find(name, word, 1, true) then
                return true
            end
        end
        current = current.Parent
    end

    return false
end

function Scanner.Identify(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return nil, nil, nil
    end

    local model = prompt:FindFirstAncestorOfClass("Model")
    if isBlacklisted(model or prompt.Parent, prompt) then
        return nil, nil, nil
    end

    -- 1. Check prompt ObjectText
    if prompt.ObjectText and prompt.ObjectText ~= "" then
        local name, biome = Database.Match(prompt.ObjectText)
        if name and biome then
            local part = prompt.Parent:IsA("BasePart") and prompt.Parent or (model and model.PrimaryPart) or prompt:FindFirstAncestorWhichIsA("BasePart")
            return name, biome, part
        end
    end

    -- 2. Check model name
    if model and model.Name ~= "Workspace" and model.Name ~= "Map" and model.Name ~= "SpawnedItems" then
        local name, biome = Database.Match(model.Name)
        if name and biome then
            local part = prompt.Parent:IsA("BasePart") and prompt.Parent or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            return name, biome, part
        end
    end

    -- 3. Check direct parent BasePart
    if prompt.Parent and prompt.Parent:IsA("BasePart") then
        local name, biome = Database.Match(prompt.Parent.Name)
        if name and biome then
            return name, biome, prompt.Parent
        end
    end

    -- 4. Deep search across child meshes/parts (Handles generic "Model" wrappers)
    if model then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                local name, biome = Database.Match(child.Name)
                if name and biome then
                    return name, biome, child
                end
            end
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
            local name, biome, part = Scanner.Identify(descendant)
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
