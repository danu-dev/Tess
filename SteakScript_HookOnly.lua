--[[ =========================================================
     STEAK SCRIPT - HOOK ONLY (ID server-side)
     - Scan 0 ID? Tenang, hook rekam ID valid otomatis
     - UI: minimize ke bar kecil / close total
     - Mobile friendly
     Load: loadstring(game:HttpGet(".../SteakScript_HookOnly.lua"))()
========================================================= ]]

if _G.StealHookLoaded then
    pcall(function() _G.StealHookUI:Destroy() end)
end
_G.StealHookLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

local CONFIG = {
    NormalSpeed = 16,
    BoostSpeed  = 28,
    MaxSpeed    = 32,
    StealAction = "requestReplicateToServerInteractable",
    StealVerb   = "steal",
    Cooldown    = 1.5,
    MaxLog      = 30,
}

local State = {
    SpeedOn     = false,
    Busy        = false,
    LastTime    = 0,
    Hooked      = false,
    RecordedIds = {},
    LogLines    = {},
    Base        = nil,
    UIMode      = "full",  -- "full" | "minimized" | "closed"
}

-- ================= UTIL =================
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function setSpeed(s)
    local h = getHum()
    if h then h.WalkSpeed = math.clamp(s, 0, CONFIG.MaxSpeed) end
end

-- ================= LOG =================
local LogScroll = nil
local function addLog(msg, color)
    local ts = os.date("%H:%M:%S")
    table.insert(State.LogLines, { text = "["..ts.."] "..msg, color = color or Color3.fromRGB(200,200,200) })
    if #State.LogLines > CONFIG.MaxLog then table.remove(State.LogLines, 1) end
    if LogScroll then
        for _, ch in ipairs(LogScroll:GetChildren()) do
            if ch:IsA("TextLabel") then ch:Destroy() end
        end
        for _, e in ipairs(State.LogLines) do
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -8, 0, 16)
            l.BackgroundTransparency = 1
            l.Text = e.text
            l.TextColor3 = e.color
            l.Font = Enum.Font.Code
            l.TextSize = 10
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = LogScroll
        end
        LogScroll.CanvasSize = UDim2.new(0, 0, 0, #State.LogLines * 18)
        LogScroll.CanvasPosition = Vector2.new(0, math.max(0, #State.LogLines * 18 - LogScroll.AbsoluteSize.Y))
    end
    print("[HookOnly] "..msg)
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
        local old = remote.FireServer
        hookFunc(old, function(self, action, id, verb, ...)
            if action == CONFIG.StealAction and verb == CONFIG.StealVerb and type(id) == "number" then
                local new = not State.RecordedIds[id]
                State.RecordedIds[id] = tick()
                if new then
                    addLog("🔗 Rekam ID valid: "..id, Color3.fromRGB(0,220,120))
                end
            end
            return old(self, action, id, verb, ...)
        end)
        State.Hooked = true
    end)
    return ok
end

-- ================= STEAL =================
local function sendSteal(id)
    local remote = getRemote()
    if not remote then return false end
    local ok = pcall(function()
        remote:FireServer(CONFIG.StealAction, id, CONFIG.StealVerb)
    end)
    addLog(ok and ("📤 Kirim ID "..id) or ("❌ Gagal ID "..id), ok and Color3.fromRGB(200,200,255) or Color3.fromRGB(255,100,100))
    return ok
end

local function stealRecorded()
    if State.Busy then
        addLog("⏳ Sibuk...", Color3.fromRGB(255,200,100))
        return
    end
    local now = tick()
    if now - State.LastTime < CONFIG.Cooldown then return end
    State.Busy = true
    State.LastTime = now

    task.spawn(function()
        local ids = {}
        for id in pairs(State.RecordedIds) do table.insert(ids, id) end
        if #ids == 0 then
            addLog("❌ Belum ada ID. Steal manual 1x dulu!", Color3.fromRGB(255,100,100))
            notify("Steal", "Steal manual 1x dulu biar ke-hook")
            State.Busy = false
            return
        end
        addLog("✅ "..#ids.." ID terekam, kirim...", Color3.fromRGB(0,255,150))
        for i, id in ipairs(ids) do
            sendSteal(id)
            task.wait(0.3)
        end
        addLog("🎉 Selesai", Color3.fromRGB(0,255,150))
        State.SpeedOn = true
        setSpeed(CONFIG.BoostSpeed)
        addLog("⚡ Speed ON ("..CONFIG.BoostSpeed..")", Color3.fromRGB(0,220,120))
        State.Busy = false
    end)
end

-- ================= BASE =================
local function setBase()
    local hrp = getHRP()
    if hrp then
        State.Base = hrp.Position
        addLog("📍 Base diset", Color3.fromRGB(0,220,120))
    end
end
local function distBase()
    local hrp = getHRP()
    if not hrp or not State.Base then return nil end
    return math.floor((hrp.Position - State.Base).Magnitude)
end

-- ================= UI =================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "StealHookUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.StealHookUI = gui

    -- ===== FLOATING BUTTON =====
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

    -- ===== MAIN PANEL =====
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 320, 0, 500)
    Main.Position = UDim2.new(0, 70, 0.5, -250)
    Main.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,12); mc.Parent = Main
    local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(0,200,140); ms.Thickness = 2; ms.Parent = Main

    -- ===== TITLE BAR =====
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0,12); tbc.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🥩 HOOK STEAL"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    -- tombol minimize (—)
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 32, 0, 32)
    MinBtn.Position = UDim2.new(1, -76, 0, 4)
    MinBtn.BackgroundColor3 = Color3.fromRGB(180, 140, 0)
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 18
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0,8); mbc.Parent = MinBtn

    -- tombol close (✕)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -38, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TitleBar
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,8); cbc.Parent = CloseBtn

    -- ===== CONTENT =====
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -50)
    Content.Position = UDim2.new(0, 8, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Parent = Main
    local v = Instance.new("UIListLayout"); v.Padding = UDim.new(0, 6); v.SortOrder = Enum.SortOrder.LayoutOrder; v.Parent = Content

    -- status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 28)
    status.BackgroundColor3 = Color3.fromRGB(35,35,45)
    status.Text = "🔗 Hook: OFF | 📦 ID: 0"
    status.TextColor3 = Color3.fromRGB(255,200,100)
    status.Font = Enum.Font.GothamSemibold
    status.TextSize = 12
    status.BorderSizePixel = 0
    status.LayoutOrder = 1
    status.Parent = Content
    local stc = Instance.new("UICorner"); stc.CornerRadius = UDim.new(0,8); stc.Parent = status

    local function btn(text, color, cb, order, height)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, height or 42)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 13
        b.BorderSizePixel = 0
        b.LayoutOrder = order
        b.Parent = Content
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    btn("🔁 KIRIM ULANG ID TEREKAM", Color3.fromRGB(0, 170, 115), stealRecorded, 2, 52)
    btn("📍 Set Base", Color3.fromRGB(50, 170, 110), setBase, 3)

    local spd = btn("⚡ Speed: OFF", Color3.fromRGB(70,70,90), function() end, 4)
    spd.MouseButton1Click:Connect(function()
        State.SpeedOn = not State.SpeedOn
        setSpeed(State.SpeedOn and CONFIG.BoostSpeed or CONFIG.NormalSpeed)
        spd.Text = "⚡ Speed: " .. (State.SpeedOn and "ON" or "OFF")
        spd.BackgroundColor3 = State.SpeedOn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
        addLog("⚡ Speed "..(State.SpeedOn and "ON" or "OFF"), State.SpeedOn and Color3.fromRGB(0,220,120) or Color3.fromRGB(200,200,200))
    end)

    -- log header
    local lh = Instance.new("TextLabel")
    lh.Size = UDim2.new(1, 0, 0, 24)
    lh.BackgroundColor3 = Color3.fromRGB(35,35,45)
    lh.Text = "📜 LOG"
    lh.TextColor3 = Color3.fromRGB(0,220,150)
    lh.Font = Enum.Font.GothamBold
    lh.TextSize = 12
    lh.BorderSizePixel = 0
    lh.LayoutOrder = 5
    lh.Parent = Content
    local lhc = Instance.new("UICorner"); lhc.CornerRadius = UDim.new(0,8); lhc.Parent = lh

    local logFrame = Instance.new("Frame")
    logFrame.Size = UDim2.new(1, 0, 0, 200)
    logFrame.BackgroundColor3 = Color3.fromRGB(12,12,18)
    logFrame.BorderSizePixel = 0
    logFrame.LayoutOrder = 6
    logFrame.Parent = Content
    local lfc = Instance.new("UICorner"); lfc.CornerRadius = UDim.new(0,8); lfc.Parent = logFrame

    local logS = Instance.new("ScrollingFrame")
    logS.Size = UDim2.new(1, -8, 1, -8)
    logS.Position = UDim2.new(0, 4, 0, 4)
    logS.BackgroundTransparency = 1
    logS.BorderSizePixel = 0
    logS.ScrollBarThickness = 4
    logS.ScrollBarImageColor3 = Color3.fromRGB(0,160,110)
    logS.CanvasSize = UDim2.new(0, 0, 0, 0)
    logS.Parent = logFrame
    LogScroll = logS

    -- update status
    task.spawn(function()
        while _G.StealHookLoaded do
            task.wait(0.5)
            pcall(function()
                local n = 0
                for _ in pairs(State.RecordedIds) do n = n + 1 end
                local d = distBase()
                status.Text = "🔗 Hook: "..(State.Hooked and "ON" or "OFF").." | 📦 ID: "..n
                if d then status.Text = status.Text.." | 📍 "..d.."m" end
                status.TextColor3 = State.Hooked and Color3.fromRGB(0,255,150) or Color3.fromRGB(255,150,100)
            end)
        end
    end)

    -- ===== MINIMIZE BAR (saat minimized) =====
    local MiniBar = Instance.new("TextButton")
    MiniBar.Size = UDim2.new(0, 260, 0, 38)
    MiniBar.Position = UDim2.new(0, 70, 0, 20)
    MiniBar.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    MiniBar.Text = "🥩 HOOK STEAL  ▼"
    MiniBar.TextColor3 = Color3.new(1,1,1)
    MiniBar.Font = Enum.Font.GothamBold
    MiniBar.TextSize = 13
    MiniBar.BorderSizePixel = 0
    MiniBar.Visible = false
    MiniBar.Active = true
    MiniBar.Draggable = true
    MiniBar.Parent = gui
    local mbc2 = Instance.new("UICorner"); mbc2.CornerRadius = UDim.new(0,10); mbc2.Parent = MiniBar
    local mbs = Instance.new("UIStroke"); mbs.Color = Color3.fromRGB(0,255,180); mbs.Thickness = 2; mbs.Parent = MiniBar

    -- ===== TOGGLE FUNCTIONS =====
    local function setMode(mode)
        State.UIMode = mode
        if mode == "full" then
            Main.Visible = true
            MiniBar.Visible = false
            Main.Size = UDim2.new(0, 320, 0, 0)
            TweenService:Create(Main, TweenInfo.new(0.2), { Size = UDim2.new(0, 320, 0, 500) }):Play()
        elseif mode == "minimized" then
            TweenService:Create(Main, TweenInfo.new(0.15), { Size = UDim2.new(0, 320, 0, 0) }):Play()
            task.delay(0.15, function()
                if State.UIMode == "minimized" then
                    Main.Visible = false
                    MiniBar.Visible = true
                    -- posisi mini bar ikut posisi main
                    MiniBar.Position = UDim2.new(0, Main.AbsolutePosition.X, 0, Main.AbsolutePosition.Y)
                    MiniBar.Size = UDim2.new(0, 0, 0, 38)
                    TweenService:Create(MiniBar, TweenInfo.new(0.2), { Size = UDim2.new(0, 260, 0, 38) }):Play()
                end
            end)
        elseif mode == "closed" then
            TweenService:Create(Main, TweenInfo.new(0.15), { Size = UDim2.new(0, 320, 0, 0) }):Play()
            task.delay(0.15, function()
                if State.UIMode == "closed" then
                    Main.Visible = false
                    MiniBar.Visible = false
                end
            end)
        end
    end

    MinBtn.MouseButton1Click:Connect(function() setMode("minimized") end)
    CloseBtn.MouseButton1Click:Connect(function() setMode("closed") end)
    MiniBar.MouseButton1Click:Connect(function() setMode("full") end)

    float.MouseButton1Click:Connect(function()
        if State.UIMode == "full" then
            setMode("closed")
        else
            setMode("full")
        end
    end)

    addLog("🚀 Script dimuat", Color3.fromRGB(0,255,150))
    addLog("Steal manual 1x biar ID terekam", Color3.fromRGB(255,200,100))
end

-- ================= INIT =================
createUI()
local hooked = setupHook()
addLog(hooked and "🔗 Hook ON - siap rekam" or "⚠ Hook GAGAL", hooked and Color3.fromRGB(0,255,150) or Color3.fromRGB(255,100,100))
notify("Hook Steal", hooked and "Hook ON" or "Hook OFF")
