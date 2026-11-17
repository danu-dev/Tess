--[[
    ⚔️ BUILD TO DEFEND LOOT — ALL-IN-ONE v4 (Mobile Edition)
    =========================================================
    ★ BYPASS ANTI-CHEAT AGGRESSIVE — semua otomatis saat load:
        - Blokir Kick (hookmetamethod + hookfunction)
        - Blokir remote anti-cheat mencurigakan
        - Matikan LocalScript AC di PlayerScripts, PlayerGui & karakter
        - Spoof WalkSpeed: script AC membaca speed kamu sebagai 16
    ★ AUTO STEAL TP — TP masuk -> steal -> keluar -> jalan balik (anti-nyangkut)
        - Jalan balik pakai noclip sementara
        - Kalau tetap kehalang -> TP langsung ke base (tidak ada lagi timeout nyangkut)
    ★ FILTER LOOT / RARITY — pilih loot yang mau dicuri (mis: golden, secret, legendary)
    ★ SKIP HACK — prompt "Hack" (bukan loot) otomatis di-skip
    ★ Tombol ⚔️ melayang untuk buka/tutup GUI (mobile)
    ★ Panel log + Copy Log

    CARA PAKAI:
      1. Execute -> tap tombol ⚔️
      2. Berdiri di base -> tap "📍 Set Base"
      3. (Opsional) isi "Filter Loot", mis: golden, legendary
      4. Aktifkan "★ Auto Steal TP" -> selesai
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

    -- Auto Steal TP
    HomeRadius        = 45,   -- area base sendiri (studs) — prompt di sini di-skip
    StealHoldTime     = 0.5,  -- lama diam di target saat steal
    ExitDistance      = 30,   -- jarak keluar dari base musuh setelah steal
    WalkBackTimeout   = 6,    -- batas waktu jalan balik sebelum TP paksa (detik)
    ReturnTPFallback  = true, -- kalau jalan balik kehalang -> TP langsung ke base
    DelayPerCycle     = 0.8,
    FallbackAnyPrompt = true,

    RarityFilter     = {},    -- ISI LEWAT GUI. contoh: {"golden","secret","legendary"} — kosong = semua
    StealKeywords    = {"steal", "claim", "loot", "rob", "hack", "take", "grab"},
    CollectKeywords  = {"collect", "cash", "money", "pickup", "drop"},

    -- Bypass
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
    SkipHack      = true, -- default ON: prompt "Hack" di-skip (bukan loot)
}

local HomeCFrame = nil

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
-- ★ BYPASS ANTI-CHEAT (aggressive — semua otomatis)
--==================================================
local function protectFn(f)
    return (newcclosure and newcclosure(f)) or f
end

local function initBypass()
    log("BYPASS", "Memasang bypass anti-cheat (AGGRESSIVE)...")

    -- A. Hook __namecall: blokir Kick + remote anti-cheat
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
                        log("BYPASS", "Remote diblokir: " .. name .. " (" .. method .. ")")
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

    -- B. Hook fungsi Kick langsung
    if hookfunction then
        local ok, err = pcall(function()
            hookfunction(LocalPlayer.Kick, protectFn(function(self, ...)
                log("BYPASS", "Kick() diblokir 🛡️")
                return
            end))
        end)
        log("BYPASS", ok and "Hook Kick aktif ✅" or ("Hook Kick GAGAL: " .. tostring(err)))
    else
        log("BYPASS", "⚠️ Executor tidak support hookfunction")
    end

    -- C. Spoof WalkSpeed: script AC membaca speed kamu = 16 (padahal jalan cepat)
    if hookmetamethod then
        local ok, err = pcall(function()
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
        log("BYPASS", ok and "Spoof WalkSpeed aktif ✅" or ("Spoof WalkSpeed GAGAL: " .. tostring(err)))
    end

    -- D. Matikan LocalScript anti-cheat di SEMUA tempat + jaga yang baru muncul
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
    -- filter rarity: kalau diisi, HANYA loot yang mengandung kata filter
    if #Config.RarityFilter > 0 and not matches(txt, Config.RarityFilter) then
        return false
    end
    -- skip prompt Hack (bukan loot)
    if State.SkipHack and matches(txt, {"hack"}) then
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
    local totalPrompts, skipped = 0, 0

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            totalPrompts = totalPrompts + 1
            if not isOwnPrompt(obj) then
                local part = promptPart(obj)
                if part then
                    local distHome = (part.Position - homePos).Magnitude
                    if distHome > Config.HomeRadius then
                        local txt = promptText(obj)
                        local dist = (part.Position - hrp.Position).Magnitude
                        if matches(txt, Config.StealKeywords) then
                            if passesFilter(txt) then
                                if dist < bestDist then
                                    bestP, bestPart, bestDist = obj, part, dist
                                end
                            else
                                skipped = skipped + 1
                            end
                        elseif Config.FallbackAnyPrompt and passesFilter(txt) and dist < fbDist then
                            fbP, fbPart, fbDist = obj, part, dist
                        end
                    end
                end
            end
        end
    end

    if bestP then return bestP, bestPart, totalPrompts, skipped end
    return fbP, fbPart, totalPrompts, skipped
end

local stealing = false

local function doStealCycle()
    if stealing then return end
    local char = getChar()
    local hrp  = getHRP()
    if not (char and hrp) then
        log("STEAL", "⚠️ Karakter belum siap")
        return
    end

    if not HomeCFrame then
        HomeCFrame = hrp.CFrame
        log("STEAL", "📍 Base otomatis di-set ke posisi sekarang")
    end

    local prompt, part, totalPrompts, skipped = findStealTarget()
    if not (prompt and part) then
        if tick() - lastNoTargetLog > 5 then
            lastNoTargetLog = tick()
            if skipped and skipped > 0 and #Config.RarityFilter > 0 then
                log("STEAL", "⚠️ Tidak ada loot yang cocok filter: " .. table.concat(Config.RarityFilter, ", "))
            else
                log("STEAL", "⚠️ Tidak ada target (" .. totalPrompts .. " prompt). Tap Debug Prompts.")
            end
        end
        return
    end

    stealing = true
    log("STEAL", "🎯 Target: [" .. promptText(prompt) .. "] jarak " .. math.floor((part.Position - hrp.Position).Magnitude) .. " studs")

    -- 1) TP MASUK
    char:PivotTo(part.CFrame + Vector3.new(0, 2, 0))
    log("STEAL", "🌀 TP masuk ke base musuh")
    task.wait(0.15)

    -- 2) STEAL
    firePrompt(prompt)
    log("STEAL", "💰 Steal fired!")
    task.wait(Config.StealHoldTime)
    firePrompt(prompt)

    -- 3) KELUAR base musuh
    local homePos = HomeCFrame.Position
    local dir = homePos - part.Position
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
    char:PivotTo(CFrame.new(part.Position + dir.Unit * Config.ExitDistance + Vector3.new(0, 2, 0)))
    log("STEAL", "🚪 Keluar base musuh")
    task.wait(0.2)

    -- 4) JALAN balik — pakai noclip SEMENTARA biar tidak kehalang tembok
    local hum = getHumanoid()
    if hum then
        log("STEAL", "🏃 Jalan balik ke base...")

        -- simpan kondisi collide asli, lalu tembus sementara
        local originalCollide = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                originalCollide[p] = p.CanCollide
                p.CanCollide = false
            end
        end

        hum:MoveTo(homePos)
        local arrived = false
        local t0 = tick()
        while tick() - t0 < Config.WalkBackTimeout do
            local h = getHRP()
            if not h then break end
            if (h.Position - homePos).Magnitude < 10 then
                arrived = true
                break
            end
            task.wait(0.2)
        end

        -- kembalikan collide seperti semula
        for p, v in pairs(originalCollide) do
            if p and p.Parent then
                p.CanCollide = v
            end
        end

        if arrived then
            log("STEAL", "✅ Sampai base — siklus selesai")
        elseif Config.ReturnTPFallback then
            -- FIX TIMEOUT: kehalang? langsung TP pulang, tidak buang waktu
            char:PivotTo(HomeCFrame)
            log("STEAL", "🌀 Jalan kehalang -> TP langsung ke base ✅")
        else
            log("STEAL", "⚠️ Timeout jalan balik")
        end

        local h = getHRP()
        if h then hum:MoveTo(h.Position) end -- stop
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
    log("DEBUG", "Total: " .. n .. " prompt — Copy Log lalu kirim ke aku")
end

--==================================================
-- GUI (mobile-friendly)
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
gui.Name = "BTDL_v4"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local isMobile = UserInputService.TouchEnabled
local guiHeight = isMobile and 360 or 430

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 250, 0, guiHeight)
main.Position = UDim2.new(0.5, -125, 0.15, 0)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
title.Text = "⚔️ BTD Loot v4"
title.TextColor3 = Color3.fromRGB(255, 215, 90)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.BorderSizePixel = 0
title.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local btnScroll = Instance.new("ScrollingFrame")
btnScroll.Size = UDim2.new(1, 0, 0, guiHeight - 30 - 20 - 100 - 32)
btnScroll.Position = UDim2.new(0, 0, 0, 32)
btnScroll.BackgroundTransparency = 1
btnScroll.BorderSizePixel = 0
btnScroll.ScrollBarThickness = 4
btnScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
btnScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
btnScroll.Parent = main

local btnLayout = Instance.new("UIListLayout")
btnLayout.Padding = UDim.new(0, 6)
btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
btnLayout.Parent = btnScroll

local btnPad = Instance.new("UIPadding")
btnPad.PaddingTop = UDim.new(0, 6)
btnPad.Parent = btnScroll

local logTitle = Instance.new("TextLabel")
logTitle.Size = UDim2.new(1, 0, 0, 16)
logTitle.Position = UDim2.new(0, 8, 0, guiHeight - 100 - 30)
logTitle.BackgroundTransparency = 1
logTitle.Text = "📜 LOG:"
logTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 11
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Parent = main

logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -16, 0, 100)
logScroll.Position = UDim2.new(0, 8, 0, guiHeight - 100 - 14)
logScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 4
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.Parent = main

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logScroll

local logLayout = Instance.new("UIListLayout")
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logScroll

local logBtnRow = Instance.new("Frame")
logBtnRow.Size = UDim2.new(1, -16, 0, 26)
logBtnRow.Position = UDim2.new(0, 8, 1, -30)
logBtnRow.BackgroundTransparency = 1
logBtnRow.Parent = main

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.5, -3, 1, 0)
copyBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
copyBtn.Text = "📋 Copy Log"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 12
copyBtn.BorderSizePixel = 0
copyBtn.Parent = logBtnRow
local copyCorner = Instance.new("UICorner") copyCorner.CornerRadius = UDim.new(0, 6) copyCorner.Parent = copyBtn

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0.5, -3, 1, 0)
clearBtn.Position = UDim2.new(0.5, 3, 0, 0)
clearBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
clearBtn.Text = "🗑 Clear"
clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 12
clearBtn.BorderSizePixel = 0
clearBtn.Parent = logBtnRow
local clearCorner = Instance.new("UICorner") clearCorner.CornerRadius = UDim.new(0, 6) clearCorner.Parent = clearBtn

copyBtn.MouseButton1Click:Connect(function()
    local text = table.concat(LogBuffer, "\n")
    if setclipboard then
        setclipboard(text)
        log("LOG", "Log disalin ✅ paste & kirim ke aku")
    else
        log("LOG", "⚠️ Executor tidak support copy — screenshot log ini")
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    for _, lbl in ipairs(logLabels) do lbl:Destroy() end
    logLabels = {}
    LogBuffer = {}
end)

local function styleButton(btn)
    btn.Size = UDim2.new(1, -16, 0, 32)
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
    btn.Parent = btnScroll

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

--=== ISI TOMBOL ===--
makeButton("📍 Set Base (berdiri di base!)", Color3.fromRGB(200, 120, 40), function(btn)
    local hrp = getHRP()
    if hrp then
        HomeCFrame = hrp.CFrame
        log("BASE", "📍 Base tersimpan di " .. tostring(Vector3.new(
            math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z))))
        btn.Text = "✅ Base tersimpan!"
        task.wait(1)
        btn.Text = "📍 Set Base (berdiri di base!)"
    end
end)

makeToggle("★ Auto Steal TP", "AutoStealTP", function(on)
    if on and not HomeCFrame then
        local hrp = getHRP()
        if hrp then
            HomeCFrame = hrp.CFrame
            log("BASE", "📍 Base otomatis di-set ke posisi sekarang")
        end
    end
end)

makeButton("▶ Steal TP Sekali", Color3.fromRGB(60, 90, 160), function()
    task.spawn(doStealCycle)
end)

-- Filter loot / rarity
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
    if #Config.RarityFilter > 0 then
        log("GUI", "🎯 Filter loot aktif: " .. table.concat(Config.RarityFilter, ", "))
    else
        log("GUI", "🎯 Filter loot: SEMUA loot")
    end
end)

makeToggle("Skip Prompt Hack", "SkipHack")
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
speedBox.PlaceholderText = "WalkSpeed (16-500)"
speedBox.Parent = btnScroll
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

makeButton("🔍 Debug Prompts", Color3.fromRGB(90, 60, 130), debugPrompts)

--=== TOMBOL ⚔️ MELAYANG ===--
local bubble = Instance.new("TextButton")
bubble.Size = UDim2.new(0, 48, 0, 48)
bubble.Position = UDim2.new(0, 12, 0.4, 0)
bubble.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
bubble.Text = "⚔️"
bubble.TextSize = 22
bubble.Font = Enum.Font.GothamBold
bubble.TextColor3 = Color3.fromRGB(255, 215, 90)
bubble.BorderSizePixel = 0
bubble.Active = true
bubble.Draggable = true
bubble.Parent = gui

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

bubble.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleGUIKey then
        main.Visible = not main.Visible
    end
end)

--==================================================
-- START
--==================================================
log("SYS", "Script v4 loaded ✅ " .. (isMobile and "(mode MOBILE 📱)" or "(mode PC 🖥️)"))
log("SYS", "Tap tombol ⚔️ untuk buka/tutup GUI")
task.spawn(function()
    task.wait(1.5)
    initBypass()
end)
