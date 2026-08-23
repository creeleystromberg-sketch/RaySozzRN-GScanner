local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Navigator = {}
local player = Players.LocalPlayer

local currentToken = 0
local isRunning = false
local currentTarget = nil

local Movement = nil
local Config = nil
local onStatusCallback = nil

function Navigator.Init(deps)
    Movement = deps.Movement
    Config = deps.Config
end

function Navigator.SetStatusCallback(callback)
    onStatusCallback = callback
end

local function notifyStatus(line1, line2, line3)
    if onStatusCallback then
        onStatusCallback(line1, line2, line3)
    end
end

local function glideToTarget(token, targetPosition, targetDistanceThreshold)
    local root = Movement.GetRoot()
    local char = player.Character
    if not root or not char then return false end

    -- Temporary NoClip & BodyVelocity stabilization
    local speed = Config.GlideSpeed or 35
    local started = os.clock()
    local reached = false

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = root

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.CFrame = root.CFrame
    bg.Parent = root

    local noclipConnection
    noclipConnection = RunService.Stepped:Connect(function()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    while os.clock() - started < 12 do
        if token ~= currentToken or not isRunning then break end
        if not root.Parent then break end

        local toTarget = targetPosition - root.Position
        local dist = toTarget.Magnitude

        if dist <= targetDistanceThreshold then
            reached = true
            break
        end

        bv.Velocity = toTarget.Unit * speed
        bg.CFrame = CFrame.new(root.Position, targetPosition)
        RunService.Heartbeat:Wait()
    end

    if noclipConnection then noclipConnection:Disconnect() end
    bv:Destroy()
    bg:Destroy()

    return reached
end

local function stepAlongPath(token, waypoints, targetPart, prompt)
    local root = Movement.GetRoot()
    local hum = Movement.GetHumanoid()
    if not root or not hum then return false end

    local activationDist = prompt and math.max(4.5, prompt.MaxActivationDistance) or (Config.ReachDistance or 4.0)

    for i = 2, #waypoints do
        if token ~= currentToken or not isRunning then return false end
        if not targetPart.Parent then return false end

        local wp = waypoints[i]
        local isJumpAction = (wp.Action == Enum.PathWaypointAction.Jump)

        local currentDist = (root.Position - targetPart.Position).Magnitude
        if currentDist <= activationDist - 0.5 then
            return true
        end

        notifyStatus("AI: Routing", "Waypoint " .. i .. "/" .. #waypoints, math.floor(currentDist) .. " studs left")
        hum:MoveTo(wp.Position)

        if isJumpAction then
            Movement.TryGroundedJump(0.8, 0)
        end

        local started = os.clock()
        local lastPos = root.Position
        local lastMoveTime = os.clock()

        while os.clock() - started < (Config.WaypointTimeout or 3.2) do
            if token ~= currentToken or not isRunning then return false end
            if not root.Parent or hum.Health <= 0 then return false end

            local flatDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(wp.Position.X, 0, wp.Position.Z)).Magnitude
            if flatDist <= 3.2 then break end

            if Movement.IsObstacleAhead(wp.Position) then
                Movement.TryGroundedJump(0.8, 0)
            end

            if (root.Position - lastPos).Magnitude >= 0.5 then
                lastPos = root.Position
                lastMoveTime = os.clock()
            elseif os.clock() - lastMoveTime >= 0.85 then
                -- Trigger jump on stuck
                Movement.TryGroundedJump(0.5, 0)
                lastMoveTime = os.clock()
            end

            task.wait(0.04)
        end
    end

    return (root.Position - targetPart.Position).Magnitude <= activationDist
end

function Navigator.GoTo(entry, onComplete)
    if not entry or not entry.part or not entry.part.Parent then
        notifyStatus("AI: Error", "Target does not exist.")
        return
    end

    currentToken += 1
    local token = currentToken
    isRunning = true
    currentTarget = entry

    task.spawn(function()
        local maxRepaths = Config.MaxRepaths or 6
        local activationDist = entry.prompt and math.max(4.5, entry.prompt.MaxActivationDistance) or 4.0

        for attempt = 1, maxRepaths do
            if token ~= currentToken or not isRunning then return end
            if not entry.part.Parent then
                Navigator.Stop("Target collected or lost.")
                return
            end

            local root = Movement.GetRoot()
            local hum = Movement.GetHumanoid()
            if not root or not hum or hum.Health <= 0 then
                Navigator.Stop("Character unavailable.")
                return
            end

            local currentDist = (root.Position - entry.part.Position).Magnitude
            if currentDist <= activationDist then
                notifyStatus("AI: Arrived", "At target: " .. entry.name)
                if onComplete then onComplete(entry) end
                return
            end

            notifyStatus("AI: Pathfinding", entry.name, "Attempt " .. attempt .. "/" .. maxRepaths)

            local path = PathfindingService:CreatePath({
                AgentRadius = 2.0,
                AgentHeight = 5.0,
                AgentCanJump = true,
                AgentJumpHeight = 8.0,
                AgentMaxSlope = 50.0,
                WaypointSpacing = 3.8
            })

            local ok, _ = pcall(function()
                path:ComputeAsync(root.Position, entry.part.Position)
            end)

            local reached = false
            if ok and path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                reached = stepAlongPath(token, waypoints, entry.part, entry.prompt)
            else
                -- Fallback: Hybrid Glide if path generation fails
                notifyStatus("AI: Obstacle bypass", "Gliding to " .. entry.name)
                reached = glideToTarget(token, entry.part.Position, activationDist - 0.5)
            end

            if token ~= currentToken or not isRunning then return end

            if reached then
                notifyStatus("AI: Arrived", "Target reached.")
                if onComplete then onComplete(entry) end
                return
            end

            task.wait(0.2)
        end

        Navigator.Stop("Route failed after max repaths.")
    end)
end

function Navigator.Stop(reason)
    currentToken += 1
    isRunning = false
    currentTarget = nil

    local hum = Movement and Movement.GetHumanoid()
    local root = Movement and Movement.GetRoot()
    if hum and root then
        hum:MoveTo(root.Position)
    end

    notifyStatus("AI: Idle", reason or "Navigation halted.")
end

function Navigator.IsRunning()
    return isRunning
end

return Navigator
