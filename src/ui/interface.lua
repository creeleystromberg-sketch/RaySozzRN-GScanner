local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local UI = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config, Scanner, Navigator, Collector, Visuals, Movement, Server
local gui, main, miniButton
local trackerConnection = nil
local trackerEnabled = false
local materialRows = {}

local function uiCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 7)
    c.Parent = parent
    return c
end

local function uiStroke(parent, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(72, 76, 86)
    s.Thickness = 1
    s.Transparency = transparency or 0.25
    s.Parent = parent
    return s
end

function UI.Init(deps)
    Config = deps.Config
    Scanner = deps.Scanner
    Navigator = deps.Navigator
    Collector = deps.Collector
    Visuals = deps.Visuals
    Movement = deps.Movement
    Server = deps.Server

    local oldGui = playerGui:FindFirstChild("SolsScanner_Modular")
    if oldGui then oldGui:Destroy() end

    gui = Instance.new("ScreenGui")
    gui.Name = "SolsScanner_Modular"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = playerGui

    UI.BuildMain()
    
    Movement.SetSpeed(Config.DefaultSpeed or 18)
    player.CharacterAdded:Connect(function(char)
        char:WaitForChild("Humanoid", 5)
        task.wait(0.2)
        Movement.SetSpeed(Config.DefaultSpeed or 18)
    end)

    if Config.AutoStartTracker then
        UI.ToggleTracker(true)
    end
end

function UI.BuildMain()
    main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(690, 430)
    main.Position = UDim2.new(0.5, -345, 0.5, -215)
    main.BackgroundColor3 = Config.Colors.Background
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    uiCorner(main, 10)
    uiStroke(main, Config.Colors.Border, 0.18)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Config.Colors.Surface
    header.BorderSizePixel = 0
    header.Parent = main
    uiCorner(header, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -120, 1, 0)
    title.Position = UDim2.fromOffset(14, 0)
    title.BackgroundTransparency = 1
    title.Text = "Sol's RNG Scanner"
    title.TextColor3 = Config.Colors.TextPrimary
    title.TextSize = 16
    title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local versionLabel = Instance.new("TextLabel")
    versionLabel.Size = UDim2.fromOffset(160, 18)
    versionLabel.Position = UDim2.fromOffset(150, 13)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Text = Config.Version .. " • " .. Config.Build
    versionLabel.TextColor3 = Config.Colors.TextSecondary
    versionLabel.TextSize = 10
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.Parent = header

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(30, 28)
    minBtn.Position = UDim2.new(1, -70, 0, 8)
    minBtn.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
    minBtn.BorderSizePixel = 0
    minBtn.Text = "–"
    minBtn.TextColor3 = Config.Colors.TextPrimary
    minBtn.TextSize = 17
    minBtn.Font = Enum.Font.GothamMedium
    minBtn.Parent = header
    uiCorner(minBtn, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(225, 120, 120)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamMedium
    closeBtn.Parent = header
    uiCorner(closeBtn, 6)

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.fromOffset(138, 370)
    sidebar.Position = UDim2.fromOffset(10, 50)
    sidebar.BackgroundColor3 = Color3.fromRGB(17, 18, 21)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    uiCorner(sidebar, 8)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -166, 1, -60)
    content.Position = UDim2.fromOffset(156, 50)
    content.BackgroundTransparency = 1
    content.Parent = main

    local pages = {}
    local tabButtons = {}

    local function makePage(name)
        local p = Instance.new("Frame")
        p.Name = name
        p.Size = UDim2.fromScale(1, 1)
        p.BackgroundTransparency = 1
        p.Visible = false
        p.Parent = content
        pages[name] = p
        return p
    end

    local function makeTab(name, y)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 35)
        b.Position = UDim2.fromOffset(6, y)
        b.BackgroundColor3 = Color3.fromRGB(23, 25, 30)
        b.BorderSizePixel = 0
        b.Text = name
        b.TextColor3 = Config.Colors.TextSecondary
        b.TextSize = 12
        b.Font = Enum.Font.GothamMedium
        b.Parent = sidebar
        uiCorner(b, 6)
        tabButtons[name] = b
        return b
    end

    local materialsPage = makePage("Materials")
    local trackerPage = makePage("Tracker")
    local playerPage = makePage("Player")
    local serverPage = makePage("Server")

    local matTab = makeTab("Materials", 7)
    local trackTab = makeTab("Tracker", 48)
    local playTab = makeTab("Player", 89)
    local servTab = makeTab("Server", 130)

    local function showPage(name)
        for pName, p in pairs(pages) do p.Visible = (pName == name) end
        for bName, b in pairs(tabButtons) do
            b.BackgroundColor3 = (bName == name) and Color3.fromRGB(34, 37, 44) or Color3.fromRGB(23, 25, 30)
            b.TextColor3 = (bName == name) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        end
    end

    matTab.MouseButton1Click:Connect(function() showPage("Materials") end)
    trackTab.MouseButton1Click:Connect(function() showPage("Tracker") end)
    playTab.MouseButton1Click:Connect(function() showPage("Player") end)
    servTab.MouseButton1Click:Connect(function() showPage("Server") end)

    -- Build Materials Page
    local matList = Instance.new("ScrollingFrame")
    matList.Size = UDim2.new(1, 0, 1, -20)
    matList.Position = UDim2.fromOffset(0, 10)
    matList.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
    matList.BorderSizePixel = 0
    matList.ScrollBarThickness = 4
    matList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    matList.CanvasSize = UDim2.fromOffset(0, 0)
    matList.Parent = materialsPage
    uiCorner(matList, 8)

    local matPadding = Instance.new("UIPadding")
    matPadding.PaddingTop = UDim.new(0, 7)
    matPadding.PaddingBottom = UDim.new(0, 7)
    matPadding.PaddingLeft = UDim.new(0, 7)
    matPadding.PaddingRight = UDim.new(0, 7)
    matPadding.Parent = matList

    local matLayout = Instance.new("UIListLayout")
    matLayout.Padding = UDim.new(0, 6)
    matLayout.SortOrder = Enum.SortOrder.LayoutOrder
    matLayout.Parent = matList

    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Size = UDim2.new(1, -10, 0, 42)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "No materials detected on map"
    emptyLabel.TextColor3 = Config.Colors.TextSecondary
    emptyLabel.TextSize = 12
    emptyLabel.Font = Enum.Font.Gotham
    emptyLabel.Parent = matList

    -- Build Tracker & AI Page
    local trackBtn = Instance.new("TextButton")
    trackBtn.Size = UDim2.fromOffset(160, 36)
    trackBtn.Position = UDim2.fromOffset(0, 20)
    trackBtn.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
    trackBtn.BorderSizePixel = 0
    trackBtn.Text = "TRACK ITEMS: OFF"
    trackBtn.TextColor3 = Config.Colors.TextPrimary
    trackBtn.TextSize = 12
    trackBtn.Font = Enum.Font.GothamBold
    trackBtn.Parent = trackerPage
    uiCorner(trackBtn, 7)

    local autoBtn = Instance.new("TextButton")
    autoBtn.Size = UDim2.fromOffset(160, 36)
    autoBtn.Position = UDim2.fromOffset(170, 20)
    autoBtn.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
    autoBtn.BorderSizePixel = 0
    autoBtn.Text = "AUTO-COLLECT: OFF"
    autoBtn.TextColor3 = Config.Colors.TextPrimary
    autoBtn.TextSize = 12
    autoBtn.Font = Enum.Font.GothamBold
    autoBtn.Parent = trackerPage
    uiCorner(autoBtn, 7)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.fromOffset(100, 36)
    stopBtn.Position = UDim2.fromOffset(340, 20)
    stopBtn.BackgroundColor3 = Config.Colors.AccentDanger
    stopBtn.BorderSizePixel = 0
    stopBtn.Text = "STOP AI"
    stopBtn.TextColor3 = Color3.fromRGB(229, 169, 173)
    stopBtn.TextSize = 12
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.Parent = trackerPage
    uiCorner(stopBtn, 7)

    local navStatus = Instance.new("TextLabel")
    navStatus.Size = UDim2.new(1, 0, 0, 80)
    navStatus.Position = UDim2.fromOffset(0, 75)
    navStatus.BackgroundColor3 = Config.Colors.Surface
    navStatus.BorderSizePixel = 0
    navStatus.Text = "AI: Idle\nReady for operations."
    navStatus.TextColor3 = Config.Colors.TextPrimary
    navStatus.TextSize = 12
    navStatus.Font = Enum.Font.Gotham
    navStatus.TextWrapped = true
    navStatus.TextXAlignment = Enum.TextXAlignment.Left
    navStatus.TextYAlignment = Enum.TextYAlignment.Top
    navStatus.Parent = trackerPage
    uiCorner(navStatus, 7)

    local statusPadding = Instance.new("UIPadding")
    statusPadding.PaddingTop = UDim.new(0, 10)
    statusPadding.PaddingLeft = UDim.new(0, 10)
    statusPadding.Parent = navStatus

    Navigator.SetStatusCallback(function(l1, l2, l3)
        local lines = { l1 }
        if l2 and l2 ~= "" then table.insert(lines, l2) end
        if l3 and l3 ~= "" then table.insert(lines, l3) end
        navStatus.Text = table.concat(lines, "\n")
    end)

    Collector.SetStatusCallback(function(l1, l2, l3)
        local lines = { l1 }
        if l2 and l2 ~= "" then table.insert(lines, l2) end
        if l3 and l3 ~= "" then table.insert(lines, l3) end
        navStatus.Text = table.concat(lines, "\n")
    end)

    trackBtn.MouseButton1Click:Connect(function()
        UI.ToggleTracker()
        trackBtn.Text = trackerEnabled and "TRACK ITEMS: ON" or "TRACK ITEMS: OFF"
        trackBtn.BackgroundColor3 = trackerEnabled and Color3.fromRGB(92, 68, 18) or Color3.fromRGB(32, 35, 42)
    end)

    autoBtn.MouseButton1Click:Connect(function()
        if Collector.IsAutoActive() then
            Collector.StopAutoQueue()
            autoBtn.Text = "AUTO-COLLECT: OFF"
            autoBtn.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
        else
            Collector.StartAutoQueue()
            autoBtn.Text = "AUTO-COLLECT: ON"
            autoBtn.BackgroundColor3 = Config.Colors.Accent
        end
    end)

    stopBtn.MouseButton1Click:Connect(function()
        Collector.StopAutoQueue()
        Navigator.Stop("Stopped manually.")
        autoBtn.Text = "AUTO-COLLECT: OFF"
        autoBtn.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
    end)

    -- Build Player Page
    local speedCard = Instance.new("Frame")
    speedCard.Size = UDim2.new(1, 0, 0, 70)
    speedCard.Position = UDim2.fromOffset(0, 20)
    speedCard.BackgroundColor3 = Config.Colors.Surface
    speedCard.BorderSizePixel = 0
    speedCard.Parent = playerPage
    uiCorner(speedCard, 8)

    local spdTitle = Instance.new("TextLabel")
    spdTitle.Size = UDim2.fromOffset(150, 24)
    spdTitle.Position = UDim2.fromOffset(12, 10)
    spdTitle.BackgroundTransparency = 1
    spdTitle.Text = "WalkSpeed"
    spdTitle.TextColor3 = Config.Colors.TextPrimary
    spdTitle.TextSize = 13
    spdTitle.Font = Enum.Font.GothamMedium
    spdTitle.TextXAlignment = Enum.TextXAlignment.Left
    spdTitle.Parent = speedCard

    local spdVal = Instance.new("TextLabel")
    spdVal.Size = UDim2.fromOffset(50, 28)
    spdVal.Position = UDim2.new(1, -140, 0, 20)
    spdVal.BackgroundTransparency = 1
    spdVal.Text = tostring(Config.DefaultSpeed)
    spdVal.TextColor3 = Config.Colors.TextPrimary
    spdVal.TextSize = 16
    spdVal.Font = Enum.Font.GothamMedium
    spdVal.Parent = speedCard

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.fromOffset(34, 30)
    minusBtn.Position = UDim2.new(1, -80, 0, 20)
    minusBtn.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
    minusBtn.BorderSizePixel = 0
    minusBtn.Text = "−"
    minusBtn.TextColor3 = Config.Colors.TextPrimary
    minusBtn.TextSize = 18
    minusBtn.Parent = speedCard
    uiCorner(minusBtn, 6)

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.fromOffset(34, 30)
    plusBtn.Position = UDim2.new(1, -40, 0, 20)
    plusBtn.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
    plusBtn.BorderSizePixel = 0
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Config.Colors.TextPrimary
    plusBtn.TextSize = 17
    plusBtn.Parent = speedCard
    uiCorner(plusBtn, 6)

    minusBtn.MouseButton1Click:Connect(function()
        local hum = Movement.GetHumanoid()
        if hum then
            local s = math.max(1, hum.WalkSpeed - 1)
            Movement.SetSpeed(s)
            spdVal.Text = tostring(s)
        end
    end)

    plusBtn.MouseButton1Click:Connect(function()
        local hum = Movement.GetHumanoid()
        if hum then
            local s = hum.WalkSpeed + 1
            Movement.SetSpeed(s)
            spdVal.Text = tostring(s)
        end
    end)

    -- Build Server Page
    local sInput = Instance.new("TextBox")
    sInput.Size = UDim2.new(1, 0, 0, 38)
    sInput.Position = UDim2.fromOffset(0, 20)
    sInput.BackgroundColor3 = Config.Colors.Surface
    sInput.BorderSizePixel = 0
    sInput.PlaceholderText = "Paste private server link / JobId..."
    sInput.PlaceholderColor3 = Color3.fromRGB(91, 96, 107)
    sInput.TextColor3 = Config.Colors.TextPrimary
    sInput.TextSize = 11
    sInput.Font = Enum.Font.Code
    sInput.ClearTextOnFocus = false
    sInput.Parent = serverPage
    uiCorner(sInput, 7)

    local sJoin = Instance.new("TextButton")
    sJoin.Size = UDim2.fromOffset(100, 34)
    sJoin.Position = UDim2.fromOffset(0, 68)
    sJoin.BackgroundColor3 = Config.Colors.Accent
    sJoin.BorderSizePixel = 0
    sJoin.Text = "JOIN"
    sJoin.TextColor3 = Config.Colors.TextPrimary
    sJoin.TextSize = 12
    sJoin.Font = Enum.Font.GothamBold
    sJoin.Parent = serverPage
    uiCorner(sJoin, 7)

    local sStatus = Instance.new("TextLabel")
    sStatus.Size = UDim2.new(1, -112, 0, 52)
    sStatus.Position = UDim2.fromOffset(112, 60)
    sStatus.BackgroundTransparency = 1
    sStatus.Text = "Waiting for link."
    sStatus.TextColor3 = Config.Colors.TextSecondary
    sStatus.TextSize = 11
    sStatus.Font = Enum.Font.Gotham
    sStatus.TextWrapped = true
    sStatus.TextXAlignment = Enum.TextXAlignment.Left
    sStatus.Parent = serverPage

    sJoin.MouseButton1Click:Connect(function()
        sStatus.Text = Server.HandleJoin(sInput.Text)
    end)

    -- Minimized Widget
    miniButton = Instance.new("TextButton")
    miniButton.Size = UDim2.fromOffset(44, 44)
    miniButton.Position = UDim2.new(0.5, -22, 0.5, -22)
    miniButton.BackgroundColor3 = Config.Colors.Surface
    miniButton.BorderSizePixel = 0
    miniButton.Text = "S"
    miniButton.TextColor3 = Config.Colors.TextPrimary
    miniButton.TextSize = 16
    miniButton.Font = Enum.Font.GothamBold
    miniButton.Visible = false
    miniButton.Active = true
    miniButton.Draggable = true
    miniButton.Parent = gui
    uiCorner(miniButton, 9)

    minBtn.MouseButton1Click:Connect(function() main.Visible = false miniButton.Visible = true end)
    miniButton.MouseButton1Click:Connect(function() miniButton.Visible = false main.Visible = true end)
    closeBtn.MouseButton1Click:Connect(function()
        UI.ToggleTracker(false)
        Collector.StopAutoQueue()
        Navigator.Stop()
        Visuals.Clear()
        gui:Destroy()
    end)

    showPage("Materials")

    -- Periodic UI Render Loop
    task.spawn(function()
        while gui.Parent do
            if trackerEnabled then
                local entries = Scanner.Scan()
                Visuals.Update(entries, gui)
                UI.RefreshMaterialRows(entries, matList, emptyLabel, function(entry)
                    showPage("Tracker")
                    Collector.CollectItem(entry)
                end)
            end
            task.wait(Config.ScanInterval or 0.35)
        end
    end)
end

function UI.RefreshMaterialRows(entries, parentList, emptyLabel, onGo)
    for _, row in pairs(materialRows) do
        if row and row.Parent then row:Destroy() end
    end
    materialRows = {}

    emptyLabel.Visible = (#entries == 0)

    for index, entry in ipairs(entries) do
        local row = Instance.new("Frame")
        row.Name = "Row_" .. index
        row.Size = UDim2.new(1, -4, 0, 56)
        row.BackgroundColor3 = Color3.fromRGB(19, 20, 24)
        row.BorderSizePixel = 0
        row.Parent = parentList
        uiCorner(row, 7)

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -120, 0, 22)
        name.Position = UDim2.fromOffset(10, 6)
        name.BackgroundTransparency = 1
        name.Text = entry.name
        name.TextColor3 = Config.Colors.TextPrimary
        name.TextSize = 13
        name.Font = Enum.Font.GothamMedium
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Parent = row

        local det = Instance.new("TextLabel")
        det.Size = UDim2.new(1, -120, 0, 18)
        det.Position = UDim2.fromOffset(10, 28)
        det.BackgroundTransparency = 1
        det.Text = entry.biome .. " • " .. math.floor(entry.distance + 0.5) .. " studs"
        det.TextColor3 = Config.Colors.TextSecondary
        det.TextSize = 10
        det.Font = Enum.Font.Gotham
        det.TextXAlignment = Enum.TextXAlignment.Left
        det.Parent = row

        local go = Instance.new("TextButton")
        go.Size = UDim2.fromOffset(60, 28)
        go.Position = UDim2.new(1, -70, 0.5, -14)
        go.BackgroundColor3 = Config.Colors.Accent
        go.BorderSizePixel = 0
        go.Text = "GO"
        go.TextColor3 = Config.Colors.TextPrimary
        go.TextSize = 11
        go.Font = Enum.Font.GothamBold
        go.Parent = row
        uiCorner(go, 6)

        go.MouseButton1Click:Connect(function()
            if onGo then onGo(entry) end
        end)

        table.insert(materialRows, row)
    end
end

function UI.ToggleTracker(state)
    trackerEnabled = (state ~= nil) and state or not trackerEnabled
    if not trackerEnabled then
        Visuals.Clear()
    end
end

return UI
