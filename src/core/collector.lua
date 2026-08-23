local Collector = {}

local isAutoCollecting = false
local currentToken = 0

local Scanner = nil
local Navigator = nil
local Config = nil
local onStatusCallback = nil

function Collector.Init(deps)
    Scanner = deps.Scanner
    Navigator = deps.Navigator
    Config = deps.Config
end

function Collector.SetStatusCallback(callback)
    onStatusCallback = callback
end

local function notify(line1, line2, line3)
    if onStatusCallback then
        onStatusCallback(line1, line2, line3)
    end
end

function Collector.TriggerPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false, "Prompt unavailable."
    end

    if type(fireproximityprompt) == "function" then
        local ok, err = pcall(function()
            fireproximityprompt(prompt, 0)
        end)
        return ok, ok and nil or tostring(err)
    end

    return false, "Executor has no fireproximityprompt; interact manually."
end

function Collector.CollectItem(entry, onFinished)
    if not entry or not entry.prompt or not entry.prompt.Parent then
        if onFinished then onFinished(false, "Item missing.") end
        return
    end

    Navigator.GoTo(entry, function(target)
        notify("Collector", "Triggering pickup for " .. target.name)
        local fired, err = Collector.TriggerPrompt(target.prompt)
        
        if fired then
            -- Await destruction/pickup
            local started = os.clock()
            while os.clock() - started < 1.5 do
                if not target.prompt.Parent or not target.part.Parent then
                    notify("Collector", "Successfully collected " .. target.name)
                    if onFinished then onFinished(true) end
                    return
                end
                task.wait(0.1)
            end
        end

        if onFinished then onFinished(fired, err) end
    end)
end

function Collector.StartAutoQueue()
    if isAutoCollecting then return end
    isAutoCollecting = true
    currentToken += 1
    local token = currentToken

    task.spawn(function()
        while isAutoCollecting and token == currentToken do
            local entries = Scanner.Scan()
            if #entries == 0 then
                notify("Auto-Collector", "No materials found. Waiting...")
                task.wait(1.5)
            else
                local target = entries[1]
                local finished = false

                notify("Auto-Collector", "Targeting " .. target.name .. " (" .. target.biome .. ")")
                
                Collector.CollectItem(target, function(success, err)
                    finished = true
                end)

                while not finished and isAutoCollecting and token == currentToken do
                    task.wait(0.2)
                end

                task.wait(0.4)
            end
        end
    end)
end

function Collector.StopAutoQueue()
    isAutoCollecting = false
    currentToken += 1
    Navigator.Stop("Auto-collection stopped.")
end

function Collector.IsAutoActive()
    return isAutoCollecting
end

return Collector
