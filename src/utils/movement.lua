local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Movement = {}
local player = Players.LocalPlayer

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
    if now - (lastJumpTime or 0) < (cooldown or 0.85) then return lastJumpTime end
    if hum.FloorMaterial == Enum.Material.Air then return lastJumpTime end

    hum.Jump = true
    return now
end

function Movement.IsObstacleAhead(targetPos)
    local root = Movement.GetRoot()
    local char = player.Character
    if not root or not char then return false end

    local origin = root.Position - Vector3.new(0, 1.4, 0)
    local flatDir = Vector3.new(targetPos.X - origin.X, 0, targetPos.Z - origin.Z)
    if flatDir.Magnitude < 0.1 then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true

    return Workspace:Raycast(origin, flatDir.Unit * 2.8, params) ~= nil
end

return Movement
