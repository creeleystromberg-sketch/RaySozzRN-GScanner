-- Sol's RNG Universal Modular Loader
-- Entry point for Roblox executors

local BASE_URL = "https://raw.githubusercontent.com/Rayzz123/sols/main/src/"

local function import(path)
    local url = BASE_URL .. path .. ".lua"
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or not source or source == "" then
        error("[Loader Error] Failed to fetch: " .. url)
    end

    local fn, syntaxErr = loadstring(source)
    if not fn then
        error("[Loader Compile Error] " .. path .. ": " .. tostring(syntaxErr))
    end

    return fn()
end

-- 1. Load Utilities & Config
local Config    = import("config")
local Database  = import("database")
local Movement  = import("utils/movement")
local Server    = import("utils/server")

-- 2. Load Core Engines
local Scanner   = import("core/scanner")
local Navigator = import("core/navigator")
local Collector = import("core/collector")
local Visuals   = import("ui/visuals")
local UI        = import("ui/interface")

-- 3. Initialize Inter-module Dependencies
Scanner.Init({
    Database = Database,
    Movement = Movement
})

Navigator.Init({
    Movement = Movement,
    Config = Config
})

Collector.Init({
    Scanner = Scanner,
    Navigator = Navigator,
    Config = Config
})

Visuals.Init({
    Movement = Movement
})

-- 4. Launch Interface & Services
UI.Init({
    Config = Config,
    Scanner = Scanner,
    Navigator = Navigator,
    Collector = Collector,
    Visuals = Visuals,
    Movement = Movement,
    Server = Server
})

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Sol's RNG Suite",
        Text = Config.Version .. " loaded successfully.",
        Duration = 4
    })
end)
