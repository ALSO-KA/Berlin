--[[==============================================================
      BERLIN · REMOTE 嗅探器
      原理：Roblox 客户端拿不到服务器内部数据，但能抓到本机
            发给服务器的 Remote 请求。抓一次，之后就能直接重放，
            不再需要模拟鼠标键盘。

      用法：进游戏执行 → 手动打一拳、格挡一次、闪避一次
            → 屏幕上会列出所有 FireServer 调用和参数
            → 把对应那几条发我，我写进 Berlin 做直调模式。
==============================================================]]--

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

if not game:IsLoaded() then game.Loaded:Wait() end

local hookmm = rawget(getfenv(0), "hookmetamethod")
local getncm = rawget(getfenv(0), "getnamecallmethod")

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
panel.Size = UDim2.new(0.9, 0, 0.7, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Parent = gui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 170, 255); s.Thickness = 1.5; s.Transparency = 0.3; s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.Text = "Berlin 嗅探器 · 等待 Remote 调用"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -92)
scroll.Position = UDim2.new(0, 10, 0, 48)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 150, 240)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
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
footer.Text = "现在去手动打一拳 / 格挡一次 / 闪避一次"
footer.Parent = panel

-- ===== 参数序列化 =====
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        if #v > 40 then v = v:sub(1, 40) .. "…" end
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
        local parts = {}
        local n = 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 6 then break end
            table.insert(parts, tostring(k) .. "=" .. ser(vv, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

-- ===== 记录 =====
local records = {}
local MAX_SHOW = 40

local function addRow(remote, args, isUnreliable)
    local name = remote:GetFullName()
    local argStr = ""
    for i = 1, select("#", table.unpack(args)) do
        argStr = argStr .. (i > 1 and ", " or "") .. ser(args[i])
    end
    if argStr == "" then argStr = "<无参数>" end

    local rec = {
        name = name,
        shortName = remote.Name,
        args = argStr,
        t = os.clock(),
    }
    table.insert(records, 1, rec)
    if #records > MAX_SHOW then table.remove(records, MAX_SHOW + 1) end

    title.Text = string.format("Berlin 嗅探器 · 已记录 %d 条  （最近：%s）", #records, remote.Name)
    print(string.format("[SNIFF] %s | %s | %s", name, argStr, isUnreliable and "Unreliable" or ""))

    local line = Instance.new("TextButton")
    line.Size = UDim2.new(1, -6, 0, 46)
    line.BackgroundColor3 = Color3.fromRGB(22, 44, 84)
    line.BackgroundTransparency = 0.3
    line.BorderSizePixel = 0
    line.AutoButtonColor = false
    line.Font = Enum.Font.Code
    line.TextSize = 11
    line.TextWrapped = true
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.TextYAlignment = Enum.TextYAlignment.Top
    line.TextColor3 = Color3.fromRGB(190, 225, 255)
    line.Text = string.format(" %s\n %s", name, argStr)
    line.LayoutOrder = -os.clock()
    line.Parent = scroll
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = line
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 8); p.PaddingTop = UDim.new(0, 4)
        p.Parent = line
    end
    line.MouseButton1Click:Connect(function()
        footer.Text = "重放：" .. remote.Name
        local raw = rawget(getfenv(0), "getrawmetatable")
        pcall(function()
            remote:FireServer(table.unpack(args))
        end)
    end)

    -- 只保留最近 40 行 UI
    local kids = {}
    for _, ch in ipairs(scroll:GetChildren()) do
        if ch:IsA("TextButton") then table.insert(kids, ch) end
    end
    if #kids > MAX_SHOW then
        table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        for i = 1, #kids - MAX_SHOW do kids[i]:Destroy() end
    end
end

-- ===== 安装 hook =====
local installed = false

if hookmm and getncm then
    local old
    local function okInstall()
        local success, err = pcall(function()
            old = hookmm(game, "__namecall", function(self, ...)
                local method = getncm()
                if method == "FireServer" then
                    local isRemote = false
                    pcall(function()
                        isRemote = self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")
                    end)
                    if isRemote then
                        local args = { ... }
                        pcall(addRow, self, args, false)
                    end
                end
                return old(self, ...)
            end)
        end)
        return success, err
    end
    local success = okInstall()
    if success then
        installed = true
        title.Text = "Berlin 嗅探器 · hook 已装好，等你操作"
    else
        title.Text = "hook 安装失败，执行器不支持 hookmetamethod"
    end
else
    title.Text = "执行器缺少 hookmetamethod / getnamecallmethod"
    footer.Text = "把你的执行器名字告诉我，我换一种抓法"
end

-- ===== 兜底：枚举所有 Remote 名字 =====
task.spawn(function()
    task.wait(2)
    local list = {}
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") or d:IsA("RemoteFunction") then
            table.insert(list, d:GetFullName())
        end
    end
    print("[SNIFF] 共发现 " .. #list .. " 个 Remote：")
    for i, n in ipairs(list) do
        if i > 120 then break end
        print("  " .. n)
    end
end)
