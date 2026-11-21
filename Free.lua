--[[
    SENAR HUB | Build to Defense Loot
    Dev : GGSIHLUH | Fix : DanuDev
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
if not LP then return end

-- CONFIG
local GAME_NAME = "Build to Defense Loot"
local ICON_ID   = 75030918293811
local BG_ID     = 75030918293811

local STEAL_WORDS = { "steal", "take", "grab", "pick", "pickup", "collect", "claim", "loot", "rob", "carry", "hold", "interact", "equip", "snatch", "curi", "ambil", "colong", "bawa", "angkat" }
local IGNORE_WORDS = {
    "lock", "unlock", "upgrade", "buy", "purchase", "sell", "shop", "open", "close", "spawn",
    "kunci", "beli", "jual", "thumbs", "like", "sign", "change", "friend", "allow", "toggle",
    "merge", "machine", "expansion", "hack", "door", "pickup all", "conveyor", "haunted",
}
local RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }
local RARITY_ALIAS = {
    common = { "common", "umum" }, uncommon = { "uncommon", "tidak umum" }, rare = { "rare", "langka" },
    epic = { "epic", "epik" }, legendary = { "legendary", "legendaris" }, mythic = { "mythic", "mitos" },
    secret = { "secret", "rahasia" },
}

-- STATE
local Flags = { autosteal = false, speedforce = false, resetfirst = true, nobase = true, enemyonly = true, antiafk = true, anyprompt = false }
local Vals = { speed = 100, hi = 100, lo = 50, wait = 0.4, lift = 4 }
local RarSel = { all = true, common = false, uncommon = false, rare = false, epic = false, legendary = false, mythic = false, secret = false }
local hooks = {}
local widgets = {}

local env = (getgenv and getgenv()) or _G
if env.__SenarBTDL then pcall(env.__SenarBTDL) end

-- UI HELPERS
local C = {
    BG    = Color3.fromRGB(12, 9, 7),
    CARD  = Color3.fromRGB(24, 17, 12),
    CARD2 = Color3.fromRGB(38, 26, 16),
    OR    = Color3.fromRGB(255, 122, 0),
    OR2   = Color3.fromRGB(255, 176, 70),
    DEEP  = Color3.fromRGB(125, 54, 0),
    TXT   = Color3.fromRGB(255, 255, 255),
    SUB   = Color3.fromRGB(170, 152, 138),
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
    local getters = {
        function() return gethui and gethui() end,
        function() return game:GetService("CoreGui") end,
        function() return LP:WaitForChild("PlayerGui", 5) end,
    }
    for _, g in ipairs(getters) do
        local ok, p = pcall(g)
        if ok and p and pcall(function() gui.Parent = p end) and gui.Parent == p then return gui end
    end
    error("Tidak bisa menaruh UI")
end

local gui = makeGui()
local conns = {}
local function track(c) table.insert(conns, c) return c end
env.__SenarBTDL = function()
    if gui and gui.Parent then gui:Destroy() end
end

-- WINDOW
local W, MIN_H, FULL_H = 340, 214, 452
local cam0 = workspace.CurrentCamera
local vp = cam0 and cam0.ViewportSize or Vector2.new(800, 400)
local baseScale = math.clamp(math.min(vp.X / (W + 40), vp.Y / (FULL_H + 40)), 0.5, 1.1)

local Main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -FULL_H * baseScale / 2),
    Size = UDim2.fromOffset(W, MIN_H), BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(Main, 18)
local mainScale = new("UIScale", { Scale = baseScale }, Main)
stroke(Main, C.OR, 2)

new("ImageLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. BG_ID, ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.82, ZIndex = 0,
}, Main)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, ZIndex = 2 }, Main)
local logoBox = new("Frame", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(14, 12), BackgroundColor3 = C.CARD,
    BorderSizePixel = 0, ZIndex = 3 }, header)
corner(logoBox, 12)
stroke(logoBox, C.OR, 1.5)
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "S", TextColor3 = C.OR,
    Font = Enum.Font.GothamBlack, TextSize = 24, ZIndex = 3 }, logoBox)
new("ImageLabel", { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1,
    Image = "rbxassetid://" .. ICON_ID, ScaleType = Enum.ScaleType.Fit, ZIndex = 4 }, logoBox)

new("Frame", { Size = UDim2.fromOffset(2, 34), Position = UDim2.fromOffset(72, 19), BackgroundColor3 = C.OR, BorderSizePixel = 0,
    ZIndex = 3 }, header)
new("TextLabel", { Position = UDim2.fromOffset(82, 12), Size = UDim2.fromOffset(160, 24), BackgroundTransparency = 1,
    Text = "<font color='#FFFFFF'>Senar</font> <font color='#FF7A00'>Hub</font>", RichText = true,
    Font = Enum.Font.GothamBold, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, header)
new("TextLabel", { Position = UDim2.fromOffset(82, 38), Size = UDim2.fromOffset(170, 18), BackgroundTransparency = 1,
    Text = GAME_NAME, TextColor3 = C.SUB, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 }, header)

local plusBtn = new("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -84, 0, 20), BackgroundColor3 = C.CARD,
    Text = "+", TextColor3 = C.OR, Font = Enum.Font.GothamBlack, TextSize = 20, AutoButtonColor = false, ZIndex = 5 }, header)
corner(plusBtn, 16)
stroke(plusBtn, C.OR, 1.5)
local closeBtn = new("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -44, 0, 20), BackgroundColor3 = C.CARD,
    Text = "X", TextColor3 = C.TXT, Font = Enum.Font.GothamBlack, TextSize = 15, AutoButtonColor = false, ZIndex = 5 }, header)
corner(closeBtn, 16)
stroke(closeBtn, C.OR, 1.5)

new("Frame", { Position = UDim2.fromOffset(14, 72), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = C.DEEP, BorderSizePixel = 0,
    ZIndex = 2 }, Main)

do
    local dragging, start, startPos
    local dragArea = new("Frame", { Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 4 }, header)
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

-- WIDGETS
local function setFlag(name, v)
    Flags[name] = v
    for _, f in ipairs(widgets[name] or {}) do f() end
    if hooks[name] then task.spawn(hooks[name], v) end
end

local function row(parent, h, order)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.CARD, BorderSizePixel = 0, LayoutOrder = order or 0,
        ZIndex = 3 }, parent)
    corner(f, 12)
    stroke(f, C.DEEP, 1)
    return f
end

local function addToggle(parent, label, flag)
    local r = row(parent, 38)
    new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TXT, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, r)
    local track_ = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = C.CARD2, BorderSizePixel = 0, ZIndex = 4 }, r)
    corner(track_, 11)
    local knob = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.SUB,
        BorderSizePixel = 0, ZIndex = 5 }, track_)
    corner(knob, 8)
    local function refresh()
        local on = Flags[flag]
        tw(track_, 0.16, { BackgroundColor3 = on and C.OR or C.CARD2 })
        tw(knob, 0.16, { Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = on and C.TXT or C.SUB })
    end
    widgets[flag] = widgets[flag] or {}
    table.insert(widgets[flag], refresh)
    refresh()
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, r)
    hit.Activated:Connect(function() setFlag(flag, not Flags[flag]) end)
end

local function addSlider(parent, label, key, minV, maxV, onChange)
    local r = row(parent, 50)
    new("TextLabel", { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -90, 0, 20), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TXT, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, r)
    local valLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 4), Size = UDim2.fromOffset(70, 20),
        BackgroundTransparency = 1, Text = tostring(Vals[key]), TextColor3 = C.OR2, Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 }, r)
    local bar = new("Frame", { Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.CARD2,
        BorderSizePixel = 0, ZIndex = 4 }, r)
    corner(bar, 3)
    local fill = new("Frame", { Size = UDim2.fromScale((Vals[key] - minV) / (maxV - minV), 1), BackgroundColor3 = C.OR,
        BorderSizePixel = 0, ZIndex = 5 }, bar)
    corner(fill, 3)
    local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((Vals[key] - minV) / (maxV - minV), 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = C.TXT, BorderSizePixel = 0, ZIndex = 6 }, bar)
    corner(knob, 7)
    local hit = new("TextButton", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        Text = "", ZIndex = 7 }, r)
    local sliding = false
    local function setFrom(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(minV + rel * (maxV - minV) + 0.5)
        Vals[key] = v
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = tostring(v)
        if onChange then task.spawn(onChange, v) end
    end
    hit.InputBegan:Connect(function(i) if isPointer(i) then sliding = true setFrom(i.Position.X) end end)
    track(UIS.InputChanged:Connect(function(i) if sliding and isMove(i) then setFrom(i.Position.X) end end))
    track(UIS.InputEnded:Connect(function(i) if isPointer(i) then sliding = false end end))
end

local function addButton(parent, text, cb)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.OR, Text = text, TextColor3 = Color3.fromRGB(20, 12, 4),
        Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false, ZIndex = 3 }, parent)
    corner(b, 12)
    b.Activated:Connect(function() task.spawn(cb) end)
    return b
end

local function addLabel(parent, text)
    return new("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = text, TextColor3 = C.SUB,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3 }, parent)
end

local rarWidgets = {}
local function refreshRarity()
    for _, f in pairs(rarWidgets) do f() end
end
local function addRarityBox(parent, label, key)
    local r = row(parent, 32)
    local box = new("Frame", { Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.CARD2,
        BorderSizePixel = 0, ZIndex = 4 }, r)
    corner(box, 5)
    stroke(box, C.DEEP, 1)
    local mark = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(20, 12, 4),
        Font = Enum.Font.GothamBlack, TextSize = 13, ZIndex = 5 }, box)
    new("TextLabel", { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TXT, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, r)
    rarWidgets[key] = function()
        local on = RarSel[key]
        box.BackgroundColor3 = on and C.OR or C.CARD2
        mark.Text = on and "✓" or ""
    end
    rarWidgets[key]()
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, r)
    hit.Activated:Connect(function()
        if key == "all" then
            RarSel.all = true
            for _, k in ipairs(RARITIES) do RarSel[k] = false end
        else
            RarSel[key] = not RarSel[key]
            local any = false
            for _, k in ipairs(RARITIES) do if RarSel[k] then any = true end end
            RarSel.all = not any
        end
        refreshRarity()
    end)
end

-- KATEGORI
local quick = new("Frame", { Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 0, 88), BackgroundTransparency = 1, ZIndex = 2 }, Main)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, quick)
addToggle(quick, "Auto Steal", "autosteal")
addToggle(quick, "Speed Force", "speedforce")

local catArea = new("ScrollingFrame", {
    Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 1, -(82 + 46)), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = C.OR, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    Visible = false, ZIndex = 2,
}, Main)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, catArea)

local cats = {}
local function category(name, icon, order)
    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = order, ZIndex = 2 }, catArea)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
    local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.CARD, Text = "", AutoButtonColor = false,
        LayoutOrder = 0, ZIndex = 3 }, holder)
    corner(head, 23)
    local st = stroke(head, C.DEEP, 1.5)
    new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(30, 46), BackgroundTransparency = 1, Text = icon,
        TextColor3 = C.OR, Font = Enum.Font.GothamBold, TextSize = 20, ZIndex = 4 }, head)
    new("Frame", { Position = UDim2.fromOffset(52, 11), Size = UDim2.fromOffset(2, 24), BackgroundColor3 = C.OR, BorderSizePixel = 0,
        ZIndex = 4 }, head)
    new("TextLabel", { Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1, Text = name,
        TextColor3 = C.TXT, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, head)
    local chev = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1, Text = "›", TextColor3 = C.OR, Font = Enum.Font.GothamBlack, TextSize = 24, ZIndex = 4 }, head)
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.CARD,
        BackgroundTransparency = 0.4, Visible = false, LayoutOrder = 1, ZIndex = 3 }, holder)
    corner(body, 14)
    pad(body, 8, 8, 8, 8)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    local entry = { body = body, chev = chev, st = st }
    table.insert(cats, entry)
    head.Activated:Connect(function()
        local open = not body.Visible
        for _, c in ipairs(cats) do
            c.body.Visible = false
            c.chev.Rotation = 0
            c.st.Color = C.DEEP
        end
        if open then
            body.Visible = true
            chev.Rotation = 90
            st.Color = C.OR
        end
    end)
    return body
end

local stealBody   = category("Steal", "🤝", 1)
local configBody  = category("Config", "⚙", 2)
local settingBody = category("Setting", "❤️", 3)
local debugBody   = category("Debug", "🐞", 4)

-- STATUS BAR & LOG
local statusBar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -8), Size = UDim2.new(1, -28, 0, 30),
    BackgroundColor3 = C.CARD, BorderSizePixel = 0, ZIndex = 3 }, Main)
corner(statusBar, 10)
stroke(statusBar, C.DEEP, 1)
local statusDot = new("Frame", { Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.SUB,
    BorderSizePixel = 0, ZIndex = 4 }, statusBar)
corner(statusDot, 4)
local statusLbl = new("TextLabel", { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1,
    Text = "Idle", TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 }, statusBar)
local statsLbl = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(70, 30),
    BackgroundTransparency = 1, Text = "Steal 0", TextColor3 = C.OR2, Font = Enum.Font.GothamBold, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 }, statusBar)

local logs = {}
local MAX_LOGS = 200
local logBox
local function addLog(msg)
    local ts = os.date("%H:%M:%S")
    local line = "[" .. ts .. "] " .. tostring(msg)
    table.insert(logs, line)
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    if logBox then logBox.Text = table.concat(logs, "\n") end
end

local function setStatus(t)
    local s = tostring(t)
    statusLbl.Text = s
    local on = Flags.autosteal
    statusLbl.TextColor3 = on and C.TXT or C.SUB
    statusDot.BackgroundColor3 = on and C.OR or C.SUB
    addLog("Status: " .. s)
end

local expanded = false
local function setExpanded(v)
    expanded = v
    plusBtn.Text = v and "–" or "+"
    if v then
        quick.Visible = false
        catArea.Visible = true
        tw(Main, 0.4, { Size = UDim2.fromOffset(W, FULL_H) }, Enum.EasingStyle.Quint)
    else
        catArea.Visible = false
        quick.Visible = true
        tw(Main, 0.3, { Size = UDim2.fromOffset(W, MIN_H) }, Enum.EasingStyle.Quint)
    end
end
plusBtn.Activated:Connect(function() setExpanded(not expanded) end)

local floatBtn = new("ImageButton", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 16, 0.5, -27), BackgroundColor3 = C.CARD,
    Image = "rbxassetid://" .. ICON_ID, ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, Visible = false, ZIndex = 50 }, gui)
corner(floatBtn, 27)
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
                mainScale.Scale = baseScale * 0.85
                tw(mainScale, 0.25, { Scale = baseScale }, Enum.EasingStyle.Back)
            end
        end
    end))
end
closeBtn.Activated:Connect(function()
    Main.Visible = false
    floatBtn.Visible = true
end)

-- ISI KATEGORI
addToggle(stealBody, "Auto Steal", "autosteal")
addToggle(stealBody, "Reset Karakter dulu", "resetfirst")
addToggle(stealBody, "No Scan My Base", "nobase")
addToggle(stealBody, "Hanya Base Musuh", "enemyonly")
addToggle(stealBody, "Speed Force", "speedforce")
addLabel(stealBody, "Rarity Loot")
addRarityBox(stealBody, "All", "all")
for _, k in ipairs(RARITIES) do
    addRarityBox(stealBody, k:sub(1, 1):upper() .. k:sub(2), k)
end

addSlider(configBody, "Speed Force (WalkSpeed)", "speed", 16, 300)
addSlider(configBody, "Speed ke Home (cepat)", "hi", 20, 200)
addSlider(configBody, "Speed ke Home (pelan / tembok)", "lo", 10, 150)
addSlider(configBody, "Naik tiap langkah (tembok)", "lift", 1, 10)
local homeInfo = addLabel(configBody, "Home: belum terdeteksi")
local btnScanHome = addButton(configBody, "Scan Home Sekarang", function() end)
local btnSetHome = addButton(configBody, "Set Home = posisi saya", function() end)
addToggle(configBody, "Prompt apa saja (jika loot tak terdeteksi)", "anyprompt")

addToggle(settingBody, "Anti AFK", "antiafk")
addButton(settingBody, "Hapus UI", function()
    Flags.autosteal = false
    if gui then gui:Destroy() end
end)

local function copyText(txt)
    local clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if clip then
        local ok = pcall(clip, txt)
        if ok then return true end
    end
    return false
end
addButton(debugBody, "Copy Semua Log", function()
    local txt = table.concat(logs, "\n")
    if txt == "" then txt = "(log kosong)" end
    if copyText(txt) then
        statusLbl.Text = "Log disalin (" .. #logs .. " baris)"
    elseif logBox then
        logBox:CaptureFocus()
        logBox.SelectionStart = 1
        logBox.CursorPosition = #logBox.Text + 1
        statusLbl.Text = "Pilih & copy manual di kotak log"
    end
end)
local btnDumpPrompts = addButton(debugBody, "Dump Prompt Sekitar", function() end)
addButton(debugBody, "Clear Log", function()
    logs = {}
    if logBox then logBox.Text = "" end
    statusLbl.Text = "Log dibersihkan"
end)
local logScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.BG, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = C.OR,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 3,
}, debugBody)
corner(logScroll, 10)
stroke(logScroll, C.DEEP, 1)
pad(logScroll, 6, 6, 6, 6)
logBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Text = "", TextColor3 = C.SUB, Font = Enum.Font.Code, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, MultiLine = true, TextEditable = false, ClearTextOnFocus = false, ZIndex = 4,
}, logScroll)
addLog("Init OK | fireproximityprompt=" .. tostring(fireproximityprompt ~= nil))

-- LOGIKA
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function put(hrp, pos)
    local h = hum()
    if h and h.Sit then h.Sit = false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(pos) * (hrp.CFrame - hrp.CFrame.Position)
end

local prompts = {}
local function reg(d) if d:IsA("ProximityPrompt") then prompts[d] = true end end
task.spawn(function()
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        reg(d)
        n += 1
        if n % 3000 == 0 then task.wait() end
    end
end)
track(Workspace.DescendantAdded:Connect(reg))
track(Workspace.DescendantRemoving:Connect(function(d) prompts[d] = nil end))

local function promptPos(p)
    local par = p.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    if par:IsA("Model") then return par:GetPivot().Position end
    local part = par:FindFirstChildWhichIsA("BasePart", true) or par:FindFirstAncestorWhichIsA("BasePart")
    return part and part.Position
end

-- DETEKSI BASE
local homeModel, homeCF, homeSize, homeSpawn, homeManual
local baseInfo, myBaseRoots, enemyBaseRoots = {}, {}, {}
local lastScan = 0

local OWNER_HINTS  = { "owner", "player", "user", "creator", "pemilik", "ownerid", "userid", "creatorid" }
local BASE_HINTS   = { "base", "plot", "house", "home", "island", "tower", "land", "territory", "kampung", "rumah", "petak" }
local SKIP_FOLDERS = { "placed", "conveyor", "machine", "client", "effect", "debris", "loot", "drop", "shop", "lobby", "arena" }

local function lower(s) return string.lower(tostring(s)) end
local function hasHint(text, hints)
    local l = lower(text)
    for _, h in ipairs(hints) do
        if string.find(l, h, 1, true) then return true end
    end
    return false
end

local function playerFromValue(v)
    if typeof(v) == "Instance" and v:IsA("Player") then return v end
    if type(v) == "string" then
        for _, pl in ipairs(Players:GetPlayers()) do
            if v == pl.Name or v == pl.DisplayName or v == tostring(pl.UserId) then return pl end
        end
        local n = tonumber(v)
        if n then return Players:GetPlayerByUserId(n) end
    elseif type(v) == "number" then
        return Players:GetPlayerByUserId(v)
    end
    return nil
end

local function ownerShallow(node)
    local ok, attrs = pcall(function() return node:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            if hasHint(k, OWNER_HINTS) then
                local pl = playerFromValue(v)
                if pl then return pl end
            end
        end
    end
    for _, c in ipairs(node:GetChildren()) do
        if c:IsA("StringValue") or c:IsA("IntValue") or c:IsA("NumberValue") or c:IsA("ObjectValue") then
            if hasHint(c.Name, OWNER_HINTS) then
                local pl = playerFromValue(c.Value)
                if pl then return pl end
            end
        end
    end
    local name = lower(node.Name)
    for _, pl in ipairs(Players:GetPlayers()) do
        local pn = lower(pl.Name)
        if #pn >= 3 and string.find(name, pn, 1, true) then return pl end
        local dn = lower(pl.DisplayName)
        if #dn >= 3 and string.find(name, dn, 1, true) then return pl end
        if string.find(name, tostring(pl.UserId), 1, true) then return pl end
    end
    return nil
end

local function ownerDeep(node)
    local pl = ownerShallow(node)
    if pl then return pl end
    local n = 0
    for _, d in ipairs(node:GetDescendants()) do
        n += 1
        if n > 150 then break end
        if d:IsA("ObjectValue") and d.Value and d.Value:IsA("Player") then return d.Value end
        local ok, at = pcall(function() return d:GetAttributes() end)
        if ok and at then
            for k, v in pairs(at) do
                if hasHint(k, OWNER_HINTS) then
                    local p = playerFromValue(v)
                    if p then return p end
                end
            end
        end
    end
    return nil
end

local function boundingBoxOf(node)
    if node:IsA("Model") then
        local ok, cf, size = pcall(function() return node:GetBoundingBox() end)
        if ok and cf then return cf, size end
    end
    local min, max
    for _, d in ipairs(node:GetDescendants()) do
        if d:IsA("BasePart") then
            local a, b = d.Position - d.Size / 2, d.Position + d.Size / 2
            if not min then
                min, max = a, b
            else
                min = Vector3.new(math.min(min.X, a.X), math.min(min.Y, a.Y), math.min(min.Z, a.Z))
                max = Vector3.new(math.max(max.X, b.X), math.max(max.Y, b.Y), math.max(max.Z, b.Z))
            end
        end
    end
    if min and max then return CFrame.new((min + max) / 2), (max - min) end
    return nil, nil
end

local function boxHas(cf, size, pos, margin)
    if not cf or not size or not pos then return false end
    local rel = cf:PointToObjectSpace(pos)
    return math.abs(rel.X) <= size.X / 2 + margin and math.abs(rel.Z) <= size.Z / 2 + margin
        and math.abs(rel.Y) <= size.Y / 2 + margin
end

local function addBase(node, owner)
    if not node or baseInfo[node] then return end
    local cf, size = boundingBoxOf(node)
    baseInfo[node] = { owner = owner, cf = cf, size = size }
end

local function isBaseContainer(node)
    if not hasHint(node.Name, BASE_HINTS) then return false end
    if node:IsA("Folder") then
        for _, c in ipairs(node:GetChildren()) do
            if c:IsA("Model") or c:IsA("Folder") then return true end
        end
        return false
    end
    for _, c in ipairs(node:GetChildren()) do
        if c:IsA("BasePart") then return false end
    end
    local n = 0
    for _, c in ipairs(node:GetChildren()) do
        if c:IsA("Model") or c:IsA("Folder") then n += 1 end
    end
    return n >= 2
end

local function scanBaseFolder(folder, depth)
    for _, a in ipairs(folder:GetChildren()) do
        if a ~= LP.Character and not a:IsA("Terrain") and not a:IsA("Camera") and (a:IsA("Model") or a:IsA("Folder")) then
            if not hasHint(a.Name, SKIP_FOLDERS) then
                if isBaseContainer(a) then
                    for _, b in ipairs(a:GetChildren()) do
                        if b:IsA("Model") or b:IsA("Folder") then addBase(b, ownerDeep(b)) end
                    end
                elseif hasHint(a.Name, BASE_HINTS) then
                    addBase(a, ownerDeep(a))
                elseif depth == 0 then
                    local owner = ownerShallow(a)
                    if owner then
                        addBase(a, owner)
                    elseif a:IsA("Folder") then
                        scanBaseFolder(a, depth + 1)
                    end
                elseif a:IsA("Folder") and depth < 2 then
                    scanBaseFolder(a, depth + 1)
                end
            end
        end
    end
end

local function collectBases()
    baseInfo, myBaseRoots, enemyBaseRoots = {}, {}, {}
    scanBaseFolder(Workspace, 0)
end

local function scanHome(force)
    if not force and os.clock() - lastScan < 3 then return homeModel ~= nil end
    lastScan = os.clock()
    collectBases()
    homeModel, homeCF, homeSize = nil, nil, nil

    for _, info in pairs(baseInfo) do
        if info.owner == LP then info.mine = true end
    end
    for _, info in pairs(baseInfo) do
        if not info.mine then
            if boxHas(info.cf, info.size, homeSpawn, 25) or boxHas(info.cf, info.size, homeManual, 25) then
                info.mine = true
            end
        end
    end
    local anyMine = false
    for _, info in pairs(baseInfo) do if info.mine then anyMine = true break end end
    if not anyMine and homeSpawn then
        local bestD, bestR
        for r, info in pairs(baseInfo) do
            if info.cf then
                local d = (info.cf.Position - homeSpawn).Magnitude
                if d <= 120 and (not bestD or d < bestD) then bestD, bestR = d, r end
            end
        end
        if bestR then baseInfo[bestR].mine = true end
    end

    local bestArea = -1
    local nEnemy = 0
    for r, info in pairs(baseInfo) do
        if info.mine then
            myBaseRoots[r] = true
            local area = info.size and (info.size.X * info.size.Z) or 0
            if area > bestArea then
                bestArea = area
                homeModel, homeCF, homeSize = r, info.cf, info.size
            end
        else
            enemyBaseRoots[r] = true
            nEnemy += 1
        end
    end

    local txt
    if homeModel then
        txt = "Base ku: " .. homeModel.Name .. "  |  Musuh: " .. nEnemy
    elseif homeManual then
        txt = "Home: manual  |  Musuh: " .. nEnemy
    elseif homeSpawn then
        txt = "Home: titik spawn  |  Musuh: " .. nEnemy
    else
        txt = "Home: belum terdeteksi  |  Musuh: " .. nEnemy
    end
    homeInfo.Text = txt
    return homeModel ~= nil
end

local function homeDest()
    if homeManual then return homeManual end
    if homeSpawn then return homeSpawn end
    if homeCF then return homeCF.Position end
    local r = root()
    return r and r.Position
end

local function inMyBase(pos)
    if homeManual and Vector3.new(pos.X - homeManual.X, 0, pos.Z - homeManual.Z).Magnitude <= 45 then return true end
    if homeCF and homeSize and boxHas(homeCF, homeSize, pos, 12) then return true end
    for r in pairs(myBaseRoots) do
        local info = baseInfo[r]
        if info and boxHas(info.cf, info.size, pos, 12) then return true end
    end
    if not homeCF and homeSpawn and Vector3.new(pos.X - homeSpawn.X, 0, pos.Z - homeSpawn.Z).Magnitude <= 35 then return true end
    return false
end

local function promptRoot(p)
    local a = p
    while a and a ~= Workspace do
        if baseInfo[a] then return a end
        a = a.Parent
    end
    return nil
end

-- Deteksi pemilik dari ancestor prompt (misal PlacedItems_<UserId>)
local function promptOwner(p)
    local a = p.Parent
    while a and a ~= Workspace do
        local pl = ownerShallow(a)
        if pl then return pl end
        a = a.Parent
    end
    return nil
end

-- LOOT
local function rarityIndex(prompt)
    local par = prompt.Parent
    local rootObj = par and ((par:IsA("Model") and par) or par:FindFirstAncestorOfClass("Model") or par)
    local best = 0
    local function scanText(txt)
        local low = string.lower(txt)
        for i = #RARITIES, best + 1, -1 do
            for _, w in ipairs(RARITY_ALIAS[RARITIES[i]]) do
                if string.find(low, w, 1, true) then best = i return end
            end
        end
    end
    scanText(prompt.ObjectText .. " " .. prompt.ActionText)
    if par then scanText(par.Name) end
    if rootObj then
        scanText(rootObj.Name)
        for k, v in pairs(rootObj:GetAttributes()) do
            if string.lower(k):find("rarity") and type(v) == "string" then scanText(v) end
        end
        for _, d in ipairs(rootObj:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then scanText(d.Text)
            elseif d:IsA("StringValue") and string.lower(d.Name):find("rarity") then scanText(d.Value) end
        end
    end
    return best
end

local function isStealPrompt(p)
    local parName = p.Parent and p.Parent.Name or ""
    local grandName = (p.Parent and p.Parent.Parent and p.Parent.Parent.Name) or ""
    local t = string.lower(p.ActionText .. " " .. p.ObjectText .. " " .. p.Name .. " " .. parName .. " " .. grandName)
    for _, w in ipairs(IGNORE_WORDS) do
        if string.find(t, w, 1, true) then return false end
    end
    if Flags.anyprompt then return true end
    for _, w in ipairs(STEAL_WORDS) do
        if string.find(t, w, 1, true) then return true end
    end
    return false
end

local function allowed(idx)
    if RarSel.all then return true end
    return idx > 0 and RarSel[RARITIES[idx]] == true
end

local function pickLoot()
    local hrp = root()
    local best, bestScore
    local total, disabled, notSteal, inBase, rarSkip = 0, 0, 0, 0, 0
    for p in pairs(prompts) do
        if p.Parent and not (LP.Character and p:IsDescendantOf(LP.Character)) then
            total += 1
            if not p.Enabled then
                disabled += 1
            elseif not isStealPrompt(p) then
                notSteal += 1
            else
                local pos = promptPos(p)
                if pos then
                    local br = promptRoot(p)
                    local info = br and baseInfo[br]
                    local own = (info and info.owner) or promptOwner(p)
                    local mine = (info and info.mine) or (own == LP) or inMyBase(pos)
                    local enemy = (own ~= nil and own ~= LP) or (br ~= nil and info ~= nil and not info.mine)
                    local blocked = false
                    if Flags.nobase and mine then blocked = true end
                    if Flags.enemyonly and (mine or not enemy) then blocked = true end
                    if blocked then
                        inBase += 1
                    else
                        local idx = rarityIndex(p)
                        if allowed(idx) then
                            local d = hrp and (pos - hrp.Position).Magnitude or 0
                            local score = idx * 100000 - d
                            if enemy then score += 5000000 end
                            if not bestScore or score > bestScore then
                                local name = (p.ObjectText ~= "" and p.ObjectText) or (p.Parent and p.Parent.Name) or "Loot"
                                best = { prompt = p, pos = pos, name = name, rarity = idx, enemy = enemy }
                                bestScore = score
                            end
                        else
                            rarSkip += 1
                        end
                    end
                end
            end
        end
    end
    if best then
        addLog(("Loot dipilih: %s | act=%q obj=%q hold=%.2f rar=%d enemy=%s"):format(
            best.name, best.prompt.ActionText, best.prompt.ObjectText, best.prompt.HoldDuration, best.rarity, tostring(best.enemy)))
    else
        addLog(("PickLoot nil (total=%d disabled=%d notSteal=%d inBase=%d rarSkip=%d)"):format(
            total, disabled, notSteal, inBase, rarSkip))
    end
    return best
end

local stolen = 0
local token = 0

local function firePrompt(p, fallbackPos, tk)
    local triggered = false
    local trigConn
    pcall(function()
        trigConn = p.Triggered:Connect(function(plr)
            if plr == LP then triggered = true end
        end)
    end)

    local origHold, origDist, origLos = 0, 10, true
    pcall(function()
        origHold = p.HoldDuration
        origDist = p.MaxActivationDistance
        origLos = p.RequiresLineOfSight
        p.RequiresLineOfSight = false
        if p.MaxActivationDistance < 30 then p.MaxActivationDistance = 30 end
    end)

    local function keepNear()
        local hrp = root()
        if not hrp then return false end
        local ppos = promptPos(p) or fallbackPos
        if ppos then
            put(hrp, ppos + Vector3.new(0, 2.5, 0))
        end
        return true
    end

    local function done()
        return triggered or not Flags.autosteal or tk ~= token or not p.Parent or not p.Enabled
    end

    if fireproximityprompt then
        pcall(function() p.HoldDuration = 0 end)
        for _ = 1, 5 do
            if done() or not keepNear() then break end
            pcall(fireproximityprompt, p)
            task.wait(0.15)
        end
    end

    if not done() then
        pcall(function() p.HoldDuration = origHold end)
        if keepNear() then
            pcall(function() p:InputHoldBegin() end)
            local holdWait = math.max(origHold, 0.1) + 0.15
            local t0 = os.clock()
            while not done() and os.clock() - t0 < holdWait do
                keepNear()
                task.wait(0.05)
            end
            pcall(function() p:InputHoldEnd() end)
        end
    end

    if trigConn then pcall(function() trigConn:Disconnect() end) end
    pcall(function()
        if p.Parent then
            p.HoldDuration = origHold
            p.MaxActivationDistance = origDist
            p.RequiresLineOfSight = origLos
        end
    end)
    local ok = triggered or not p.Parent or not p.Enabled
    addLog(("firePrompt: ok=%s trig=%s parent=%s enabled=%s hold=%.2f"):format(
        tostring(ok), tostring(triggered), tostring(p.Parent ~= nil), tostring(p.Enabled), origHold))
    return ok
end

local function resetChar(tk)
    local old = LP.Character
    local h = hum()
    if h then h.Health = 0 elseif old then old:BreakJoints() end
    local t0 = os.clock()
    while Flags.autosteal and tk == token and os.clock() - t0 < 20 do
        local c = LP.Character
        if c and c ~= old and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid") then
            task.wait(0.35)
            return Flags.autosteal and tk == token and root() ~= nil
        end
        task.wait()
    end
    return false
end

local function wallAhead(origin, dir, dist)
    local ignore = { LP.Character }
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 4 do
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(origin, dir * dist, params)
        if not res then return false end
        if res.Instance.CanCollide then return true end
        table.insert(ignore, res.Instance)
    end
    return false
end
local function groundBelow(pos)
    local ignore = { LP.Character }
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 4 do
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(pos, Vector3.new(0, -600, 0), params)
        if not res then return nil end
        if res.Instance.CanCollide then return res.Position.Y end
        table.insert(ignore, res.Instance)
    end
    return nil
end

local function forceHome(dest, tk)
    local lifted = false
    local t0 = os.clock()
    while Flags.autosteal and tk == token and os.clock() - t0 < 45 do
        local hrp = root()
        if not hrp then return false end
        local pos = hrp.Position
        local flat = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
        local dist = flat.Magnitude
        if dist < 5 then
            local gy = groundBelow(pos)
            if gy and pos.Y - gy > 4 then put(hrp, Vector3.new(pos.X, gy + 3, pos.Z)) end
            return true
        end
        local dir = flat.Unit
        local dt = RunService.Heartbeat:Wait()
        hrp = root()
        if not hrp then return false end
        pos = hrp.Position
        local blocked = wallAhead(pos, dir, 6) or wallAhead(pos + Vector3.new(0, 3, 0), dir, 6)
        local speed = Vals.hi
        if blocked then
            speed = Vals.lo
            hrp.CFrame = hrp.CFrame + Vector3.new(0, Vals.lift, 0)
            lifted = true
        else
            if lifted then
                speed = Vals.lo
                local gy = groundBelow(pos)
                if gy and pos.Y - gy > 4 then
                    local low = Vector3.new(pos.X, gy + 3, pos.Z)
                    if not wallAhead(low, dir, 8) then
                        hrp.CFrame = CFrame.new(low) * (hrp.CFrame - hrp.CFrame.Position)
                        lifted = false
                    end
                else
                    lifted = false
                end
            end
            hrp.CFrame = hrp.CFrame + dir * math.min(speed * dt, dist)
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    local hrp = root()
    if hrp and Flags.autosteal and tk == token then put(hrp, dest + Vector3.new(0, 3, 0)) end
    return false
end

local function cycle(tk)
    if not Flags.resetfirst then
        local hrp0 = root()
        if hrp0 and not homeSpawn then homeSpawn = hrp0.Position end
    end
    scanHome()
    if Flags.resetfirst then
        setStatus("Reset karakter...")
        if not resetChar(tk) then return end
        local hrp0 = root()
        if hrp0 then homeSpawn = hrp0.Position end
        scanHome(true)
    end
    if not Flags.autosteal or tk ~= token then return end

    setStatus("Scan loot...")
    local loot = pickLoot()
    if not loot then
        setStatus("Loot tidak ditemukan (sesuai rarity)")
        task.wait(1.5)
        return
    end
    local hrp = root()
    if not hrp then return end
    setStatus("TP ke loot: " .. loot.name)
    local wt0 = os.clock()
    while Flags.autosteal and tk == token and os.clock() - wt0 < Vals.wait do
        hrp = root()
        if not hrp then return end
        local ppos = promptPos(loot.prompt) or loot.pos
        put(hrp, ppos + Vector3.new(0, 2.5, 0))
        task.wait(0.05)
    end
    if not Flags.autosteal or tk ~= token then return end

    setStatus("Curi: " .. loot.name)
    local okSteal = firePrompt(loot.prompt, loot.pos, tk)
    if not Flags.autosteal or tk ~= token then return end
    if not okSteal then
        setStatus("Gagal curi, ulang...")
        task.wait(0.3)
        return
    end

    setStatus("Gerak paksa ke home")
    local dest = homeDest()
    if dest then forceHome(dest, tk) end
    stolen += 1
    statsLbl.Text = "Steal " .. stolen
end

hooks.autosteal = function(v)
    token += 1
    local tk = token
    if not v then
        setStatus("Idle")
        return
    end
    setStatus("Aktif")
    task.spawn(function()
        while Flags.autosteal and tk == token and gui.Parent do
            local ok, err = pcall(cycle, tk)
            if not ok then
                addLog("ERROR cycle: " .. tostring(err))
                warn("[Senar Hub] " .. tostring(err))
                task.wait(1)
            end
            task.wait(0.2)
        end
        if tk == token then setStatus("Idle") end
    end)
end

track(RunService.Heartbeat:Connect(function()
    if Flags.speedforce then
        local h = hum()
        if h then h.WalkSpeed = Vals.speed end
    end
end))
hooks.speedforce = function(v)
    if not v then
        local h = hum()
        if h then h.WalkSpeed = 16 end
    end
end

btnScanHome.Activated:Connect(function()
    if scanHome(true) then
        local n = 0
        for _ in pairs(enemyBaseRoots) do n += 1 end
        setStatus("Base ku: " .. homeModel.Name .. " | musuh: " .. n)
    else
        setStatus("Base ku tidak ketemu, pakai titik spawn")
    end
end)
btnSetHome.Activated:Connect(function()
    local r = root()
    if r then
        homeManual = r.Position
        homeInfo.Text = "Home: manual"
        setStatus("Home disimpan")
    end
end)

btnDumpPrompts.Activated:Connect(function()
    local hrp = root()
    local list = {}
    for p in pairs(prompts) do
        if p.Parent then
            local pos = promptPos(p)
            local d = (hrp and pos) and (pos - hrp.Position).Magnitude or 99999
            table.insert(list, { p = p, d = d })
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    addLog("=== DUMP PROMPT (" .. #list .. " total, tampil 12 terdekat) ===")
    for i = 1, math.min(12, #list) do
        local item = list[i]
        local p = item.p
        addLog(("%d) d=%.1f en=%s hold=%.1f dist=%.1f act=%q obj=%q path=%s"):format(
            i, item.d, tostring(p.Enabled), p.HoldDuration, p.MaxActivationDistance, p.ActionText, p.ObjectText, p:GetFullName()))
    end
    statusLbl.Text = "Dump prompt selesai (" .. math.min(12, #list) .. ")"
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

Main.Visible = true
mainScale.Scale = baseScale * 0.85
tw(mainScale, 0.3, { Scale = baseScale }, Enum.EasingStyle.Back)
setStatus("Idle")
task.spawn(function() scanHome(true) end)
