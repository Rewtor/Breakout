-- =========================================================
-- DICE RADAR V19 | RADAR OTIMIZADO + FARM
-- Painel mobile + ranking + webhook + server hop
-- Ida, coleta e retorno; destino da ida fixado na coordenada do ovo.
-- =========================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Http = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Teleport = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

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
local CONFIG_FILE = "DiceRadar_Config.json"
local DEFAULT_POSITION = Vector3.new(519.82, 71.85, -364.44)

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
    FARM = false,
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
cfg.FARM = cfg.FARM == true
cfg.AH = cfg.AH == true

-- Encerra a versao anterior que usa o mesmo nome.
local function removePrevious(parent)
    for _, name in ipairs({
        "DiceRadarGUI",
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
        Font = Enum.Font.FredokaOne,
        TextSize = 13,
        TextStrokeColor3 = Color3.fromRGB(13, 20, 34),
        TextStrokeTransparency = 0.55,
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
        BackgroundColor3 = Color3.new(1, 1, 1),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.FredokaOne,
        TextStrokeColor3 = Color3.fromRGB(12, 28, 61),
        TextStrokeTransparency = 0.25,
        TextSize = 13,
        BorderSizePixel = 0,
    })

    create("UICorner", object, {
        CornerRadius = UDim.new(0, 10),
    })

    create("UIGradient", object, {
        Color = ColorSequence.new(Color3.fromRGB(81, 177, 255), Color3.fromRGB(31, 98, 194)),
        Rotation = 90,
    })
    create("UIStroke", object, {
        Color = Color3.fromRGB(12, 31, 65), Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    object.AutoButtonColor = false
    local scale = create("UIScale", object, {Scale = 1})
    local motion
    local hovering = false
    local function animate(value)
        if motion then motion:Cancel() end
        motion = TweenService:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value})
        motion:Play()
    end
    connect(object.MouseEnter, function() hovering = true; animate(1.025) end)
    connect(object.MouseLeave, function() hovering = false; animate(1) end)
    connect(object.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then animate(0.96) end
    end)
    connect(object.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then animate(hovering and 1.025 or 1) end
    end)
    connect(object.Destroying, function() if motion then motion:Cancel() end end)
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
local collectorBusy = false
local stopCollection

local isHopping = false
local hopGeneration = 0
local lastValidEggTime = os.clock()

-- =========================================================
-- INTERFACE
-- =========================================================

local uiMotion = {generation = 0, tabGeneration = 0, animating = false, settings = false}
local gui = create("ScreenGui", host, {
    Name = "DiceRadarGUI",
    ResetOnSpawn = false,
    DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

connect(gui.Destroying, function()
    if stopCollection then stopCollection(true) end
    alive = false
    uiMotion.generation = uiMotion.generation + 1
    if uiMotion.panel then uiMotion.panel:Cancel() end
    if uiMotion.shade then uiMotion.shade:Cancel() end
    if uiMotion.tab then uiMotion.tab:Cancel() end
    hopGeneration = hopGeneration + 1

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end)

local shade = create("TextButton", gui, {
    Name = "PanelBackdrop", Size = UDim2.fromScale(1, 1), Text = "",
    BackgroundColor3 = Color3.fromRGB(12, 15, 28), BackgroundTransparency = 1,
    AutoButtonColor = false, BorderSizePixel = 0, Visible = false,
})
local main = create("Frame", gui, {
    Name = "FinderPanel", AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(430, 500),
    Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Color3.fromRGB(27, 32, 49),
    BorderSizePixel = 0,
    Active = true,
})

create("UICorner", main, {CornerRadius = UDim.new(0, 16)})
create("UIGradient", main, {
    Color = ColorSequence.new(Color3.fromRGB(222, 232, 255), Color3.fromRGB(145, 158, 192)),
    Rotation = 90,
})
create("UIStroke", main, {
    Color = Color3.fromRGB(61, 29, 5),
    Thickness = 3,
})

local header = create("Frame", main, {
    Size = UDim2.new(1, -106, 0, 50),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Active = true,
})
create("UICorner", header, {CornerRadius = UDim.new(0, 13)})
create("UIGradient", header, {
    Color = ColorSequence.new(Color3.fromRGB(255, 238, 1), Color3.fromRGB(255, 107, 2)),
    Rotation = 90,
})

local title = text(header, {
    Text = "EGG FINDER",
    Font = Enum.Font.FredokaOne,
    TextStrokeColor3 = Color3.fromRGB(83, 37, 0),
    TextStrokeTransparency = 0,
    TextSize = 16,
    Position = UDim2.fromOffset(14, 14),
    Size = UDim2.new(1, -116, 1, -14),
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
closeButton:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(255, 104, 88), Color3.fromRGB(210, 39, 43))

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
hopButton:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(137, 235, 78), Color3.fromRGB(48, 146, 48))
cancelButton:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(255, 113, 94), Color3.fromRGB(183, 45, 54))

local footer = text(body, {
    Text = "Encontre ovos, ajuste seus filtros e acompanhe o farm.\nRenda e tamanho estimados pelos dados disponíveis.",
    TextSize = 11,
    TextColor3 = Color3.fromRGB(170, 181, 199),
})

local radarTab = button(body, "OVOS", UDim2.new(), UDim2.new())
local viewport = create("Frame", body, {
    Name = "ContentViewport", BackgroundTransparency = 1, ClipsDescendants = true,
})
list.Parent, settings.Parent = viewport, viewport
local expandedSize = main.Size
local headerHeight = 50
local refreshFinder

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

-- Transicoes iguais ao ritmo do Finder nativo: Back/Out ao abrir, Quad/In ao sair.
local function layout()
    if not alive then return end
    local view = gui.AbsoluteSize
    if view.X <= 0 or view.Y <= 0 then return end
    local wasMobile = mobile
    mobile = UIS.TouchEnabled or view.X < 700
    if wasMobile ~= mobile then viewVersion = viewVersion + 1 end
    local width = math.max(1, math.min(mobile and 460 or 640, view.X - 28))
    local height = math.max(1, math.min(730, view.Y - 28))
    local tight = view.Y < 440
    local tiny = view.Y < 360
    headerHeight = tight and 50 or 62
    expandedSize = UDim2.fromOffset(width, height)
    main.Size = expandedSize
    uiMotion.home = UDim2.fromOffset(view.X / 2, view.Y / 2)
    uiMotion.hidden = UDim2.fromOffset(view.X + width / 2 + 28, view.Y / 2)
    if not uiMotion.animating then
        main.Visible = not minimized
        main.Position = minimized and uiMotion.hidden or uiMotion.home
    end
    header.Size = UDim2.new(1, 0, 0, headerHeight)
    title.Text, title.TextSize = width < 300 and "FINDER" or "EGG FINDER", mobile and 24 or 28
    title.Position = UDim2.fromOffset(18, tight and 9 or 15)
    minimizeButton.Size, closeButton.Size = UDim2.fromOffset(38, 38), UDim2.fromOffset(38, 38)
    minimizeButton.Position = UDim2.new(1, -92, 0, (headerHeight - 38) / 2)
    closeButton.Position = UDim2.new(1, -48, 0, (headerHeight - 38) / 2)
    body.Position, body.Size = UDim2.fromOffset(0, headerHeight), UDim2.new(1, 0, 1, -headerHeight)
    body.Visible = true
    radarTab.Position, radarTab.Size = UDim2.fromOffset(14, 10), UDim2.new(0.4, -18, 0, 38)
    settingsButton.Position, settingsButton.Size = UDim2.new(0.4, 4, 0, 10), UDim2.new(0.6, -18, 0, 38)
    settingsButton.Text = "AJUSTES & FARM"
    local active = ColorSequence.new(Color3.fromRGB(255, 222, 65), Color3.fromRGB(239, 144, 24))
    local idle = ColorSequence.new(Color3.fromRGB(93, 118, 167), Color3.fromRGB(48, 66, 103))
    radarTab:FindFirstChildOfClass("UIGradient").Color = uiMotion.settings and idle or active
    settingsButton:FindFirstChildOfClass("UIGradient").Color = uiMotion.settings and active or idle
    mobileOptions.Visible = false
    for _, object in ipairs({sortButton, detailButton, pauseButton}) do
        object.Parent = body
        object.Visible = not uiMotion.settings and not tiny
    end
    sortButton.Position, sortButton.Size = UDim2.fromOffset(14, 57), UDim2.new(0.42, -18, 0, 34)
    detailButton.Position, detailButton.Size = UDim2.new(0.42, 0, 0, 57), UDim2.new(0.34, -8, 0, 34)
    pauseButton.Position, pauseButton.Size = UDim2.new(0.76, 0, 0, 57), UDim2.new(0.24, -14, 0, 34)
    stat.Position, stat.Size = UDim2.fromOffset(16, 99), UDim2.new(1, -32, 0, 38)
    stat.Visible = not tight and not uiMotion.settings
    local top = (uiMotion.settings or tiny) and 58 or (tight and 101 or 143)
    viewport.Position, viewport.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -top - (tiny and 56 or 88))
    list.Position, list.Size = UDim2.new(), UDim2.fromScale(1, 1)
    settings.Position, settings.Size = UDim2.new(), UDim2.fromScale(1, 1)
    hopStatus.Position, hopStatus.Size = UDim2.new(0, 16, 1, -83), UDim2.new(1, -32, 0, 20)
    hopStatus.Visible = not tiny
    hopButton.Position, hopButton.Size = UDim2.new(0, 14, 1, tiny and -46 or -59), UDim2.new(0.7, -18, 0, tiny and 34 or 40)
    cancelButton.Position, cancelButton.Size = UDim2.new(0.7, 0, 1, tiny and -46 or -59), UDim2.new(0.3, -14, 0, tiny and 34 or 40)
    cancelButton.Visible = true
    footer.Visible = false
    refreshHopButton()
    if refreshFinder then refreshFinder() end
    if render then render() end
end

local function setPanelOpen(open)
    if not alive then return end
    uiMotion.generation = uiMotion.generation + 1
    local generation = uiMotion.generation
    local wasVisible = main.Visible
    if uiMotion.panel then uiMotion.panel:Cancel() end
    if uiMotion.shade then uiMotion.shade:Cancel() end
    uiMotion.animating = true
    minimized = not open
    layout()
    main.Visible, shade.Visible = true, true
    if open and not wasVisible then main.Position = uiMotion.hidden end
    local info = open and TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        or TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local tween = TweenService:Create(main, info, {Position = open and uiMotion.home or uiMotion.hidden})
    uiMotion.panel = tween
    uiMotion.shade = TweenService:Create(shade, TweenInfo.new(0.2), {BackgroundTransparency = open and 0.6 or 1})
    if uiMotion.completed then uiMotion.completed:Disconnect() end
    uiMotion.completed = tween.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed or generation ~= uiMotion.generation or not alive then return end
        uiMotion.animating = false
        main.Visible, shade.Visible = open, open
        uiMotion.completed:Disconnect()
        uiMotion.completed = nil
    end)
    uiMotion.shade:Play()
    tween:Play()
end
connect(gui.Destroying, function() if uiMotion.completed then uiMotion.completed:Disconnect() end end)
connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
    uiMotion.generation = uiMotion.generation + 1
    if uiMotion.panel then uiMotion.panel:Cancel() end
    if uiMotion.shade then uiMotion.shade:Cancel() end
    if uiMotion.tab then uiMotion.tab:Cancel() end
    uiMotion.animating = false
    shade.Visible, shade.BackgroundTransparency = not minimized, minimized and 1 or 0.6
    layout()
end)
local function selectTab(showSettings)
    if uiMotion.tab then uiMotion.tab:Cancel() end
    uiMotion.settings = showSettings
    settings.Visible, list.Visible = showSettings, not showSettings
    layout()
    local incoming = showSettings and settings or list
    incoming.Position = UDim2.fromOffset(showSettings and 28 or -28, 0)
    uiMotion.tab = TweenService:Create(incoming, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new()})
    uiMotion.tab:Play()
end
connect(radarTab.Activated, function() selectTab(false) end)
connect(settingsButton.Activated, function() selectTab(true) end)
connect(minimizeButton.Activated, function() setPanelOpen(false) end)
connect(closeButton.Activated, function() setPanelOpen(false) end)
connect(shade.Activated, function() setPanelOpen(false) end)
connect(UIS.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Escape and not minimized then setPanelOpen(false) end
end)

-- O launcher herda a aparencia do HUD, mas vive na nossa GUI: nao altera
-- o layout nem as conexoes dos botoes originais do jogo.
do
    local overlay = create("Frame", gui, {
        Name = "FinderLauncherLayer", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Active = false,
    })
    local fallback = button(overlay, "FINDER", UDim2.new(0, 12, 0.5, -96), UDim2.fromOffset(100, 64))
    local nativeButton, sourceButton, indexButton
    local watchers = {}
    local finderColors = ColorSequence.new(Color3.fromRGB(255, 107, 2), Color3.fromRGB(255, 238, 1))
    fallback:FindFirstChildOfClass("UIGradient").Color = finderColors
    fallback:FindFirstChildOfClass("UIGradient").Rotation = -90
    local function openFinder()
        setPanelOpen(minimized)
    end
    connect(fallback.Activated, openFinder)
    local function disconnectNative()
        for _, connection in ipairs(watchers) do connection:Disconnect() end
        table.clear(watchers)
        if nativeButton then nativeButton:Destroy() end
        nativeButton, sourceButton, indexButton = nil, nil, nil
    end
    local function visible(object)
        while object and object ~= host do
            if object:IsA("GuiObject") and not object.Visible then return false end
            if object:IsA("ScreenGui") and not object.Enabled then return false end
            object = object.Parent
        end
        return object == host
    end
    refreshFinder = function()
        local nativeReady = nativeButton and sourceButton and sourceButton:IsDescendantOf(host)
            and indexButton and indexButton:IsDescendantOf(host)
        fallback.Visible = not nativeReady
        if not nativeReady then return end
        local size = sourceButton.AbsoluteSize
        nativeButton.Visible = size.X > 0 and size.Y > 0 and visible(indexButton) and visible(sourceButton)
        if not nativeButton.Visible then return end
        local center = sourceButton.AbsolutePosition + size / 2
        local indexCenter = indexButton.AbsolutePosition + indexButton.AbsoluteSize / 2
        -- Mesma posicao do teste4: acima do Shop, usando o intervalo Shop/Index.
        local spacing = Vector2.new(0, indexCenter.Y - center.Y)
        if math.abs(spacing.Y) < 1 then spacing = Vector2.new(0, size.Y + 8) end
        local target = center - spacing - overlay.AbsolutePosition
        nativeButton.Position = UDim2.fromOffset(target.X, target.Y)
        nativeButton.Size = UDim2.fromOffset(size.X, size.Y)
    end
    local function attach()
        local hud = host:FindFirstChild("HUD")
        local gameHud = hud and hud:FindFirstChild("GameHUD")
        local column = gameHud and gameHud:FindFirstChild("LeftControls")
        local shop = column and column:FindFirstChild("ShopBTN")
        local index = column and column:FindFirstChild("IndexBTN")
        if shop == sourceButton and index == indexButton and nativeButton then
            refreshFinder(); return
        end
        disconnectNative()
        if not shop or not shop:IsA("GuiButton") or not index or not index:IsA("GuiObject") then
            refreshFinder(); return
        end
        local ok, clone = pcall(function() return shop:Clone() end)
        if not ok or not clone then refreshFinder(); return end
        for _, object in ipairs(clone:GetDescendants()) do
            if object:IsA("LuaSourceContainer") then object:Destroy() end
        end
        for key in pairs(clone:GetAttributes()) do clone:SetAttribute(key, nil) end
        for _, name in ipairs({"Notification", "ReadyNotification", "NightImage", "NightText", "ConsoleButton", "GamepadGlyph", "Badge"}) do
            local object = clone:FindFirstChild(name)
            if object then object:Destroy() end
        end
        for _, object in ipairs(clone:GetDescendants()) do
            if object:IsA("GuiObject") then object.Active = false end
            if object:IsA("UIScale") then object.Scale = 1 end
        end
        local label = clone:FindFirstChild("txt", true) or clone:FindFirstChild("Label", true) or clone:FindFirstChild("TextLabel", true)
        if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
            label.Text = "Finder"
        elseif clone:IsA("TextButton") then
            clone.Text = "Finder"
        else
            label = text(clone, {Text = "Finder", TextScaled = true,
                Size = UDim2.fromScale(1, 0.28), Position = UDim2.fromScale(0, 0.7),
                TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0})
        end
        local gradient = clone:FindFirstChildOfClass("UIGradient")
            or create("UIGradient", clone, {})
        gradient.Color, gradient.Rotation = finderColors, -90
        local stroke = clone:FindFirstChild("UIStroke")
        if stroke and stroke:IsA("UIStroke") then stroke.Color = Color3.fromRGB(60, 24, 0) end
        local light = clone:FindFirstChild("UIStrokeClr")
        if light and light:IsA("UIStroke") then light.Color = Color3.fromRGB(255, 222, 55) end
        local right = gameHud:FindFirstChild("RightButtons")
        local eggs = right and right:FindFirstChild("EggsButton")
        local eggIcon = eggs and eggs:FindFirstChild("ImageLabel")
        local hasEggIcon = false
        for _, name in ipairs({"ImageLabel", "Icon"}) do
            local icon = clone:FindFirstChild(name)
            if icon and icon:IsA("ImageLabel") and eggIcon and eggIcon:IsA("ImageLabel") then
                icon.Image, icon.Visible = eggIcon.Image, true
                hasEggIcon = true
            elseif icon and icon:IsA("GuiObject") then
                icon.Visible = false
            end
        end
        -- Lupa desenhada com UI nativa; dispensa assets externos.
        local lens = create("Frame", clone, {BackgroundTransparency = 1,
            Visible = not hasEggIcon,
            ZIndex = clone.ZIndex + 5,
            Position = UDim2.fromScale(0.28, 0.12), Size = UDim2.fromScale(0.36, 0.36)})
        create("UIAspectRatioConstraint", lens, {AspectRatio = 1})
        create("UICorner", lens, {CornerRadius = UDim.new(1, 0)})
        create("UIStroke", lens, {Color = Color3.new(1, 1, 1), Thickness = 3})
        local handle = create("Frame", clone, {BackgroundColor3 = Color3.new(1, 1, 1),
            Visible = not hasEggIcon,
            ZIndex = clone.ZIndex + 5,
            BorderSizePixel = 0, Rotation = 45, Position = UDim2.fromScale(0.59, 0.48),
            Size = UDim2.fromScale(0.23, 0.065)})
        create("UICorner", handle, {CornerRadius = UDim.new(1, 0)})
        clone.Name, clone.AnchorPoint, clone.Visible = "DiceFinderButton", Vector2.new(0.5, 0.5), false
        clone.Parent = overlay
        nativeButton, sourceButton, indexButton = clone, shop, index
        watchers[#watchers + 1] = clone.Activated:Connect(openFinder)
        local function watch(object, property)
            watchers[#watchers + 1] = object:GetPropertyChangedSignal(property):Connect(refreshFinder)
        end
        for _, object in ipairs({shop, index, overlay}) do
            watch(object, "AbsolutePosition"); watch(object, "AbsoluteSize")
        end
        local ancestor = index
        while ancestor and ancestor ~= host do
            if ancestor:IsA("GuiObject") then watch(ancestor, "Visible") end
            if ancestor:IsA("ScreenGui") then watch(ancestor, "Enabled") end
            ancestor = ancestor.Parent
        end
        refreshFinder()
    end
    connect(gui.Destroying, disconnectNative)
    task.spawn(function()
        while alive do
            local ok = pcall(attach)
            if not ok then disconnectNative(); fallback.Visible = true end
            task.wait(3)
        end
    end)
end

local function addBox(label, value, callback)
    local frame = create("Frame", settings, {
        Size = UDim2.new(1, -8, 0, 74),
        BackgroundColor3 = Color3.fromRGB(40, 49, 70),
        BorderSizePixel = 0,
    })

    create("UICorner", frame, {CornerRadius = UDim.new(0, 10)})
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
        BackgroundColor3 = Color3.fromRGB(27, 35, 53),
        BorderSizePixel = 0,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.FredokaOne,
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
        btn.BackgroundColor3 = Color3.new(1, 1, 1)
        btn:FindFirstChildOfClass("UIGradient").Color = value
            and ColorSequence.new(Color3.fromRGB(140, 232, 82), Color3.fromRGB(55, 143, 39))
            or ColorSequence.new(Color3.fromRGB(119, 99, 150), Color3.fromRGB(66, 48, 93))
    end

    connect(btn.Activated, function()
        value = not value
        paint()
        callback(value)
    end)

    paint()
    return function(newValue)
        value=newValue==true
        paint()
    end
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

local function addSection(label)
    return text(settings, {
        Text = label, Size = UDim2.new(1, -8, 0, 30), TextSize = 19,
        TextColor3 = Color3.fromRGB(255, 220, 97),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
end

local unloadButton = addButton("Encerrar script", function() gui:Destroy() end)
unloadButton.Parent.LayoutOrder = 1000

local function filtersChanged()
    viewVersion = viewVersion + 1
    lastValidEggTime = os.clock()
    if render then render() end
end

addSection("NOTIFICAÇÕES")
addBox("Webhook URL", cfg.W, function(v) cfg.W = v end)
addBox("Ping Discord ID", cfg.P, function(v) cfg.P = v end)

addSection("FILTROS & SERVIDORES")
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
            av = aa.S
            bv = bb.S
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
                BackgroundColor3 = Color3.fromRGB(38, 48, 69),
                BorderSizePixel = 0,
            })

            create("UICorner", frame, {CornerRadius = UDim.new(0, 8)})
            create("UIStroke", frame, {
                Color = Color3.fromRGB(93, 121, 162), Thickness = 1.5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            })

            row = {
                frame = frame,
                icon = create("ImageLabel", frame, {
                    Position = UDim2.fromOffset(10, 9),
                    Size = UDim2.fromOffset(48, 48),
                    BackgroundTransparency = 1,
                    ScaleType = Enum.ScaleType.Fit,
                }),
                title = text(frame, {
                    Font = Enum.Font.FredokaOne,
                    TextSize = 15,
                    TextWrapped = false,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                }),
                value = text(frame, {
                    Font = Enum.Font.FredokaOne,
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

        if row.rank ~= index then
            row.frame.LayoutOrder = index
            row.title.Text = string.format("#%02d  %s", index, data.C)
            row.rank = index
        end

        if row.data ~= data
            or row.view ~= viewVersion
            or row.compact ~= compact
            or row.mobile ~= mobile then

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

            row.meta.Text = exact(data.S).."×  •  Área "..tostring(data.A)
            if not mobile then
                row.meta.Text=row.meta.Text.."\n"..(data.Availability or "Disponibilidade não informada")
            end

            row.details.Visible = not compact

            -- Não formata detalhes escondidos.
            if not compact then
                row.details.Text = string.format(
                    "Tamanho: %s×\nBase: $%s/s • multiplicador: %s×\nRenda estimada: $%s/s\nOrigem: %s\nUID: %s\n%s\n%s\n%s\n ",
                    exact(data.S), exact(data.Base), exact(data.ScaleMult),
                    data.Ready and exact(data.R) or "pendente",
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
        if stopCollection then stopCollection() end
        if isHopping and cancelHop then cancelHop() end
        stat.Text = "PAUSADO • última leitura mantida"
        hopStatus.Text = "Auto hop suspenso enquanto o radar está pausado."
    end
end)

-- =========================================================
-- MODULOS DO JOGO
-- =========================================================

local modules = {}
local moduleRevision = 0
local nextModuleTry = 0

local modulePaths = {
    EggState = {"Client", "EggState"},
    AssetItems = {"Shared", "Util", "AssetItems"},
    AssetEarnings = {"Shared", "Util", "AssetEarnings"},
    Mutations = {"Shared", "Modules", "Mutations"},
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
    "Mutations","Mutation","BaseMutation","Rarity",
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

-- Campos realmente usados pelo calculo; tabelas continuam observadas em profundidade.
local attributeFields = {
    "Mutations","Mutation","BaseMutation","PreparedSourceName","Zone",
    "Category","AssetCategory","ItemName","DisplayName","Scale","AssetScale",
    "Rarity","RarityTier","Tier","AreaId","Area","Income","EarningRate",
}

local function readInputs(model, rec, state)
    local attrs = model and model:GetAttributes() or {}
    local visual = model and model:IsA("Model") and finite(model:GetScale()) or nil
    local previous = state.inputs
    if not previous then
        previous = {values = {}, token = 0}
        state.inputs = previous
    end
    local name = model and model.Name or ""
    local changed = previous.visual ~= visual or previous.name ~= name
        or previous.revision ~= moduleRevision
    previous.visual, previous.name, previous.revision = visual, name, moduleRevision
    local index, valid = 0, true
    local function compare(value)
        index = index + 1
        if type(value) == "table" then
            value = signature(value)
            if value == nil then valid = false end
        end
        if previous.values[index] ~= value then
            changed = true
            previous.values[index] = value
        end
    end
    for _, field in ipairs(attributeFields) do compare(attrs[field]) end
    for _, field in ipairs(recordFields) do compare(rec[field]) end
    if changed then previous.token = previous.token + 1 end
    return attrs, visual, valid and previous.token or nil
end

-- =========================================================
-- CALCULO UNICO POR OVO
-- =========================================================

local function buildCard(uid, model, rec, attrs, visual)
    local mutation = attrs.Mutations or attrs.Mutation or rec.Mutations or rec.Mutation
    if mutation == nil or mutation == false or mutation == ""
        or (type(mutation) == "table" and next(mutation) == nil) then
        local base = attrs.BaseMutation or rec.BaseMutation
        if base and base ~= "" and base ~= "None" and base ~= "Normal" then
            mutation = {base}
        end
    end
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

    -- Calcula renda e tamanho a partir dos registros e assets atuais.
    local rawCategory = attrs.Category or attrs.AssetCategory or attrs.ItemName
        or rec.AssetCategory or rec.Category or rec.ItemName or "Egg"

    local rawDisplay = attrs.PreparedSourceName or attrs.DisplayName
        or rec.PreparedSourceName or rec.DisplayName or rawCategory

    if rawDisplay == "Egg" and model
        and model.Name ~= "Model" and model.Name ~= "Part"
        and #model.Name < 30 and not string.find(model.Name, "_", 1, true) then
        rawDisplay = model.Name
    end

    local category = rawCategory
    local display = rawDisplay
    local modelName = model and model.Name

    local asset = getAsset(display) or getAsset(category) or getAsset(modelName)
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
    for _,name in ipairs({display,category,modelName}) do
        if not base or base==0 then
            local candidate=getAsset(name)
            if candidate then
                base=finite(candidate.EarningRate
                    or (type(candidate.Egg)=="table" and candidate.Egg.EarningRate))
            end
        end
    end
    if not base or base==0 then
        base=finite(attrs.Income or attrs.EarningRate or rec.Income or rec.EarningRate or rec.MoneyPerSecond)
    end
    if (not base or base==0) and type(rec.ItemData)=="table" then
        base=finite(rec.ItemData.MoneyPerSecond or rec.ItemData.Income)
    end

    card.C = tostring(display)
    card.Source = tostring(rawDisplay)
    card.S, card.CS = scale, scale
    card.P = string.format("%.1fx", scale)
    card.Base = base
    card.Icon = iconOf(asset)
    card.Rar = inferRarity(display, attrs, rec, asset, modelName)

    local income, mult = incomeFor(base, scale)
    local adjusted = income and finite(income * mutationMult)

    if adjusted then
        card.R = math.floor(adjusted + 0.5)
        card.ScaleMult = mult
        card.Ready = true
    end

    local earnings = modules.AssetEarnings
    if earnings
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
        prompt = model:FindFirstChild("CarryAreaEgg", true)
            or model:FindFirstChild("StealPrompt", true)
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
    if collectorBusy then
        hopStatus.Text = "Aguarde a coleta ou cancele-a nos ajustes."
        return
    end

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
        local remainingToSkip = target == 1 and 20 or 0

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
                            local uid = tostring(rec.Uid or rec.Id or key)
                            records[uid] = rec
                            all[uid] = true
                        end
                    end
                end
            end
        end
    end

    -- O estado atualizado tem prioridade sobre valores em cache ou modelos antigos.
    for uid, rec in pairs(records) do
        if rec.State == "Claimed" then
            all[uid] = nil
            models[uid] = nil
            -- Invalida imediatamente a renda usada por notificacoes ainda nao enviadas.
            if cached[uid] then
                cached[uid] = nil
                dataVersion = dataVersion + 1
            end
            cacheState[uid] = nil
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
    local state = cacheState[uid]
    if not state or state.model ~= model then
        state = {model = model}
        cacheState[uid] = state
    end
    local attrs, visual, inputSignature = readInputs(model, rec, state)

    local recalculate = not state
        or state.model ~= model
        or not inputSignature
        or state.signature ~= inputSignature
        or now >= state.expires
        or not cached[uid]
        or not cached[uid].Ready

    local card = cached[uid]

    if recalculate then
        local result = buildCard(uid, model, rec, attrs, visual)

        state.signature = inputSignature
        -- Revisões distribuídas para não expirar todos os ovos juntos.
        state.expires = now + 25 + math.random() * 10

        result.Availability = card and card.Availability
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

-- =========================================================
-- COLETA: VIAGEM MANUAL OU FARM CONTINUO DOS OVOS APROVADOS
-- O farm reavalia o lote apos cada entrega e espera novos alvos quando esgota.
-- Posse conferida por ReadCarryState.Uid; remocao/Claimed nao prova entrega.
-- =========================================================
local collector = {
    enabled = false, generation = 0, seen = {}, attempted = {}, pending = false,
    changedAt = 0, startedAt = 0, humanoid = nil, prompt = nil,
    cleanup = nil, finished = false,
}
-- Associacao por ancora observada ANTES da aproximacao.
local promptAnchors={pool={},bindings={},pending={},records={},models={},elapsed=0}
function promptAnchors.position(prompt)
    local parent=prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then return parent:GetPivot().Position end
end
function promptAnchors.track(object)
    if object:IsA("ProximityPrompt") and object.Name=="CarryAreaEgg" then promptAnchors.pool[object]=true end
end
for _,object in ipairs(Workspace:GetDescendants()) do promptAnchors.track(object) end
connect(Workspace.DescendantAdded,promptAnchors.track)
connect(Workspace.DescendantRemoving,function(object)
    promptAnchors.pool[object]=nil
    promptAnchors.bindings[object]=nil
    promptAnchors.pending[object]=nil
end)
function promptAnchors.valid(binding,records,models)
    local record=records[binding.uid]
    return record and record.State~="Claimed" and typeof(record.BottomCFrame)=="CFrame"
        and (record.BottomCFrame.Position-binding.bottom).Magnitude<=0.05
        -- Modelo visual pode nao estar carregado; UID + ancora continuam verificaveis.
        and (binding.model==nil or (models[binding.uid]==binding.model and binding.model.Parent~=nil))
end
function promptAnchors.sample()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local records,models=promptAnchors.records,promptAnchors.models
    local now=os.clock()
    for prompt in pairs(promptAnchors.pool) do
        local binding=promptAnchors.bindings[prompt]
        if binding and not promptAnchors.valid(binding,records,models) then
            promptAnchors.bindings[prompt]=nil;binding=nil
        end
        local position=promptAnchors.position(prompt)
        local matchedUid=nil
        local matchCount=0
        if position then
            for eggUid,record in pairs(records) do
                if record.State~="Claimed" and typeof(record.BottomCFrame)=="CFrame"
                    and (position-record.BottomCFrame.Position).Magnitude<=0.05 then
                    matchCount=matchCount+1;matchedUid=eggUid
                end
            end
        end
        if matchCount==1 and (root.Position-position).Magnitude>=12 then
            local record=records[matchedUid]
            local bottom=record.BottomCFrame.Position
            if binding and binding.uid~=matchedUid then promptAnchors.bindings[prompt]=nil end
            local pending=promptAnchors.pending[prompt]
            if not pending or pending.uid~=matchedUid or pending.model~=models[matchedUid]
                or (pending.bottom-bottom).Magnitude>0.05 then
                promptAnchors.pending[prompt]={uid=matchedUid,bottom=bottom,model=models[matchedUid],since=now}
            elseif now-pending.since>=0.2 then
                promptAnchors.bindings[prompt]={uid=matchedUid,bottom=bottom,model=models[matchedUid]}
            end
        else
            promptAnchors.pending[prompt]=nil
        end
    end
end
connect(game:GetService("RunService").Heartbeat,function(dt)
    if not alive or not collector.enabled or paused then return end
    promptAnchors.elapsed=promptAnchors.elapsed+dt
    if promptAnchors.elapsed<0.25 then return end
    promptAnchors.elapsed=0
    promptAnchors.sample()
end)
addSection("FARM & COLETA")
local collectionStatus = text(settings, {
    Text = "Coleta desligada.", Size = UDim2.new(1, -8, 0, 64),
    LayoutOrder = 100,
})
local function collectionMessage(message)
    if alive then collectionStatus.Text = message end
end
local updateFarmToggle=nil
local function setFarmEnabled(value)
    value=value==true
    local changed=cfg.FARM~=value
    cfg.FARM=value
    if updateFarmToggle then updateFarmToggle(value) end
    if changed and writefile then
        local saved=pcall(function() writefile(CONFIG_FILE,Http:JSONEncode(cfg)) end)
        if not saved then collectionMessage("Estado do farm alterado; nao foi possivel salvar as configuracoes.") end
    end
end
stopCollection = function(preservePreference)
    if collector.returnMotionCleanup then collector.returnMotionCleanup();collector.returnMotionCleanup=nil end
    if collector.restoreSpeed then collector.restoreSpeed() end
    if collector.cleanup then collector.cleanup() end
    collector.enabled = false
    if preservePreference~=true then setFarmEnabled(false) end
    collector.pending = false
    collector.generation = collector.generation + 1
    if collector.prompt then
        pcall(function() collector.prompt:InputHoldEnd() end)
        collector.prompt = nil
    end
    if collector.humanoid and collector.humanoid.Parent then
        local root = collector.humanoid.RootPart
        if root then collector.humanoid:MoveTo(root.Position) end
    end
    -- Busy so e liberado quando o worker antigo terminar.
    collectionMessage("Coleta desligada. Viagem cancelada.")
end
local function startCollection(automatic)
    if collectorBusy then
        collectionMessage("Caminhada em andamento; cancele antes de iniciar outra.")
        return
    end
    if isHopping then
        collectionMessage("Cancele a busca de servidor antes de coletar.")
        return
    end
    collector.automatic = automatic
    setFarmEnabled(automatic)
    collector.mode = "walk"
    collector.enabled = true
    collector.finished = false
    table.clear(collector.seen)
    table.clear(collector.attempted)
    collector.pending = true
    collector.startedAt = os.clock()
    collector.changedAt = os.clock()
    collectionMessage(automatic and "Farm ligado: buscando ovos com rendimento e tamanho aprovados no filtro do webhook..."
        or "Ida e volta: aguardando os ovos carregarem...")
    return true
end
addButton("Coletar ovo mais caro e voltar", function() startCollection(false) end)
updateFarmToggle=addToggle("Farm continuo (filtro do webhook)",cfg.FARM,function(value)
    if value then
        if not startCollection(true) then updateFarmToggle(cfg.FARM) end
    else
        stopCollection()
    end
end)
addButton("DESLIGAR coleta / cancelar viagem", stopCollection)

-- Posicao do registro, com alternativa pelo modelo visual.
local function collectionDestination(model, rec)
    if rec and typeof(rec.BottomCFrame) == "CFrame" then return rec.BottomCFrame.Position end
    if not model then return nil end
    if model:IsA("Model") then return model:GetPivot().Position end
    if model:IsA("BasePart") then return model.Position end
    local part = model:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

-- Ida e volta andando; sem teleporte.
local function runCollection(uid, model, rec)
    collectorBusy = true
    collector.generation = collector.generation + 1
    local generation = collector.generation
    local tripReturned = false
    local deliveryConfirmed = false
    local deliveryConnection=nil
    local interactionAttempted=false
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    collector.humanoid = humanoid
    local shown = {}
    local promptService = game:GetService("ProximityPromptService")
    local shownConnection = promptService.PromptShown:Connect(function(prompt) shown[prompt] = true end)
    local hiddenConnection = promptService.PromptHidden:Connect(function(prompt) shown[prompt] = nil end)
    local function active()
        return alive and collector.enabled and not paused
            and generation == collector.generation
            and player.Character == character and root and root.Parent
            and humanoid and humanoid.Parent and humanoid.Health > 0
    end
    local function readCarryState()
        local state=modules.EggState
        if not state or type(state.ReadCarryState)~="function" then return nil,"ReadCarryState indisponivel" end
        local success,value=pcall(state.ReadCarryState)
        if not success or type(value)~="table" then return nil,"Falha ao ler estado carregado" end
        return value
    end
    local ok, err = pcall(function()
        if not active() then error("personagem indisponivel", 0) end
        local initialCarry,carryError=readCarryState()
        if not initialCarry then error(carryError,0) end
        if initialCarry.IsCarrying then error("Ja esta carregando um ovo; entregue antes de iniciar",0) end
        if root.Anchored or humanoid.WalkSpeed <= 0 then
            error("personagem imobilizado; saia da esteira antes de coletar", 0)
        end
        if collector.automatic and not isTarget(cached[uid]) then
            error("Alvo fora do filtro do webhook antes da partida",0)
        end
        local origin = DEFAULT_POSITION
        local eggTarget = collectionDestination(model, rec)
        if not eggTarget then error("ovo sem posicao", 0) end
        -- Ponto fixo de preparacao e retorno, compartilhado por todos os usuarios.
        local returnTarget=origin
        local returningToDefault=false
        -- Evidencia positiva do jogo, nunca apenas sumico de Drop/Triggered.
        -- Ignora mensagens que ja estavam visiveis antes desta viagem.
        local visibleMessages={}
        local function deliveryMessages()
            local found={}
            for _,object in ipairs(host:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local text=object.Text:lower():gsub("<[^>]->", "")
                    if text:find("you stole an egg",1,true) then
                        local visible=object.Visible
                        local ancestor=object.Parent
                        while visible and ancestor and ancestor~=host do
                            if ancestor:IsA("GuiObject") and not ancestor.Visible then visible=false end
                            if ancestor:IsA("ScreenGui") and not ancestor.Enabled then visible=false end
                            ancestor=ancestor.Parent
                        end
                        if visible then found[object]=object.Text end
                    end
                end
            end
            return found
        end
        visibleMessages=deliveryMessages()
        local deliveryElapsed=0
        deliveryConnection=game:GetService("RunService").Heartbeat:Connect(function(dt)
            deliveryElapsed=deliveryElapsed+dt
            if deliveryElapsed<0.1 or not active() then return end
            deliveryElapsed=0
            local current=deliveryMessages()
            for object in pairs(current) do
                if not visibleMessages[object] and returningToDefault then
                    deliveryConfirmed=true
                end
            end
            visibleMessages=current
        end)
        -- Um unico destino por perna: sem PathfindingService nem desvios intermediarios.
        local function walkTo(target, returning, targetProvider)
            returningToDefault=returning
            local function flatDistance(a,b)
                return Vector3.new(a.X-b.X,0,a.Z-b.Z).Magnitude
            end
            local arrivalRadius=returning and 3 or 0.03
            local verticalTolerance=math.max(6,humanoid.HipHeight+root.Size.Y/2+3)
            local previousPosition=root.Position
            local arrived=false
            local function updateReturnCrossing()
                if not returning or arrived then return arrived end
                local current=root.Position
                local delta=Vector3.new(current.X-previousPosition.X,0,current.Z-previousPosition.Z)
                local offset=Vector3.new(target.X-previousPosition.X,0,target.Z-previousPosition.Z)
                local lengthSquared=delta:Dot(delta)
                local t=lengthSquared>0 and math.clamp(offset:Dot(delta)/lengthSquared,0,1) or 0
                local closestHeight=previousPosition.Y+(current.Y-previousPosition.Y)*t
                if (offset-delta*t).Magnitude<=arrivalRadius and math.abs(closestHeight-target.Y)<=verticalTolerance then
                    arrived=true
                end
                previousPosition=current
                return arrived
            end
            local normalSpeed=humanoid.WalkSpeed
            local appliedSpeed=nil
            local function restoreSpeed()
                if appliedSpeed and humanoid.Parent and humanoid.WalkSpeed==appliedSpeed then humanoid.WalkSpeed=normalSpeed end
                appliedSpeed=nil
            end
            collector.restoreSpeed=restoreSpeed
            local initialDistance=flatDistance(root.Position,target)
            local deadline=os.clock()+math.clamp(initialDistance/math.max(normalSpeed,1)*3+60,120,1800)
            local runService=game:GetService("RunService")
            local binding="DiceRadarDirect_"..tostring(generation)
            local bound=false
            local stableSince=nil
            local controlError=nil
            local lastMessage=0
            local progressPosition=root.Position
            local progressTime=os.clock()
            local failure="Caminhada interrompida"
            local function cleanupMotion()
                if bound then runService:UnbindFromRenderStep(binding);bound=false end
                if humanoid.Parent then humanoid:Move(Vector3.zero,false) end
            end
            collector.returnMotionCleanup=cleanupMotion
            bound=true
            runService:BindToRenderStep(binding,Enum.RenderPriority.Character.Value+1,function(dt)
                local success,problem=pcall(function()
                    if not active() or controlError or arrived then humanoid:Move(Vector3.zero,false);return end
                    if updateReturnCrossing() then humanoid:Move(Vector3.zero,false);return end
                    local delta=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z)
                    local distance=delta.Magnitude
                    local verticalOK=math.abs(root.Position.Y-target.Y)<=verticalTolerance
                    if not returning then
                        -- So a ida freia e centraliza; a volta preserva a velocidade do jogo.
                        if appliedSpeed and humanoid.WalkSpeed~=appliedSpeed then normalSpeed=humanoid.WalkSpeed;appliedSpeed=nil
                        elseif not appliedSpeed then normalSpeed=humanoid.WalkSpeed end
                        local velocity=root.AssemblyLinearVelocity
                        local actual=Vector3.new(velocity.X,0,velocity.Z).Magnitude
                        local brakeDistance=math.max(30,math.max(normalSpeed,actual)*0.45+20)
                        if distance<=arrivalRadius then
                            humanoid:Move(Vector3.zero,false)
                            if verticalOK and actual<0.3 then
                                stableSince=stableSince or os.clock()
                                arrived=os.clock()-stableSince>=0.15
                            else stableSince=nil end
                            return
                        end
                        stableSince=nil
                        if distance<4 then
                            appliedSpeed=math.min(normalSpeed,6,distance*0.35/math.max(dt,1/240))
                            humanoid.WalkSpeed=appliedSpeed
                        elseif distance<brakeDistance and normalSpeed>12 then
                            appliedSpeed=math.min(normalSpeed,math.max(2,math.sqrt(160*math.max(distance-arrivalRadius,0))))
                            humanoid.WalkSpeed=appliedSpeed
                        else restoreSpeed() end
                    end
                    if distance>0 then humanoid:Move(delta.Unit,false) end
                end)
                if not success then controlError=tostring(problem) end
            end)
            while active() and not arrived and not controlError and os.clock()<deadline do
                if targetProvider then
                    local latest=targetProvider()
                    if not latest then failure="Alvo removido durante a ida";break end
                    if (latest-target).Magnitude>0.1 then
                        target=latest;stableSince=nil;progressPosition=root.Position;progressTime=os.clock()
                    end
                end
                local distance=flatDistance(root.Position,target)
                if distance>4 then
                    if flatDistance(root.Position,progressPosition)>=1 then
                        progressPosition=root.Position;progressTime=os.clock()
                    elseif os.clock()-progressTime>=0.75 then
                        failure="Passagem direta bloqueada: sem progresso por 0.75s"
                        break
                    end
                else progressPosition=root.Position;progressTime=os.clock() end
                if os.clock()-lastMessage>=0.25 then
                    lastMessage=os.clock()
                    collectionMessage(string.format((returning and "Voltando direto ao DEFAULT" or "Indo direto ao destino").." | faltam %.1f studs",distance))
                end
                runService.Heartbeat:Wait()
            end
            cleanupMotion();collector.returnMotionCleanup=nil
            restoreSpeed();collector.restoreSpeed=nil
            if controlError then error(controlError,0) end
            if not arrived and os.clock()>=deadline then failure="Tempo de caminhada direta esgotado" end
            return arrived,failure
        end

        local promptPosition=promptAnchors.position
        local function belongsToSelectedEgg(prompt)
            if not prompt or not prompt.Parent then return false,"removido" end
            if prompt.Name~="CarryAreaEgg" and prompt.Name~="StealPrompt" then
                return false,"tipo diferente"
            end
            if rec and rec.State=="Claimed" then return false,"alvo indisponivel" end
            local inside=model and model.Parent and prompt:IsDescendantOf(model)
            local owner=prompt
            local matched=false
            while owner and owner~=Workspace do
                for _,key in ipairs({"EggUid","UID","Uid"}) do
                    local value=owner:GetAttribute(key)
                    if value~=nil then
                        if tostring(value)~=tostring(uid) then return false,"UID diferente" end
                        matched=true
                    end
                end
                if owner==model then break end
                owner=owner.Parent
            end
            if inside then return true,"modelo do alvo" end
            if matched then return true,"UID do alvo" end
            local binding=promptAnchors.bindings[prompt]
            if binding then
                local currentModels,currentRecords=collectSources()
                if not promptAnchors.valid(binding,currentRecords,currentModels) then
                    promptAnchors.bindings[prompt]=nil
                    return false,"ancora invalidada: ovo removido, substituido ou deslocado"
                end
                if binding.uid~=tostring(uid) then return false,"ancora pertence a outro UID" end
                return true,"ancora BottomCFrame observada antes da aproximacao"
            end
            return false,"sem UID/modelo ou ancora previa valida"
        end
        local function selectPrompt()
            local selected=nil
            local count=0
            local inspected={}
            local function consider(prompt)
                if inspected[prompt] then return end
                inspected[prompt]=true
                if not prompt:IsA("ProximityPrompt") or not prompt.Parent or not prompt.Enabled then return end
                if not belongsToSelectedEgg(prompt) then return end
                local position=promptPosition(prompt)
                if not position or (root.Position-position).Magnitude>prompt.MaxActivationDistance then return end
                if prompt.RequiresLineOfSight then
                    local params=RaycastParams.new()
                    params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={character}
                    params.RespectCanCollide=true
                    local hit=Workspace:Raycast(root.Position,position-root.Position,params)
                    if hit and (hit.Position-position).Magnitude>2
                        and not (model and hit.Instance:IsDescendantOf(model)) then return end
                end
                selected=prompt;count=count+1
            end
            if model and model.Parent then
                for _,object in ipairs(model:GetDescendants()) do consider(object) end
            end
            for prompt in pairs(shown) do consider(prompt) end
            for prompt in pairs(promptAnchors.pool) do consider(prompt) end
            return count==1 and selected or nil,count
        end
        collectionMessage("Preparando: indo ao ponto DEFAULT antes da coleta...")
        local atDefault,defaultWhy=walkTo(origin,false)
        if not active() then return end
        if not atDefault then error("Nao chegou ao DEFAULT: "..tostring(defaultWhy),0) end
        -- A rota de preparacao nao e uma rota de retorno do ovo.
        local lastTargetRefresh=0
        local function refreshTarget(force)
            if not force and os.clock()-lastTargetRefresh<0.25 then return eggTarget end
            lastTargetRefresh=os.clock()
            local currentModels,currentRecords=collectSources()
            promptAnchors.models=currentModels;promptAnchors.records=currentRecords
            model=currentModels[tostring(uid)]
            local current=currentRecords[tostring(uid)]
            if not current or current.State=="Claimed" then eggTarget=nil;return nil end
            rec=current
            eggTarget=collectionDestination(model,rec)
            return eggTarget
        end
        local currentDestination=refreshTarget(true)
        local arrived,why=false,"Alvo indisponivel antes da aproximacao"
        if currentDestination then
            collectionMessage("Indo diretamente ao ovo...")
            arrived,why=walkTo(currentDestination,false,refreshTarget)
        end
        if not active() then return end
        local outcome="Ida interrompida: "..tostring(why)
        if arrived then
            humanoid:MoveTo(root.Position)
            collectionMessage("No centro: preparando coleta...")
            local deadline=os.clock()+5
            local prompt,count
            repeat
                prompt,count=selectPrompt()
                if prompt or not active() then break end
                task.wait(0.1)
            until os.clock()>=deadline
            if not active() then return end
            outcome=count and count>1 and "Interacao ambigua; coleta nao tentada."
                or "Sem prompt unico por UID/modelo ou ancora previa; coleta bloqueada."
            if prompt then
                interactionAttempted=true
                local _,association=belongsToSelectedEgg(prompt)
                local triggered=false
                local originalExclusivity=prompt.Exclusivity
                local connection=prompt.Triggered:Connect(function(who)
                    if who==player then triggered=true end
                end)
                collector.prompt=prompt
                local originalHold=prompt.HoldDuration
                local cleaned=false
                local function cleanupInteraction()
                    if cleaned then return end
                    cleaned=true
                    pcall(function() prompt:InputHoldEnd() end)
                    pcall(function() prompt.HoldDuration=originalHold end)
                    pcall(function()
                        if prompt.Exclusivity==Enum.ProximityPromptExclusivity.AlwaysShow then
                            prompt.Exclusivity=originalExclusivity
                        end
                    end)
                    connection:Disconnect()
                end
                collector.cleanup=cleanupInteraction
                local interactionOK,interactionError=pcall(function()
                    local belongs,reason=belongsToSelectedEgg(prompt)
                    if not belongs then error("Prompt perdeu vinculo com o alvo: "..reason,0) end
                    collectionMessage("Preparando exibicao do prompt selecionado | UID "..tostring(uid))
                    prompt.Exclusivity=Enum.ProximityPromptExclusivity.AlwaysShow
                    local showDeadline=os.clock()+0.75
                    while active() and prompt.Parent and prompt.Enabled and not shown[prompt]
                        and os.clock()<showDeadline do
                        game:GetService("RunService").Heartbeat:Wait()
                    end
                    local promptVisible=shown[prompt]==true
                    if not active() then return end
                    if not promptVisible then error("Prompt selecionado continua oculto; interacao bloqueada",0) end
                    belongs,reason=belongsToSelectedEgg(prompt)
                    if not belongs then error("Prompt perdeu vinculo antes do hold: "..reason,0) end
                    local position=promptPosition(prompt)
                    if not position or not prompt.Enabled or (root.Position-position).Magnitude>prompt.MaxActivationDistance then
                        error("Prompt indisponivel ou fora do alcance antes do hold",0)
                    end
                    if collector.automatic then
                        -- Releitura do mesmo predicado do webhook, imediatamente antes do hold.
                        local currentModels,currentRecords=collectSources()
                        local record=currentRecords[tostring(uid)]
                        if not record or record.State=="Claimed" then error("Alvo indisponivel antes da coleta",0) end
                        local updated,data=pcall(updateEgg,uid,currentModels[tostring(uid)],record,os.clock())
                        local approved=updated and isTarget(data)==true
                        if not approved then error("Alvo nao atende mais ao filtro do webhook; coleta bloqueada",0) end
                    end
                    collectionMessage("Coletando ovo selecionado...")
                    if prompt.Name=="CarryAreaEgg" then prompt.HoldDuration=0 end
                    prompt:InputHoldBegin()
                    local holdUntil=os.clock()+prompt.HoldDuration
                    -- Mesmo com duracao zero, deixa o motor processar um frame.
                    game:GetService("RunService").Heartbeat:Wait()
                    if not triggered and prompt.Parent and not belongsToSelectedEgg(prompt) then error("Vinculo do prompt mudou durante a interacao",0) end
                    while active() and not triggered and prompt.Parent and prompt.Enabled
                        and os.clock()<holdUntil do
                        game:GetService("RunService").Heartbeat:Wait()
                        if not triggered and prompt.Parent and not belongsToSelectedEgg(prompt) then error("Vinculo do prompt mudou durante a interacao",0) end
                    end
                    prompt:InputHoldEnd()
                    local waitUntil=os.clock()+0.25
                    while active() and not triggered and prompt.Parent and prompt.Enabled
                        and os.clock()<waitUntil do
                        game:GetService("RunService").Heartbeat:Wait()
                    end
                end)
                cleanupInteraction()
                collector.cleanup=nil
                collector.prompt=nil
                outcome=interactionOK and (triggered
                    and ("Interacao acionada por "..association.."; posse do ovo nao confirmada.")
                    or "Interacao sem confirmacao; verifique a coleta.")
                    or "Falha na interacao: "..tostring(interactionError)
            end
        end
        if not active() then return end
        if interactionAttempted then
            collectionMessage("Conferindo ovo carregado...")
            local carryDeadline=os.clock()+2
            local carried
            repeat
                carried=readCarryState()
                if carried and carried.IsCarrying then break end
                game:GetService("RunService").Heartbeat:Wait()
            until not active() or os.clock()>=carryDeadline
            if not active() then return end
            if not carried or not carried.IsCarrying then
                error("Coleta sem confirmacao de posse; automatico interrompido",0)
            end
            if tostring(carried.Uid)~=tostring(uid) then
                error("Ovo errado: alvo "..tostring(uid)..", carregado "..tostring(carried.Uid).."; automatico interrompido",0)
            end
            outcome="Ovo correto confirmado."
        end
        collectionMessage(outcome.." Voltando ao ponto de partida...")
        local returned,returnWhy=walkTo(returnTarget,true)
        tripReturned = returned and active()
        if returned and active() and not deliveryConfirmed then
            collectionMessage("Dentro da base: aguardando confirmacao de entrega...")
            local confirmationDeadline=os.clock()+2
            while active() and not deliveryConfirmed and os.clock()<confirmationDeadline do
                game:GetService("RunService").Heartbeat:Wait()
            end
        end
        if active() then
            collectionMessage(deliveryConfirmed and "Entrega confirmada pelo jogo."
                or (returned and "Retorno concluido; entrega nao confirmada."
                or "Retorno interrompido: "..tostring(returnWhy)))
        end
    end)
    if deliveryConnection then deliveryConnection:Disconnect();deliveryConnection=nil end
    if collector.returnMotionCleanup then collector.returnMotionCleanup();collector.returnMotionCleanup=nil end
    if collector.restoreSpeed then collector.restoreSpeed();collector.restoreSpeed=nil end
    shownConnection:Disconnect()
    hiddenConnection:Disconnect()
    if collector.cleanup then collector.cleanup();collector.cleanup=nil end
    if collector.prompt then
        pcall(function() collector.prompt:InputHoldEnd() end)
        collector.prompt=nil
    end
    if alive and generation==collector.generation and not active() then
        collectionMessage("Viagem interrompida: personagem morreu, mudou ou radar foi pausado.")
    end
    if humanoid and humanoid.Parent and root and root.Parent then humanoid:MoveTo(root.Position) end
    if not ok and alive then collectionMessage("Falha na caminhada: "..tostring(err)) end
    collector.humanoid=nil
    -- Entrega sem mensagem nao encerra o farm se ja voltamos e estamos livres.
    -- Nao inicia outra viagem enquanto ainda carrega um ovo ou a leitura falha.
    local readyForNext=false
    local finalCarry=nil
    if collector.automatic and ok and tripReturned and active() then
        finalCarry=readCarryState()
        readyForNext=finalCarry~=nil and finalCarry.IsCarrying==false
    end
    collectorBusy=false
    if collector.automatic and collector.enabled and generation==collector.generation
        and ok and tripReturned and readyForNext then
        collector.finished=false
        -- Reavalia imediatamente os ovos restantes, sem esperar UIDs novos.
        -- attempted preserva os UIDs ja tentados nesta sessao de farm.
        collector.pending=true
        if os.clock()-collector.changedAt>=3 then
            collector.startedAt=os.clock()-12
        end
        collectionMessage(collectionStatus.Text.." Farm ligado: buscando o proximo ovo aprovado no filtro.")
    else
        collector.finished=true
        collector.pending=false
        if collector.automatic and collector.enabled then
            collector.enabled=false
            setFarmEnabled(false)
            local reason=finalCarry and finalCarry.IsCarrying
                and "personagem ainda carrega um ovo."
                or "retorno incompleto ou estado do personagem indisponivel."
            collectionMessage(collectionStatus.Text.." Automatico desligado: "..reason)
        end
    end
    lastValidEggTime=os.clock()
end

local function updateCollection(models, records, all, now)
    if not collector.enabled or collector.finished then return end
    for uid in pairs(all) do
        if not collector.seen[uid] then
            collector.seen[uid] = true
            if not collector.pending then collector.startedAt = now end
            collector.pending = true
            collector.changedAt = now
        end
    end
    if collectorBusy or isHopping or not collector.pending or paused then return end
    if now - collector.changedAt < 3 and now - collector.startedAt < 12 then return end
    local bestUid, bestModel, bestRecord, bestRate
    local pendingData = false
    local counts = {total=0, noModel=0, pending=0, missing=0, ambiguous=0, claimed=0, tried=0, filtered=0}
    for uid in pairs(all) do
        counts.total = counts.total + 1
        local model, data, rec = models[uid], cached[uid], records[uid]
        if collector.attempted[uid] then
            counts.tried = counts.tried + 1
        elseif rec and rec.State == "Claimed" then
            counts.claimed = counts.claimed + 1
        elseif not collectionDestination(model, rec) then
            counts.noModel = counts.noModel + 1
            pendingData = true
        elseif not data or not data.Ready then
            counts.pending = counts.pending + 1
            pendingData = true
        elseif collector.automatic and not isTarget(data) then
            counts.filtered = counts.filtered + 1
        else
            if not bestRate or data.R > bestRate
                or (data.R == bestRate and uid < bestUid) then
                bestUid, bestModel, bestRecord, bestRate = uid, model, rec, data.R
            end
        end
    end
    if bestUid and not (pendingData and now - collector.startedAt < 12) then
        collector.pending = false
        collector.attempted[bestUid] = true
        collectorBusy = true
        task.spawn(runCollection, bestUid, bestModel, bestRecord)
    else
        -- Sem candidato agora: continua verificando dados, novos ovos e filtros.
        collectionMessage(string.format(
            "Aguardando: %d ovos | sem posicao: %d | renda pendente: %d\nFora do filtro: %d | indisponiveis: %d | tentados: %d",
            counts.total, counts.noModel, counts.pending, counts.filtered, counts.claimed, counts.tried))
    end
end

local lastScanWarning = 0

local function scan()
    loadModules()

    local models, records, all = collectSources()
    if collector.enabled then
        promptAnchors.models=models
        promptAnchors.records=records
    end
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
        end
    end

    updateCollection(models, records, all, now)

    if targets > 0 or collectorBusy then
        lastValidEggTime = now
    elseif errors == 0 and cfg.AH and not isHopping and not collector.enabled
        and now - lastValidEggTime >= cfg.AHT then
        task.spawn(doServerHop)
    end

    if not minimized then
        local stateText = cfg.FARM and "Farm ligado" or "Radar ativo"

        if cfg.AH and targets == 0 and not collector.enabled then
            local remaining = math.max(
                0, math.ceil(cfg.AHT - (now - lastValidEggTime))
            )
            stateText = "Sem alvos • hop em " .. remaining .. "s"
        end

        setText(stat, string.format(
            "%s  •  %d ovos  •  %d alvos\nMelhor ovo: $%s/s",
            stateText, total, targets, short(best)
        ))
    end

    if errors > 0 and now - lastScanWarning >= 10 then
        lastScanWarning = now
        warn("[Dice Radar] Falha de leitura em " .. errors .. " ovo(s); nova tentativa no próximo ciclo.")
    end

    render()
end

body.Visible = true
minimizeButton.Text = "—"

layout()

-- Restaura o farm salvo quando o script e carregado novamente.
if cfg.FARM then startCollection(true) end

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
