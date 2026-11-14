--[[==============================================================
      BERLIN · PROBE 2   分离检测点
      A：放一个静态 BodyVelocity（速度为 0，人不动）
         → 被踢 = 游戏在扫角色里的 BodyMover 实例
      B：用 ApplyImpulse 上升到 +15（角色里没有任何实例）
         → 被踢 = 游戏在查 Y 坐标 / 离地高度
      C：把 JumpPower 提到 130 跳一次
         → 被踢 = 游戏在查跳跃力度
      每一步之间会先落回地面再继续。
==============================================================]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

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
box.Size = UDim2.new(1, 0, 0, 120)
box.Position = UDim2.new(0, 0, 0, 70)
box.BackgroundColor3 = Color3.fromRGB(8, 18, 38)
box.BackgroundTransparency = 0.1
box.BorderSizePixel = 0
box.Parent = gui
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = box
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 170, 255); s.Thickness = 1.5; s.Parent = box
end)

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -24, 1, -24)
lbl.Position = UDim2.new(0, 12, 0, 12)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 19
lbl.TextWrapped = true
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextColor3 = Color3.fromRGB(150, 215, 255)
lbl.Text = "Berlin 探针 2 · 准备中"
lbl.Parent = box

local function say(t)
    lbl.Text = t
    print("[PROBE2] " .. t)
end

local function char()
    local c = LP.Character
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if h and r then return c, h, r end
    return nil
end

local function waitGround()
    for i = 1, 20 do
        local _, h = char()
        if h and h.FloorMaterial ~= Enum.Material.Air then return true end
        task.wait(0.5)
    end
    return false
end

local function count(sec, prefix)
    for i = sec, 1, -1 do
        say(prefix .. "\n剩余 " .. i .. " 秒")
        task.wait(1)
    end
end

task.wait(3)
say("探针 2 启动：三步，约 40 秒。\n被踢就记住最后一个显示的是第几步。")
task.wait(3)
waitGround()

--------------------------------------------------------------------
-- A：静态 BodyVelocity
--------------------------------------------------------------------
say("【A / 3】角色里放一个 BodyVelocity，速度为 0，人完全不动\n如果被踢 → 游戏在扫 BodyMover 实例（用冲量就能绕过）")
task.wait(3)
do
    local c, h, r = char()
    if r then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "BodyVelocity"
        bv.MaxForce = Vector3.new(1, 1, 1) * 1e6
        bv.Velocity = Vector3.zero
        bv.Parent = r
        count(6, "A 进行中：静态 BodyVelocity")
        pcall(function() bv:Destroy() end)
    end
end
say("✅ A 通过：角色里放 BodyVelocity 不踢")
task.wait(3)

--------------------------------------------------------------------
-- B：ApplyImpulse 上升
--------------------------------------------------------------------
say("【B / 3】用冲量升到 +15 格（角色里没有任何实例）\n如果被踢 → 游戏在查 Y 坐标 / 离地高度")
task.wait(3)
do
    local c, h, r = char()
    if r then
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local cc = LP.Character
            local rr = cc and cc:FindFirstChild("HumanoidRootPart")
            if not rr then return end
            local targetVel = Vector3.new(0, 22, 0)
            local d = targetVel - rr.AssemblyLinearVelocity
            local m = rr.AssemblyMass
            if m and m > 0 then
                rr:ApplyImpulse(d * m)
            end
        end)
        count(4, "B 进行中：冲量上升")
        if conn then conn:Disconnect() end
    end
end
say("✅ B 通过：冲量升空不踢（说明服务端不查高度）")
task.wait(2)
waitGround()

--------------------------------------------------------------------
-- C：JumpPower
--------------------------------------------------------------------
say("【C / 3】JumpPower 提到 130，跳一次\n如果被踢 → 游戏在查跳跃力度")
task.wait(3)
do
    local c, h = char()
    if h then
        local old = h.JumpPower
        h.JumpPower = 130
        task.wait(0.3)
        h.Jump = true
        count(5, "C 进行中：JumpPower = 130")
        pcall(function() h.JumpPower = old end)
    end
end
say("✅ C 通过：改跳跃力不踢")

task.wait(2)
say("=== 全部通过 ===\n结论：A/B/C 都不触发检测，之前是 PlatformStand 或速度峰值的问题。")
task.wait(20)
pcall(function() gui:Destroy() end)
