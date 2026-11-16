--[[ =========================================================
     STEAK SCRIPT FINAL - Hook Auto Replay
     - Hook FireServer, rekam ID valid otomatis
     - Replay ID terakhir tanpa scan
     - Mobile friendly + floating button
     Load: loadstring(game:HttpGet(".../SteakScript_Final.lua"))()
========================================================= ]]

if _G.SteakFinalLoaded then
    pcall(function() _G.SteakFinalUI:Destroy() end)
end
_G.SteakFinalLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ================= CONFIG =================
local CONFIG = {
    NormalSpeed   = 16,
    SafeSpeed     = 26,
    MaxSpeed      = 32,
    StealAction   = "requestReplicateToServerInteractable",
    StealVerb     = "steal",
    ReplayGap     = {0.25, 0.45},  -- gap antar replay (natural)
    AutoReplay    = false,
    AutoReplayDelay = {1.5, 2.5},
    MaxRecorded   = 30,           -- batas ID yang disimpan
}

local State = {
    SpeedOn    = false,
    UIOpen     = true,
    Hooked     = false,
    LastId     = nil,
    RecordedIds = {},   -- { [id] = timestamp }
    ReplayCount = 0,
}

-- ================= UTIL =================
local function rnd(r) return r[1] + math.random() * (r[2] - r[1]) end
local function getHum()
    local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid")
end
local function setSpeed(s)
    local h = getHum()
    if h then h.WalkSpeed = math.clamp(s, 0, CONFIG.MaxSpeed) end
end
local function notify(t, x)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = t, Text = x, Duration = 2.5
        })
    end)
end

-- ================= REMOTE =================
local function getRemote()
    local ep = ReplicatedStorage:FindFirstChild("endpoints")
    if not ep then return nil end
    return ep:FindFirstChild("Interactables")
end

-- ================= HOOK =================
local function setupHook()
    local remote = getRemote()
    if not remote then return false end

    local hookFunc = hookfunction or (syn and syn.hookfunction) or (getgenv and getgenv().hookfunction)
    if not hookFunc then return false end

    local ok = pcall(function()
        local oldFire = remote.FireServer
        hookFunc(oldFire, function(self, action, id, verb, ...)
            if action == CONFIG.StealAction and verb == CONFIG.StealVerb and type(id) == "number" then
                -- rekam ID + waktu
                State.RecordedIds[id] = tick()
                State.LastId = id
                -- batasi jumlah
                local count = 0
                local oldestId, oldestTime = nil, math.huge
                for k, t in pairs(State.RecordedIds) do
                    count = count + 1
                    if t < oldestTime then oldestTime = t; oldestId = k end
                end
                if count > CONFIG.MaxRecorded and oldestId then
                    State.RecordedIds[oldestId] = nil
                end
            end
            return oldFire(self, action, id, verb, ...)
        end)
        State.Hooked = true
    end)
    return ok
end

-- ================= REPLAY =================
local function replayId(id)
    local remote = getRemote()
    if not remote then return false end
    local ok = pcall(function()
        remote:FireServer(CONFIG.StealAction, id, CONFIG.StealVerb)
    end)
    if ok then
        State.ReplayCount = State.ReplayCount + 1
    end
    return ok
end

local function replayLast()
    if not State.LastId then
        notify("Replay", "Belum ada ID terekam. Steal manual dulu 1x.")
        return
    end
    replayId(State.LastId)
    notify("Replay", "Kirim ID: "..State.LastId)
end

local function replayAll()
    local ids = {}
    for id in pairs(State.RecordedIds) do table.insert(ids, id) end
    if #ids == 0 then
        notify("Replay", "Belum ada ID terekam")
        return
    end
    task.spawn(function()
        for _, id in ipairs(ids) do
            replayId(id)
            task.wait(rnd(CONFIG.ReplayGap))
        end
        notify("Replay", "Selesai ("..#ids.." ID)")
    end)
end

-- auto loop
task.spawn(function()
    while _G.SteakFinalLoaded do
        task.wait(rnd(CONFIG.AutoReplayDelay))
        if CONFIG.AutoReplay and State.LastId then
            pcall(replayId, State.LastId)
        end
    end
end)

-- ================= SPEED =================
local function setSpeedOn(on)
    State.SpeedOn = on
    setSpeed(on and CONFIG.SafeSpeed or CONFIG.NormalSpeed)
    notify("Speed", on and ("ON ("..CONFIG.SafeSpeed..")") or "OFF")
end

-- ================= UI =================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SteakFinalUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.SteakFinalUI = gui

    -- floating button
    local float = Instance.new("TextButton")
    float.Size = UDim2.new(0, 56, 0, 56)
    float.Position = UDim2.new(0, 12, 0.5, -28)
    float.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    float.Text = "🥩"
    float.TextSize = 26
    float.Font = Enum.Font.GothamBold
    float.TextColor3 = Color3.new(1,1,1)
    float.BorderSizePixel = 0
    float.Active = true
    float.Draggable = true
    float.Parent = gui
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1,0); fc.Parent = float
    local fs = Instance.new("UIStroke"); fs.Color = Color3.fromRGB(255,255,255); fs.Thickness = 2; fs.Parent = float

    -- main panel
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 290, 0, 400)
    Main.Position = UDim2.new(0, 80, 0.5, -200)
    Main.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,12); mc.Parent = Main
    local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(0,200,140); ms.Thickness = 2; ms.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    Title.Text = "🥩 STEAK FINAL"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.BorderSizePixel = 0
    Title.Parent = Main
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,12); tc.Parent = Title

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -38, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = Title
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,8); cc.Parent = CloseBtn

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -50)
    Content.Position = UDim2.new(0, 8, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Parent = Main
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.Parent = Content

    local function btn(text, color, cb, height)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, height or 44)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 14
        b.BorderSizePixel = 0
        b.Parent = Content
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    -- status hook
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 28)
    status.BackgroundColor3 = Color3.fromRGB(35,35,45)
    status.Text = "🔗 Hook: " .. (State.Hooked and "ON" or "OFF") .. "  |  📦 ID: " .. (State.LastId or "-")
    status.TextColor3 = State.Hooked and Color3.fromRGB(0,255,150) or Color3.fromRGB(255,150,100)
    status.Font = Enum.Font.GothamSemibold
    status.TextSize = 12
    status.BorderSizePixel = 0
    status.Parent = Content
    local stc = Instance.new("UICorner"); stc.CornerRadius = UDim.new(0,8); stc.Parent = status

    -- tombol utama
    btn("🔁 REPLAY LAST ID", Color3.fromRGB(0, 170, 115), replayLast, 52)
    btn("📦 Replay Semua ID", Color3.fromRGB(50, 110, 200), replayAll)

    local spd = btn("⚡ Speed: OFF", Color3.fromRGB(70,70,90), function() end)
    spd.MouseButton1Click:Connect(function()
        setSpeedOn(not State.SpeedOn)
        spd.Text = "⚡ Speed: " .. (State.SpeedOn and "ON" or "OFF")
        spd.BackgroundColor3 = State.SpeedOn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    local auto = btn("🔄 Auto Replay: OFF", Color3.fromRGB(70,70,90), function() end)
    auto.MouseButton1Click:Connect(function()
        CONFIG.AutoReplay = not CONFIG.AutoReplay
        auto.Text = "🔄 Auto Replay: " .. (CONFIG.AutoReplay and "ON" or "OFF")
        auto.BackgroundColor3 = CONFIG.AutoReplay and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 70)
    info.BackgroundTransparency = 1
    info.Text = "CARA PAKAI:\n1. Steal manual 1x (rekam ID)\n2. Tap REPLAY LAST ID\n3. Nyalakan Auto Replay untuk loop"
    info.TextColor3 = Color3.fromRGB(180,180,180)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextWrapped = true
    info.Parent = Content

    -- update status realtime
    task.spawn(function()
        while _G.SteakFinalLoaded do
            task.wait(0.5)
            pcall(function()
                status.Text = "🔗 Hook: " .. (State.Hooked and "ON" or "OFF") ..
                              "  |  📦 ID: " .. (State.LastId or "-") ..
                              "  |  ♻️ " .. State.ReplayCount
            end)
        end
    end)

    -- toggle
    local function setOpen(open)
        State.UIOpen = open
        if open then
            Main.Visible = true
            TweenService:Create(Main, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 290, 0, 400)
            }):Play()
        else
            TweenService:Create(Main, TweenInfo.new(0.15), {
                Size = UDim2.new(0, 290, 0, 0)
            }):Play()
            task.delay(0.15, function()
                if not State.UIOpen then Main.Visible = false end
            end)
        end
    end

    float.MouseButton1Click:Connect(function() setOpen(not State.UIOpen) end)
    CloseBtn.MouseButton1Click:Connect(function() setOpen(false) end)
end

-- ================= INIT =================
createUI()
setupHook()
notify("Steak Final", State.Hooked and "Hook ON - siap replay!" or "Hook GAGAL")

LP.CharacterAdded:Connect(function()
    task.wait(1)
    setSpeed(CONFIG.NormalSpeed)
end)
