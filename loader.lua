-- Sol's RNG Universal Modular Loader
-- Repository: creeleystromberg-sketch/RaySozzRN-GScanner

local REPO_URL = "https://raw.githubusercontent.com/creeleystromberg-sketch/RaySozzRN-GScanner/main/src/"

local function import(path)
    local url = REPO_URL .. path .. ".lua?t=" .. tostring(os.time())
    
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or not source or source == "" or string.find(source, "404: Not Found", 1, true) then
        error("[Loader 404] File not found: " .. path .. ".lua (Check path and file name on GitHub)")
    end

    local fn, syntaxErr = loadstring(source)
    if not fn then
        error("[Loader Syntax Error] in " .. path .. ": " .. tostring(syntaxErr))
    end

    print("[✓ Loaded] " .. path)
    return fn()
end

print("------------------------------------------")
print("[Sols Scanner] Starting modular initialization...")

-- 1. Utilities & Config
local Config    = import("config")
local Database  = import("database")
local Movement  = import("utils/movement")
local Server    = import("utils/server")

-- 2. Core Engines
local Scanner   = import("core/scanner")
local Navigator = import("core/navigator")
local Collector = import("core/collector")
local Visuals   = import("ui/visuals")
local UI        = import("ui/interface")

-- 3. Dependency Injection
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

-- 4. Launch Interface
UI.Init({
    Config = Config,
    Scanner = Scanner,
    Navigator = Navigator,
    Collector = Collector,
    Visuals = Visuals,
    Movement = Movement,
    Server = Server
})

print("[Sols Scanner] System successfully initialized.")
print("------------------------------------------")
