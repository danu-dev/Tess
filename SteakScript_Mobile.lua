--[[ =========================================================
     STEAK SCRIPT - MOBILE EDITION
     Mobile friendly: floating button buka/tutup, UI draggable
     Remote-based steal (endpoints.Interactables)
     Load: loadstring(game:HttpGet(".../SteakScript_Mobile.lua"))()
========================================================= ]]

if _G.SteakMobileLoaded then
    pcall(function() _G.SteakMobileUI:Destroy() end)
end
_G.SteakMobileLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer

-- ================= CONFIG =================
local CONFIG = {
    NormalSpeed    = 16,
    SafeSpeed      = 26,
    MaxSpeed       = 32,
    StealAction    = "requestReplicateToServerInteractable",
    StealVerb      = "steal",
    SpamCount      = 3,
    SpamGap        = {0.08, 0.15},
    TargetCooldown = 1.2,
    ScanRadius     = 150,
    AutoScan       = false,
    AutoScanDelay  = {1.0, 2.0},
}

local State = {
    SpeedOn    = false,
    Busy       = false,
    LastTarget = 0,
    UIOpen     = true,
}

-- ================= UTIL =================
local function rnd(r) return r[1] + math.random() * (r[2] - r[1]) end
local function getChar() return LP.Character end
local function getHRP()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
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

-- ================= SCAN ID =================
local function findInteractableIds()
    local results = {}
    local hrp = getHRP()
    if not hrp then return results end

    local seen = {}
    local function add(id, obj)
        if id and not seen[id] then
            seen[id] = true
            table.insert(results, { id = id, obj = obj })
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
                    local v = obj:GetAttribute(attr)
                    local n = tonumber(v)
                    if n then add(n, obj) end
                end
            end
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") then
                    local ln = child.Name:lower()
                    if ln:find("id") or ln:find("interact") then
                        local n = tonumber(child.Value)
                        if n then add(n, obj) end
                    end
                end
            end
        end
    end
    return results
end

-- ================= STEAL =================
local function stealId(id)
    local remote = getRemote()
    if not remote then
        notify("Error", "Remote tidak ditemukan")
        return
    end
    for i = 1, CONFIG.SpamCount do
        pcall(function()
            remote:FireServer(CONFIG.StealAction, id, CONFIG.StealVerb)
        end)
        if i < CONFIG.SpamCount then task.wait(rnd(CONFIG.SpamGap)) end
    end
end

local function stealAll()
    if State.Busy then return end
    local now = tick()
    if now - State.LastTarget < CONFIG.TargetCooldown then return end
    State.Busy = true
    State.LastTarget = now

    task.spawn(function()
        local ids = findInteractableIds()
        if #ids == 0 then
            notify("Steal", "Tidak ada interactable di radius "..CONFIG.ScanRadius)
            State.Busy = false
            return
        end
        for _, entry in ipairs(ids) do
            stealId(entry.id)
            task.wait(rnd({0.15, 0.4}))
        end
        notify("Steal", "Selesai ("..#ids.." target)")
        State.Busy = false
    end)
end

local function stealManual(id)
    if not id then return end
    notify("Steal", "Kirim ID: "..id)
    stealId(id)
end

-- ================= SPEED =================
local function setSpeedOn(on)
    State.SpeedOn = on
    setSpeed(on and CONFIG.SafeSpeed or CONFIG.NormalSpeed)
    notify("Speed", on and ("ON ("..CONFIG.SafeSpeed..")") or "OFF")
end

-- auto loop
task.spawn(function()
    while _G.SteakMobileLoaded do
        task.wait(rnd(CONFIG.AutoScanDelay))
        if CONFIG.AutoScan and not State.Busy then
            pcall(stealAll)
        end
    end
end)

-- ================= UI =================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SteakMobileUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.SteakMobileUI = gui

    -- ===== FLOATING BUTTON (buka/tutup) =====
    local float = Instance.new("TextButton")
    float.Name = "FloatBtn"
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
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 280, 0, 400)
    Main.Position = UDim2.new(0, 80, 0.5, -200)
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
    Title.Text = "🥩 STEAK MOBILE"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.BorderSizePixel = 0
    Title.Parent = Main
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,12); tc.Parent = Title

    -- close button
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

    -- content scroll
    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -16, 1, -50)
    Content.Position = UDim2.new(0, 8, 0, 45)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.ScrollBarImageColor3 = Color3.fromRGB(0,160,110)
    Content.CanvasSize = UDim2.new(0, 0, 0, 0)
    Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Content.Parent = Main
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = Content

    local function btn(text, color, cb, height)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, height or 42)
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

    -- tombol besar steal
    btn("🔎 SCAN & STEAL", Color3.fromRGB(0, 170, 115), stealAll, 50)

    -- input ID
    local idHolder = Instance.new("Frame")
    idHolder.Size = UDim2.new(1, 0, 0, 38)
    idHolder.BackgroundColor3 = Color3.fromRGB(35,35,45)
    idHolder.BorderSizePixel = 0
    idHolder.Parent = Content
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0,8); hc.Parent = idHolder

    local idBox = Instance.new("TextBox")
    idBox.Size = UDim2.new(0.55, -10, 0, 28)
    idBox.Position = UDim2.new(0, 10, 0.5, -14)
    idBox.BackgroundColor3 = Color3.fromRGB(50,50,62)
    idBox.BorderSizePixel = 0
    idBox.PlaceholderText = "ID (15230)"
    idBox.Text = "15230"
    idBox.TextColor3 = Color3.new(1,1,1)
    idBox.Font = Enum.Font.Gotham
    idBox.TextSize = 13
    idBox.Parent = idHolder
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = idBox

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.4, 0, 0, 28)
    sendBtn.Position = UDim2.new(0.57, 0, 0.5, -14)
    sendBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
    sendBtn.Text = "Steal ID"
    sendBtn.TextColor3 = Color3.new(1,1,1)
    sendBtn.Font = Enum.Font.GothamSemibold
    sendBtn.TextSize = 13
    sendBtn.BorderSizePixel = 0
    sendBtn.Parent = idHolder
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,6); sc.Parent = sendBtn
    sendBtn.MouseButton1Click:Connect(function()
        stealManual(tonumber(idBox.Text))
    end)

    -- speed
    local spd = btn("⚡ Speed: OFF", Color3.fromRGB(70,70,90), function() end)
    spd.MouseButton1Click:Connect(function()
        setSpeedOn(not State.SpeedOn)
        spd.Text = "⚡ Speed: " .. (State.SpeedOn and "ON" or "OFF")
        spd.BackgroundColor3 = State.SpeedOn and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    -- auto scan
    local auto = btn("🔁 Auto Scan: OFF", Color3.fromRGB(70,70,90), function() end)
    auto.MouseButton1Click:Connect(function()
        CONFIG.AutoScan = not CONFIG.AutoScan
        auto.Text = "🔁 Auto Scan: " .. (CONFIG.AutoScan and "ON" or "OFF")
        auto.BackgroundColor3 = CONFIG.AutoScan and Color3.fromRGB(0,160,110) or Color3.fromRGB(70,70,90)
    end)

    -- info
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 70)
    info.BackgroundTransparency = 1
    info.Text = "Remote: endpoints.Interactables\nSpam: "..CONFIG.SpamCount.."x | Cooldown: "..CONFIG.TargetCooldown.."s\nDrag tombol 🥩 untuk pindah\nTekan ✕ untuk tutup"
    info.TextColor3 = Color3.fromRGB(180,180,180)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextWrapped = true
    info.Parent = Content

    -- ===== TOGGLE =====
    local function setOpen(open)
        State.UIOpen = open
        if open then
            Main.Visible = true
            Main.Size = UDim2.new(0, 280, 0, 0)
            TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, 280, 0, 400)
            }):Play()
        else
            TweenService:Create(Main, TweenInfo.new(0.15), {
                Size = UDim2.new(0, 280, 0, 0)
            }):Play()
            task.delay(0.15, function()
                if not State.UIOpen then Main.Visible = false end
            end)
        end
    end

    float.MouseButton1Click:Connect(function()
        setOpen(not State.UIOpen)
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        setOpen(false)
    end)

    return gui
end

-- ================= HOTKEY (kalau ada keyboard) =================
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.E then stealAll()
    elseif i.KeyCode == Enum.KeyCode.R then setSpeedOn(false)
    end
end)

-- ================= INIT =================
createUI()
notify("Steak Mobile", "Loaded. Tap 🥩 untuk buka/tutup UI.")

LP.CharacterAdded:Connect(function()
    task.wait(1)
    setSpeed(CONFIG.NormalSpeed)
end)
