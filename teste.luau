-- ========================================================
-- 1. IMPORTAÇÃO DOS SERVIÇOS DO ROBLOX
-- ========================================================
local e = game:GetService("Players")
local r = game:GetService("Workspace")
local y = game:GetService("RunService")
local a = game:GetService("HttpService")
local c = game:GetService("CoreGui")
local w = game:GetService("UserInputService")
local j = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local o = e.LocalPlayer

local req = (syn and syn.request) or http_request or request or HttpPost

-- ========================================================
-- 2. CONFIGURAÇÕES PADRÃO E GESTÃO DE FICHEIRO JSON
-- ========================================================
local h = {W="", P="", I=0, S=0, E=true, WH=false, AH=false, AHT=60, PC=1}
local cfgFile = "DiceRadar_Config.json"

if isfile and readfile and isfile(cfgFile) then
    pcall(function()
        local saved = a:JSONDecode(readfile(cfgFile))
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                h[k] = v
            end
        end
    end)
end

h.I = tonumber(h.I) or 0
h.S = tonumber(h.S) or 0
h.AHT = tonumber(h.AHT) or 60
h.PC = tonumber(h.PC) or 1

local X = {} 
local Z = {} 
local cachedEggs = {} 
local b = 0  
local isHopping = false 
local lastReset = os.clock()
local lastValidEggTime = os.clock() 

-- ========================================================
-- 3. CONSTRUÇÃO DA INTERFACE GRÁFICA (GUI)
-- ========================================================
if c:FindFirstChild("DiceRadarGUI") then c.DiceRadarGUI:Destroy() end

local gui = Instance.new("ScreenGui", c)
gui.Name = "DiceRadarGUI"

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 250, 0, 95)
main.AnchorPoint = Vector2.new(0, 0)
main.Position = UDim2.new(0, 20, 0, 20)
main.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true 
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", main)
stk.Color = Color3.fromRGB(0, 195, 255)
stk.Thickness = 1.5

local top = Instance.new("Frame", main)
top.Size = UDim2.new(1, 0, 0, 30)
top.BackgroundTransparency = 1
local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(1, -10, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Radar & Webhook (Clique abaixo)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local cont = Instance.new("ScrollingFrame", main)
cont.Size = UDim2.new(1, 0, 1, -95)
cont.Position = UDim2.new(0, 0, 0, 95)
cont.BackgroundTransparency = 1
cont.ScrollBarThickness = 2
cont.Visible = false
local lay = Instance.new("UIListLayout", cont)
lay.Padding = UDim.new(0, 5)
lay.SortOrder = Enum.SortOrder.LayoutOrder

local function addBox(txt, val, cb)
    local f = Instance.new("Frame", cont)
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -10, 0, 15)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    local bx = Instance.new("TextBox", f)
    bx.Size = UDim2.new(1, -20, 0, 20)
    bx.Position = UDim2.new(0, 10, 0, 18)
    bx.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
    bx.TextColor3 = Color3.fromRGB(255, 255, 255)
    bx.Font = Enum.Font.Gotham
    bx.TextSize = 11
    bx.Text = tostring(val)
    Instance.new("UICorner", bx).CornerRadius = UDim.new(0, 4)
    bx.FocusLost:Connect(function() cb(bx.Text) end)
end

local function addTog(txt, val, cb)
    local f = Instance.new("Frame", cont)
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -50, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0, 30, 0, 16)
    btn.Position = UDim2.new(1, -40, 0.5, -8)
    btn.BackgroundColor3 = val and Color3.fromRGB(0, 195, 255) or Color3.fromRGB(50, 50, 50)
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local cr = Instance.new("Frame", btn)
    cr.Size = UDim2.new(0, 14, 0, 14)
    cr.Position = val and UDim2.new(1, -15, 0, 1) or UDim2.new(0, 1, 0, 1)
    cr.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", cr).CornerRadius = UDim.new(1, 0)
    btn.MouseButton1Click:Connect(function()
        val = not val
        btn.BackgroundColor3 = val and Color3.fromRGB(0, 195, 255) or Color3.fromRGB(50, 50, 50)
        cr.Position = val and UDim2.new(1, -15, 0, 1) or UDim2.new(0, 1, 0, 1)
        cb(val)
    end)
end

local function addBtn(txt, cb)
    local f = Instance.new("Frame", cont)
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, -20, 1, 0)
    btn.Position = UDim2.new(0, 10, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(0, 195, 255)
    btn.TextColor3 = Color3.fromRGB(20, 24, 34)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = txt
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(cb)
end

local stat = Instance.new("TextButton", main)
stat.Size = UDim2.new(1, -20, 0, 60)
stat.Position = UDim2.new(0, 10, 0, 30)
stat.BackgroundTransparency = 1
stat.AutoButtonColor = false
stat.Text = "Status: Waiting...\nOvos no Mapa: 0\nValidos: 0 | Melhor: $0/s"
stat.TextColor3 = Color3.fromRGB(0, 255, 160)
stat.Font = Enum.Font.GothamBold
stat.TextSize = 14
stat.TextXAlignment = Enum.TextXAlignment.Left
stat.TextYAlignment = Enum.TextYAlignment.Top
stat.TextWrapped = true

local isMinimized = true
stat.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        main.Size = UDim2.new(0, 250, 0, 95)
        cont.Visible = false
    else
        main.Size = UDim2.new(0, 250, 0, 550)
        cont.Visible = true
    end
end)

addBox("Webhook URL", h.W, function(v) h.W = v end)
addBox("Ping Discord ID", h.P, function(v) h.P = v end)
addBox("Min Real Income ($/s)", h.I, function(v) h.I = tonumber(v) or 0 end)
addBox("Min Scale ou Kg", h.S, function(v) h.S = tonumber(v) or 0 end)
addBox("Auto Hop Timer (s)", h.AHT, function(v) h.AHT = tonumber(v) or 60 end)

addTog("Enable ESP", h.E, function(v) 
    h.E = v 
    for k, esp in pairs(Z) do
        if esp.B then pcall(function() esp.B.Enabled = v end) end
    end
end)

addTog("Enable Webhooks", h.WH, function(v) h.WH = v end)
addTog("Auto Server Hop", h.AH, function(v) 
    h.AH = v 
    lastValidEggTime = os.clock() 
end)

local fPC = Instance.new("Frame", cont)
fPC.Size = UDim2.new(1, 0, 0, 30)
fPC.BackgroundTransparency = 1
local btnPC = Instance.new("TextButton", fPC)
btnPC.Size = UDim2.new(1, -20, 1, 0)
btnPC.Position = UDim2.new(0, 10, 0, 0)
btnPC.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
btnPC.TextColor3 = Color3.fromRGB(20, 24, 34)
btnPC.Font = Enum.Font.GothamBold
btnPC.TextSize = 12
btnPC.Text = "Buscar: " .. tostring(h.PC) .. " Jogador(es)"
Instance.new("UICorner", btnPC).CornerRadius = UDim.new(0, 4)
btnPC.MouseButton1Click:Connect(function()
    h.PC = (h.PC == 1) and 2 or 1
    btnPC.Text = "Buscar: " .. tostring(h.PC) .. " Jogador(es)"
end)

local function formatNumber(n)
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

-- V1: NOVO BOTÃO DE TESTE DE WEBHOOK
addBtn("Testar Webhook (V1)", function()
    if h.W == "" or not req then return end
    
    local playerName = o.Name
    local placeId = game.PlaceId
    local jobId = game.JobId
    local joinLink = "https://darling-liger-02e311.netlify.app/index.html?placeId=" .. tostring(placeId) .. "&jobId=" .. tostring(jobId)

    local eggList = {}
    for u, d in pairs(cachedEggs) do
        table.insert(eggList, d)
    end
    table.sort(eggList, function(a, b) return (a.R or 0) > (b.R or 0) end)
    
    local eggString = ""
    local maxList = 15
    for i, d in ipairs(eggList) do
        if i > maxList then 
            eggString = eggString .. string.format("\n*... e mais %d ovos escondidos*", #eggList - maxList)
            break 
        end
        eggString = eggString .. string.format("• **%s** (%s) | $%s/s\n", d.C, d.P, formatNumber(d.R))
    end
    
    if #eggList == 0 then
        eggString = "Nenhum ovo carregado no mapa no momento."
    end

    local m = ""
    if h.P ~= "" then 
        m = "Teste de Ping do Radar! <@"..h.P..">" 
    else
        m = "Teste de Ping do Radar!"
    end
    
    local E = {{
        title = "✅ Conexão Estabelecida!",
        description = "O Webhook do Dice Radar está configurado.\n\n**📋 Top Ovos no Mapa Atual:**\n" .. eggString,
        url = joinLink,
        color = 65352,
        fields = {
            {name = "👤 Conta Testando", value = "**" .. playerName .. "**", inline = true},
            {name = "🔗 Servidor Atual", value = "[Clique para Join (Netlify)](" .. joinLink .. ")", inline = true},
        }
    }}
    
    pcall(function()
        req({Url=h.W, Method="POST", Headers={["Content-Type"]="application/json"}, Body=a:JSONEncode({content=m, embeds=E})})
    end)
end)

addBtn("Salvar Configurações", function()
    if writefile then
        pcall(function()
            writefile(cfgFile, a:JSONEncode(h))
        end)
    end
end)

-- ========================================================
-- 4. SISTEMA DE SERVER HOP
-- ========================================================
local function doServerHop()
    if isHopping then return end
    isHopping = true 
    
    pcall(function()
        if stat then stat.Text = "Status: Procurando servidores (Modo Rápido)..." end
        
        local baseUrl = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
        local cursor = ""
        local availableServers = {}
        local pagesLoaded = 0
        local maxPages = 30
        
        while pagesLoaded < maxPages do
            local currentUrl = baseUrl
            if cursor ~= "" then
                currentUrl = currentUrl .. "&cursor=" .. cursor
            end
            currentUrl = currentUrl .. "&_nocache=" .. tostring(os.clock() + math.random(10000, 99999))
            
            local success, result = pcall(function() return game:HttpGet(currentUrl) end)
            
            if not success or not result then
                if stat then stat.Text = "Status: Roblox limitou a busca. Pausa de 1s..." end
                task.wait(1)
                continue
            end
            
            local data = a:JSONDecode(result)
            if data and data
