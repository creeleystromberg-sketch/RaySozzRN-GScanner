local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local UI = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local environment = getgenv and getgenv() or _G

local Config, Scanner, Visuals, Movement, Server
local gui, main, miniButton
local trackerEnabled = false
local materialRows = {}
local respawnConnection = nil
local promptTriggeredConnection = nil
local pickupAssistConnection = nil
local runToken = 0

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
    if environment.SolsTrackerCleanup then
        pcall(environment.SolsTrackerCleanup)
    end

    Config = deps.Config
    Scanner = deps.Scanner
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
    runToken += 1
    respawnConnection = player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 8)
        char:WaitForChild("Humanoid", 8)
        Movement.SetSpeed(Config.DefaultSpeed or 18)
        Visuals.Clear()
        Scanner.Invalidate()
        task.defer(function()
            local ok, entries = pcall(Scanner.Scan)
            if ok and trackerEnabled and gui and gui.Parent then
                pcall(Visuals.Update, entries, gui)
            end
        end)
    end)

    environment.SolsTrackerCleanup = function()
        trackerEnabled = false
        runToken += 1
        if respawnConnection then
            respawnConnection:Disconnect()
            respawnConnection = nil
        end
        if promptTriggeredConnection then
            promptTriggeredConnection:Disconnect()
            promptTriggeredConnection = nil
        end
        if pickupAssistConnection then
            pickupAssistConnection:Disconnect()
            pickupAssistConnection = nil
        end
        Scanner.Destroy()
        Visuals.Clear()
        if gui and gui.Parent then gui:Destroy() end
    end

    UI.ToggleTracker(true)
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
    local inspectorPage = makePage("Inspector")
    local playerPage = makePage("Player")
    local serverPage = makePage("Server")

    local matTab = makeTab("Materials", 7)
    local trackTab = makeTab("Tracker", 48)
    local playTab = makeTab("Player", 89)
    local servTab = makeTab("Server", 130)
    local inspectTab = makeTab("Inspector", 171)

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
    inspectTab.MouseButton1Click:Connect(function() showPage("Inspector") end)

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

    -- Build Tracker Page
    local trackBtn = Instance.new("TextButton")
    trackBtn.Size = UDim2.fromOffset(160, 36)
    trackBtn.Position = UDim2.fromOffset(0, 20)
    trackBtn.BackgroundColor3 = Color3.fromRGB(92, 68, 18)
    trackBtn.BorderSizePixel = 0
    trackBtn.Text = "TRACK ITEMS: ON"
    trackBtn.TextColor3 = Config.Colors.TextPrimary
    trackBtn.TextSize = 12
    trackBtn.Font = Enum.Font.GothamBold
    trackBtn.Parent = trackerPage
    uiCorner(trackBtn, 7)

    local navStatus = Instance.new("TextLabel")
    navStatus.Size = UDim2.new(1, 0, 0, 80)
    navStatus.Position = UDim2.fromOffset(0, 75)
    navStatus.BackgroundColor3 = Config.Colors.Surface
    navStatus.BorderSizePixel = 0
    navStatus.Text = Config.CalibrationMode
        and "Tracker active — broad calibration mode\nFull map refresh every 15 seconds."
        or "Tracker active\nE pickup assist: 15–100 studs.\nFull map refresh every 15 seconds."
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

    trackBtn.MouseButton1Click:Connect(function()
        UI.ToggleTracker()
        trackBtn.Text = trackerEnabled and "TRACK ITEMS: ON" or "TRACK ITEMS: OFF"
        trackBtn.BackgroundColor3 = trackerEnabled and Color3.fromRGB(92, 68, 18) or Color3.fromRGB(32, 35, 42)
    end)

    pickupAssistConnection = UserInputService.InputBegan:Connect(function(input)
        if not trackerEnabled or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode ~= (Config.RemotePickupKey or Enum.KeyCode.E) then return end

        local ok, pickedUp, message = pcall(Scanner.TryPickupNearest)
        if ok and pickedUp then
            navStatus.Text = "Pickup assist sent\n" .. tostring(message)
        elseif not ok then
            navStatus.Text = "Pickup assist error: " .. tostring(pickedUp)
        end
    end)

    -- Build Pickup Inspector Page
    local inspectStatus = Instance.new("TextLabel")
    inspectStatus.Size = UDim2.new(1, -176, 0, 34)
    inspectStatus.Position = UDim2.fromOffset(0, 0)
    inspectStatus.BackgroundTransparency = 1
    inspectStatus.Text = "Waiting for a ProximityPrompt interaction..."
    inspectStatus.TextColor3 = Config.Colors.TextSecondary
    inspectStatus.TextSize = 11
    inspectStatus.Font = Enum.Font.Gotham
    inspectStatus.TextXAlignment = Enum.TextXAlignment.Left
    inspectStatus.TextWrapped = true
    inspectStatus.Parent = inspectorPage

    local copyInspect = Instance.new("TextButton")
    copyInspect.Size = UDim2.fromOffset(82, 30)
    copyInspect.Position = UDim2.new(1, -170, 0, 2)
    copyInspect.BackgroundColor3 = Config.Colors.Accent
    copyInspect.BorderSizePixel = 0
    copyInspect.Text = "COPY"
    copyInspect.TextColor3 = Config.Colors.TextPrimary
    copyInspect.TextSize = 11
    copyInspect.Font = Enum.Font.GothamBold
    copyInspect.Parent = inspectorPage
    uiCorner(copyInspect, 6)

    local clearInspect = Instance.new("TextButton")
    clearInspect.Size = UDim2.fromOffset(82, 30)
    clearInspect.Position = UDim2.new(1, -82, 0, 2)
    clearInspect.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
    clearInspect.BorderSizePixel = 0
    clearInspect.Text = "CLEAR"
    clearInspect.TextColor3 = Config.Colors.TextPrimary
    clearInspect.TextSize = 11
    clearInspect.Font = Enum.Font.GothamBold
    clearInspect.Parent = inspectorPage
    uiCorner(clearInspect, 6)

    local inspectScroll = Instance.new("ScrollingFrame")
    inspectScroll.Size = UDim2.new(1, 0, 1, -42)
    inspectScroll.Position = UDim2.fromOffset(0, 42)
    inspectScroll.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
    inspectScroll.BorderSizePixel = 0
    inspectScroll.ScrollBarThickness = 5
    inspectScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    inspectScroll.CanvasSize = UDim2.fromOffset(0, 0)
    inspectScroll.Parent = inspectorPage
    uiCorner(inspectScroll, 8)

    local inspectPadding = Instance.new("UIPadding")
    inspectPadding.PaddingTop = UDim.new(0, 9)
    inspectPadding.PaddingBottom = UDim.new(0, 9)
    inspectPadding.PaddingLeft = UDim.new(0, 9)
    inspectPadding.PaddingRight = UDim.new(0, 9)
    inspectPadding.Parent = inspectScroll

    local inspectReport = Instance.new("TextLabel")
    inspectReport.Size = UDim2.fromOffset(490, 20)
    inspectReport.AutomaticSize = Enum.AutomaticSize.XY
    inspectReport.BackgroundTransparency = 1
    inspectReport.Text = "Interact with an item. Its internal prompt, model, attributes, tags, parts and colors will appear here."
    inspectReport.TextColor3 = Color3.fromRGB(205, 209, 218)
    inspectReport.TextSize = 11
    inspectReport.Font = Enum.Font.Code
    inspectReport.TextXAlignment = Enum.TextXAlignment.Left
    inspectReport.TextYAlignment = Enum.TextYAlignment.Top
    inspectReport.Parent = inspectScroll

    copyInspect.MouseButton1Click:Connect(function()
        local copied = Server.Copy(inspectReport.Text)
        inspectStatus.Text = copied and "Inspector report copied." or "Clipboard is unavailable in this executor."
    end)
    clearInspect.MouseButton1Click:Connect(function()
        inspectReport.Text = "Waiting for the next interaction..."
        inspectStatus.Text = "Inspector cleared."
    end)

    promptTriggeredConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
        if triggeringPlayer and triggeringPlayer ~= player then return end
        if not Scanner.IsCollectionPrompt(prompt) then return end
        local ok, report = pcall(Scanner.DescribePrompt, prompt)
        if ok then
            inspectReport.Text = report
            inspectStatus.Text = "Captured: " .. tostring(prompt.ObjectText ~= "" and prompt.ObjectText or prompt.ActionText)
            environment.SolsTrackerLastInspection = report
        else
            inspectStatus.Text = "Inspector failed: " .. tostring(report)
        end
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
        environment.SolsTrackerCleanup()
    end)

    showPage("Materials")

    -- Periodic UI Render Loop
    task.spawn(function()
        local token = runToken
        while gui.Parent and token == runToken do
            if trackerEnabled then
                local ok, entries = pcall(Scanner.Scan)
                if ok then
                    local renderOk, renderError = pcall(function()
                        Visuals.Update(entries, gui)
                        UI.RefreshMaterialRows(entries, matList, emptyLabel)
                    end)
                    local mode = Config.CalibrationMode and " — broad calibration mode" or ""
                    local scanWarning = Scanner.GetLastError and Scanner.GetLastError() or nil
                    if renderOk then
                        navStatus.Text = "Tracker active" .. mode .. "\nFound: " .. #entries
                            .. "\nE pickup assist: 15–100 studs."
                            .. (scanWarning and ("\nSkipped error: " .. scanWarning) or "\nFull refresh every 15 seconds.")
                    else
                        navStatus.Text = "Visual update error: " .. tostring(renderError)
                    end
                else
                    navStatus.Text = "Scan error: " .. tostring(entries)
                end
            end
            task.wait(Config.ScanInterval or 2.0)
        end
    end)
end

function UI.RefreshMaterialRows(entries, parentList, emptyLabel)
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
        name.Size = UDim2.new(1, -20, 0, 22)
        name.Position = UDim2.fromOffset(10, 6)
        name.BackgroundTransparency = 1
        name.Text = entry.name
        name.TextColor3 = Config.Colors.TextPrimary
        name.TextSize = 13
        name.Font = Enum.Font.GothamMedium
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Parent = row

        local det = Instance.new("TextLabel")
        det.Size = UDim2.new(1, -20, 0, 18)
        det.Position = UDim2.fromOffset(10, 28)
        det.BackgroundTransparency = 1
        det.Text = entry.biome .. " • " .. math.floor(entry.distance + 0.5) .. " studs"
        det.TextColor3 = Config.Colors.TextSecondary
        det.TextSize = 10
        det.Font = Enum.Font.Gotham
        det.TextXAlignment = Enum.TextXAlignment.Left
        det.Parent = row

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
