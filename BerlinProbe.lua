--[[==============================================================
      BERLIN · PROBE  反作弊探针 v1
      作用：逐项测试 Gakuran 服务端到底在监控什么，
            被踢时屏幕上会停在触发的那一步。
      用法：进游戏 → 执行本脚本 → 看顶部蓝色提示条。
            注意：会被踢，属正常。每次只测一项，记下停在第几步。
==============================================================]]--

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

-- ===== 屏幕提示条 =====
local pg = LP:FindFirstChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "P_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not ok or not gui.Parent then
    gui.Parent = pg or LP:WaitForChild("PlayerGui")
end

local box = Instance.new("Frame")
box.Size = UDim2.new(1, 0, 0, 110)
box.Position = UDim2.new(0, 0, 0, 70)
box.BackgroundColor3 = Color3.fromRGB(8, 18, 38)
box.BackgroundTransparency = 0.12
box.BorderSizePixel = 0
box.Parent = gui
pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 14)
    c.Parent = box
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(90, 170, 255)
    s.Thickness = 1.5
    s.Parent = box
end)

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -24, 1, -24)
lbl.Position = UDim2.new(0, 12, 0, 12)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 20
lbl.TextWrapped = true
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextColor3 = Color3.fromRGB(150, 215, 255)
lbl.Text = "Berlin 探针 · 准备中"
lbl.Parent = box

local function say(t)
    lbl.Text = t
    print("[PROBE] " .. t)
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

local function clearBV()
    local c = char()
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v.Name == "ProbeBV" then
            pcall(function() v:Destroy() end)
        end
    end
end

local function attachBV(vel)
    local c, h, r = char()
    if not c then return nil end
    clearBV()
    local bv = Instance.new("BodyVelocity")
    bv.Name = "ProbeBV"
    bv.MaxForce = Vector3.new(1, 1, 1) * 1e6
    bv.Velocity = vel
    bv.Parent = r
    return bv
end

local function countdown(sec, prefix)
    for i = sec, 1, -1 do
        say(prefix .. "\n剩余 " .. i .. " 秒（被踢就停在这一步）")
        task.wait(1)
    end
end

-- ===== 开始 =====
task.wait(3)

say("探针启动：本次会依次测试 4 项，约 40 秒。\n如果被踢，重进游戏告诉我停在第几步。")
task.wait(3)

-- ---------- 1 ----------
local c1, h1 = char()
say("【第 1 步 / 4】设置 PlatformStand = true\n如果被踢 → 服务端监控这个属性（那飞行就别用标准模式）")
task.wait(2)
if h1 then
    pcall(function() h1.PlatformStand = true end)
end
countdown(5, "第 1 步进行中：PlatformStand = true")
local _, h1b = char()
if h1b then pcall(function() h1b.PlatformStand = false end) end
say("✅ 第 1 步通过：PlatformStand 不踢")
task.wait(3)

-- ---------- 2 ----------
local y0 = 0
do
    local _, _, r0 = char()
    if r0 then y0 = r0.Position.Y end
end
say("【第 2 步 / 4】缓慢垂直上升到 +12 格\n如果被踢 → 服务端查 Y 坐标（低空也飞不了）")
task.wait(2)
local bv2 = attachBV(Vector3.new(0, 12, 0))
countdown(5, "第 2 步进行中：垂直上升 +12")
clearBV()
local _, _, r2 = char()
local dy = r2 and math.floor(r2.Position.Y - y0) or 0
say("✅ 第 2 步通过：升高 " .. dy .. " 格没被踢")
task.wait(3)

-- ---------- 3 ----------
say("【第 3 步 / 4】水平速度 40 格/秒（不改 WalkSpeed）\n如果被踢 → 服务端查移动速度")
task.wait(2)
local bv3 = attachBV(Vector3.new(40, 0, 0))
countdown(5, "第 3 步进行中：水平 40 速度")
clearBV()
say("✅ 第 3 步通过：水平 40 速度不踢")
task.wait(3)

-- ---------- 4 ----------
local y4 = 0
do
    local _, _, r4 = char()
    if r4 then y4 = r4.Position.Y end
end
say("【第 4 步 / 4】快速升到 +60 格\n如果被踢 → 高空被检测（只能低空）")
task.wait(2)
local bv4 = attachBV(Vector3.new(0, 55, 0))
countdown(5, "第 4 步进行中：高空 +60")
clearBV()
local _, _, r4b = char()
local dy4 = r4b and math.floor(r4b.Position.Y - y4) or 0
say("✅ 第 4 步通过：升高 " .. dy4 .. " 格不踢")

task.wait(2)
say("=== 全部通过 ===\n结论：服务端没在做位置/状态检测，只是你之前的 PlatformStand 太明显。\n用「隐」模式 + 低空即可。")

-- 收尾：清理
task.wait(25)
pcall(function() gui:Destroy() end)
