--[[
========================================================================
 EVENTS LAB (hub separado / client) -- so testes no CLIENT
 Janela propria (fecha X / minimiza -). Testa o sistema de eventos +
 EDITOR DE SCRIPTS do client (lista clicavel, extrair/editar/aplicar).
========================================================================
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer
local playerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- ---------- acha remotes/config ----------
local function findRemote(name)
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    local r = rem and rem:FindFirstChild(name)
    if r then return r end
    return ReplicatedStorage:FindFirstChild(name, true)
end
local EventShopAction     = findRemote("EventShopAction")
local EventShopUpdate     = findRemote("EventShopUpdate")
local SelectInventoryItem = findRemote("SelectInventoryItem")

local function findEventConfig()
    local es = ReplicatedStorage:FindFirstChild("EventSystem") or ReplicatedStorage:FindFirstChild("EventSystem", true)
    local mod = es and es:FindFirstChild("EventConfig")
    if not mod then mod = ReplicatedStorage:FindFirstChild("EventConfig", true) end
    if not mod then return nil end
    local ok, cfg = pcall(require, mod)
    return ok and cfg or nil
end
local EventConfig = findEventConfig()

-- ---------- estado ----------
local AUTO_PRIME = true
local latest = {}
if EventShopUpdate then
    EventShopUpdate.OnClientEvent:Connect(function(p) if type(p)=="table" then latest = p end end)
end

local logLines = {}
local logLbl
local function log(msg)
    print("[EVENTS-LAB] " .. msg)
    table.insert(logLines, os.date("%H:%M:%S") .. " " .. msg)
    if #logLines > 80 then table.remove(logLines, 1) end
    if logLbl then logLbl.Text = table.concat(logLines, "\n") end
end

local function prime()
    if not AUTO_PRIME then return end
    pcall(function() LocalPlayer:SetAttribute("EventShopMenuOpen", true) end)
    if SelectInventoryItem then pcall(function() SelectInventoryItem:FireServer(0) end) end
    if EventShopAction then pcall(function() EventShopAction:FireServer("RequestState") end) end
end

local function activate(id)
    if not EventShopAction then log("[!] EventShopAction nao encontrado"); return end
    prime(); task.wait(0.1)
    pcall(function() EventShopAction:FireServer("Activate", id) end)
    log("Activate -> " .. tostring(id))
end
local function attemptSecond(id)
    if not EventShopAction then log("[!] EventShopAction nao encontrado"); return end
    pcall(function() EventShopAction:FireServer("AttemptSecondEvent", id) end)
    log("AttemptSecondEvent -> " .. tostring(id))
end
local function requestState()
    if not EventShopAction then log("[!] EventShopAction nao encontrado"); return end
    pcall(function() EventShopAction:FireServer("RequestState") end)
    log("RequestState enviado")
end

local function tenXEvents()
    if not EventConfig then return {} end
    local ok, all = pcall(EventConfig.GetAllEvents)
    if not ok or type(all) ~= "table" then return {} end
    local maxMult = 1
    for _, e in ipairs(all) do maxMult = math.max(maxMult, tonumber(e.CashMultiplier) or 1) end
    local list = {}
    for _, e in ipairs(all) do if (tonumber(e.CashMultiplier) or 1) == maxMult then table.insert(list, e) end end
    table.sort(list, function(a, b) return (tonumber(a.Cost) or 0) < (tonumber(b.Cost) or 0) end)
    return list, maxMult
end

-- helper generico de instancia
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

-- ======================= JANELA PRINCIPAL =======================
local existing = playerGui:FindFirstChild("EventsLabHub"); if existing then existing:Destroy() end
-- DisplayOrder alto: fica ACIMA do modal de Offline Earnings (DisplayOrder=10030),
-- que senao cobriria/esconderia o hub e impediria o clique.
local screenGui = new("ScreenGui", playerGui, { Name="EventsLabHub", ResetOnSpawn=false, DisplayOrder=10050, IgnoreGuiInset=true })
-- guard: o modal de Offline chama hideOtherGameUIs (Enabled=false em todas as ScreenGuis).
-- Isso re-habilita o hub na hora, mantendo ele clicavel durante a janela de coleta.
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

-- ---- STATUS ----
section("STATUS (ao vivo)", Color3.fromRGB(120,220,255))
local statusLbl = fullLabel("EventCoins: ? | Ativo: ? | Resta: ?", Color3.fromRGB(200,255,200))
fullLabel(("Remotes: Action=%s Update=%s | EventConfig=%s"):format(tostring(EventShopAction~=nil), tostring(EventShopUpdate~=nil), tostring(EventConfig~=nil)),
    (EventShopAction and EventConfig) and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))
button("RequestState (atualizar estado)", Color3.fromRGB(60,60,90), requestState)

local primeBtn
primeBtn = button("Auto-prime: LIGADO", Color3.fromRGB(0,110,60), function()
    AUTO_PRIME = not AUTO_PRIME
    primeBtn.Text = "Auto-prime: " .. (AUTO_PRIME and "LIGADO" or "DESLIGADO")
    primeBtn.BackgroundColor3 = AUTO_PRIME and Color3.fromRGB(0,110,60) or Color3.fromRGB(80,60,60)
end)

-- ---- acoes rapidas ----
section("ACOES RAPIDAS", Color3.fromRGB(255,180,90))
local tenx, maxMult = tenXEvents()
button(("Ativar 10x mais barato (%s)"):format(tenx[1] and tenx[1].Id or "?"), Color3.fromRGB(150,90,240), function()
    if tenx[1] then activate(tenx[1].Id) else log("[!] nenhum evento "..tostring(maxMult).."x") end
end)
button("Tentar 2o evento com o 10x mais barato", Color3.fromRGB(120,70,200), function()
    if tenx[1] then attemptSecond(tenx[1].Id) else log("[!] sem evento pra 2o") end
end)

-- ---- manual ----
section("MANUAL (Event Id)", Color3.fromRGB(255,180,90))
local idBox = textField("ex: KING_MILLIONAIRE")
button("Activate este Id", Color3.fromRGB(0,150,90), function()
    local id = idBox.Text:gsub("%s+",""); if id ~= "" then activate(id) else log("[!] digite um Id") end
end)
button("AttemptSecondEvent este Id", Color3.fromRGB(0,120,150), function()
    local id = idBox.Text:gsub("%s+",""); if id ~= "" then attemptSecond(id) else log("[!] digite um Id") end
end)

-- ---- lista 10x ----
section(("EVENTOS %sx (clique pra ativar)"):format(tostring(maxMult or 10)), Color3.fromRGB(255,120,120))
if #tenx == 0 then
    fullLabel("(EventConfig nao carregou -- abra a loja de eventos 1x)", Color3.fromRGB(255,150,150))
else
    for _, e in ipairs(tenx) do
        button(("%s | custo %s"):format(tostring(e.Id), tostring(e.Cost)), Color3.fromRGB(70,50,110), function() activate(e.Id) end)
    end
end

-- ---- teste atributo ----
section("TESTE ATRIBUTO CLIENT (so HUD/local)", Color3.fromRGB(255,120,120))
button("Forcar ActiveEventCashMultiplier = 10 (local)", Color3.fromRGB(120,60,60), function()
    pcall(function() LocalPlayer:SetAttribute("ActiveEventCashMultiplier", 10) end)
    log("Atributo local=10 -- veja se a renda MUDA (se mudar = vuln)")
end)
button("Resetar atributo = 1", Color3.fromRGB(70,70,80), function()
    pcall(function() LocalPlayer:SetAttribute("ActiveEventCashMultiplier", 1) end)
    log("Atributo local=1")
end)

-- ======================= TESTES DE VETORES (anti-cheat) =======================
-- Em SALA PRIVADA: clique cada teste e observe. Se o servidor CONCEDER (moeda
-- sobe, upgrade acontece, minigame completa) = brecha aberta. Se IGNORAR = OK.
local AdminAbuseRemote  = ReplicatedStorage:FindFirstChild("AdminAbuseRemote", true)
local ManageSlimeAction = findRemote("ManageSlimeAction")
local OfflineEarnings   = findRemote("OfflineEarnings")
local MiniParkourEvent  = findRemote("MiniParkourEvent")
local MiniGameEvent     = findRemote("MiniGame1MemoryEvent")
local GiftAction        = findRemote("GiftAction")
local PassPurchase      = findRemote("PassPurchaseRequest")
local SellSlimeAction   = findRemote("SellSlimeAction")
local TreeShopAction    = (function()
    local ts  = ReplicatedStorage:FindFirstChild("TreeSystem")
    local rem = ts and ts:FindFirstChild("Remotes")
    return (rem and rem:FindFirstChild("ShopAction")) or ReplicatedStorage:FindFirstChild("ShopAction", true)
end)()

-- dispara remote:FireServer(...) com pcall + log (preserva nils no meio)
local function fire(remote, rname, ...)
    if not remote then log("[!] remote ausente: " .. tostring(rname)); return false end
    local a = table.pack(...)
    local ok, err = pcall(function() remote:FireServer(table.unpack(a, 1, a.n)) end)
    if ok then log("-> " .. tostring(rname) .. " enviado")
    else log("[!] " .. tostring(rname) .. " falhou: " .. tostring(err)) end
    return ok
end

-- captura o ServerToken que o servidor emite pelo remote do minigame
local capturedToken = nil
if MiniGameEvent then
    pcall(function()
        MiniGameEvent.OnClientEvent:Connect(function(...)
            local a = table.pack(...)
            for i = 1, a.n do
                local v = a[i]
                if type(v) == "string" and #v >= 16 and v:find("%-") and v ~= "HitTheSlime" and v ~= "Memory" then
                    capturedToken = v
                elseif type(v) == "table" then
                    local t = v.ServerToken or v.Token or v.token
                    if type(t) == "string" then capturedToken = t end
                end
            end
        end)
    end)
end

section("TESTES DE VETORES -- SALA PRIVADA", Color3.fromRGB(255,80,80))
fullLabel("Concedeu = BRECHA. Ignorou = OK. Veja STATUS/renda/minigame.", Color3.fromRGB(255,200,120))
fullLabel(("Admin=%s Manage=%s Offline=%s Parkour=%s MiniGame=%s Tree=%s"):format(
    tostring(AdminAbuseRemote~=nil), tostring(ManageSlimeAction~=nil), tostring(OfflineEarnings~=nil),
    tostring(MiniParkourEvent~=nil), tostring(MiniGameEvent~=nil), tostring(TreeShopAction~=nil)),
    Color3.fromRGB(180,220,255))

-- [CRITICO] AdminAbuse -- deve exigir admin no servidor
section("[CRITICO] AdminAbuse (deve exigir admin)", Color3.fromRGB(255,90,90))
button("GiveEventCoins +1.000.000 (veja STATUS)", Color3.fromRGB(150,40,40), function()
    fire(AdminAbuseRemote, "Admin:GiveEventCoins", "GiveEventCoins", {Amount=1000000})
    log("   observe EventCoins no STATUS: subiu = NAO checa admin")
    if AdminAbuseRemote then pcall(function() AdminAbuseRemote:FireServer("RequestState") end) end
end)
button("StartManual (Scope=SERVER)", Color3.fromRGB(130,50,50), function()
    fire(AdminAbuseRemote, "Admin:StartManual", "StartManual", {Scope="SERVER"})
end)
button("AnnouncementPreset HELLO (spam p/ sala)", Color3.fromRGB(130,50,50), function()
    fire(AdminAbuseRemote, "Admin:Announcement", "AnnouncementPreset", {Preset="HELLO"})
end)
button("Stop", Color3.fromRGB(90,60,60), function()
    fire(AdminAbuseRemote, "Admin:Stop", "Stop")
end)
button("SetBoxCount 99 (args chute)", Color3.fromRGB(130,50,50), function()
    fire(AdminAbuseRemote, "Admin:SetBoxCount", "SetBoxCount", {BoxCount=99})
end)
fullLabel("v GLOBAL afeta TODOS os servidores (jogadores reais). Use ciente.", Color3.fromRGB(255,160,110))
button("StartManual (Scope=GLOBAL) !!", Color3.fromRGB(175,25,25), function()
    fire(AdminAbuseRemote, "Admin:StartManual/GLOBAL", "StartManual", {Scope="GLOBAL"})
end)
button("StartAuto (Scope=GLOBAL) !!", Color3.fromRGB(175,25,25), function()
    fire(AdminAbuseRemote, "Admin:StartAuto/GLOBAL", "StartAuto", {Scope="GLOBAL"})
end)

-- [CRITICO] concessoes por Robux sem pagar -- so ProcessReceipt pode conceder
section("[CRITICO] Robux SEM pagar (so ProcessReceipt)", Color3.fromRGB(255,90,90))
button("RobuxUpgrade (sem prompt)", Color3.fromRGB(150,40,40), function()
    fire(ManageSlimeAction, "RobuxUpgrade", "RobuxUpgrade")
    log("   aconteceu sem prompt de Robux = GRATIS")
end)
button("RobuxUpgrade100 (sem prompt)", Color3.fromRGB(150,40,40), function()
    fire(ManageSlimeAction, "RobuxUpgrade100", "RobuxUpgrade100")
end)
button("RobuxStar (sem prompt)", Color3.fromRGB(150,40,40), function()
    fire(ManageSlimeAction, "RobuxStar", "RobuxStar")
end)
button("OfflineEarnings ClaimX10 (sem pagar R$50)", Color3.fromRGB(150,40,40), function()
    fire(OfflineEarnings, "ClaimX10", "ClaimX10")
    log("   creditou x10 sem compra = GRATIS")
end)
button("Diagnostico VIP: HasVIPPass?", Color3.fromRGB(90,60,60), function()
    log("   HasVIPPass = "..tostring(LocalPlayer:GetAttribute("HasVIPPass")))
    log("   se ja for true, o 'VIP ACTIVATED' foi so confirmacao (NAO brecha)")
end)
button("PassPurchaseRequest VIP (sem ter o passe)", Color3.fromRGB(130,50,50), function()
    local had = LocalPlayer:GetAttribute("HasVIPPass")
    fire(PassPurchase, "Pass:VIP", "VIP")
    log("   HasVIPPass antes="..tostring(had).." -- se era false e virar true = VIP GRATIS")
end)
button("PassPurchaseRequest VIP_CASH (sem 1e17 cash?)", Color3.fromRGB(150,40,40), function()
    fire(PassPurchase, "Pass:VIP_CASH", "VIP_CASH")
    log("   ativou VIP sem ter 1e17 de cash = brecha (servidor nao re-checa saldo)")
end)

-- [ALTO] offline replay/valor
section("[ALTO] Offline earnings (replay)", Color3.fromRGB(255,140,90))
button("ClaimNormal x3 (replay)", Color3.fromRGB(150,80,40), function()
    for i=1,3 do fire(OfflineEarnings, "ClaimNormal#"..i, "ClaimNormal"); task.wait(0.15) end
    log("   creditou mais de 1x = replay aberto")
end)

-- [ALTO] minigames token/skip
-- Checks do servidor ja confirmados: token unico, monotonic, LIMITE de pairs(9),
-- exige progresso E tempo minimo ("Too fast"). Memory ~15s, HitTheSlime ~3min.
-- StartRound exige proximidade. => teste "paciente": espera o tempo minimo.
section("[ALTO] Minigames (token/skip)", Color3.fromRGB(255,140,90))
local MINTIME = { Memory = 16, HitTheSlime = 185 }   -- segundos (folga p/ passar do "Too fast")
local function startAndGetToken(gameName, timeout)
    capturedToken = nil
    if not fire(MiniGameEvent, gameName..":StartRound", "StartRound", gameName) then return nil end
    local t0 = os.clock()
    while not capturedToken and os.clock()-t0 < (timeout or 3) do task.wait(0.05) end
    return capturedToken
end
-- campo de progress MAXIMO por rodada (default 9). Se >9, manda 1 Progress EXTRA com
-- esse valor ANTES do WinRound -- MAS agora respeitando o tempo minimo (o 99999
-- anterior foi instantaneo; aqui isola se o "INVALID" e limite ou pressa).
local progBox = textField("progress max por rodada (default 9)")
progBox.Text = "9"
-- roda 1 auto-complete completo (BLOQUEANTE): pace 1..9 no tempo minimo; se progBox>9,
-- envia 1 Progress EXTRA = progBox antes do WinRound. Completou/pagou = brecha.
local function runAutoComplete(gameName)
    local tok = startAndGetToken(gameName)
    if not tok then log("[!] "..gameName..": sem token (fique PERTO do minigame)"); return false end
    local dur = MINTIME[gameName] or 16
    local maxProg = math.max(1, math.floor(tonumber(progBox.Text) or 9))
    local baseSteps = math.min(maxProg, 9)
    log(("%s: token %s -> ~%ds, progress ate %d"):format(gameName, tok, dur, maxProg))
    for i=1,baseSteps do
        task.wait(dur/baseSteps)
        if gameName == "Memory" then fire(MiniGameEvent, "Memory:Progress "..i, "Progress", "Memory", tok, i)
        else fire(MiniGameEvent, "Hit:Progress "..i, "Progress", "HitTheSlime", tok, i, i) end
    end
    if maxProg > 9 then
        if gameName == "Memory" then fire(MiniGameEvent, "Memory:Progress EXTRA "..maxProg, "Progress", "Memory", tok, maxProg)
        else fire(MiniGameEvent, "Hit:Progress EXTRA "..maxProg, "Progress", "HitTheSlime", tok, maxProg, maxProg) end
        log("   Progress EXTRA = "..maxProg.." (alem de 9) COM timing valido")
    end
    fire(MiniGameEvent, gameName..":WinRound(REAL)", "WinRound", gameName, tok)
    log("   "..gameName..": WinRound apos ~"..dur.."s (max progress "..maxProg..") -> veja recompensa")
    return true
end
local function timedAutoComplete(gameName) task.spawn(runAutoComplete, gameName) end
button("AUTO-COMPLETE Memory (~15s, usa 'progress max')", Color3.fromRGB(170,60,40), function()
    timedAutoComplete("Memory")
end)
button("AUTO-COMPLETE HitTheSlime (~3min, background)", Color3.fromRGB(170,60,40), function()
    timedAutoComplete("HitTheSlime")
    log("   Hit roda ~3min em background; args de Progress por nivel sao chute")
end)
-- LOOP: repete o auto-complete do Memory ate desligar (mede a taxa de farm)
local loopOn = false
local loopBtn
loopBtn = button("LOOP AUTO Memory: OFF (repete p/ farmar)", Color3.fromRGB(120,70,50), function()
    loopOn = not loopOn
    loopBtn.Text = "LOOP AUTO Memory: " .. (loopOn and "ON (clique p/ PARAR)" or "OFF (repete p/ farmar)")
    loopBtn.BackgroundColor3 = loopOn and Color3.fromRGB(190,45,40) or Color3.fromRGB(120,70,50)
    if not loopOn then return end
    task.spawn(function()
        local n = 0
        while loopOn do
            local ok = runAutoComplete("Memory")
            if ok then n = n + 1; log("   >>> LOOP Memory: rodada #"..n.." completa") else task.wait(1) end
            task.wait(0.4)
        end
        log("LOOP Memory PARADO apos "..n.." rodadas")
    end)
end)
fullLabel("v Abaixo = CONTROLES (devem ser recusados = servidor OK)", Color3.fromRGB(180,220,255))
button("INSTANT Memory (sem esperar) -> deve dar 'Too fast'", Color3.fromRGB(120,70,50), function()
    local tok = startAndGetToken("Memory")
    if not tok then log("[!] sem token (proximidade?)"); return end
    for i=1,9 do fire(MiniGameEvent, "Memory:Progress "..i, "Progress", "Memory", tok, i); task.wait(0.05) end
    fire(MiniGameEvent, "Memory:WinRound(REAL)", "WinRound", "Memory", tok)
    log("   esperado: 'Too fast' (tempo minimo)")
end)
button("Progress 99999 -> deve dar 'INVALID PROGRESS'", Color3.fromRGB(120,70,50), function()
    local tok = startAndGetToken("Memory")
    if not tok then log("[!] sem token (proximidade?)"); return end
    fire(MiniGameEvent, "Memory:Progress(99999)", "Progress", "Memory", tok, 99999)
    log("   esperado: 'INVALID MEMORY PROGRESS' (limite validado)")
end)
button("WinRound sem progress -> 'progress not verified'", Color3.fromRGB(120,70,50), function()
    local tok = startAndGetToken("Memory")
    if not tok then log("[!] sem token (proximidade?)"); return end
    fire(MiniGameEvent, "Memory:WinRound(noprog)", "WinRound", "Memory", tok)
    log("   esperado: 'Round progress not verified'")
end)
button("WinRound token FALSO -> 'Round not active'", Color3.fromRGB(120,70,50), function()
    fire(MiniGameEvent, "Memory:WinRound(FALSO)", "WinRound", "Memory", "FAKE-TOKEN-0000-0000")
    log("   esperado: 'Round not active' (token validado)")
end)

-- [ALTO] parkour checkpoints/skip
section("[ALTO] Parkour (checkpoints/skip)", Color3.fromRGB(255,140,90))
button("StartParkourLevel (Normal/Test)", Color3.fromRGB(60,90,150), function()
    fire(MiniParkourEvent, "Parkour:Start", "StartParkourLevel", {Mode="Normal", MapName="Test"})
end)
button("CheckpointTouched 1..40 (spam instantaneo)", Color3.fromRGB(150,80,40), function()
    if not MiniParkourEvent then log("[!] MiniParkourEvent ausente"); return end
    for i=1,40 do pcall(function() MiniParkourEvent:FireServer("CheckpointTouched", i) end) end
    log("Parkour: 40 checkpoints instantaneos -> terminou sem correr = SKIP aberto")
end)
button("SubmitParkourPin 0000", Color3.fromRGB(130,80,50), function()
    fire(MiniParkourEvent, "Parkour:Pin", "SubmitParkourPin", "0000")
end)

-- [MEDIO] economia saldo/replay
section("[MEDIO] Economia (saldo/replay)", Color3.fromRGB(255,190,90))
button("BuyStar (checa saldo?)", Color3.fromRGB(120,90,40), function()
    fire(ManageSlimeAction, "BuyStar", "BuyStar")
end)
button("Upgrade (checa saldo?)", Color3.fromRGB(120,90,40), function()
    fire(ManageSlimeAction, "Upgrade", "Upgrade")
end)
button("Upgrade10 (checa saldo?)", Color3.fromRGB(120,90,40), function()
    fire(ManageSlimeAction, "Upgrade10", "Upgrade10")
end)
button("Upgrade100 (checa saldo?)", Color3.fromRGB(120,90,40), function()
    fire(ManageSlimeAction, "Upgrade100", "Upgrade100")
end)
button("Collect x5 (replay/cooldown?)", Color3.fromRGB(120,90,40), function()
    for i=1,5 do fire(ManageSlimeAction, "Collect#"..i, "Collect"); task.wait(0.1) end
end)
button("SellSlimeAction SellAll", Color3.fromRGB(120,90,40), function()
    fire(SellSlimeAction, "SellAll", "SellAll")
end)
button("Tree Buy commonTree (slot 1) -- seed valido", Color3.fromRGB(120,90,40), function()
    fire(TreeShopAction, "Tree:Buy commonTree", "Buy", 1, "commonTree")
    log("   Buy(slotIndex=1, 'commonTree'); seeds: commonTree..DivineTree")
end)
button("Tree Buy DivineTree slot 1 (checa saldo?)", Color3.fromRGB(120,90,40), function()
    fire(TreeShopAction, "Tree:Buy DivineTree", "Buy", 1, "DivineTree")
    log("   comprou a semente mais cara sem saldo = brecha")
end)

-- [ALTO] caixas / gacha (OpenBoxClick nao tem args -> servidor rola o slime)
section("[ALTO] Caixas / Gacha (box)", Color3.fromRGB(255,140,90))
local OpenBoxClick = findRemote("OpenBoxClick")
local RetryRun     = findRemote("RetryRun")
button("OpenBoxClick x10 (abre caixa sem ganhar?)", Color3.fromRGB(150,80,40), function()
    if not OpenBoxClick then log("[!] OpenBoxClick ausente"); return end
    for i=1,10 do fire(OpenBoxClick, "OpenBox#"..i); task.wait(0.25) end
    log("   ganhou slimes sem correr a rampa = GACHA aberto; 'no box'/nada = protegido")
end)
button("RetryRun x5 (repete run sem correr?)", Color3.fromRGB(150,80,40), function()
    if not RetryRun then log("[!] RetryRun ausente"); return end
    for i=1,5 do fire(RetryRun, "RetryRun#"..i); task.wait(0.25) end
    log("   deu caixa/premio sem correr = brecha")
end)

-- [MEDIO] gifts dup/target
-- Alvo do RequestGift = UserId (numero). Passar o objeto Player da "Player not found"
-- (o servidor faz tonumber(alvo)). Segure um slime no inventario ANTES de testar.
section("[MEDIO] Gifts (dup/target)", Color3.fromRGB(255,190,90))
local function firstOther()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then return p end
    end
    return nil
end
fullLabel("Gift: SEGURE um slime no inventario ANTES de clicar.", Color3.fromRGB(220,200,120))
button("RequestGift OUTRO por UserId (numero)", Color3.fromRGB(120,90,40), function()
    local p = firstOther(); if not p then log("[!] sem outro jogador na sala"); return end
    fire(GiftAction, "Gift->"..p.Name.."(uid)", "RequestGift", p.UserId)
    log("   'Player not found' = servidor NAO aceita UserId; senao formato OK")
end)
button("RequestGift OUTRO por Player (instancia)", Color3.fromRGB(120,90,40), function()
    local p = firstOther(); if not p then log("[!] sem outro jogador na sala"); return end
    fire(GiftAction, "Gift->"..p.Name.."(inst)", "RequestGift", p)
    log("   compare com o de UserId pra saber o formato aceito")
end)
button("RequestGift MIM por UserId (self dup)", Color3.fromRGB(150,80,40), function()
    fire(GiftAction, "Gift:self(uid)", "RequestGift", LocalPlayer.UserId)
    log("   completou = self-DUP aberto; 'Player not found' = self bloqueado")
end)
button("RequestGift MIM por Player (o que falhou)", Color3.fromRGB(120,90,40), function()
    fire(GiftAction, "Gift:self(inst)", "RequestGift", LocalPlayer)
    log("   este foi o que deu 'Player not found'")
end)
button("RequestGift MIM por Nome (string)", Color3.fromRGB(120,90,40), function()
    fire(GiftAction, "Gift:self(name)", "RequestGift", LocalPlayer.Name)
    log("   tenta alvo = Name (string)")
end)
button("RequestGift MIM por {UserId=..} (tabela)", Color3.fromRGB(120,90,40), function()
    fire(GiftAction, "Gift:self(tbl)", "RequestGift", {UserId = LocalPlayer.UserId})
    log("   tenta alvo = tabela {UserId}")
end)
fullLabel("Se TODOS os 'MIM' derem 'Player not found' = self travado no servidor (target==voce). So dup com 2 contas.", Color3.fromRGB(255,180,120))

-- OUTRA VIA: o alvo do gift vem do ProximityPrompt "GiftSlimePrompt" (atributo
-- TargetUserId). O servidor so registra o alvo quando voce TRIGGERA esse prompt --
-- por isso RequestGift sozinho da "Player not found". A UI esconde o SEU prompt, mas
-- fireproximityprompt forca o trigger direto. Segure um slime ANTES.
fullLabel("v OUTRA VIA: dispara o GiftSlimePrompt (fireproximityprompt)", Color3.fromRGB(120,220,255))
local function findGiftPrompt(char)
    if not char then return nil end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "GiftSlimePrompt" then return d end
    end
    return nil
end
button("Listar GiftSlimePrompts (TargetUserId/dono)", Color3.fromRGB(60,90,150), function()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "GiftSlimePrompt" then
            n = n + 1
            local owner = d.Parent and d.Parent.Parent
            log(("   #%d TargetUserId=%s Enabled=%s dono=%s"):format(n,
                tostring(d:GetAttribute("TargetUserId")), tostring(d.Enabled), tostring(owner and owner.Name)))
        end
    end
    if n == 0 then log("   nenhum GiftSlimePrompt no workspace") end
end)
-- confirmacao REAL: o servidor so manda GiftOpenInventory se aceitar o trigger.
local GiftOpenInventory = findRemote("GiftOpenInventory")
local giftOpenedAt = 0
if GiftOpenInventory then
    GiftOpenInventory.OnClientEvent:Connect(function()
        giftOpenedAt = os.clock()
        log("[GIFT] <<< servidor ABRIU o fluxo de presente (trigger ACEITO)")
    end)
end
-- fluxo completo: habilita+dispara o prompt, espera o GiftOpenInventory, dai RequestGift
local function giftViaPrompt(prompt, who)
    if typeof(fireproximityprompt) ~= "function" then log("[!] executor sem fireproximityprompt"); return end
    if not prompt then log("[!] sem GiftSlimePrompt ("..who..") -- esta perto?"); return end
    pcall(function() prompt.Enabled = true end)
    local target = tonumber(prompt:GetAttribute("TargetUserId"))
    giftOpenedAt = 0
    pcall(fireproximityprompt, prompt)
    log(("   [%s] prompt disparado (TargetUserId=%s), aguardando servidor..."):format(who, tostring(target)))
    task.wait(0.8)
    if giftOpenedAt > 0 then
        log(("   [%s] trigger ACEITO -> enviando RequestGift(%s)"):format(who, tostring(target)))
        fire(GiftAction, "Gift:"..who.."(viaPrompt)", "RequestGift", target)
        log("   completou/pagou = presente foi (self=DUP); erro de slime = segure um slime e repita")
    else
        log(("   [%s] servidor NAO abriu -> trigger bloqueado (defesa OK p/ esse alvo)"):format(who))
    end
end
button("SELF via prompt + RequestGift (COMPLETO)", Color3.fromRGB(150,80,40), function()
    giftViaPrompt(findGiftPrompt(LocalPlayer.Character), "self")
end)
button("OUTRO via prompt + RequestGift (COMPLETO)", Color3.fromRGB(150,80,40), function()
    local p = firstOther(); if not p then log("[!] sem outro jogador na sala"); return end
    giftViaPrompt(findGiftPrompt(p.Character), p.Name)
end)

button("AcceptGift", Color3.fromRGB(120,90,40), function()
    fire(GiftAction, "Gift:Accept", "AcceptGift")
end)
button("DeclineGift", Color3.fromRGB(120,90,40), function()
    fire(GiftAction, "Gift:Decline", "DeclineGift")
end)

-- ======================= EDITOR DE SCRIPTS (overlay) =======================
local function openScriptEditor()
    local sg = playerGui:FindFirstChild("ScriptEditorGui"); if sg then sg:Destroy() end
    sg = new("ScreenGui", playerGui, { Name="ScriptEditorGui", ResetOnSpawn=false, DisplayOrder=10060, IgnoreGuiInset=true })
    sg:GetPropertyChangedSignal("Enabled"):Connect(function() if not sg.Enabled then sg.Enabled = true end end)

    local W, H, TH = 720, 520, 28
    local RX = 266
    local RW = W - RX - 8
    local bw = (RW - 12) / 3

    local fr = new("Frame", sg, { Size=UDim2.new(0,W,0,H), Position=UDim2.new(0.5,-W/2,0.5,-H/2),
        BackgroundColor3=Color3.fromRGB(20,20,26), BorderSizePixel=0, Active=true, Draggable=true, ClipsDescendants=true })
    new("UIStroke", fr, { Color=Color3.fromRGB(150,90,240), Thickness=1, Transparency=0.3 })
    local tb = new("Frame", fr, { Size=UDim2.new(1,0,0,TH), BackgroundColor3=Color3.fromRGB(34,30,46), BorderSizePixel=0 })
    new("TextLabel", tb, { Size=UDim2.new(1,-34,1,0), Position=UDim2.new(0,12,0,0), BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(200,160,255), Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Text="EDITOR DE SCRIPTS (client)" })
    local xb = new("TextButton", tb, { Size=UDim2.new(0,32,1,0), Position=UDim2.new(1,-32,0,0),
        BackgroundColor3=Color3.fromRGB(150,45,45), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=14, Text="X" })
    xb.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- esquerda: busca + reescanear + lista
    local search = new("TextBox", fr, { Size=UDim2.new(0,250,0,26), Position=UDim2.new(0,8,0,TH+8),
        BackgroundColor3=Color3.fromRGB(48,48,56), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.Gotham, TextSize=12,
        PlaceholderText="filtrar por nome...", Text="", ClearTextOnFocus=false })
    local rescan = new("TextButton", fr, { Size=UDim2.new(0,250,0,24), Position=UDim2.new(0,8,0,TH+38),
        BackgroundColor3=Color3.fromRGB(60,60,90), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=12, Text="Reescanear" })
    local listScroll = new("ScrollingFrame", fr, { Size=UDim2.new(0,250,0,H-(TH+70)), Position=UDim2.new(0,8,0,TH+66),
        BackgroundColor3=Color3.fromRGB(14,14,18), BackgroundTransparency=0.2, BorderSizePixel=0, ScrollBarThickness=5,
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y })
    new("UIListLayout", listScroll, { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2) })

    -- direita: caminho + editor + arquivo + botoes
    local pathLbl = new("TextLabel", fr, { Size=UDim2.new(0,RW,0,20), Position=UDim2.new(0,RX,0,TH+8),
        BackgroundColor3=Color3.fromRGB(40,40,48), BorderSizePixel=0, TextColor3=Color3.fromRGB(200,255,200), Font=Enum.Font.Code, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, Text="(escaneando...)" })
    local edScroll = new("ScrollingFrame", fr, { Size=UDim2.new(0,RW,0,320), Position=UDim2.new(0,RX,0,TH+32),
        BackgroundColor3=Color3.fromRGB(12,12,16), BorderSizePixel=0, ScrollBarThickness=6, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y })
    local editor = new("TextBox", edScroll, { Size=UDim2.new(1,-8,0,0), Position=UDim2.new(0,4,0,4), BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(220,255,220), Font=Enum.Font.Code, TextSize=12, MultiLine=true, ClearTextOnFocus=false, TextWrapped=true,
        TextEditable=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, AutomaticSize=Enum.AutomaticSize.Y, Text="" })
    local fileB = new("TextBox", fr, { Size=UDim2.new(0,RW,0,24), Position=UDim2.new(0,RX,0,TH+356),
        BackgroundColor3=Color3.fromRGB(48,48,56), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.Gotham, TextSize=12,
        PlaceholderText="arquivo (workspace do executor)", Text="override.lua", ClearTextOnFocus=false })

    local selected, lastRow = nil, nil

    local function refreshList()
        for _, c in ipairs(listScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        lastRow = nil
        local filter = search.Text:lower()
        local roots = {}
        local ps = LocalPlayer:FindFirstChild("PlayerScripts"); if ps then table.insert(roots, ps) end
        table.insert(roots, playerGui); table.insert(roots, ReplicatedStorage); table.insert(roots, game:GetService("ReplicatedFirst"))
        local char = LocalPlayer.Character; if char then table.insert(roots, char) end
        local n = 0
        for _, root in ipairs(roots) do
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Script") then
                    if filter == "" or d.Name:lower():find(filter, 1, true) then
                        n = n + 1
                        local inst = d
                        local rowBtn = new("TextButton", listScroll, { Size=UDim2.new(1,-4,0,22), BackgroundColor3=Color3.fromRGB(30,30,38),
                            BorderSizePixel=0, TextColor3=Color3.fromRGB(220,220,220), Font=Enum.Font.Gotham, TextSize=11,
                            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, Text=" "..d.Name.." ("..d.ClassName..")", LayoutOrder=n })
                        rowBtn.MouseButton1Click:Connect(function()
                            if lastRow then lastRow.BackgroundColor3 = Color3.fromRGB(30,30,38) end
                            rowBtn.BackgroundColor3 = Color3.fromRGB(70,50,110); lastRow = rowBtn
                            selected = inst
                            pathLbl.Text = inst:GetFullName()
                        end)
                    end
                end
            end
        end
        pathLbl.Text = "achou " .. n .. " scripts -- clique um na lista"
    end

    local function doExtract()
        if not selected then log("[!] selecione um script"); return end
        if typeof(decompile) ~= "function" then editor.Text = "-- executor sem decompile()"; log("[!] sem decompile"); return end
        local ok, src = pcall(decompile, selected)
        if ok and type(src) == "string" and src ~= "" then editor.Text = src; log("extraido: " .. selected:GetFullName())
        else editor.Text = "-- falha ao decompilar (script protegido?)"; log("[!] decompile falhou") end
    end
    local function doApply()
        if not selected then log("[!] selecione um script"); return end
        if typeof(loadstring) ~= "function" then log("[!] sem loadstring"); return end
        local path = selected:GetFullName()
        local code = editor.Text
        killScript(selected)
        local fn, err = loadstring(code, "@edit:" .. path)
        if not fn then log("[!] sintaxe: " .. tostring(err)); return end
        task.spawn(function()
            local ok, rerr = pcall(fn)
            log(ok and ("aplicado: " .. path) or ("[!] rodou com erro: " .. tostring(rerr)))
        end)
        selected, lastRow = nil, nil
    end
    local function doCopy()
        if typeof(setclipboard) == "function" then pcall(setclipboard, editor.Text); log("editor copiado pro clipboard") else log("[!] sem setclipboard") end
    end
    local function doSave()
        if typeof(writefile) ~= "function" then log("[!] sem writefile"); return end
        local f = fileB.Text:gsub("%s+",""); if f == "" then log("[!] nome de arquivo vazio"); return end
        pcall(writefile, f, editor.Text); log("salvo: workspace/" .. f)
    end
    local function doLoad()
        if typeof(readfile) ~= "function" then log("[!] sem readfile"); return end
        local f = fileB.Text:gsub("%s+",""); local ok, c = pcall(readfile, f)
        if ok and type(c) == "string" then editor.Text = c; log("carregado: " .. f) else log("[!] nao li " .. f) end
    end
    local function doDumpBytecode()
        if not selected then log("[!] selecione um script"); return end
        if typeof(getscriptbytecode) ~= "function" then log("[!] executor sem getscriptbytecode"); return end
        local ok, bc = pcall(getscriptbytecode, selected)
        if not ok or type(bc) ~= "string" or bc == "" then log("[!] getscriptbytecode falhou/vazio (script sem bytecode acessivel)"); return end
        if typeof(writefile) ~= "function" then log("[!] sem writefile"); return end
        local out = "bytecode_" .. selected.Name .. ".luac"
        pcall(writefile, out, bc)
        log(("bytecode salvo: workspace/%s (%d bytes) -> decompile externo v12"):format(out, #bc))
    end

    local function mkAction(label, col, x, y, cb)
        local b = new("TextButton", fr, { Size=UDim2.new(0,bw,0,26), Position=UDim2.new(0,RX+x,0,y), BackgroundColor3=col,
            BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=12, Text=label })
        b.MouseButton1Click:Connect(cb); return b
    end
    local r1, r2 = TH+384, TH+414
    mkAction("Extrair",  Color3.fromRGB(0,120,150),  0,          r1, doExtract)
    mkAction("Aplicar",  Color3.fromRGB(150,90,240), bw+6,       r1, doApply)
    mkAction("Copiar",   Color3.fromRGB(60,60,90),   2*(bw+6),   r1, doCopy)
    mkAction("Salvar",   Color3.fromRGB(0,150,90),   0,          r2, doSave)
    mkAction("Carregar", Color3.fromRGB(70,70,90),   bw+6,       r2, doLoad)
    mkAction("Matar",    Color3.fromRGB(120,60,60),  2*(bw+6),   r2, function()
        if selected then log("morto: " .. selected:GetFullName()); killScript(selected); selected, lastRow = nil, nil else log("[!] selecione") end
    end)
    local dbtn = new("TextButton", fr, { Size=UDim2.new(0,RW,0,26), Position=UDim2.new(0,RX,0,TH+444),
        BackgroundColor3=Color3.fromRGB(80,80,110), BorderSizePixel=0, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=12,
        Text="Dump bytecode (getscriptbytecode -> arquivo)" })
    dbtn.MouseButton1Click:Connect(doDumpBytecode)

    rescan.MouseButton1Click:Connect(refreshList)
    search.FocusLost:Connect(refreshList)
    refreshList()
end

section("EDITOR DE SCRIPTS DO CLIENT", Color3.fromRGB(255,120,120))
fullLabel("So afeta o CLIENT. Matar PlayerModule quebra o movimento.", Color3.fromRGB(220,200,120))
button("Abrir Editor (extrair/editar/aplicar)", Color3.fromRGB(150,90,240), openScriptEditor)

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

-- ======================= updater ao vivo =======================
task.spawn(function()
    while screenGui.Parent do
        local coins = tostring(latest.EventCoins or "?")
        local id    = tostring(latest.ActiveEventId or "")
        local ends  = tonumber(latest.ActiveEventEndsAt) or 0
        local rem   = ends > 0 and math.max(0, math.ceil(ends - os.time())) or 0
        statusLbl.Text = ("EventCoins: %s | Ativo: %s | Resta: %ds"):format(coins, id ~= "" and id or "nenhum", rem)
        task.wait(1)
    end
end)

if EventShopAction then requestState() end
log("Events Lab pronto. Editor de Scripts: botao 'Abrir Editor'.")
