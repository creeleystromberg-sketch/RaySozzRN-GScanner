local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Movement = {}
local player = Players.LocalPlayer

local function raycastParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = player.Character and { player.Character } or {}
    params.IgnoreWater = true
    return params
end

local function rotateFlat(direction, angle)
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    return Vector3.new(
        direction.X * cosine - direction.Z * sine,
        0,
        direction.X * sine + direction.Z * cosine
    )
end

function Movement.GetHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Movement.GetRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Movement.SetSpeed(speed)
    local hum = Movement.GetHumanoid()
    if hum then
        hum.WalkSpeed = speed
    end
end

function Movement.TryGroundedJump(cooldown, lastJumpTime)
    local hum = Movement.GetHumanoid()
    if not hum or hum.Health <= 0 then return lastJumpTime end
    
    local now = os.clock()
    if now - (lastJumpTime or 0) < (cooldown or 0.8) then return lastJumpTime end
    if hum.FloorMaterial == Enum.Material.Air then return lastJumpTime end

    hum.Jump = true
    return now
end

function Movement.IsObstacleAhead(targetPos)
    local root = Movement.GetRoot()
    local char = player.Character
    if not root or not char then return false end

    local origin = root.Position - Vector3.new(0, 1.35, 0)
    local flatDir = Vector3.new(targetPos.X - origin.X, 0, targetPos.Z - origin.Z)
    if flatDir.Magnitude < 0.1 then return false end

    local hit = Workspace:Raycast(origin, flatDir.Unit * 2.8, raycastParams())
    return hit ~= nil, hit
end

function Movement.FindWalkDirection(targetPos)
    local root = Movement.GetRoot()
    if not root then return nil end

    local desired = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
    if desired.Magnitude < 0.1 then return nil end
    desired = desired.Unit

    local origin = root.Position - Vector3.new(0, 1.35, 0)
    local params = raycastParams()
    local angles = { 0, math.rad(35), math.rad(-35), math.rad(70), math.rad(-70), math.rad(105), math.rad(-105) }

    for _, angle in ipairs(angles) do
        local direction = rotateFlat(desired, angle)
        local wall = Workspace:Raycast(origin, direction * 3.5, params)
        local groundOrigin = root.Position + direction * 3.0 + Vector3.new(0, 2.0, 0)
        local ground = Workspace:Raycast(groundOrigin, Vector3.new(0, -7.0, 0), params)

        if not wall and ground then
            return direction
        end
    end

    return nil
end

return Movement
