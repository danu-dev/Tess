--[[
    ⚔️ BUILD TO DEFEND LOOT — ALL-IN-ONE v6
    ========================================
    v6:
    ★ Fix UI lama ketumpuk — GUI lama dihapus dari SEMUA lokasi
      (gethui, CoreGui, PlayerGui) saat script jalan
    ★ Prompt "Pickup All Loot/Defenses" (milik base sendiri) di-skip —
      tidak buang waktu retry lagi
    ★ Smart Move glide (anti rubber-band)
    ★ Steal terverifikasi + retry 3x + blacklist target gagal 20s
    ★ Noclip otomatis selama siklus (anti kejebak)
    ★ Bypass anti-cheat aggressive (otomatis)
    ★ Mobile: tombol ⚔️ melayang buka/tutup GUI

    CARA PAKAI: execute -> ⚔️ -> 📍 Set Base -> ★ Auto Steal TP ON
    PENTING: hapus script lama di executor kamu, paste FULL yang ini.
    GUI versi baru: judul "⚔️ BTD Loot v6" warna BIRU.
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
-- KONFIGURASI
--==================================================
local Config = {
    WalkSpeedValue   = 50,
    ScanDelay        = 0.2,
    AutoStealRange   = 20,
    AutoCollectRange = 25,

    HomeRadius        = 45,
    MoveStep          = 12,
    SettleTime        = 0.35,
    StealRetries      = 3,
    BlacklistTime     = 20,
    ExitDistance      = 30,
    DelayPerCycle     = 0.5,
    FallbackAnyPrompt = true,

    RarityFilter      = {},
    StealKeywords     = {"steal", "claim", "loot", "rob", "hack", "take", "grab"},
    StealSkipKeywords = {"pickup"}, -- prompt berisi kata ini BUKAN target steal (tombol base sendiri)
    CollectKeywords   = {"collect", "cash", "money", "pickup", "drop"},

    BlockedRemoteKeywords = {"anticheat", "anti-cheat", "anti_cheat", "cheat", "exploit", "kick", "ban", "flag", "report"},
    WhitelistKeywords     = {"steal", "loot", "collect", "claim", "cash", "buy", "shop", "build", "place", "hack"},
    AntiCheatScriptNames  = {"anticheat", "anti-cheat", "anti_cheat", "cheatdetect", "anticheatclient", "clientac"},

    ToggleGUIKey = Enum.KeyCode.RightShift,
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
    SkipHack      = true,
}

local HomeCFrame = nil
local blacklist  = {}

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
    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 30)
        prompt.Enabled = true
    end)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt, 1) end)
    end
    -- fallback/tambahan: simulasi tekan manual (lebih ampuh di mobile executor)
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end)
end

local function smartMove(targetPos)
    local t0 = tick()
    while tick() - t0 < 10 do
        local char, hrp = getChar(), getHRP()
        if not (char and hrp) then return end
        local delta = targetPos - hrp.Position
        local dist  = delta.Magnitude
        if dist <= 4 then break end
        char:PivotTo(CFrame.new(hrp.Position + delta.Unit * math.min(Config.MoveStep, dist)))
        RunService.Heartbeat:Wait()
    end
end

local function backpackItems()
    local t = {}
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, i in ipairs(bp:GetChildren()) do
            t[i.Name] = (t[i.Name] or 0) + 1
        end
    end
    local char = getChar()
    if char then
        for _, i in ipairs(char:GetChildren()) do
            if i:IsA("Tool") then
                t[i.Name] = (t[i.Name] or 0) + 1
            end
        end
    end
    return t
end

local function findNewItem(before)
    local now = backpackItems()
    for name, count in pairs(now) do
        if (before[name] or 0) < count then
            return name
        end
    end
    return nil
end

--==================================================
-- LOGGER
--==================================================
local LogBuffer = {}
local logScroll = nil
local logLabels = {}

local function log(tag, msg)
    local line = string.format("[%s][%s] %s", os.date("%H:%M:%S"), tag, tostring(msg))
    print(line)
    table.insert(LogBuffer, line)
    if #LogBuffer > 200 then
        table.remove(LogBuffer, 1)
    end

    if logScroll then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextColor3 = Color3.fromRGB(170, 255, 170)
        lbl.Text = line
        lbl.Parent = logScroll
        table.insert(logLabels, lbl)
        if #logLabels > 60 then
            table.remove(logLabels, 1):Destroy()
        end
        task.defer(function()
            pcall(function()
                logScroll.CanvasPosition = Vector2.new(0, math.huge)
            end)
        end)
    end
end

--==================================================
-- ★ BYPASS ANTI-CHEAT (otomatis)
--==================================================
local function protectFn(f)
    return (newcclosure and newcclosure(f)) or f
end

local function initBypass()
    log("BYPASS", "Memasang bypass anti-cheat...")

    if hookmetamethod and getnamecallmethod then
        local ok, err = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", protectFn(function(self, ...)
                local method = getnamecallmethod()
                local name = ""
                pcall(function() name = string.lower(self.Name) end)

                if (method == "Kick" or method == "kick") and self == LocalPlayer then
                    log("BYPASS", "Kick diblokir 🛡️")
                    return
                end

                if method == "FireServer" or method == "InvokeServer" then
                    if not matches(name, Config.WhitelistKeywords) and matches(name, Config.BlockedRemoteKeywords) then
                        log("BYPASS", "Remote diblokir: " .. name)
                        return
                    end
                end

                return oldNamecall(self, ...)
            end))
        end)
        log("BYPASS", ok and "Hook __namecall aktif ✅" or ("Hook __namecall GAGAL: " .. tostring(err)))
    else
        log("BYPASS", "⚠️ Executor tidak support hookmetamethod")
    end

    if hookfunction then
        pcall(function()
            hookfunction(LocalPlayer.Kick, protectFn(function(self, ...)
                log("BYPASS", "Kick() diblokir 🛡️")
                return
            end))
        end)
    end

    if hookmetamethod then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", protectFn(function(self, key)
                if not checkcaller() and typeof(self) == "Instance"
                    and self:IsA("Humanoid") and key == "WalkSpeed"
                    and State.WalkSpeed then
                    return 16
                end
                return oldIndex(self, key)
            end))
        end)
    end

    local function tryDisable(s)
        if s:IsA("LocalScript") and matches(s.Name, Config.AntiCheatScriptNames) then
            pcall(function() s.Disabled = true end)
            log("BYPASS", "Anti-cheat dimatikan: " .. s:GetFullName())
        end
    end

    local function scanRoot(root)
        if not root then return end
        pcall(function()
            for _, s in ipairs(root:GetDescendants()) do
                tryDisable(s)
            end
            root.DescendantAdded:Connect(function(s)
                task.wait(0.1)
                tryDisable(s)
            end)
        end)
    end

    task.spawn(function() scanRoot(LocalPlayer:WaitForChild("PlayerScripts", 5)) end)
    task.spawn(function() scanRoot(LocalPlayer:WaitForChild("PlayerGui", 5)) end)
    task.spawn(function()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        scanRoot(char)
    end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        scanRoot(char)
    end)

    log("BYPASS", "Bypass selesai 🛡️")
end

--==================================================
-- ★ AUTO STEAL TP
--==================================================
local lastNoTargetLog = 0

local function passesFilter(txt)
    if #Config.RarityFilter > 0 and not matches(txt, Config.RarityFilter) then
        return false
    end
    if State.SkipHack and matches(txt, {"hack"}) then
        return false
    end
    if matches(txt, Config.StealSkipKeywords) then
        return false
    end
    return true
end

local function findStealTarget()
    local hrp = getHRP()
    if not hrp then return nil, nil end
    local homePos = HomeCFrame and HomeCFrame.Position or hrp.Position

    local bestP, bestPart, bestDist = nil, nil, math.huge
    local fbP, fbPart, fbDist = nil, nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            if blacklist[obj] and tick() - blacklist[obj] < Config.BlacklistTime then
                continue
            end
            if not isOwnPrompt(obj) then
                local part = promptPart(obj)
                if part then
                    local distHome = (part.Position - homePos).Magnitude
                    if distHome > Config.HomeRadius then
                        local txt = promptText(obj)
                        local dist = (part.Position - hrp.Position).Magnitude
                        if matches(txt, Config.StealKeywords) then
                            if passesFilter(txt) and dist < bestDist then
                                bestP, bestPart, bestDist = obj, part, dist
                            end
                        elseif Config.FallbackAnyPrompt and passesFilter(txt) and dist < fbDist then
                            fbP, fbPart, fbDist = obj, part, dist
                        end
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

    if not HomeCFrame then
        HomeCFrame = hrp.CFrame
        log("STEAL", "📍 Base otomatis di-set")
    end

    local prompt, part = findStealTarget()
    if not (prompt and part) then
        if tick() - lastNoTargetLog > 5 then
            lastNoTargetLog = tick()
            log("STEAL", "⚠️ Tidak ada target")
        end
        return
    end

    stealing = true
    log("STEAL", "🎯 Target: [" .. promptText(prompt) .. "] jarak " .. math.floor((part.Position - hrp.Position).Magnitude))

    local originalCollide = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            originalCollide[p] = p.CanCollide
            p.CanCollide = false
        end
    end

    -- 1) MASUK
    smartMove(part.Position + Vector3.new(0, 2, 0))
    -- tempel tepat di target supaya masuk jarak prompt
    pcall(function() char:PivotTo(CFrame.new(part.Position + Vector3.new(0, 2.5, 0))) end)
    task.wait(Config.SettleTime)

    -- 2) STEAL + VERIFIKASI
    local before = backpackItems()
    local sukses = false
    for i = 1, Config.StealRetries do
        -- pastikan tetap menempel di target tiap percobaan
        local h = getHRP()
        if h then
            h.AssemblyLinearVelocity = Vector3.zero
            pcall(function() char:PivotTo(CFrame.new(part.Position + Vector3.new(0, 2.5, 0))) end)
        end
        for _ = 1, 3 do
            firePrompt(prompt)
            task.wait(0.1)
        end
        task.wait(0.35)

        if not (prompt and prompt.Parent and prompt.Enabled) then
            sukses = true
            log("STEAL", "✅ Steal SUKSES (prompt hilang)")
            break
        end

        local newItem = findNewItem(before)
        if newItem then
            sukses = true
            log("STEAL", "✅ MASUK INVENTORY: " .. newItem)
            break
        end

        log("STEAL", "🔁 Retry " .. i .. "/" .. Config.StealRetries)
    end

    if not sukses then
        blacklist[prompt] = tick()
        log("STEAL", "❌ Server tolak steal -> skip 20s, pindah target lain")
    end

    -- 3) KELUAR + 4) PULANG
    local homePos = HomeCFrame.Position
    local dir = homePos - part.Position
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
    smartMove(part.Position + dir.Unit * Config.ExitDistance + Vector3.new(0, 2, 0))
    smartMove(homePos + Vector3.new(0, 2, 0))
    log("STEAL", "✅ Sampai base — siklus selesai")

    for p, v in pairs(originalCollide) do
        if p and p.Parent then
            p.CanCollide = v
        end
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
-- INSTANT STEAL
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
-- AUTO STEAL (tanpa TP) + AUTO COLLECT
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
-- WALKSPEED / INFINITE JUMP / NOCLIP / ANTI KNOCKBACK
--==================================================
RunService.Heartbeat:Connect(function()
    if State.WalkSpeed then
        local hum = getHumanoid()
        if hum and hum.WalkSpeed ~= Config.WalkSpeedValue then
            hum.WalkSpeed = Config.WalkSpeedValue
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

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
            local h = Vector3.new(v.X, 0, v.Z)
            if h.Magnitude > 100 then
                hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.1, v.Y, v.Z * 0.1)
            end
        end
    end
end)

--==================================================
-- DEBUG PROMPTS
--==================================================
local function debugPrompts()
    log("DEBUG", "===== DAFTAR PROMPT =====")
    local n = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            n = n + 1
            log("DEBUG", string.format("[%d] %s | Hold=%.1f | Own=%s",
                n, promptText(obj), obj.HoldDuration, tostring(isOwnPrompt(obj))))
        end
    end
    log("DEBUG", "Total: " .. n .. " prompt")
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

-- ★ Hapus GUI lama dari SEMUA lokasi (gethui / CoreGui / PlayerGui)
local function destroyOldGui(name)
    local roots = {}
    pcall(function() table.insert(roots, gethui()) end)
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() table.insert(roots, LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
    for _, root in ipairs(roots) do
        if root then
            for _, g in ipairs(root:GetChildren()) do
                if g:IsA("ScreenGui") and g.Name == name then
                    pcall(function() g:Destroy() end)
                end
            end
        end
    end
end

for _, name in ipairs({"BTDL_v6", "BTDL_v5", "BTDL_v4", "BTDL_v3", "BTDL_AllInOne", "StealTools"}) do
    destroyOldGui(name)
end

local gui = Instance.new("ScreenGui")
gui.Name = "BTDL_v6"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local isMobile = UserInputService.TouchEnabled
local viewport = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 400)
local guiWidth  = isMobile and math.clamp(viewport.X * 0.75, 340, 460) or 400
local guiHeight = isMobile and math.clamp(viewport.Y * 0.8, 210, 320) or 400
local btnHeight = isMobile and 40 or 32
local logHeight = isMobile and 60 or 100

-- drag universal (mouse + touch)
local function makeDraggable(handle, target, onTap)
    local dragging, startPos, startInput, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startPos, startInput = target.Position, input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if not moved and onTap then onTap() end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, guiWidth, 0, guiHeight)
main.Position = UDim2.new(0.5, -guiWidth / 2, 0.08, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(24, 40, 60)
title.Text = "  ⚔️ BTD Loot v6"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(90, 220, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.BorderSizePixel = 0
title.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -30)
body.Position = UDim2.new(0, 0, 0, 30)
body.BackgroundTransparency = 1
body.Parent = main

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 34, 0, 24)
minBtn.Position = UDim2.new(1, -38, 0, 3)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 3
minBtn.Parent = main
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = minBtn end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = minimized and UDim2.new(0, guiWidth, 0, 30) or UDim2.new(0, guiWidth, 0, guiHeight)
    minBtn.Text = minimized and "+" or "—"
end)

-- SIDEBAR + AREA KONTEN
local sidebarW = isMobile and 78 or 92
local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, sidebarW, 1, -6)
sidebar.Position = UDim2.new(0, 4, 0, 3)
sidebar.BackgroundColor3 = Color3.fromRGB(14, 20, 30)
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 2
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebar.Parent = body
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = sidebar end
do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 4)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Parent = sidebar
    local pd = Instance.new("UIPadding")
    pd.PaddingTop = UDim.new(0, 4)
    pd.Parent = sidebar
end

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -(sidebarW + 12), 1, -6)
content.Position = UDim2.new(0, sidebarW + 8, 0, 3)
content.BackgroundTransparency = 1
content.Parent = body

local btnScroll -- page aktif (dipakai makeToggle/makeButton)
local tabPages, tabButtons = {}, {}

local function selectTab(name)
    for n, pg in pairs(tabPages) do
        pg.Visible = (n == name)
        tabButtons[n].BackgroundColor3 = (n == name) and Color3.fromRGB(35, 110, 160) or Color3.fromRGB(30, 40, 58)
    end
end

local function newTab(name, isFrame)
    local page
    if isFrame then
        page = Instance.new("Frame")
        page.BackgroundTransparency = 1
    else
        page = Instance.new("ScrollingFrame")
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 4
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 6)
        l.HorizontalAlignment = Enum.HorizontalAlignment.Center
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Parent = page
        local pd = Instance.new("UIPadding")
        pd.PaddingTop = UDim.new(0, 2)
        pd.PaddingRight = UDim.new(0, 4)
        pd.Parent = page
    end
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BorderSizePixel = 0
    page.Visible = false
    page.Parent = content
    tabPages[name] = page

    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(1, -8, 0, isMobile and 38 or 32)
    tb.BackgroundColor3 = Color3.fromRGB(30, 40, 58)
    tb.Text = name
    tb.TextColor3 = Color3.fromRGB(235, 235, 235)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 11
    tb.TextWrapped = true
    tb.BorderSizePixel = 0
    tb.Parent = sidebar
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = tb end
    tb.MouseButton1Click:Connect(function() selectTab(name) end)
    tabButtons[name] = tb

    if not isFrame then btnScroll = page end
    return page
end

local function buildLogTab()
    local page = newTab("📜 Log", true)
    logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, -4, 1, -34)
    logScroll.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 4
    logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.Parent = page
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = logScroll end
    do local l = Instance.new("UIListLayout") l.SortOrder = Enum.SortOrder.LayoutOrder l.Parent = logScroll end

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 28)
    row.Position = UDim2.new(0, 0, 1, -28)
    row.BackgroundTransparency = 1
    row.Parent = page

    local function mk(txt, col, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -3, 1, 0)
        b.Position = pos
        b.BackgroundColor3 = col
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.Parent = row
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
        return b
    end
    local copyBtn = mk("📋 Copy", Color3.fromRGB(60, 90, 160), UDim2.new(0, 0, 0, 0))
    local clearBtn = mk("🗑 Clear", Color3.fromRGB(120, 50, 50), UDim2.new(0.5, 3, 0, 0))

    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(table.concat(LogBuffer, "\n"))
            log("LOG", "Log disalin ✅")
        else
            log("LOG", "⚠️ Executor tidak support copy — screenshot log ini")
        end
    end)
    clearBtn.MouseButton1Click:Connect(function()
        for _, lbl in ipairs(logLabels) do lbl:Destroy() end
        logLabels = {}
        LogBuffer = {}
    end)
    for _, line in ipairs(LogBuffer) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextColor3 = Color3.fromRGB(170, 255, 170)
        lbl.Text = line
        lbl.Parent = logScroll
        table.insert(logLabels, lbl)
    end
end


local function styleButton(btn)
    btn.Size = UDim2.new(1, -16, 0, btnHeight)
    btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
    btn.TextColor3 = Color3.fromRGB(235, 235, 235)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    if btn:IsA("GuiButton") then btn.AutoButtonColor = true end
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
end

local function makeToggle(labelText, stateKey, onToggle)
    local btn = Instance.new("TextButton")
    styleButton(btn)
    btn.Parent = btnScroll

    local function refresh()
        if State[stateKey] then
            btn.Text = labelText .. " : ON"
            btn.BackgroundColor3 = Color3.fromRGB(35, 140, 80)
        else
            btn.Text = labelText .. " : OFF"
            btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
        end
    end

    btn.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        refresh()
        log("GUI", labelText .. " -> " .. (State[stateKey] and "ON ✅" or "OFF"))
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
    btn.Parent = btnScroll
    btn.MouseButton1Click:Connect(function()
        pcall(callback, btn)
    end)
    return btn
end

--=== OPSI TAMBAHAN ===--
local function makeSection(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = "── " .. text .. " ──"
    l.TextColor3 = Color3.fromRGB(90, 220, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.Parent = btnScroll
end

local function makeNumberBox(labelText, cfgKey, minV, maxV)
    local box = Instance.new("TextBox")
    styleButton(box)
    box.Text = labelText .. ": " .. tostring(Config[cfgKey])
    box.PlaceholderText = labelText .. " (" .. minV .. "-" .. maxV .. ")"
    box.ClearTextOnFocus = true
    box.Parent = btnScroll
    box.FocusLost:Connect(function()
        local n = tonumber(string.match(box.Text, "-?[%d%.]+"))
        if n then
            Config[cfgKey] = math.clamp(n, minV, maxV)
            log("CFG", labelText .. " = " .. Config[cfgKey])
        end
        box.Text = labelText .. ": " .. tostring(Config[cfgKey])
    end)
end

newTab("📍 Base")
makeButton("📍 Set Base (berdiri di base!)", Color3.fromRGB(200, 120, 40), function(btn)
    local hrp = getHRP()
    if hrp then
        HomeCFrame = hrp.CFrame
        log("BASE", "📍 Base tersimpan")
        btn.Text = "✅ Base tersimpan!"
        task.wait(1)
        btn.Text = "📍 Set Base (berdiri di base!)"
    end
end)

makeButton("🏠 Pulang ke Base", Color3.fromRGB(200, 120, 40), function()
    if HomeCFrame then
        local c = getChar()
        if c then c:PivotTo(HomeCFrame + Vector3.new(0, 3, 0)) end
        log("TP", "Pulang ke base")
    else
        log("TP", "⚠️ Base belum di-set")
    end
end)
makeNumberBox("Radius Base", "HomeRadius", 10, 300)

newTab("★ Auto Steal TP")
makeToggle("★ Auto Steal TP", "AutoStealTP", function(on)
    if on and not HomeCFrame then
        local hrp = getHRP()
        if hrp then
            HomeCFrame = hrp.CFrame
            log("BASE", "📍 Base otomatis di-set")
        end
    end
end)

makeButton("▶ Steal TP Sekali", Color3.fromRGB(60, 90, 160), function()
    task.spawn(doStealCycle)
end)
makeNumberBox("Jumlah Retry", "StealRetries", 1, 10)
makeNumberBox("Kecepatan TP", "MoveStep", 4, 60)
makeNumberBox("Jeda Siklus (detik)", "DelayPerCycle", 0.1, 10)
makeNumberBox("Blacklist (detik)", "BlacklistTime", 5, 120)
State.FallbackAny = Config.FallbackAnyPrompt
makeToggle("Fallback Semua Prompt", "FallbackAny", function(on) Config.FallbackAnyPrompt = on end)

newTab("🔎 Filter Loot")

local filterBox = Instance.new("TextBox")
styleButton(filterBox)
filterBox.PlaceholderText = "Filter loot: golden, secret..."
filterBox.Text = ""
filterBox.Parent = btnScroll
filterBox.FocusLost:Connect(function()
    Config.RarityFilter = {}
    for word in string.gmatch(string.lower(filterBox.Text), "[^,%s]+") do
        table.insert(Config.RarityFilter, word)
    end
    log("GUI", "🎯 Filter: " .. (#Config.RarityFilter > 0 and table.concat(Config.RarityFilter, ", ") or "SEMUA loot"))
end)

makeToggle("Skip Prompt Hack", "SkipHack")

newTab("🤏 Auto Steal")
makeToggle("Auto Steal (tanpa TP)", "AutoSteal")
makeNumberBox("Range Auto Steal", "AutoStealRange", 5, 100)

newTab("⚡ Instant Steal")

makeToggle("Instant Steal", "InstantSteal", function(on)
    if on then
        for _, o in ipairs(Workspace:GetDescendants()) do
            pcall(applyInstant, o)
        end
    end
end)

newTab("🏃 WalkSpeed")
makeToggle("WalkSpeed", "WalkSpeed", function(on)
    if not on then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end
end)

local speedBox = Instance.new("TextBox")
styleButton(speedBox)
speedBox.Text = tostring(Config.WalkSpeedValue)
speedBox.PlaceholderText = "WalkSpeed (16-500)"
speedBox.Parent = btnScroll
speedBox.FocusLost:Connect(function()
    local n = tonumber(speedBox.Text)
    if n then
        Config.WalkSpeedValue = math.clamp(math.floor(n), 16, 500)
    end
    speedBox.Text = tostring(Config.WalkSpeedValue)
end)

newTab("🦘 Inf Jump")
makeToggle("Infinite Jump", "InfiniteJump")

newTab("👻 NoClip")
makeToggle("NoClip", "NoClip")

newTab("💰 Collect")
makeToggle("Auto Collect", "AutoCollect")
makeNumberBox("Range Auto Collect", "AutoCollectRange", 5, 100)

newTab("🛡 Anti KB")
makeToggle("Anti Knockback", "AntiKnockback")

newTab("🎯 TP Target")
makeButton("🎯 TP ke Target Terdekat", Color3.fromRGB(60, 90, 160), function()
    local _, part = findStealTarget()
    local c = getChar()
    if part and c then
        c:PivotTo(CFrame.new(part.Position + Vector3.new(0, 3, 0)))
        log("TP", "TP ke target")
    else
        log("TP", "⚠️ Tidak ada target")
    end
end)
makeButton("💀 Reset Karakter", Color3.fromRGB(120, 50, 50), function()
    local h = getHumanoid()
    if h then h.Health = 0 end
end)

newTab("👁 ESP Loot")
local espFolder = Instance.new("Folder")
espFolder.Name = "BTDL_ESP"
espFolder.Parent = gui
task.spawn(function()
    while true do
        task.wait(1.5)
        espFolder:ClearAllChildren()
        if State.ESP then
            local n = 0
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if n >= 60 then break end
                if obj:IsA("ProximityPrompt") and matches(promptText(obj), Config.StealKeywords) and not isOwnPrompt(obj) then
                    local part = promptPart(obj)
                    if part then
                        n = n + 1
                        local bb = Instance.new("BillboardGui")
                        bb.Adornee = part
                        bb.AlwaysOnTop = true
                        bb.Size = UDim2.new(0, 120, 0, 20)
                        bb.StudsOffset = Vector3.new(0, 3, 0)
                        local t = Instance.new("TextLabel")
                        t.Size = UDim2.new(1, 0, 1, 0)
                        t.BackgroundTransparency = 1
                        t.Text = "💰 " .. (obj.ObjectText ~= "" and obj.ObjectText or part.Name)
                        t.TextColor3 = Color3.fromRGB(255, 220, 60)
                        t.TextStrokeTransparency = 0
                        t.Font = Enum.Font.GothamBold
                        t.TextSize = 12
                        t.Parent = bb
                        bb.Parent = espFolder
                    end
                end
            end
        end
    end
end)
makeToggle("ESP Loot", "ESP")

newTab("💡 Fullbright")

local Lighting = game:GetService("Lighting")
local oldLight = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd}
makeToggle("Fullbright", "Fullbright", function(on)
    if on then
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = 2, 14, 1e5
    else
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = oldLight.Brightness, oldLight.ClockTime, oldLight.FogEnd
    end
end)

newTab("😴 Anti AFK")
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)
State.AntiAFK = true
makeToggle("Anti AFK", "AntiAFK")

newTab("🕊 Fly")
makeToggle("Fly (Mobile/PC)", "Fly")
RunService.Heartbeat:Connect(function()
    if State.Fly then
        local hrp, hum = getHRP(), getHumanoid()
        if hrp and hum then
            local cam = Workspace.CurrentCamera
            local dir = hum.MoveDirection
            local vy = 0
            if hum.Jump then vy = 50 end
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * Config.WalkSpeedValue, vy, dir.Z * Config.WalkSpeedValue)
                + Vector3.new(0, 1.9, 0)
        end
    end
end)

newTab("🔁 Auto Base")
makeToggle("Auto Reset Kalau Mati", "AutoRespawnBase")
LocalPlayer.CharacterAdded:Connect(function(char)
    if State.AutoRespawnBase and HomeCFrame then
        task.wait(1)
        pcall(function() char:PivotTo(HomeCFrame + Vector3.new(0, 3, 0)) end)
    end
end)

newTab("🌐 Server")
makeButton("🔄 Rejoin Server", Color3.fromRGB(90, 60, 130), function()
    local TS = game:GetService("TeleportService")
    pcall(function() TS:Teleport(game.PlaceId, LocalPlayer) end)
end)
makeButton("❌ Tutup Script (Unload)", Color3.fromRGB(120, 50, 50), function()
    for k in pairs(State) do State[k] = false end
    espFolder:ClearAllChildren()
    gui:Destroy()
end)

newTab("🔍 Debug")
makeButton("🔍 Debug Prompts", Color3.fromRGB(90, 60, 130), debugPrompts)

buildLogTab()
selectTab("📍 Base")

-- pastikan menu terbuka (tidak minimize) saat pertama jalan
minimized = false
body.Visible = true
main.Size = UDim2.new(0, guiWidth, 0, guiHeight)
minBtn.Text = "—"

--=== LOG: tangkap error Roblox + simpan ke file + kirim webhook ===--
pcall(function()
    game:GetService("LogService").MessageOut:Connect(function(msg, mtype)
        if mtype == Enum.MessageType.MessageError or mtype == Enum.MessageType.MessageWarning then
            log(mtype == Enum.MessageType.MessageError and "ERR" or "WARN", string.sub(msg, 1, 160))
        end
    end)
end)

local LOG_FILE = "BTD_Loot_log.txt"
local function saveLogFile()
    if writefile then
        pcall(writefile, LOG_FILE, table.concat(LogBuffer, "\n"))
        return true
    end
    return false
end
task.spawn(function()
    while true do
        task.wait(10)
        saveLogFile()
    end
end)

local webhookUrl = ""
local function sendWebhook()
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if webhookUrl == "" or not req then
        log("LOG", "⚠️ Isi URL webhook Discord dulu / executor tidak support request")
        return
    end
    local text = "```\n" .. string.sub(table.concat(LogBuffer, "\n"), -1800) .. "\n```"
    local ok, err = pcall(function()
        req({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = game:GetService("HttpService"):JSONEncode({content = text}),
        })
    end)
    log("LOG", ok and "Log terkirim ke webhook ✅" or ("Gagal kirim: " .. tostring(err)))
end

newTab("📤 Kirim Log")
makeButton("📋 Copy Semua Log", Color3.fromRGB(60, 90, 160), function()
    if setclipboard then
        setclipboard(table.concat(LogBuffer, "\n"))
        log("LOG", "Log disalin ✅")
    else
        log("LOG", "⚠️ Executor tidak support copy")
    end
end)
makeButton("💾 Simpan ke File", Color3.fromRGB(40, 110, 90), function()
    log("LOG", saveLogFile() and ("Tersimpan: workspace/" .. LOG_FILE) or "⚠️ writefile tidak didukung")
end)
local whBox = Instance.new("TextBox")
styleButton(whBox)
whBox.PlaceholderText = "URL Webhook Discord (opsional)"
whBox.Text = ""
whBox.ClearTextOnFocus = false
whBox.Parent = btnScroll
whBox.FocusLost:Connect(function() webhookUrl = whBox.Text end)
makeButton("📨 Kirim Log ke Webhook", Color3.fromRGB(88, 101, 242), function()
    webhookUrl = whBox.Text
    sendWebhook()
end)
selectTab("📍 Base")

--=== TOMBOL ⚔️ MELAYANG ===--
local bubble = Instance.new("TextButton")
bubble.Size = UDim2.new(0, 48, 0, 48)
bubble.Position = UDim2.new(0, 12, 0.4, 0)
bubble.BackgroundColor3 = Color3.fromRGB(24, 40, 60)
bubble.Text = "⚔️"
bubble.TextSize = 22
bubble.Font = Enum.Font.GothamBold
bubble.TextColor3 = Color3.fromRGB(90, 220, 255)
bubble.BorderSizePixel = 0
bubble.Active = true
bubble.Parent = gui

makeDraggable(title, main)
makeDraggable(bubble, bubble, function()
    main.Visible = not main.Visible
end)

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleGUIKey then
        main.Visible = not main.Visible
    end
end)

--==================================================
-- START
--==================================================
log("SYS", "Script v6 loaded ✅ " .. (isMobile and "(MOBILE 📱)" or "(PC 🖥️)"))
task.spawn(function()
    task.wait(1.5)
    initBypass()
end)
