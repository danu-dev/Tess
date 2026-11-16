--[[ =========================================================
     STEAK SCRIPT - CONSERVATIVE EDITION
     Mengurangi risiko deteksi anomali (TIDAK menjamin aman)
     Load: loadstring(game:HttpGet("..."))()
========================================================= ]]

if _G.SteakSafeLoaded then
    pcall(function() _G.SteakSafeUI:Destroy() end)
end
_G.SteakSafeLoaded = true

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ================= CONFIG (konservatif) =================
local CONFIG = {
    NormalSpeed     = 16,
    SafeSpeed       = 26,       -- jangan 60, ini lebih aman
    MaxSpeed        = 32,       -- batas atas biar ga aneh
    BasePosition    = nil,
    PickupDelay     = {0.15, 0.35},   -- delay acak sebelum pickup
    TeleportDelay   = {0.20, 0.40},   -- delay acak sebelum teleport
    CooldownSteal   = 2.0,      -- cooldown antar steal (detik)
    CooldownBase    = 1.5,
    AutoReturn      = false,
    AutoReturnDelay = {1.2, 2.0},  -- delay acak auto return
}

local State = {
    SpeedOn     = false,
    CurrentBase = CONFIG.BasePosition,
    LastSteal   = 0,
    LastBase    = 0,
    Busy        = false,
}

-- ================= UTIL =================
local function rnd(range)
    return range[1] + math.random() * (range[2] - range[1])
end

local function getChar() return LP.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function setSpeed(s)
    local h = getHum()
    if h then h.WalkSpeed = math.clamp(s, 0, CONFIG.MaxSpeed) end
end
local function notify(t, x)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = t, Text = x, Duration = 3
        })
    end)
end

-- ================= FITUR =================
local F = {}

function F.SetSpeed(on)
    State.SpeedOn = on
    setSpeed(on and CONFIG.SafeSpeed or CONFIG.NormalSpeed)
    notify("Speed", on and ("ON ("..CONFIG.SafeSpeed..")") or "OFF")
end

-- cari steak di sekitar player (radius terbatas, bukan seluruh workspace)
local function findNearbySteak(radius)
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, radius
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name:lower():find("steak") then
            local handle = obj:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local d = (handle.Position - hrp.Position).Magnitude
                if d < bestDist then
                    best, bestDist = obj, d
                end
            end
        end
    end
    return best
end

function F.StealSteak()
    if State.Busy then return end
    local now = tick()
    if now - State.LastSteal < CONFIG.CooldownSteal then
        notify("Steal", "Cooldown...")
        return
    end
    State.Busy = true
    State.LastSteal = now

    task.spawn(function()
        -- 1) delay acak sebelum pickup
        task.wait(rnd(CONFIG.PickupDelay))

        -- 2) cari steak terdekat
        local steak = findNearbySteak(60)
        local bp = LP:FindFirstChild("Backpack")

        if steak and bp then
            steak.Parent = bp
            notify("Steal", "Steak diambil")
        else
            notify("Steal", "Steak tidak ditemukan (radius 60)")
        end

        -- 3) speed on
        F.SetSpeed(true)

        -- 4) auto return dengan delay acak
        if CONFIG.AutoReturn and State.CurrentBase then
            task.wait(rnd(CONFIG.AutoReturnDelay))
            F.ReturnBase()
        end

        State.Busy = false
    end)
end

function F.ReturnBase()
    if State.Busy then return end
    local now = tick()
    if now - State.LastBase < CONFIG.CooldownBase then return end
    State.LastBase = now
    State.Busy = true

    task.spawn(function()
        task.wait(rnd(CONFIG.TeleportDelay))

        local hrp = getHRP()
        if not hrp then State.Busy = false return end

        local target = State.CurrentBase
        if not target then
            local sp = workspace:FindFirstChildOfClass("SpawnLocation")
            if sp then target = sp.Position + Vector3.new(0, 3, 0) end
        end
        if not target then
            notify("Base", "Base belum diset")
            State.Busy = false
            return
        end

        -- teleport halus: tween posisi (bukan loncat instan)
        local startCF = hrp.CFrame
        local endCF = CFrame.new(target) * (startCF - startCF.Position)
        local t = 0
        local dur = 0.18
        local conn
        conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
            if not hrp or not hrp.Parent then
                if conn then conn:Disconnect() end
                return
            end
            t = math.min(t + dt, dur)
            local a = t / dur
            hrp.CFrame = startCF:Lerp(endCF, a)
            if t >= dur then
                if conn then conn:Disconnect() end
            end
        end)

        task.wait(dur + 0.1)
        F.SetSpeed(false)
        notify("Base", "Kembali ke base")
        State.Busy = false
    end)
end

function F.SetBaseHere()
    local hrp = getHRP()
    if hrp then
        State.CurrentBase = hrp.Position
        CONFIG.BasePosition = hrp.Position
        notify("Base", "Base diset di posisi sekarang")
    end
end

-- ================= UI =================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SteakSafeUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.SteakSafeUI = gui

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 270, 0, 380)
    Main.Position = UDim2.new(0, 20, 0, 20)
    Main.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = Main
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(0,200,140); s.Thickness = 2; s.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    Title.Text = "🥩 STEAK SAFE MODE"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.BorderSizePixel = 0
    Title.Parent = Main
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,10); tc.Parent = Title

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -20, 1, -50)
    Content.Position = UDim2.new(0, 10, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Parent = Main
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.Parent = Content

    local function btn(text, color, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 38)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 13
        b.BorderSizePixel = 0
        b.Parent = Content
        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,8); cc.Parent = b
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    btn("🥩 Steal Steak (Safe)", Color3.fromRGB(0, 160, 110), F.StealSteak)
    btn("🏠 Teleport Base (Halus)", Color3.fromRGB(50, 110, 200), F.ReturnBase)
    btn("📍 Set Base di Sini", Color3.fromRGB(50, 170, 110), F.SetBaseHere)

    local spd = btn("⚡ Speed: OFF", Color3.fromRGB(70,70,90), function() end)
    spd.MouseButton1Click:Connect(function()
        F.SetSpeed(not State.SpeedOn)
        spd.Text = "⚡ Speed: " .. (State.SpeedOn and "ON" or "OFF")
        spd.BackgroundColor3 = State.SpeedOn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    local ar = btn("🔄 Auto Return: OFF", Color3.fromRGB(70,70,90), function() end)
    ar.MouseButton1Click:Connect(function()
        CONFIG.AutoReturn = not CONFIG.AutoReturn
        ar.Text = "🔄 Auto Return: " .. (CONFIG.AutoReturn and "ON" or "OFF")
        ar.BackgroundColor3 = CONFIG.AutoReturn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    -- info
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "⚠ Mode konservatif\nSpeed dibatasi " .. CONFIG.MaxSpeed ..
                "\nDelay acak aktif\nTidak menjamin aman"
    info.TextColor3 = Color3.fromRGB(200,200,200)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextWrapped = true
    info.Parent = Content
end

-- ================= HOTKEY =================
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.E then F.StealSteak()
    elseif i.KeyCode == Enum.KeyCode.Q then F.ReturnBase()
    elseif i.KeyCode == Enum.KeyCode.R then F.SetSpeed(false)
    end
end)

-- ================= INIT =================
createUI()
notify("Steak Safe Mode", "Loaded. Speed max "..CONFIG.MaxSpeed..", delay acak aktif.")

LP.CharacterAdded:Connect(function()
    task.wait(1)
    setSpeed(CONFIG.NormalSpeed)
end)
