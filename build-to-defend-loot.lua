--[[
    ⚔️ BUILD TO DEFEND LOOT — ALL-IN-ONE v2
    ========================================
    Fitur utama:
      ★ AUTO STEAL TP  — TP masuk ke base musuh -> steal -> keluar -> jalan balik ke base
      1. Auto Steal        — otomatis steal/claim loot di sekitar (tanpa TP)
      2. Instant Steal     — menghapus waktu tahan (hold) saat steal
      3. Steal TP          — tombol manual: 1x siklus steal (masuk -> steal -> pulang)
      4. WalkSpeed         — atur kecepatan jalan
      5. Infinite Jump     — lompat tanpa batas
      6. NoClip            — tembus tembok / pertahanan base musuh
      7. Auto Collect      — otomatis ambil cash / loot drop di sekitar
      8. Anti Knockback    — anti terpental saat diserang

    CARA PAKAI AUTO STEAL TP:
      1. Berdiri di base kamu -> tekan tombol "📍 Set Base"
      2. Aktifkan "Auto Steal TP"
      3. Script akan: TP ke loot musuh terdekat -> steal -> keluar -> jalan balik ke base
      4. Tekan RightShift untuk buka/tutup GUI

    KALAU STEAL TIDAK KEDETEKSI:
      - Tekan tombol "🔍 Debug Prompts" lalu lihat console executor (F9 / console)
      - Lihat tulisan Action/Object prompt steal di game, tambahkan kata itu
        ke Config.StealKeywords di bawah.

    CATATAN: game ini punya anti-cheat. Risiko banned ditanggung sendiri.
]]

--==================================================
-- SERVICES
--==================================================
local Players                = game:GetService("Players")
local RunService             = game:GetService("RunService")
local UserInputService       = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace              = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- KONFIGURASI (ubah sesuai kebutuhan)
--==================================================
local Config = {
    WalkSpeedValue   = 50,    -- kecepatan saat WalkSpeed ON
    ScanDelay        = 0.2,   -- jeda scan Auto Steal / Auto Collect (detik)
    AutoStealRange   = 20,    -- jarak Auto Steal biasa (studs)
    AutoCollectRange = 25,    -- jarak Auto Collect (studs)

    --=== PENGATURAN AUTO STEAL TP ===--
    HomeRadius       = 45,    -- prompt dalam radius ini dari base dianggap MILIK SENDIRI (di-skip)
    StealHoldTime    = 0.5,   -- lama diam di target saat steal (detik)
    ExitDistance     = 30,    -- jarak keluar dari base musuh setelah steal (studs)
    WalkBackTimeout  = 8,     -- batas waktu jalan balik ke base (detik)
    DelayPerCycle    = 0.8,   -- jeda antar siklus Auto Steal TP
    FallbackAnyPrompt = true, -- kalau tidak ada prompt cocok keyword, pakai prompt musuh apa saja

    StealKeywords    = {"steal", "claim", "loot", "rob", "hack", "take", "grab"},
    CollectKeywords  = {"collect", "cash", "money", "pickup", "drop"},
    ToggleGUIKey     = Enum.KeyCode.RightShift,
}

local State = {
    AutoStealTP   = false,
    AutoSteal     = false,
    InstantSteal  = false,
    WalkSpeed     = false,
    InfiniteJump  = false,
    NoClip        = false,
    AutoCollect   = false,
    AntiKnockback = false,
}

local HomeCFrame = nil -- posisi base kamu (di-set lewat tombol Set Base)

--==================================================
-- HELPERS
--==================================================
local function getChar()
    return LocalPlayer.Character
end

local function getHumanoid()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function matches(text, keywords)
    text = string.lower(text or "")
    for _, kw in ipairs(keywords) do
        if string.find(text, string.lower(kw), 1, true) then
            return true
        end
    end
    return false
end

local function promptText(prompt)
    return table.concat({
        prompt.Name or "",
        prompt.ActionText or "",
        prompt.ObjectText or "",
        (prompt.Parent and prompt.Parent.Name) or "",
    }, " ")
end

local function promptPart(prompt)
    local p = prompt.Parent
    if p and p:IsA("BasePart") then
        return p
    elseif p and p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then
        return p.Parent
    elseif p and p:IsA("Model") then
        return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

-- deteksi apakah prompt ini milik base sendiri
local function isOwnPrompt(prompt)
    local myName    = string.lower(LocalPlayer.Name)
    local myDisplay = string.lower(LocalPlayer.DisplayName)

    local node = prompt.Parent
    while node and node ~= Workspace and node ~= game do
        local n = string.lower(node.Name)
        if string.find(n, myName, 1, true) or (myDisplay ~= "" and string.find(n, myDisplay, 1, true)) then
            return true
        end
        local owner = node:FindFirstChild("Owner") or node:FindFirstChild("owner")
        if owner then
            if owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
                return true
            elseif owner:IsA("StringValue") then
                local v = string.lower(owner.Value)
                if v == myName or v == myDisplay then
                    return true
                end
            end
        end
        node = node.Parent
    end
    return false
end

local function firePrompt(prompt)
    pcall(function() prompt.HoldDuration = 0 end)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait()
            prompt:InputHoldEnd()
        end)
    end
end

--==================================================
-- ★ AUTO STEAL TP
--==================================================
local function findStealTarget()
    local hrp = getHRP()
    if not hrp then return nil, nil end
    local homePos = HomeCFrame and HomeCFrame.Position or hrp.Position

    local bestP, bestPart, bestDist = nil, nil, math.huge
    local fbP, fbPart, fbDist = nil, nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and not isOwnPrompt(obj) then
            local part = promptPart(obj)
            if part then
                local distHome = (part.Position - homePos).Magnitude
                if distHome > Config.HomeRadius then -- skip area base sendiri
                    local dist = (part.Position - hrp.Position).Magnitude
                    if matches(promptText(obj), Config.StealKeywords) then
                        if dist < bestDist then
                            bestP, bestPart, bestDist = obj, part, dist
                        end
                    elseif Config.FallbackAnyPrompt and dist < fbDist then
                        fbP, fbPart, fbDist = obj, part, dist
                    end
                end
            end
        end
    end

    if bestP then return bestP, bestPart end
    return fbP, fbPart
end

local stealing = false

local function doStealCycle()
    if stealing then return end
    local char = getChar()
    local hrp  = getHRP()
    if not (char and hrp) then return end

    -- kalau belum set base, pakai posisi sekarang
    if not HomeCFrame then
        HomeCFrame = hrp.CFrame
    end

    local prompt, part = findStealTarget()
    if not (prompt and part) then return end

    stealing = true

    -- 1) TP MASUK ke loot musuh
    char:PivotTo(part.CFrame + Vector3.new(0, 2, 0))
    task.wait(0.15)

    -- 2) STEAL (instant + fire beberapa kali biar pasti)
    firePrompt(prompt)
    task.wait(Config.StealHoldTime)
    firePrompt(prompt)

    -- 3) KELUAR base musuh (TP sedikit menjauh ke arah base sendiri)
    local homePos = HomeCFrame.Position
    local dir = (homePos - part.Position)
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
    local exitPos = part.Position + dir.Unit * Config.ExitDistance + Vector3.new(0, 2, 0)
    char:PivotTo(CFrame.new(exitPos))
    task.wait(0.2)

    -- 4) JALAN balik ke base (MoveTo = terlihat natural, lebih aman dari anti-cheat)
    local hum = getHumanoid()
    if hum then
        hum:MoveTo(homePos)
        local t0 = tick()
        while tick() - t0 < Config.WalkBackTimeout do
            local h = getHRP()
            if not h or (h.Position - homePos).Magnitude < 10 then break end
            task.wait(0.2)
        end
        hum:Move(Vector3.new(0, 0, 0)) -- stop
    end

    stealing = false
end

task.spawn(function()
    while true do
        task.wait(Config.DelayPerCycle)
        if State.AutoStealTP then
            pcall(doStealCycle)
        end
    end
end)

--==================================================
-- 2. INSTANT STEAL (HoldDuration = 0)
--==================================================
local function applyInstant(prompt)
    if prompt:IsA("ProximityPrompt") and matches(promptText(prompt), Config.StealKeywords) then
        prompt.HoldDuration = 0
    end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if State.InstantSteal then
        pcall(applyInstant, prompt)
    end
end)

--==================================================
-- 1 + 7. AUTO STEAL & AUTO COLLECT (tanpa TP)
--==================================================
task.spawn(function()
    while true do
        task.wait(Config.ScanDelay)
        if State.AutoSteal or State.AutoCollect then
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local part = promptPart(obj)
                        if part then
                            local txt  = promptText(obj)
                            local dist = (part.Position - hrp.Position).Magnitude
                            if State.AutoSteal and dist <= Config.AutoStealRange
                                and matches(txt, Config.StealKeywords) and not isOwnPrompt(obj) then
                                pcall(firePrompt, obj)
                            elseif State.AutoCollect and dist <= Config.AutoCollectRange
                                and matches(txt, Config.CollectKeywords) then
                                pcall(firePrompt, obj)
                            end
                        end
                    elseif State.AutoCollect and obj:IsA("TouchInterest") then
                        local part = obj.Parent
                        if part and part:IsA("BasePart")
                            and matches(part.Name, Config.CollectKeywords)
                            and firetouchinterest then
                            pcall(function()
                                firetouchinterest(hrp, part, 0)
                                firetouchinterest(hrp, part, 1)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

--==================================================
-- 4. WALKSPEED
--==================================================
RunService.Heartbeat:Connect(function()
    if State.WalkSpeed then
        local hum = getHumanoid()
        if hum and hum.WalkSpeed ~= Config.WalkSpeedValue then
            hum.WalkSpeed = Config.WalkSpeedValue
        end
    end
end)

--==================================================
-- 5. INFINITE JUMP
--==================================================
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

--==================================================
-- 6. NOCLIP
--==================================================
RunService.Stepped:Connect(function()
    if State.NoClip then
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

--==================================================
-- 8. ANTI KNOCKBACK
--==================================================
RunService.Heartbeat:Connect(function()
    if State.AntiKnockback then
        local char = getChar()
        local hrp  = getHRP()
        if char and hrp then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BodyVelocity") or v:IsA("LinearVelocity")
                    or v:IsA("VectorForce") or v:IsA("BodyAngularVelocity") then
                    v:Destroy()
                end
            end
            local v = hrp.AssemblyLinearVelocity
            local horizontal = Vector3.new(v.X, 0, v.Z)
            if horizontal.Magnitude > 100 then
                hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.1, v.Y, v.Z * 0.1)
            end
        end
    end
end)

--==================================================
-- DEBUG: lihat semua prompt di console (F9)
--==================================================
local function debugPrompts()
    print("========== DAFTAR PROMPT ==========")
    local n = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            n = n + 1
            print(string.format(
                "[%d] Name=%s | Action=%s | Object=%s | Parent=%s | Hold=%.1f | Own=%s",
                n, obj.Name, obj.ActionText, obj.ObjectText,
                (obj.Parent and obj.Parent.Name) or "?",
                obj.HoldDuration,
                tostring(isOwnPrompt(obj))
            ))
        end
    end
    print("Total prompt: " .. n .. " — kirim hasil ini kalau steal belum kedeteksi")
end

--==================================================
-- GUI
--==================================================
local guiParent
do
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then
        guiParent = hui
    else
        local ok2, coreGui = pcall(function() return game:GetService("CoreGui") end)
        guiParent = (ok2 and coreGui) or LocalPlayer:WaitForChild("PlayerGui")
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BTDL_AllInOne"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 240, 0, 560)
main.Position = UDim2.new(0.5, -120, 0.2, 0)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
title.Text = "⚔️ Build to Defend Loot v2"
title.TextColor3 = Color3.fromRGB(255, 215, 90)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.BorderSizePixel = 0
title.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, -36)
container.Position = UDim2.new(0, 0, 0, 36)
container.BackgroundTransparency = 1
container.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.Parent = container

local function styleButton(btn)
    btn.Size = UDim2.new(1, -20, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    btn.TextColor3 = Color3.fromRGB(235, 235, 235)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
end

local function makeToggle(labelText, stateKey, onToggle)
    local btn = Instance.new("TextButton")
    styleButton(btn)
    btn.Parent = container

    local function refresh()
        if State[stateKey] then
            btn.Text = labelText .. " : ON"
            btn.BackgroundColor3 = Color3.fromRGB(35, 140, 80)
        else
            btn.Text = labelText .. " : OFF"
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
        end
    end

    btn.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        refresh()
        if onToggle then
            pcall(onToggle, State[stateKey])
        end
    end)

    refresh()
    return btn
end

local function makeButton(labelText, color, callback)
    local btn = Instance.new("TextButton")
    styleButton(btn)
    btn.Text = labelText
    btn.BackgroundColor3 = color
    btn.Parent = container
    btn.MouseButton1Click:Connect(function()
        pcall(callback, btn)
    end)
    return btn
end

--=== TOMBOL UTAMA: AUTO STEAL TP ===--
makeButton("📍 Set Base (berdiri di base dulu!)", Color3.fromRGB(200, 120, 40), function(btn)
    local hrp = getHRP()
    if hrp then
        HomeCFrame = hrp.CFrame
        btn.Text = "✅ Base tersimpan!"
        task.wait(1)
        btn.Text = "📍 Set Base (berdiri di base dulu!)"
    end
end)

makeToggle("★ Auto Steal TP", "AutoStealTP", function(on)
    if on and not HomeCFrame then
        local hrp = getHRP()
        if hrp then HomeCFrame = hrp.CFrame end
    end
end)

makeButton("▶ Steal TP Sekali", Color3.fromRGB(60, 90, 160), function()
    task.spawn(doStealCycle)
end)

--=== FITUR LAIN ===--
makeToggle("Auto Steal (tanpa TP)", "AutoSteal")

makeToggle("Instant Steal", "InstantSteal", function(on)
    if on then
        for _, o in ipairs(Workspace:GetDescendants()) do
            pcall(applyInstant, o)
        end
    end
end)

makeToggle("WalkSpeed", "WalkSpeed", function(on)
    if not on then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end
end)

local speedBox = Instance.new("TextBox")
styleButton(speedBox)
speedBox.Text = tostring(Config.WalkSpeedValue)
speedBox.PlaceholderText = "Isi WalkSpeed (16-500)"
speedBox.Parent = container
speedBox.FocusLost:Connect(function()
    local n = tonumber(speedBox.Text)
    if n then
        Config.WalkSpeedValue = math.clamp(math.floor(n), 16, 500)
    end
    speedBox.Text = tostring(Config.WalkSpeedValue)
end)

makeToggle("Infinite Jump", "InfiniteJump")
makeToggle("NoClip", "NoClip")
makeToggle("Auto Collect", "AutoCollect")
makeToggle("Anti Knockback", "AntiKnockback")

makeButton("🔍 Debug Prompts (lihat console)", Color3.fromRGB(90, 60, 130), debugPrompts)

-- Buka/tutup GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleGUIKey then
        main.Visible = not main.Visible
    end
end)

print("[BTDL v2] Script loaded ✅ | Tekan RightShift untuk GUI | Set Base dulu sebelum Auto Steal TP")
