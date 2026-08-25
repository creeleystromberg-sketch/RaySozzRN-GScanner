local Players = game:GetService("Players")

local Visuals = {}
local player = Players.LocalPlayer

local activeVisuals = {}
local Movement = nil

function Visuals.Init(deps)
    Movement = deps.Movement
end

function Visuals.DestroyVisual(key)
    local visual = activeVisuals[key]
    if not visual then return end

    for _, obj in pairs(visual) do
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        end
    end
    activeVisuals[key] = nil
end

function Visuals.Clear()
    local keys = {}
    for key in pairs(activeVisuals) do table.insert(keys, key) end
    for _, key in ipairs(keys) do Visuals.DestroyVisual(key) end
end

local function createCard(billboard, name, biome)
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0
    card.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(220, 224, 232)
    stroke.Thickness = 1
    stroke.Transparency = 0.58
    stroke.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -14, 0, 25)
    nameLabel.Position = UDim2.fromOffset(7, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(248, 249, 251)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.Text = name .. " (" .. biome .. ")"
    nameLabel.TextWrapped = true
    nameLabel.Parent = card

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.Size = UDim2.new(1, -14, 0, 16)
    distanceLabel.Position = UDim2.fromOffset(7, 28)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(166, 172, 184)
    distanceLabel.TextSize = 11
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = card

    return card, nameLabel, distanceLabel
end

function Visuals.Create(entry, guiParent)
    local root = Movement and Movement.GetRoot()
    if not root or not entry.prompt or not entry.part then return end

    Visuals.DestroyVisual(entry.prompt)

    local sourceAtt = Instance.new("Attachment")
    sourceAtt.Name = "SolsTrackerSource"
    sourceAtt.Parent = root

    local targetAtt = Instance.new("Attachment")
    targetAtt.Name = "SolsTrackerTarget"
    targetAtt.Parent = entry.part

    local beam = Instance.new("Beam")
    beam.Name = "SolsTrackerBeam"
    beam.Attachment0 = sourceAtt
    beam.Attachment1 = targetAtt
    beam.Width0 = 1.1
    beam.Width1 = 0.7
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Brightness = 2.5
    beam.Segments = 24
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.15)
    })
    beam.Parent = root

    local highlight = Instance.new("Highlight")
    highlight.Name = "SolsTrackerHighlight"
    highlight.Adornee = entry.part:FindFirstAncestorOfClass("Model") or entry.part
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(235, 238, 244)
    highlight.FillTransparency = 0.88
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = guiParent

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SolsTrackerBillboard"
    billboard.Adornee = entry.part
    billboard.Size = UDim2.fromOffset(178, 50)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = guiParent

    local card, nameLabel, distanceLabel = createCard(billboard, entry.name, entry.biome)

    activeVisuals[entry.prompt] = {
        sourceAtt = sourceAtt,
        targetAtt = targetAtt,
        beam = beam,
        highlight = highlight,
        billboard = billboard,
        card = card,
        nameLabel = nameLabel,
        distanceLabel = distanceLabel,
        targetPart = entry.part
    }
end

function Visuals.Update(entries, guiParent)
    local activeMap = {}

    for _, entry in ipairs(entries) do
        activeMap[entry.prompt] = true
        local visual = activeVisuals[entry.prompt]

        if not visual or not visual.beam or not visual.beam.Parent or visual.targetPart ~= entry.part then
            Visuals.Create(entry, guiParent)
            visual = activeVisuals[entry.prompt]
        end

        if visual and visual.distanceLabel then
            visual.distanceLabel.Text = tostring(math.floor(entry.distance + 0.5)) .. " studs"
        end
        if visual and visual.nameLabel then
            visual.nameLabel.Text = entry.name .. " (" .. entry.biome .. ")"
        end
    end

    local stale = {}
    for prompt in pairs(activeVisuals) do
        if not activeMap[prompt] or not prompt.Parent then
            table.insert(stale, prompt)
        end
    end
    for _, prompt in ipairs(stale) do
        Visuals.DestroyVisual(prompt)
    end
end

return Visuals
