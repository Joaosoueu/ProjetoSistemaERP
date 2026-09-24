--[[
========================================================================
 EVENTS LAB (client) -- FOCO: PET / MEGA SLIME / TREE-GROW
 Janela propria (fecha X / minimiza -). SPY (captura args reais) +
 secao dos sistemas novos + HOOKS LAB (tamper/getgc).
========================================================================
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local playerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- ---------- acha remotes ----------
local function findRemote(name)
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    local r = rem and rem:FindFirstChild(name)
    if r then return r end
    return ReplicatedStorage:FindFirstChild(name, true)
end

-- ---------- log ----------
local logLines = {}
local logLbl
local function log(msg)
    print("[EVENTS-LAB] " .. msg)
    table.insert(logLines, os.date("%H:%M:%S") .. " " .. msg)
    if #logLines > 120 then table.remove(logLines, 1) end
    if logLbl then logLbl.Text = table.concat(logLines, "\n") end
end

-- ---------- helpers ----------
local function new(cls, parent, props)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function killScript(s)
    pcall(function() if s:IsA("BaseScript") then s.Disabled = true end end)
    return (pcall(function() s:Destroy() end))
end

-- dispara remote:FireServer(...) com pcall + log (preserva nils no meio)
local function fire(remote, rname, ...)
    if not remote then log("[!] remote ausente: " .. tostring(rname)); return false end
    local a = table.pack(...)
    local ok, err = pcall(function() remote:FireServer(table.unpack(a, 1, a.n)) end)
    if ok then log("-> " .. tostring(rname) .. " enviado")
    else log("[!] " .. tostring(rname) .. " falhou: " .. tostring(err)) end
    return ok
end

-- ======================= JANELA PRINCIPAL =======================
local existing = playerGui:FindFirstChild("EventsLabHub"); if existing then existing:Destroy() end
local screenGui = new("ScreenGui", playerGui, { Name="EventsLabHub", ResetOnSpawn=false, DisplayOrder=10050, IgnoreGuiInset=true })
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not screenGui.Enabled then screenGui.Enabled = true end
end)

local TITLE_H = 32
local frame = new("Frame", screenGui, { Size=UDim2.new(0,380,0,460), Position=UDim2.new(0,420,0,60),
    BackgroundColor3=Color3.fromRGB(22,22,28), BorderSizePixel=0, Active=true, Draggable=true, ClipsDescendants=true })
new("UIStroke", frame, { Color=Color3.fromRGB(150,90,240), Thickness=1, Transparency=0.3 })
local titleBar = new("Frame", frame, { Size=UDim2.new(1,0,0,TITLE_H), BackgroundColor3=Color3.fromRGB(34,30,46), BorderSizePixel=0 })
new("TextLabel", titleBar, { Size=UDim2.new(1,-64,1,0), Position=UDim2.new(0,12,0,0), BackgroundTransparency=1,
    TextColor3=Color3.fromRGB(200,160,255), Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Text="EVENTS LAB (client)" })
local minBtn = new("TextButton", titleBar, { Size=UDim2.new(0,30,0,TITLE_H), Position=UDim2.new(1,-62,0,0), BackgroundTransparency=1,
    TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=16, Text="—" })
local closeBtn = new("TextButton", titleBar, { Size=UDim2.new(0,30,0,TITLE_H), Position=UDim2.new(1,-30,0,0),
    BackgroundColor3=Color3.fromRGB(150,45,45), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=14, Text="X" })

local body = new("ScrollingFrame", frame, { Position=UDim2.new(0,0,0,TITLE_H), Size=UDim2.new(1,0,1,-TITLE_H),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y })
new("UIPadding", body, { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,10) })
new("UIListLayout", body, { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6) })

local order = 0
local function nextOrder() order = order + 1; return order end
local function section(text, color)
    return new("TextLabel", body, { Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, TextColor3=color or Color3.fromRGB(200,160,255),
        Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Text=text, LayoutOrder=nextOrder() })
end
local function button(text, color, cb)
    local b = new("TextButton", body, { Size=UDim2.new(1,0,0,30), BackgroundColor3=color, TextColor3=Color3.new(1,1,1),
        Font=Enum.Font.GothamBold, TextSize=12, Text=text, LayoutOrder=nextOrder() })
    b.MouseButton1Click:Connect(cb); return b
end
local function fullLabel(txt, color)
    return new("TextLabel", body, { Size=UDim2.new(1,0,0,22), BackgroundColor3=Color3.fromRGB(40,40,48), BorderSizePixel=0,
        TextColor3=color or Color3.fromRGB(220,220,220), Font=Enum.Font.Code, TextSize=11, Text=txt, LayoutOrder=nextOrder() })
end
local function textField(placeholder)
    return new("TextBox", body, { Size=UDim2.new(1,0,0,28), BackgroundColor3=Color3.fromRGB(48,48,56), BorderSizePixel=0,
        TextColor3=Color3.new(1,1,1), Font=Enum.Font.Gotham, TextSize=12, PlaceholderText=placeholder, Text="", ClearTextOnFocus=false, LayoutOrder=nextOrder() })
end

-- ---------- remotes dos sistemas novos ----------
local PetEvent        = findRemote("PetEvent")
local MegaSlimeAction = findRemote("MegaSlimeAction")
local TreeShopAction  = (function()
    local ts  = ReplicatedStorage:FindFirstChild("TreeSystem")
    local rem = ts and ts:FindFirstChild("Remotes")
    return (rem and rem:FindFirstChild("ShopAction")) or ReplicatedStorage:FindFirstChild("ShopAction", true)
end)()

section("STATUS", Color3.fromRGB(120,220,255))
fullLabel(("Pet=%s Mega=%s Tree=%s"):format(tostring(PetEvent~=nil), tostring(MegaSlimeAction~=nil), tostring(TreeShopAction~=nil)),
    (PetEvent and MegaSlimeAction) and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))

-- ======================= REMOTE SPY (captura TUDO: OUT + IN) =======================
-- OUT: FireServer/InvokeServer que o JOGO manda (hook __namecall + checkcaller).
-- IN : todos os OnClientEvent (servidor -> cliente): rewards, state, etc.
-- Guarda cada OUT distinto p/ replay por indice. Salva tudo em arquivo.
section("REMOTE SPY (captura TUDO: out + in)", Color3.fromRGB(120,220,255))
local spyOn = false
local spyInOn = false
local spyLines = {}
local spyCaptured = {}
local spyFilterBox = textField("filtro (nome do remote; vazio = tudo)")
local lastSpy = nil
local spyHooked, spyInHooked = false, false

local function spyFmt(...)
    local a = table.pack(...)
    local parts = {}
    for i = 1, a.n do
        local v = a[i]; local t = typeof(v)
        if t == "Instance" then parts[i] = v.ClassName..":"..v.Name
        elseif t == "table" then
            local kv = {}; for k2, v2 in pairs(v) do kv[#kv+1] = tostring(k2).."="..tostring(v2) end
            parts[i] = "{"..table.concat(kv, ",").."}"
        elseif t == "string" then parts[i] = '"'..v..'"'
        else parts[i] = tostring(v) end
    end
    return table.concat(parts, ", ")
end
local function matchFilter(nm)
    local flt = spyFilterBox.Text:lower()
    return flt == "" or (nm ~= nil and nm:lower():find(flt, 1, true) ~= nil)
end
local function pushLine(s)
    table.insert(spyLines, os.date("%H:%M:%S").." "..s)
    if #spyLines > 500 then table.remove(spyLines, 1) end
    log("[SPY] "..s)
end

local function installSpy()
    if spyHooked then return true end
    if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
        log("[SPY] executor sem hookmetamethod/getnamecallmethod"); return false
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if spyOn then
            local ok, method = pcall(getnamecallmethod)
            if ok and (method == "FireServer" or method == "InvokeServer")
               and not (typeof(checkcaller) == "function" and checkcaller()) then
                local nm = (typeof(self) == "Instance") and self.Name or tostring(self)
                if matchFilter(nm) then
                    local args = table.pack(...)
                    lastSpy = { remote = self, args = args }
                    local sig = method.." "..nm.."("..spyFmt(...)..")"
                    local dup = false
                    for _, c in ipairs(spyCaptured) do if c.sig == sig then dup = true; break end end
                    if not dup then table.insert(spyCaptured, { remote = self, args = args, sig = sig }) end
                    pushLine("-> "..sig)
                end
            end
        end
        return old(self, ...)
    end)
    spyHooked = true
    return true
end

local SPY_IGNORE = { UpdateMoney=true, CarShopUpdate=true, LeaderboardUpdate=true,
    IndexUpdate=true, InventoryUpdate=true, CheckpointLuckUpdate=true, SlimeReveal=true }
local function installSpyIncoming()
    if spyInHooked then return true end
    local function hookEvt(ev)
        pcall(function()
            ev.OnClientEvent:Connect(function(...)
                if spyInOn and matchFilter(ev.Name) then
                    if spyFilterBox.Text == "" and SPY_IGNORE[ev.Name] then return end
                    pushLine("<- "..ev.Name.."("..spyFmt(...)..")")
                end
            end)
        end)
    end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") then hookEvt(d) end
    end
    pcall(function()
        ReplicatedStorage.DescendantAdded:Connect(function(d)
            if d:IsA("RemoteEvent") then hookEvt(d) end
        end)
    end)
    spyInHooked = true
    return true
end

local spyBtn
spyBtn = button("SPY OUT: OFF (FireServer do jogo)", Color3.fromRGB(60,90,150), function()
    if not spyOn then if not installSpy() then return end; spyOn = true else spyOn = false end
    spyBtn.Text = "SPY OUT: "..(spyOn and "ON (jogue normal)" or "OFF").." (FireServer do jogo)"
    spyBtn.BackgroundColor3 = spyOn and Color3.fromRGB(40,120,90) or Color3.fromRGB(60,90,150)
    log("[SPY] OUT "..(spyOn and "ligado" or "desligado"))
end)
local spyInBtn
spyInBtn = button("SPY IN: OFF (server -> cliente)", Color3.fromRGB(60,90,150), function()
    if not spyInOn then installSpyIncoming(); spyInOn = true else spyInOn = false end
    spyInBtn.Text = "SPY IN: "..(spyInOn and "ON (rewards/state)" or "OFF").." (server -> cliente)"
    spyInBtn.BackgroundColor3 = spyInOn and Color3.fromRGB(40,120,90) or Color3.fromRGB(60,90,150)
    log("[SPY] IN "..(spyInOn and "ligado -- use filtro (ex: Pet)" or "desligado"))
end)
button("Listar OUT capturados p/ replay (#)", Color3.fromRGB(60,60,90), function()
    if #spyCaptured == 0 then log("[SPY] nada capturado ainda"); return end
    for i, c in ipairs(spyCaptured) do log("   #"..i.." "..c.sig) end
end)
local replayBox = textField("indice p/ Replay #N (ex: 3)")
button("Replay #N (da lista de capturados)", Color3.fromRGB(150,80,40), function()
    local i = tonumber(replayBox.Text)
    local c = i and spyCaptured[i]
    if not c then log("[SPY] indice invalido -- use 'Listar OUT capturados'"); return end
    local ok, err = pcall(function() c.remote:FireServer(table.unpack(c.args, 1, c.args.n)) end)
    log(ok and ("[SPY] replay #"..i.." -> "..c.sig) or ("[SPY] replay #"..i.." falhou: "..tostring(err)))
end)
button("Replay ULTIMO capturado", Color3.fromRGB(150,80,40), function()
    if not lastSpy then log("[SPY] nada capturado ainda"); return end
    local ok, err = pcall(function() lastSpy.remote:FireServer(table.unpack(lastSpy.args, 1, lastSpy.args.n)) end)
    log(ok and ("[SPY] replay -> "..lastSpy.remote.Name) or ("[SPY] replay falhou: "..tostring(err)))
end)
button("Copiar SPY log (out+in)", Color3.fromRGB(60,60,90), function()
    if typeof(setclipboard) == "function" then pcall(setclipboard, table.concat(spyLines, "\n")); log("[SPY] "..#spyLines.." linhas copiadas") else log("[!] sem setclipboard") end
end)
button("Salvar SPY -> spy_log.txt (workspace)", Color3.fromRGB(0,150,90), function()
    if typeof(writefile) ~= "function" then log("[!] sem writefile"); return end
    pcall(writefile, "spy_log.txt", table.concat(spyLines, "\n"))
    log("[SPY] salvo em workspace/spy_log.txt ("..#spyLines.." linhas)")
end)

-- ======================= [NOVO] PET / MEGA SLIME / TREE-GROW =======================
-- Pets (Remotes.PetEvent): BuyEgg/BuyEggRobux/OpenReadyEgg/HatchNow{NestIndex,EggKey};
--   SellPet/UpgradePetStar/PrepareRobuxPetStar/BeginPetGift{Uid}; SellAllPets{}.
-- Mega (Remotes.MegaSlimeAction): Select/Sell{Uid}; SellAll{}; OpenSell{}; EquipBest.
-- Tree (TreeSystem.Remotes.ShopAction): Grow30(slotIndex).
-- EggKey/Uid vem do SERVIDOR -> ligue o SPY (filtro Pet/Mega), faca a acao real 1x, cole aqui.
section("[NOVO] Pet / Mega Slime / Tree-Grow", Color3.fromRGB(255,140,90))
fullLabel("EggKey/Uid = do servidor. SPY ON -> faca 1 acao real -> cole o valor.", Color3.fromRGB(220,200,120))
local nestBox = textField("NestIndex / slot (default 1)"); nestBox.Text = "1"
local eggBox  = textField("EggKey (pego no SPY)")
local uidBox  = textField("Pet/Mega Uid (pego no SPY)")

-- PET
button("PET RequestState (popula estado)", Color3.fromRGB(60,90,150), function()
    fire(PetEvent, "Pet:RequestState", "RequestState")
end)
button("PET BuyEgg (cash) -- caro sem saldo?", Color3.fromRGB(120,90,40), function()
    fire(PetEvent, "Pet:BuyEgg", "BuyEgg", {NestIndex = tonumber(nestBox.Text) or 1, EggKey = eggBox.Text})
    log("   comprou ovo caro sem saldo = brecha (servidor tem que checar custo)")
end)
button("PET BuyEggRobux (SEM pagar?)", Color3.fromRGB(150,40,40), function()
    fire(PetEvent, "Pet:BuyEggRobux", "BuyEggRobux", {NestIndex = tonumber(nestBox.Text) or 1, EggKey = eggBox.Text})
    log("   ovo sem prompt de Robux = GRATIS (so ProcessReceipt)")
end)
button("PET HatchNow (skip SEM Robux?)", Color3.fromRGB(150,40,40), function()
    fire(PetEvent, "Pet:HatchNow", "HatchNow", {NestIndex = tonumber(nestBox.Text) or 1, EggKey = eggBox.Text})
    log("   chocou na hora sem pagar = brecha")
end)
button("PET OpenReadyEgg (abre ovo pronto)", Color3.fromRGB(120,90,40), function()
    fire(PetEvent, "Pet:OpenReadyEgg", "OpenReadyEgg", {NestIndex = tonumber(nestBox.Text) or 1, EggKey = eggBox.Text})
end)
button("PET UpgradePetStar (Uid) -- checa saldo?", Color3.fromRGB(120,90,40), function()
    fire(PetEvent, "Pet:UpgradePetStar", "UpgradePetStar", {Uid = uidBox.Text})
    log("   subiu estrela sem cash = brecha")
end)
button("PET PrepareRobuxPetStar (SEM pagar?)", Color3.fromRGB(150,40,40), function()
    fire(PetEvent, "Pet:PrepareRobuxPetStar", "PrepareRobuxPetStar", {Uid = uidBox.Text})
end)
button("PET SellPet (Uid)", Color3.fromRGB(120,90,40), function()
    fire(PetEvent, "Pet:SellPet", "SellPet", {Uid = uidBox.Text})
    log("   Uid falso/negativo ou o equipado = testa dup/protecao")
end)
button("PET SellAllPets (protege o equipado?)", Color3.fromRGB(120,90,40), function()
    fire(PetEvent, "Pet:SellAllPets", "SellAllPets", {})
    log("   vendeu ate o equipado = protecao falha")
end)
button("PET BeginPetGift (Uid) -> self-dup?", Color3.fromRGB(150,80,40), function()
    fire(PetEvent, "Pet:BeginPetGift", "BeginPetGift", {Uid = uidBox.Text})
    log("   inicia gift de pet; depois testar self-dup")
end)

-- MEGA SLIME
button("MEGA Select (Uid) -> coloca mega alheio?", Color3.fromRGB(120,90,40), function()
    fire(MegaSlimeAction, "Mega:Select", "Select", {Uid = uidBox.Text})
end)
button("MEGA EquipBest", Color3.fromRGB(120,90,40), function()
    fire(MegaSlimeAction, "Mega:EquipBest", "EquipBest")
end)
button("MEGA Sell (Uid) -- falso/negativo p/ dup?", Color3.fromRGB(120,90,40), function()
    fire(MegaSlimeAction, "Mega:Sell", "Sell", {Uid = uidBox.Text})
end)
button("MEGA SellAll (protege o colocado?)", Color3.fromRGB(120,90,40), function()
    fire(MegaSlimeAction, "Mega:SellAll", "SellAll", {})
end)

-- TREE GROW30
button("Tree Grow30 (SEM pagar? slot=nestBox)", Color3.fromRGB(150,40,40), function()
    fire(TreeShopAction, "Tree:Grow30", "Grow30", tonumber(nestBox.Text) or 1)
    log("   adiantou o crescimento sem pagar = brecha")
end)

-- FUZZ automatico: dispara varios args MALFORMADOS em sequencia (nil / tabela / negativo /
-- gigante / tipo errado). Olhe o LOG e o jogo: se o servidor CONCEDER algum invalido = brecha.
fullLabel("v FUZZ: manda args ruins em sequencia. Veja qual o servidor ACEITA.", Color3.fromRGB(255,200,120))
button("FUZZ Pet BuyEgg (NestIndex/EggKey ruins)", Color3.fromRGB(150,80,40), function()
    task.spawn(function()
        local egg = eggBox.Text
        local cases = {
            {NestIndex = -1,     EggKey = egg},
            {NestIndex = 0,      EggKey = egg},
            {NestIndex = 999999, EggKey = egg},
            {NestIndex = 1,      EggKey = ""},
            {NestIndex = 1,      EggKey = "FAKE_EGG"},
            {NestIndex = 1,      EggKey = {}},
            {NestIndex = 1},                    -- EggKey nil
            "NAO_TABELA",                       -- payload nao e tabela
        }
        for i, c in ipairs(cases) do
            fire(PetEvent, "FUZZ BuyEgg#"..i, "BuyEgg", c); task.wait(0.25)
        end
        log("[FUZZ] BuyEgg: se ganhou ovo em algum caso invalido = brecha (checar no servidor)")
    end)
end)
button("FUZZ Pet SellPet (Uid ruins)", Color3.fromRGB(150,80,40), function()
    task.spawn(function()
        local cases = { {Uid=""}, {Uid="FAKE"}, {Uid=-1}, {Uid=0}, {Uid={}}, {}, "NAO_TABELA" }
        for i, c in ipairs(cases) do
            fire(PetEvent, "FUZZ SellPet#"..i, "SellPet", c); task.wait(0.25)
        end
        log("[FUZZ] SellPet: creditou/dup com Uid invalido = brecha")
    end)
end)
button("FUZZ Mega Sell (Uid ruins)", Color3.fromRGB(150,80,40), function()
    task.spawn(function()
        local cases = { {Uid=""}, {Uid="FAKE"}, {Uid=-1}, {Uid={}}, {}, "NAO_TABELA" }
        for i, c in ipairs(cases) do
            fire(MegaSlimeAction, "FUZZ MegaSell#"..i, "Sell", c); task.wait(0.25)
        end
        log("[FUZZ] Mega Sell: idem SellPet")
    end)
end)
button("FUZZ Tree Grow30 (slot ruins)", Color3.fromRGB(150,80,40), function()
    task.spawn(function()
        for _, v in ipairs({-1, 0, 999999, 1.5}) do
            fire(TreeShopAction, "FUZZ Grow30("..tostring(v)..")", "Grow30", v); task.wait(0.25)
        end
        fire(TreeShopAction, "FUZZ Grow30(nil)", "Grow30")
        log("[FUZZ] Grow30: cresceu com slot invalido/sem pagar = brecha")
    end)
end)

-- ======================= HOOKS LAB (overlay) =======================
-- Menu dedicado: escaneia as funcoes do executor e da ferramenta p/ cada hook.
local function openHooksLab()
    local sg = playerGui:FindFirstChild("HooksLabGui"); if sg then sg:Destroy() end
    sg = new("ScreenGui", playerGui, { Name="HooksLabGui", ResetOnSpawn=false, DisplayOrder=10070, IgnoreGuiInset=true })
    sg:GetPropertyChangedSignal("Enabled"):Connect(function() if not sg.Enabled then sg.Enabled = true end end)

    local TH = 28
    local fr = new("Frame", sg, { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
        Size=UDim2.new(0,460,0,560), BackgroundColor3=Color3.fromRGB(20,20,26), BorderSizePixel=0,
        Active=true, Draggable=true, ClipsDescendants=true })
    local cam = workspace.CurrentCamera
    local function fitHooks()
        local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
        fr.Size = UDim2.new(0, math.min(460, math.floor(vp.X * 0.94)), 0, math.min(560, math.floor(vp.Y * 0.86)))
    end
    fitHooks()
    if cam then pcall(function() cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitHooks) end) end
    new("UIStroke", fr, { Color=Color3.fromRGB(90,200,240), Thickness=1, Transparency=0.3 })
    local tb = new("Frame", fr, { Size=UDim2.new(1,0,0,TH), BackgroundColor3=Color3.fromRGB(26,36,46), BorderSizePixel=0 })
    new("TextLabel", tb, { Size=UDim2.new(1,-34,1,0), Position=UDim2.new(0,12,0,0), BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(140,220,255), Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Text="HOOKS LAB (executor)" })
    local xb = new("TextButton", tb, { Size=UDim2.new(0,32,1,0), Position=UDim2.new(1,-32,0,0),
        BackgroundColor3=Color3.fromRGB(150,45,45), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=14, Text="X" })
    xb.MouseButton1Click:Connect(function() sg:Destroy() end)

    local hbody = new("ScrollingFrame", fr, { Position=UDim2.new(0,0,0,TH), Size=UDim2.new(1,0,1,-TH),
        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=5, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y })
    new("UIPadding", hbody, { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,10) })
    new("UIListLayout", hbody, { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,5) })
    local ho = 0
    local function hnext() ho = ho + 1; return ho end
    local function hsec(t, c) new("TextLabel", hbody, { Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, TextColor3=c or Color3.fromRGB(140,220,255),
        Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Text=t, LayoutOrder=hnext() }) end
    local function hbtn(t, c, cb) local b = new("TextButton", hbody, { Size=UDim2.new(1,0,0,28), BackgroundColor3=c, TextColor3=Color3.new(1,1,1),
        Font=Enum.Font.GothamBold, TextSize=12, Text=t, LayoutOrder=hnext() }); b.MouseButton1Click:Connect(cb); return b end
    local function hlbl(t, c) return new("TextLabel", hbody, { Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=Color3.fromRGB(30,30,38),
        BorderSizePixel=0, TextColor3=c or Color3.fromRGB(210,210,210), Font=Enum.Font.Code, TextSize=11, TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left, Text=t, LayoutOrder=hnext() }) end
    local function hfield(ph, def) return new("TextBox", hbody, { Size=UDim2.new(1,0,0,26), BackgroundColor3=Color3.fromRGB(48,48,56), BorderSizePixel=0,
        TextColor3=Color3.new(1,1,1), Font=Enum.Font.Gotham, TextSize=12, PlaceholderText=ph, Text=def or "", ClearTextOnFocus=false, LayoutOrder=hnext() }) end

    -- log proprio (sem corte) + copiar/salvar aqui dentro
    local hookLines = {}
    local outerLog = log
    local function log(msg)
        table.insert(hookLines, os.date("%H:%M:%S").." "..tostring(msg))
        if #hookLines > 4000 then table.remove(hookLines, 1) end
        outerLog(msg)
    end

    -- 1) SCAN
    hsec("1) FUNCOES DO EXECUTOR (scan)", Color3.fromRGB(140,220,255))
    local capLbl = hlbl("(clique escanear)")
    local function scan()
        local names = {
            "hookfunction","hookmetamethod","getrawmetatable","setreadonly","isreadonly","newcclosure",
            "checkcaller","getnamecallmethod","iscclosure","islclosure","clonefunction",
            "getconnections","firesignal","firetouchinterest","fireclickdetector","fireproximityprompt",
            "getgc","getinstances","getnilinstances","getloadedmodules","getsenv","getrenv","getgenv",
            "getscriptclosure","getscriptbytecode","getscripthash","getcustomasset","gethui","cloneref",
            "compareinstances","setclipboard","setfpscap","identifyexecutor","request","writefile","readfile",
        }
        local env = {}
        pcall(function() env = (typeof(getgenv) == "function" and getgenv()) or getfenv(0) end)
        local function has(n)
            local ok, v = pcall(function() return env[n] end)
            return ok and typeof(v) == "function"
        end
        local have, miss = {}, {}
        for _, n in ipairs(names) do
            if has(n) then table.insert(have, n) else table.insert(miss, n) end
        end
        local dbg = {}
        if typeof(debug) == "table" then
            for _, dn in ipairs({"getupvalues","getupvalue","setupvalue","getconstants","getproto","getprotos","getinfo","getstack"}) do
                if typeof(debug[dn]) == "function" then table.insert(dbg, "debug."..dn) end
            end
        end
        capLbl.Text = "TEM ("..#have.."): "..table.concat(have, ", ").."\n\ndebug: "..table.concat(dbg, ", ").."\n\nFALTA: "..table.concat(miss, ", ")
        log("[HOOK] scan: "..#have.." funcoes + "..#dbg.." debug.*; faltam "..#miss)
        local exec = "?"; pcall(function() if identifyexecutor then exec = tostring((identifyexecutor())) end end)
        log("[HOOK] executor: "..exec)
    end
    hbtn("Escanear funcoes do executor", Color3.fromRGB(40,120,150), scan)

    -- 2) TOUCH / CLICK / PROMPT
    hsec("2) FIRE: touch / click / prompt", Color3.fromRGB(255,180,90))
    local touchFilter = hfield("nome da parte (ex: Checkpoint)", "Checkpoint")
    hbtn("firetouchinterest: tocar partes p/ nome", Color3.fromRGB(120,90,40), function()
        if typeof(firetouchinterest) ~= "function" then log("[HOOK] sem firetouchinterest"); return end
        local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then log("[HOOK] sem HumanoidRootPart"); return end
        local flt = touchFilter.Text:lower(); local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and (flt == "" or d.Name:lower():find(flt, 1, true)) then
                n = n + 1
                pcall(function() firetouchinterest(hrp, d, 0); firetouchinterest(hrp, d, 1) end)
            end
        end
        log("[HOOK] firetouchinterest em "..n.." partes ('"..flt.."')")
    end)
    hbtn("fireclickdetector: TODOS ClickDetectors", Color3.fromRGB(120,90,40), function()
        if typeof(fireclickdetector) ~= "function" then log("[HOOK] sem fireclickdetector"); return end
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ClickDetector") then n = n + 1; pcall(fireclickdetector, d) end
        end
        log("[HOOK] fireclickdetector em "..n.." detectores")
    end)
    local promptFilter = hfield("filtro prompt (ex: PetNest / vazio=todos)", "")
    hbtn("fireproximityprompt: por filtro", Color3.fromRGB(120,90,40), function()
        if typeof(fireproximityprompt) ~= "function" then log("[HOOK] sem fireproximityprompt"); return end
        local flt = promptFilter.Text:lower(); local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and (flt == "" or d.Name:lower():find(flt, 1, true)) then
                n = n + 1; pcall(function() d.Enabled = true; fireproximityprompt(d) end)
            end
        end
        log("[HOOK] fireproximityprompt em "..n.." prompts ('"..flt.."')")
    end)

    -- 3) ARG-TAMPER
    hsec("3) ARG-TAMPER (altera FireServer real)", Color3.fromRGB(255,90,90))
    hlbl("Reescreve 1 arg das chamadas REAIS. Ex: remote=PetEvent, idx=1, val=<tabela/valor>. idx e 1-based (arg1=1o depois do :). SELF_USERID/SELF_PLAYER como valor.", Color3.fromRGB(220,200,120))
    local tRemote = hfield("remote (ex: PetEvent)", "PetEvent")
    local tIdx = hfield("arg index (ex: 2)", "2")
    local tVal = hfield("novo valor (SELF_USERID / texto / numero)", "SELF_USERID")
    local tamperOn = false
    local tamperHooked = false
    local function parseVal(s)
        if s == "SELF_USERID" then return LocalPlayer.UserId end
        if s == "SELF_PLAYER" then return LocalPlayer end
        local n = tonumber(s); if n ~= nil then return n end
        return s
    end
    local function installTamper()
        if tamperHooked then return true end
        if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then log("[HOOK] sem hookmetamethod"); return false end
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if tamperOn and not (typeof(checkcaller) == "function" and checkcaller()) then
                local ok, m = pcall(getnamecallmethod)
                if ok and (m == "FireServer" or m == "InvokeServer") then
                    local nm = (typeof(self) == "Instance") and self.Name or ""
                    local want = tRemote.Text:lower()
                    if want ~= "" and nm:lower():find(want, 1, true) then
                        local a = table.pack(...)
                        local idx = math.floor(tonumber(tIdx.Text) or 0)
                        if idx >= 1 and idx <= a.n then
                            a[idx] = parseVal(tVal.Text)
                            log("[TAMPER] "..nm.." arg#"..idx.." -> "..tostring(a[idx]))
                            return old(self, table.unpack(a, 1, a.n))
                        end
                    end
                end
            end
            return old(self, ...)
        end)
        tamperHooked = true
        return true
    end
    local tBtn
    tBtn = hbtn("TAMPER: OFF (liga e faz a acao no jogo)", Color3.fromRGB(150,40,40), function()
        if not tamperOn then if not installTamper() then return end; tamperOn = true else tamperOn = false end
        tBtn.Text = "TAMPER: "..(tamperOn and "ON (faca a acao real no jogo)" or "OFF (liga e faz a acao no jogo)")
        tBtn.BackgroundColor3 = tamperOn and Color3.fromRGB(190,45,40) or Color3.fromRGB(150,40,40)
        log("[TAMPER] "..(tamperOn and ("ligado: "..tRemote.Text.." arg#"..tIdx.Text.."="..tVal.Text) or "desligado"))
    end)

    -- 4) SIGNALS
    hsec("4) SIGNALS (getconnections)", Color3.fromRGB(255,180,90))
    local sigRemote = hfield("remote p/ OnClientEvent (ex: PetEvent)", "PetEvent")
    hbtn("Contar conexoes do OnClientEvent", Color3.fromRGB(60,90,150), function()
        if typeof(getconnections) ~= "function" then log("[HOOK] sem getconnections"); return end
        local r = findRemote(sigRemote.Text); if not r then log("[HOOK] remote nao achado"); return end
        local ok, cons = pcall(getconnections, r.OnClientEvent)
        if ok then log("[HOOK] "..r.Name..".OnClientEvent tem "..#cons.." conexoes") else log("[HOOK] falhou") end
    end)
    hbtn("DESLIGAR conexoes (testa anti-cheat client)", Color3.fromRGB(150,40,40), function()
        if typeof(getconnections) ~= "function" then log("[HOOK] sem getconnections"); return end
        local r = findRemote(sigRemote.Text); if not r then log("[HOOK] remote nao achado"); return end
        local ok, cons = pcall(getconnections, r.OnClientEvent)
        if ok then for _, c in ipairs(cons) do pcall(function() c:Disable() end) end
            log("[HOOK] desligadas "..#cons.." conexoes de "..r.Name)
        end
    end)

    -- 5) getgc SEARCH
    hsec("5) getgc SEARCH (memoria do cliente)", Color3.fromRGB(255,180,90))
    hlbl("Varre a memoria por palavra: acha tabelas/funcoes. Ex: Uid, EggKey, EggOrder, PetIncome, Pets.", Color3.fromRGB(220,200,120))
    local gcBox = hfield("palavra (ex: Uid, EggKey, PetIncome)", "Uid")
    hbtn("Buscar no getgc", Color3.fromRGB(120,90,40), function()
        if typeof(getgc) ~= "function" then log("[HOOK] sem getgc"); return end
        local kw = gcBox.Text:lower(); if kw == "" then log("[HOOK] digite uma palavra"); return end
        local nT, nF = 0, 0
        local ok = pcall(function()
            for _, o in ipairs(getgc(true)) do
                local t = typeof(o)
                if t == "table" then
                    for k, v in pairs(o) do
                        if tostring(k):lower():find(kw, 1, true) or tostring(v):lower():find(kw, 1, true) then
                            nT = nT + 1; log("   [gc-tbl] "..tostring(k).." = "..tostring(v)); break
                        end
                    end
                elseif t == "function" and typeof(debug) == "table" and typeof(debug.getconstants) == "function" then
                    local okc, cs = pcall(debug.getconstants, o)
                    if okc then for _, c in ipairs(cs) do
                        if type(c) == "string" and c:lower():find(kw, 1, true) then
                            nF = nF + 1
                            local src = "?"; pcall(function() src = tostring(debug.getinfo(o).short_src) end)
                            log("   [gc-fn] const '"..tostring(c).."' em "..src); break
                        end
                    end end
                end
                if nT + nF >= 40 then log("   (limite 40 -- refine)"); break end
            end
        end)
        log("[HOOK] getgc '"..kw.."': "..nT.." tabelas, "..nF.." funcoes"..(ok and "" or " (erro na varredura)"))
    end)

    -- 6) EXPORTAR LOG
    hsec("6) EXPORTAR LOG DO HOOK", Color3.fromRGB(140,220,255))
    local exLbl = hlbl("(clique copiar ou salvar depois dos testes)")
    hbtn("Copiar HOOK log (clipboard)", Color3.fromRGB(40,120,150), function()
        if typeof(setclipboard) == "function" then
            pcall(setclipboard, table.concat(hookLines, "\n"))
            exLbl.Text = "copiado: "..#hookLines.." linhas -> cola no chat"
            log("[HOOK] "..#hookLines.." linhas copiadas")
        else exLbl.Text = "executor sem setclipboard -- use Salvar" end
    end)
    hbtn("Salvar hook_log.txt (workspace)", Color3.fromRGB(0,150,90), function()
        if typeof(writefile) ~= "function" then exLbl.Text = "sem writefile"; return end
        pcall(writefile, "hook_log.txt", table.concat(hookLines, "\n"))
        exLbl.Text = "salvo: workspace/hook_log.txt ("..#hookLines.." linhas)"
        log("[HOOK] salvo em hook_log.txt")
    end)
    hbtn("Limpar HOOK log", Color3.fromRGB(90,60,60), function()
        for i = #hookLines, 1, -1 do hookLines[i] = nil end
        exLbl.Text = "log limpo"
    end)

    log("[HOOK] HOOKS LAB aberto. Comece por 'Escanear funcoes'.")
    scan()
end

section("FERRAMENTAS", Color3.fromRGB(255,120,120))
button("Abrir HOOKS LAB (scan + tamper + getgc)", Color3.fromRGB(90,200,240), openHooksLab)

-- ---- LOG ----
section("LOG", Color3.fromRGB(180,180,180))
button("Copiar LOG (clipboard)", Color3.fromRGB(60,60,90), function()
    if typeof(setclipboard) == "function" then pcall(setclipboard, table.concat(logLines,"\n")); log("log copiado") else log("[!] sem setclipboard") end
end)
logLbl = new("TextLabel", body, { Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundColor3=Color3.fromRGB(14,14,18),
    BorderSizePixel=0, TextColor3=Color3.fromRGB(180,255,180), Font=Enum.Font.Code, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true, Text="", LayoutOrder=nextOrder() })

-- ======================= minimizar / fechar =======================
local minimized = false
local savedH = frame.Size.Y.Offset
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, minimized and TITLE_H or savedH)
    minBtn.Text = minimized and "▢" or "—"
end)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

log("Events Lab pronto (foco Pet/Mega/Tree). SPY p/ pegar EggKey/Uid; HOOKS LAB p/ tamper/getgc.")
