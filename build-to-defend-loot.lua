--[[
    ⚔️ BUILD TO DEFEND LOOT — ALL-IN-ONE SCRIPT
    ============================================
    Fitur:
      1. Auto Steal        — otomatis steal/claim loot di sekitar
      2. Instant Steal     — menghapus waktu tahan (hold) saat steal
      3. Steal TP          — teleport ke target steal terdekat
      4. WalkSpeed         — atur kecepatan jalan
      5. Infinite Jump     — lompat tanpa batas
      6. NoClip            — tembus tembok / pertahanan base musuh
      7. Auto Collect      — otomatis ambil cash / loot drop di sekitar
      8. Anti Knockback    — anti terpental saat diserang

    CARA PAKAI:
      1. Buka executor (Delta, Fluxus, Codex, Wave, dll)
      2. Join game "Build to Defend Loot"
      3. Copy-paste seluruh isi file ini -> Execute
      4. Tekan RightShift untuk buka/tutup GUI

    CATATAN:
      - Game ini punya anti-cheat. Saat pakai Instant/Auto Steal,
        ambil lalu menjauh sedikit sebelum claim ulang biar lebih aman.
      - Kalau Auto Steal / Auto Collect tidak jalan, tambahkan kata
        kunci prompt di game ke Config.StealKeywords / Config.CollectKeywords.
      - Risiko banned ditanggung sendiri. Sebaiknya pakai akun cadangan.
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
    WalkSpeedValue   = 50,   -- kecepatan saat WalkSpeed ON
    AutoStealRange   = 20,   -- jarak maksimal Auto Steal (studs)
    AutoCollectRange = 25,   -- jarak maksimal Auto Collect (studs)
    ScanDelay        = 0.25, -- jeda scan Auto Steal / Auto Collect (detik)
    StealKeywords    = {"steal", "claim", "loot", "rob", "hack"},
    CollectKeywords  = {"collect", "cash", "money", "pickup", "take", "drop"},
    ToggleGUIKey     = Enum.KeyCode.RightShift, -- tombol buka/tutup GUI
}

local State = {
    AutoSteal     = false,
    InstantSteal  = false,
    WalkSpeed     = false,
    InfiniteJump  = false,
    NoClip        = false,
    AutoCollect   = false,
    AntiKnockback = false,
}

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

-- fireproximityprompt dengan fallback kalau executor tidak support
local function firePrompt(prompt)
    if fireproximityprompt then
        fireproximityprompt(prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait()
            prompt:InputHoldEnd()
        end)
    end
end

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
-- 1 + 7. AUTO STEAL & AUTO COLLECT (loop scan)
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
                            if State.AutoSteal
                                and dist <= Config.AutoStealRange
                                and matches(txt, Config.StealKeywords) then
                                pcall(firePrompt, obj)
                            elseif State.AutoCollect
                                and dist <= Config.AutoCollectRange
                                and matches(txt, Config.CollectKeywords) then
                                pcall(firePrompt, obj)
                            end
                        end
                    elseif State.AutoCollect and obj:IsA("TouchInterest") then
                        -- cash / loot drop berbasis sentuhan
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
-- 3. STEAL TP (teleport ke target steal terdekat)
--==================================================
local function stealTP()
    local char = getChar()
    local hrp  = getHRP()
    if not (char and hrp) then return end

    local bestPart, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and matches(promptText(obj), Config.StealKeywords) then
            local part = promptPart(obj)
            if part then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPart = part
                end
            end
        end
    end

    if bestPart then
        char:PivotTo(bestPart.CFrame + Vector3.new(0, 3, 0))
    end
end

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
            -- redam kecepatan horizontal ekstrem (ciri khas knockback)
            local v = hrp.AssemblyLinearVelocity
            local horizontal = Vector3.new(v.X, 0, v.Z)
            if horizontal.Magnitude > 100 then
                hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.1, v.Y, v.Z * 0.1)
            end
        end
    end
end)

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
main.Size = UDim2.new(0, 240, 0, 440)
main.Position = UDim2.new(0.5, -120, 0.3, 0)
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
title.Text = "⚔️ Build to Defend Loot"
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
end

local function makeButton(labelText, callback)
    local btn = Instance.new("TextButton")
    styleButton(btn)
    btn.Text = labelText
    btn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    btn.Parent = container
    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
end

-- Urutan tombol sesuai permintaan
makeToggle("Auto Steal", "AutoSteal")

makeToggle("Instant Steal", "InstantSteal", function(on)
    if on then
        -- terapkan juga ke prompt yang sudah ada
        for _, o in ipairs(Workspace:GetDescendants()) do
            pcall(applyInstant, o)
        end
    end
end)

makeButton("Steal TP (ke target terdekat)", stealTP)

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

-- Tombol buka/tutup GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleGUIKey then
        main.Visible = not main.Visible
    end
end)

print("[BTDL] Script loaded ✅ | Tekan RightShift untuk buka/tutup GUI")
