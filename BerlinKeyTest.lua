--[[==============================================================
      BERLIN · 按键盲测
      背景：上一轮自检证明「鼠标注入有效、键盘注入无效」。
            这个脚本把鼠标三个键 + 常用按键全部试一遍，
            用动画轨道变化判断哪个真的能被游戏接收。

      注意：请站在室外空地再跑（教室/音乐室会禁用战斗动作）。
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
    return nil
end

-- ===== UI =====
local pg = LP:FindFirstChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "K_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okp or not gui.Parent then
    gui.Parent = pg or LP:WaitForChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.9, 0, 0.8, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(8, 16, 34)
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
title.TextSize = 14
title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.Text = "按键盲测 · 3 秒后开始，请站到室外空地"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -96)
scroll.Position = UDim2.new(0, 10, 0, 54)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 150, 240)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 3)
layout.Parent = scroll

local order = 0
local function row(text, color)
    order = order + 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -6, 0, 22)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.TextColor3 = color or Color3.fromRGB(205, 225, 250)
    l.Text = " " .. text
    l.LayoutOrder = order
    l.Parent = scroll
    print("[KEYTEST] " .. text)
    return l
end

-- ===== 工具 =====
local function char()
    local c = LP.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if h and r then return c, h, r end
    return nil
end

local function tracks()
    local set = {}
    local _, h = char()
    if not h then return set end
    local an = h:FindFirstChildOfClass("Animator")
    if not an then return set end
    local ok2, list = pcall(function() return an:GetPlayingAnimationTracks() end)
    if ok2 and list then
        for _, t in ipairs(list) do set[string.lower(t.Name)] = true end
    end
    return set
end

local function watch(sec)
    local before = tracks()
    task.wait(sec or 0.45)
    local after = tracks()
    local added = {}
    for k in pairs(after) do
        if not before[k] then table.insert(added, k) end
    end
    return added
end

-- ===== 测试项 =====
local CAM = workspace.CurrentCamera
local function vp()
    local c = workspace.CurrentCamera or CAM
    return c and c.ViewportSize or Vector2.new(1280, 720)
end

local function mouseClick(btn)
    local size = vp()
    local x, y = size.X * 0.5, size.Y * 0.45
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, btn, true, game, 0)
    end)
    task.wait(0.04)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, btn, false, game, 0)
    end)
end

local function keyPress(kc)
    pcall(function()
        VIM:SendKeyEvent(true, kc, false, game)
    end)
    task.wait(0.08)
    pcall(function()
        VIM:SendKeyEvent(false, kc, false, game)
    end)
end

local TESTS = {
    { label = "鼠标左键 (M1)",  kind = "mouse", v = 0 },
    { label = "鼠标右键 (M2)",  kind = "mouse", v = 1 },
    { label = "鼠标中键",       kind = "mouse", v = 2 },
    { label = "键盘 F",         kind = "key",   v = Enum.KeyCode.F },
    { label = "键盘 Q",         kind = "key",   v = Enum.KeyCode.Q },
    { label = "键盘 G",         kind = "key",   v = Enum.KeyCode.G },
    { label = "键盘 R",         kind = "key",   v = Enum.KeyCode.R },
    { label = "键盘 E",         kind = "key",   v = Enum.KeyCode.E },
    { label = "键盘 左Shift",   kind = "key",   v = Enum.KeyCode.LeftShift },
    { label = "键盘 空格",      kind = "key",   v = Enum.KeyCode.Space },
    { label = "键盘 T",         kind = "key",   v = Enum.KeyCode.T },
    { label = "键盘 V",         kind = "key",   v = Enum.KeyCode.V },
    { label = "键盘 C",         kind = "key",   v = Enum.KeyCode.C },
    { label = "键盘 1",         kind = "key",   v = Enum.KeyCode.One },
}

task.wait(3)

local c, h, r = char()
if not c then
    row("角色没加载", Color3.fromRGB(255, 140, 140))
    return
end

row("开始测试，每项 0.45 秒…", Color3.fromRGB(150, 200, 255))
task.wait(0.5)

local good = {}
for _, t in ipairs(TESTS) do
    title.Text = "测试中：" .. t.label
    if t.kind == "mouse" then
        local added
        local before = tracks()
        mouseClick(t.v)
        added = watch(0.45)
        if #added > 0 then
            row(string.format("✅ %-14s → %s", t.label, table.concat(added, ",")), Color3.fromRGB(120, 240, 180))
            table.insert(good, t.label)
        else
            row(string.format("❌ %-14s → 无变化", t.label), Color3.fromRGB(140, 155, 180))
        end
    else
        local before = tracks()
        keyPress(t.v)
        local added = watch(0.45)
        if #added > 0 then
            row(string.format("✅ %-14s → %s", t.label, table.concat(added, ",")), Color3.fromRGB(120, 240, 180))
            table.insert(good, t.label)
        else
            row(string.format("❌ %-14s → 无变化", t.label), Color3.fromRGB(140, 155, 180))
        end
    end
    task.wait(0.25)
end

task.wait(0.3)
if #good > 0 then
    title.Text = "完成 · 有效输入：" .. table.concat(good, " / ")
    row("有效：" .. table.concat(good, "、"), Color3.fromRGB(160, 255, 200))
else
    title.Text = "完成 · 全部无效"
    row("全部无效（先确认站在室外、且不在过场/死亡状态）", Color3.fromRGB(255, 160, 160))
end
