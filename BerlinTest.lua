--[[==============================================================
      BERLIN · 战斗自检   v1
      不猜、不试，直接用「动画轨道变化」判断攻击/格挡有没有真的触发。
      跑完把屏幕上的结果截图发我，一次定位所有问题。

      会自动做的事：
        1. 列出执行器 API 状态
        2. 找最近的 Model（NPC/玩家），报告距离
        3. 用 VirtualInputManager 点一次左键，比对动画轨道
        4. 用 VirtualInputManager 按一次 F，比对动画轨道
        5. 用 keypress 再各试一次（对比两种通道）
==============================================================]]--

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

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

-- ===== UI =====
local pg = LP:FindFirstChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "T_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okp or not gui.Parent then
    gui.Parent = pg or LP:WaitForChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.92, 0, 0.82, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(8, 16, 34)
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.Parent = gui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 170, 255)
    s.Thickness = 1.5; s.Transparency = 0.3; s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.Text = "Berlin 战斗自检"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -90)
scroll.Position = UDim2.new(0, 10, 0, 48)
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

local order = 0
local function line(text, color)
    order = order + 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 0, 20)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.TextColor3 = color or Color3.fromRGB(205, 225, 250)
    l.Text = " " .. text
    l.LayoutOrder = order
    l.Parent = scroll
    print("[TEST] " .. text)
    return l
end

local function ok(t) line("✅ " .. t, Color3.fromRGB(120, 240, 180)) end
local function bad(t) line("❌ " .. t, Color3.fromRGB(255, 140, 140)) end
local function info(t) line("• " .. t, Color3.fromRGB(190, 210, 240)) end

-- ===== 工具 =====
local function char()
    local c = LP.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if h and r then return c, h, r end
    return nil
end

local function trackNames()
    local seen = {}
    local _, h = char()
    if not h then return seen end
    local an = h:FindFirstChildOfClass("Animator")
    if not an then return seen end
    local ok2, tracks = pcall(function() return an:GetPlayingAnimationTracks() end)
    if ok2 and tracks then
        for _, t in ipairs(tracks) do
            seen[string.lower(t.Name)] = true
        end
    end
    return seen
end

local function diff(before, after)
    local added = {}
    for k in pairs(after) do
        if not before[k] then table.insert(added, k) end
    end
    return added
end

local function watchAnimation(duration)
    local before = trackNames()
    return function()
        task.wait(duration or 0.35)
        local after = trackNames()
        return diff(before, after)
    end
end

-- ===== 开始 =====
task.wait(2)

local c, h, r = char()
if not c then
    bad("角色没加载，先重进游戏")
    return
end

-- 1. API
info("===== 1. 执行器 =====")
for _, n in ipairs({ "hookmetamethod", "getconnections", "mouse1click", "keypress", "protect_gui" }) do
    if api(n) then ok(n) else bad(n .. " 缺失") end
end

-- 2. 附近目标
info("===== 2. 附近目标 =====")
local myPos = r.Position
local targets = {}
for _, obj in ipairs(workspace:GetChildren()) do
    if obj:IsA("Model") and obj ~= c then
        local th = obj:FindFirstChildOfClass("Humanoid")
        local tr = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
        if th and tr and th.Health > 0 then
            local d = (tr.Position - myPos).Magnitude
            if d < 200 then
                table.insert(targets, {
                    name = obj.Name, dist = d,
                    isPlayer = Players:GetPlayerFromCharacter(obj) ~= nil,
                })
            end
        end
    end
end
table.sort(targets, function(a, b) return a.dist < b.dist end)
if #targets == 0 then
    bad("200 格内没有任何角色，先跑到有人/怪的地方")
else
    for i = 1, math.min(#targets, 5) do
        local t = targets[i]
        info(string.format("%d. %s  %.1f 格  %s", i, t.name, t.dist, t.isPlayer and "玩家" or "NPC"))
    end
end

-- 3. 鼠标左键（VIM）
info("===== 3. 攻击测试 A：VIM 左键 =====")
local cam = workspace.CurrentCamera
local vp = cam.ViewportSize
local checkA = watchAnimation(0.4)
pcall(function()
    VIM:SendMouseButtonEvent(vp.X * 0.5, vp.Y * 0.42, 0, true, game, 0)
end)
task.wait(0.05)
pcall(function()
    VIM:SendMouseButtonEvent(vp.X * 0.5, vp.Y * 0.42, 0, false, game, 0)
end)
local addedA = checkA()
if #addedA > 0 then
    ok("出动作了：" .. table.concat(addedA, ", "))
else
    bad("没有任何动画变化")
end

task.wait(0.6)

-- 4. 键盘 G（VIM）
info("===== 4. 攻击测试 B：VIM 按 G =====")
local checkB = watchAnimation(0.4)
pcall(function()
    VIM:SendKeyEvent(true, Enum.KeyCode.G, false, game)
end)
task.wait(0.05)
pcall(function()
    VIM:SendKeyEvent(false, Enum.KeyCode.G, false, game)
end)
local addedB = checkB()
if #addedB > 0 then
    ok("出动作了：" .. table.concat(addedB, ", "))
else
    bad("G 键没有动画变化")
end

task.wait(0.6)

-- 5. 键盘 G（keypress）
info("===== 5. 攻击测试 C：keypress G =====")
local kp = api("keypress")
local kr = api("keyrelease")
if kp then
    local checkC = watchAnimation(0.4)
    pcall(kp, "g")
    task.wait(0.08)
    if kr then pcall(kr, "g") end
    local addedC = checkC()
    if #addedC > 0 then
        ok("出动作了：" .. table.concat(addedC, ", "))
    else
        bad("keypress 没有动画变化")
    end
else
    bad("没有 keypress")
end

task.wait(0.6)

-- 6. 格挡 F
info("===== 6. 格挡测试：VIM 按 F =====")
local checkD = watchAnimation(0.4)
pcall(function()
    VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
end)
task.wait(0.12)
pcall(function()
    VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
end)
local addedD = checkD()
if #addedD > 0 then
    ok("格挡动作：" .. table.concat(addedD, ", "))
else
    bad("F 没有动画变化")
end

-- 7. 现有动画清单
info("===== 7. 当前动画轨道 =====")
local now = trackNames()
local n = 0
for k in pairs(now) do
    n = n + 1
    if n <= 12 then info("  " .. k) end
end
if n == 0 then info("（当前没有正在播放的动画）") end

title.Text = "自检完成 · 把这块截图发我"
