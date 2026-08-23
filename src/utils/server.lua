local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Server = {}
local player = Players.LocalPlayer

function Server.GetUrlOpener()
    if type(openurl) == "function" then return openurl end
    if type(open_url) == "function" then return open_url end
    if syn and type(syn.open_url) == "function" then return syn.open_url end
    return nil
end

function Server.Copy(text)
    local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if fn then
        return pcall(fn, text)
    end
    return false
end

function Server.CleanInput(raw)
    local text = tostring(raw or ""):gsub("\\_", "_")
    local url = text:match("(https?://[^%s%)%]]+)")
    if url then text = url end
    return text:gsub('[">]+$', ""):gsub("%s+", "")
end

function Server.HandleJoin(rawText)
    local text = Server.CleanInput(rawText)
    if text == "" then return "Paste a server link first." end

    local joinGuardId = text:match("^https?://join%-guard%.solsstattracker%.com/([%w_%-]+)")
    if joinGuardId then
        local opener = Server.GetUrlOpener()
        if opener then
            pcall(opener, text)
            return "Opening Join Guard verification..."
        else
            Server.Copy(text)
            return "Link copied — open in browser for verification."
        end
    end

    local gameInstanceId = text:match("[?&]gameInstanceId=([^&]+)")
    if gameInstanceId then
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, gameInstanceId, player)
        end)
        return ok and "Joining server..." or ("Join failed: " .. tostring(err))
    end

    if #text > 20 and not string.find(string.lower(text), "http", 1, true) then
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, text, player)
        end)
        return ok and "Joining JobId..." or ("Server id failed: " .. tostring(err))
    end

    return "Unsupported format."
end

return Server
