--[[ =========================================================
     TORA HUB WRAPPER + REMOTE LOGGER
     - Menjalankan script asli Tora Hub
     - Merekam semua FireServer / InvokeServer
     - Tombol "Copy All" untuk kirim log ke saya
     - UI ringan + bisa minimize (mobile friendly)
     Load: loadstring(game:HttpGet(".../ToraLogger.lua"))()
========================================================= ]]

if _G.ToraLoggerLoaded then
    pcall(function() _G.ToraLoggerUI:Destroy() end)
end
_G.ToraLoggerLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local CONFIG = {
    MaxLogs = 200, -- batasi biar ga berat
    LogFile = "tora_remote_log.txt",
}

local State = {
    Logs = {},
    Hooked = false,
    Minimized = false,
}

-- ================= UTIL =================
local function getTime()
    return os.date("%H:%M:%S")
end

local function addLog(line, color)
    table.insert(State.Logs, { text = line, color = color or Color3.fromRGB(200,200,200) })
    if #State.Logs > CONFIG.MaxLogs then
        table.remove(State.Logs, 1)
    end
    -- update UI nanti
end

local function notify(t, x)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = t, Text = x, Duration = 2
        })
    end)
end

-- ================= HOOK =================
-- Coba hook FireServer dan InvokeServer
local function setupHooks()
    local ok = pcall(function()
        -- 1. Hook semua RemoteEvent.FireServer
        local oldFire = Instance.new("RemoteEvent").FireServer
        hookfunction(oldFire, function(self, ...)
            local args = {...}
            local argStr = ""
            for i, v in ipairs(args) do
                if i > 1 then argStr = argStr .. ", " end
                if type(v) == "table" then
                    argStr = argStr .. "table"
                elseif type(v) == "string" then
                    argStr = argStr .. '"'..v..'"'
                else
                    argStr = argStr .. tostring(v)
                end
            end
            local path = self:GetFullName()
            addLog("["..getTime().."] FS: "..path.." | args: "..argStr, Color3.fromRGB(100,200,255))
            return oldFire(self, ...)
        end)

        -- 2. Hook semua RemoteFunction.InvokeServer
        local oldInvoke = Instance.new("RemoteFunction").InvokeServer
        hookfunction(oldInvoke, function(self, ...)
            local args = {...}
            local argStr = ""
            for i, v in ipairs(args) do
                if i > 1 then argStr = argStr .. ", " end
                if type(v) == "table" then
                    argStr = argStr .. "table"
                elseif type(v) == "string" then
                    argStr = argStr .. '"'..v..'"'
                else
                    argStr = argStr .. tostring(v)
                end
            end
            local path = self:GetFullName()
            addLog("["..getTime().."] IS: "..path.." | args: "..argStr, Color3.fromRGB(255,200,100))
            return oldInvoke(self, ...)
        end)
        State.Hooked = true
        addLog("Hook aktif, merekam remote...", Color3.fromRGB(0,255,150))
    end)
    if not ok then
        addLog("Hook gagal, executor tidak support hookfunction", Color3.fromRGB(255,100,100))
    end
    return ok
end

-- ================= UI =================
local LogLabel
local function refreshLogUI()
    if not LogLabel then return end
    local text = ""
    for _, entry in ipairs(State.Logs) do
        text = text .. entry.text .. "\n"
    end
    LogLabel.Text = text
    -- scroll ke bawah
    local parent = LogLabel.Parent
    if parent and parent:IsA("ScrollingFrame") then
        parent.CanvasPosition = Vector2.new(0, math.max(0, LogLabel.TextBounds.Y - parent.AbsoluteSize.Y))
    end
end

local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ToraLoggerUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.ToraLoggerUI = gui

    -- ===== PANEL UTAMA =====
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 340, 0, 420)
    Main.Position = UDim2.new(0, 20, 0.5, -210)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,10); mc.Parent = Main
    local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(100,100,255); ms.Thickness = 2; ms.Parent = Main

    -- Title bar
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundColor3 = Color3.fromRGB(50, 50, 120)
    Title.Text = "📡 TORA REMOTE LOGGER"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 13
    Title.BorderSizePixel = 0
    Title.Parent = Main
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,10); tc.Parent = Title

    -- Tombol minimize (pojok kanan title)
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -34, 0, 3)
    MinBtn.BackgroundColor3 = Color3.fromRGB(180, 140, 0)
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 16
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = Title
    local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0,6); mbc.Parent = MinBtn

    -- Area log (ScrollingFrame)
    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, -20, 1, -120)
    LogScroll.Position = UDim2.new(0, 10, 0, 42)
    LogScroll.BackgroundColor3 = Color3.fromRGB(10,10,15)
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 4
    LogScroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,255)
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.Parent = Main
    local lsc = Instance.new("UICorner"); lsc.CornerRadius = UDim.new(0,6); lsc.Parent = LogScroll

    LogLabel = Instance.new("TextLabel")
    LogLabel.Size = UDim2.new(1, -10, 0, 0)
    LogLabel.Position = UDim2.new(0, 5, 0, 5)
    LogLabel.BackgroundTransparency = 1
    LogLabel.Text = "Menunggu remote...\n"
    LogLabel.TextColor3 = Color3.fromRGB(200,200,200)
    LogLabel.Font = Enum.Font.Code
    LogLabel.TextSize = 10
    LogLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogLabel.TextYAlignment = Enum.TextYAlignment.Top
    LogLabel.TextWrapped = true
    LogLabel.AutomaticSize = Enum.AutomaticSize.Y
    LogLabel.Parent = LogScroll

    -- Tombol Copy All
    local CopyBtn = Instance.new("TextButton")
    CopyBtn.Size = UDim2.new(0.6, -10, 0, 36)
    CopyBtn.Position = UDim2.new(0, 10, 1, -46)
    CopyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    CopyBtn.Text = "📋 COPY ALL LOG"
    CopyBtn.TextColor3 = Color3.new(1,1,1)
    CopyBtn.Font = Enum.Font.GothamBold
    CopyBtn.TextSize = 12
    CopyBtn.BorderSizePixel = 0
    CopyBtn.Parent = Main
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,8); cbc.Parent = CopyBtn

    -- Tombol Clear
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0.35, -10, 0, 36)
    ClearBtn.Position = UDim2.new(0.62, 0, 1, -46)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 60)
    ClearBtn.Text = "🗑 Clear"
    ClearBtn.TextColor3 = Color3.new(1,1,1)
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 12
    ClearBtn.BorderSizePixel = 0
    ClearBtn.Parent = Main
    local cbc2 = Instance.new("UICorner"); cbc2.CornerRadius = UDim.new(0,8); cbc2.Parent = ClearBtn

    -- ===== MINIMIZE ICON (bulat kecil) =====
    local MiniIcon = Instance.new("TextButton")
    MiniIcon.Size = UDim2.new(0, 48, 0, 48)
    MiniIcon.Position = UDim2.new(0, 15, 0.15, 0)
    MiniIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 120)
    MiniIcon.Text = "📡"
    MiniIcon.TextSize = 22
    MiniIcon.BorderSizePixel = 0
    MiniIcon.Visible = false
    MiniIcon.Active = true
    MiniIcon.Draggable = true
    MiniIcon.Parent = gui
    local mic = Instance.new("UICorner"); mic.CornerRadius = UDim.new(1,0); mic.Parent = MiniIcon
    local mis = Instance.new("UIStroke"); mis.Color = Color3.fromRGB(150,150,255); mis.Thickness = 2; mis.Parent = MiniIcon

    -- ===== FUNGSI TOGGLE =====
    local function setMinimized(state)
        State.Minimized = state
        if state then
            Main.Visible = false
            MiniIcon.Visible = true
        else
            Main.Visible = true
            MiniIcon.Visible = false
        end
    end

    MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
    MiniIcon.MouseButton1Click:Connect(function() setMinimized(false) end)

    -- Copy All
    CopyBtn.MouseButton1Click:Connect(function()
        local text = ""
        for _, entry in ipairs(State.Logs) do
            text = text .. entry.text .. "\n"
        end
        if setclipboard then
            setclipboard(text)
            notify("Logger", "Log disalin ke clipboard ("..#State.Logs.." baris)")
            addLog("[SYSTEM] Log disalin ke clipboard", Color3.fromRGB(0,255,150))
        else
            notify("Logger", "Executor tidak support setclipboard")
        end
        refreshLogUI()
    end)

    -- Clear
    ClearBtn.MouseButton1Click:Connect(function()
        State.Logs = {}
        refreshLogUI()
        addLog("[SYSTEM] Log dibersihkan", Color3.fromRGB(255,200,100))
    end)

    return gui
end

-- ================= MAIN =================
-- 1. Buat UI dulu
createUI()

-- 2. Setup hook
local hooked = setupHooks()
refreshLogUI()

-- 3. Jalankan Tora Hub
task.spawn(function()
    task.wait(0.5)
    addLog("[SYSTEM] Menjalankan Tora Hub...", Color3.fromRGB(0,255,150))
    refreshLogUI()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/BuildtoDefendLoot"))()
    end)
    if ok then
        addLog("[SYSTEM] Tora Hub berhasil dijalankan", Color3.fromRGB(0,255,150))
    else
        addLog("[SYSTEM] Tora Hub GAGAL: "..tostring(err), Color3.fromRGB(255,100,100))
    end
    refreshLogUI()
    notify("Tora Logger", "Siap. Gunakan fitur Tora, lalu Copy All.")
end)

-- 4. Loop refresh log ringan (tiap 1 detik biar ga berat)
task.spawn(function()
    while _G.ToraLoggerLoaded do
        task.wait(1)
        pcall(refreshLogUI)
    end
end)
