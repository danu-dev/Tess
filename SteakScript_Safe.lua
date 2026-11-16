--[[ =========================================================
     REMOTE LOGGER FULL — Mobile Friendly
     Hook remote + UI log + Copy All
     Cara pakai:
       1. Execute script ini
       2. Execute script referensi
       3. Steal steak di game
       4. Tap COPY ALL → paste ke chat
     Hotkey: RIGHT SHIFT = toggle UI
========================================================= ]]

-- ================= ANTI DOUBLE =================
if _G.RemoteLoggerFull then
    pcall(function() _G.RemoteLoggerFull:Destroy() end)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ================= STATE =================
local Logs = {}
local MAX_LOGS = 80
local UI = {}

-- ================= HELPER =================
local function safeTostring(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<unprintable>"
end

local function addLog(text, color)
    if not UI.Scroll then return end
    local entry = Instance.new("TextLabel")
    entry.Size = UDim2.new(1, -8, 0, 0)
    entry.AutomaticSize = Enum.AutomaticSize.Y
    entry.BackgroundTransparency = 1
    entry.Text = text
    entry.TextColor3 = color or Color3.fromRGB(0, 220, 140)
    entry.Font = Enum.Font.Code
    entry.TextSize = 11
    entry.TextWrapped = true
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.Parent = UI.Scroll

    table.insert(Logs, text)
    if #Logs > MAX_LOGS then
        table.remove(Logs, 1)
        local first = UI.Scroll:FindFirstChildOfClass("TextLabel")
        if first then first:Destroy() end
    end

    task.defer(function()
        if UI.Scroll then
            UI.Scroll.CanvasPosition = Vector2.new(0, UI.Scroll.AbsoluteCanvasSize.Y)
        end
    end)
end

-- ================= UI =================
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "RemoteLoggerFull"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = LP:WaitForChild("PlayerGui")
    _G.RemoteLoggerFull = gui
    UI.Gui = gui

    -- MAIN FRAME
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(1, -20, 0, 280)
    Main.Position = UDim2.new(0, 10, 0, 10)
    Main.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = gui
    UI.Main = Main

    local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 10); c1.Parent = Main
    local s1 = Instance.new("UIStroke"); s1.Color = Color3.fromRGB(0, 200, 140); s1.Thickness = 2; s1.Parent = Main

    -- TITLE
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 32)
    Title.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    Title.Text = "📡 REMOTE LOGGER"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.BorderSizePixel = 0
    Title.Parent = Main
    local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 10); c2.Parent = Title

    -- COPY ALL
    local CopyBtn = Instance.new("TextButton")
    CopyBtn.Size = UDim2.new(0, 95, 0, 26)
    CopyBtn.Position = UDim2.new(1, -105, 0, 3)
    CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
    CopyBtn.Text = "📋 COPY ALL"
    CopyBtn.TextColor3 = Color3.new(1,1,1)
    CopyBtn.Font = Enum.Font.GothamBold
    CopyBtn.TextSize = 12
    CopyBtn.BorderSizePixel = 0
    CopyBtn.Parent = Title
    local c3 = Instance.new("UICorner"); c3.CornerRadius = UDim.new(0, 6); c3.Parent = CopyBtn
    UI.CopyBtn = CopyBtn

    -- CLEAR
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0, 60, 0, 26)
    ClearBtn.Position = UDim2.new(1, -172, 0, 3)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    ClearBtn.Text = "🗑 CLEAR"
    ClearBtn.TextColor3 = Color3.new(1,1,1)
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 11
    ClearBtn.BorderSizePixel = 0
    ClearBtn.Parent = Title
    local c4 = Instance.new("UICorner"); c4.CornerRadius = UDim.new(0, 6); c4.Parent = ClearBtn
    UI.ClearBtn = ClearBtn

    -- SCROLL
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -16, 1, -45)
    Scroll.Position = UDim2.new(0, 8, 0, 38)
    Scroll.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 6
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Scroll.Parent = Main
    local c5 = Instance.new("UICorner"); c5.CornerRadius = UDim.new(0, 8); c5.Parent = Scroll
    UI.Scroll = Scroll

    local List = Instance.new("UIListLayout")
    List.Padding = UDim.new(0, 4)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Parent = Scroll

    -- ===== EVENT TOMBOL =====
    CopyBtn.MouseButton1Click:Connect(function()
        if #Logs == 0 then
            CopyBtn.Text = "KOSONG!"
            task.delay(1.2, function() CopyBtn.Text = "📋 COPY ALL" end)
            return
        end
        local full = table.concat(Logs, "\n")

        -- coba setclipboard
        local copied = false
        pcall(function()
            if setclipboard then
                setclipboard(full)
                copied = true
            end
        end)

        if copied then
            CopyBtn.Text = "✅ COPIED!"
            CopyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
            task.delay(1.5, function()
                CopyBtn.Text = "📋 COPY ALL"
                CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
            end)
        else
            -- fallback: kirim ke console + bikin TextBox manual
            CopyBtn.Text = "⚠ MANUAL"
            CopyBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 0)

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, -20, 0, 120)
            box.Position = UDim2.new(0, 10, 1, -130)
            box.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            box.TextColor3 = Color3.new(1,1,1)
            box.Font = Enum.Font.Code
            box.TextSize = 11
            box.Multiline = true
            box.ClearTextOnFocus = false
            box.TextEditable = true
            box.Text = full
            box.Parent = Main
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = box
            box:CaptureFocus()
            print("[LOGGER] setclipboard gagal, pakai TextBox manual. Select all text di kotak bawah lalu copy.")
        end
    end)

    ClearBtn.MouseButton1Click:Connect(function()
        Logs = {}
        for _, v in ipairs(Scroll:GetChildren()) do
            if v:IsA("TextLabel") then v:Destroy() end
        end
    end)
end

-- ================= HOOK =================
local function installHooks()
    -- 1. __namecall → FireServer / InvokeServer
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local ok, fullName = pcall(function() return self:GetFullName() end)
            local args = {...}
            local parts = {}
            for i, v in ipairs(args) do
                parts[i] = safeTostring(v)
            end
            local line = ("[REMOTE] %s | %s | args: %s")
                :format(fullName or "?", method, table.concat(parts, ", "))
            task.spawn(function() addLog(line) end)
        end
        return oldNamecall(self, ...)
    end)

    -- 2. HttpGet (biar keliatan URL yang dimuat)
    local oldHttpGet
    oldHttpGet = hookfunction(game.HttpGet, function(self, url, ...)
        task.spawn(function()
            addLog("[HTTPGET] " .. tostring(url), Color3.fromRGB(180, 140, 255))
        end)
        return oldHttpGet(self, url, ...)
    end)

    -- 3. FireServer langsung di RemoteEvent (backup kalau __namecall ga nangkep)
    local oldFire
    if hookmetamethod then
        -- skip, sudah ditangani __namecall
    end
end

-- ================= HOTKEY =================
local function installHotkey()
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if UI.Main then UI.Main.Visible = not UI.Main.Visible end
        end
    end)
end

-- ================= INIT =================
buildUI()
installHooks()
installHotkey()

addLog("Hook aktif ✅", Color3.fromRGB(0, 220, 140))
addLog("1. Execute script referensi", Color3.fromRGB(255, 200, 0))
addLog("2. Steal steak di game", Color3.fromRGB(255, 200, 0))
addLog("3. Tap COPY ALL", Color3.fromRGB(255, 200, 0))
addLog("Right Shift = hide/show UI", Color3.fromRGB(200,200,200))
print("[LOGGER] Full logger aktif. Right Shift = toggle UI.")
