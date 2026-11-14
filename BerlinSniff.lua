--[[==============================================================
      BERLIN · 能力探测 + Remote 嗅探   v2
      1. 先列出你的执行器到底支持哪些 API
      2. 用三种方式尝试挂 hook（hookmetamethod / rawmetatable / hookfunction）
      3. 挂上之后记录所有 FireServer 调用和参数
==============================================================]]--

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

-- ===== 通用 API 探测 =====
local function api(name)
    local ok, v = pcall(function() return getfenv(0)[name] end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return getgenv()[name] end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return _G[name] end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return rawget(_G, name) end)
    if ok and v ~= nil then return v end
    return nil
end

local CAPS = {
    "hookmetamethod", "getnamecallmethod", "hookfunction", "replaceclosure",
    "getrawmetatable", "setreadonly", "isreadonly", "newcclosure", "checkcaller",
    "getconnections", "firesignal", "getgenv", "getrenv", "getgc",
    "getinstances", "gethui", "protect_gui", "identifyexecutor",
    "mouse1click", "keypress", "setclipboard", "readfile", "writefile", "isfile",
    "request", "http", "setthreadidentity", "getscriptclosure",
}

local supported, missing = {}, {}
for _, n in ipairs(CAPS) do
    if api(n) then table.insert(supported, n) else table.insert(missing, n) end
end

-- ===== 界面 =====
local pg = LP:FindFirstChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "N_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not ok or not gui.Parent then
    gui.Parent = pg or LP:WaitForChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.92, 0, 0.76, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Parent = gui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 170, 255)
    s.Thickness = 1.5; s.Transparency = 0.3; s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 46)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.Text = "检测中…"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -96)
scroll.Position = UDim2.new(0, 10, 0, 54)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 150, 240)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = scroll

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 34)
footer.Position = UDim2.new(0, 10, 1, -38)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextColor3 = Color3.fromRGB(150, 185, 225)
footer.Text = "正在检测执行器能力…"
footer.Parent = panel

local function row(text, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 0, 20)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = color or Color3.fromRGB(200, 220, 245)
    l.Text = " " .. text
    l.Parent = scroll
    return l
end

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        if #v > 32 then v = v:sub(1, 32) .. "…" end
        return '"' .. v .. '"'
    elseif t == "number" then
        return tostring(math.floor(v * 100) / 100)
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Vector3" then
        return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
    elseif t == "Instance" then
        return v.Name
    elseif t == "table" and depth < 2 then
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 5 then break end
            table.insert(parts, tostring(k) .. "=" .. ser(vv, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

-- ===== 显示能力 =====
title.Text = string.format("执行器能力：%d 项可用 / %d 项缺失", #supported, #missing)
row("== 可用 ==", Color3.fromRGB(120, 240, 180))
row(table.concat(supported, ", "), Color3.fromRGB(150, 225, 250))
row("== 缺失 ==", Color3.fromRGB(255, 150, 150))
row(table.concat(missing, ", "), Color3.fromRGB(230, 170, 170))

print("[CAPS] supported: " .. table.concat(supported, ","))
print("[CAPS] missing:   " .. table.concat(missing, ","))

-- ===== 记录 =====
local records = {}

local function addRecord(remote, args)
    local name = remote:GetFullName()
    local parts = {}
    for i = 1, #args do parts[i] = ser(args[i]) end
    local argStr = #parts > 0 and table.concat(parts, ", ") or "<无参数>"

    table.insert(records, 1, { name = name, args = argStr })
    if #records > 30 then table.remove(records, 31) end

    row(name .. "  |  " .. argStr, Color3.fromRGB(190, 230, 255))
    print(string.format("[SNIFF] %s | %s", name, argStr))
    title.Text = string.format("已记录 %d 条 · 最近：%s", #records, remote.Name)
end

-- ===== 三种 hook 方案 =====
local hooked = false

-- 方案 1：hookmetamethod
do
    local hookmm = api("hookmetamethod")
    local getncm = api("getnamecallmethod")
    if type(hookmm) == "function" and type(getncm) == "function" then
        local ok1 = pcall(function()
            local old
            local function handler(self, ...)
                local m = getncm()
                if m == "FireServer" then
                    local isR = false
                    pcall(function()
                        isR = self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")
                    end)
                    if isR then pcall(addRecord, self, { ... }) end
                end
                return old(self, ...)
            end
            old = hookmm(game, "__namecall", handler)
        end)
        if ok1 then
            hooked = true
            row("✅ 已用 hookmetamethod 挂上", Color3.fromRGB(120, 240, 180))
        else
            row("✗ hookmetamethod 存在但调用失败", Color3.fromRGB(255, 150, 150))
        end
    else
        row("✗ 没有 hookmetamethod", Color3.fromRGB(255, 150, 150))
    end
end

-- 方案 2：直接改 __namecall
if not hooked then
    local grm = api("getrawmetatable")
    local sro = api("setreadonly")
    local ncc = api("newcclosure")
    if type(grm) == "function" and type(sro) == "function" then
        local ok2 = pcall(function()
            local mt = grm(game)
            sro(mt, false)
            local old = mt.__namecall
            local function handler(self, ...)
                local m = getnamecallmethod and getnamecallmethod() or nil
                if m == "FireServer" then
                    local isR = false
                    pcall(function()
                        isR = self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")
                    end)
                    if isR then pcall(addRecord, self, { ... }) end
                end
                return old(self, ...)
            end
            if type(ncc) == "function" then handler = ncc(handler) end
            mt.__namecall = handler
            sro(mt, true)
        end)
        if ok2 then
            hooked = true
            row("✅ 已用 getrawmetatable 改 __namecall", Color3.fromRGB(120, 240, 180))
        else
            row("✗ getrawmetatable 路径失败", Color3.fromRGB(255, 150, 150))
        end
    else
        row("✗ 没有 getrawmetatable / setreadonly", Color3.fromRGB(255, 150, 150))
    end
end

-- 方案 3：hookfunction 打 RemoteEvent 的 FireServer 方法
if not hooked then
    local hookf = api("hookfunction")
    if type(hookf) == "function" then
        local ok3 = pcall(function()
            local re = Instance.new("RemoteEvent")
            local oldFire = re.FireServer
            hookf(oldFire, function(self, ...)
                pcall(addRecord, self, { ... })
                return oldFire(self, ...)
            end)
            re:Destroy()
        end)
        if ok3 then
            hooked = true
            row("✅ 已用 hookfunction 打 FireServer", Color3.fromRGB(120, 240, 180))
        else
            row("✗ hookfunction 路径失败", Color3.fromRGB(255, 150, 150))
        end
    else
        row("✗ 没有 hookfunction", Color3.fromRGB(255, 150, 150))
    end
end

if hooked then
    footer.Text = "去游戏里手动打一拳 / 格挡 / 闪避，列表会实时记录"
else
    footer.Text = "三条 hook 路径都失败，请把上面【可用】那一行截图发我"
end

-- ===== 兜底：列出所有 Remote =====
task.spawn(function()
    task.wait(2)
    local list = {}
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") or d:IsA("RemoteFunction") then
            table.insert(list, d:GetFullName())
        end
    end
    print("[SNIFF] 共 " .. #list .. " 个 Remote")
    for i, n in ipairs(list) do
        if i > 100 then break end
        print("  " .. n)
    end
end)
