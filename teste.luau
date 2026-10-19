-- ========================================================
-- RADAR V13 (HALLOWEEN DEFINITIVE PATCH + FULL ALIASES FIX)
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
-- 3. CONSTRUÇÃO DA INTERFACE GRÁFICA (GUI) - MINIMIZÁVEL
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

addBtn("Testar Webhook (V20)", function()
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
            if data and data.data then
                for _, v in ipairs(data.data) do
                    if type(v) == "table" and v.id ~= game.JobId and v.playing and v.maxPlayers and v.playing == h.PC then
                        table.insert(availableServers, v.id)
                    end
                end
                
                if #availableServers >= 8 then
                    break
                end
                
                if data.nextPageCursor then
                    cursor = data.nextPageCursor
                    pagesLoaded = pagesLoaded + 1
                else
                    break
                end
            else
                break
            end
        end
        
        if #availableServers > 0 then
            math.randomseed(os.clock())
            local randomServerId = availableServers[math.random(1, #availableServers)]
            
            if stat then stat.Text = "Status: Teleportando..." end
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServerId, o)
            
            task.delay(8, function()
                isHopping = false
                lastValidEggTime = os.clock()
            end)
            return
        end
        
        isHopping = false
        if stat then stat.Text = "Status: Erro ao achar servidor. Tentando de novo..." end
    end)
end

addBtn("Server Hop (Servidor Vazio)", doServerHop)

-- ========================================================
-- 5. CARREGAMENTO DOS MÓDULOS INTERNOS DO JOGO
-- ========================================================
local s = nil pcall(function() s = require(j:WaitForChild("Client", 5):WaitForChild("EggState", 5)) end)
if not s then pcall(function() s = require(j.Client.EggState) end) end

local pUtil = nil pcall(function() pUtil = require(j:WaitForChild("Shared", 5):WaitForChild("Util", 5):WaitForChild("AssetItems", 5)) end)
if not pUtil then pcall(function() pUtil = require(j.Shared.Util.AssetItems) end) end

local AssetEarnings = nil pcall(function() AssetEarnings = require(j:WaitForChild("Shared", 5):WaitForChild("Util", 5):WaitForChild("AssetEarnings", 5)) end)
if not AssetEarnings then pcall(function() AssetEarnings = require(j.Shared.Util.AssetEarnings) end) end

local mutModule = nil pcall(function() mutModule = require(j:WaitForChild("Shared", 5):WaitForChild("Modules", 5):WaitForChild("Mutations", 5)) end)
if not mutModule then pcall(function() mutModule = require(j.Shared.Modules.Mutations) end) end

local hwPets = nil pcall(function() hwPets = require(j:FindFirstChild("HalloweenPets", true)) end)
local assetsMod = nil pcall(function() assetsMod = require(j:FindFirstChild("Assets", true)) end)

-- ========================================================
-- 6. EXTRAÇÃO INTELIGENTE DE RARIDADE DOS OVOS
-- ========================================================
local function getEggRarity(cat, rawModel, rec)
    local rar = "Unknown"
    if rawModel then 
        rar = rawModel:GetAttribute("Rarity") or rawModel:GetAttribute("RarityTier") or rawModel:GetAttribute("Tier") or rar 
    end
    if rar == "Unknown" and rec and rec.Rarity then 
        rar = rec.Rarity 
    end
    if type(rar) == "table" then 
        rar = rar.DisplayName or rar.Name or rar._id or "Unknown" 
    end
    if rar == "Unknown" then
        pcall(function()
            if pUtil and pUtil.Assets and pUtil.Assets[cat] then
                local ast = pUtil.Assets[cat]
                local rData = ast.Rarity or (ast.Egg and ast.Egg.Rarity)
                if type(rData) == "table" then 
                    rar = rData.DisplayName or rData.Name or rData._id or "Unknown"
                elseif type(rData) == "string" then 
                    rar = rData 
                end
            end
        end)
    end
    rar = tostring(rar)
    
    local searchStr = string.lower(string.format("%s %s %s", tostring(cat), tostring(rec and rec.Uid or ""), tostring(rawModel and rawModel.Name or "")))
    local lowerRar = string.lower(rar)
    
    local function checkMatch(str)
        if string.find(str, "divine") then return "Divine" end
        if string.find(str, "eternal") then return "Eternal" end
        if string.find(str, "secret") then return "Secret" end
        if string.find(str, "cosmic") then return "Cosmic" end
        if string.find(str, "mythic") then return "Mythic" end
        if string.find(str, "legendary") then return "Legendary" end
        if string.find(str, "epic") then return "Epic" end
        if string.find(str, "rare") then return "Rare" end
        if string.find(str, "uncommon") then return "Uncommon" end
        if string.find(str, "common") then return "Common" end
        return nil
    end

    local match = checkMatch(lowerRar)
    if match then return match end
    match = checkMatch(searchStr)
    if match then return match end
    
    if string.find(searchStr, "nightflame") or string.find(searchStr, "unicornegg") or string.find(searchStr, "unicorn egg") or string.find(searchStr, "shatteredcolossus") or string.find(searchStr, "kitsune") or string.find(searchStr, "elmaja") or string.find(searchStr, "el maja") then return "Divine" end
    if string.find(searchStr, "gorillaking") or string.find(searchStr, "gorilla king") or string.find(searchStr, "lunardragon") or string.find(searchStr, "lunar dragon") or string.find(searchStr, "onitiger") or string.find(searchStr, "oni tiger") or string.find(searchStr, "mosasaurus") then return "Eternal" end
    if string.find(searchStr, "mutantshark") or string.find(searchStr, "mutant shark") or string.find(searchStr, "skeletonboss") or string.find(searchStr, "skeleton boss") or string.find(searchStr, "stagegg") or string.find(searchStr, "stag egg") or string.find(searchStr, "cosmicdragon") or string.find(searchStr, "cosmic dragon") or string.find(searchStr, "trex") or string.find(searchStr, "t-rex") or string.find(searchStr, "tralaledon") or string.find(searchStr, "kraken") then return "Secret" end
    if string.find(searchStr, "saturnita") or string.find(searchStr, "saturno") or string.find(searchStr, "mantaris") or string.find(searchStr, "mantis") or string.find(searchStr, "moth") or string.find(searchStr, "imp") or string.find(searchStr, "rhinotaur") or string.find(searchStr, "snowyowl") or string.find(searchStr, "snowy owl") or string.find(searchStr, "koiegg") or string.find(searchStr, "koi egg") or string.find(searchStr, "triceratops") or string.find(searchStr, "bronto") or string.find(searchStr, "whaleshark") or string.find(searchStr, "whale shark") or string.find(searchStr, "belugawhale") or string.find(searchStr, "beluga whale") then return "Cosmic" end
    if string.find(searchStr, "bladehide") or string.find(searchStr, "redpanda") or string.find(searchStr, "red panda") or string.find(searchStr, "cosmicgorilla") or string.find(searchStr, "cosmic gorilla") or string.find(searchStr, "ankylosaurus") or string.find(searchStr, "orca") then return "Mythic" end
    if string.find(searchStr, "spideron") or string.find(searchStr, "crustacia") or string.find(searchStr, "salamander") or string.find(searchStr, "cosmicgecko") or string.find(searchStr, "cosmic gecko") or string.find(searchStr, "pterodactyl") or string.find(searchStr, "sharkegg") or string.find(searchStr, "shark egg") then return "Legendary" end
    if string.find(searchStr, "crane") or string.find(searchStr, "centapede") or string.find(searchStr, "swordfish") then return "Epic" end
    if string.find(searchStr, "dodo") or string.find(searchStr, "parrotfish") then return "Rare" end

    local income = tonumber(rec and rec.EarningRate or rec and rec.Income or rawModel and rawModel:GetAttribute("Income") or 0)
    if income and income >= 150000000 then return "Secret" end

    if rar ~= "Unknown" then return rar end
    return "Normal"
end

-- ========================================================
-- 7. SISTEMA DE DISCORD WEBHOOK (Notificações)
-- ========================================================
local function Wk(d)
    if not h.WH or h.W == "" or not req then return end

    local playerName = o.Name
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    local joinLink = "https://darling-liger-02e311.netlify.app/index.html?placeId=" .. tostring(placeId) .. "&jobId=" .. tostring(jobId)
    
    local m = ""
    if h.P ~= "" then 
        m = "**" .. playerName .. "** encontrou **" .. tostring(d.C) .. "** de **" .. formatNumber(d.R) ..  "** <@"..h.P..">" 
    else
        m = "**" .. playerName .. "** encontrou **" .. tostring(d.C) .. "** de **" .. formatNumber(d.R) ..  "** pega la"
    end
    
    local E = {{
        title = "🥚 Ovo Gigante DETECTADO!",
        url = joinLink,
        color = 65352,
        fields = {
            {name = "Categoria", value = d.C, inline = true},
            {name = "Area", value = d.A, inline = true},
            {name = "Raridade", value = d.Rar, inline = true},
            {name = "Tamanho", value = d.P, inline = true},
            {name = "Dinheiro/S", value = "$" .. formatNumber(d.R) .. "/s", inline = true},
            {name = "🔗 Link de Join Automático", value = "[Abrir Servidor](" .. joinLink .. ")", inline = false},
        }
    }}
    
    pcall(function()
        req({Url = h.W, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = a:JSONEncode({content = m, embeds = E})})
    end)
end

-- ========================================================
-- 8. SISTEMA DE ESP VISUAL (Apenas Texto - Sem Highlight)
-- ========================================================
local function Dk(u, m, d, isValid)
    if not m then return end
    
    local isVisible = h.E and isValid

    if Z[u] then 
        if Z[u].B and Z[u].B:FindFirstChild("TextLabel") then
            Z[u].B.TextLabel.Text = string.format("[%s]\n$%s/s | %s", d.C, formatNumber(d.R), d.P)
        end
        if Z[u].B then pcall(function() Z[u].B.Enabled = isVisible end) end
        return 
    end
    
    if not isVisible then return end
    
    local bb = Instance.new("BillboardGui", m)
    bb.Size = UDim2.new(0, 150, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Enabled = true
    
    local tl = Instance.new("TextLabel", bb)
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.Text = string.format("[%s]\n$%s/s | %s", d.C, formatNumber(d.R), d.P)
    tl.TextColor3 = Color3.fromRGB(0, 195, 255)
    tl.TextStrokeTransparency = 0.2
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 11
    
    Z[u] = {B = bb, M = m}
end

-- ========================================================
-- 9. LOOP PRINCIPAL DE VARREDURA DO MAPA (Radar Definitivo V13)
-- ========================================================
task.spawn(function()
    
    -- 🎃 BASE DE DADOS SUPREMA DE HALLOWEEN 🎃
    local HalloweenDB = {
        ["Hexed Pumpkin"] = {Base = 150000000, Rar = "Cosmic"},
        ["Graveyard Brute"] = {Base = 75000000, Rar = "Secret"},
        ["Toadstool"] = {Base = 1600000, Rar = "Mythic"},
        ["Haunted Scorpio"] = {Base = 30000000, Rar = "Cosmic"},
        ["Crowshade"] = {Base = 4500000, Rar = "Mythic"},
        ["Shelltide Voyager"] = {Base = 1600000000, Rar = "Eternal"},
        ["Halloween Gigantopithecus"] = {Base = 1500000000, Rar = "Eternal"},
        ["Werewolf"] = {Base = 1300000000, Rar = "Secret"},
        ["Mimic Chest"] = {Base = 600000, Rar = "Legendary"},
        ["Zombified Halloween Glyptodon"] = {Base = 800000000, Rar = "Secret"},
        ["Zombified Halloween Dunkleosteus"] = {Base = 4000000000, Rar = "Eternal"},
        ["BloodBloom"] = {Base = 450000000, Rar = "Secret"},
        ["Hooded Gerbil"] = {Base = 300000, Rar = "Legendary"},
        ["Ghost Reaper"] = {Base = 300000000, Rar = "Eternal"},
        ["Abomination Kong"] = {Base = 3500000000, Rar = "Eternal"},
        ["Patchwork Imp"] = {Base = 20000000, Rar = "Cosmic"},
        ["Voidseer Pumpkin"] = {Base = 14000000000, Rar = "Divine"},
        ["Halloween Terrorbird"] = {Base = 160000, Rar = "Mythic"},
        ["Halloween Dunkleosteus"] = {Base = 450000000, Rar = "Secret"},
        ["Zombified Halloween Terrorbird"] = {Base = 1100000000, Rar = "Secret"},
        ["Zombified Halloween Gigantopithecus"] = {Base = 6000000000, Rar = "Eternal"},
        ["Candlefang"] = {Base = 225000, Rar = "Mythic"},
        ["Jesterpop"] = {Base = 40000, Rar = "Legendary"},
        ["Whiskers"] = {Base = 2000, Rar = "Epic"},
        ["Zombified Halloween Sabertooth"] = {Base = 14000000000, Rar = "Divine"},
        ["Halloween Sabertooth"] = {Base = 7500000000, Rar = "Divine"},
        ["Halloween Glyptodon"] = {Base = 35000, Rar = "Legendary"},
        ["Spirit Knight"] = {Base = 3000000, Rar = "Cosmic"},
        ["Zombified Halloween Megatherium"] = {Base = 1400000000, Rar = "Secret"},
        ["Halloween Megatherium"] = {Base = 6000000, Rar = "Cosmic"},
    }

    -- 🔄 DICIONÁRIO DE SINÓNIMOS (ALIASES) COMPLETO 🔄
    local EggAliases = {
        ["Rotshroom"] = "Toadstool",
        ["Rotshroom Egg"] = "Toadstool",
        ["Dread Wolf"] = "Werewolf",
        ["Halloween Royal Mimic Egg"] = "Mimic Chest",
        ["Royal Mimic Egg"] = "Mimic Chest",
        ["Royal Mimic"] = "Mimic Chest",
        ["Frankenstein Kong Egg"] = "Abomination Kong",
        ["Quilted Imp Egg"] = "Patchwork Imp",
        ["SpiritKnight"] = "Spirit Knight",
    }

    while task.wait(1.5) do
        pcall(function()
            local act = 0
            local total = 0
            
            if os.clock() - lastReset >= 10 then
                b = 0
                lastReset = os.clock()
            end
            
            local allUids = {}
            local pModels = {}
            
            local function scanFolder(folder)
                if not folder then return end
                for _, v in ipairs(folder:GetChildren()) do
                    local uidAttr = v:GetAttribute("UID") or v:GetAttribute("Uid") or v:GetAttribute("EggUid") or v:GetAttribute("HalloweenEggUid") or v:GetAttribute("Id")
                    if not uidAttr and v.Name ~= "Model" and v.Name ~= "Part" then uidAttr = v.Name end
                    
                    if uidAttr then 
                        local uidStr = tostring(uidAttr)
                        pModels[uidStr] = v 
                        allUids[uidStr] = true
                    end
                end
            end
            
            scanFolder(r:FindFirstChild("AreaEggSlotsClient"))
            scanFolder(r:FindFirstChild("__DEBRIS"))
            
            for _, folder in ipairs(r:GetChildren()) do
                if folder:IsA("Folder") and string.find(string.lower(folder.Name), "eggslots") and folder.Name ~= "AreaEggSlotsClient" then
                    scanFolder(folder)
                end
            end

            local hwDimension = r:FindFirstChild("HalloweenDimension")
            if hwDimension then
                local worldEggs = hwDimension:FindFirstChild("WorldEggs")
                if worldEggs then
                    scanFolder(worldEggs)
                end
            end
            
            local records = {}
            if s then
                local st, fd = false, nil
                if s.ReadFieldEggs then st, fd = pcall(s.ReadFieldEggs)
                elseif s.SyncFieldEggs then st, fd = pcall(s.SyncFieldEggs) end
                
                if st and type(fd) == "table" then
                    local rawRec = fd.Records or fd
                    if type(rawRec) == "table" then
                        for k, rec in pairs(rawRec) do
                            if type(rec) == "table" then
                                local u = tostring(rec.Uid or rec.HalloweenEggUid or rec.Id or k)
                                records[u] = rec
                                allUids[u] = true 
                            end
                        end
                    end
                end
            end
            
            for u in pairs(allUids) do
                local rawModel = pModels[u]
                local rec = records[u] or {}
                
                total = total + 1
                
                if not cachedEggs[u] then
                    local rawCat = (rawModel and (rawModel:GetAttribute("Category") or rawModel:GetAttribute("AssetCategory") or rawModel:GetAttribute("ItemName"))) or rec.AssetCategory or rec.Category or rec.ItemName or "Egg"
                    local rawDisplayCat = (rawModel and (rawModel:GetAttribute("PreparedSourceName") or rawModel:GetAttribute("DisplayName"))) or rec.PreparedSourceName or rec.DisplayName or rawCat
                    
                    if rawDisplayCat == "Egg" and rawModel and rawModel.Name ~= "Model" and rawModel.Name ~= "Part" then 
                        if string.len(rawModel.Name) < 30 and not string.find(rawModel.Name, "_") then
                            rawDisplayCat = rawModel.Name 
                        end
                    end
                    
                    -- APLICA OS ALIASES DE NOME COMPLETO
                    local cat = EggAliases[rawCat] or rawCat
                    local displayCat = EggAliases[rawDisplayCat] or rawDisplayCat
                    local rName = rawModel and (EggAliases[rawModel.Name] or rawModel.Name)
                    
                    local area = (rawModel and (rawModel:GetAttribute("AreaId") or rawModel:GetAttribute("Area") or rawModel:GetAttribute("Zone"))) or rec.AreaId or rec.Zone or "Unknown"

                    local scale = tonumber((rawModel and (rawModel:GetAttribute("Scale") or rawModel:GetAttribute("AssetScale"))) or rec.Scale or rec.AssetScale)
                    if not scale and rawModel and rawModel:IsA("Model") then
                        pcall(function() scale = rawModel:GetScale() end)
                        if not scale or scale == 1 then
                            pcall(function()
                                local extents = rawModel:GetExtentsSize()
                                local maxAxis = math.max(extents.X, extents.Y, extents.Z)
                                if maxAxis > 5 then scale = maxAxis / 4.5 end
                            end)
                        end
                    end
                    scale = tonumber(scale) or 1
                    
                    local mAttr = (rawModel and (rawModel:GetAttribute("Mutations") or rawModel:GetAttribute("Mutation"))) or rec.Mutations or rec.Mutation
                    
                    local real, base = 0, 0
                    local rarity = "Unknown"
                    
                    -- 🚀 VERIFICAÇÃO NA BASE DE DADOS SUPREMA DE HALLOWEEN 🚀
                    local hwData = HalloweenDB[displayCat] or HalloweenDB[cat] or (rName and HalloweenDB[rName])
                    
                    if hwData then
                        base = hwData.Base
                        rarity = hwData.Rar
                    else
                        local tryNames = {displayCat, cat, rName}
                        for _, n in ipairs(tryNames) do
                            if not n or base > 0 then continue end
                            if hwPets and hwPets.Specs and hwPets.Specs[n] then
                                base = tonumber(hwPets.Specs[n].EarningRate) or 0
                            end
                            if base == 0 and assetsMod and assetsMod.Directory and assetsMod.Directory[n] then
                                base = tonumber(assetsMod.Directory[n].EarningRate) or 0
                            end
                            if base == 0 and pUtil and pUtil.Assets and pUtil.Assets.Directory and pUtil.Assets.Directory[n] then
                                base = tonumber(pUtil.Assets.Directory[n].EarningRate) or 0
                            end
                            if base == 0 and pUtil and pUtil.Assets and pUtil.Assets[n] then
                                base = tonumber(pUtil.Assets[n].EarningRate or (pUtil.Assets[n].Egg and pUtil.Assets[n].Egg.EarningRate)) or 0
                            end
                        end
                        
                        if base == 0 then
                            base = tonumber((rawModel and (rawModel:GetAttribute("Income") or rawModel:GetAttribute("EarningRate"))) or rec.Income or rec.EarningRate or rec.MoneyPerSecond) or 0
                            if base == 0 and type(rec.ItemData) == "table" then base = tonumber(rec.ItemData.MoneyPerSecond or rec.ItemData.Income) or 0 end
                        end
                        
                        rarity = getEggRarity(displayCat, rawModel, rec)
                    end
                    
                    base = (base == 0) and 1 or base
                    
                    -- Corrige apenas a escala usada na renda dos ovos de Halloween.
                    -- A escala exibida, filtros, mutacoes e demais sistemas permanecem iguais.
                    local incomeScale = scale
                    if hwData and rawModel and rawModel:IsA("Model") and rawModel:GetAttribute("HalloweenEggUid") ~= nil then
                        pcall(function()
                            local dataFolder = j:FindFirstChild("Data")
                            local petsModule = dataFolder and dataFolder:FindFirstChild("HalloweenPets")
                            if not petsModule then return end
                            local specs = require(petsModule).Specs
                            if type(specs) ~= "table" then return end
                            local sourceName = rawModel:GetAttribute("PreparedSourceName")
                            local spec = specs[displayCat] or specs[cat]
                            if type(spec) ~= "table" then
                                for key, entry in pairs(specs) do
                                    if type(entry) == "table" and ((sourceName and (entry.EggSource == sourceName or entry.EggModel == sourceName)) or entry.Id == displayCat or key == displayCat) then
                                        spec = entry
                                        break
                                    end
                                end
                            end
                            if type(spec) ~= "table" or type(spec.EggModel) ~= "string" then return end
                            local zone = tonumber(rawModel:GetAttribute("Zone"))
                            if zone ~= 1 and zone ~= 2 and zone ~= 3 then return end
                            local assetsFolder = j:FindFirstChild("Assets")
                            local modelsFolder = assetsFolder and assetsFolder:FindFirstChild("Models")
                            local eggsFolder = modelsFolder and modelsFolder:FindFirstChild("Eggs")
                            local template = eggsFolder and eggsFolder:FindFirstChild(spec.EggModel)
                            if not template or not template:IsA("Model") then return end
                            if math.abs(template:GetScale() - 1) > 0.000001 then return end
                            local size = template:GetExtentsSize()
                            local largestDimension = math.max(size.X, size.Y, size.Z)
                            local corrected = rawModel:GetScale() * largestDimension / (4.5 + zone)
                            if corrected > 0 and corrected < math.huge then incomeScale = corrected end
                        end)
                    end
                    local scaleMult = (incomeScale <= 5) and (incomeScale ^ 1.85) or (((incomeScale / 5) ^ 1.2) * 19.637875755794)
                    local mutMult = 1
                    if mutModule and mAttr then
                        pcall(function() mutMult = tonumber(mutModule.EarningsFor(mAttr)) or 1 end)
                    elseif type(mAttr) == "table" then
                        for _, m in pairs(mAttr) do
                            local val = (type(m) == "table" and tonumber(m.Multiplier or m.Value)) or tonumber(m) or 1.5
                            mutMult = mutMult * val
                        end
                    elseif mAttr then 
                        mutMult = 1.5 
                    end
                    
                    real = math.floor((base * scaleMult * mutMult) + 0.5)

                    if not hwData and AssetEarnings and AssetEarnings.MutationOnlyRatePerSecond then
                        local nativeReal = 0
                        pcall(function() nativeReal = tonumber(AssetEarnings.MutationOnlyRatePerSecond({Category = cat, Mutations = mAttr, Scale = scale})) or 0 end)
                        if nativeReal == 0 and displayCat ~= cat then
                            pcall(function() nativeReal = tonumber(AssetEarnings.MutationOnlyRatePerSecond({Category = displayCat, Mutations = mAttr, Scale = scale})) or 0 end)
                        end
                        if nativeReal > real then real = nativeReal end
                    end
                    
                    local pesoStr = string.format("%.1fx", scale)
                    local checkSize = scale
                    
                    cachedEggs[u] = {C=displayCat, A=area, S=scale, R=real, P=pesoStr, Rar=rarity, CS=checkSize}
                end
                
                local cData = cachedEggs[u]
                if cData.R > b then b = cData.R end
                
                local isValid = (cData.R >= h.I and cData.CS >= h.S)
                local d = {U=u, C=cData.C, A=cData.A, S=cData.S, R=cData.R, P=cData.P, Rar=cData.Rar}
                
                if isValid then
                    act = act + 1
                    if not X[u] then
                        X[u] = true
                        Wk(d) 
                    end
                end
                
                if rawModel then
                    local pModel = rawModel
                    if pModel:IsA("Folder") then
                        pModel = pModel:FindFirstChildWhichIsA("BasePart") or pModel:FindFirstChildWhichIsA("Model") or pModel
                    end
                    Dk(u, pModel, d, isValid)
                end
            end
            
            if act > 0 then
                lastValidEggTime = os.clock()
            elseif h.AH and (os.clock() - lastValidEggTime >= h.AHT) then
                task.spawn(doServerHop)
            end
            
            if stat then 
                if h.AH and act == 0 then
                    local tempoRestante = math.max(0, math.floor(h.AHT - (os.clock() - lastValidEggTime)))
                    stat.Text = string.format("Status: Hop em %ds...\nOvos no Mapa: %d\nValidos: %d | Melhor: $%s/s", tempoRestante, total, act, formatNumber(b))
                else
                    stat.Text = string.format("Status: Scanning...\nOvos no Mapa: %d\nValidos (Alvos): %d | Melhor: $%s/s", total, act, formatNumber(b)) 
                end
            end
            
            for k, v in pairs(Z) do
                if not allUids[k] or not v.M or not v.M.Parent then
                    if v.B then pcall(function() v.B:Destroy() end) end
                    Z[k] = nil
                end
            end
            for k in pairs(cachedEggs) do
                if not allUids[k] then
                    cachedEggs[k] = nil
                end
            end
            
        end)
    end
end)
