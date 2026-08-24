local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local Navigator = {}
local player = Players.LocalPlayer
local currentToken = 0
local isRunning = false
local currentTarget = nil
local Movement, Config
local onStatusCallback = nil

function Navigator.Init(deps)
    Movement = deps.Movement
    Config = deps.Config
end

function Navigator.SetStatusCallback(callback)
    onStatusCallback = callback
end

local function notifyStatus(line1, line2, line3)
    if onStatusCallback then onStatusCallback(line1, line2, line3) end
end

local function isActive(token)
    return token == currentToken and isRunning
end

local function withinReach(root, targetPart, reachDistance)
    return (root.Position - targetPart.Position).Magnitude <= reachDistance
end

local function moveUntilReached(token, destination, targetPart, reachDistance, timeout, statusText)
    local root = Movement.GetRoot()
    local humanoid = Movement.GetHumanoid()
    if not root or not humanoid then return false end

    humanoid:MoveTo(destination)
    local startedAt = os.clock()
    local lastProgressAt = startedAt
    local lastPosition = root.Position
    local lastJumpTime = 0

    while os.clock() - startedAt < timeout do
        if not isActive(token) or not targetPart.Parent then return false end
        if not root.Parent or humanoid.Health <= 0 then return false end
        if withinReach(root, targetPart, reachDistance) then return true end

        if destination.Y - root.Position.Y > 1.3 or Movement.IsObstacleAhead(destination) then
            lastJumpTime = Movement.TryGroundedJump(0.8, lastJumpTime)
        end

        if (root.Position - lastPosition).Magnitude >= 0.5 then
            lastPosition = root.Position
            lastProgressAt = os.clock()
        elseif os.clock() - lastProgressAt > 0.8 then
            lastJumpTime = Movement.TryGroundedJump(0.8, lastJumpTime)
            humanoid:MoveTo(destination)
            lastProgressAt = os.clock()
        end

        notifyStatus(statusText, math.floor((root.Position - targetPart.Position).Magnitude) .. " studs left")
        task.wait(0.05)
    end

    return withinReach(root, targetPart, reachDistance)
end

local function followPath(token, waypoints, targetPart, reachDistance)
    for index = 2, #waypoints do
        if not isActive(token) or not targetPart.Parent then return false end
        local root = Movement.GetRoot()
        if not root then return false end

        local waypoint = waypoints[index]
        if waypoint.Action == Enum.PathWaypointAction.Jump
            or waypoint.Position.Y - root.Position.Y > 1.3
            or Movement.IsObstacleAhead(waypoint.Position) then
            Movement.TryGroundedJump(0.8, 0)
        end

        if moveUntilReached(
            token,
            waypoint.Position,
            targetPart,
            reachDistance,
            Config.WaypointTimeout or 3.2,
            "AI: Waypoint " .. index .. "/" .. #waypoints
        ) then
            return true
        end
    end

    local root = Movement.GetRoot()
    return root ~= nil and withinReach(root, targetPart, reachDistance)
end

local function directWalk(token, targetPart, reachDistance)
    notifyStatus("AI: Direct Walk", "Path unavailable; using ground movement.")
    local deadline = os.clock() + 12

    while os.clock() < deadline do
        if not isActive(token) or not targetPart.Parent then return false end
        local root = Movement.GetRoot()
        if not root then return false end
        if withinReach(root, targetPart, reachDistance) then return true end

        if moveUntilReached(token, targetPart.Position, targetPart, reachDistance, 1.0, "AI: Direct Walk") then
            return true
        end
    end

    return false
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
        local reachDistance = entry.prompt and math.max(4.5, entry.prompt.MaxActivationDistance)
            or (Config.ReachDistance or 3.5)

        for attempt = 1, maxRepaths do
            if not isActive(token) then return end
            if not entry.part.Parent then
                Navigator.Stop("Target collected or lost.")
                return
            end

            local root = Movement.GetRoot()
            local humanoid = Movement.GetHumanoid()
            if not root or not humanoid or humanoid.Health <= 0 then
                Navigator.Stop("Character unavailable.")
                return
            end

            if withinReach(root, entry.part, reachDistance) then
                isRunning = false
                notifyStatus("AI: Arrived", "At target: " .. entry.name)
                if onComplete then onComplete(entry) end
                return
            end

            notifyStatus("AI: Pathfinding", entry.name, "Attempt " .. attempt .. "/" .. maxRepaths)
            local path = PathfindingService:CreatePath({
                AgentRadius = 2.0,
                AgentHeight = 5.0,
                AgentCanJump = true,
                AgentJumpHeight = 7.5,
                AgentMaxSlope = 50.0,
                WaypointSpacing = 3.5
            })

            local computed = pcall(function()
                path:ComputeAsync(root.Position, entry.part.Position)
            end)

            local reached
            if computed and path.Status == Enum.PathStatus.Success then
                reached = followPath(token, path:GetWaypoints(), entry.part, reachDistance)
            else
                reached = directWalk(token, entry.part, reachDistance)
            end

            if not isActive(token) then return end
            if reached then
                isRunning = false
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

    local humanoid = Movement and Movement.GetHumanoid()
    local root = Movement and Movement.GetRoot()
    if humanoid and root then humanoid:MoveTo(root.Position) end
    notifyStatus("AI: Idle", reason or "Navigation halted.")
end

function Navigator.IsRunning()
    return isRunning
end

return Navigator
