-- Sol's RNG material tracker
local REPO_URL = "https://raw.githubusercontent.com/creeleystromberg-sketch/RaySozzRN-GScanner/main/src/"
local RELEASE = "tracker-005"

local function import(path)
    local ok, source = pcall(function()
        return game:HttpGet(REPO_URL .. path .. ".lua?v=" .. RELEASE)
    end)
    if not ok or not source or source == "" or string.find(source, "404: Not Found", 1, true) then
        error("[Loader] Could not load " .. path .. ".lua: " .. tostring(source))
    end
    local chunk, syntaxError = loadstring(source)
    if not chunk then error("[Loader] Syntax error in " .. path .. ": " .. tostring(syntaxError)) end
    return chunk()
end

local function importBatch(modules)
    local results, errors = {}, {}
    local remaining = 0
    local completed = Instance.new("BindableEvent")

    for key, path in pairs(modules) do
        remaining += 1
        task.spawn(function()
            local ok, result = pcall(import, path)
            if ok then results[key] = result else errors[key] = result end
            remaining -= 1
            completed:Fire()
        end)
    end
    while remaining > 0 do completed.Event:Wait() end
    completed:Destroy()

    for key, loadError in pairs(errors) do
        error("[Loader] Module " .. key .. " failed: " .. tostring(loadError))
    end
    return results
end

print("[Sols Tracker] Loading modules...")
local modules = importBatch({
    Config = "config",
    Database = "database",
    Movement = "utils/movement",
    Server = "utils/server",
    Scanner = "core/scanner",
    Visuals = "ui/visuals",
    UI = "ui/interface",
})

modules.Scanner.Init({
    Database = modules.Database,
    Movement = modules.Movement,
    Config = modules.Config,
})
modules.Visuals.Init({ Movement = modules.Movement })
modules.UI.Init({
    Config = modules.Config,
    Scanner = modules.Scanner,
    Visuals = modules.Visuals,
    Movement = modules.Movement,
    Server = modules.Server,
})

print("[Sols Tracker] Ready.")
