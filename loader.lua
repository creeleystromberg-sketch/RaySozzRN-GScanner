local BASE_URL = "https://raw.githubusercontent.com/ТвойНикнейм/sols-rng-tracker/main/src/"

local function import(path)
    local source = game:HttpGet(BASE_URL .. path .. ".lua")
    local fn, syntaxErr = loadstring(source)
    if not fn then
        error("[Loader Error] " .. path .. ": " .. tostring(syntaxErr))
    end
    return fn()
end

-- Инициализация модулей
local Config    = import("config")
local Database  = import("database")
local Visuals   = import("ui/visuals")
local Scanner   = import("core/scanner")
local Navigator = import("core/navigator")
local UI        = import("ui/interface")

-- Запуск системы
UI.init({
    config = Config,
    scanner = Scanner,
    navigator = Navigator,
    visuals = Visuals
})
