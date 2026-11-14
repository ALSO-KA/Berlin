--[[==============================================================
      BERLIN · LOADER  (一行式入口)
      用法：先用长代码执行一次本文件，之后每次只要一行：
            loadstring(game:HttpGet("你的Loader地址"))()
      或者更短（已缓存到本地时）：
            loadstring(readfile("Berlin.lua"))()
==============================================================]]--

-- ↓↓↓ 已按你的仓库预填好，换仓库才需要改
local USER = "ALSO-KA"
local REPO = "Berlin"
local BRANCH = "main"
local FILE = "Berlin.lua"

local SOURCES = {
    string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", USER, REPO, BRANCH, FILE),
    string.format("https://cdn.jsdelivr.net/gh/%s/%s@%s/%s", USER, REPO, BRANCH, FILE),
    string.format("https://raw.gitmirror.com/%s/%s/%s/%s", USER, REPO, BRANCH, FILE),
    string.format("https://ghproxy.net/https://raw.githubusercontent.com/%s/%s/%s/%s", USER, REPO, BRANCH, FILE),
    string.format("https://gitee.com/%s/%s/raw/%s/%s", USER, REPO, BRANCH, FILE),
}

-- ================= 以下不用改 =================
local CACHE_FILE = "Berlin.lua"

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(body) == "string" and #body > 2000 then
        return body
    end
    -- 备用请求通道
    local req = rawget(getfenv(0), "request") or (syn and syn.request)
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 2000 then
            return res.Body
        end
    end
    return nil
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 5,
        })
    end)
    print("[" .. title .. "] " .. text)
end

-- 1) 依次尝试各个源
local src
for i, url in ipairs(SOURCES) do
    local body = httpGet(url)
    -- GitHub 404 页面会返回 "404: Not Found"
    if body and not string.find(body, "404: Not Found", 1, true) then
        src = body
        print("[Berlin] 源 " .. i .. " 拉取成功：" .. url)
        break
    end
end

-- 2) 全部失败就退回本地缓存
if not src then
    local rf = rawget(getfenv(0), "readfile")
    local isf = rawget(getfenv(0), "isfile")
    if rf and isf and pcall(isfile, CACHE_FILE) then
        local ok, cached = pcall(rf, CACHE_FILE)
        if ok and type(cached) == "string" and #cached > 2000 then
            src = cached
            notify("Berlin", "网络失败，已用本地缓存启动")
        end
    end
end

if not src then
    notify("Berlin", "加载失败：检查 USER/REPO 是否改对，或换网络重试")
    return
end

-- 3) 缓存到本地，下次可离线一行启动
local wf = rawget(getfenv(0), "writefile")
if wf then pcall(wf, CACHE_FILE, src) end

-- 4) 执行
local fn, err = loadstring(src)
if not fn then
    notify("Berlin", "语法错误：" .. tostring(err))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    notify("Berlin", "运行错误：" .. tostring(runErr))
end
