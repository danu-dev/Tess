--[[ =========================================================
     STEAK SCRIPT - STEAL + SPEED + LOG PANEL
     - Log realtime (scan, steal, speed, base)
     - UI rapi + bisa buka/tutup (mobile friendly)
     - Tanpa teleportasi instan (aman validasi posisi)
     Load: loadstring(game:HttpGet(".../SteakScript_StealSpeedLog.lua"))()
========================================================= ]]

if _G.StealLogLoaded then
    pcall(function() _G.StealLogUI:Destroy() end)
end
_G.StealLogLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ================= CONFIG =================
local CONFIG = {
    NormalSpeed  = 16,
    BoostSpeed   = 28,
    MaxSpeed     = 32,
    StealAction  = "requestReplicateToServerInteractable",
    StealVerb    = "steal",
    ScanRadius   = 40,
    Cooldown     = 1.5,
    AutoSteal    = false,
    MaxLogLines  = 50,
}

local State = {
    SpeedOn  = false,
    Busy     = false,
    LastTime = 0,
    Base     = nil,
    LogLines = {},
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

-- ================= LOG SYSTEM =================
local LogLabel = nil   -- diisi setelah UI dibuat
local LogScroll = nil

local function addLog(msg, color)
    local timestamp = os.date("%H:%M:%S")
    local line = "[" .. timestamp .. "] " .. msg
    table.insert(State.LogLines, { text = line, color = color or Color3.fromRGB(200,200,200) })
    if #State.LogLines > CONFIG.MaxLogLines then
        table.remove(State.LogLines, 1)
    end
    -- update UI
    if LogScroll then
        for _, child in ipairs(LogScroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        for _, entry in ipairs(State.LogLines) do
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -8, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Text = entry.text
            lbl.TextColor3 = entry.color
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextWrapped = false
            lbl.Parent = LogScroll
        end
        LogScroll.CanvasSize = UDim2.new(0, 0, 0, #State.LogLines * 18)
        LogScroll.CanvasPosition = Vector2.new(0, math.max(0, #State.LogLines * 18 - LogScroll.AbsoluteSize.Y))
    end
    print("[SteakLog] " .. line)
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

-- ================= SCAN =================
local function findNearbyIds()
    local results = {}
    local hrp = getHRP()
    if not hrp then return results end

    local seen = {}
    local function add(id, name)
        if id and not seen[id] then
            seen[id] = true
            table.insert(results, { id = id, name = name })
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        local pos
        if obj:IsA("BasePart") then pos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
        if pos and (pos - hrp.Position).Magnitude <= CONFIG.ScanRadius then
            for _, attr in ipairs(obj:GetAttributes()) do
                local ln = attr:lower()
                if ln:find("id") or ln:find("interact") then
                    local n = tonumber(obj:GetAttribute(attr))
                    if n then add(n, obj.Name) end
                end
            end
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") then
                    local ln = child.Name:lower()
                    if ln:find("id") or ln:find("interact") then
                        local n = tonumber(child.Value)
                        if n then add(n, obj.Name) end
                    end
                end
            end
        end
    end
    return results
end

-- ================= STEAL =================
local function stealNearby()
    if State.Busy then
        addLog("⏳ Masih sibuk, tunggu...", Color3.fromRGB(255,200,100))
        return
    end
    local now = tick()
    if now - State.LastTime < CONFIG.Cooldown then
        addLog("⏳ Cooldown " .. string.format("%.1f", CONFIG.Cooldown - (now - State.LastTime)) .. "s", Color3.fromRGB(255,200,100))
        return
    end
    State.Busy = true
    State.LastTime = now

    task.spawn(function()
        addLog("🔎 Scan objek radius " .. CONFIG.ScanRadius .. "...", Color3.fromRGB(100,200,255))
        local ids = findNearbyIds()
        local remote = getRemote()

        if not remote then
            addLog("❌ Remote Interactables tidak ditemukan", Color3.fromRGB(255,100,100))
            State.Busy = false
            return
        end
        if #ids == 0 then
            addLog("❌ Tidak ada objek dekat (radius " .. CONFIG.ScanRadius .. ")", Color3.fromRGB(255,100,100))
            notify("Steal", "Tidak ada objek dekat")
            State.Busy = false
            return
        end

        addLog("✅ Ditemukan " .. #ids .. " objek", Color3.fromRGB(0,255,150))

        for i, entry in ipairs(ids) do
            addLog("📤 Kirim steal ID " .. entry.id .. " (" .. entry.name .. ")", Color3.fromRGB(200,200,255))
            local ok = pcall(function()
                remote:FireServer(CONFIG.StealAction, entry.id, CONFIG.StealVerb)
            end)
            if ok then
                addLog("   ✔ Terkirim #" .. i, Color3.fromRGB(0,220,120))
            else
                addLog("   ✘ Gagal kirim #" .. i, Color3.fromRGB(255,100,100))
            end
            task.wait(0.2)
        end

        addLog("🎉 Selesai curi " .. #ids .. " objek", Color3.fromRGB(0,255,150))
        notify("Steal", "Curi " .. #ids .. " objek")

        -- auto speed ON
        State.SpeedOn = true
        setSpeed(CONFIG.BoostSpeed)
        addLog("⚡ Speed ON (" .. CONFIG.BoostSpeed .. ")", Color3.fromRGB(0,220,120))
        addLog("🏃 Balik ke base manual!", Color3.fromRGB(255,200,100))

        State.Busy = false
    end)
end

-- auto loop
task.spawn(function()
    while _G.StealLogLoaded do
        task.wait(1.5)
        if CONFIG.AutoSteal and not State.Busy then
            pcall(stealNearby)
        end
    end
end)

-- ================= BASE =================
local function setBaseHere()
    local hrp = getHRP()
    if hrp then
        State.Base = hrp.Position
        addLog("📍 Base diset di posisi ini", Color3.fromRGB(0,220,120))
        notify("Base", "Base diset")
    else
        addLog("❌ Character tidak ada", Color3.fromRGB(255,100,100))
    end
end

local function getDistanceToBase()
    local hrp = getHRP()
    if not hrp or not State.Base then return nil end
    return math.floor((hrp.Position - State.Base).Magnitude)
end

-- ================= UI =================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "StealLogUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.StealLogUI = gui

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
    Main.Size = UDim2.new(0, 320, 0, 480)
    Main.Position = UDim2.new(0, 70, 0.5, -240)
    Main.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,12); mc.Parent = Main
    local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(0,200,140); ms.Thickness = 2; ms.Parent = Main

    -- title bar
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    Title.Text = "🥩 STEAL + SPEED + LOG"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
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

    -- ===== CONTENT =====
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -50)
    Content.Position = UDim2.new(0, 8, 0, 45)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    -- layout vertikal
    local vLayout = Instance.new("UIListLayout")
    vLayout.Padding = UDim.new(0, 6)
    vLayout.SortOrder = Enum.SortOrder.LayoutOrder
    vLayout.Parent = Content

    -- status jarak
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 28)
    status.BackgroundColor3 = Color3.fromRGB(35,35,45)
    status.Text = "📍 Base belum diset"
    status.TextColor3 = Color3.fromRGB(255,200,100)
    status.Font = Enum.Font.GothamSemibold
    status.TextSize = 12
    status.BorderSizePixel = 0
    status.LayoutOrder = 1
    status.Parent = Content
    local stc = Instance.new("UICorner"); stc.CornerRadius = UDim.new(0,8); stc.Parent = status

    -- tombol curi
    local stealBtn = Instance.new("TextButton")
    stealBtn.Size = UDim2.new(1, 0, 0, 50)
    stealBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 115)
    stealBtn.Text = "🥩 CURi OBJEK DEKAT"
    stealBtn.TextColor3 = Color3.new(1,1,1)
    stealBtn.Font = Enum.Font.GothamBold
    stealBtn.TextSize = 15
    stealBtn.BorderSizePixel = 0
    stealBtn.LayoutOrder = 2
    stealBtn.Parent = Content
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,8); sc.Parent = stealBtn

    -- baris tombol kecil
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundTransparency = 1
    row.LayoutOrder = 3
    row.Parent = Content
    local rLayout = Instance.new("UIListLayout")
    rLayout.FillDirection = Enum.FillDirection.Horizontal
    rLayout.Padding = UDim.new(0, 6)
    rLayout.Parent = row

    local function smallBtn(text, color, parent, width)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(width or 0.5, -3, 1, 0)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
        return b
    end

    local baseBtn = smallBtn("📍 Set Base", Color3.fromRGB(50, 170, 110), row, 0.5)
    baseBtn.MouseButton1Click:Connect(function()
        pcall(setBaseHere)
    end)

    local speedBtn = smallBtn("⚡ Speed: OFF", Color3.fromRGB(70,70,90), row, 0.5)
    speedBtn.MouseButton1Click:Connect(function()
        State.SpeedOn = not State.SpeedOn
        setSpeed(State.SpeedOn and CONFIG.BoostSpeed or CONFIG.NormalSpeed)
        speedBtn.Text = "⚡ Speed: " .. (State.SpeedOn and "ON" or "OFF")
        speedBtn.BackgroundColor3 = State.SpeedOn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
        addLog("⚡ Speed " .. (State.SpeedOn and "ON" or "OFF"), State.SpeedOn and Color3.fromRGB(0,220,120) or Color3.fromRGB(200,200,200))
    end)

    -- auto steal toggle
    local autoBtn = Instance.new("TextButton")
    autoBtn.Size = UDim2.new(1, 0, 0, 34)
    autoBtn.BackgroundColor3 = Color3.fromRGB(70,70,90)
    autoBtn.Text = "🔄 Auto Steal: OFF"
    autoBtn.TextColor3 = Color3.new(1,1,1)
    autoBtn.Font = Enum.Font.GothamSemibold
    autoBtn.TextSize = 12
    autoBtn.BorderSizePixel = 0
    autoBtn.LayoutOrder = 4
    autoBtn.Parent = Content
    local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0,8); ac.Parent = autoBtn
    autoBtn.MouseButton1Click:Connect(function()
        CONFIG.AutoSteal = not CONFIG.AutoSteal
        autoBtn.Text = "🔄 Auto Steal: " .. (CONFIG.AutoSteal and "ON" or "OFF")
        autoBtn.BackgroundColor3 = CONFIG.AutoSteal and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
        addLog("🔄 Auto Steal " .. (CONFIG.AutoSteal and "ON" or "OFF"), Color3.fromRGB(200,200,255))
    end)

    -- ===== LOG PANEL =====
    local logHeader = Instance.new("TextLabel")
    logHeader.Size = UDim2.new(1, 0, 0, 24)
    logHeader.BackgroundColor3 = Color3.fromRGB(35,35,45)
    logHeader.Text = "📜 LOG AKTIVITAS"
    logHeader.TextColor3 = Color3.fromRGB(0,220,150)
    logHeader.Font = Enum.Font.GothamBold
    logHeader.TextSize = 12
    logHeader.BorderSizePixel = 0
    logHeader.LayoutOrder = 5
    logHeader.Parent = Content
    local lhc = Instance.new("UICorner"); lhc.CornerRadius = UDim.new(0,8); lhc.Parent = logHeader

    local logFrame = Instance.new("Frame")
    logFrame.Size = UDim2.new(1, 0, 0, 180)
    logFrame.BackgroundColor3 = Color3.fromRGB(12,12,18)
    logFrame.BorderSizePixel = 0
    logFrame.LayoutOrder = 6
    logFrame.Parent = Content
    local lfc = Instance.new("UICorner"); lfc.CornerRadius = UDim.new(0,8); lfc.Parent = logFrame

    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, -8, 1, -8)
    logScroll.Position = UDim2.new(0, 4, 0, 4)
    logScroll.BackgroundTransparency = 1
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 4
    logScroll.ScrollBarImageColor3 = Color3.fromRGB(0,160,110)
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.Parent = logFrame
    LogScroll = logScroll

    -- update status jarak realtime
    task.spawn(function()
        while _G.StealLogLoaded do
            task.wait(0.5)
            pcall(function()
                local d = getDistanceToBase()
                if d then
                    status.Text = "📍 Jarak ke base: " .. d .. " stud"
                    status.TextColor3 = d < 30 and Color3.fromRGB(0,255,150) or Color3.fromRGB(255,200,100)
                else
                    status.Text = "📍 Base belum diset"
                end
            end)
        end
    end)

    -- tombol sambung
    stealBtn.MouseButton1Click:Connect(function()
        pcall(stealNearby)
    end)

    -- buka/tutup
    local open = true
    local function setOpen(o)
        open = o
        if open then
            Main.Visible = true
            TweenService:Create(Main, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 320, 0, 480)
            }):Play()
        else
            TweenService:Create(Main, TweenInfo.new(0.15), {
                Size = UDim2.new(0, 320, 0, 0)
            }):Play()
            task.delay(0.15, function()
                if not open then Main.Visible = false end
            end)
        end
    end
    float.MouseButton1Click:Connect(function() setOpen(not open) end)
    CloseBtn.MouseButton1Click:Connect(function() setOpen(false) end)

    -- log awal
    addLog("🚀 Script dimuat", Color3.fromRGB(0,255,150))
    addLog("Dekati objek lalu tap CURi", Color3.fromRGB(200,200,255))
end

-- ================= INIT =================
createUI()
notify("Steal+Speed+Log", "Loaded. Dekati objek, tap Curi. Log aktif.")

LP.CharacterAdded:Connect(function()
    task.wait(1)
    setSpeed(CONFIG.NormalSpeed)
    addLog("🔄 Respawn, speed reset", Color3.fromRGB(200,200,200))
end)
