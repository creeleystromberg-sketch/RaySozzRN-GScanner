local PathfindingService = game:GetService("PathfindingService")

local Navigator = {}
local currentToken = 0
local isRunning = false
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

local function distanceToTarget(root, targetPart)
    return (root.Position - targetPart.Position).Magnitude
end

local function moveToWaypoint(token, waypoint, waypointIndex, waypointCount, targetPart, reachDistance, isPathBlocked)
    local root = Movement.GetRoot()
    local humanoid = Movement.GetHumanoid()
    if not root or not humanoid then return "failed" end

    local initialDirection = Vector3.new(
        waypoint.Position.X - root.Position.X,
        0,
        waypoint.Position.Z - root.Position.Z
    )
    local waypointJumpPending = waypoint.Action == Enum.PathWaypointAction.Jump
    if not waypointJumpPending
        and initialDirection.Magnitude > 0.1
        and not Movement.IsDirectionSafe(initialDirection, math.min(initialDirection.Magnitude, 3.0)) then
        humanoid:MoveTo(root.Position)
        return "repath"
    end

    humanoid.AutoRotate = true
    humanoid:MoveTo(waypoint.Position)

    local startedAt = os.clock()
    local lastProgressAt = startedAt
    local lastPosition = root.Position
    local lastJumpTime = 0
    local recoveryJumps = 0

    while os.clock() - startedAt < (Config.WaypointTimeout or 3.2) do
        if not isActive(token) or not targetPart.Parent then return "cancelled" end
        if not root.Parent or humanoid.Health <= 0 then return "failed" end
        if distanceToTarget(root, targetPart) <= reachDistance then return "target" end
        if isPathBlocked(waypointIndex) then return "repath" end

        local flatOffset = Vector3.new(
            waypoint.Position.X - root.Position.X,
            0,
            waypoint.Position.Z - root.Position.Z
        )
        if flatOffset.Magnitude <= 2.0 and math.abs(waypoint.Position.Y - root.Position.Y) <= 4.0 then
            return "waypoint"
        end

        if humanoid.FloorMaterial ~= Enum.Material.Air
            and not waypointJumpPending
            and flatOffset.Magnitude > 0.1
            and not Movement.IsDirectionSafe(flatOffset, math.min(flatOffset.Magnitude, 3.0)) then
            humanoid:MoveTo(root.Position)
            return "repath"
        end

        local obstacleAhead = Movement.IsObstacleAhead(waypoint.Position)
        if waypointJumpPending
            or waypoint.Position.Y - root.Position.Y > 1.3
            or obstacleAhead then
            local jumpTime = Movement.TryGroundedJump(0.8, lastJumpTime, waypoint.Position)
            if waypointJumpPending and jumpTime ~= lastJumpTime then waypointJumpPending = false end
            lastJumpTime = jumpTime
        end

        if (root.Position - lastPosition).Magnitude >= 0.45 then
            lastPosition = root.Position
            lastProgressAt = os.clock()
            recoveryJumps = 0
        elseif os.clock() - lastProgressAt > 0.8 then
            local jumpTime = Movement.TryGroundedJump(0.8, lastJumpTime, waypoint.Position)
            if jumpTime ~= lastJumpTime then recoveryJumps += 1 end
            lastJumpTime = jumpTime
            humanoid:MoveTo(waypoint.Position)
            lastProgressAt = os.clock()

            if recoveryJumps >= 2 then return "repath" end
        end

        notifyStatus(
            "AI: Walking " .. waypointIndex .. "/" .. waypointCount,
            math.floor(distanceToTarget(root, targetPart)) .. " studs left",
            obstacleAhead and "Obstacle detected; jumping." or "Path clear."
        )
        task.wait(0.05)
    end

    return "repath"
end

local function followPath(token, path, targetPart, reachDistance)
    local waypoints = path:GetWaypoints()
    if #waypoints < 2 then return false end

    local blockedWaypoint = nil
    local blockedConnection = path.Blocked:Connect(function(index)
        blockedWaypoint = blockedWaypoint and math.min(blockedWaypoint, index) or index
    end)

    local function pathIsBlocked(currentIndex)
        return blockedWaypoint ~= nil and blockedWaypoint >= currentIndex
    end

    for index = 2, #waypoints do
        local result = moveToWaypoint(
            token,
            waypoints[index],
            index,
            #waypoints,
            targetPart,
            reachDistance,
            pathIsBlocked
        )

        if result == "target" then
            blockedConnection:Disconnect()
            return true
        end
        if result ~= "waypoint" then
            blockedConnection:Disconnect()
            return false
        end
    end

    blockedConnection:Disconnect()
    local root = Movement.GetRoot()
    return root ~= nil and distanceToTarget(root, targetPart) <= reachDistance
end

local function directWalk(token, targetPart, reachDistance)
    local humanoid = Movement.GetHumanoid()
    local root = Movement.GetRoot()
    if not humanoid or not root then return false end

    notifyStatus("AI: Local avoidance", "Searching for a walkable direction.")
    local deadline = os.clock() + 4.0
    local lastProgressAt = os.clock()
    local bestDistance = distanceToTarget(root, targetPart)
    local lastJumpTime = 0

    while os.clock() < deadline do
        if not isActive(token) or not targetPart.Parent then return false end
        if not root.Parent or humanoid.Health <= 0 then return false end

        local currentDistance = distanceToTarget(root, targetPart)
        if currentDistance <= reachDistance then return true end
        if currentDistance < bestDistance - 0.5 then
            bestDistance = currentDistance
            lastProgressAt = os.clock()
        elseif os.clock() - lastProgressAt > 1.2 then
            return false
        end

        local obstacleAhead = Movement.IsObstacleAhead(targetPart.Position)
        local direction = Movement.FindWalkDirection(targetPart.Position)
        if direction then
            humanoid.AutoRotate = true
            humanoid:MoveTo(root.Position + direction * 5.0)
        else
            lastJumpTime = Movement.TryGroundedJump(0.8, lastJumpTime, targetPart.Position)
            humanoid:MoveTo(targetPart.Position)
        end

        if obstacleAhead then
            lastJumpTime = Movement.TryGroundedJump(0.8, lastJumpTime, targetPart.Position)
        end

        notifyStatus(
            "AI: Local avoidance",
            math.floor(currentDistance) .. " studs left",
            direction and "Steering around obstacle." or "No clear side; retrying path."
        )
        task.wait(0.12)
    end

    return false
end

local function createPath()
    return PathfindingService:CreatePath({
        AgentRadius = 2.0,
        AgentHeight = 5.0,
        AgentCanJump = true,
        AgentJumpHeight = 7.5,
        AgentMaxSlope = 50.0,
        WaypointSpacing = 3.5
    })
end

function Navigator.GoTo(entry, onComplete)
    if not entry or not entry.part or not entry.part.Parent then
        notifyStatus("AI: Error", "Target does not exist.")
        return
    end

    currentToken += 1
    local token = currentToken
    isRunning = true

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

            if distanceToTarget(root, entry.part) <= reachDistance then
                isRunning = false
                notifyStatus("AI: Arrived", "At target: " .. entry.name)
                if onComplete then onComplete(entry) end
                return
            end

            notifyStatus("AI: Mapping route", entry.name, "Attempt " .. attempt .. "/" .. maxRepaths)
            local path = createPath()
            local computed = pcall(function()
                path:ComputeAsync(root.Position, entry.part.Position)
            end)

            local reached = false
            if computed and path.Status == Enum.PathStatus.Success then
                reached = followPath(token, path, entry.part, reachDistance)
                if not reached and isActive(token) then
                    reached = directWalk(token, entry.part, reachDistance)
                end
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

            task.wait(0.15)
        end

        Navigator.Stop("Route failed after max repaths.")
    end)
end

function Navigator.Stop(reason)
    currentToken += 1
    isRunning = false

    local humanoid = Movement and Movement.GetHumanoid()
    local root = Movement and Movement.GetRoot()
    if humanoid and root then humanoid:MoveTo(root.Position) end
    notifyStatus("AI: Idle", reason or "Navigation halted.")
end

function Navigator.IsRunning()
    return isRunning
end

return Navigator
