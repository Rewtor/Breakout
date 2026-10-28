-- =========================================================
-- DICE RADAR V18 LITE | HOP POR PAGINA
-- Painel mobile + ranking + webhook + server hop
-- Sem ESP, coleta automatica ou atualizacao por frame.
-- =========================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Http = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Teleport = game:GetService("TeleportService")

local player = Players.LocalPlayer
assert(player, "Execute no cliente.")

local host = player:WaitForChild("PlayerGui", 10)
assert(host, "PlayerGui indisponivel.")

local requestFn =
    (syn and syn.request)
    or http_request
    or request
    or HttpPost

local SCAN_INTERVAL = 1.5
local GEOMETRY_TTL = 60
local CONFIG_FILE = "DiceRadar_Config.json"

local function finite(value)
    local n = tonumber(value)
    if n and n == n and n > -math.huge and n < math.huge then
        return n
    end
end

local function positive(value, fallback)
    local n = finite(value)
    return n and n > 0 and n or fallback
end

local cfg = {
    W = "",
    P = "",
    I = 0,
    S = 0,
    WH = false,
    AH = false,
    AHT = 60,
    PC = 1,
}

if isfile and readfile then
    pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local saved = Http:JSONDecode(readfile(CONFIG_FILE))
        if type(saved) ~= "table" then return end

        for key in pairs(cfg) do
            if saved[key] ~= nil then
                cfg[key] = saved[key]
            end
        end
    end)
end

cfg.W = type(cfg.W) == "string" and cfg.W or ""
cfg.P = type(cfg.P) == "string" and cfg.P or ""
cfg.I = math.max(0, finite(cfg.I) or 0)
cfg.S = math.max(0, finite(cfg.S) or 0)
cfg.AHT = math.max(5, finite(cfg.AHT) or 60)
cfg.PC = tonumber(cfg.PC) == 2 and 2 or 1
cfg.WH = cfg.WH == true
cfg.AH = cfg.AH == true

-- Encerra a versao anterior que usa o mesmo nome.
local function removePrevious(parent)
    for _, name in ipairs({
        "DiceRadarGUI",
        "HalloweenReadOnlyRadarV4",
    }) do
        local previous = parent:FindFirstChild(name)
        if previous then previous:Destroy() end
    end
end

removePrevious(host)
pcall(function()
    removePrevious(game:GetService("CoreGui"))
end)

local alive = true
local paused = false
local mobile = UIS.TouchEnabled
local compact = mobile
local minimized = true

local connections = {}
local cached = {}
local cacheState = {}
local knownSources = {}
local rows = {}

local dataVersion = 0
local viewVersion = 0
local lastRendered = nil
local sortedVersion = -1
local sortedMode = -1
local sorted = {}

local sortMode = 1
local sortNames = {
    "Maior renda",
    "Maior escala",
    "Maior raridade",
}

local rarityRanks = {
    Common = 1, Uncommon = 2, Rare = 3,
    Epic = 4, Legendary = 5, Mythic = 6,
    Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10,
}

local rarityColors = {
    Divine = Color3.fromRGB(255, 115, 215),
    Eternal = Color3.fromRGB(255, 170, 100),
    Secret = Color3.fromRGB(255, 100, 120),
    Cosmic = Color3.fromRGB(185, 125, 255),
    Mythic = Color3.fromRGB(210, 140, 255),
    Legendary = Color3.fromRGB(255, 207, 95),
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end

local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function text(parent, properties)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(229, 233, 243),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        RichText = false,
    }

    for key, value in pairs(properties) do
        defaults[key] = value
    end

    return create("TextLabel", parent, defaults)
end

local function button(parent, title, position, size)
    local object = create("TextButton", parent, {
        Text = title,
        Position = position,
        Size = size,
        BackgroundColor3 = Color3.fromRGB(48, 58, 76),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
    })

    create("UICorner", object, {
        CornerRadius = UDim.new(0, 6),
    })

    return object
end

local function setText(object, value)
    if object.Text ~= value then object.Text = value end
end

local function short(value)
    local n = finite(value)
    if not n then return "pendente" end

    if n >= 1e15 then return string.format("%.2fQ", n / 1e15) end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function exact(value)
    local n = finite(value)
    return n and string.format("%.2f", n) or "pendente"
end

local function isTarget(data)
    return data
        and data.Ready
        and data.R >= cfg.I
        and data.CS >= cfg.S
end

local render
local doServerHop
local cancelHop

local isHopping = false
local hopGeneration = 0
local lastValidEggTime = os.clock()

-- =========================================================
-- INTERFACE
-- =========================================================

local gui = create("ScreenGui", host, {
    Name = "DiceRadarGUI",
    ResetOnSpawn = false,
    DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

connect(gui.Destroying, function()
    alive = false
    hopGeneration = hopGeneration + 1

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end)

local main = create("Frame", gui, {
    Size = UDim2.fromOffset(430, 500),
    Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Color3.fromRGB(18, 23, 32),
    BorderSizePixel = 0,
    Active = true,
})

create("UICorner", main, {CornerRadius = UDim.new(0, 10)})
create("UIStroke", main, {
    Color = Color3.fromRGB(255, 156, 70),
    Thickness = 1.5,
})

local header = create("Frame", main, {
    Size = UDim2.new(1, -106, 0, 50),
    BackgroundTransparency = 1,
    Active = true,
})

local title = text(header, {
    Text = "DICE / RADAR",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    Position = UDim2.fromOffset(14, 14),
    Size = UDim2.new(1, -14, 1, -14),
    TextWrapped = false,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local minimizeButton = button(
    main, "—",
    UDim2.new(1, -100, 0, 5),
    UDim2.fromOffset(44, 44)
)

local closeButton = button(
    main, "X",
    UDim2.new(1, -50, 0, 5),
    UDim2.fromOffset(44, 44)
)

local body = create("Frame", main, {
    Position = UDim2.fromOffset(0, 50),
    Size = UDim2.new(1, 0, 1, -50),
    BackgroundTransparency = 1,
})

local sortButton = button(body, sortNames[sortMode], UDim2.new(), UDim2.new())
local detailButton = button(body, compact and "Detalhes: OFF" or "Detalhes: ON", UDim2.new(), UDim2.new())
local pauseButton = button(body, "Pausar", UDim2.new(), UDim2.new())

local stat = text(body, {
    Text = "Carregando...",
    Size = UDim2.new(1, -24, 0, 48),
    TextSize = 12,
})

local list = create("ScrollingFrame", body, {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 7,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
})

create("UIListLayout", list, {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local empty = text(list, {
    Text = "Aguardando ovos carregados...",
    Size = UDim2.new(1, -12, 0, 55),
})

local settings = create("ScrollingFrame", body, {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 7,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Visible = false,
})

create("UIListLayout", settings, {
    Padding = UDim.new(0, 9),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local mobileOptions = create("Frame", settings, {
    Size = UDim2.new(1, -8, 0, 100),
    BackgroundTransparency = 1,
    LayoutOrder = -10,
})

local hopStatus = text(body, {
    Text = "Pronto para buscar servidor.",
    TextSize = 11,
    TextColor3 = Color3.fromRGB(170, 181, 199),
})

local settingsButton = button(body, "Ajustes", UDim2.new(), UDim2.new())
local hopButton = button(body, "Trocar servidor", UDim2.new(), UDim2.new())
local cancelButton = button(body, "Cancelar", UDim2.new(), UDim2.new())

local footer = text(body, {
    Text = "Atualização a cada 1,5 s • sem ESP\nRenda e peso estimados; mutações dependem dos dados disponíveis.",
    TextSize = 11,
    TextColor3 = Color3.fromRGB(170, 181, 199),
})

local expandedSize = main.Size
local headerHeight = 50

local function refreshHopButton()
    setText(hopButton,
        mobile and isHopping and "Cancelar busca" or "Trocar servidor"
    )
end

local function setHopState(value, message)
    isHopping = value
    if alive then
        refreshHopButton()
        if message then setText(hopStatus, message) end
    end
end

local function clampPosition()
    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then return end

    local width = main.Size.X.Offset
    local height = main.Size.Y.Offset
    local x = main.Position.X.Scale * view.X + main.Position.X.Offset
    local yy = main.Position.Y.Scale * view.Y + main.Position.Y.Offset

    main.Position = UDim2.fromOffset(
        math.clamp(x, 0, math.max(0, view.X - width)),
        math.clamp(yy, 0, math.max(0, view.Y - height))
    )
end

local function layout()
    if not alive then return end

    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then return end

    local previousMobile = mobile
    mobile = UIS.TouchEnabled or view.X < 640 or view.Y < 500

    if previousMobile ~= mobile then
        viewVersion = viewVersion + 1
    end

    headerHeight = mobile and 50 or 46

    local width = mobile and math.min(430, view.X - 16)
        or math.min(570, view.X - 32)
    local height = mobile and (view.Y - 16)
        or math.min(760, view.Y * 0.82)

    width = math.max(1, width)
    height = math.max(1, height)

    expandedSize = UDim2.fromOffset(width, height)
    main.Size = minimized and UDim2.fromOffset(width, headerHeight)
        or expandedSize

    header.Size = UDim2.new(1, mobile and -106 or -90, 0, headerHeight)
    title.Text = mobile and "DICE / RADAR" or "DICE / RADAR + SERVER HOP"
    title.TextSize = mobile and 16 or 17

    minimizeButton.Size = UDim2.fromOffset(mobile and 44 or 30, mobile and 44 or 28)
    closeButton.Size = minimizeButton.Size
    minimizeButton.Position = UDim2.new(1, mobile and -100 or -80, 0, mobile and 5 or 9)
    closeButton.Position = UDim2.new(1, mobile and -50 or -42, 0, mobile and 5 or 9)

    body.Position = UDim2.fromOffset(0, headerHeight)
    body.Size = UDim2.new(1, 0, 1, -headerHeight)

    mobileOptions.Visible = mobile
    sortButton.Parent = mobile and mobileOptions or body
    detailButton.Parent = mobile and mobileOptions or body
    pauseButton.Parent = mobile and mobileOptions or body

    if mobile then
        sortButton.Position = UDim2.new()
        sortButton.Size = UDim2.new(1, 0, 0, 44)
        detailButton.Position = UDim2.fromOffset(0, 52)
        detailButton.Size = UDim2.new(0.56, -4, 0, 44)
        pauseButton.Position = UDim2.new(0.56, 4, 0, 52)
        pauseButton.Size = UDim2.new(0.44, -4, 0, 44)

        list.Position = UDim2.fromOffset(10, 4)
        list.Size = UDim2.new(1, -20, 1, -62)
        settings.Position = UDim2.fromOffset(10, 4)
        settings.Size = UDim2.new(1, -20, 1, -94)

        hopStatus.Position = UDim2.new(0, 10, 1, -84)
        hopStatus.Size = UDim2.new(1, -20, 0, 28)
        settingsButton.Position = UDim2.new(0, 10, 1, -50)
        settingsButton.Size = UDim2.new(0.4, -14, 0, 44)
        hopButton.Position = UDim2.new(0.4, 4, 1, -50)
        hopButton.Size = UDim2.new(0.6, -14, 0, 44)
    else
        sortButton.Position = UDim2.fromOffset(12, 0)
        sortButton.Size = UDim2.new(0.40, -12, 0, 30)
        detailButton.Position = UDim2.new(0.40, 5, 0, 0)
        detailButton.Size = UDim2.new(0.34, -10, 0, 30)
        pauseButton.Position = UDim2.new(0.74, 0, 0, 0)
        pauseButton.Size = UDim2.new(0.26, -12, 0, 30)

        stat.Position = UDim2.fromOffset(12, 38)
        list.Position = UDim2.fromOffset(10, 90)
        list.Size = UDim2.new(1, -20, 1, -205)
        settings.Position = list.Position
        settings.Size = list.Size

        hopStatus.Position = UDim2.new(0, 12, 1, -106)
        hopStatus.Size = UDim2.new(1, -24, 0, 28)
        settingsButton.Position = UDim2.new(0, 12, 1, -73)
        settingsButton.Size = UDim2.new(0.36, -16, 0, 30)
        hopButton.Position = UDim2.new(0.36, 0, 1, -73)
        hopButton.Size = UDim2.new(0.38, -6, 0, 30)
        cancelButton.Position = UDim2.new(0.74, 0, 1, -73)
        cancelButton.Size = UDim2.new(0.26, -12, 0, 30)
    end

    footer.Position = UDim2.new(0, 12, 1, -37)
    footer.Size = UDim2.new(1, -24, 0, 34)
    footer.Visible = not mobile
    stat.Visible = not mobile
    cancelButton.Visible = not mobile
    hopStatus.Visible = not mobile or settings.Visible

    settingsButton.Text = settings.Visible and "Voltar"
        or (mobile and "Ajustes" or "Configurações")

    refreshHopButton()
    clampPosition()
    if render then render() end
end

connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)

connect(settingsButton.Activated, function()
    settings.Visible = not settings.Visible
    list.Visible = not settings.Visible
    layout()
end)

connect(minimizeButton.Activated, function()
    minimized = not minimized
    body.Visible = not minimized
    minimizeButton.Text = minimized and "+" or "—"
    layout()
end)

connect(closeButton.Activated, function()
    gui:Destroy()
end)

local dragInput, dragStart, startPosition

connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        dragStart = input.Position
        startPosition = main.Position
    end
end)

connect(UIS.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)

connect(UIS.InputChanged, function(input)
    if not dragInput then return end

    if input == dragInput
        or (
            dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        ) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
        clampPosition()
    end
end)

local function addBox(label, value, callback)
    local frame = create("Frame", settings, {
        Size = UDim2.new(1, -8, 0, 74),
        BackgroundTransparency = 1,
    })

    text(frame, {
        Text = label,
        Position = UDim2.fromOffset(2, 0),
        Size = UDim2.new(1, -4, 0, 20),
        TextSize = 12,
    })

    local box = create("TextBox", frame, {
        Position = UDim2.fromOffset(0, 23),
        Size = UDim2.new(1, 0, 0, 46),
        Text = tostring(value),
        ClearTextOnFocus = false,
        BackgroundColor3 = Color3.fromRGB(31, 39, 52),
        BorderSizePixel = 0,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.Gotham,
        TextSize = 15,
    })

    create("UICorner", box, {CornerRadius = UDim.new(0, 6)})
    connect(box.FocusLost, function() callback(box.Text) end)
end

local function addToggle(label, value, callback)
    local frame = create("Frame", settings, {
        Size = UDim2.new(1, -8, 0, 50),
        BackgroundTransparency = 1,
    })

    text(frame, {
        Text = label,
        Position = UDim2.fromOffset(2, 5),
        Size = UDim2.new(1, -112, 0, 38),
        TextSize = 12,
    })

    local btn = button(
        frame, "",
        UDim2.new(1, -102, 0, 2),
        UDim2.fromOffset(100, 46)
    )

    local function paint()
        btn.Text = value and "ATIVADO" or "DESATIVADO"
        btn.BackgroundColor3 = value and Color3.fromRGB(73, 103, 51)
            or Color3.fromRGB(48, 58, 76)
    end

    connect(btn.Activated, function()
        value = not value
        paint()
        callback(value)
    end)

    paint()
end

local function addButton(label, callback)
    local frame = create("Frame", settings, {
        Size = UDim2.new(1, -8, 0, 46),
        BackgroundTransparency = 1,
    })

    local btn = button(frame, label, UDim2.new(), UDim2.new(1, 0, 1, 0))
    connect(btn.Activated, callback)
    return btn
end

local function filtersChanged()
    viewVersion = viewVersion + 1
    lastValidEggTime = os.clock()
    if render then render() end
end

addBox("Webhook URL", cfg.W, function(v) cfg.W = v end)
addBox("Ping Discord ID", cfg.P, function(v) cfg.P = v end)

addBox("Rendimento mínimo ($/s)", cfg.I, function(v)
    cfg.I = math.max(0, finite(v) or 0)
    filtersChanged()
end)

addBox("Escala visual mínima (x, não kg)", cfg.S, function(v)
    cfg.S = math.max(0, finite(v) or 0)
    filtersChanged()
end)

addBox("Tempo sem alvos antes do hop (mínimo 5 s)", cfg.AHT, function(v)
    cfg.AHT = math.max(5, finite(v) or 60)
    lastValidEggTime = os.clock()
end)

addToggle("Notificações no Discord", cfg.WH, function(v)
    cfg.WH = v
end)

addToggle("Trocar servidor automaticamente sem alvos", cfg.AH, function(v)
    cfg.AH = v
    lastValidEggTime = os.clock()
end)

local playerCountButton
playerCountButton = addButton(
    "Buscar servidores com " .. cfg.PC .. " jogador(es)",
    function()
        cfg.PC = cfg.PC == 1 and 2 or 1
        playerCountButton.Text = "Buscar servidores com " .. cfg.PC .. " jogador(es)"
    end
)

addButton("Salvar configurações", function()
    if not writefile then
        hopStatus.Text = "Gravação de arquivo indisponível."
        return
    end

    local ok = pcall(function()
        writefile(CONFIG_FILE, Http:JSONEncode(cfg))
    end)

    hopStatus.Text = ok and "Configurações salvas." or "Falha ao salvar configurações."
end)

-- =========================================================
-- RANKING: ORDENA E REDESENHA APENAS QUANDO NECESSARIO
-- =========================================================

local function rebuildSorted()
    if sortedVersion == dataVersion and sortedMode == sortMode then return end

    table.clear(sorted)
    for uid, data in pairs(cached) do
        sorted[#sorted + 1] = {uid = uid, data = data}
    end

    table.sort(sorted, function(left, right)
        local aa, bb = left.data, right.data

        if aa.Ready ~= bb.Ready then return aa.Ready end

        local av, bv = aa.R, bb.R

        if sortMode == 2 then
            av = aa.EconomicScale or aa.S
            bv = bb.EconomicScale or bb.S
        elseif sortMode == 3 then
            av = rarityRanks[aa.Rar] or 0
            bv = rarityRanks[bb.Rar] or 0
        end

        if av ~= bv then return av > bv end
        if aa.R ~= bb.R then return aa.R > bb.R end
        if aa.C ~= bb.C then return aa.C < bb.C end
        return left.uid < right.uid
    end)

    sortedVersion = dataVersion
    sortedMode = sortMode
end

render = function()
    if not alive or minimized or settings.Visible then return end

    local renderKey = table.concat({
        dataVersion, viewVersion, sortMode,
        compact and 1 or 0, mobile and 1 or 0,
    }, ":")

    if renderKey == lastRendered then return end

    rebuildSorted()
    local seen = {}

    for index, entry in ipairs(sorted) do
        local uid, data = entry.uid, entry.data
        local row = rows[uid]
        seen[uid] = true

        if not row then
            local frame = create("Frame", list, {
                BackgroundColor3 = Color3.fromRGB(31, 39, 52),
                BorderSizePixel = 0,
            })

            create("UICorner", frame, {CornerRadius = UDim.new(0, 8)})

            row = {
                frame = frame,
                icon = create("ImageLabel", frame, {
                    Position = UDim2.fromOffset(10, 9),
                    Size = UDim2.fromOffset(48, 48),
                    BackgroundTransparency = 1,
                    ScaleType = Enum.ScaleType.Fit,
                }),
                title = text(frame, {
                    Font = Enum.Font.GothamBold,
                    TextSize = 15,
                    TextWrapped = false,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                }),
                value = text(frame, {
                    Font = Enum.Font.GothamBold,
                    TextSize = 15,
                }),
                meta = text(frame, {
                    Position = UDim2.fromOffset(12, 61),
                    TextSize = 12,
                }),
                details = text(frame, {
                    Size = UDim2.new(1, -24, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextSize = 11,
                }),
            }
            rows[uid] = row
        end

        if row.data ~= data
            or row.rank ~= index
            or row.view ~= viewVersion
            or row.compact ~= compact
            or row.mobile ~= mobile then

            row.frame.LayoutOrder = index
            row.frame.Size = UDim2.new(1, -7, 0, mobile and 96 or 102)
            row.frame.AutomaticSize = compact and Enum.AutomaticSize.None
                or Enum.AutomaticSize.Y

            row.meta.Size = UDim2.new(1, -24, 0, mobile and 30 or 36)
            row.details.Position = UDim2.fromOffset(12, mobile and 97 or 101)
            row.details.TextSize = mobile and 12 or 11
            row.value.TextSize = mobile and 14 or 15

            local hasIcon = type(data.Icon) == "string" and data.Icon ~= ""
            row.icon.Image = data.Icon or ""
            row.icon.Visible = hasIcon

            local left = hasIcon and 66 or 12
            row.title.Position = UDim2.fromOffset(left, 9)
            row.title.Size = UDim2.new(1, -left - 12, 0, 24)
            row.value.Position = UDim2.fromOffset(left, 35)
            row.value.Size = UDim2.new(1, -left - 12, 0, 22)

            row.title.Text = string.format("#%02d  %s", index, data.C)
            row.title.TextColor3 = rarityColors[data.Rar]
                or Color3.fromRGB(220, 225, 240)

            row.value.Text = data.Ready
                and ("~$" .. short(data.R) .. "/s  •  " .. data.Rar)
                or "PENDENTE • aguardando dados"

            row.value.TextColor3 = data.Ready
                and Color3.fromRGB(155, 245, 105)
                or Color3.fromRGB(255, 192, 100)

            if mobile then
                row.meta.Text = (
                    data.Weight and (exact(data.Weight) .. " kg")
                    or (exact(data.EconomicScale or data.S) .. "×")
                ) .. "  •  Área " .. tostring(data.A)
            else
                row.meta.Text = string.format(
                    "%s %s× • Área %s\nPeso estimado: %s kg • %s",
                    data.EconomicScale and "Escala corrigida" or "Escala visual",
                    exact(data.EconomicScale or data.S),
                    tostring(data.A), exact(data.Weight),
                    data.Availability or "Disponibilidade não informada"
                )
            end

            row.details.Visible = not compact

            -- Não formata detalhes escondidos.
            if not compact then
                row.details.Text = string.format(
                    "Visual: %s× → corrigida: %s×\nBase: $%s/s • multiplicador: %s×\nRenda estimada: $%s/s\nTemplate: %s\nOrigem: %s\nUID: %s\n%s\n%s\n%s\n ",
                    exact(data.S), exact(data.EconomicScale),
                    exact(data.Base), exact(data.ScaleMult),
                    data.Ready and exact(data.R) or "pendente",
                    data.Template or "não informado",
                    data.Source or data.C, uid,
                    data.MutationNote or "Mutação não informada",
                    isTarget(data) and "ALVO • atende aos filtros"
                        or "Fora dos filtros / dados pendentes",
                    data.Reason or ""
                )
            end

            row.data = data
            row.rank = index
            row.view = viewVersion
            row.compact = compact
            row.mobile = mobile
        end
    end

    for uid, row in pairs(rows) do
        if not seen[uid] then
            row.frame:Destroy()
            rows[uid] = nil
        end
    end

    empty.Visible = #sorted == 0
    lastRendered = renderKey
end

connect(sortButton.Activated, function()
    sortMode = sortMode % #sortNames + 1
    sortButton.Text = sortNames[sortMode]
    render()
end)

connect(detailButton.Activated, function()
    compact = not compact
    detailButton.Text = compact and "Detalhes: OFF" or "Detalhes: ON"
    render()
end)

connect(pauseButton.Activated, function()
    paused = not paused
    pauseButton.Text = paused and "Retomar" or "Pausar"
    lastValidEggTime = os.clock()

    if paused then
        if isHopping and cancelHop then cancelHop() end
        stat.Text = "PAUSADO • última leitura mantida"
        hopStatus.Text = "Auto hop suspenso enquanto o radar está pausado."
    end
end)

-- =========================================================
-- MODULOS E CACHE DE TEMPLATES
-- =========================================================

local modules = {}
local moduleRevision = 0
local nextModuleTry = 0

local modulePaths = {
    EggState = {"Client", "EggState"},
    AssetItems = {"Shared", "Util", "AssetItems"},
    AssetEarnings = {"Shared", "Util", "AssetEarnings"},
    Mutations = {"Shared", "Modules", "Mutations"},
    HalloweenPets = {"Data", "HalloweenPets"},
    Assets = {"Data", "Assets"},
}

local function loadModules()
    local now = os.clock()
    if now < nextModuleTry then return end
    nextModuleTry = now + 5

    for name, path in pairs(modulePaths) do
        if not modules[name] then
            local object = RS
            for _, part in ipairs(path) do
                object = object and object:FindFirstChild(part)
            end

            if object and object:IsA("ModuleScript") then
                local ok, result = pcall(require, object)
                if ok and type(result) == "table" then
                    modules[name] = result
                    moduleRevision = moduleRevision + 1
                end
            end
        end
    end
end

local geometryCache = {}

local function templateGeometry(name)
    if type(name) ~= "string" or name == "" then
        return nil, "Template não informado"
    end

    local now = os.clock()
    local previous = geometryCache[name]

    if previous
        and now < previous.expires
        and previous.model.Parent == previous.parent
        and previous.model.Name == name then
        return previous
    end

    local assets = RS:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local eggs = models and models:FindFirstChild("Eggs")

    if not eggs then return nil, "Templates não carregados" end

    local found
    for _, child in ipairs(eggs:GetChildren()) do
        if child.Name == name and child:IsA("Model") then
            if found then return nil, "Template ambíguo: " .. name end
            found = child
        end
    end

    if not found then return nil, "Template ausente: " .. name end

    local size = found:GetExtentsSize()
    local result = {
        model = found,
        parent = eggs,
        scale = found:GetScale(),
        dimension = math.max(size.X, size.Y, size.Z),
        expires = now + GEOMETRY_TTL,
    }

    geometryCache[name] = result
    return result
end

local sourceCache = {}
local sourceCacheSpecs
local sourceCacheExpiry = 0

local function resolveSource(source)
    local specs = modules.HalloweenPets and modules.HalloweenPets.Specs
    if type(specs) ~= "table" then
        return nil, nil, "HalloweenPets.Specs indisponível"
    end

    if type(source) ~= "string" or source == "" then
        return nil, nil, "Origem não informada"
    end

    local now = os.clock()
    if sourceCacheSpecs ~= specs or now >= sourceCacheExpiry then
        table.clear(sourceCache)
        sourceCacheSpecs = specs
        sourceCacheExpiry = now + 30
    end

    local hit = sourceCache[source]
    if hit then return hit.id, hit.key end

    local direct = specs[source]
    if type(direct) == "table" then
        local id = direct.Id or source
        sourceCache[source] = {id = id, key = source}
        return id, source
    end

    local id, key
    for candidate, spec in pairs(specs) do
        if type(spec) == "table"
            and (spec.EggSource == source or spec.EggModel == source) then
            local candidateId = spec.Id or candidate
            if id and id ~= candidateId then
                return nil, nil, "Origem ambígua"
            end
            id, key = candidateId, candidate
        end
    end

    if id then
        sourceCache[source] = {id = id, key = key}
        return id, key
    end

    return nil, nil, "Origem não encontrada em Specs"
end

local aliases = {
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

-- Compatibilidade para registros sem modelo Halloween.
local halloweenFallback = {
    ["Hexed Pumpkin"]={150000000,"Cosmic"},
    ["Graveyard Brute"]={75000000,"Secret"},
    ["Toadstool"]={1600000,"Mythic"},
    ["Haunted Scorpio"]={30000000,"Cosmic"},
    ["Crowshade"]={4500000,"Mythic"},
    ["Shelltide Voyager"]={1600000000,"Eternal"},
    ["Halloween Gigantopithecus"]={1500000000,"Eternal"},
    ["Werewolf"]={1300000000,"Secret"},
    ["Mimic Chest"]={600000,"Legendary"},
    ["Zombified Halloween Glyptodon"]={800000000,"Secret"},
    ["Zombified Halloween Dunkleosteus"]={4000000000,"Eternal"},
    ["BloodBloom"]={450000000,"Secret"},
    ["Hooded Gerbil"]={300000,"Legendary"},
    ["Ghost Reaper"]={300000000,"Eternal"},
    ["Abomination Kong"]={3500000000,"Eternal"},
    ["Patchwork Imp"]={20000000,"Cosmic"},
    ["Voidseer Pumpkin"]={14000000000,"Divine"},
    ["Halloween Terrorbird"]={160000,"Mythic"},
    ["Halloween Dunkleosteus"]={450000000,"Secret"},
    ["Zombified Halloween Terrorbird"]={1100000000,"Secret"},
    ["Zombified Halloween Gigantopithecus"]={6000000000,"Eternal"},
    ["Candlefang"]={225000,"Mythic"},
    ["Jesterpop"]={40000,"Legendary"},
    ["Whiskers"]={2000,"Epic"},
    ["Zombified Halloween Sabertooth"]={14000000000,"Divine"},
    ["Halloween Sabertooth"]={7500000000,"Divine"},
    ["Halloween Glyptodon"]={35000,"Legendary"},
    ["Spirit Knight"]={3000000,"Cosmic"},
    ["Zombified Halloween Megatherium"]={1400000000,"Secret"},
    ["Halloween Megatherium"]={6000000,"Cosmic"},
}

local function getAsset(name)
    if not name then return nil end

    local directory = modules.Assets and modules.Assets.Directory
    if type(directory) == "table" and type(directory[name]) == "table" then
        return directory[name]
    end

    local assets = modules.AssetItems and modules.AssetItems.Assets
    if type(assets) == "table" then
        if type(assets.Directory) == "table"
            and type(assets.Directory[name]) == "table" then
            return assets.Directory[name]
        end
        if type(assets[name]) == "table" then return assets[name] end
    end
end

local function iconOf(asset)
    if type(asset) ~= "table" then return nil end
    local icon = asset.Icon or asset.Thumbnail

    if type(icon) == "number" or (type(icon) == "string" and tonumber(icon)) then
        return "rbxassetid://" .. tostring(icon)
    end
    if type(icon) == "string" then return icon end
end

local function rarityName(value)
    if type(value) == "table" then
        value = value.DisplayName or value.Name or value._id
    end
    if value == nil then return nil end
    value = tostring(value)
    if value == "" or value == "Unknown" then return nil end
    return value
end

local rarityHints = {
    {"Divine", {"nightflame","unicornegg","unicorn egg","shatteredcolossus","kitsune","elmaja","el maja"}},
    {"Eternal", {"gorillaking","gorilla king","lunardragon","lunar dragon","onitiger","oni tiger","mosasaurus"}},
    {"Secret", {"mutantshark","mutant shark","skeletonboss","skeleton boss","stagegg","stag egg","cosmicdragon","cosmic dragon","trex","t-rex","tralaledon","kraken"}},
    {"Cosmic", {"saturnita","saturno","mantaris","mantis","moth","imp","rhinotaur","snowyowl","snowy owl","koiegg","koi egg","triceratops","bronto","whaleshark","whale shark","belugawhale","beluga whale"}},
    {"Mythic", {"bladehide","redpanda","red panda","cosmicgorilla","cosmic gorilla","ankylosaurus","orca"}},
    {"Legendary", {"spideron","crustacia","salamander","cosmicgecko","cosmic gecko","pterodactyl","sharkegg","shark egg"}},
    {"Epic", {"crane","centapede","swordfish"}},
    {"Rare", {"dodo","parrotfish"}},
}

local rarityOrder = {
    "Divine","Eternal","Secret","Cosmic","Mythic",
    "Legendary","Epic","Uncommon","Rare","Common",
}

local function inferRarity(name, attrs, rec, asset, modelName)
    local direct = rarityName(attrs.Rarity or attrs.RarityTier or attrs.Tier)
        or rarityName(rec.Rarity)
        or rarityName(asset and asset.Rarity)

    if direct then return direct end

    local search = string.lower(
        tostring(name) .. " " .. tostring(rec.Uid or "") .. " " .. tostring(modelName or "")
    )

    for _, rarity in ipairs(rarityOrder) do
        if string.find(search, string.lower(rarity), 1, true) then return rarity end
    end

    for _, group in ipairs(rarityHints) do
        for _, hint in ipairs(group[2]) do
            if string.find(search, hint, 1, true) then return group[1] end
        end
    end

    local income = finite(rec.EarningRate or rec.Income or attrs.Income)
    if income and income >= 150000000 then return "Secret" end

    return "Normal"
end

local function incomeFor(base, scale)
    base, scale = finite(base), finite(scale)
    if not base or base < 0 or not scale or scale <= 0 then return nil end

    local mult = scale <= 5 and scale ^ 1.85
        or ((scale / 5) ^ 1.2) * 19.637875755794113

    return finite(base * mult), mult
end

local function mutationInfo(value)
    if value == nil then
        return 1, "Mutação não informada • renda estimada"
    end

    if value == false or value == ""
        or (type(value) == "table" and next(value) == nil) then
        return 1, "Sem mutações registradas • renda estimada"
    end

    local module = modules.Mutations
    if module and type(module.EarningsFor) == "function" then
        local ok, result = pcall(module.EarningsFor, value)
        result = ok and positive(result, nil) or nil
        if result then
            return result, "Mutação informada • multiplicador usado: " .. exact(result) .. "×"
        end
    end

    return 1, "Mutação informada • multiplicador indisponível"
end

-- =========================================================
-- ASSINATURA DOS DADOS: DETECTA MUDANCAS, INCLUSIVE EM TABELAS
-- =========================================================

local recordFields = {
    "AssetCategory","Category","ItemName",
    "PreparedSourceName","DisplayName",
    "AreaId","Area","Zone","Scale","AssetScale",
    "Mutations","Mutation","Rarity",
    "Income","EarningRate","MoneyPerSecond","ItemData","Uid",
}

local function signature(value)
    local budget = 256
    local seen = {}

    local function encode(item, depth)
        budget = budget - 1
        if budget < 0 or depth > 8 then error("signature limit") end

        local kind = type(item)
        if kind == "nil" then return "nil" end
        if kind == "string" then return "s" .. string.format("%q", item) end
        if kind == "boolean" then return item and "true" or "false" end
        if kind == "number" then return "n" .. string.format("%.17g", item) end

        if kind ~= "table" then
            return kind .. ":" .. tostring(item)
        end

        if seen[item] then error("signature cycle") end
        seen[item] = true

        local parts = {}
        for key, child in pairs(item) do
            parts[#parts + 1] = encode(key, depth + 1) .. "=" .. encode(child, depth + 1)
        end

        table.sort(parts)
        seen[item] = nil
        return "{" .. table.concat(parts, ";") .. "}"
    end

    local ok, result = pcall(encode, value, 0)
    return ok and result or nil
end

local function sameCard(aa, bb)
    if not aa or not bb then return false end
    for key, value in pairs(aa) do
        if bb[key] ~= value then return false end
    end
    for key, value in pairs(bb) do
        if aa[key] ~= value then return false end
    end
    return true
end

local function readInputs(model, rec)
    local attrs = model and model:GetAttributes() or {}
    local visual

    if model and model:IsA("Model") then
        visual = finite(model:GetScale())
    end

    local recValues = {}
    for _, field in ipairs(recordFields) do
        recValues[field] = rec[field]
    end

    return attrs, visual, signature({
        attrs = attrs,
        rec = recValues,
        visual = visual,
        modelName = model and model.Name or "",
        revision = moduleRevision,
    })
end

-- =========================================================
-- CALCULO UNICO POR OVO
-- =========================================================

local function buildCard(uid, model, rec, attrs, visual)
    local mutation = attrs.Mutations or attrs.Mutation or rec.Mutations or rec.Mutation
    local mutationMult, mutationNote = mutationInfo(mutation)

    local card = {
        C = "Ovo não identificado",
        A = tostring(attrs.AreaId or attrs.Area or attrs.Zone or rec.AreaId or rec.Zone or "?"),
        S = positive(visual, 1),
        CS = positive(visual, 1),
        R = 0,
        P = "1.00x",
        Rar = "Normal",
        Ready = false,
        MutationNote = mutationNote,
    }

    -- Halloween: não passa pelo calculo generico.
    if model and attrs.HalloweenEggUid ~= nil then
        local source = attrs.PreparedSourceName

        if type(source) == "string" and source ~= "" then
            knownSources[uid] = source
        else
            source = knownSources[uid]
        end

        local id, key, reason = resolveSource(source)
        local directory = modules.Assets and modules.Assets.Directory
        local asset = type(directory) == "table" and id and directory[id]

        if type(asset) ~= "table" and type(directory) == "table"
            and key and type(directory[key]) == "table" then
            id, asset = key, directory[key]
        end

        card.C = tostring(id or source or "Ovo não identificado")
        card.Source = tostring(source or "ausente")
        card.A = tostring(attrs.Zone or "?")
        card.P = exact(card.S) .. "x"
        card.Rar = "Desconhecida"

        if type(asset) ~= "table" then
            card.Reason = reason or "Assets.Directory indisponível"
            return card
        end

        card.Base = finite(asset.EarningRate)
        card.Rar = rarityName(asset.Rarity) or "Desconhecida"
        card.Icon = iconOf(asset)

        local egg = type(asset.Egg) == "table" and asset.Egg or {}
        card.Template = egg.ModelName

        local geometry, geometryError = templateGeometry(card.Template)
        if not geometry then
            card.Reason = geometryError
            return card
        end

        local zone = finite(attrs.Zone)
        if zone ~= 1 and zone ~= 2 and zone ~= 3 then
            card.Reason = "Conversão validada apenas nas zonas 1–3"
            return card
        end

        if not finite(geometry.scale)
            or math.abs(geometry.scale - 1) > 0.000001 then
            card.Reason = "Template com escala diferente de 1"
            return card
        end

        if not visual or visual <= 0 or geometry.dimension <= 0 then
            card.Reason = "Escala ou geometria inválida"
            return card
        end

        card.EconomicScale = finite(visual * geometry.dimension / (4.5 + zone))

        local income, mult = incomeFor(card.Base, card.EconomicScale)
        local adjusted = income and finite(income * mutationMult)

        if adjusted then
            card.R = math.floor(adjusted + 0.5)
            card.ScaleMult = mult
            card.Ready = true
        else
            card.Reason = "Renda pendente"
        end

        local baseWeight = positive(egg.WeightKg, nil)
        if baseWeight and card.EconomicScale then
            card.Weight = finite(baseWeight * card.EconomicScale ^ 3)
        end

        return card
    end

    -- Demais ovos: conserva os aliases e as fontes da V17.
    local rawCategory = attrs.Category or attrs.AssetCategory or attrs.ItemName
        or rec.AssetCategory or rec.Category or rec.ItemName or "Egg"

    local rawDisplay = attrs.PreparedSourceName or attrs.DisplayName
        or rec.PreparedSourceName or rec.DisplayName or rawCategory

    if rawDisplay == "Egg" and model
        and model.Name ~= "Model" and model.Name ~= "Part"
        and #model.Name < 30 and not string.find(model.Name, "_", 1, true) then
        rawDisplay = model.Name
    end

    local category = aliases[rawCategory] or rawCategory
    local display = aliases[rawDisplay] or rawDisplay
    local modelName = model and (aliases[model.Name] or model.Name)

    local asset = getAsset(display) or getAsset(category) or getAsset(modelName)
    local fallback = halloweenFallback[display]
        or halloweenFallback[category]
        or (modelName and halloweenFallback[modelName])

    local scale = finite(attrs.Scale or attrs.AssetScale or rec.Scale or rec.AssetScale)

    if not scale then
        scale = visual
        if model and model:IsA("Model") and (not scale or scale == 1) then
            local size = model:GetExtentsSize()
            local largest = math.max(size.X, size.Y, size.Z)
            if largest > 5 then scale = largest / 4.5 end
        end
    end

    scale = positive(scale, 1)

    local base
    if fallback then
        base = fallback[1]
    else
        local specs = modules.HalloweenPets and modules.HalloweenPets.Specs
        for _, name in ipairs({display, category, modelName}) do
            if not base or base == 0 then
                local spec = type(specs) == "table" and specs[name]
                if type(spec) == "table" then base = finite(spec.EarningRate) end

                if not base or base == 0 then
                    local candidate = getAsset(name)
                    if candidate then
                        base = finite(candidate.EarningRate
                            or (type(candidate.Egg) == "table" and candidate.Egg.EarningRate))
                    end
                end
            end
        end

        if not base or base == 0 then
            base = finite(attrs.Income or attrs.EarningRate
                or rec.Income or rec.EarningRate or rec.MoneyPerSecond)
        end

        if (not base or base == 0) and type(rec.ItemData) == "table" then
            base = finite(rec.ItemData.MoneyPerSecond or rec.ItemData.Income)
        end
    end

    card.C = tostring(display)
    card.Source = tostring(rawDisplay)
    card.S, card.CS = scale, scale
    card.P = string.format("%.1fx", scale)
    card.Base = base
    card.Icon = iconOf(asset)
    card.Rar = fallback and fallback[2]
        or inferRarity(display, attrs, rec, asset, modelName)

    local income, mult = incomeFor(base, scale)
    local adjusted = income and finite(income * mutationMult)

    if adjusted then
        card.R = math.floor(adjusted + 0.5)
        card.ScaleMult = mult
        card.Ready = true
    end

    local earnings = modules.AssetEarnings
    if not fallback and earnings
        and type(earnings.MutationOnlyRatePerSecond) == "function" then
        local function nativeRate(name)
            local ok, result = pcall(earnings.MutationOnlyRatePerSecond, {
                Category = name,
                Mutations = mutation,
                Scale = scale,
            })
            return ok and positive(result, nil) or nil
        end

        local native = nativeRate(category)
        if not native and display ~= category then native = nativeRate(display) end

        if native and native > card.R then
            card.R = native
            card.Ready = true
        end
    end

    if not card.Ready then card.Reason = "Renda base indisponível" end
    return card
end

-- Prompt é observado separadamente: mudar Enabled não refaz o cálculo.
local function availabilityFor(model, state)
    if not model then return nil end

    local prompt = state.prompt
    if prompt and (not prompt.Parent or not prompt:IsDescendantOf(model)) then
        prompt = nil
    end

    local now = os.clock()
    if not prompt and now >= (state.nextPromptTry or 0) then
        prompt = model:FindFirstChild("StealPrompt", true)
        if prompt and not prompt:IsA("ProximityPrompt") then prompt = nil end
        state.nextPromptTry = now + 5
    end

    state.prompt = prompt
    if not prompt then return "Prompt ausente" end
    return prompt.Enabled and "Disponível" or "Prompt desativado"
end

-- =========================================================
-- WEBHOOK: FORA DO LOOP DE VARREDURA
-- =========================================================

local notified = {}
local notificationBusy = {}

local function joinLink()
    return "https://darling-liger-02e311.netlify.app/index.html?placeId="
        .. tostring(game.PlaceId) .. "&jobId=" .. tostring(game.JobId)
end

local function postWebhook(payload)
    if not alive or not requestFn or cfg.W == "" then return false end

    local url = cfg.W
    local ok, response = pcall(function()
        return requestFn({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = Http:JSONEncode(payload),
        })
    end)

    if not ok then return false end

    local status = type(response) == "table"
        and tonumber(response.StatusCode or response.Status)

    -- Alguns ambientes não retornam o status.
    if not status then return true end
    return status >= 200 and status < 300
end

local function notifyEgg(uid)
    if notified[uid] or notificationBusy[uid] then return end
    if not cfg.WH or cfg.W == "" or not requestFn then return end

    notificationBusy[uid] = true

    task.spawn(function()
        local data = cached[uid]
        if not alive or not cfg.WH or not isTarget(data) then
            notificationBusy[uid] = nil
            return
        end

        local link = joinLink()
        local content = "**" .. player.Name .. "** encontrou **"
            .. data.C .. "** de **" .. short(data.R) .. "/s**"

        if cfg.P ~= "" then content = content .. " <@" .. cfg.P .. ">" end

        local success = postWebhook({
            content = content,
            embeds = {{
                title = "🥚 Ovo detectado!",
                url = link,
                color = 65352,
                fields = {
                    {name="Categoria", value=data.C, inline=true},
                    {name="Área", value=tostring(data.A), inline=true},
                    {name="Raridade", value=data.Rar, inline=true},
                    {name="Tamanho", value=data.P, inline=true},
                    {name="Dinheiro/s", value="$"..short(data.R).."/s", inline=true},
                    {name="Servidor", value="[Abrir servidor]("..link..")", inline=false},
                },
            }},
        })

        if success then
            notified[uid] = true
            notificationBusy[uid] = nil
        else
            -- Impede repetir a requisição a cada 1,5 s em caso de falha.
            task.delay(60, function()
                notificationBusy[uid] = nil
            end)
        end
    end)
end

addButton("Enviar teste ao Discord", function()
    if not requestFn or cfg.W == "" then
        hopStatus.Text = "Informe o webhook e confira o suporte a HTTP."
        return
    end

    task.spawn(function()
        local items = {}
        for _, data in pairs(cached) do
            if data.Ready then items[#items + 1] = data end
        end

        table.sort(items, function(aa, bb) return aa.R > bb.R end)

        local lines = {}
        for index = 1, math.min(15, #items) do
            local data = items[index]
            lines[#lines + 1] = "• **" .. data.C .. "** | $" .. short(data.R) .. "/s"
        end

        local description = #lines > 0 and table.concat(lines, "\n")
            or "Nenhum ovo calculado no momento."

        local ok = postWebhook({
            content = "Teste do Dice Radar!" .. (cfg.P ~= "" and (" <@" .. cfg.P .. ">") or ""),
            embeds = {{
                title = "Teste do radar",
                description = string.sub(description, 1, 3900),
                url = joinLink(),
                color = 65352,
            }},
        })

        if alive then
            hopStatus.Text = ok and "Teste enviado." or "Falha ao enviar o teste."
        end
    end)
end)

-- =========================================================
-- SERVER HOP: SEM HEARTBEAT
-- =========================================================

cancelHop = function()
    hopGeneration = hopGeneration + 1
    lastValidEggTime = os.clock()
    setHopState(false, "Busca cancelada. Temporizador reiniciado.")
end

doServerHop = function()
    if isHopping or not alive then return end

    hopGeneration = hopGeneration + 1
    local generation = hopGeneration
    setHopState(true, "Buscando servidores...")

    local function current()
        return alive and generation == hopGeneration
    end

    local function release(message)
        if not current() then return end
        lastValidEggTime = os.clock()
        setHopState(false, message)
    end

    local ok, err = pcall(function()
        local cursor = ""
        local failures = 0
        local target = cfg.PC
        local remainingToSkip = target == 1 and 50 or 0

        for page = 1, 30 do
            if not current() then return end

            hopStatus.Text = string.format(
                "Buscando %d jogador(es) • página %d/30",
                target, page
            )

            local url = "https://games.roblox.com/v1/games/"
                .. tostring(game.PlaceId)
                .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"

            if cursor ~= "" then url = url .. "&cursor=" .. Http:UrlEncode(cursor) end
            url = url .. "&_nocache=" .. tostring(math.floor(os.clock() * 1000))

            local success, data = pcall(function()
                return Http:JSONDecode(game:HttpGet(url))
            end)

            if not current() then return end

            if not success or type(data) ~= "table" or type(data.data) ~= "table" then
                failures = failures + 1
                if failures >= 3 then
                    release("Busca interrompida após 3 falhas.")
                    return
                end
                hopStatus.Text = "Falha na consulta. Tentando novamente..."
                task.wait(failures)
            else
                failures = 0

                -- Candidatos existem apenas para esta pagina.
                -- Modo 1: descarta somente os primeiros 50 resultados da busca inteira.
                local candidates = {}
                local skipped = math.min(remainingToSkip, #data.data)
                remainingToSkip = remainingToSkip - skipped
                local firstIndex = skipped + 1
                for index = firstIndex, #data.data do
                    local server = data.data[index]
                    if type(server) == "table" then
                        local playing = finite(server.playing)
                        local maximum = finite(server.maxPlayers)

                        if type(server.id) == "string"
                            and server.id ~= ""
                            and server.id ~= game.JobId
                            and playing == target
                            and maximum and playing < maximum then
                            candidates[#candidates + 1] = server.id
                        end
                    end
                end

                if #candidates > 0 then
                    if not current() then return end
                    local selected = candidates[math.random(1, #candidates)]
                    hopStatus.Text = "Teleportando..."
                    Teleport:TeleportToPlaceInstance(game.PlaceId, selected, player)

                    task.delay(12, function()
                        if current() and isHopping then
                            release("Teleporte não concluído. Tente novamente.")
                        end
                    end)
                    return
                end

                if type(data.nextPageCursor) ~= "string"
                    or data.nextPageCursor == "" then
                    break
                end

                cursor = data.nextPageCursor
                task.wait(0.15)
            end
        end

        if not current() then return end

        release("Nenhum servidor com " .. target .. " jogador(es) passou pelo filtro.")
    end)

    if not ok then
        release("Falha ao buscar ou teleportar.")
        warn("[Dice Radar hop] " .. tostring(err))
    end
end

connect(Teleport.TeleportInitFailed, function(failedPlayer)
    if failedPlayer == player and alive and isHopping then
        hopGeneration = hopGeneration + 1
        lastValidEggTime = os.clock()
        setHopState(false, "O teleporte falhou. Tente outro servidor.")
    end
end)

connect(hopButton.Activated, function()
    if isHopping then
        cancelHop()
    else
        task.spawn(doServerHop)
    end
end)

connect(cancelButton.Activated, cancelHop)



-- =========================================================
-- DESCOBERTA E VARREDURA
-- =========================================================

local scanFolders = {}
local nextFolderRefresh = 0

local function refreshFolders()
    local now = os.clock()
    if now < nextFolderRefresh then return end
    nextFolderRefresh = now + 5

    table.clear(scanFolders)
    local seen = {}

    local function add(folder)
        if folder and not seen[folder] then
            seen[folder] = true
            scanFolders[#scanFolders + 1] = folder
        end
    end

    add(Workspace:FindFirstChild("AreaEggSlotsClient"))
    add(Workspace:FindFirstChild("__DEBRIS"))

    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Folder")
            and string.find(string.lower(child.Name), "eggslots", 1, true) then
            add(child)
        end
    end

    local dimension = Workspace:FindFirstChild("HalloweenDimension")
    add(dimension and dimension:FindFirstChild("WorldEggs"))
end

local emptyRecord = {}

local function collectSources()
    refreshFolders()

    local models, records, all = {}, {}, {}

    for _, folder in ipairs(scanFolders) do
        if folder:IsDescendantOf(Workspace) then
            for _, child in ipairs(folder:GetChildren()) do
                local uid = child:GetAttribute("UID")
                    or child:GetAttribute("Uid")
                    or child:GetAttribute("EggUid")
                    or child:GetAttribute("HalloweenEggUid")
                    or child:GetAttribute("Id")

                if not uid and child.Name ~= "Model" and child.Name ~= "Part" then
                    uid = child.Name
                end

                if uid then
                    uid = tostring(uid)
                    models[uid] = child
                    all[uid] = true
                end
            end
        end
    end

    local state = modules.EggState
    if state then
        local reader = state.ReadFieldEggs or state.SyncFieldEggs
        if type(reader) == "function" then
            local ok, result = pcall(reader)
            if ok and type(result) == "table" then
                local source = result.Records or result
                if type(source) == "table" then
                    for key, rec in pairs(source) do
                        if type(rec) == "table" then
                            local uid = tostring(rec.Uid or rec.HalloweenEggUid or rec.Id or key)
                            records[uid] = rec
                            all[uid] = true
                        end
                    end
                end
            end
        end
    end

    -- O estado atualizado tem prioridade sobre valores em cache ou modelos antigos.
    -- Claimed foi confirmado no diagnostico de ovos coletados do mapa normal.
    for uid, rec in pairs(records) do
        local model = models[uid]
        local halloween = rec.HalloweenEggUid ~= nil
            or (model and model:GetAttribute("HalloweenEggUid") ~= nil)
        if not halloween and rec.State == "Claimed" then
            all[uid] = nil
            models[uid] = nil
            -- Invalida imediatamente a renda usada por notificacoes ainda nao enviadas.
            if cached[uid] then
                cached[uid] = nil
                dataVersion = dataVersion + 1
            end
            cacheState[uid] = nil
            knownSources[uid] = nil
            notified[uid] = nil
            local row = rows[uid]
            if row then
                row.frame:Destroy()
                rows[uid] = nil
            end
        end
    end

    return models, records, all
end

local function updateEgg(uid, model, rec, now)
    local attrs, visual, inputSignature = readInputs(model, rec)
    local state = cacheState[uid]

    local recalculate = not state
        or state.model ~= model
        or not inputSignature
        or state.signature ~= inputSignature
        or now >= state.expires
        or not cached[uid]
        or not cached[uid].Ready

    if not state or state.model ~= model then
        state = {model = model}
        cacheState[uid] = state
    end

    local card = cached[uid]

    if recalculate then
        local result = buildCard(uid, model, rec, attrs, visual)

        state.signature = inputSignature
        -- Revisões distribuídas para não expirar todos os ovos juntos.
        state.expires = now + 25 + math.random() * 10

        if not sameCard(card, result) then
            card = result
        end
    end

    local availability = availabilityFor(model, state)

    if card.Availability ~= availability then
        local updated = {}
        for key, value in pairs(card) do updated[key] = value end
        updated.Availability = availability
        card = updated
    end

    if cached[uid] ~= card then
        cached[uid] = card
        dataVersion = dataVersion + 1
    end

    return card
end

local lastScanWarning = 0

local function scan()
    loadModules()

    local models, records, all = collectSources()
    local total, targets, best, errors = 0, 0, 0, 0
    local now = os.clock()

    for uid in pairs(all) do
        total = total + 1

        local ok, data = pcall(
            updateEgg, uid, models[uid], records[uid] or emptyRecord, now
        )

        if ok and data then
            best = math.max(best, data.R)

            if isTarget(data) then
                targets = targets + 1
                notifyEgg(uid)
            end
        else
            errors = errors + 1
            -- Não deixa valor antigo continuar sendo alvo após erro.
            if cached[uid] then
                cached[uid] = nil
                cacheState[uid] = nil
                dataVersion = dataVersion + 1
            end
        end
    end

    for uid in pairs(cached) do
        if not all[uid] then
            cached[uid] = nil
            cacheState[uid] = nil
            knownSources[uid] = nil
            notified[uid] = nil
            dataVersion = dataVersion + 1

            -- Libera objetos de ovos removidos mesmo com painel escondido.
            local row = rows[uid]
            if row then
                row.frame:Destroy()
                rows[uid] = nil
            end
        end
    end

    for uid in pairs(cacheState) do
        if not all[uid] then
            cacheState[uid] = nil
            knownSources[uid] = nil
        end
    end

    if targets > 0 then
        lastValidEggTime = now
    elseif errors == 0 and cfg.AH and not isHopping
        and now - lastValidEggTime >= cfg.AHT then
        task.spawn(doServerHop)
    end

    if not minimized and not mobile then
        local stateText = "Monitorando o mapa"

        if cfg.AH and targets == 0 then
            local remaining = math.max(
                0, math.ceil(cfg.AHT - (now - lastValidEggTime))
            )
            stateText = "Sem alvos • hop em " .. remaining .. "s"
        end

        setText(stat, string.format(
            "%s\nOvos: %d • Alvos: %d\nMelhor: $%s/s",
            stateText, total, targets, short(best)
        ))
    end

    if errors > 0 and now - lastScanWarning >= 10 then
        lastScanWarning = now
        warn("[Dice Radar] Falha de leitura em " .. errors .. " ovo(s); nova tentativa no próximo ciclo.")
    end

    render()
end

body.Visible = false
minimizeButton.Text = "+"

layout()

task.spawn(function()
    while alive do
        if not paused then
            local ok, err = pcall(scan)

            if not ok and alive then
                setText(stat, "Falha ao atualizar. Tentando novamente...")
                local now = os.clock()

                if now - lastScanWarning >= 10 then
                    lastScanWarning = now
                    warn("[Dice Radar] " .. tostring(err))
                end
            end
        end

        task.wait(SCAN_INTERVAL)
    end
end)
