-- RADAR V15 - dados renovados, envio confirmado e hop limitado.
-- Luau / cliente com as mesmas capacidades de executor exigidas pela V14.
-- Valores de módulos privados são candidatos, não garantia de renda real.
-- Não reexecuta automaticamente após teleporte.
-- Migração da V14: entre novamente no servidor antes de executar, pois o loop
-- legado não oferecia mecanismo de encerramento. Reexecuções da V15 se encerram.
-- Por padrão, renda estimada não passa nos filtros. Para usar módulos de contrato
-- não confirmado e a fórmula antiga, ative "Aceitar renda estimada nos filtros".
-- Testado localmente com mocks, não dentro do Roblox. Não envia testes sozinho.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
assert(player, "Radar requer contexto de cliente")
local requestFn = (syn and syn.request) or http_request or request
if type(requestFn) ~= "function" then requestFn = nil end
local function finite(v)
    local n = tonumber(v)
    if n and n == n and n > -math.huge and n < math.huge then return n end
end
local function nonnegative(v) local n = finite(v); if n and n >= 0 then return n end end
local function positive(v) local n = finite(v); if n and n > 0 then return n end end
local function trim(v) return tostring(v or ""):match("^%s*(.-)%s*$") end
local function short(v, limit)
    local s = tostring(v or "Unknown")
    if #s <= limit then return s end
    local cut = limit - 3
    -- Não cortar no meio de uma sequência UTF-8.
    while cut > 0 and s:byte(cut + 1) >= 128 and s:byte(cut + 1) < 192 do cut = cut - 1 end
    return s:sub(1, cut) .. "..."
end
local state = {alive=true, threads={}, connections={}, esps={}, notices={}, candidates={}, visited={}}
local old = CoreGui:FindFirstChild("DiceRadarGUI")
if old then
    local stopper = old:FindFirstChild("StopRadar")
    if stopper and stopper:IsA("BindableEvent") then stopper:Fire(); task.wait() end
    old:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "DiceRadarGUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui
local stopEvent = Instance.new("BindableEvent", gui)
stopEvent.Name = "StopRadar"
local function spawn(fn)
    local thread
    thread = task.defer(function()
        if state.alive then
            local ok = pcall(fn)
            if not ok and state.alive then warn("[Radar] Uma tarefa falhou; consulte o status.") end
        end
        state.threads[coroutine.running()] = nil
    end)
    state.threads[thread] = true
    return thread
end
local function stop()
    if not state.alive then return end
    state.alive = false
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    for _, esp in pairs(state.esps) do esp.B:Destroy() end
    local current = coroutine.running()
    for thread in pairs(state.threads) do
        if thread ~= current then pcall(task.cancel, thread) end
    end
    gui:Destroy()
end
table.insert(state.connections, stopEvent.Event:Connect(stop))
table.insert(state.connections, gui.Destroying:Connect(stop))
local h = {W="", P="", I=0, S=0, E=true, WH=false, AH=false, AHT=60, PC=1, EST=false}
local cfgFile = "DiceRadar_Config.json"
if type(isfile) == "function" and type(readfile) == "function" then
    pcall(function()
        if isfile(cfgFile) then
            local saved = HttpService:JSONDecode(readfile(cfgFile))
            if type(saved) == "table" then
                for k, default in pairs(h) do
                    if type(default) == "boolean" then
                        if type(saved[k]) == "boolean" then h[k] = saved[k] end
                    elseif type(default) == "number" then
                        h[k] = nonnegative(saved[k]) or default
                    elseif type(saved[k]) == "string" then h[k] = trim(saved[k]) end
                end
            end
        end
    end)
end
h.AHT = math.clamp(h.AHT, 10, 3600)
h.PC = h.PC == 2 and 2 or 1
local lastValidEggTime, nextHopAt = os.clock(), 0
local isHopping, hopGeneration = false, 0
local notice, noticeUntil = "", 0
local function status(text, seconds) notice = text; noticeUntil = os.clock() + (seconds or 6) end
local function formatNumber(n)
    if not finite(n) then return "?" end
    if n >= 1e15 then return string.format("%.2fQ", n/1e15) end
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end
-- Timeout local: uma resposta atrasada nunca altera o resultado já encerrado.
local function timedCall(fn, timeout)
    local finished, result = false, nil
    local thread = spawn(function() result = table.pack(pcall(fn)); finished = true end)
    local deadline = os.clock() + timeout
    while state.alive and not finished and os.clock() < deadline do task.wait(0.1) end
    if not finished then
        pcall(task.cancel, thread); state.threads[thread] = nil
        return false, nil
    end
    return table.unpack(result, 1, result.n)
end
local function http(options)
    options.Timeout = 12
    local ok, response = timedCall(function()
        if requestFn then return requestFn(options) end
        if options.Method == "GET" then
            return {StatusCode=200, Body=game:HttpGet(options.Url)}
        end
        error("HTTP indisponivel")
    end, 15)
    if not ok or type(response) ~= "table" then return nil end
    return response
end

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
title.Text = "Radar V15 | clique para configurar"
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
    bx.ClearTextOnFocus = false
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
        main.Size = UDim2.new(0, 290, 0, 550)
        cont.Visible = true
    end
end)


cont.AutomaticCanvasSize = Enum.AutomaticSize.Y
cont.CanvasSize = UDim2.new(0, 0, 0, 0)
local function setNumber(key, value, default, min, max)
    h[key] = math.clamp(finite(value) or default, min, max)
end
addBox("Webhook URL (salva em texto simples)", h.W, function(v)
    h.W = trim(v); state.notices = {}; state.webhookBlocked = nil
end)
addBox("Ping Discord ID", h.P, function(v) h.P = trim(v):match("^%d+$") or "" end)
addBox("Renda minima ($/s, numero completo)", h.I, function(v) setNumber("I", v, 0, 0, 1e30) end)
addBox("Escala minima (x, nao kg)", h.S, function(v) setNumber("S", v, 0, 0, 1e6) end)
addBox("Auto Hop sem alvos (10-3600 s)", h.AHT, function(v) setNumber("AHT", v, 60, 10, 3600) end)
addTog("Mostrar ESP", h.E, function(v)
    h.E = v
    for _, esp in pairs(state.esps) do esp.B.Enabled = v and esp.valid end
end)
addTog("Enviar webhooks", h.WH, function(v)
    h.WH = v
    if v then state.webhookBlocked = nil end
end)
addTog("Aceitar renda estimada nos filtros", h.EST, function(v) h.EST = v end)
addTog("Auto Server Hop", h.AH, function(v) h.AH = v; lastValidEggTime = os.clock() end)
addBtn("Alternar busca: 1 ou 2 jogadores", function()
    h.PC = h.PC == 1 and 2 or 1
    status("Buscar servidor com " .. h.PC .. " jogador(es)")
end)
addBtn("Salvar configuracoes", function()
    if type(writefile) ~= "function" then status("Executor sem escrita de arquivos"); return end
    local ok = pcall(function() writefile(cfgFile, HttpService:JSONEncode(h)) end)
    status(ok and "Configuracoes salvas" or "Falha ao salvar configuracoes")
end)
local function validWebhook(url)
    return type(url) == "string" and (
        url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+$") or
        url:match("^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$")) ~= nil
end
local function joinLink()
    -- Mantém o endereço da V14. Site externo não validado pelo radar.
    return "https://darling-liger-02e311.netlify.app/index.html?placeId=" .. tostring(game.PlaceId)
        .. "&jobId=" .. HttpService:UrlEncode(tostring(game.JobId))
end
local function sendWebhook(data, isTest, url)
    if not validWebhook(url) then return false, 60, true, "URL de webhook invalida" end
    if not requestFn then return false, 60, true, "Executor sem HTTP POST" end
    local ping = h.P:match("^%d+$")
    local amount = (data.estimated and "~" or "") .. formatNumber(data.R)
    local payload = {
        content = (isTest and "Teste do Radar V15" or (short(player.Name, 40) .. " encontrou " .. short(data.C, 100)))
            .. (ping and (" <@" .. ping .. ">") or ""),
        allowed_mentions = {parse={}, users=ping and {ping} or {}},
        embeds = {{title=isTest and "Teste de conexao" or "Ovo detectado", color=65352,
            url=joinLink(), fields={
                {name="Categoria", value=short(data.C, 150), inline=true},
                {name="Area", value=short(data.A, 150), inline=true},
                {name="Raridade", value=short(data.Rar, 80), inline=true},
                {name="Escala", value=data.P, inline=true},
                {name="Renda / segundo", value="$" .. amount .. "/s", inline=true},
                {name="Fonte da renda", value=short(data.source, 200), inline=false},
                {name="Servidor (link externo)", value="[Abrir servidor](" .. joinLink() .. ")", inline=false},
            }}}
    }
    local response = http({Url=url, Method="POST", Headers={["Content-Type"]="application/json"},
        Body=HttpService:JSONEncode(payload)})
    if not response then return false, 10, false, "Webhook: timeout ou falha de rede" end
    local code = tonumber(response.StatusCode or response.Status)
    if code and code >= 200 and code < 300 then return true, 0, false, "Webhook enviado" end
    if code == 429 then
        local delay = 5
        pcall(function()
            local body = HttpService:JSONDecode(response.Body or "{}")
            delay = math.clamp(positive(body.retry_after) or 5, 1, 3600)
        end)
        return false, delay, false, "Webhook limitado; aguardando"
    end
    return false, 15, code ~= nil and code >= 400 and code < 500,
        "Webhook: HTTP " .. tostring(code or "desconhecido")
end
local webhookTestPending = false
addBtn("Testar webhook", function() webhookTestPending = true end)

local function finishHop(generation, message)
    if generation ~= hopGeneration then return end
    isHopping = false
    nextHopAt = os.clock() + 20
    lastValidEggTime = os.clock()
    if message then status(message) end
end
local function doServerHop(automatic)
    if isHopping or not state.alive or os.clock() < nextHopAt then return end
    isHopping = true
    hopGeneration = hopGeneration + 1
    local generation = hopGeneration
    -- Libera mesmo se uma API de teleporte não retornar.
    spawn(function()
        task.wait(75)
        if state.alive and isHopping and generation == hopGeneration then
            finishHop(generation, "Hop excedeu o tempo; tente novamente")
            hopGeneration = hopGeneration + 1
        end
    end)
    local ok = pcall(function()
        status("Buscando servidores com " .. h.PC .. " jogador(es)", 65)
        local targetPlayers = h.PC
        local cursor, servers, selected, cursors = "", {}, {}, {}
        local deadline = os.clock() + 55
        local pages, failures = 0, 0
        while state.alive and pages < 30 and failures < 4 and os.clock() < deadline do
            if generation ~= hopGeneration or (automatic and not h.AH) then break end
            if automatic and next(state.candidates) then break end
            local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
                .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
            if cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
            local response = http({Url=url, Method="GET"})
            local code = response and tonumber(response.StatusCode or response.Status)
            if code == 200 then
                local decoded, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
                if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then break end
                pages = pages + 1
                for _, server in ipairs(data.data) do
                    if type(server) == "table" and type(server.id) == "string"
                        and server.id ~= game.JobId and not selected[server.id]
                        and finite(server.playing) == targetPlayers
                        and positive(server.maxPlayers) and server.playing < server.maxPlayers
                        and (not state.visited[server.id] or os.clock() - state.visited[server.id] > 900) then
                        selected[server.id] = true
                        table.insert(servers, server.id)
                    end
                end
                if #servers >= 8 or type(data.nextPageCursor) ~= "string" or data.nextPageCursor == "" then break end
                cursor = data.nextPageCursor
                if cursors[cursor] then break end
                cursors[cursor] = true
                task.wait(0.4)
            else
                failures = failures + 1
                if code and code >= 400 and code < 500 and code ~= 429 then break end
                task.wait(math.min(2 ^ failures, 8))
            end
        end
        if not state.alive or generation ~= hopGeneration then return end
        if automatic and (not h.AH or next(state.candidates)) then
            finishHop(generation, "Hop cancelado: alvo encontrado ou opcao desligada"); return
        end
        if #servers == 0 then finishHop(generation, "Nenhum servidor encontrado; nova tentativa depois"); return end
        local id = servers[math.random(1, #servers)]
        state.visited[id] = os.clock()
        state.teleportTarget = id
        status("Teleportando...", 25)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, id, player)
        spawn(function()
            task.wait(20)
            if state.alive and isHopping then finishHop(generation, "Teleporte nao concluido; hop liberado") end
        end)
    end)
    if not ok then finishHop(generation, "Falha no hop; estado recuperado") end
end
table.insert(state.connections, TeleportService.TeleportInitFailed:Connect(function(who)
    if who == player and isHopping then
        finishHop(hopGeneration, "Teleporte recusado; tente outro servidor")
        hopGeneration = hopGeneration + 1
    end
end))
addBtn("Trocar servidor agora", function() spawn(function() doServerHop(false) end) end)
addBtn("Encerrar radar", stop)

-- Módulos internos: carregamento limitado e refeito quando ainda não disponíveis.
local modules, moduleAttempt = {}, -math.huge
local function loadModules()
    if os.clock() - moduleAttempt < 30 then return end
    moduleAttempt = os.clock()
    local paths = {
        eggState={"Client", "EggState"}, assets={"Shared", "Util", "AssetItems"},
        earnings={"Shared", "Util", "AssetEarnings"}, mutations={"Shared", "Modules", "Mutations"},
        halloween={"HalloweenPets"}, directory={"Assets"},
    }
    for key, path in pairs(paths) do
        if not modules[key] then
            local object = ReplicatedStorage
            for _, name in ipairs(path) do
                object = object and object:FindFirstChild(name, #path == 1)
            end
            if object and object:IsA("ModuleScript") then
                local ok, value = timedCall(function() return require(object) end, 2)
                if ok and type(value) == "table" then modules[key] = value end
            end
        end
    end
end
local aliases = {
    ["Rotshroom"]="Toadstool", ["Rotshroom Egg"]="Toadstool", ["Dread Wolf"]="Werewolf",
    ["Halloween Royal Mimic Egg"]="Mimic Chest", ["Royal Mimic Egg"]="Mimic Chest",
    ["Royal Mimic"]="Mimic Chest", ["Frankenstein Kong Egg"]="Abomination Kong",
    ["Quilted Imp Egg"]="Patchwork Imp", ["SpiritKnight"]="Spirit Knight",
}
local function attr(model, names)
    if model then
        for _, name in ipairs(names) do
            local v = model:GetAttribute(name)
            if v ~= nil then return v end
        end
    end
end
local function field(record, names)
    for _, name in ipairs(names) do if record[name] ~= nil then return record[name] end end
end
local function normalizeRarity(v)
    if type(v) == "table" then v = v.DisplayName or v.Name or v._id end
    if type(v) == "string" and v ~= "" and v ~= "Unknown" then return v end
end
local function findSpec(names)
    local sources = {
        modules.halloween and modules.halloween.Specs or {},
        modules.directory and modules.directory.Directory or {},
        modules.assets and modules.assets.Assets and modules.assets.Assets.Directory or {},
        modules.assets and modules.assets.Assets or {},
    }
    for _, source in ipairs(sources) do
        if type(source) == "table" then
            for _, name in ipairs(names) do
                local spec = source[name]
                if type(spec) == "table" then return spec end
            end
        end
    end
end
local rarityByName = {
    cosmicdragon="Secret", cosmicgorilla="Mythic", cosmicgecko="Legendary",
    nightflame="Divine", unicorn="Divine", shatteredcolossossus="Divine", shatteredcolossus="Divine",
    kitsune="Divine", elmaja="Divine", gorillaking="Eternal", lunardragon="Eternal", onitiger="Eternal",
    mosasaurus="Eternal", mutantshark="Secret", skeletonboss="Secret", stag="Secret", trex="Secret",
    tralaledon="Secret", kraken="Secret", saturnita="Cosmic", saturno="Cosmic", mantaris="Cosmic",
    mantis="Cosmic", moth="Cosmic", imp="Cosmic", rhinotaur="Cosmic", snowyowl="Cosmic", koi="Cosmic",
    triceratops="Cosmic", bronto="Cosmic", whaleshark="Cosmic", belugawhale="Cosmic", bladehide="Mythic",
    redpanda="Mythic", ankylosaurus="Mythic", orca="Mythic", spideron="Legendary", crustacia="Legendary",
    salamander="Legendary", pterodactyl="Legendary", shark="Legendary", crane="Epic", centapede="Epic",
    swordfish="Epic", dodo="Rare", parrotfish="Rare",
}
local function getRarity(model, rec, spec, name)
    local direct = normalizeRarity(attr(model, {"Rarity", "RarityTier", "Tier"}))
        or normalizeRarity(rec.Rarity)
        or normalizeRarity(spec and (spec.Rarity or (type(spec.Egg) == "table" and spec.Egg.Rarity)))
    if direct then return direct end
    local key = name:lower():gsub("[%s_%-]", ""):gsub("egg$", "")
    -- Mapeamento herdado da V14; rotulado como inferência, não dado oficial.
    if rarityByName[key] then return rarityByName[key] .. " (inferida)" end
    return "Unknown"
end
local function readEgg(uid, model, rec)
    local category = attr(model, {"Category", "AssetCategory", "ItemName"})
        or field(rec, {"AssetCategory", "Category", "ItemName"})
    local display = attr(model, {"PreparedSourceName", "DisplayName"})
        or field(rec, {"PreparedSourceName", "DisplayName"}) or category or "Egg"
    category = tostring(category or display)
    display = tostring(display)
    -- Preserva identificadores originais para chamadas internas.
    local names = {category, display, aliases[category] or category, aliases[display] or display}
    if model then table.insert(names, model.Name) end
    local spec = findSpec(names)
    local scale = positive(attr(model, {"Scale", "AssetScale"}) or field(rec, {"Scale", "AssetScale"}))
    local scaleEstimated = false
    if not scale and model and model:IsA("Model") then
        scale = positive(model:GetScale()); scaleEstimated = scale ~= nil
    end
    local mutation = attr(model, {"Mutations", "Mutation"}) or field(rec, {"Mutations", "Mutation"})
    if type(mutation) == "string" and (mutation:sub(1,1) == "[" or mutation:sub(1,1) == "{") then
        local ok, value = pcall(function() return HttpService:JSONDecode(mutation) end)
        if ok and type(value) == "table" then mutation = value end
    end
    local rate, estimated, source = nil, true, "Renda indisponivel"
    -- Apenas campos explicitamente finais são tratados como renda reportada.
    rate = nonnegative(attr(model, {"RealIncome", "FinalIncome", "FinalEarningRate"})
        or field(rec, {"RealIncome", "FinalIncome", "FinalEarningRate"}))
    if rate ~= nil then estimated = false; source = "Campo final informado pelo jogo" end
    -- Contrato deste módulo privado não acompanha o arquivo: candidato estimado.
    if rate == nil and modules.earnings and type(modules.earnings.MutationOnlyRatePerSecond) == "function" and scale then
        for _, name in ipairs(names) do
            local ok, value = pcall(modules.earnings.MutationOnlyRatePerSecond,
                {Category=name, Mutations=mutation, Scale=scale})
            if ok and positive(value) then
                rate = positive(value); source = "Modulo nativo (contrato nao validado)"; break
            end
        end
    end
    -- Campos ambíguos são exibidos sem multiplicar uma segunda vez.
    if rate == nil then
        rate = nonnegative(attr(model, {"Income", "EarningRate", "MoneyPerSecond"})
            or field(rec, {"Income", "EarningRate", "MoneyPerSecond"}))
        if rate == nil and type(rec.ItemData) == "table" then
            rate = nonnegative(rec.ItemData.MoneyPerSecond or rec.ItemData.Income)
        end
        if rate ~= nil then source = "Income/EarningRate (base ou final nao confirmado)" end
    end
    if rate == nil and spec and scale then
        local base = nonnegative(spec.EarningRate or (type(spec.Egg) == "table" and spec.Egg.EarningRate))
        local mult
        if mutation == nil or mutation == "" or (type(mutation) == "table" and next(mutation) == nil) then
            mult = 1
        elseif modules.mutations and type(modules.mutations.EarningsFor) == "function" then
            local ok, value = pcall(modules.mutations.EarningsFor, mutation)
            if ok then mult = positive(value) end
        end
        -- Sem multiplicador inventado para mutação desconhecida.
        if base and mult then
            local scaleMult = scale <= 5 and scale ^ 1.85 or ((scale / 5) ^ 1.2 * 5 ^ 1.85)
            rate = nonnegative(base * scaleMult * mult)
            source = "Formula estimada herdada da V14"
        end
    end
    return {U=uid, C=aliases[display] or display,
        A=tostring(attr(model, {"AreaId", "Area", "Zone"}) or field(rec, {"AreaId", "Area", "Zone"}) or "Unknown"),
        R=rate, S=scale, P=scale and ((scaleEstimated and "~" or "") .. string.format("%.2fx", scale)) or "?",
        Rar=getRarity(model, rec, spec, display), estimated=estimated, source=source, scaleEstimated=scaleEstimated}
end
local function isValid(data)
    return data.R ~= nil and (not data.estimated or h.EST)
        and data.R >= h.I and (h.S == 0 or (data.S ~= nil and data.S >= h.S))
end
local function updateESP(uid, model, data, valid)
    local anchor
    if model then
        anchor = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
    end
    local existing = state.esps[uid]
    if existing and (not anchor or existing.M ~= anchor or not existing.B.Parent) then
        existing.B:Destroy(); state.esps[uid] = nil; existing = nil
    end
    if not anchor or not valid then
        if existing then existing.valid = false; existing.B.Enabled = false end
        return
    end
    if not existing and h.E then
        local bb = Instance.new("BillboardGui")
        bb.Name = "DiceRadarESP"
        bb.Adornee = anchor
        bb.Size = UDim2.new(0, 220, 0, 65)
        bb.StudsOffset = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop = true
        bb.Parent = gui
        local label = Instance.new("TextLabel", bb)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(0, 195, 255)
        label.TextStrokeTransparency = 0.2
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        existing = {B=bb, M=anchor, label=label}; state.esps[uid] = existing
    end
    if existing then
        existing.valid = valid; existing.B.Enabled = h.E and valid
        existing.label.Text = string.format("[%s]\n%s$%s/s | %s", short(data.C, 70),
            data.estimated and "~" or "", formatNumber(data.R), data.P)
    end
end

local function collectEggs()
    local models, records, uids = {}, {}, {}
    local function scanFolder(folder)
        if not folder then return end
        for _, object in ipairs(folder:GetChildren()) do
            if object:IsA("Model") or object:IsA("BasePart") or object:IsA("Folder") then
                local uid = attr(object, {"UID", "Uid", "EggUid", "HalloweenEggUid"})
                local category = attr(object, {"Category", "AssetCategory", "ItemName"})
                -- Em __DEBRIS exige marcador específico de ovo ou UID + categoria.
                local eggMarker = attr(object, {"EggUid", "HalloweenEggUid"})
                local trustedFolder = folder.Name ~= "__DEBRIS"
                if not uid and trustedFolder and category then
                    uid = attr(object, {"Id"}) or object.Name
                end
                if uid and (trustedFolder or eggMarker or category) then
                    uid = tostring(uid); models[uid] = object; uids[uid] = true
                end
            end
        end
    end
    scanFolder(Workspace:FindFirstChild("AreaEggSlotsClient"))
    scanFolder(Workspace:FindFirstChild("__DEBRIS"))
    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder:IsA("Folder") and folder.Name ~= "AreaEggSlotsClient"
            and folder.Name:lower():find("eggslots", 1, true) then scanFolder(folder) end
    end
    local halloween = Workspace:FindFirstChild("HalloweenDimension")
    if halloween then scanFolder(halloween:FindFirstChild("WorldEggs")) end
    local eggState = modules.eggState
    if eggState then
        local reader = eggState.ReadFieldEggs or eggState.SyncFieldEggs
        if type(reader) == "function" then
            local ok, value = timedCall(function() return reader() end, 3)
            if not ok or type(value) ~= "table" then
                -- Não interpretar falha de leitura como mapa vazio e iniciar hop.
                error("EggState indisponivel")
            end
            local raw = value.Records or value
            if type(raw) ~= "table" then error("EggState fora do formato esperado") end
            for key, record in pairs(raw) do
                if type(record) == "table" and (record.Uid or record.HalloweenEggUid or record.Id
                    or record.AssetCategory or record.Category or record.ItemName) then
                    local uid = tostring(record.Uid or record.HalloweenEggUid or record.Id or key)
                    records[uid] = record; uids[uid] = true
                    if not models[uid] then
                        -- Nomes só servem de UID se corroborados pelos registros do jogo.
                        local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
                        models[uid] = folder and folder:FindFirstChild(uid)
                    end
                end
            end
        end
    end
    return uids, models, records
end
spawn(function()
    while state.alive do
        loadModules()
        task.wait(30)
    end
end)
spawn(function()
    while state.alive do
        local ok = pcall(function()
            local uids, models, records = collectEggs()
            local candidates, count, active, unknown, best, errors = {}, 0, 0, 0, nil, 0
            for uid in pairs(uids) do
                count = count + 1
                -- Erro em um ovo não aborta a leitura dos outros.
                local success, data = pcall(readEgg, uid, models[uid], records[uid] or {})
                if success then
                    if data.R == nil then unknown = unknown + 1 end
                    if data.R and (not best or data.R > best.R) then best = data end
                    local valid = isValid(data)
                    if valid then active = active + 1; candidates[uid] = data end
                    local espOK = pcall(updateESP, uid, models[uid], data, valid)
                    if not espOK then errors = errors + 1 end
                else
                    errors = errors + 1
                    local esp = state.esps[uid]
                    if esp then esp.B.Enabled = false; esp.valid = false end
                end
            end
            state.candidates = candidates
            state.lastScan = os.clock()
            for uid, esp in pairs(state.esps) do
                if not uids[uid] or not esp.M.Parent then esp.B:Destroy(); state.esps[uid] = nil end
            end
            for uid in pairs(state.notices) do
                if not uids[uid] then state.notices[uid] = nil end
            end
            for id, visitedAt in pairs(state.visited) do
                if os.clock() - visitedAt > 900 then state.visited[id] = nil end
            end
            if active > 0 or errors > 0 then lastValidEggTime = os.clock() end
            if h.AH and active == 0 and errors == 0 and not isHopping
                and os.clock() - lastValidEggTime >= h.AHT and os.clock() >= nextHopAt then
                spawn(function() doServerHop(true) end)
            end
            local line = "Busca: " .. h.PC .. " jogador(es)"
            if os.clock() < noticeUntil then line = notice
            elseif isHopping then line = "Busca / teleporte em andamento"
            elseif errors > 0 then line = "Falhas na leitura: " .. errors
            elseif h.AH and active == 0 then
                line = "Hop em " .. math.ceil(math.max(0, h.AHT - (os.clock() - lastValidEggTime), nextHopAt - os.clock())) .. "s"
            end
            stat.TextSize = 12
            stat.Text = string.format("%s\nOvos: %d | Alvos: %d | Sem renda: %d\nMelhor: %s$%s/s",
                line, count, active, unknown, best and best.estimated and "~" or "", formatNumber(best and best.R))
        end)
        if not ok then
            state.candidates = {}; lastValidEggTime = os.clock()
            status("Falha na leitura; hop suspenso nesta rodada")
            stat.Text = "Falha na leitura dos dados. Tentando novamente..."
        end
        task.wait(1.5)
    end
end)
-- Uma única fila implícita: no máximo uma requisição de webhook por vez.
spawn(function()
    local nextSend = 0
    while state.alive do
        if os.clock() >= nextSend then
            local uid, data, isTest
            if webhookTestPending then
                webhookTestPending = false; isTest = true
                data = {C="Teste manual", A="Servidor atual", Rar="N/A", P="N/A", source="Teste de conexao"}
            elseif h.WH and h.W ~= "" and not state.webhookBlocked
                and state.lastScan and os.clock() - state.lastScan < 10 then
                for key, candidate in pairs(state.candidates) do
                    local entry = state.notices[key]
                    if not entry or (not entry.sent and entry.attempts < 4 and os.clock() >= entry.retryAt) then
                        if not data or candidate.R > data.R then uid = key; data = candidate end
                    end
                end
            end
            if data then
                local url = h.W
                local ok, delay, permanent, message = sendWebhook(data, isTest, url)
                nextSend = os.clock() + math.max(2, delay)
                if state.alive and h.W == url then
                    if uid then
                        local entry = state.notices[uid] or {attempts=0}
                        entry.attempts = entry.attempts + 1
                        entry.sent = ok
                        entry.retryAt = os.clock() + math.max(delay, 2 ^ entry.attempts)
                        state.notices[uid] = entry
                    end
                    if permanent then state.webhookBlocked = true end
                    status(message .. (permanent and "; revise URL/HTTP e reative webhooks" or ""))
                end
            end
        end
        task.wait(0.25)
    end
end)
status("V15: ~ = estimativa; filtros estimados desligados", 10)
