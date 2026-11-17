--[[
    ⚔️ BUILD TO DEFEND LOOT — ALL-IN-ONE v8
    ========================================
    v8:
    ★ ANTI ANOMALI / MODE MANUSIA — saat steal "tidak normal", server
      tetap menganggap normal:
      - glide dibatasi kecepatan per-DETIK (terlihat seperti lari, bukan TP)
      - steal menahan prompt sesuai HoldDuration asli (bukan spam fire)
      - semua timing diberi jitter acak (ritme tidak kaku seperti bot)
    v7:
    ★ UI baru: modern, ringan, 5 tab (Steal, Filter, Player, Misc, Log)
      — tab dibangun lazy, log hanya 1 TextLabel
    ★ Filter rarity (Common..OG), jarak maks target, fallback OFF
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
    ScanDelay        = 0.5,
    AutoStealRange   = 20,
    AutoCollectRange = 25,

    HomeRadius        = 45,
    MoveStep          = 12,
    -- ★ ANTI ANOMALI
    HumanMode         = true,  -- ON: server melihat gerakan/steal seperti pemain normal
    NormalMoveSpeed   = 60,    -- studs per DETIK saat glide (16=jalan, 50-60=lari cepat)
    JitterDelay       = 0.25,  -- variasi acak (detik) pada semua timing
    SettleTime        = 0.35,
    StealRetries      = 3,
    BlacklistTime     = 20,
    ExitDistance      = 30,
    DelayPerCycle     = 0.5,
    FallbackAnyPrompt = false, -- OFF: hanya prompt "Steal" asli, tidak nyasar ke prompt lain
    MaxTargetDistance = 200,   -- target lebih jauh dari ini diabaikan
    Rarities          = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Vaulted", "OG"},

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
    HumanMode     = true,
}

local HomeCFrame = nil
local blacklist  = {}

-- CACHE prompt/touch (scan sekali, update lewat event) => ringan
local PromptCache = {}
local ownCache = setmetatable({}, {__mode = "k"})
do
    local function track(o)
        if o:IsA("ProximityPrompt") or o:IsA("TouchInterest") then
            PromptCache[o] = true
        end
    end
    for o in pairs(PromptCache) do track(o) end
    Workspace.DescendantAdded:Connect(track)
    Workspace.DescendantRemoving:Connect(function(o) PromptCache[o] = nil; ownCache[o] = nil end)
end

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

local function isOwnPromptRaw(prompt)
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

local function isOwnPrompt(prompt)
    local c = ownCache[prompt]
    if c == nil then
        c = isOwnPromptRaw(prompt)
        ownCache[prompt] = c
    end
    return c
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
    while tick() - t0 < 15 do
        local char, hrp = getChar(), getHRP()
        if not (char and hrp) then return end
        local delta = targetPos - hrp.Position
        local dist  = delta.Magnitude
        if dist <= 3.5 then break end
        local dt = RunService.Heartbeat:Wait()
        local step
        if Config.HumanMode then
            -- kecepatan per DETIK: server melihat "lari", bukan teleport
            step = math.max(Config.NormalMoveSpeed * dt, 0.5)
        else
            step = Config.MoveStep
        end
        char:PivotTo(CFrame.new(hrp.Position + delta.Unit * math.min(step, dist)))
    end
end

-- delay dengan jitter acak (ritme tidak kaku seperti bot)
local function jwait(base)
    task.wait(base + math.random() * Config.JitterDelay)
end

-- tahan prompt seperti pemain asli (hormati HoldDuration asli dari server)
local function humanSteal(prompt)
    local hold = 0
    pcall(function() hold = prompt.HoldDuration or 0 end)
    pcall(function()
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 15)
    end)
    pcall(function() prompt:InputHoldBegin() end)
    if hold > 0 then
        jwait(hold)
    else
        jwait(0.1)
    end
    pcall(function() prompt:InputHoldEnd() end)
    -- sekali penguat via fireproximityprompt (bukan spam)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt, 1) end)
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
local logScroll, logLabel = nil, nil
local logPending = false

local function refreshLog()
    logPending = false
    if logLabel then
        logLabel.Text = table.concat(LogBuffer, "\n", math.max(1, #LogBuffer - 39))
        task.defer(function()
            pcall(function() logScroll.CanvasPosition = Vector2.new(0, 1e6) end)
        end)
    end
end

local function log(tag, msg)
    local line = string.format("[%s][%s] %s", os.date("%H:%M:%S"), tag, tostring(msg))
    print(line)
    table.insert(LogBuffer, line)
    if #LogBuffer > 200 then
        table.remove(LogBuffer, 1)
    end
    -- satu TextLabel saja, di-update paling cepat tiap 0.3 dtk (ringan)
    if logLabel and not logPending then
        logPending = true
        task.delay(0.3, refreshLog)
    end
end

--==================================================
-- ★ BYPASS ANTI-CHEAT (otomatis)
--==================================================
local function protectFn(f)
    return (newcclosure and newcclosure(f)) or f
end

local remoteVerdict = {}

local function initBypass()
    log("BYPASS", "Memasang bypass anti-cheat...")

    if hookmetamethod and getnamecallmethod then
        local ok, err = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", protectFn(function(self, ...)
                -- jalur cepat: mayoritas namecall langsung lewat tanpa kerja ekstra
                local method = getnamecallmethod()
                if method == "Kick" or method == "kick" then
                    if self == LocalPlayer then
                        task.defer(log, "BYPASS", "Kick diblokir 🛡️")
                        return
                    end
                elseif method == "FireServer" or method == "InvokeServer" then
                    local ok, name = pcall(function() return string.lower(self.Name) end)
                    if ok then
                        local c = remoteVerdict[name]
                        if c == nil then
                            c = (not matches(name, Config.WhitelistKeywords)) and matches(name, Config.BlockedRemoteKeywords)
                            remoteVerdict[name] = c
                        end
                        if c then
                            task.defer(log, "BYPASS", "Remote diblokir: " .. name)
                            return
                        end
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
                if key == "WalkSpeed" and State.WalkSpeed
                    and not checkcaller() and typeof(self) == "Instance"
                    and self:IsA("Humanoid") then
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

--=== DETEKSI RARITY (nama/attribute/text di sekitar prompt) ===--
local RaritySel = {}      -- rarity yang dipilih; kosong = semua
local rarityCache = setmetatable({}, {__mode = "k"})

local function hasWord(text, word)
    return string.find(string.lower(text), "%f[%a]" .. string.lower(word) .. "%f[%A]") ~= nil
end

local function findRarityIn(text)
    if type(text) ~= "string" or text == "" then return nil end
    for _, r in ipairs(Config.Rarities) do
        if hasWord(text, r) then return r end
    end
    return nil
end

local function detectRarity(prompt)
    local c = rarityCache[prompt]
    if c and (c.r or tick() - c.t < 5) then return c.r end

    local found
    local node = prompt.Parent
    local depth = 0
    while node and node ~= Workspace and depth < 5 and not found do
        found = findRarityIn(node.Name)
        if not found then
            for k, v in pairs(node:GetAttributes()) do
                found = findRarityIn(tostring(k)) or findRarityIn(tostring(v))
                if found then break end
            end
        end
        if not found then
            for _, ch in ipairs(node:GetChildren()) do
                if ch:IsA("StringValue") then
                    found = findRarityIn(ch.Name) or findRarityIn(ch.Value)
                elseif ch:IsA("Folder") or ch:IsA("Model") or ch:IsA("BasePart") then
                    found = findRarityIn(ch.Name)
                end
                if found then break end
            end
        end
        -- label teks (BillboardGui/SurfaceGui) di dalam model
        if not found and depth >= 1 then
            for _, d in ipairs(node:GetDescendants()) do
                if d:IsA("TextLabel") then
                    found = findRarityIn(d.Text)
                    if found then break end
                end
            end
        end
        node = node.Parent
        depth = depth + 1
    end

    rarityCache[prompt] = {r = found, t = tick()}
    return found
end

local function rarityOK(prompt)
    if next(RaritySel) == nil then return true end
    local r = detectRarity(prompt)
    return r ~= nil and RaritySel[r] == true -- rarity tak terdeteksi = dilewati
end

local function passesFilter(txt, prompt)
    if prompt and not rarityOK(prompt) then
        return false
    end
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

    for obj in pairs(PromptCache) do
        if obj:IsA("ProximityPrompt") then
            if blacklist[obj] and tick() - blacklist[obj] < Config.BlacklistTime then
                continue
            end
            if not isOwnPrompt(obj) then
                local part = promptPart(obj)
                if part then
                    local distHome = (part.Position - homePos).Magnitude
                    if distHome > Config.HomeRadius
                        and (part.Position - hrp.Position).Magnitude <= Config.MaxTargetDistance then
                        local txt = promptText(obj)
                        local dist = (part.Position - hrp.Position).Magnitude
                        if matches(txt, Config.StealKeywords) then
                            if dist < bestDist and passesFilter(txt, obj) then
                                bestP, bestPart, bestDist = obj, part, dist
                            end
                        elseif Config.FallbackAnyPrompt and dist < fbDist and passesFilter(txt, obj) then
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
    jwait(Config.SettleTime)

    -- 2) STEAL + VERIFIKASI
    local before = backpackItems()
    local sukses = false

    -- kunci posisi tiap frame (anti jatuh karena CanCollide off / konveyor bergerak)
    local lockConn = RunService.Heartbeat:Connect(function()
        local h = getHRP()
        if h and part and part.Parent then
            h.CFrame = CFrame.new(part.Position + Vector3.new(0, 2.5, 0))
            h.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    jwait(0.4) -- beri waktu server menerima posisi baru

    for i = 1, Config.StealRetries do
        if Config.HumanMode then
            humanSteal(prompt) -- terlihat seperti pemain biasa menahan E
        else
            for _ = 1, 3 do
                firePrompt(prompt)
                task.wait(0.1)
            end
        end
        jwait(0.5)

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

    lockConn:Disconnect()
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
        jwait(Config.DelayPerCycle) -- jitter: ritme antar siklus tidak kaku
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
                for obj in pairs(PromptCache) do
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

local ncParts, ncT = {}, 0
RunService.Stepped:Connect(function()
    if State.NoClip then
        local char = getChar()
        if char then
            if tick() - ncT > 1 then
                ncT = tick()
                ncParts = {}
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then table.insert(ncParts, part) end
                end
            end
            for _, part in ipairs(ncParts) do
                if part.CanCollide then part.CanCollide = false end
            end
        end
    end
end)

local akT = 0
RunService.Heartbeat:Connect(function()
    if State.AntiKnockback and tick() - akT > 0.5 then
        akT = tick()
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
    for obj in pairs(PromptCache) do
        if obj:IsA("ProximityPrompt") then
            n = n + 1
            log("DEBUG", string.format("[%d] %s | Hold=%.1f | Own=%s | Rarity=%s",
                n, promptText(obj), obj.HoldDuration, tostring(isOwnPrompt(obj)), tostring(detectRarity(obj))))
        end
    end
    log("DEBUG", "Total: " .. n .. " prompt")
end

--==================================================
-- GUI v7 — modern & ringan (tab dibuat lazy, tanpa banyak instance)
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
for _, name in ipairs({"BTDL_v8", "BTDL_v7", "BTDL_v6", "BTDL_v5", "BTDL_v4", "BTDL_v3", "BTDL_AllInOne", "StealTools"}) do
    destroyOldGui(name)
end

local gui = Instance.new("ScreenGui")
gui.Name = "BTDL_v8"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

State.FallbackAny = Config.FallbackAnyPrompt
State.AntiAFK = true

local espFolder = Instance.new("Folder")
espFolder.Name = "BTDL_ESP"
espFolder.Parent = gui

do
    local isMobile = UserInputService.TouchEnabled
    local viewport = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 400)
    local W   = isMobile and math.clamp(viewport.X * 0.55, 300, 380) or 360
    local H   = isMobile and math.clamp(viewport.Y * 0.78, 210, 280) or 330
    local ROW = isMobile and 34 or 30

    local C = {
        bg     = Color3.fromRGB(18, 20, 28),
        bar    = Color3.fromRGB(26, 29, 40),
        row    = Color3.fromRGB(34, 38, 52),
        accent = Color3.fromRGB(96, 156, 255),
        on     = Color3.fromRGB(70, 205, 130),
        off    = Color3.fromRGB(72, 78, 98),
        text   = Color3.fromRGB(232, 235, 242),
        sub    = Color3.fromRGB(135, 143, 165),
        danger = Color3.fromRGB(210, 75, 80),
    }

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 6)
        c.Parent = o
    end

    -- drag (mouse + touch)
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

    ----------------------------------------------------------
    -- WINDOW
    ----------------------------------------------------------
    local main = mk("Frame", {
        Name = "Main", Size = UDim2.new(0, W, 0, H),
        Position = UDim2.new(0.5, -W / 2, 0.08, 0),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
    }, gui)
    corner(main, 10)

    local topbar = mk("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.bar, BorderSizePixel = 0}, main)
    mk("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
        Text = "⚔️ BTD Loot  v8", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)

    local body = mk("Frame", {Size = UDim2.new(1, 0, 1, -28), Position = UDim2.new(0, 0, 0, 28), BackgroundTransparency = 1}, main)

    local minimized = false
    local minBtn = mk("TextButton", {
        Size = UDim2.new(0, 28, 0, 20), Position = UDim2.new(1, -62, 0, 4), BackgroundColor3 = C.row,
        Text = "—", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0,
    }, topbar)
    corner(minBtn, 5)
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        body.Visible = not minimized
        main.Size = UDim2.new(0, W, 0, minimized and 28 or H)
        minBtn.Text = minimized and "+" or "—"
    end)
    local hideBtn = mk("TextButton", {
        Size = UDim2.new(0, 28, 0, 20), Position = UDim2.new(1, -32, 0, 4), BackgroundColor3 = C.danger,
        Text = "✕", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0,
    }, topbar)
    corner(hideBtn, 5)
    hideBtn.MouseButton1Click:Connect(function() main.Visible = false end)

    ----------------------------------------------------------
    -- TABS (lazy build)
    ----------------------------------------------------------
    local TAB_NAMES = {"Steal", "Filter", "Player", "Misc", "Log"}
    local tabbar = mk("Frame", {Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0, 6, 0, 4), BackgroundTransparency = 1}, body)
    do
        local l = Instance.new("UIListLayout")
        l.FillDirection = Enum.FillDirection.Horizontal
        l.Padding = UDim.new(0, 4)
        l.Parent = tabbar
    end
    local holder = mk("Frame", {Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), BackgroundTransparency = 1}, body)

    local pages, tabBtns, builders, built = {}, {}, {}, {}
    local cur -- page yang sedang dibangun

    local function selectTab(name)
        for n, pg in pairs(pages) do
            local on = (n == name)
            pg.Visible = on
            tabBtns[n].TextColor3 = on and C.accent or C.sub
            tabBtns[n].BackgroundColor3 = on and C.row or C.bar
        end
        if not built[name] then
            built[name] = true
            cur = pages[name]
            builders[name]()
        end
    end

    for _, name in ipairs(TAB_NAMES) do
        local pg = mk("ScrollingFrame", {
            Size = UDim2.new(1, -8, 1, -4), Position = UDim2.new(0, 4, 0, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false,
        }, holder)
        do
            local l = Instance.new("UIListLayout")
            l.Padding = UDim.new(0, 4)
            l.SortOrder = Enum.SortOrder.LayoutOrder
            l.Parent = pg
            local pd = Instance.new("UIPadding")
            pd.PaddingLeft, pd.PaddingRight, pd.PaddingBottom = UDim.new(0, 2), UDim.new(0, 4), UDim.new(0, 6)
            pd.Parent = pg
        end
        pages[name] = pg

        local tb = mk("TextButton", {
            Size = UDim2.new(1 / #TAB_NAMES, -4, 1, 0), BackgroundColor3 = C.bar, Text = name,
            TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0, AutoButtonColor = false,
        }, tabbar)
        corner(tb, 6)
        tb.MouseButton1Click:Connect(function() selectTab(name) end)
        tabBtns[name] = tb
    end

    ----------------------------------------------------------
    -- KOMPONEN
    ----------------------------------------------------------
    local function section(text)
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = text, TextColor3 = C.accent,
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, cur)
    end

    local function toggle(label, key, onChange)
        local row = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = C.row, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        }, cur)
        corner(row)
        mk("TextLabel", {
            Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
            Text = label, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        local pill = mk("Frame", {Size = UDim2.new(0, 34, 0, 16), Position = UDim2.new(1, -44, 0.5, -8), BorderSizePixel = 0}, row)
        corner(pill, 8)
        local knob = mk("Frame", {Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, pill)
        corner(knob, 6)
        local function refresh()
            local on = State[key] and true or false
            pill.BackgroundColor3 = on and C.on or C.off
            knob.Position = UDim2.new(0, on and 20 or 2, 0, 2)
        end
        row.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            refresh()
            log("GUI", label .. " -> " .. (State[key] and "ON" or "OFF"))
            if onChange then pcall(onChange, State[key]) end
        end)
        refresh()
    end

    local function button(label, color, callback)
        local b = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = color or C.row, Text = label, TextColor3 = C.text,
            Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0,
        }, cur)
        corner(b)
        b.MouseButton1Click:Connect(function() pcall(callback, b) end)
        return b
    end

    local function numbox(label, cfgKey, minV, maxV, onSet)
        local box = mk("TextBox", {
            Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = C.row, TextColor3 = C.text,
            PlaceholderColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, BorderSizePixel = 0,
            ClearTextOnFocus = true, Text = label .. ": " .. tostring(Config[cfgKey]),
        }, cur)
        corner(box)
        box.FocusLost:Connect(function()
            local n = tonumber(string.match(box.Text, "-?[%d%.]+"))
            if n then
                Config[cfgKey] = math.clamp(n, minV, maxV)
                if onSet then pcall(onSet, Config[cfgKey]) end
                log("CFG", label .. " = " .. Config[cfgKey])
            end
            box.Text = label .. ": " .. tostring(Config[cfgKey])
        end)
    end

    ----------------------------------------------------------
    -- TAB: STEAL
    ----------------------------------------------------------
    builders["Steal"] = function()
        toggle("★ Auto Steal TP", "AutoStealTP", function(on)
            if on and not HomeCFrame then
                local hrp = getHRP()
                if hrp then
                    HomeCFrame = hrp.CFrame
                    log("BASE", "📍 Base otomatis di-set")
                end
            end
        end)
        button("📍 Set Base (berdiri di base!)", Color3.fromRGB(190, 115, 40), function(btn)
            local hrp = getHRP()
            if hrp then
                HomeCFrame = hrp.CFrame
                log("BASE", "📍 Base tersimpan")
                btn.Text = "✅ Base tersimpan!"
                task.wait(1)
                btn.Text = "📍 Set Base (berdiri di base!)"
            end
        end)
        button("🏠 Pulang ke Base", nil, function()
            local c = getChar()
            if HomeCFrame and c then
                c:PivotTo(HomeCFrame + Vector3.new(0, 3, 0))
            else
                log("TP", "⚠️ Base belum di-set")
            end
        end)
        button("▶ Steal TP Sekali", nil, function() task.spawn(doStealCycle) end)

        section("PENGATURAN")
        numbox("Radius Base", "HomeRadius", 10, 300)
        numbox("Jarak Maks Target", "MaxTargetDistance", 20, 1000)
        numbox("Jumlah Retry", "StealRetries", 1, 10)
        numbox("Kecepatan TP", "MoveStep", 4, 60)
        numbox("Jeda Siklus (dtk)", "DelayPerCycle", 0.1, 10)
        numbox("Blacklist (dtk)", "BlacklistTime", 5, 120)
        toggle("Fallback Semua Prompt", "FallbackAny", function(on) Config.FallbackAnyPrompt = on end)

        section("🕵️ ANTI ANOMALI")
        toggle("Mode Manusia (server lihat normal)", "HumanMode", function(on) Config.HumanMode = on end)
        numbox("Kecepatan Normal", "NormalMoveSpeed", 16, 200)

        section("MODE LAIN")
        toggle("Auto Steal (tanpa TP)", "AutoSteal")
        numbox("Range Auto Steal", "AutoStealRange", 5, 100)
        toggle("Instant Steal", "InstantSteal", function(on)
            if on then
                for o in pairs(PromptCache) do pcall(applyInstant, o) end
            end
        end)
        toggle("Auto Collect", "AutoCollect")
        numbox("Range Auto Collect", "AutoCollectRange", 5, 100)
    end

    ----------------------------------------------------------
    -- TAB: FILTER
    ----------------------------------------------------------
    builders["Filter"] = function()
        section("RARITY (kosong = semua)")
        for _, r in ipairs(Config.Rarities) do
            toggle(r, "R_" .. r, function(on)
                RaritySel[r] = on or nil
                local list = {}
                for _, name in ipairs(Config.Rarities) do
                    if RaritySel[name] then table.insert(list, name) end
                end
                log("GUI", "🎯 Rarity: " .. (#list > 0 and table.concat(list, ", ") or "SEMUA"))
            end)
        end
        section("KATA KUNCI")
        local fb = mk("TextBox", {
            Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = C.row, TextColor3 = C.text, PlaceholderColor3 = C.sub,
            PlaceholderText = "Filter nama: golden, secret...", Text = "", Font = Enum.Font.Gotham, TextSize = 12,
            BorderSizePixel = 0, ClearTextOnFocus = false,
        }, cur)
        corner(fb)
        fb.FocusLost:Connect(function()
            Config.RarityFilter = {}
            for word in string.gmatch(string.lower(fb.Text), "[^,%s]+") do
                table.insert(Config.RarityFilter, word)
            end
            log("GUI", "🎯 Filter: " .. (#Config.RarityFilter > 0 and table.concat(Config.RarityFilter, ", ") or "SEMUA"))
        end)
        toggle("Skip Prompt Hack", "SkipHack")
    end

    ----------------------------------------------------------
    -- TAB: PLAYER
    ----------------------------------------------------------
    builders["Player"] = function()
        toggle("WalkSpeed", "WalkSpeed", function(on)
            if not on then
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = 16 end
            end
        end)
        numbox("Nilai WalkSpeed", "WalkSpeedValue", 16, 500, function(v) Config.WalkSpeedValue = math.floor(v) end)
        toggle("Infinite Jump", "InfiniteJump")
        toggle("NoClip", "NoClip")
        toggle("Fly", "Fly")
        toggle("Anti Knockback", "AntiKnockback")
        toggle("Auto Reset ke Base Saat Respawn", "AutoRespawnBase")
        toggle("Anti AFK", "AntiAFK")
    end

    ----------------------------------------------------------
    -- TAB: MISC
    ----------------------------------------------------------
    builders["Misc"] = function()
        toggle("ESP Loot", "ESP")
        local Lighting = game:GetService("Lighting")
        local oldLight = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd}
        toggle("Fullbright", "Fullbright", function(on)
            if on then
                Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = 2, 14, 1e5
            else
                Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = oldLight.Brightness, oldLight.ClockTime, oldLight.FogEnd
            end
        end)
        button("🎯 TP ke Target Terdekat", nil, function()
            local _, part = findStealTarget()
            local c = getChar()
            if part and c then
                c:PivotTo(CFrame.new(part.Position + Vector3.new(0, 3, 0)))
            else
                log("TP", "⚠️ Tidak ada target")
            end
        end)
        button("🔍 Debug Prompts", nil, debugPrompts)
        button("💀 Reset Karakter", Color3.fromRGB(150, 60, 60), function()
            local h = getHumanoid()
            if h then h.Health = 0 end
        end)
        button("🔄 Rejoin Server", Color3.fromRGB(100, 70, 150), function()
            pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
        end)
        button("❌ Unload Script", C.danger, function()
            for k in pairs(State) do State[k] = false end
            espFolder:ClearAllChildren()
            gui:Destroy()
        end)
    end

    ----------------------------------------------------------
    -- TAB: LOG
    ----------------------------------------------------------
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
            task.wait(15)
            if #LogBuffer > 0 then saveLogFile() end
        end
    end)

    local webhookUrl = ""
    local function sendWebhook()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if webhookUrl == "" or not req then
            log("LOG", "⚠️ Isi URL webhook dulu / executor tidak support request")
            return
        end
        local text = "```\n" .. string.sub(table.concat(LogBuffer, "\n"), -1800) .. "\n```"
        local ok, err = pcall(function()
            req({
                Url = webhookUrl, Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = game:GetService("HttpService"):JSONEncode({content = text}),
            })
        end)
        log("LOG", ok and "Log terkirim ✅" or ("Gagal kirim: " .. tostring(err)))
    end

    builders["Log"] = function()
        logScroll = mk("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, isMobile and 110 or 150), BackgroundColor3 = Color3.fromRGB(12, 14, 20),
            BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
        }, cur)
        corner(logScroll)
        logLabel = mk("TextLabel", {
            Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(170, 240, 190), Font = Enum.Font.Code,
            TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Text = "",
        }, logScroll)
        refreshLog()

        button("📋 Copy Log", Color3.fromRGB(60, 95, 165), function()
            if setclipboard then
                setclipboard(table.concat(LogBuffer, "\n"))
                log("LOG", "Log disalin ✅")
            else
                log("LOG", "⚠️ Executor tidak support copy")
            end
        end)
        button("💾 Simpan ke File", Color3.fromRGB(45, 120, 95), function()
            log("LOG", saveLogFile() and ("Tersimpan: workspace/" .. LOG_FILE) or "⚠️ writefile tidak didukung")
        end)
        button("🗑 Clear", Color3.fromRGB(130, 55, 55), function()
            LogBuffer = {}
            refreshLog()
        end)
        local wh = mk("TextBox", {
            Size = UDim2.new(1, 0, 0, ROW), BackgroundColor3 = C.row, TextColor3 = C.text, PlaceholderColor3 = C.sub,
            PlaceholderText = "URL Webhook Discord (opsional)", Text = "", Font = Enum.Font.Gotham, TextSize = 11,
            BorderSizePixel = 0, ClearTextOnFocus = false,
        }, cur)
        corner(wh)
        wh.FocusLost:Connect(function() webhookUrl = wh.Text end)
        button("📨 Kirim ke Webhook", Color3.fromRGB(88, 101, 242), function()
            webhookUrl = wh.Text
            sendWebhook()
        end)
    end

    selectTab("Steal")

    ----------------------------------------------------------
    -- TOMBOL MELAYANG + TOGGLE KEY
    ----------------------------------------------------------
    local bubble = mk("TextButton", {
        Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 12, 0.4, 0), BackgroundColor3 = C.bar,
        Text = "⚔️", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = C.accent, BorderSizePixel = 0, Active = true,
    }, gui)
    corner(bubble, 22)
    makeDraggable(topbar, main)
    makeDraggable(bubble, bubble, function() main.Visible = not main.Visible end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Config.ToggleGUIKey then
            main.Visible = not main.Visible
        end
    end)
end

--==================================================
-- FITUR PENDUKUNG (loop ringan)
--==================================================

-- ESP: update tiap 3 dtk, maksimal 40 label
task.spawn(function()
    while true do
        task.wait(3)
        if State.ESP or #espFolder:GetChildren() > 0 then espFolder:ClearAllChildren() end
        if State.ESP then
            local n = 0
            for obj in pairs(PromptCache) do
                if n >= 40 then break end
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

LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if State.Fly then
        local hrp, hum = getHRP(), getHumanoid()
        if hrp and hum then
            local dir = hum.MoveDirection
            local vy = hum.Jump and 50 or 0
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * Config.WalkSpeedValue, vy, dir.Z * Config.WalkSpeedValue)
                + Vector3.new(0, 1.9, 0)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if State.AutoRespawnBase and HomeCFrame then
        task.wait(1)
        pcall(function() char:PivotTo(HomeCFrame + Vector3.new(0, 3, 0)) end)
    end
end)

-- tangkap error Roblox ke log (dibatasi 1 baris/detik)
local lastGameLog = 0
pcall(function()
    game:GetService("LogService").MessageOut:Connect(function(msg, mtype)
        if mtype == Enum.MessageType.MessageError or mtype == Enum.MessageType.MessageWarning then
            local now = tick()
            if now - lastGameLog < 1 then return end
            lastGameLog = now
            log(mtype == Enum.MessageType.MessageError and "ERR" or "WARN", string.sub(msg, 1, 160))
        end
    end)
end)

--==================================================
-- START
--==================================================
log("SYS", "Script v8 loaded ✅ " .. (UserInputService.TouchEnabled and "(MOBILE 📱)" or "(PC 🖥️)"))
task.spawn(function()
    task.wait(1.5)
    initBypass()
end)
