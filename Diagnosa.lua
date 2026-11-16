--[[ =========================================================
     DIAGNOSA REMOTE - Build to Defend Loot
     Jalankan sekali, copy outputnya, kirim ke saya
     Load: loadstring(game:HttpGet(".../Diagnosa.lua"))()
========================================================= ]]

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

print("=== STRUKTUR ReplicatedStorage ===")
for _, v in ipairs(RS:GetChildren()) do
    print("  ", v.Name, "("..v.ClassName..")")
end

print("\n=== STRUKTUR endpoints ===")
local ep = RS:FindFirstChild("endpoints")
if ep then
    local function dump(obj, indent)
        for _, child in ipairs(obj:GetChildren()) do
            print(indent .. child.Name .. " ("..child.ClassName..")")
            if child:IsA("Folder") or child:IsA("Configuration") then
                dump(child, indent .. "  ")
            end
        end
    end
    dump(ep, "  ")
else
    print("  endpoints TIDAK ADA")
end

print("\n=== INTERACTABLES REMOTE ===")
local inter = RS:FindFirstChild("endpoints") and RS.endpoints:FindFirstChild("Interactables")
if inter then
    print("  Nama:", inter.Name, "| Class:", inter.ClassName)
    print("  Path:", inter:GetFullName())
    pcall(function()
        local mt = getmetatable(inter)
        if mt then
            for k, v in pairs(mt) do
                print("  [meta]", k, typeof(v))
            end
        end
    end)
else
    print("  Interactables TIDAK ADA")
end

print("\n=== SCAN OBJECT YANG PUNYA ID DI WORKSPACE (radius 200) ===")
local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        local pos
        if obj:IsA("BasePart") then pos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
        if pos and (pos - hrp.Position).Magnitude <= 200 then
            for _, attr in ipairs(obj:GetAttributes()) do
                local val = obj:GetAttribute(attr)
                print("  [ATTR]", obj:GetFullName(), "|", attr, "=", tostring(val))
                count = count + 1
            end
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") then
                    local ln = child.Name:lower()
                    if ln:find("id") or ln:find("interact") or ln:find("steal") then
                        print("  [VALUE]", child:GetFullName(), "=", tostring(child.Value))
                        count = count + 1
                    end
                end
            end
        end
    end
    print("  Total kandidat ID:", count)
else
    print("  Character/HRP tidak ada")
end

print("\n=== DONE ===")
