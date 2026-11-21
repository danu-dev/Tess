--[[
    SENAR HUB | Build to Defend Loot
    Improved & Debugged (BaseOwner + VALUABLE + fireproximityprompt)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
if not LP then return end

-- CONFIG & STATE
local RARITIES = { "ALL", "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET", "OG" }
local Flags = {
    autosteal   = false,
    resetfirst  = true,
    trydisabled = true,
    walkspeed   = false,
    infjump     = false,
    antiafk     = true,
}
local Vals = { speed = 35, rarityIdx = 1 }
local hooks, widgets = {}, {}
local conns = {}
local function track(c) table.insert(conns, c) return c end

local env = (getgenv and getgenv()) or _G
if env.__SenarBTDL then pcall(env.__SenarBTDL) end

-- UI HELPERS
local C = {
    BG    = Color3.fromRGB(13, 10, 8),
    PANEL = Color3.fromRGB(20, 15, 11),
    CARD  = Color3.fromRGB(27, 20, 14),
    CARD2 = Color3.fromRGB(42, 30, 20),
    OR    = Color3.fromRGB(255, 122, 0),
    OR2   = Color3.fromRGB(255, 178, 76),
    DEEP  = Color3.fromRGB(115, 50, 0),
    TXT   = Color3.fromRGB(255, 255, 255),
    SUB   = Color3.fromRGB(168, 152, 138),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, col, th)
    return new("UIStroke", { Color = col or C.DEEP, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function pad(o, l, t, r, b)
    return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) }, o)
end
local function tw(o, t, p, style, dir)
    local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p)
    x:Play()
    return x
end
local function isPointer(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function makeGui()
    local gui = new("ScreenGui", { Name = "SenarHubBTDL", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) elseif protectgui then protectgui(gui) end
    end)
    for _, g in ipairs({
        function() return gethui and gethui() end,
        function() return game:GetService("CoreGui") end,
        function() return LP:WaitForChild("PlayerGui", 5) end,
    }) do
        local ok, p = pcall(g)
        if ok and p and pcall(function() gui.Parent = p end) and gui.Parent == p then return gui end
    end
    error("Tidak bisa menaruh UI")
end

local gui = makeGui()
env.__SenarBTDL = function()
    if gui and gui.Parent then gui:Destroy() end
end

-- WINDOW
local W, HEAD_H, FULL_H = 360, 56, 420
local cam0 = workspace.CurrentCamera
local vp = cam0 and cam0.ViewportSize or Vector2.new(800, 400)
local baseScale = math.clamp(math.min(vp.X / (W + 32), vp.Y / (FULL_H + 32)), 0.5, 1.1)

local Main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -FULL_H * baseScale / 2),
    Size = UDim2.fromOffset(W, FULL_H), BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(Main, 16)
local mainScale = new("UIScale", { Scale = baseScale }, Main)
stroke(Main, C.OR, 1.8)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, HEAD_H), BackgroundColor3 = C.PANEL, BorderSizePixel = 0, ZIndex = 2 }, Main)
new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.DEEP, BorderSizePixel = 0, ZIndex = 3 }, header)

local logoBox = new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 10), BackgroundColor3 = C.CARD,
    BorderSizePixel = 0, ZIndex = 3 }, header)
corner(logoBox, 10)
stroke(logoBox, C.OR, 1.3)
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "S", TextColor3 = C.OR,
    Font = Enum.Font.GothamBlack, TextSize = 20, ZIndex = 4 }, logoBox)

new("TextLabel", { Position = UDim2.fromOffset(56, 8), Size = UDim2.fromOffset(180, 20), BackgroundTransparency = 1,
    Text = "<font color='#FFFFFF'>Senar</font> <font color='#FF7A00'>Hub</font>", RichText = true,
    Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, header)
new("TextLabel", { Position = UDim2.fromOffset(56, 29), Size = UDim2.fromOffset(190, 16), BackgroundTransparency = 1,
    Text = "Build to Defend Loot", TextColor3 = C.SUB, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, header)

local minBtn = new("TextButton", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -74, 0, 14), BackgroundColor3 = C.CARD,
    Text = "-", TextColor3 = C.OR, Font = Enum.Font.GothamBlack, TextSize = 18, AutoButtonColor = false, ZIndex = 5 }, header)
corner(minBtn, 8)
stroke(minBtn, C.DEEP, 1.2)

local closeBtn = new("TextButton", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 14), BackgroundColor3 = C.CARD,
    Text = "X", TextColor3 = C.TXT, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false, ZIndex = 5 }, header)
corner(closeBtn, 8)
stroke(closeBtn, C.DEEP, 1.2)

do
    local dragging, start, startPos
    local dragArea = new("Frame", { Size = UDim2.new(1, -84, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 4 }, header)
    dragArea.InputBegan:Connect(function(i)
        if isPointer(i) then dragging, start, startPos = true, i.Position, Main.Position end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and isMove(i) then
            local d = (i.Position - start) / mainScale.Scale
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X * mainScale.Scale,
                startPos.Y.Scale, startPos.Y.Offset + d.Y * mainScale.Scale)
        end
    end))
    track(UIS.InputEnded:Connect(function(i) if isPointer(i) then dragging = false end end))
end

-- TABS
local tabBar = new("Frame", { Position = UDim2.fromOffset(12, HEAD_H + 8), Size = UDim2.new(1, -24, 0, 32),
    BackgroundColor3 = C.PANEL, BorderSizePixel = 0, ZIndex = 2 }, Main)
corner(tabBar, 10)
stroke(tabBar, C.DEEP, 1)
pad(tabBar, 3, 3, 3, 3)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
    HorizontalFlex = Enum.UIFlexAlignment.Fill, SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

local contentWrap = new("Frame", { Position = UDim2.fromOffset(12, HEAD_H + 46), Size = UDim2.new(1, -24, 1, -(HEAD_H + 46 + 40)),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 }, Main)

local tabs = {}
local function addTab(name, order)
    local btn = new("TextButton", { Size = UDim2.new(0.33, -3, 1, 0), BackgroundColor3 = C.CARD, BackgroundTransparency = 1,
        Text = name, TextColor3 = C.SUB, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = order, ZIndex = 3 }, tabBar)
    corner(btn, 8)
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.OR, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        Visible = false, ZIndex = 2,
    }, contentWrap)
    pad(page, 1, 2, 4, 4)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    local entry = { btn = btn, page = page }
    table.insert(tabs, entry)
    local function selectTab()
        for _, t in ipairs(tabs) do
            local sel = (t == entry)
            t.page.Visible = sel
            t.btn.TextColor3 = sel and Color3.fromRGB(20, 12, 4) or C.SUB
            tw(t.btn, 0.15, { BackgroundTransparency = sel and 0 or 1, BackgroundColor3 = sel and C.OR or C.CARD })
        end
    end
    btn.Activated:Connect(selectTab)
    if #tabs == 1 then selectTab() end
    return page
end

-- WIDGETS
local function setFlag(name, v)
    Flags[name] = v
    for _, f in ipairs(widgets[name] or {}) do f() end
    if hooks[name] then task.spawn(hooks[name], v) end
end

local function row(parent, h)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.CARD, BorderSizePixel = 0, ZIndex = 3 }, parent)
    corner(f, 10)
    stroke(f, C.DEEP, 1)
    return f
end

local function addToggle(parent, label, flag)
    local r = row(parent, 36)
    new("TextLabel", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -66, 1, 0), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TXT, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, r)
    local track_ = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = C.CARD2, BorderSizePixel = 0, ZIndex = 4 }, r)
    corner(track_, 10)
    local knob = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = C.SUB,
        BorderSizePixel = 0, ZIndex = 5 }, track_)
    corner(knob, 7)
    local function refresh()
        local on = Flags[flag]
        tw(track_, 0.16, { BackgroundColor3 = on and C.OR or C.CARD2 })
        tw(knob, 0.16, { Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = on and C.TXT or C.SUB })
    end
    widgets[flag] = widgets[flag] or {}
    table.insert(widgets[flag], refresh)
    refresh()
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, r)
    hit.Activated:Connect(function() setFlag(flag, not Flags[flag]) end)
end

local function addSlider(parent, label, key, minV, maxV)
    local r = row(parent, 48)
    new("TextLabel", { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -84, 0, 18), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TXT, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, r)
    local valLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.fromOffset(64, 18),
        BackgroundTransparency = 1, Text = tostring(Vals[key]), TextColor3 = C.OR2, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 }, r)
    local bar = new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = C.CARD2,
        BorderSizePixel = 0, ZIndex = 4 }, r)
    corner(bar, 3)
    local fill = new("Frame", { Size = UDim2.fromScale((Vals[key] - minV) / (maxV - minV), 1), BackgroundColor3 = C.OR,
        BorderSizePixel = 0, ZIndex = 5 }, bar)
    corner(fill, 3)
    local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((Vals[key] - minV) / (maxV - minV), 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = C.TXT, BorderSizePixel = 0, ZIndex = 6 }, bar)
    corner(knob, 7)
    local hit = new("TextButton", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        Text = "", ZIndex = 7 }, r)
    local sliding = false
    local function setFrom(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(minV + rel * (maxV - minV) + 0.5)
        Vals[key] = v
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = tostring(v)
    end
    hit.InputBegan:Connect(function(i) if isPointer(i) then sliding = true setFrom(i.Position.X) end end)
    track(UIS.InputChanged:Connect(function(i) if sliding and isMove(i) then setFrom(i.Position.X) end end))
    track(UIS.InputEnded:Connect(function(i) if isPointer(i) then sliding = false end end))
end

local function addButton(parent, text, cb)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.OR, Text = text, TextColor3 = Color3.fromRGB(20, 12, 4),
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 3 }, parent)
    corner(b, 10)
    b.Activated:Connect(function() task.spawn(cb) end)
    return b
end

local function addLabel(parent, text)
    return new("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = text, TextColor3 = C.SUB,
        Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3 }, parent)
end

-- STATUS BAR & LOG
local statusBar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -8), Size = UDim2.new(1, -24, 0, 28),
    BackgroundColor3 = C.PANEL, BorderSizePixel = 0, ZIndex = 3 }, Main)
corner(statusBar, 8)
stroke(statusBar, C.DEEP, 1)
local statusDot = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.SUB,
    BorderSizePixel = 0, ZIndex = 4 }, statusBar)
corner(statusDot, 4)
local statusLbl = new("TextLabel", { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1,
    Text = "Idle", TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 }, statusBar)
local statsLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(66, 28),
    BackgroundTransparency = 1, Text = "Steal 0", TextColor3 = C.OR2, Font = Enum.Font.GothamBold, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 }, statusBar)

local logs = {}
local logBox
local function addLog(msg)
    local line = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(msg)
    table.insert(logs, line)
    if #logs > 200 then table.remove(logs, 1) end
    if logBox then logBox.Text = table.concat(logs, "\n") end
end

local function setStatus(t)
    local s = tostring(t)
    statusLbl.Text = s
    statusLbl.TextColor3 = Flags.autosteal and C.TXT or C.SUB
    statusDot.BackgroundColor3 = Flags.autosteal and C.OR or C.SUB
    addLog("Status: " .. s)
end

-- MINIMIZE & FLOAT
local minimized = false
local function setMinimized(v)
    minimized = v
    minBtn.Text = v and "+" or "-"
    tabBar.Visible = not v
    contentWrap.Visible = not v
    statusBar.Visible = not v
    tw(Main, 0.25, { Size = UDim2.fromOffset(W, v and HEAD_H or FULL_H) }, Enum.EasingStyle.Quint)
end
minBtn.Activated:Connect(function() setMinimized(not minimized) end)

local floatBtn = new("TextButton", { Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 16, 0.5, -24), BackgroundColor3 = C.CARD,
    Text = "S", TextColor3 = C.OR, Font = Enum.Font.GothamBlack, TextSize = 22, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(floatBtn, 24)
stroke(floatBtn, C.OR, 2)
do
    local dragging, moved, start, startPos
    floatBtn.InputBegan:Connect(function(i)
        if isPointer(i) then dragging, moved, start, startPos = true, false, i.Position, floatBtn.Position end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and isMove(i) then
            local d = i.Position - start
            if d.Magnitude > 6 then moved = true end
            if moved then floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if dragging and isPointer(i) then
            dragging = false
            if not moved then
                floatBtn.Visible = false
                Main.Visible = true
            end
        end
    end))
end
closeBtn.Activated:Connect(function()
    Main.Visible = false
    floatBtn.Visible = true
end)

-- BUILD TABS
local stealTab  = addTab("Steal", 1)
local playerTab = addTab("Player", 2)
local debugTab  = addTab("Debug", 3)

addToggle(stealTab, "Auto Steal (Loop)", "autosteal")
addToggle(stealTab, "Reset Karakter dulu", "resetfirst")
addToggle(stealTab, "Coba Prompt Disabled", "trydisabled")

local rarBtn = addButton(stealTab, "Rarity: ALL (klik ganti)", function() end)
rarBtn.Activated:Connect(function()
    Vals.rarityIdx = (Vals.rarityIdx % #RARITIES) + 1
    rarBtn.Text = "Rarity: " .. RARITIES[Vals.rarityIdx] .. " (klik ganti)"
end)
local btnOnce = addButton(stealTab, "Steal 1x Sekarang", function() end)
local plotLbl = addLabel(stealTab, "My Plot: belum terdeteksi")

addToggle(playerTab, "Walk Speed", "walkspeed")
addSlider(playerTab, "Speed", "speed", 16, 100)
addToggle(playerTab, "Inf Jump", "infjump")
addButton(playerTab, "Unlock Zoom Limit", function()
    LP.CameraMinZoomDistance = 0.5
    LP.CameraMaxZoomDistance = 500
    LP.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
    setStatus("Zoom limit dibuka")
end)
addToggle(playerTab, "Anti AFK", "antiafk")
addButton(playerTab, "Hapus UI", function()
    Flags.autosteal = false
    if gui then gui:Destroy() end
end)

local function copyText(txt)
    local clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if clip then return pcall(clip, txt) end
    return false
end
addButton(debugTab, "Copy Semua Log", function()
    local txt = table.concat(logs, "\n")
    if copyText(txt) then statusLbl.Text = "Log disalin (" .. #logs .. ")" end
end)
local btnDumpVal = addButton(debugTab, "Dump VALUABLE Sekitar", function() end)
addButton(debugTab, "Clear Log", function()
    logs = {}
    if logBox then logBox.Text = "" end
end)
local logScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 165), BackgroundColor3 = C.PANEL, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = C.OR,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 3,
}, debugTab)
corner(logScroll, 8)
stroke(logScroll, C.DEEP, 1)
pad(logScroll, 6, 6, 6, 6)
logBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Text = "", TextColor3 = C.SUB, Font = Enum.Font.Code, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, MultiLine = true, TextEditable = false, ClearTextOnFocus = false, ZIndex = 4,
}, logScroll)

-- GAME LOGIC (Tora mechanics + bug fixes)
local myAvatar = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=100&h=100"
local myPlot, mySpawnPos = nil, nil
local skipUntil = {}
local stolen, token, busy = 0, 0, false

local function findMyPlot()
    local plots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Plots")
    if not plots then return nil end
    for _, v in ipairs(plots:GetDescendants()) do
        if v.Name == "BaseOwner" then
            local bb = v:FindFirstChild("Billboard")
            local av = bb and bb:FindFirstChild("Avatar")
            if av and av:IsA("ImageLabel") and av.Image == myAvatar then
                myPlot = v.Parent
                plotLbl.Text = "My Plot: " .. myPlot.Name
                return myPlot
            end
        end
    end
    return myPlot
end

local function getMySpawnCF()
    local plot = myPlot or findMyPlot()
    if plot then
        local sp = plot:FindFirstChild("Spawn", true)
        if sp and sp:IsA("BasePart") then return sp.CFrame end
    end
    return mySpawnPos and CFrame.new(mySpawnPos) or nil
end

local function isMyItem(item)
    if string.find(item.Name, tostring(LP.UserId), 1, true) then return true end
    local plot = myPlot
    if plot then
        local ok, cf, size = pcall(function() return plot:GetBoundingBox() end)
        if ok and cf and size then
            local rel = cf:PointToObjectSpace(item:GetPivot().Position)
            if math.abs(rel.X) <= size.X / 2 + 6 and math.abs(rel.Z) <= size.Z / 2 + 6 then
                return true
            end
        end
    end
    return false
end

local function findPromptPart(item)
    for _, d in ipairs(item:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") then
            return d.Parent, d
        end
    end
    return nil, nil
end

local function pickValuable()
    local placed = Workspace:FindFirstChild("PlacedItems")
    if not placed then return nil end
    local selRar = RARITIES[Vals.rarityIdx]
    local now = os.clock()
    local best, bestScore
    local total, mine, cd, dis = 0, 0, 0, 0

    for _, item in ipairs(placed:GetChildren()) do
        if item:GetAttribute("BuildableType") == "VALUABLE" then
            total += 1
            if isMyItem(item) then
                mine += 1
            elseif skipUntil[item] and now < skipUntil[item] then
                cd += 1
            elseif selRar == "ALL" or string.find(string.upper(item.Name), selRar, 1, true) then
                local part, prompt = findPromptPart(item)
                if part and prompt then
                    if not prompt.Enabled and not Flags.trydisabled then
                        dis += 1
                    else
                        local score = prompt.Enabled and 10000 or 0
                        for idx, r in ipairs(RARITIES) do
                            if r ~= "ALL" and string.find(string.upper(item.Name), r, 1, true) then
                                score += idx * 100
                            end
                        end
                        if not bestScore or score > bestScore then
                            best = { item = item, part = part, prompt = prompt }
                            bestScore = score
                        end
                    end
                end
            end
        end
    end

    if not best then
        addLog(("Pick nil (val=%d mine=%d dis=%d cd=%d rar=%s)"):format(total, mine, dis, cd, selRar))
    end
    return best
end

local function doStealOnce(tk)
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        findMyPlot()
        local target = pickValuable()
        if not target then
            setStatus("Loot musuh tidak ditemukan")
            task.wait(1.2)
            return
        end

        if Flags.resetfirst then
            setStatus("Reset karakter...")
            local c = LP.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
            local newC = LP.CharacterAdded:Wait()
            newC:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.35)
            mySpawnPos = newC.HumanoidRootPart.Position
        end
        if tk and (not Flags.autosteal or tk ~= token) then return end

        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not target.item.Parent then return end

        local prompt = target.prompt
        local triggered = false
        local trigConn = prompt.Triggered:Connect(function(plr)
            if plr == LP then triggered = true end
        end)

        setStatus("Steal: " .. target.item.Name)
        addLog(("Target: %s | act=%q en=%s hold=%.2f"):format(
            target.item.Name, prompt.ActionText, tostring(prompt.Enabled), prompt.HoldDuration))

        -- Sesuai mekanik Tora: TP ke part lalu fireproximityprompt tanpa mengubah HoldDuration ke 0
        for _ = 1, 3 do
            if not target.item.Parent or triggered then break end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = target.part.CFrame * CFrame.new(0, 1.5, 0)
            task.wait(0.2)
            if fireproximityprompt then pcall(fireproximityprompt, prompt) end
        end

        if not triggered and target.item.Parent and prompt.Parent then
            pcall(function() prompt:InputHoldBegin() end)
            local t0 = os.clock()
            local waitT = math.max(prompt.HoldDuration, 0.2) + 0.3
            while not triggered and target.item.Parent and os.clock() - t0 < waitT do
                if tk and (not Flags.autosteal or tk ~= token) then break end
                task.wait(0.1)
            end
            pcall(function() prompt:InputHoldEnd() end)
        end
        trigConn:Disconnect()

        local accepted = triggered and (not target.item.Parent or not prompt.Enabled)
        addLog(("Steal result: trig=%s itemGone=%s promptEn=%s"):format(
            tostring(triggered), tostring(not target.item.Parent), tostring(prompt.Parent and prompt.Enabled)))

        if not accepted and target.item.Parent and prompt.Enabled then
            skipUntil[target.item] = os.clock() + 12
            setStatus("Ditolak/terkunci (cooldown 12s)")
            return
        end

        local spCF = getMySpawnCF()
        if spCF and hrp.Parent then
            setStatus("TP pulang ke " .. (myPlot and myPlot.Name or "Spawn"))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = spCF * CFrame.new(0, 4, 0)
            task.wait(0.8)
        end
        stolen += 1
        statsLbl.Text = "Steal " .. stolen
    end)
    if not ok then addLog("ERROR: " .. tostring(err)) end
    busy = false
end

btnOnce.Activated:Connect(function()
    if not busy then doStealOnce(nil) end
end)

hooks.autosteal = function(v)
    token += 1
    local tk = token
    if not v then setStatus("Idle") return end
    setStatus("Aktif")
    task.spawn(function()
        while Flags.autosteal and tk == token and gui.Parent do
            doStealOnce(tk)
            task.wait(0.4)
        end
        if tk == token then setStatus("Idle") end
    end)
end

-- WalkSpeed (tanpa recursion PropertyChanged)
track(RunService.Heartbeat:Connect(function()
    if Flags.walkspeed then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed ~= Vals.speed then h.WalkSpeed = Vals.speed end
    end
end))
hooks.walkspeed = function(v)
    if not v then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end

-- Inf Jump (1 koneksi bersih, bisa di-toggle)
track(UIS.JumpRequest:Connect(function()
    if Flags.infjump then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

btnDumpVal.Activated:Connect(function()
    local placed = Workspace:FindFirstChild("PlacedItems")
    if not placed then addLog("PlacedItems tidak ada") return end
    local n = 0
    addLog("=== DUMP VALUABLE ===")
    for _, item in ipairs(placed:GetChildren()) do
        if item:GetAttribute("BuildableType") == "VALUABLE" then
            n += 1
            local part, p = findPromptPart(item)
            addLog(("%d) %s | mine=%s en=%s hold=%.1f"):format(
                n, item.Name, tostring(isMyItem(item)), tostring(p and p.Enabled), p and p.HoldDuration or -1))
        end
    end
    addLog("Total VALUABLE: " .. n)
end)

track(LP.Idled:Connect(function()
    if Flags.antiafk then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end))

gui.Destroying:Connect(function()
    Flags.autosteal = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
end)

addLog("Init OK | fireproximityprompt=" .. tostring(fireproximityprompt ~= nil))
findMyPlot()
setStatus("Idle")
