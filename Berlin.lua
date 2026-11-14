--[[==============================================================
      B E R L I N   ·  Mobile Edition  v2.0  (Stealth Build)
      适用     : Roblox《学乱》Gakuran
                 PlaceId 128736949265057 / 9199655655
      执行器   : Delta Mobile / Fluxus Mobile / 支持
                 VirtualInputManager + getconnections 的手机执行器
      功能     : 智能防御 · 飞天 · 透视 · 加速 · 无限体力 · AI 自动战斗
      防封设计 : ① 人类化抖动（间隔/招架成功率/走速微波动）
                 ② 有人观察自动降级  ③ 可疑玩家监听
                 ④ 会话时限提醒      ⑤ 低调模式 + 限高限速
                 ⑥ 双飞行模式（低可观测）
                 ⑦ 长按悬浮球 1 秒急停还原
                 ⑧ UI 随机命名，不留固定特征
      说明     : 纯客户端脚本，只改本机表现与输入模拟。
==============================================================]]--

--------------------------------------------------------------
-- 0. 环境
--------------------------------------------------------------
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- 平台判定：PC 端走键鼠，手机端走屏幕按钮
local IS_PC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local IS_TOUCH_ONLY = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- 执行器 API 探测：不同执行器（YuB-X / Delta / Wave / Fluxus…）暴露位置不一样，
-- 只认 rawget(getfenv(0), …) 会在部分执行器上全部拿到 nil。
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

local nativeClick = api("mouse1click")
local nativePress = api("keypress")
local nativeRelease = api("keyrelease")

local rawGetConnections = api("getconnections")

local function safeGetConnections(signal)
    if not rawGetConnections then return nil end
    local ok, res = pcall(rawGetConnections, signal)
    if ok then return res end
    return nil
end

--------------------------------------------------------------
-- 1. 主题
--------------------------------------------------------------
local C = {
    glass    = Color3.fromRGB(18, 38, 76),
    card     = Color3.fromRGB(24, 52, 100),
    card2    = Color3.fromRGB(18, 40, 80),
    stroke   = Color3.fromRGB(96, 170, 255),
    accent   = Color3.fromRGB(56, 138, 255),
    accentHi = Color3.fromRGB(130, 200, 255),
    text     = Color3.fromRGB(234, 244, 255),
    dim      = Color3.fromRGB(148, 180, 220),
    ok       = Color3.fromRGB(72, 224, 168),
    off      = Color3.fromRGB(62, 84, 120),
    danger   = Color3.fromRGB(255, 98, 110),
    warn     = Color3.fromRGB(255, 190, 80),
}
local FONT   = Enum.Font.GothamMedium
local FONT_B = Enum.Font.GothamBold

--------------------------------------------------------------
-- 2. 实例工具
--------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then o[k] = v end
        end
    end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 12)
    c.Parent = o
    return c
end

local function stroke(o, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.stroke
    s.Thickness = th or 1
    s.Transparency = tr or 0.45
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o
    return s
end

local function pad(o, l, t, r, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = o
    return p
end

local function vlist(o, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Padding = UDim.new(0, gap or 8)
    l.Parent = o
    return l
end

local function hlist(o, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, gap or 6)
    l.Parent = o
    return l
end

local function tween(o, t, props)
    local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function guiParent()
    local ok, h = pcall(function()
        if gethui then return gethui() end
        return nil
    end)
    if ok and h then return h end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

local function getHum()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function hasAny(s, list)
    for _, k in ipairs(list) do
        if string.find(s, k, 1, true) then return true end
    end
    return false
end

--------------------------------------------------------------
-- 3. 配置 + 安全档位
--------------------------------------------------------------
-- 三档防封强度：数值越保守越不容易被察觉
local PROFILES = {
    ["稳健"] = { maxWalk = 1.6, maxFly = 40,  parryRate = 0.78, maxHeight = 55,  gapScale = 1.25 },
    ["平衡"] = { maxWalk = 2.0, maxFly = 60,  parryRate = 0.88, maxHeight = 95,  gapScale = 1.05 },
    ["激进"] = { maxWalk = 3.0, maxFly = 120, parryRate = 0.97, maxHeight = 400, gapScale = 0.90 },
}

local CFG = {
    -- 机动
    fly = false, flySpeed = 45, flyLift = 0, flyForward = false, flyMode = "隐", flyMaxHeight = 25,
    flyEngine = "冲量",
    speedOn = false, speedMul = 1.8,

    -- 战斗
    defense = false, defMode = "智能", defLead = 0.10, defRange = 22, parryRate = 0.88,
    combat = "OFF", atkGap = 0.34, atkMode = "自动", chaseRange = 90,

    -- 辅助
    stamina = false, stealth = false,

    -- 防封
    profile = "平衡",
    humanize = true,
    watchPause = true,
    adminWatch = true,
    sessionGuard = true,

    -- 透视
    espPlayer = false, espNPC = false, espDrop = false,
    espDist = true, espHealth = true, espRange = 400,

    -- 运行时状态
    watched = false, watchers = 0, flagged = nil, sessionStart = os.clock(),
}

local BASE_WALK = 16

local function prof()
    return PROFILES[CFG.profile] or PROFILES["平衡"]
end

-- 前向声明（Lua 词法作用域：必须在使用它的函数定义之前声明）
local refreshers = {}
local selectorRefreshers = {}
local statusLabel, ball, doPanic

--------------------------------------------------------------
-- 4. 输入模拟
--------------------------------------------------------------
local function pressKey(k, holdSec)
    -- 执行器原生 keypress 优先，其次 VirtualInputManager
    if nativePress and IS_PC then
        local name = k.Name
        if pcall(nativePress, name) then
            task.delay(holdSec or 0.06, function()
                if nativeRelease then pcall(nativeRelease, name) end
            end)
            return
        end
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, k, false, game)
    end)
    task.delay(holdSec or 0.06, function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, k, false, game)
        end)
    end)
end

local function clickCenter()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    -- PC：原生 mouse1click 最稳
    if IS_PC and nativeClick then
        if pcall(nativeClick) then return end
    end

    -- 点击位置做 ±8% 抖动，避免每次都是固定点
    -- PC 上取偏上区域（40%），避开底部的血条/快捷栏 UI
    local jx = (math.random() - 0.5) * 0.16
    local jy = (math.random() - 0.5) * 0.16
    local x = vp.X * (0.5 + jx)
    local y = vp.Y * ((IS_PC and 0.42 or 0.5) + jy)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    end)
    task.delay(0.03, function()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end)
end

local buttonCache, buttonCacheTime = {}, 0

local function findButtons(keys, maxCount, useCache)
    local now = os.clock()
    local key = table.concat(keys, "|")
    if useCache and buttonCache[key] and now - buttonCacheTime < 2 then
        local out = {}
        for _, b in ipairs(buttonCache[key]) do
            if b and b.Parent and b.Visible then table.insert(out, b) end
        end
        if #out > 0 then return out end
    end

    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return out end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible and d.AbsoluteSize.Magnitude > 4 then
            if hasAny(string.lower(d.Name), keys) then
                table.insert(out, d)
                if maxCount and #out >= maxCount then break end
            end
        end
    end
    buttonCache[key] = out
    buttonCacheTime = now
    return out
end

local function fireButton(btn)
    if not btn or not btn.Parent then return false end
    -- 路径 1：直接调用按钮上的连接函数（最精确）
    for _, sig in ipairs({ btn.MouseButton1Click, btn.MouseButton1Down, btn.Activated }) do
        local conns = safeGetConnections(sig)
        if conns then
            for _, c in ipairs(conns) do
                local f = c.Function or c.func or c[1]
                if type(f) == "function" then
                    pcall(f)
                end
            end
        end
    end
    -- 路径 2：无条件补一次真实坐标点击（移动端触摸通道）
    -- 有些游戏的连接函数只做视觉反馈，真正逻辑挂在内部触摸处理上，必须两个都打
    local pos = btn.AbsolutePosition + btn.AbsoluteSize * 0.5
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
    end)
    task.delay(0.05, function()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
        end)
    end)
    return true
end

local KEY_BLOCK  = { "block", "guard", "parry", "defend", "counter", "格挡", "防御", "挡", "招架" }
local KEY_ATTACK = { "m1", "attack", "punch", "light", "jab", "hit", "拳", "攻击", "打", "普攻", "轻击" }
local KEY_DODGE  = { "dodge", "dash", "roll", "evade", "闪", "翻滚", "闪避", "躲避" }

-- 兜底：名字对不上时，按屏幕位置盲选右下角的按钮
local NOT_BATTLE = { "close", "exit", "setting", "menu", "chat", "shop", "back", "leave",
                     "quit", "invite", "friend", "report", "关闭", "设置", "聊天", "商店", "退出" }
local fallbackCache, fallbackTime = nil, 0

local function findFallbackButtons()
    local now = os.clock()
    if fallbackCache and now - fallbackTime < 2 then
        local alive = {}
        for _, b in ipairs(fallbackCache) do
            if b and b.Parent and b.Visible then table.insert(alive, b) end
        end
        if #alive > 0 then return alive end
    end

    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local cam = Workspace.CurrentCamera
    if not (pg and cam) then return out end
    local vp = cam.ViewportSize

    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local p, s = d.AbsolutePosition, d.AbsoluteSize
            if p.X > vp.X * 0.55 and p.Y > vp.Y * 0.45 and s.Magnitude > 24 then
                if not hasAny(string.lower(d.Name), NOT_BATTLE) then
                    table.insert(out, d)
                end
            end
        end
    end
    table.sort(out, function(a, b)
        return a.AbsolutePosition.X + a.AbsolutePosition.Y > b.AbsolutePosition.X + b.AbsolutePosition.Y
    end)
    fallbackCache = out
    fallbackTime = now
    return out
end

local function actionBlock()
    if IS_PC then
        -- PC：游戏读的是键盘 F，直接按，按钮只做补充
        pressKey(Enum.KeyCode.F)
        local btns = findButtons(KEY_BLOCK, 1, true)
        if #btns > 0 then fireButton(btns[1]) end
        return true
    end
    -- 手机：按钮优先，再兜位置，最后按 F
    local btns = findButtons(KEY_BLOCK, 2, true)
    if #btns == 0 then btns = findFallbackButtons() end
    if #btns > 0 then fireButton(btns[1]) end
    pressKey(Enum.KeyCode.F)
    return #btns > 0
end

local function actionDodge()
    if IS_PC then
        pressKey(Enum.KeyCode.Q)
        local btns = findButtons(KEY_DODGE, 1, true)
        if #btns > 0 then fireButton(btns[1]) end
        return true
    end
    local btns = findButtons(KEY_DODGE, 2, true)
    if #btns == 0 then btns = findFallbackButtons() end
    if #btns > 0 then fireButton(btns[1]) end
    pressKey(Enum.KeyCode.Q)
    return #btns > 0
end

-- 运行计数（面板底部显示，用来判断到底有没有打出去）
local STAT = { atk = 0, def = 0, btnHit = 0, lastErr = "" }

--------------------------------------------------------------
-- 5. 移动
--------------------------------------------------------------
local flyBV, flyConn = nil, nil

local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    local hum = getHum()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function startFly()
    local ch = LP.Character
    if not ch then return end
    local root = ch:FindFirstChild("HumanoidRootPart")
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return end

    stopFly()

    -- 【反检测核心】只有「标准」模式才碰 PlatformStand。
    -- 这个属性会被复制到服务端，是最容易被 kick 的特征，默认不再使用。
    local hardMode = (CFG.flyMode == "标准")
    if hardMode then
        hum.PlatformStand = true
    end

    -- 以起飞点为基准，限制相对高度（绝对高度检测是最常见的服务端检测点）
    local groundY = root.Position.Y

    -- 【引擎选择】冲量模式不在角色里创建任何实例。
    -- 游戏脚本遍历 Character 找 BodyVelocity/BodyGyro 是经典检测手段，
    -- 用 ApplyImpulse 就没有可扫的东西。
    local useImpulse = (CFG.flyEngine ~= "BV")
    local bv
    if not useImpulse then
        bv = Instance.new("BodyVelocity")
        bv.Name = "BodyVelocity"   -- 用引擎默认名，不留自定义特征
        bv.MaxForce = Vector3.new(1, 1, 1) * 1e6
        bv.Velocity = Vector3.zero
        bv.Parent = root
        flyBV = bv
    else
        -- 冲量模式：起飞先给一脚，脱离地面摩擦后再交给每帧控制
        if hum.FloorMaterial ~= Enum.Material.Air then
            local m = root.AssemblyMass or 1
            root:ApplyImpulse(Vector3.new(0, 26 * m, 0))
        end
    end

    local cur = Vector3.zero

    flyConn = RunService.RenderStepped:Connect(function(dt)
        local c = LP.Character
        if not c then return end
        local r = c:FindFirstChild("HumanoidRootPart")
        local h = c:FindFirstChildOfClass("Humanoid")
        if not (r and h) then return end
        if bv and not bv.Parent then return end

        local dir = h.MoveDirection
        if CFG.flyForward then
            local cam = Workspace.CurrentCamera
            if cam then
                local lk = cam.CFrame.LookVector
                dir = Vector3.new(lk.X, 0, lk.Z)
                if dir.Magnitude > 0.05 then dir = dir.Unit end
            end
        elseif dir.Magnitude < 0.05 then
            dir = Vector3.zero
        end

        local p = prof()
        local spd = math.min(CFG.flySpeed, p.maxFly)

        -- 隐模式硬上限：水平 28、垂直缓升，尽量贴近"正常移动"的量级
        if not hardMode then
            spd = math.min(spd, 28)
        end
        if CFG.stealth then spd = math.min(spd, 22) end
        if CFG.watched then spd = math.min(spd, 16) end

        if CFG.humanize then
            spd = spd * (0.97 + math.sin(os.clock() * 3.1) * 0.03)
        end

        -- 高度天花板
        local ceiling = groundY + CFG.flyMaxHeight
        if hardMode then
            ceiling = math.min(ceiling, p.maxHeight)
        end

        local lift = CFG.flyLift * spd * 0.7
        if not hardMode then
            -- 不设 PlatformStand 时靠小幅上推离地，不猛冲
            lift = math.max(lift, 1.4)
        end
        if r.Position.Y > ceiling then
            lift = math.min(lift, -3)
        end

        local target = dir * spd + Vector3.new(0, lift, 0)

        -- 平滑加速，避免速度瞬间跳变（速度突变是最明显的特征之一）
        cur = cur:Lerp(target, math.clamp(dt * 6, 0, 1))

        if bv then
            bv.Velocity = cur
        else
            -- 冲量模式：把当前速度拉向目标速度，角色里不生成任何实例
            local vel = r.AssemblyLinearVelocity
            local delta = cur - vel
            local mass = r.AssemblyMass
            if mass and mass > 0 then
                r:ApplyImpulse(delta * mass)
            end
        end
    end)
end

local function applySpeed()
    local hum = getHum()
    if not hum then return end
    local target = BASE_WALK
    if CFG.speedOn then
        local p = prof()
        local mul = math.min(CFG.speedMul, p.maxWalk)
        if CFG.stealth then mul = math.min(mul, 1.4) end
        if CFG.watched then mul = math.min(mul, 1.12) end
        target = BASE_WALK * mul
        if CFG.humanize then
            target = target + math.sin(os.clock() * 4.3) * 0.06
        end
    end
    if math.abs(hum.WalkSpeed - target) > 0.05 then
        hum.WalkSpeed = target
    end
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if CFG.speedOn then pcall(applySpeed) end
    end
end)

--------------------------------------------------------------
-- 6. 无限体力（带随机波动的软锁）
--------------------------------------------------------------
local staminaTargets = {}
local STAM_KEYS = { "posture", "stamina", "energy", "endurance", "guard", "poise", "体力", "气力" }

local function scanStamina(scene)
    local ok, attrs = pcall(function() return scene:GetAttributes() end)
    if ok and attrs then
        for name, val in pairs(attrs) do
            if type(val) == "number" and hasAny(string.lower(name), STAM_KEYS) then
                local exists = false
                for _, t in ipairs(staminaTargets) do
                    if t.obj == scene and t.key == name then exists = true break end
                end
                if not exists then
                    table.insert(staminaTargets, {
                        obj = scene, key = name, kind = "attr",
                        max = math.max(val, 100), resets = 0,
                    })
                end
            end
        end
    end
    for _, d in ipairs(scene:GetDescendants()) do
        if d:IsA("NumberValue") or d:IsA("IntValue") then
            if hasAny(string.lower(d.Name), STAM_KEYS) then
                local exists = false
                for _, t in ipairs(staminaTargets) do
                    if t.obj == d then exists = true break end
                end
                if not exists then
                    table.insert(staminaTargets, {
                        obj = d, kind = "value",
                        max = math.max(d.Value, 100), resets = 0,
                    })
                end
            end
        end
    end
end

local function rescanStamina()
    staminaTargets = {}
    scanStamina(LP)
    if LP.Character then scanStamina(LP.Character) end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then scanStamina(pg) end
end

local function lockStamina()
    -- 不锁死 100%，在 90–100% 间波动，避免"恒定满值"这种异常特征
    local jitter = 0.90 + math.random() * 0.10
    for i = #staminaTargets, 1, -1 do
        local t = staminaTargets[i]
        if not t.obj.Parent then
            table.remove(staminaTargets, i)
        elseif t.kind == "attr" then
            pcall(function()
                local cur = t.obj:GetAttribute(t.key)
                if type(cur) == "number" then
                    if cur > t.max then t.max = cur end
                    local goal = t.max * jitter
                    if cur < goal then
                        t.obj:SetAttribute(t.key, goal)
                    end
                    if cur < t.max * 0.6 then t.resets = t.resets + 1 end
                end
            end)
        else
            pcall(function()
                if t.obj.Value > t.max then t.max = t.obj.Value end
                local goal = t.max * jitter
                if t.obj.Value < goal then
                    t.obj.Value = goal
                end
                if t.obj.Value < t.max * 0.6 then t.resets = t.resets + 1 end
            end)
        end
    end
end

--------------------------------------------------------------
-- 7. ESP
--------------------------------------------------------------
local espData = {}
local espGui = LP:FindFirstChild("PlayerGui") or guiParent()

local function clearESP()
    for _, d in pairs(espData) do
        if d.hl then d.hl:Destroy() end
        if d.bb then d.bb:Destroy() end
    end
    espData = {}
end

local function colorForKind(kind)
    if kind == "player" then return Color3.fromRGB(255, 86, 96) end
    if kind == "ally"   then return Color3.fromRGB(88, 232, 150) end
    if kind == "npc"    then return Color3.fromRGB(255, 196, 82) end
    return Color3.fromRGB(180, 120, 255)
end

local function createESP(obj, kind)
    local col = colorForKind(kind)
    local head = obj:FindFirstChild("Head")

    local hl = Instance.new("Highlight")
    hl.Name = "HL"
    hl.FillColor = col
    hl.OutlineColor = col
    hl.FillTransparency = 0.62
    hl.OutlineTransparency = 0.05
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = obj
    hl.Parent = espGui

    local bb, label, barBg, barFill
    if head then
        bb = Instance.new("BillboardGui")
        bb.Name = "BB"
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.ResetOnSpawn = false
        bb.Size = UDim2.fromOffset(150, 42)
        bb.StudsOffset = Vector3.new(0, 2.7, 0)
        bb.Adornee = head
        bb.Parent = espGui

        label = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = FONT_B,
            TextSize = 13,
            TextColor3 = col,
            TextStrokeTransparency = 0.35,
            Text = "",
        }, bb)

        barBg = new("Frame", {
            Size = UDim2.new(1, -8, 0, 5),
            Position = UDim2.new(0, 4, 0, 20),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.45,
            BorderSizePixel = 0,
        }, bb)
        corner(barBg, 3)

        barFill = new("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = col,
            BorderSizePixel = 0,
        }, barBg)
        corner(barFill, 3)
    end

    return { hl = hl, bb = bb, label = label, barFill = barFill, kind = kind }
end

local function updateESPObject(model, data, hum, root)
    local myRoot = getRoot()
    local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0

    if data.label then
        local name = model.Name
        local plr = Players:GetPlayerFromCharacter(model)
        if plr then name = plr.DisplayName end
        if CFG.espDist then
            data.label.Text = string.format("%s  [%dm]", name, math.floor(dist))
        else
            data.label.Text = name
        end
    end

    if data.barFill then
        if CFG.espHealth then
            local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            data.barFill.Visible = true
            data.barFill.Size = UDim2.new(ratio, 0, 1, 0)
            data.barFill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - ratio)), math.floor(230 * ratio), 90)
        else
            data.barFill.Visible = false
        end
    end
end

local DROP_KEYS = { "drop", "loot", "item", "coin", "cash", "money", "chest", "reward", "pickup", "掉" }

local function scanESP()
    if not (CFG.espPlayer or CFG.espNPC or CFG.espDrop) then
        if next(espData) then clearESP() end
        return
    end
    local myRoot = getRoot()
    if not myRoot then return end
    local myPos = myRoot.Position
    local seen = {}

    for _, obj in ipairs(Workspace:GetChildren()) do
        local handled = false

        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and root and hum.Health > 0 then
                local plr = Players:GetPlayerFromCharacter(obj)
                local kind
                if plr then
                    if plr.Team and LP.Team and plr.Team == LP.Team then
                        kind = "ally"
                    else
                        kind = "player"
                    end
                else
                    kind = "npc"
                end
                local want = (kind == "npc") and CFG.espNPC or CFG.espPlayer
                local dist = (root.Position - myPos).Magnitude
                if want and dist <= CFG.espRange then
                    local data = espData[obj]
                    if not data then
                        data = createESP(obj, kind)
                        espData[obj] = data
                    end
                    updateESPObject(obj, data, hum, root)
                    seen[obj] = true
                    handled = true
                end
            end
        end

        if not handled and CFG.espDrop and not obj:FindFirstChildOfClass("Humanoid") then
            local isDrop = obj:IsA("Tool") or hasAny(string.lower(obj.Name), DROP_KEYS)
            if isDrop then
                local pos = obj:IsA("BasePart") and obj.Position
                    or (obj.PrimaryPart and obj.PrimaryPart.Position)
                if pos and (pos - myPos).Magnitude <= CFG.espRange then
                    local data = espData[obj]
                    if not data then
                        data = createESP(obj, "drop")
                        espData[obj] = data
                    end
                    if data.label then
                        data.label.Text = string.format("%s [%dm]", obj.Name,
                            math.floor((pos - myPos).Magnitude))
                    end
                    seen[obj] = true
                end
            end
        end
    end

    for obj, data in pairs(espData) do
        if not seen[obj] or not obj.Parent then
            if data.hl then data.hl:Destroy() end
            if data.bb then data.bb:Destroy() end
            espData[obj] = nil
        end
    end
end

--------------------------------------------------------------
-- 8. 智能防御
--------------------------------------------------------------
local LIGHT_KEYS = { "m1", "punch", "jab", "light", "attack", "slash", "swing", "strike", "hit", "combo" }
local HEAVY_KEYS = { "m2", "heavy", "kick", "slam", "smash", "strong", "uppercut", "finisher", "guardbreak" }

local defState = { lastAction = 0 }

local function scanEnemies()
    local list = {}
    local myRoot = getRoot()
    if not myRoot then return list end
    local myPos = myRoot.Position
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and root and hum.Health > 0 then
                local plr = Players:GetPlayerFromCharacter(obj)
                local isAlly = plr and plr.Team and LP.Team and plr.Team == LP.Team
                if not isAlly then
                    local d = (root.Position - myPos).Magnitude
                    if d <= CFG.defRange then
                        table.insert(list, { model = obj, hum = hum, root = root, dist = d })
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function getAttackKind(enemyHum)
    local animator = enemyHum:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok or not tracks then return nil end
    local window = 0.18 + CFG.defLead
    for _, tr in ipairs(tracks) do
        local n = string.lower(tr.Name)
        if tr.TimePosition < window then
            if hasAny(n, HEAVY_KEYS) then return "heavy" end
            if hasAny(n, LIGHT_KEYS) then return "light" end
        end
    end
    return nil
end

local function updateDefense()
    local now = os.clock()
    if now - defState.lastAction < 0.16 then return end

    -- 防封：按档位抽签，故意漏掉一部分，避免 100% 招架率
    local rate = math.min(CFG.parryRate, prof().parryRate)
    if math.random() > rate then
        defState.lastAction = now
        return
    end

    local enemies = scanEnemies()
    if #enemies == 0 then return end
    local me = getRoot()
    if not me then return end

    for _, e in ipairs(enemies) do
        local kind = getAttackKind(e.hum)

        if kind == "heavy" then
            if CFG.defMode == "只格挡" then actionBlock() else actionDodge() end
            STAT.def = STAT.def + 1
            defState.lastAction = now
            return
        elseif kind == "light" then
            if CFG.defMode == "只闪避" then actionDodge() else actionBlock() end
            STAT.def = STAT.def + 1
            defState.lastAction = now
            return
        end

        if e.dist < 7.5 then
            local look = e.root.CFrame.LookVector
            local toMe = me.Position - e.root.Position
            if toMe.Magnitude > 0.1 and look:Dot(toMe.Unit) > 0.35 then
                if CFG.defMode == "只闪避" then actionDodge() else actionBlock() end
                STAT.def = STAT.def + 1
                defState.lastAction = now
                return
            end
        end
    end
end

--------------------------------------------------------------
-- 9. AI 自动战斗
--------------------------------------------------------------
local atkState = { last = 0, lock = nil, remote = nil }

local function fireRemoteAttack()
    local cache = atkState.remote
    if cache and cache.Parent then
        pcall(function() cache:FireServer() end)
        return true
    end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            if hasAny(string.lower(d.Name), { "attack", "m1", "punch", "combat", "hit", "strike" }) then
                atkState.remote = d
                pcall(function() d:FireServer() end)
                return true
            end
        end
    end
    return false
end

local function doAttack()
    local now = os.clock()
    local gap = CFG.atkGap * prof().gapScale
    if CFG.humanize then
        gap = gap * (0.85 + math.random() * 0.30)   -- 人类化：节奏不固定
    end
    if CFG.watched then gap = gap * 1.6 end          -- 有人看着就慢下来
    if now - atkState.last < gap then return end
    atkState.last = now
    STAT.atk = STAT.atk + 1

    if CFG.atkMode == "鼠标" then
        clickCenter()
    elseif CFG.atkMode == "Remote" then
        if not fireRemoteAttack() then
            local btns = findButtons(KEY_ATTACK, 2, true)
            if #btns == 0 then btns = findFallbackButtons() end
            if #btns > 0 then fireButton(btns[1]) else clickCenter() end
        end
    elseif CFG.atkMode == "按钮" then
        local btns = findButtons(KEY_ATTACK, 2, true)
        if #btns == 0 then btns = findFallbackButtons() end
        if #btns > 0 then
            fireButton(btns[1])
            STAT.btnHit = STAT.btnHit + 1
        end
    else
        -- 自动：PC 用鼠标左键（游戏本来就是左键出拳），手机找屏幕按钮
        if IS_PC then
            clickCenter()
            local btns = findButtons(KEY_ATTACK, 1, true)
            if #btns > 0 then
                fireButton(btns[1])
                STAT.btnHit = STAT.btnHit + 1
            end
        else
            local btns = findButtons(KEY_ATTACK, 2, true)
            if #btns == 0 then btns = findFallbackButtons() end
            if #btns > 0 then
                fireButton(btns[1])
                STAT.btnHit = STAT.btnHit + 1
            else
                clickCenter()
            end
        end
    end
end

local function validTarget(obj, myPos)
    if not obj or not obj.Parent then return nil end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
    if not (hum and root and hum.Health > 0) then return nil end
    if (root.Position - myPos).Magnitude > CFG.chaseRange then return nil end
    return root, hum
end

local function pickTarget(myPos)
    if atkState.lock then
        local root, hum = validTarget(atkState.lock, myPos)
        if root then return atkState.lock, root, hum end
        atkState.lock = nil
    end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and root and hum.Health > 0 then
                local plr = Players:GetPlayerFromCharacter(obj)
                local accept
                if CFG.combat == "PVP" then
                    accept = plr ~= nil
                    if accept and plr.Team and LP.Team and plr.Team == LP.Team then
                        accept = false
                    end
                elseif CFG.combat == "NPC" then
                    accept = plr == nil
                else
                    accept = false
                end
                if accept then
                    local d = (root.Position - myPos).Magnitude
                    if d < bestDist and d <= CFG.chaseRange then
                        best, bestDist = obj, d
                    end
                end
            end
        end
    end
    return best
end

local combatRotating = false

local function updateCombat()
    local me = getRoot()
    local hum = getHum()
    if not (me and hum) then return end

    if CFG.watched and CFG.watchPause then
        -- 有人在看：只保留防御，停手
        hum:Move(Vector3.zero, false)
        return
    end

    local target = pickTarget(me.Position)
    if not target then
        if combatRotating then
            hum.AutoRotate = true
            combatRotating = false
        end
        return
    end

    local tRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not tRoot then return end

    local tPos = tRoot.Position
    local myPos = me.Position
    local flat = Vector3.new(tPos.X, myPos.Y, tPos.Z)
    local dist = (flat - myPos).Magnitude

    if dist > 0.6 then
        if not combatRotating then
            hum.AutoRotate = false
            combatRotating = true
        end
        me.CFrame = CFrame.lookAt(myPos, flat)
    end

    if dist > 6.5 then
        local dir = flat - myPos
        if dir.Magnitude > 0.1 then hum:Move(dir.Unit, false) end
    else
        hum:Move(Vector3.zero, false)
        if CFG.defense then
            local kind = getAttackKind(target:FindFirstChildOfClass("Humanoid"))
            if kind == "heavy" then
                actionDodge()
                return
            end
        end
        doAttack()
    end
end

--------------------------------------------------------------
-- 10. 防封守护
--------------------------------------------------------------
local SUSPICIOUS = { "admin", "moderator", "developer", "owner", "staff", "creator", "official", "anticheat" }

local function softStop(reason)
    CFG.fly = false
    pcall(stopFly)
    CFG.speedOn = false
    pcall(applySpeed)
    CFG.combat = "OFF"
    CFG.flyLift = 0
    if statusLabel then statusLabel.Text = reason end
    for _, r in ipairs(refreshers) do pcall(r) end
    for _, r in ipairs(selectorRefreshers) do pcall(r) end
end

local function watchLoop()
    while true do
        task.wait(0.6)
        local myRoot = getRoot()
        if not myRoot then
            CFG.watched, CFG.watchers = false, 0
        else
            local cnt = 0
            local myPos = myRoot.Position
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then
                    local isAlly = plr.Team and LP.Team and plr.Team == LP.Team
                    if not isAlly then
                        local chr = plr.Character
                        local root = chr and chr:FindFirstChild("HumanoidRootPart")
                        if root then
                            local d = (root.Position - myPos).Magnitude
                            if d < 35 then
                                local toMe = myPos - root.Position
                                if toMe.Magnitude > 0.1 then
                                    if root.CFrame.LookVector:Dot(toMe.Unit) > 0.25 then
                                        cnt = cnt + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
            CFG.watchers = cnt
            local was = CFG.watched
            CFG.watched = (cnt > 0) and CFG.watchPause or false
            if CFG.watched and not was then
                CFG.combat = "OFF"
                for _, r in ipairs(refreshers) do pcall(r) end
                for _, r in ipairs(selectorRefreshers) do pcall(r) end
            end
        end
    end
end

local function adminLoop()
    while true do
        task.wait(2)
        if CFG.adminWatch then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then
                    local n = string.lower(plr.Name .. "|" .. plr.DisplayName)
                    if hasAny(n, SUSPICIOUS) then
                        if CFG.flagged ~= plr.Name then
                            CFG.flagged = plr.Name
                            pcall(softStop, "检测到可疑账号 " .. plr.Name .. "，已自动收手")
                        end
                    end
                end
            end
        end
    end
end

local function sessionLoop()
    local limit = math.random(45 * 60, 90 * 60)
    while true do
        task.wait(5)
        if CFG.sessionGuard then
            if os.clock() - CFG.sessionStart > limit then
                pcall(softStop, string.format("已连续在线 %d 分钟，建议下线休息（防封）", math.floor(limit / 60)))
                limit = math.random(45 * 60, 90 * 60) * 2
                CFG.sessionStart = os.clock()
            end
        end
    end
end

--------------------------------------------------------------
-- 11. UI 骨架
--------------------------------------------------------------
local parentGui = guiParent()

-- 清理上一次注入（用属性标记，不用固定名字）
for _, g in ipairs(parentGui:GetChildren()) do
    if g:IsA("ScreenGui") and g:GetAttribute("GKH") then
        g:Destroy()
    end
end

local RAND_TAG = tostring(math.random(100000, 999999))

local gui = new("ScreenGui", {
    Name = "UI_" .. RAND_TAG,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})

-- 关键：protect_gui 必须在设置 Parent 之前调用。
-- 作用：让这个 ScreenGui 不出现在 PlayerGui/CoreGui 的子级列表里，
--       游戏自己的 LocalScript 遍历 PlayerGui 时扫不到它。
local protectGui = api("protect_gui") or (syn and syn.protect_gui)
if protectGui then pcall(protectGui, gui) end
gui.Parent = parentGui
gui:SetAttribute("GKH", true)

local overlay = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(2, 6, 16),
    BackgroundTransparency = 0.42,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 1,
}, gui)

-- 面板尺寸：PC 上锁死 560×780（不然 92% 宽会横跨整个 2K 屏），手机按比例铺满
local CAM0 = Workspace.CurrentCamera
local VP0 = (CAM0 and CAM0.ViewportSize) or Vector2.new(1280, 720)
local PANEL_W = math.min(IS_PC and 560 or VP0.X * 0.92, VP0.X * 0.95)
local PANEL_H = math.min(IS_PC and 780 or VP0.Y * 0.84, VP0.Y * 0.92)

local panel = new("Frame", {
    Size = UDim2.fromOffset(PANEL_W, PANEL_H),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.glass,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 3,
}, gui)
corner(panel, 20)
stroke(panel, C.stroke, 1.5, 0.25)

new("UIGradient", {
    Rotation = 118,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 92, 168)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(20, 44, 88)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 18, 40)),
    }),
}, panel)

local sheen = new("Frame", {
    Size = UDim2.new(1, -18, 0, 96),
    Position = UDim2.fromOffset(9, 1),
    BackgroundColor3 = Color3.fromRGB(190, 226, 255),
    BackgroundTransparency = 0.9,
    BorderSizePixel = 0,
    ZIndex = 4,
}, panel)
corner(sheen, 18)
new("UIGradient", {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, sheen)

local glow = new("Frame", {
    Size = UDim2.new(1, 10, 1, 10),
    Position = UDim2.new(0, -5, 0, -5),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, panel)
corner(glow, 24)
stroke(glow, C.accentHi, 2, 0.82)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 64),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, panel)

local logo = new("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(16, 14),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, header)
corner(logo, 12)
new("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = FONT_B,
    TextSize = 19,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Text = "B",
}, logo)

new("TextLabel", {
    Size = UDim2.new(0, 200, 0, 22),
    Position = UDim2.fromOffset(64, 14),
    BackgroundTransparency = 1,
    Font = FONT_B,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.text,
    Text = "Berlin",
}, header)

new("TextLabel", {
    Size = UDim2.new(0, 220, 0, 18),
    Position = UDim2.fromOffset(64, 36),
    BackgroundTransparency = 1,
    Font = FONT,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.dim,
    Text = "学乱 · Gakuran · v2.0",
}, header)

local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -50, 0, 15),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.9,
    AutoButtonColor = false,
    Font = FONT_B,
    TextSize = 16,
    TextColor3 = C.text,
    Text = "✕",
    ZIndex = 7,
}, header)
corner(closeBtn, 12)
stroke(closeBtn, C.stroke, 1, 0.6)

local scroll = new("ScrollingFrame", {
    Size = UDim2.new(1, -24, 1, -150),
    Position = UDim2.fromOffset(12, 70),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.accent,
    ScrollBarImageTransparency = 0.35,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ZIndex = 5,
}, panel)
pad(scroll, 2, 4, 6, 8)
vlist(scroll, 10)

local statusBar = new("Frame", {
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.new(0, 12, 1, -42),
    BackgroundColor3 = Color3.fromRGB(6, 14, 30),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 5,
}, panel)
corner(statusBar, 10)
stroke(statusBar, C.stroke, 1, 0.7)

statusLabel = new("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0),
    Position = UDim2.fromOffset(8, 0),
    BackgroundTransparency = 1,
    Font = FONT,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextColor3 = C.dim,
    Text = "就绪 · 移动端 · 潜伏版",
}, statusBar)

--------------------------------------------------------------
-- 12. 控件工厂
--------------------------------------------------------------
local orderIndex = 0
local function nextOrder()
    orderIndex = orderIndex + 1
    return orderIndex
end

local function makeSection(title, tag)
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, scroll)
    corner(card, 16)
    stroke(card, C.stroke, 1, 0.62)
    pad(card, 10, 8, 10, 10)
    vlist(card, 6)

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = -1,
    }, card)

    local bar = new("Frame", {
        Size = UDim2.fromOffset(4, 14),
        Position = UDim2.fromOffset(0, 5),
        BackgroundColor3 = C.accentHi,
        BorderSizePixel = 0,
    }, head)
    corner(bar, 2)

    new("TextLabel", {
        Size = UDim2.new(0, 150, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = FONT_B,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.accentHi,
        Text = title,
    }, head)

    if tag then
        new("TextLabel", {
            Size = UDim2.new(0, 100, 1, 0),
            Position = UDim2.new(1, -100, 0, 0),
            BackgroundTransparency = 1,
            Font = FONT,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = C.dim,
            Text = tag,
        }, head)
    end

    return card
end

local function makeRow(parent)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = C.card2,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, parent)
    corner(row, 11)
    return row
end

local function makeLabel(row, text, sub)
    local mainH = sub and UDim2.new(1, -150, 0, 20) or UDim2.new(1, -150, 1, 0)
    new("TextLabel", {
        Size = mainH,
        Position = UDim2.fromOffset(12, sub and 5 or 0),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text,
    }, row)
    if sub then
        new("TextLabel", {
            Size = UDim2.new(1, -150, 0, 14),
            Position = UDim2.fromOffset(12, 24),
            BackgroundTransparency = 1,
            Font = FONT,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.dim,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = sub,
        }, row)
    end
end

local function makeToggle(row, getter, onChange)
    local value = getter()
    local pill = new("TextButton", {
        Size = UDim2.fromOffset(52, 26),
        Position = UDim2.new(1, -62, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = value and C.accent or C.off,
        BackgroundTransparency = 0.15,
        AutoButtonColor = false,
        Text = "",
    }, row)
    corner(pill, 13)
    local pillStroke = stroke(pill, C.accentHi, 1, value and 0.4 or 0.8)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(value and 29 or 3, 3),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, pill)
    corner(knob, 10)

    local function render()
        local v = getter()
        pill.BackgroundColor3 = v and C.accent or C.off
        knob.Position = UDim2.fromOffset(v and 29 or 3, 3)
        pillStroke.Transparency = v and 0.4 or 0.8
    end

    pill.MouseButton1Click:Connect(function()
        local v = not getter()
        onChange(v)
        render()
    end)

    table.insert(refreshers, render)
    return pill
end

local function makeButton(row, text, color, onClick)
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(96, 28),
        Position = UDim2.new(1, -106, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = color or C.accent,
        BackgroundTransparency = 0.1,
        AutoButtonColor = false,
        Font = FONT_B,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = text,
    }, row)
    corner(btn, 10)
    stroke(btn, C.accentHi, 1, 0.5)
    btn.MouseButton1Down:Connect(function()
        tween(btn, 0.08, { BackgroundTransparency = 0.38 })
    end)
    btn.MouseButton1Up:Connect(function()
        tween(btn, 0.12, { BackgroundTransparency = 0.1 })
    end)
    btn.MouseButton1Click:Connect(function()
        if onClick then onClick() end
    end)
    return btn
end

local function makeSlider(row, min, max, value, step, unit, onChange)
    local holder = new("Frame", {
        Size = UDim2.new(0, 142, 1, 0),
        Position = UDim2.new(1, -148, 0, 0),
        BackgroundTransparency = 1,
    }, row)

    local valLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = C.accentHi,
        Text = tostring(value) .. (unit or ""),
    }, holder)

    local track = new("Frame", {
        Size = UDim2.new(1, -4, 0, 6),
        Position = UDim2.new(0, 2, 0, 22),
        BackgroundColor3 = Color3.fromRGB(8, 18, 36),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
    }, holder)
    corner(track, 3)

    local fill = new("Frame", {
        Size = UDim2.fromScale((value - min) / (max - min), 1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 3)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(15, 15),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(240, 248, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(knob, 8)

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, holder)

    local dragging = false

    local function setFromX(px)
        local abs = track.AbsolutePosition
        local size = track.AbsoluteSize
        local alpha = math.clamp((px - abs.X) / math.max(size.X, 1), 0, 1)
        local raw = min + (max - min) * alpha
        if step and step > 0 then
            raw = math.floor(raw / step + 0.5) * step
        end
        raw = math.clamp(raw, min, max)
        local a = (raw - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        if step and step < 1 then
            valLbl.Text = string.format("%.2f", raw)
        else
            valLbl.Text = tostring(math.floor(raw + 0.5))
        end
        valLbl.Text = valLbl.Text .. (unit or "")
        if onChange then onChange(raw) end
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return holder
end

local function makeSelector(row, getter, options, onChange)
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(96, 28),
        Position = UDim2.new(1, -106, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.card2,
        BackgroundTransparency = 0.2,
        AutoButtonColor = false,
        Font = FONT_B,
        TextSize = 12,
        TextColor3 = C.accentHi,
        Text = getter(),
    }, row)
    corner(btn, 10)
    stroke(btn, C.stroke, 1, 0.5)

    btn.MouseButton1Click:Connect(function()
        local cur = getter()
        local idx = 1
        for i, v in ipairs(options) do
            if v == cur then idx = i break end
        end
        idx = idx + 1
        if idx > #options then idx = 1 end
        onChange(options[idx])
        btn.Text = options[idx]
    end)

    table.insert(selectorRefreshers, function()
        local cur = getter()
        btn.Text = cur
    end)
    return btn
end

--------------------------------------------------------------
-- 13. 面板内容
--------------------------------------------------------------
-- ===== 机动 =====
local secMove = makeSection("机  动", "MOVE")

local r1 = makeRow(secMove)
makeLabel(r1, "飞行", "打开后摇杆水平移动")
makeToggle(r1, function() return CFG.fly end, function(v)
    CFG.fly = v
    if v then startFly() else stopFly() end
end)

local r2 = makeRow(secMove)
makeLabel(r2, "飞行模式", "隐 = 不碰 PlatformStand")
makeSelector(r2, function() return CFG.flyMode end, { "隐", "标准" }, function(v)
    CFG.flyMode = v
    if v == "标准" then
        statusLabel.Text = "警告：标准模式会设 PlatformStand，容易被服务端 kick"
    end
    if CFG.fly then startFly() end
end)

local r2b = makeRow(secMove)
makeLabel(r2b, "飞行高度", "相对起飞点，越低越安全")
makeSlider(r2b, 10, 200, CFG.flyMaxHeight, 5, "格", function(v) CFG.flyMaxHeight = v end)

local r2c = makeRow(secMove)
makeLabel(r2c, "飞行引擎", "BV 会在角色里留实例，必被踢")
makeSelector(r2c, function() return CFG.flyEngine end, { "冲量", "BV" }, function(v)
    CFG.flyEngine = v
    if v == "BV" then
        statusLabel.Text = "警告：BV 引擎会在角色里生成 BodyVelocity，这个游戏会立刻踢"
    end
    if CFG.fly then startFly() end
end)

local r3 = makeRow(secMove)
makeLabel(r3, "飞行速度", "隐模式硬上限 28")
makeSlider(r3, 20, 200, CFG.flySpeed, 1, "", function(v) CFG.flySpeed = v end)

local r4 = makeRow(secMove)
makeLabel(r4, "升降", "按住持续上升 / 下降")
local liftWrap = new("Frame", {
    Size = UDim2.new(0, 142, 1, 0),
    Position = UDim2.new(1, -148, 0, 0),
    BackgroundTransparency = 1,
}, r4)
hlist(liftWrap, 8)

local function liftBtn(text, dir)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(64, 28),
        BackgroundColor3 = C.accent,
        BackgroundTransparency = 0.15,
        AutoButtonColor = false,
        Font = FONT_B,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = text,
    }, liftWrap)
    corner(b, 9)
    stroke(b, C.accentHi, 1, 0.5)
    b.MouseButton1Down:Connect(function()
        CFG.flyLift = dir
        b.BackgroundTransparency = 0.4
    end)
    local function release()
        CFG.flyLift = 0
        b.BackgroundTransparency = 0.15
    end
    b.MouseButton1Up:Connect(release)
    b.MouseLeave:Connect(release)
    return b
end
liftBtn("▲ 升", 1)
liftBtn("▼ 降", -1)

local r5 = makeRow(secMove)
makeLabel(r5, "镜头前进", "飞行时朝视角方向飞")
makeToggle(r5, function() return CFG.flyForward end, function(v) CFG.flyForward = v end)

local r6 = makeRow(secMove)
makeLabel(r6, "加速", "走速倍率（受档位限制）")
makeToggle(r6, function() return CFG.speedOn end, function(v)
    CFG.speedOn = v
    if not v then applySpeed() end
end)

local r7 = makeRow(secMove)
makeLabel(r7, "走速倍率", "1.0 – 3.0 倍")
makeSlider(r7, 1.0, 3.0, CFG.speedMul, 0.1, "x", function(v) CFG.speedMul = v end)

-- ===== 战斗 =====
local secFight = makeSection("战  斗", "COMBAT")

local f1 = makeRow(secFight)
makeLabel(f1, "智能防御", "Parry / 格挡 / 闪避")
makeToggle(f1, function() return CFG.defense end, function(v) CFG.defense = v end)

local f2 = makeRow(secFight)
makeLabel(f2, "防御策略", "智能 / 只格挡 / 只闪避")
makeSelector(f2, function() return CFG.defMode end, { "智能", "只格挡", "只闪避" }, function(v) CFG.defMode = v end)

local f3 = makeRow(secFight)
makeLabel(f3, "招架成功率", "别开 100%，留破绽才像人")
makeSlider(f3, 0.4, 1.0, CFG.parryRate, 0.01, "", function(v) CFG.parryRate = v end)

local f4 = makeRow(secFight)
makeLabel(f4, "侦测半径", "10 – 40 格")
makeSlider(f4, 10, 40, CFG.defRange, 1, "格", function(v) CFG.defRange = v end)

local f5 = makeRow(secFight)
makeLabel(f5, "出招提前量", "0 – 0.30 秒")
makeSlider(f5, 0, 0.30, CFG.defLead, 0.01, "s", function(v) CFG.defLead = v end)

local f6 = makeRow(secFight)
makeLabel(f6, "自动战斗", "OFF / NPC / PVP")
makeSelector(f6, function() return CFG.combat end, { "OFF", "NPC", "PVP" }, function(v) CFG.combat = v end)

local f7 = makeRow(secFight)
makeLabel(f7, "手动锁定", "锁最近目标优先攻击")
makeButton(f7, "锁定", C.accent, function()
    local me = getRoot()
    if not me then return end
    local best, bd = nil, math.huge
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local d = (root.Position - me.Position).Magnitude
                if d < bd and d < 200 then best, bd = obj, d end
            end
        end
    end
    atkState.lock = best
    statusLabel.Text = best and ("已锁定：" .. best.Name) or "附近没有目标"
end)

local f8 = makeRow(secFight)
makeLabel(f8, "攻击间隔", "越小越快，也越显眼")
makeSlider(f8, 0.1, 0.8, CFG.atkGap, 0.01, "s", function(v) CFG.atkGap = v end)

local f9 = makeRow(secFight)
makeLabel(f9, "出招方式", "自动 / 按钮 / 鼠标 / Remote")
makeSelector(f9, function() return CFG.atkMode end, { "自动", "按钮", "鼠标", "Remote" }, function(v) CFG.atkMode = v end)

-- ===== 辅助 =====
local secUtil = makeSection("辅  助", "UTIL")

local u1 = makeRow(secUtil)
makeLabel(u1, "无限体力", "Posture + Stamina 软锁")
makeToggle(u1, function() return CFG.stamina end, function(v)
    CFG.stamina = v
    if v then
        rescanStamina()
        statusLabel.Text = string.format("已接管 %d 个体力字段", #staminaTargets)
    end
end)

local u2 = makeRow(secUtil)
makeLabel(u2, "重扫体力字段", "换职业 / 重生后点一次")
makeButton(u2, "重扫", C.card2, function()
    rescanStamina()
    statusLabel.Text = string.format("重扫完成：%d 个字段", #staminaTargets)
end)

-- ===== 防封 =====
local secSafe = makeSection("防  封", "SAFE")

local s1 = makeRow(secSafe)
makeLabel(s1, "安全档位", "稳健 / 平衡 / 激进")
makeSelector(s1, function() return CFG.profile end, { "稳健", "平衡", "激进" }, function(v)
    CFG.profile = v
    if CFG.speedOn then applySpeed() end
    if CFG.fly then startFly() end
    statusLabel.Text = "档位：" .. v .. "（速度与高度上限已调整）"
end)

local s2 = makeRow(secSafe)
makeLabel(s2, "人类化抖动", "节奏/走速/招架不固定")
makeToggle(s2, function() return CFG.humanize end, function(v) CFG.humanize = v end)

local s3 = makeRow(secSafe)
makeLabel(s3, "有人观察降级", "附近有人看你就收手")
makeToggle(s3, function() return CFG.watchPause end, function(v) CFG.watchPause = v end)

local s4 = makeRow(secSafe)
makeLabel(s4, "可疑账号监听", "名字含 admin/dev 等自动收手")
makeToggle(s4, function() return CFG.adminWatch end, function(v)
    CFG.adminWatch = v
    if not v then CFG.flagged = nil end
end)

local s5 = makeRow(secSafe)
makeLabel(s5, "会话时限", "45–90 分钟自动收手")
makeToggle(s5, function() return CFG.sessionGuard end, function(v) CFG.sessionGuard = v end)

local s6 = makeRow(secSafe)
makeLabel(s6, "低调模式", "限高 55 · 限速 1.4x · 球缩小")
makeToggle(s6, function() return CFG.stealth end, function(v)
    CFG.stealth = v
    if CFG.speedOn then applySpeed() end
    if CFG.fly then startFly() end
    if ball then
        ball.Size = UDim2.fromOffset(v and 26 or 46, v and 26 or 46)
        ball.TextSize = v and 10 or 16
        ball.BackgroundTransparency = v and 0.55 or 0.18
    end
end)

local s7 = makeRow(secSafe)
makeLabel(s7, "急停", "长按悬浮球 1 秒同样触发")
makeButton(s7, "PANIC", C.danger, function()
    doPanic()
end)

-- ===== 透视 =====
local secESP = makeSection("透  视", "ESP")

local e1 = makeRow(secESP)
makeLabel(e1, "玩家高亮", "敌方红 / 队友绿")
makeToggle(e1, function() return CFG.espPlayer end, function(v) CFG.espPlayer = v end)

local e2 = makeRow(secESP)
makeLabel(e2, "NPC 高亮", "黄色描边")
makeToggle(e2, function() return CFG.espNPC end, function(v) CFG.espNPC = v end)

local e3 = makeRow(secESP)
makeLabel(e3, "掉落物高亮", "紫色描边")
makeToggle(e3, function() return CFG.espDrop end, function(v) CFG.espDrop = v end)

local e4 = makeRow(secESP)
makeLabel(e4, "显示距离", "名字后的 [xxm]")
makeToggle(e4, function() return CFG.espDist end, function(v) CFG.espDist = v end)

local e5 = makeRow(secESP)
makeLabel(e5, "显示血条", "名字下方血条")
makeToggle(e5, function() return CFG.espHealth end, function(v) CFG.espHealth = v end)

local e6 = makeRow(secESP)
makeLabel(e6, "可视范围", "50 – 1000 格")
makeSlider(e6, 50, 1000, CFG.espRange, 10, "m", function(v) CFG.espRange = v end)

-- ===== 还原 =====
local secReset = makeSection("还  原", "RESET")

local d1 = makeRow(secReset)
makeLabel(d1, "关闭全部功能", "角色状态复位")
makeButton(d1, "一键还原", C.warn, function()
    CFG.fly = false
    stopFly()
    CFG.speedOn = false
    if getHum() then applySpeed() end
    CFG.defense = false
    CFG.combat = "OFF"
    CFG.stamina = false
    CFG.espPlayer = false
    CFG.espNPC = false
    CFG.espDrop = false
    CFG.flyLift = 0
    clearESP()
    if getHum() then getHum().AutoRotate = true end
    for _, r in ipairs(refreshers) do pcall(r) end
    statusLabel.Text = "已还原：全部关闭，状态复位"
end)

--------------------------------------------------------------
-- 14. 面板开关
--------------------------------------------------------------
local function openPanel()
    overlay.Visible = true
    panel.Visible = true
    if ball then ball.Visible = false end
    panel.Size = UDim2.fromOffset(PANEL_W * 0.94, PANEL_H * 0.94)
    tween(panel, 0.2, { Size = UDim2.fromOffset(PANEL_W, PANEL_H) })
end

local function closePanel()
    overlay.Visible = false
    panel.Visible = false
    if ball then ball.Visible = true end
end

doPanic = function()
    CFG.fly = false
    pcall(stopFly)
    CFG.speedOn = false
    pcall(applySpeed)
    CFG.defense = false
    CFG.combat = "OFF"
    CFG.stamina = false
    CFG.espPlayer = false
    CFG.espNPC = false
    CFG.espDrop = false
    CFG.flyLift = 0
    pcall(clearESP)
    local hum = getHum()
    if hum then hum.AutoRotate = true end
    for _, r in ipairs(refreshers) do pcall(r) end
    for _, r in ipairs(selectorRefreshers) do pcall(r) end
    closePanel()
    statusLabel.Text = "PANIC：已全部关闭并还原"
end

-- PC 快捷键：右 Shift 开关面板
if IS_PC then
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if panel.Visible then closePanel() else openPanel() end
        end
    end)
end

closeBtn.MouseButton1Click:Connect(closePanel)
overlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        closePanel()
    end
end)

--------------------------------------------------------------
-- 15. 悬浮球
--------------------------------------------------------------
ball = new("TextButton", {
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(1, -68, 0.5, 90),
    AnchorPoint = Vector2.new(0, 0),
    BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.18,
    AutoButtonColor = false,
    Font = FONT_B,
    TextSize = 19,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Text = "B",
    Visible = false,
    ZIndex = 20,
}, gui)
corner(ball, 23)
stroke(ball, C.accentHi, 1.5, 0.3)
new("UIGradient", {
    Rotation = 130,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 90, 200)),
    }),
}, ball)

local ballDragging, dragStart, dragOrigin = false, nil, nil
local ballHoldStart = 0
local ballPanicked = false

ball.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        ballDragging = true
        ballPanicked = false
        ballHoldStart = os.clock()
        dragStart = input.Position
        dragOrigin = ball.Position
        ball.BackgroundTransparency = 0.4
        task.delay(1, function()
            if ballDragging and not ballPanicked and os.clock() - ballHoldStart >= 0.95 then
                ballPanicked = true
                ballDragging = false
                pcall(doPanic)
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        ball.Position = UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1) then
        local moved = (input.Position - dragStart).Magnitude
        ballDragging = false
        ball.BackgroundTransparency = CFG.stealth and 0.55 or 0.18
        if moved < 12 and not ballPanicked then
            openPanel()
        end
    end
end)

--------------------------------------------------------------
-- 16. 主循环
--------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if CFG.combat ~= "OFF" then
        local ok, err = pcall(updateCombat)
        if not ok then STAT.lastErr = "战斗:" .. tostring(err) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        if CFG.defense then
            local ok, err = pcall(updateDefense)
            if not ok then STAT.lastErr = "防御:" .. tostring(err) end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.12)
        if CFG.stamina then pcall(lockStamina) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.45)
        pcall(scanESP)
    end
end)

task.spawn(watchLoop)
task.spawn(adminLoop)
task.spawn(sessionLoop)

-- 状态栏
task.spawn(function()
    while true do
        task.wait(1)
        local hum = getHum()
        local parts = {}
        if CFG.fly then table.insert(parts, "飞行") end
        if CFG.speedOn then table.insert(parts, string.format("加速%.1fx", CFG.speedMul)) end
        if CFG.defense then table.insert(parts, "防御") end
        if CFG.combat ~= "OFF" then table.insert(parts, "战斗:" .. CFG.combat) end
        if CFG.stamina then table.insert(parts, "体力") end
        local active = #parts > 0 and table.concat(parts, "·") or "待机"
        local warn = ""
        if CFG.watched then
            warn = string.format(" ⚠%d", CFG.watchers)
        end
        -- 调试计数：攻=发起攻击次数 防=触发防御次数 键=匹配到的攻击按钮数
        local btnN = #findButtons(KEY_ATTACK, 4, true)
        if STAT.lastErr ~= "" then
            statusLabel.Text = "ERR " .. STAT.lastErr
            statusLabel.TextColor3 = C.danger
        else
            statusLabel.Text = string.format("%s | HP%d | 攻%d 防%d 键%d | %s%s",
                active, hum and math.floor(hum.Health) or 0,
                STAT.atk, STAT.def, btnN,
                IS_PC and "PC" or "手机", warn)
            statusLabel.TextColor3 = CFG.watched and C.warn or C.dim
        end
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if CFG.fly then
        task.wait(0.4)
        pcall(startFly)
    end
    if CFG.stamina then pcall(rescanStamina) end
    pcall(applySpeed)
end)

-- 基准走速自适应
task.spawn(function()
    while true do
        task.wait(1)
        local hum = getHum()
        if hum and not CFG.speedOn and hum.WalkSpeed > 0 and hum.WalkSpeed < 40 then
            BASE_WALK = hum.WalkSpeed
        end
    end
end)

--------------------------------------------------------------
-- 17. 启动开屏（先出名字，再出 UI）
--------------------------------------------------------------
local function playSplash()
    local splash = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(3, 7, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
    }, gui)

    -- 中心竖排容器
    local wrap = new("Frame", {
        Size = UDim2.fromOffset(300, 180),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 61,
    }, splash)

    local scale = new("UIScale", { Scale = 0.86 }, wrap)

    -- 主名字
    local nameLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 84),
        Position = UDim2.new(0, 0, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        TextSize = 64,
        Text = "Berlin",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 62,
    }, wrap)
    local nameGrad = new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 240, 255)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 190, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 120, 230)),
        }),
    }, nameLbl)

    -- 名字下方细线
    local line = new("Frame", {
        Size = UDim2.new(0, 0, 0, 2),
        Position = UDim2.new(0.5, 0, 0, 112),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = C.accentHi,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 62,
    }, wrap)
    corner(line, 1)
    local lineGrad = new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, line)

    -- 副标题
    local sub = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 124),
        BackgroundTransparency = 1,
        Font = FONT,
        TextSize = 12,
        Text = "学乱 · GAKURAN  ·  MOBILE  ·  v2.0",
        TextColor3 = C.dim,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 62,
    }, wrap)

    -- 载入条
    local barBg = new("Frame", {
        Size = UDim2.fromOffset(160, 3),
        Position = UDim2.new(0.5, 0, 0, 154),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(20, 40, 70),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 62,
    }, wrap)
    corner(barBg, 2)

    local barFill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.accentHi,
        BorderSizePixel = 0,
        ZIndex = 63,
    }, barBg)
    corner(barFill, 2)

    -- 动画序列
    task.spawn(function()
        tween(splash, 0.28, { BackgroundTransparency = 0.06 })
        tween(nameLbl, 0.45, { TextTransparency = 0 })
        tween(scale, 0.55, { Scale = 1 })
        task.wait(0.22)
        tween(line, 0.4, { Size = UDim2.new(0, 210, 0, 2), BackgroundTransparency = 0.15 })
        tween(sub, 0.4, { TextTransparency = 0.08 })
        tween(barBg, 0.3, { BackgroundTransparency = 0.25 })
        tween(barFill, 0.85, { Size = UDim2.new(1, 0, 1, 0) })

        task.wait(1.05)

        -- 淡出
        tween(splash, 0.32, { BackgroundTransparency = 1 })
        tween(nameLbl, 0.28, { TextTransparency = 1 })
        tween(sub, 0.28, { TextTransparency = 1 })
        tween(line, 0.28, { BackgroundTransparency = 1 })
        tween(barBg, 0.28, { BackgroundTransparency = 1 })
        tween(barFill, 0.28, { BackgroundTransparency = 1 })
        tween(scale, 0.5, { Scale = 1.08 })

        task.wait(0.36)
        if splash then splash:Destroy() end
        statusLabel.Text = "已注入 · Berlin · 学乱 v2.0"
        openPanel()
    end)
end

playSplash()
print("[Berlin] v2.0 loaded | PlaceId =", game.PlaceId)
