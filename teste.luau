local e=game:GetService("Players")

local r=game:GetService("Workspace")

local y=game:GetService("RunService")

local a=game:GetService("HttpService")

local c=game:GetService("CoreGui")

local w=game:GetService("UserInputService")

local j=game:GetService("ReplicatedStorage")

local o=e.LocalPlayer

local req=(syn and syn.request)or http_request or request or HttpPost



-- PADRÕES ZERADOS: Detecta 100% dos ovos imediatamente

local h={W="",P="",I=0,S=0,E=true,WH=false}

local cfgFile = "DiceRadar_Config.json"



-- ========================================================

-- CARREGAR CONFIGURAÇÃO (Se existir ficheiro guardado)

-- ========================================================

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



local X={} 

local Z={} 

local b=0 



if c:FindFirstChild("DiceRadarGUI") then c.DiceRadarGUI:Destroy() end



local gui=Instance.new("ScreenGui",c)

gui.Name="DiceRadarGUI"



local main=Instance.new("Frame",gui)

main.Size=UDim2.new(0,250,0,410) -- Aumentado para caber o botão de Salvar

main.Position=UDim2.new(0,20,0.5,-160)

main.BackgroundColor3=Color3.fromRGB(20,24,34)

main.BorderSizePixel=0

main.Active=true

main.Draggable=true

Instance.new("UICorner",main).CornerRadius=UDim.new(0,8)

local stk=Instance.new("UIStroke",main)

stk.Color=Color3.fromRGB(0,195,255)

stk.Thickness=1.5



local top=Instance.new("Frame",main)

top.Size=UDim2.new(1,0,0,30)

top.BackgroundTransparency=1

local title=Instance.new("TextLabel",top)

title.Size=UDim2.new(1,-10,1,0)

title.Position=UDim2.new(0,10,0,0)

title.BackgroundTransparency=1

title.Text="Radar & Webhook"

title.TextColor3=Color3.fromRGB(255,255,255)

title.Font=Enum.Font.GothamBold

title.TextSize=14

title.TextXAlignment=Enum.TextXAlignment.Left



local cont=Instance.new("ScrollingFrame",main)

cont.Size=UDim2.new(1,0,1,-35)

cont.Position=UDim2.new(0,0,0,35)

cont.BackgroundTransparency=1

cont.ScrollBarThickness=2

local lay=Instance.new("UIListLayout",cont)

lay.Padding=UDim.new(0,5)

lay.SortOrder=Enum.SortOrder.LayoutOrder



local function addBox(txt,val,cb)

    local f=Instance.new("Frame",cont)

    f.Size=UDim2.new(1,0,0,40)

    f.BackgroundTransparency=1

    local l=Instance.new("TextLabel",f)

    l.Size=UDim2.new(1,-10,0,15)

    l.Position=UDim2.new(0,10,0,0)

    l.BackgroundTransparency=1

    l.Text=txt

    l.TextColor3=Color3.fromRGB(200,200,200)

    l.Font=Enum.Font.Gotham

    l.TextSize=12

    l.TextXAlignment=Enum.TextXAlignment.Left

    local bx=Instance.new("TextBox",f)

    bx.Size=UDim2.new(1,-20,0,20)

    bx.Position=UDim2.new(0,10,0,18)

    bx.BackgroundColor3=Color3.fromRGB(30,34,44)

    bx.TextColor3=Color3.fromRGB(255,255,255)

    bx.Font=Enum.Font.Gotham

    bx.TextSize=11

    bx.Text=tostring(val)

    Instance.new("UICorner",bx).CornerRadius=UDim.new(0,4)

    bx.FocusLost:Connect(function() cb(bx.Text) end)

end



local function addTog(txt,val,cb)

    local f=Instance.new("Frame",cont)

    f.Size=UDim2.new(1,0,0,30)

    f.BackgroundTransparency=1

    local l=Instance.new("TextLabel",f)

    l.Size=UDim2.new(1,-50,1,0)

    l.Position=UDim2.new(0,10,0,0)

    l.BackgroundTransparency=1

    l.Text=txt

    l.TextColor3=Color3.fromRGB(200,200,200)

    l.Font=Enum.Font.Gotham

    l.TextSize=12

    l.TextXAlignment=Enum.TextXAlignment.Left

    local btn=Instance.new("TextButton",f)

    btn.Size=UDim2.new(0,30,0,16)

    btn.Position=UDim2.new(1,-40,0.5,-8)

    btn.BackgroundColor3=val and Color3.fromRGB(0,195,255) or Color3.fromRGB(50,50,50)

    btn.Text=""

    Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0)

    local cr=Instance.new("Frame",btn)

    cr.Size=UDim2.new(0,14,0,14)

    cr.Position=val and UDim2.new(1,-15,0,1) or UDim2.new(0,1,0,1)

    cr.BackgroundColor3=Color3.fromRGB(255,255,255)

    Instance.new("UICorner",cr).CornerRadius=UDim.new(1,0)

    btn.MouseButton1Click:Connect(function()

        val=not val

        btn.BackgroundColor3=val and Color3.fromRGB(0,195,255) or Color3.fromRGB(50,50,50)

        cr.Position=val and UDim2.new(1,-15,0,1) or UDim2.new(0,1,0,1)

        cb(val)

    end)

end



local function addBtn(txt,cb)

    local f=Instance.new("Frame",cont)

    f.Size=UDim2.new(1,0,0,30)

    f.BackgroundTransparency=1

    local btn=Instance.new("TextButton",f)

    btn.Size=UDim2.new(1,-20,1,0)

    btn.Position=UDim2.new(0,10,0,0)

    btn.BackgroundColor3=Color3.fromRGB(0,195,255)

    btn.TextColor3=Color3.fromRGB(20,24,34)

    btn.Font=Enum.Font.GothamBold

    btn.TextSize=12

    btn.Text=txt

    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)

    btn.MouseButton1Click:Connect(cb)

end



local stat=Instance.new("TextLabel",cont)

stat.Size=UDim2.new(1,-20,0,50)

stat.Position=UDim2.new(0,10,0,0)

stat.BackgroundTransparency=1

stat.Text="Status: Waiting...\nOvos no Mapa: 0\nValidos: 0 | Melhor: $0/s"

stat.TextColor3=Color3.fromRGB(0,255,160)

stat.Font=Enum.Font.GothamBold

stat.TextSize=12

stat.TextXAlignment=Enum.TextXAlignment.Left

stat.TextYAlignment=Enum.TextYAlignment.Top



addBox("Webhook URL",h.W,function(v) h.W=v end)

addBox("Ping Discord ID",h.P,function(v) h.P=v end)

addBox("Min Real Income ($/s)",h.I,function(v) h.I=tonumber(v) or 0 end)

addBox("Min Scale ou Kg",h.S,function(v) h.S=tonumber(v) or 0 end)



addTog("Enable ESP",h.E,function(v) 

    h.E=v 

    if not v then

        for k,esp in pairs(Z) do

            if esp.H then pcall(function() esp.H:Destroy() end) end

            if esp.B then pcall(function() esp.B:Destroy() end) end

        end

        table.clear(Z)

    end

end)



addTog("Enable Webhooks",h.WH,function(v) h.WH=v end)



addBtn("Testar Webhook", function()

    if h.W=="" or not req then return end

    local m=""

    if h.P~="" then m="<@"..h.P.."> Teste de Ping!" end

    local E={{

        title="✅ Conexão Estabelecida!",

        description="O Webhook do Dice Radar está a funcionar perfeitamente e pronto a detetar ovos.",

        color=65352

    }}

    pcall(function(...)

        req({Url=h.W,Method="POST",Headers={["Content-Type"]="application/json"},Body=a:JSONEncode({content=m,embeds=E})})

    end)

end)



-- ========================================================

-- BOTÃO DE SALVAR CONFIGURAÇÃO

-- ========================================================

addBtn("Salvar Configurações", function()

    if writefile then

        pcall(function()

            writefile(cfgFile, a:JSONEncode(h))

        end)

    end

end)



local s=nil pcall(function(...) s=require(j:WaitForChild("Client",5):WaitForChild("EggState",5)) end)

if not s then pcall(function(...) s=require(j.Client.EggState) end) end



local pUtil=nil pcall(function(...) pUtil=require(j:WaitForChild("Shared",5):WaitForChild("Util",5):WaitForChild("AssetItems",5)) end)

if not pUtil then pcall(function(...) pUtil=require(j.Shared.Util.AssetItems) end) end



local AssetEarnings=nil pcall(function(...) AssetEarnings=require(j:WaitForChild("Shared",5):WaitForChild("Util",5):WaitForChild("AssetEarnings",5)) end)

if not AssetEarnings then pcall(function(...) AssetEarnings=require(j.Shared.Util.AssetEarnings) end) end



local mutModule=nil pcall(function(...) mutModule=require(j:WaitForChild("Shared",5):WaitForChild("Modules",5):WaitForChild("Mutations",5)) end)

if not mutModule then pcall(function(...) mutModule=require(j.Shared.Modules.Mutations) end) end



local function formatNumber(n)

    if n >= 1e12 then return string.format("%.2fT", n/1e12) end

    if n >= 1e9 then return string.format("%.2fB", n/1e9) end

    if n >= 1e6 then return string.format("%.2fM", n/1e6) end

    if n >= 1e3 then return string.format("%.1fk", n/1e3) end

    return tostring(math.floor(n))

end



local function Wk(d)

    if not h.WH or h.W=="" or not req then return end

    local m=""

    if h.P~="" then m="<@"..h.P.."> Encontrei um Ovo Gigante!" end

    local E={{

        title="Ovo Gigante DETECTADO!",

        color=65352,

        fields={

            {name="Categoria",value=d.C,inline=true},

            {name="Area",value=d.A,inline=true},

            {name="Tamanho",value=d.P,inline=true},

            {name="Dinheiro/S",value="$"..formatNumber(d.R).."/s",inline=false}

        }

    }}

    pcall(function(...)

        req({Url=h.W,Method="POST",Headers={["Content-Type"]="application/json"},Body=a:JSONEncode({content=m,embeds=E})})

    end)

end



local function Dk(u,m,d)

    if not h.E or not m then return end

    

    if Z[u] then 

        if Z[u].B and Z[u].B:FindFirstChild("TextLabel") then

            Z[u].B.TextLabel.Text = string.format("[%s]\n$%s/s | %s",d.C,formatNumber(d.R),d.P)

        end

        return 

    end

    

    local hl=Instance.new("Highlight",m)

    hl.FillColor=Color3.fromRGB(0,195,255)

    hl.FillTransparency=0.6

    hl.OutlineColor=Color3.fromRGB(255,255,255)

    local bb=Instance.new("BillboardGui",m)

    bb.Size=UDim2.new(0,150,0,50)

    bb.StudsOffset=Vector3.new(0,4,0)

    bb.AlwaysOnTop=true

    local tl=Instance.new("TextLabel",bb)

    tl.Size=UDim2.new(1,0,1,0)

    tl.BackgroundTransparency=1

    tl.Text=string.format("[%s]\n$%s/s | %s",d.C,formatNumber(d.R),d.P)

    tl.TextColor3=Color3.fromRGB(0,195,255)

    tl.TextStrokeTransparency=0.2

    tl.Font=Enum.Font.GothamBold

    tl.TextSize=11

    Z[u]={H=hl,B=bb,M=m}

end



task.spawn(function(...)

    while task.wait(1.5) do

        pcall(function(...)

            local act=0

            local total=0

            

            -- 1. Criação do mapa usando os modelos FÍSICOS do jogo

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

            

            -- 2. Tentar suplementar a informação com os registros invisíveis em memória

            local records = {}

            if s then

                local st, fd = false, nil

                if s.ReadFieldEggs then st, fd = pcall(s.ReadFieldEggs)

                elseif s.SyncFieldEggs then st, fd = pcall(s.SyncFieldEggs) end

                

                if st and type(fd)=="table" then

                    local rawRec = fd.Records or fd

                    if type(rawRec)=="table" then

                        for k, rec in pairs(rawRec) do

                            if type(rec)=="table" then

                                local u = tostring(rec.Uid or k)

                                records[u] = rec

                            end

                        end

                    end

                end

            end

            

            local validUids = {}

            

            -- 3. Passar por TODOS os ovos que nós estamos vendo

            for u, rawModel in pairs(pModels) do

                total = total + 1

                local rec = records[u] or {}

                

                local cat = rawModel:GetAttribute("Category") or rawModel:GetAttribute("AssetCategory") or rec.AssetCategory or rec.Category or "Egg"

                local area = rawModel:GetAttribute("AreaId") or rawModel:GetAttribute("Area") or rec.AreaId or "Unknown"

                

                local scale = tonumber(rawModel:GetAttribute("Scale") or rawModel:GetAttribute("AssetScale"))

                if not scale then scale = tonumber(rec.Scale or rec.AssetScale) end

                scale = scale or 1

                

                local peso = tonumber(rawModel:GetAttribute("Weight") or rawModel:GetAttribute("Kg") or rawModel:GetAttribute("ModelWeight"))

                if not peso then peso = tonumber(rec.Weight or rec.Kg or rec.ModelWeight) end

                

                local mAttr = rawModel:GetAttribute("Mutations") or rawModel:GetAttribute("Mutation") or rec.Mutations or rec.Mutation

                

                -- INVOCAÇÃO DO CÁLCULO NATIVO DO JOGO PARA PRECISÃO 100%

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

                

                -- FALLBACK DE CALCULO

                if real == 0 then

                    local base = tonumber(rawModel:GetAttribute("Income") or rawModel:GetAttribute("EarningRate"))

                    if not base then base = tonumber(rec.Income or rec.EarningRate or rec.MoneyPerSecond) end

                    if (not base or base == 0) and type(rec.ItemData)=="table" then base = tonumber(rec.ItemData.MoneyPerSecond) end

                    

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

                    elseif type(mAttr)=="table" then

                        for _, m in pairs(mAttr) do

                            local val = (type(m)=="table" and tonumber(m.Multiplier or m.Value)) or tonumber(m) or 1.5

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

                

                -- APLICAÇÃO DO FILTRO DO JOGADOR

                if real >= h.I and checkSize >= h.S then

                    act = act + 1

                    validUids[u] = true

                    

                    local d = {U=u, C=cat, A=area, S=scale, R=real, P=pesoStr}

                    

                    if not X[u] then

                        X[u] = true

                        Wk(d)

                    end

                    

                    if rawModel then

                        local pModel = rawModel

                        if pModel:IsA("Folder") then

                            pModel = pModel:FindFirstChildWhichIsA("BasePart") or pModel:FindFirstChildWhichIsA("Model") or pModel

                        end

                        Dk(u, pModel, d)

                    end

                end

            end

            

            if stat then stat.Text=string.format("Status: Scanning...\nOvos no Mapa: %d\nValidos (Alvos): %d | Melhor: $%s/s",total,act,formatNumber(b)) end

            

            -- Limpeza dos ESPs antigos ou rejeitados pelo filtro

            for k,v in pairs(Z) do

                if not h.E or not validUids[k] or not v.M or not v.M.Parent then

                    if v.H then pcall(function() v.H:Destroy() end) end

                    if v.B then pcall(function() v.B:Destroy() end) end

                    Z[k]=nil

                end

            end

        end)

    end

end)