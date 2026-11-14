--[[==============================================================
      BERLIN · 全通道嗅探   v3
      记录 __namecall 上的所有调用，不只 FireServer。
      红色 = Remote 相关（真正发给服务器的）
      灰色 = 其他（本地对象操作，多半可以忽略）

      用法：执行后，在游戏里按左键攻击、右键、F、Q、空格，各按几次。
            看列表里出现什么，把红色那几条发我。
==============================================================]]--

local Players = game:GetService("Players")
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

local hookmm = api("hookmetamethod")
local getncm = api("getnamecallmethod")

-- ===== 界面 =====
local pg = LP:FindFirstChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "N_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okp or not gui.Parent then
    gui.Parent = pg or LP:WaitForChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.92, 0, 0.78, 0)
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
title.Text = "全通道嗅探 · 等待调用"
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
layout.Padding = UDim.new(0, 3)
layout.Parent = scroll

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 34)
footer.Position = UDim2.new(0, 10, 1, -38)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextColor3 = Color3.fromRGB(150, 185, 225)
footer.Text = "现在按：左键攻击 / 右键 / F / Q / 空格，各按几次"
footer.Parent = panel

-- ===== 噪音过滤 =====
local NOISE = {
    __index = true, __newindex = true, __tostring = true, __eq = true, __lt = true,
    __add = true, __sub = true, __mul = true, __div = true, __concat = true, __len = true,
    FindFirstChild = true, FindFirstChildOfClass = true, FindFirstChildWhichIsA = true,
    FindFirstAncestor = true, FindFirstAncestorOfClass = true,
    GetChildren = true, GetDescendants = true, GetAttribute = true,
    IsA = true, IsDescendantOf = true, GetService = true, WaitForChild = true,
    Destroy = true, Clone = true, GetPropertyChangedSignal = true,
    Connect = true, Once = true, Disconnect = true, Wait = true,
    GetPlayers = true, GetPlayerFromCharacter = true, GetMouseLocation = true,
    GetFocusedTextBox = true, GetTouches = true, IsKeyDown = true,
    GetBoundingBox = true, GetPivot = true, GetMass = true, GetRelativeCFrame = true,
    GetLargestDescendant = true, Clone = true,
}

local seen = {}
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        if #v > 24 then v = v:sub(1, 24) .. "…" end
        return '"' .. v .. '"'
    elseif t == "number" then
        return tostring(math.floor(v * 100) / 100)
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Vector3" then
        return string.format("V3(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.0f,%.0f,%.0f)", p.X, p.Y, p.Z)
    elseif t == "Instance" then
        return v.Name
    elseif t == "table" and depth < 2 then
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 4 then break end
            table.insert(parts, tostring(k) .. "=" .. ser(vv, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

local REMOTE_METHODS = { FireServer = true, InvokeServer = true, Fire = true, Invoke = true }

local count = 0
local remoteCount = 0

local function addRow(method, self, args, isRemote)
    local cls = "?"
    local nm = "?"
    pcall(function()
        cls = self.ClassName
        nm = self.Name
    end)

    local parts = {}
    for i = 1, #args do parts[i] = ser(args[i]) end
    local argStr = #parts > 0 and table.concat(parts, ", ") or ""

    local line = Instance.new("TextLabel")
    line.Size = UDim2.new(1, -6, 0, isRemote and 34 or 16)
    line.BackgroundTransparency = 1
    line.Font = Enum.Font.Code
    line.TextSize = 11
    line.TextWrapped = true
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.TextYAlignment = Enum.TextYAlignment.Top
    line.TextColor3 = isRemote and Color3.fromRGB(140, 255, 190) or Color3.fromRGB(130, 150, 180)
    line.Text = isRemote
        and string.format(" ▶ %s:%s(%s)", nm, method, argStr)
        or string.format("   %s:%s", nm, method)
    line.LayoutOrder = -os.clock()
    line.Parent = scroll

    count = count + 1
    if isRemote then
        remoteCount = remoteCount + 1
        title.Text = string.format("全通道 · %d 条 / Remote %d 条 · 最近：%s:%s", count, remoteCount, nm, method)
        print(string.format("[REMOTE] %s:%s | %s", nm, method, argStr))
    end

    -- 只留最近 120 行
    local kids = {}
    for _, ch in ipairs(scroll:GetChildren()) do
        if ch:IsA("TextLabel") then table.insert(kids, ch) end
    end
    if #kids > 120 then
        table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        for i = 1, #kids - 120 do kids[i]:Destroy() end
    end
end

-- ===== hook =====
local hooked = false

if type(hookmm) == "function" and type(getncm) == "function" then
    local ok1 = pcall(function()
        local old
        old = hookmm(game, "__namecall", function(self, ...)
            local m = getncm()
            if m and not NOISE[m] then
                local isR = false
                pcall(function()
                    isR = REMOTE_METHODS[m] and (self:IsA("RemoteEvent")
                        or self:IsA("UnreliableRemoteEvent")
                        or self:IsA("RemoteFunction")
                        or self:IsA("BindableEvent"))
                end)

                -- 去重：同一个 key 1 秒内只记一次
                local now = os.clock()
                local key = m .. "|" .. tostring(isR)
                if isR or not seen[key] or now - seen[key] > 1 then
                    seen[key] = now
                    local args = { ... }
                    pcall(addRow, m, self, args, isR)
                end
            end
            return old(self, ...)
        end)
    end)
    hooked = ok1
end

if hooked then
    footer.Text = "hook 已生效。按左键攻击 / 右键 / F / Q / 空格，看绿色行"
    print("[SNIFF3] hooked OK")
else
    footer.Text = "hook 失败"
end

-- ===== 同时记录 UserInputService 的按键，用来对照 =====
task.spawn(function()
    local UIS = game:GetService("UserInputService")
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(255, 210, 120)
        lbl.Text = "   [输入] " .. tostring(input.KeyCode) .. " / " .. tostring(input.UserInputType)
        lbl.LayoutOrder = -os.clock()
        lbl.Parent = scroll
    end)
end)
