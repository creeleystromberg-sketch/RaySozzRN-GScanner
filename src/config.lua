local Config = {
    Version = "v1.0.0",
    Build = "TRACKER-013",
    DefaultSpeed = 18,
    
    -- Scanner
    ScanInterval = 1.0,
    FullRescanInterval = 15.0,
    AutoStartTracker = true,
    CalibrationMode = false,
    MaterialPromptDistance = 100.0,
    RemotePickupAssist = true,
    RemotePickupMinDistance = 15.0,
    RemotePickupKey = Enum.KeyCode.E,
    
    -- UI Colors & Dimensions
    Colors = {
        Background = Color3.fromRGB(14, 15, 18),
        Surface = Color3.fromRGB(18, 19, 23),
        Accent = Color3.fromRGB(43, 137, 81),
        AccentDanger = Color3.fromRGB(49, 31, 34),
        TextPrimary = Color3.fromRGB(244, 245, 247),
        TextSecondary = Color3.fromRGB(124, 129, 140),
        Border = Color3.fromRGB(72, 76, 86)
    }
}

return Config
