-- ========================================================
-- 1. IMPORTAÇÃO DOS SERVIÇOS DO ROBLOX
-- ========================================================
-- Obtemos os serviços essenciais do motor do Roblox para manipular jogadores, workspace, interface e pedidos HTTP.
local e = game:GetService("Players")
local r = game:GetService("Workspace")
local y = game:GetService("RunService")
local a = game:GetService("HttpService")
local c = game:GetService("CoreGui")
local w = game:GetService("UserInputService")
local j = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local o = e.LocalPlayer

-- Identifica a função de requisição HTTP disponível no executor atual (Synapse, Krnl, etc.)
local req = (syn and syn.request) or http_request or request or HttpPost

-- ========================================================
-- 2. CONFIGURAÇÕES PADRÃO E GESTÃO DE FICHEIRO JSON
-- ========================================================
-- Tabela com os valores padrão de configuração do radar (Webhook, Filtros, ESP e Auto Hop)
local h = {W="", P="", I=0, S=0, E=true, WH=false, AH=false, AHT=60}
local cfgFile = "DiceRadar_Config.json"

-- Se já existir um ficheiro de configuração guardado, lê e substitui os valores padrão
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

-- Blindagem para garantir que os valores numéricos são sempre lidos como números
h.I = tonumber(h.I) or 0
h.S = tonumber(h.S) or 0
h.AHT = tonumber(h.AHT) or 60

local X = {} -- Registo de ovos já enviados ao Webhook (para não repetir)
local Z = {} -- Registo dos elementos visuais ESP ativos no mapa
local b = 0  -- Maior rendimento encontrado no momento
local lastReset = os.clock()
local lastValidEggTime = os.clock() -- Temporizador para contagem do Auto Server Hop

-- ========================================================
-- 3. CONSTRUÇÃO DA INTERFACE GRÁFICA (GUI)
-- ========================================================
-- Destrói a interface anterior caso já esteja aberta para evitar duplicados
if c:FindFirstChild("DiceRadarGUI") then c.DiceRadarGUI:Destroy() end

local gui = Instance.new("ScreenGui", c)
gui.Name = "DiceRadarGUI"

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 250, 0, 515)
main.Position = UDim2.new(0, 20, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true -- Permite arrastar a janela pelo ecrã
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", main)
stk.Color = Color3.fromRGB(0, 195, 255)
stk.Thickness = 1.5

-- Barra de Título da Janela
local top = Instance.new("Frame", main)
top.Size = UDim2.new(1, 0, 0, 30)
top.BackgroundTransparency = 1
local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(1, -10, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Radar & Webhook"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

-- Área de Scroll para conter os botões e caixas de texto
local cont = Instance.new("ScrollingFrame", main)
cont.Size = UDim2.new(1, 0, 1, -35)
cont.Position = UDim2.new(0, 0, 0, 35)
cont.BackgroundTransparency = 1
cont.ScrollBarThickness = 2
local lay = Instance.new("UIListLayout", cont)
lay.Padding = UDim.new(0, 5)
lay.SortOrder = Enum.SortOrder.LayoutOrder

-- Função auxiliar para criar caixas de texto dinamicamente
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

-- Função auxiliar para criar botões de ligar/desligar (Toggles)
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

-- Função auxiliar para criar botões de ação
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

-- Label de Status em tempo real (mostra ovos detetados, válidos e melhor renda)
local stat = Instance.new("TextLabel", cont)
stat.Size = UDim2.new(1, -20, 0, 60)
stat.Position = UDim2.new(0, 10, 0, 0)
stat.BackgroundTransparency = 1
stat.Text = "Status: Waiting...\nOvos no Mapa: 0\nValidos: 0 | Melhor: $0/s"
stat.TextColor3 = Color3.fromRGB(0, 255, 160)
stat.Font = Enum.Font.GothamBold
stat.TextSize = 16
stat.TextXAlignment = Enum.TextXAlignment.Left
stat.TextYAlignment = Enum.TextYAlignment.Top
stat.TextWrapped = true

-- Registo dos controlos na interface
addBox("Webhook URL", h.W, function(v) h.W = v end)
addBox("Ping Discord ID", h.P, function(v) h.P = v end)
addBox("Min Real Income ($/s)", h.I, function(v) h.I = tonumber(v) or 0 end)
addBox("Min Scale ou Kg", h.S, function(v) h.S = tonumber(v) or 0 end)
addBox("Auto Hop Timer (s)", h.AHT, function(v) h.AHT = tonumber(v) or 60 end)

-- Botão de ligar/desligar o ESP (atualiza a visibilidade instantaneamente)
addTog("Enable ESP", h.E, function(v) 
    h.E = v 
    for k, esp in pairs(Z) do
        if esp.H then pcall(function() esp.H.Enabled = v end) end
        if esp.B then pcall(function() esp.B.Enabled = v end) end
    end
end)

addTog("Enable Webhooks", h.WH, function(v) h.WH = v end)
addTog("Auto Server Hop", h.AH, function(v) 
    h.AH = v 
    lastValidEggTime = os.clock() 
end)

-- Botão para testar o envio de mensagens para o Discord
addBtn("Testar Webhook", function()
    if h.W == "" or not req then return end
    local m = ""
    if h.P ~= "" then m = "Teste de Ping! <@"..h.P..">" end
    local E = {{
        title = "✅ Conexão Estabelecida!",
        description = "O Webhook do Dice Radar está a funcionar perfeitamente e pronto a detetar ovos.",
        color = 65352
    }}
    pcall(function()
        req({Url=h.W, Method="POST", Headers={["Content-Type"]="application/json"}, Body=a:JSONEncode({content=m, embeds=E})})
    end)
end)

-- Botão para salvar as preferências atuais no ficheiro JSON
addBtn("Salvar Configurações", function()
    if writefile then
        pcall(function()
            writefile(cfgFile, a:JSONEncode(h))
        end)
    end
end)

-- ========================================================
-- 4. SISTEMA DE SERVER HOP (Troca de Servidor Sem Cache)
-- ========================================================
local function doServerHop()
    pcall(function()
        if stat then stat.Text = "Status: Procurando servidor vazio..." end
        -- Utiliza _nocache dinâmico para forçar o Roblox a entregar uma lista atualizada de servidores
        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true&_nocache=" .. tostring(os.clock() + math.random(10000, 99999))
        
        local success, result = pcall(function() return game:HttpGet(url) end)
        if success and result then
            local data = a:JSONDecode(result)
            if data and data.data then
                local availableServers = {}
                for _, v in ipairs(data.data) do
                    -- Filtra apenas servidores válidos, diferentes do atual e com vagas abertas
                    if type(v) == "table" and v.id ~= game.JobId and v.playing and v.maxPlayers and v.playing < v.maxPlayers then
                        table.insert(availableServers, v.id)
                    end
                end
                
                if #availableServers > 0 then
                    math.randomseed(os.clock())
                    local randomServerId = availableServers[math.random(1, #availableServers)]
                    if stat then stat.Text = "Status: Teleportando..." end
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServerId, o)
                    return
                end
            end
        end
        if stat then stat.Text = "Status: Erro ao achar servidor. Tentando de novo..." end
    end)
end

addBtn("Server Hop (Servidor Vazio)", doServerHop)

-- ========================================================
-- 5. CARREGAMENTO DOS MÓDULOS INTERNOS DO JOGO
-- ========================================================
-- Procura de forma segura pelos módulos de estado dos ovos, utilitários e cálculos de rendimento do jogo
local s = nil pcall(function() s = require(j:WaitForChild("Client", 5):WaitForChild("EggState", 5)) end)
if not s then pcall(function() s = require(j.Client.EggState) end) end

local pUtil = nil pcall(function() pUtil = require(j:WaitForChild("Shared", 5):WaitForChild("Util", 5):WaitForChild("AssetItems", 5)) end)
if not pUtil then pcall(function() pUtil = require(j.Shared.Util.AssetItems) end) end

local AssetEarnings = nil pcall(function() AssetEarnings = require(j:WaitForChild("Shared", 5):WaitForChild("Util", 5):WaitForChild("AssetEarnings", 5)) end)
if not AssetEarnings then pcall(function() AssetEarnings = require(j.Shared.Util.AssetEarnings) end) end

local mutModule = nil pcall(function() mutModule = require(j:WaitForChild("Shared", 5):WaitForChild("Modules", 5):WaitForChild("Mutations", 5)) end)
if not mutModule then pcall(function() mutModule = require(j.Shared.Modules.Mutations) end) end

-- Função para formatar números grandes em abreviaturas legíveis (ex: 1.50M, 2.30K)
local function formatNumber(n)
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

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
    
    -- Dicionário de correspondência exata para classificar pets/ovos específicos do jogo
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
    
    local m = ""
    if h.P ~= "" then 
        m = "**" .. playerName .. "** encontrou **" .. tostring(d.C) .. "** de" .. formatNumber(d.R) ..  " Gigante! <@"..h.P..">" 
    else
        m = "**" .. playerName .. "** encontrou **" .. tostring(d.C) .. "** de" .. formatNumber(d.R) ..  " pega la"
    end
    
    local E = {{
        title = "🥚 Ovo Gigante DETECTADO!",
        color = 65352,
        fields = {
            {name = "Categoria", value = d.C, inline = true},
            {name = "Area", value = d.A, inline = true},
            {name = "Raridade", value = d.Rar, inline = true},
            {name = "Tamanho", value = d.P, inline = true},
            {name = "Dinheiro/S", value = "$" .. formatNumber(d.R) .. "/s", inline = true},
        }
    }}
    
    pcall(function()
        req({Url = h.W, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = a:JSONEncode({content = m, embeds = E})})
    end)
end

-- ========================================================
-- 8. SISTEMA DE ESP VISUAL (Contornos e Textos 3D)
-- ========================================================
local function Dk(u, m, d, isValid)
    if not m then return end
    
    local isVisible = h.E and isValid

    if Z[u] then 
        if Z[u].B and Z[u].B:FindFirstChild("TextLabel") then
            Z[u].B.TextLabel.Text = string.format("[%s]\n$%s/s | %s", d.C, formatNumber(d.R), d.P)
        end
        -- Atualiza instantaneamente a visibilidade se o filtro mudar
        if Z[u].H then pcall(function() Z[u].H.Enabled = isVisible end) end
        if Z[u].B then pcall(function() Z[u].B.Enabled = isVisible end) end
        return 
    end
    
    if not isVisible then return end
    
    -- Criação do Highlight (Contorno colorido à volta do ovo)
    local hl = Instance.new("Highlight", m)
    hl.FillColor = Color3.fromRGB(0, 195, 255)
    hl.FillTransparency = 0.6
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.Enabled = true
    
    -- Criação do BillboardGui (Texto flutuante acima do ovo)
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
    
    Z[u] = {H = hl, B = bb, M = m}
end

-- ========================================================
-- 9. LOOP PRINCIPAL DE VARREDURA DO MAPA (Radar)
-- ========================================================
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local act = 0
            local total = 0
            
            -- Reseta o contador do melhor rendimento a cada 10 segundos
            if os.clock() - lastReset >= 10 then
                b = 0
                lastReset = os.clock()
            end
            
            -- Procura e armazena os modelos físicos de ovos presentes nas pastas do jogo
            local pModels = {}
            local function scanFolder(folder)
                if not folder then return end
                for _, v in ipairs(folder:GetChildren()) do
                    local uidAttr = v:GetAttribute("UID") or v:GetAttribute("Uid") or v:GetAttribute("EggUid") or v.Name
                    if uidAttr then pModels[tostring(uidAttr)] = v end
                end
            end
            
            scanFolder(r:FindFirstChild("AreaEggSlotsClient"))
            scanFolder(r:FindFirstChild("__DEBRIS"))
            
            -- Lê os registos em memória do jogo para recolher dados complementares
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
                                local u = tostring(rec.Uid or k)
                                records[u] = rec
                            end
                        end
                    end
                end
            end
            
            -- Itera sobre cada ovo detetado para calcular rendimentos e aplicar filtros
            for u, rawModel in pairs(pModels) do
                total = total + 1
                local rec = records[u] or {}
                
                local cat = rawModel:GetAttribute("Category") or rawModel:GetAttribute("AssetCategory") or rec.AssetCategory or rec.Category or "Egg"
                local area = rawModel:GetAttribute("AreaId") or rawModel:GetAttribute("Area") or rec.AreaId or "Unknown"
                local rarity = getEggRarity(cat, rawModel, rec)

                local scale = tonumber(rawModel:GetAttribute("Scale") or rawModel:GetAttribute("AssetScale"))
                if not scale then scale = tonumber(rec.Scale or rec.AssetScale) end
                scale = scale or 1
                
                local peso = tonumber(rawModel:GetAttribute("Weight") or rawModel:GetAttribute("Kg") or rawModel:GetAttribute("ModelWeight"))
                if not peso then peso = tonumber(rec.Weight or rec.Kg or rec.ModelWeight) end
                
                local mAttr = rawModel:GetAttribute("Mutations") or rawModel:GetAttribute("Mutation") or rec.Mutations or rec.Mutation
                
                -- Cálculo nativo do rendimento por segundo do ovo
                local real = 0
                if AssetEarnings and AssetEarnings.MutationOnlyRatePerSecond then
                    pcall(function()
                        real = tonumber(AssetEarnings.MutationOnlyRatePerSecond({
                            Category = cat,
                            Mutations = mAttr,
                            Scale = scale
                        })) or 0
                    end)
                end
                
                -- Sistema de cálculo secundário (Fallback) caso o nativo falhe
                if real == 0 then
                    local base = tonumber(rawModel:GetAttribute("Income") or rawModel:GetAttribute("EarningRate"))
                    if not base then base = tonumber(rec.Income or rec.EarningRate or rec.MoneyPerSecond) end
                    if (not base or base == 0) and type(rec.ItemData) == "table" then base = tonumber(rec.ItemData.MoneyPerSecond) end
                    
                    if not base or base == 0 then
                        pcall(function()
                            if pUtil and pUtil.ProfileIncomePerSecond then base = tonumber(pUtil.ProfileIncomePerSecond(cat)) end
                            if (not base or base == 0) and pUtil and pUtil.Assets and pUtil.Assets[cat] then
                                local ast = pUtil.Assets[cat]
                                base = tonumber(ast.EarningRate or (ast.Egg and ast.Egg.EarningRate))
                            end
                        end)
                    end
                    base = base or 0
                    if base == 0 then base = 1 end
                    
                    local scaleMult = (scale <= 5) and (scale ^ 1.85) or (((scale / 5) ^ 1.2) * 19.637875755794)
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
                    
                    real = base * scaleMult * mutMult
                    if real < 1 and base > 0 then real = 1 end
                end
                
                real = math.floor(real + 0.5)
                if real > b then b = real end
                
                local pesoStr = peso and string.format("%.1f Kg", peso) or string.format("%.1fx", scale)
                local checkSize = peso or scale or 0
                
                -- Verifica se o ovo cumpre os requisitos definidos pelo utilizador nos filtros
                local isValid = (real >= h.I and checkSize >= h.S)
                
                local d = {U=u, C=cat, A=area, S=scale, R=real, P=pesoStr, Rar=rarity}
                
                if isValid then
                    act = act + 1
                    if not X[u] then
                        X[u] = true
                        Wk(d) -- Dispara notificação via Webhook se for um ovo novo válido
                    end
                end
                
                -- Renderiza ou atualiza o ESP com base na validade do filtro
                if rawModel then
                    local pModel = rawModel
                    if pModel:IsA("Folder") then
                        pModel = pModel:FindFirstChildWhichIsA("BasePart") or pModel:FindFirstChildWhichIsA("Model") or pModel
                    end
                    Dk(u, pModel, d, isValid)
                end
            end
            
            -- Controlo do Auto Server Hop com base na ausência de ovos válidos
            if act > 0 then
                lastValidEggTime = os.clock()
            elseif h.AH and (os.clock() - lastValidEggTime >= h.AHT) then
                lastValidEggTime = os.clock() + 99999
                task.spawn(doServerHop)
            end
            
            -- Atualiza o painel de texto informativo na interface
            if stat then 
                if h.AH and act == 0 then
                    local tempoRestante = math.max(0, math.floor(h.AHT - (os.clock() - lastValidEggTime)))
                    stat.Text = string.format("Status: Hop em %ds...\nOvos no Mapa: %d\nValidos: %d | Melhor: $%s/s", tempoRestante, total, act, formatNumber(b))
                else
                    stat.Text = string.format("Status: Scanning...\nOvos no Mapa: %d\nValidos (Alvos): %d | Melhor: $%s/s", total, act, formatNumber(b)) 
                end
            end
            
            -- Remove da memória os elementos ESP de ovos que já foram apanhados ou saíram do mapa
            for k, v in pairs(Z) do
                if not pModels[k] or not v.M or not v.M.Parent then
                    if v.H then pcall(function() v.H:Destroy() end) end
                    if v.B then pcall(function() v.B:Destroy() end) end
                    Z[k] = nil
                end
            end
        end)
    end
end)
