-- ========================================
-- MEGA RAMP HUB - painel único com abas (Ramp / Games / Cam / Webhook /
-- Jogadores), responsivo (celular e PC), com botão de minimizar.
-- Junta megaramp_event_loop.lua + minigames_farm.lua + freecam.lua num só
-- script, mais notificação por Discord Webhook e spectate de jogadores.
-- ========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

print("=== MEGA RAMP HUB ===")

-- Guarda as últimas linhas de log num buffer global pra poder copiar tudo
-- pro clipboard de uma vez (setclipboard) -- sem isso, a única forma de
-- mandar o log era print no console + screenshot/print manual, o que
-- perde linhas quando o console rola rápido (ex: checkpoints disparando
-- em sequência). Limitado a 500 linhas mais recentes pra não crescer sem
-- fim numa sessão longa.
local HUB_LOG_BUFFER_MAX = 500
local hubLogBuffer = {}

local function addLog(msg)
    print("[HUB] " .. msg)
    table.insert(hubLogBuffer, os.date("%H:%M:%S") .. " " .. msg)
    if #hubLogBuffer > HUB_LOG_BUFFER_MAX then
        table.remove(hubLogBuffer, 1)
    end
end

local function copyHubLogToClipboard()
    if #hubLogBuffer == 0 then
        addLog("[LOG] [!] Nada pra copiar ainda")
        return
    end
    local fullText = table.concat(hubLogBuffer, "\n")
    if typeof(setclipboard) ~= "function" then
        addLog("[LOG] [!] Esse executor não suporta setclipboard -- copie manualmente do console")
        return
    end
    local ok = pcall(setclipboard, fullText)
    addLog(ok and ("[LOG] [✓] " .. #hubLogBuffer .. " linha(s) copiada(s) pro clipboard") or "[LOG] [!] Falha ao copiar pro clipboard")
end

-- ========================================
-- IDIOMA: só traduz nomes de abas e os botões/textos mais comuns
-- (Iniciar/Parar/Ativar/Desativar etc). Textos longos de explicação e as
-- mensagens de log continuam em português. Trocar o idioma na aba
-- Configurações só aplica de verdade na PRÓXIMA vez que o hub carregar
-- (rode o script de novo) -- os botões já criados não se retraduzem
-- sozinhos ao vivo.
-- ========================================

local Language = { current = "pt" }

local T = {
    tab_ramp = { pt = "Rampa", en = "Ramp", es = "Rampa" },
    tab_games = { pt = "Jogos", en = "Games", es = "Juegos" },
    tab_cam = { pt = "Camera", en = "Camera", es = "Camara" },
    tab_car = { pt = "Carro", en = "Car", es = "Auto" },
    tab_props = { pt = "Objetos", en = "Props", es = "Objetos" },
    tab_esp = { pt = "Jogadores", en = "Players", es = "Jugadores" },
    tab_anim = { pt = "Animacao", en = "Animation", es = "Animacion" },
    tab_players = { pt = "Espectar", en = "Spectate", es = "Espectar" },
    tab_slimes = { pt = "Inventario", en = "Inventory", es = "Inventario" },
    tab_settings = { pt = "Configuracoes", en = "Settings", es = "Ajustes" },
    tab_spy = { pt = "Remote Spy", en = "Remote Spy", es = "Remote Spy" },

    start = { pt = "Iniciar", en = "Start", es = "Iniciar" },
    stop = { pt = "Parar", en = "Stop", es = "Detener" },
    enable = { pt = "Ativar", en = "Enable", es = "Activar" },
    disable = { pt = "Desativar", en = "Disable", es = "Desactivar" },
    play = { pt = "Jogar", en = "Play", es = "Jugar" },
    settings_title = { pt = "IDIOMA", en = "LANGUAGE", es = "IDIOMA" },
    settings_info = {
        pt = "Muda o idioma das abas, botões e status. Textos longos de explicação continuam em português. Feche e abra o hub de novo (rode o script) pra aplicar direito em tudo.",
        en = "Changes the language of tabs, buttons and status. Long explanation texts stay in Portuguese. Close and reopen the hub (run the script again) to apply it everywhere.",
        es = "Cambia el idioma de las pestañas, botones y estado. Los textos largos de explicación siguen en portugués. Cierra y abre el hub de nuevo (ejecuta el script otra vez) para aplicarlo en todo.",
    },

    -- Status dinâmicos (usados tanto no CORE quanto no menu)
    status_stopped = { pt = "Status: PARADO", en = "Status: STOPPED", es = "Estado: DETENIDO" },
    status_running = { pt = "Status: RODANDO", en = "Status: RUNNING", es = "Estado: CORRIENDO" },
    status_activating_event = { pt = "Status: ATIVANDO EVENTO...", en = "Status: ACTIVATING EVENT...", es = "Estado: ACTIVANDO EVENTO..." },
    status_teleporting = { pt = "Status: TELEPORTANDO (evento ativo)", en = "Status: TELEPORTING (event active)", es = "Estado: TELETRANSPORTANDO (evento activo)" },
    status_selling = { pt = "Status: VENDENDO SLIMES...", en = "Status: SELLING SLIMES...", es = "Estado: VENDIENDO SLIMES..." },
    status_paused_other = { pt = "Status: PAUSADO (outro jogador)", en = "Status: PAUSED (other player)", es = "Estado: PAUSADO (otro jugador)" },
    status_active = { pt = "Status: ATIVO", en = "Status: ACTIVE", es = "Estado: ACTIVO" },
    status_inactive = { pt = "Status: DESATIVADO", en = "Status: DISABLED", es = "Estado: DESACTIVADO" },
    status_off = { pt = "Status: DESLIGADO", en = "Status: OFF", es = "Estado: APAGADO" },
    status_on_hold_shift = { pt = "Status: LIGADO (segure SHIFT)", en = "Status: ON (hold SHIFT)", es = "Estado: ACTIVADO (mantén SHIFT)" },
    status_on_no_car = { pt = "Status: LIGADO (carro não encontrado)", en = "Status: ON (car not found)", es = "Estado: ACTIVADO (auto no encontrado)" },
    status_boosting = { pt = "Status: IMPULSIONANDO", en = "Status: BOOSTING", es = "Estado: IMPULSANDO" },
    status_freecam_active = { pt = "Status: ATIVO (F5 pra sair)", en = "Status: ACTIVE (F5 to exit)", es = "Estado: ACTIVO (F5 para salir)" },
    status_none_normal_cam = { pt = "Status: NENHUM (câmera normal)", en = "Status: NONE (normal camera)", es = "Estado: NINGUNO (camara normal)" },
    status_watching = { pt = "Status: ASSISTINDO ", en = "Status: WATCHING ", es = "Estado: VIENDO " },
    label_teleports_forced = { pt = "Teleportes forçados: ", en = "Forced teleports: ", es = "Teletransportes forzados: " },
    label_cycles_complete = { pt = "Ciclos completos: ", en = "Cycles complete: ", es = "Ciclos completos: " },
    label_rounds = { pt = "Rodadas: ", en = "Rounds: ", es = "Rondas: " },
    label_selected = { pt = "Selecionado: ", en = "Selected: ", es = "Seleccionado: " },
    label_none_selected = { pt = "Nenhum objeto selecionado", en = "No object selected", es = "Ningun objeto seleccionado" },

    -- Seções e botões
    sec_ramp_cycle = { pt = "CICLO EVENTO MAIS CARO", en = "MOST EXPENSIVE EVENT CYCLE", es = "CICLO DEL EVENTO MAS CARO" },
    btn_alert_rainbow = { pt = "Alerta: Limited Rainbow", en = "Alert: Limited Rainbow", es = "Alerta: Limited Rainbow" },
    btn_alert_all_limited = { pt = "Alerta: Todos os Limited", en = "Alert: All Limiteds", es = "Alerta: Todos los Limited" },
    btn_sell_all = { pt = "Vender Todos os Slimes (manual)", en = "Sell All Slimes (manual)", es = "Vender Todos los Slimes (manual)" },
    lbl_checkpoint = { pt = "Checkpoint (X, Y, Z):", en = "Checkpoint (X, Y, Z):", es = "Checkpoint (X, Y, Z):" },
    btn_auto_pause = { pt = "Pausar Sozinho se Outro Jogador Entrar", en = "Auto-Pause if Another Player Joins", es = "Pausar Solo si Otro Jugador Entra" },
    sec_memory = { pt = "MEMÓRIA DE SLIME", en = "SLIME MEMORY", es = "MEMORIA DE SLIME" },
    sec_hitslime = { pt = "BATA O SLIME", en = "HIT THE SLIME", es = "GOLPEA AL SLIME" },
    lbl_seconds_per_round = { pt = "Segundos por rodada (nível):", en = "Seconds per round (level):", es = "Segundos por ronda (nivel):" },
    sec_freecam = { pt = "FREE CAM", en = "FREE CAM", es = "CAMARA LIBRE" },
    lbl_freecam_speed = { pt = "Velocidade base (studs/s):", en = "Base speed (studs/s):", es = "Velocidad base (studs/s):" },
    sec_car_boost = { pt = "IMPULSO DA PISTA (BOOST)", en = "TRACK BOOST", es = "IMPULSO DE LA PISTA" },
    lbl_boost_force = { pt = "Força do impulso:", en = "Boost force:", es = "Fuerza del impulso:" },
    btn_enable_boost = { pt = "Ativar Impulso (segure SHIFT pra usar)", en = "Enable Boost (hold SHIFT to use)", es = "Activar Impulso (manten SHIFT para usar)" },
    sec_clone_map = { pt = "CLONAR OBJETO DO MAPA (mira no centro)", en = "CLONE MAP OBJECT (aim in center)", es = "CLONAR OBJETO DEL MAPA (mira al centro)" },
    btn_show_crosshair = { pt = "Mostrar Mira no Centro da Tela", en = "Show Crosshair in Screen Center", es = "Mostrar Mira en el Centro de la Pantalla" },
    btn_clone_looked = { pt = "Clonar o que Estou Olhando (na mira)", en = "Clone What I'm Looking At (aim)", es = "Clonar lo que Estoy Mirando (mira)" },
    lbl_aim_distance = { pt = "Distância máxima da mira (studs):", en = "Max aim distance (studs):", es = "Distancia maxima de la mira (studs):" },
    sec_selected_object = { pt = "OBJETO SELECIONADO", en = "SELECTED OBJECT", es = "OBJETO SELECCIONADO" },
    btn_select_mode = { pt = "Modo Seleção (clique num objeto clonado)", en = "Select Mode (click a cloned object)", es = "Modo Seleccion (clic en un objeto clonado)" },
    btn_carry = { pt = "Segurar na Mão (na frente da câmera)", en = "Carry in Hand (in front of camera)", es = "Sostener en Mano (frente a la camara)" },
    btn_attach = { pt = "Grudar no que Estou Olhando", en = "Attach to What I'm Looking At", es = "Pegar a lo que Estoy Mirando" },
    btn_detach = { pt = "Soltar", en = "Detach", es = "Soltar" },
    btn_toggle_anchor = { pt = "Ancorar/Desancorar", en = "Anchor/Unanchor", es = "Anclar/Desanclar" },
    btn_shrink = { pt = "Diminuir", en = "Shrink", es = "Reducir" },
    btn_grow = { pt = "Aumentar", en = "Grow", es = "Aumentar" },
    btn_delete = { pt = "Deletar", en = "Delete", es = "Eliminar" },
    btn_clear_all = { pt = "Limpar Tudo", en = "Clear All", es = "Limpiar Todo" },
    sec_time_of_day = { pt = "HORÁRIO (DIA/NOITE -- SÓ VOCÊ VÊ)", en = "TIME OF DAY (ONLY YOU SEE)", es = "HORARIO (SOLO TU VES)" },
    btn_keep_fixed = { pt = "Manter Fixo (senão o jogo pode voltar o horário sozinho)", en = "Keep Fixed (game may revert time on its own)", es = "Mantener Fijo (el juego puede revertir la hora solo)" },
    btn_dawn = { pt = "Amanhecer", en = "Dawn", es = "Amanecer" },
    btn_day = { pt = "Dia", en = "Day", es = "Dia" },
    btn_dusk = { pt = "Entardecer", en = "Dusk", es = "Atardecer" },
    btn_night = { pt = "Noite", en = "Night", es = "Noche" },
    lbl_exact_hour = { pt = "Hora exata (0-24):", en = "Exact hour (0-24):", es = "Hora exacta (0-24):" },
    sec_esp = { pt = "ESP (VER JOGADORES)", en = "ESP (SEE PLAYERS)", es = "ESP (VER JUGADORES)" },
    lbl_esp_distance = { pt = "Distância máxima (studs):", en = "Max distance (studs):", es = "Distancia maxima (studs):" },
    sec_anim_idle = { pt = "ANIMAÇÃO CUSTOM (SÓ IDLE)", en = "CUSTOM ANIMATION (IDLE ONLY)", es = "ANIMACION CUSTOM (SOLO IDLE)" },
    lbl_idle_id = { pt = "Animation ID do IDLE (parado):", en = "IDLE Animation ID (standing):", es = "ID de Animacion IDLE (quieto):" },
    btn_capture_anim = { pt = "Capturar Animação Atual para o Idle (toque o emote antes de clicar)", en = "Capture Current Animation for Idle (play the emote before clicking)", es = "Capturar Animacion Actual para el Idle (reproduce el emote antes de hacer clic)" },
    btn_diagnose = { pt = "Diagnosticar (mostra estrutura do Animate no console)", en = "Diagnose (shows Animate structure in console)", es = "Diagnosticar (muestra la estructura del Animate en consola)" },
    btn_apply_idle = { pt = "Aplicar (só idle -- o resto continua normal)", en = "Apply (idle only -- the rest stays normal)", es = "Aplicar (solo idle -- el resto sigue normal)" },
    btn_reapply = { pt = "Reaplicar (depois de mudar o ID)", en = "Reapply (after changing the ID)", es = "Reaplicar (despues de cambiar el ID)" },
    sec_players_in_match = { pt = "JOGADORES NA PARTIDA", en = "PLAYERS IN MATCH", es = "JUGADORES EN LA PARTIDA" },
    btn_stop_spectate = { pt = "Parar Spectate", en = "Stop Spectate", es = "Detener Espectar" },
    btn_spectate = { pt = "Spectate", en = "Spectate", es = "Espectar" },
    lbl_no_other_players = { pt = "Nenhum outro jogador na partida.", en = "No other players in the match.", es = "Ningun otro jugador en la partida." },
    sec_top5 = { pt = "TOP 5 (CASH) - AO VIVO", en = "TOP 5 (CASH) - LIVE", es = "TOP 5 (CASH) - EN VIVO" },
    lbl_waiting_server = { pt = "Aguardando dados do servidor...", en = "Waiting for server data...", es = "Esperando datos del servidor..." },
    status_flying = { pt = "Status: VOANDO", en = "Status: FLYING", es = "Estado: VOLANDO" },
    sec_fly = { pt = "FLY / NO-CLIP COM O CARRO", en = "FLY / NO-CLIP WITH CAR", es = "VOLAR / NO-CLIP CON EL AUTO" },
    btn_fly_toggle = { pt = "Ativar Fly (No-Clip)", en = "Enable Fly (No-Clip)", es = "Activar Volar (No-Clip)" },
    sec_remote_spy = { pt = "REMOTE SPY (AO VIVO)", en = "REMOTE SPY (LIVE)", es = "REMOTE SPY (EN VIVO)" },
    btn_spy_enable = { pt = "Ativar Spy", en = "Enable Spy", es = "Activar Spy" },
    btn_spy_disable = { pt = "Desativar Spy", en = "Disable Spy", es = "Desactivar Spy" },
    btn_spy_copy = { pt = "Copiar Log", en = "Copy Log", es = "Copiar Log" },
    btn_spy_clear = { pt = "Limpar Log", en = "Clear Log", es = "Limpiar Log" },
    lbl_spy_unsupported = { pt = "Status: EXECUTOR NÃO SUPORTA (falta hookmetamethod)", en = "Status: EXECUTOR NOT SUPPORTED (missing hookmetamethod)", es = "Estado: EXECUTOR NO SOPORTADO (falta hookmetamethod)" },

    sec_function_spy = { pt = "FUNCTION SPY (FUNÇÃO REAL DO CHECKPOINT)", en = "FUNCTION SPY (REAL CHECKPOINT FUNCTION)", es = "FUNCTION SPY (FUNCIÓN REAL DEL CHECKPOINT)" },
    btn_capture_fn = { pt = "Capturar Função Real do Checkpoint", en = "Capture Real Checkpoint Function", es = "Capturar Función Real del Checkpoint" },
    btn_call_fn = { pt = "Chamar Função Real (com o carro)", en = "Call Real Function (with car)", es = "Llamar Función Real (con el auto)" },

    sec_weather = { pt = "CLIMA (SÓ VOCÊ VÊ)", en = "WEATHER (ONLY YOU SEE)", es = "CLIMA (SOLO TU VES)" },
    btn_weather_clear = { pt = "Limpo", en = "Clear", es = "Despejado" },
    btn_weather_rain = { pt = "Chuva", en = "Rain", es = "Lluvia" },
    btn_weather_storm = { pt = "Tempestade", en = "Storm", es = "Tormenta" },
    btn_weather_fog = { pt = "Neblina", en = "Fog", es = "Niebla" },
    btn_weather_snow = { pt = "Neve", en = "Snow", es = "Nieve" },
    btn_weather_sandstorm = { pt = "Tempestade de Areia", en = "Sandstorm", es = "Tormenta de Arena" },
}

local function t(key)
    local entry = T[key]
    if not entry then return key end
    return entry[Language.current] or entry.pt
end

-- Guarda a última aba aberta pra reabrir nela quando o menu inteiro é
-- reconstruído (troca de idioma, por exemplo), em vez de sempre voltar
-- pra Ramp.
local lastSelectedTabKey = "ramp"
local lastFramePosition = UDim2.new(0, 16, 0, 16)

local existingGui = playerGui:FindFirstChild("MegaRampHub")
if existingGui then
    existingGui:Destroy()
end

-- ========================================
-- GERACAO DO SCRIPT: destruir a GUI antiga acima nao desconecta os
-- listeners globais (F5 do Freecam, Shift do Impulso, o Heartbeat do
-- Impulso etc.) de uma execucao anterior do script -- rodando o hub 2x
-- sem fechar o jogo, os dois conjuntos de conexoes ficam ativos ao
-- mesmo tempo (foi isso que causou "[CAM] Freecam ativado" aparecer 2x
-- no log). Cada execucao pega um numero de geracao novo em _G (global
-- de verdade, sobrevive entre execucoes do script) e os handlers mais
-- sensiveis (F5, Shift, Heartbeat do impulso) checam se ainda sao a
-- geracao atual antes de fazer qualquer coisa -- a conexao antiga
-- continua existindo, mas vira um no-op sozinha.
-- ========================================

_G.MegaRampHubGeneration = (_G.MegaRampHubGeneration or 0) + 1
local HUB_GENERATION = _G.MegaRampHubGeneration

local function isCurrentHubGeneration()
    return _G.MegaRampHubGeneration == HUB_GENERATION
end

-- ========================================
-- REMOTES
-- ========================================

local function findRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r then return r end
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj.Name == name then return obj end
    end
    return nil
end

local Remotes = {
    retryRun = findRemote("RetryRun"),
    endBoxReveal = findRemote("EndBoxReveal"),
    startBoxReveal = findRemote("StartBoxReveal"),
    clientCarLaunch = findRemote("ClientCarLaunch"),
    openBoxClick = findRemote("OpenBoxClick"),
    boxStarsReveal = findRemote("BoxStarsReveal"),
    sellSlimeOpen = findRemote("SellSlimeOpen"),
    sellSlimeAction = findRemote("SellSlimeAction"),
    equipBestInventory = findRemote("EquipBestInventory"),
    eventShopUpdate = findRemote("EventShopUpdate"),
    eventShopAction = findRemote("EventShopAction"),
    selectInventoryItem = findRemote("SelectInventoryItem"),
    giftAction = findRemote("GiftAction"),
    giftIncoming = findRemote("GiftIncoming"),
    miniGameMemoryEvent = findRemote("MiniGame1MemoryEvent"),
    leaderboardUpdate = findRemote("LeaderboardUpdate"),
    miniParkourEvent = findRemote("MiniParkourEvent"),
    adminAbuseRemote = findRemote("AdminAbuseRemote"),
}

-- Diagnóstico: o jogo já renomeou coisas por baixo dos nossos pés antes
-- (carro virou "MiniCar_<numero>", JumpCar foi pra dentro de uma pasta
-- "Progetto" nova) -- se algum remote sumir/mudar de nome de novo, é
-- melhor ver isso LOGO na inicialização do hub do que só descobrir 20
-- minutos depois que uma feature específica "não faz nada". Lista o que
-- achou e o que NÃO achou, uma vez só, no início.
do
    local missing = {}
    for key, remote in pairs(Remotes) do
        if not remote then table.insert(missing, key) end
    end
    if #missing > 0 then
        table.sort(missing)
        addLog("[DIAGNOSTICO] [!] " .. #missing .. " remote(s) NÃO encontrado(s): " .. table.concat(missing, ", "))
    else
        local totalCount = 0
        for _ in pairs(Remotes) do totalCount = totalCount + 1 end
        addLog("[DIAGNOSTICO] [✓] Todos os " .. totalCount .. " remotes conhecidos foram encontrados")
    end
end

local miniGameButton = Workspace:WaitForChild("MiniGame1Button")

-- Top 5 leaderboard (Cash/renda base/carros de cada jogador) que o próprio
-- jogo já transmite pra todo mundo -- só precisamos ouvir o mesmo remote,
-- sem precisar construir nada do zero.
local latestLeaderboardData = nil
local refreshLeaderboardUI -- atribuída lá na aba JOGADORES, mais abaixo

if Remotes.leaderboardUpdate then
    Remotes.leaderboardUpdate.OnClientEvent:Connect(function(list)
        latestLeaderboardData = list
        if refreshLeaderboardUI then refreshLeaderboardUI() end
    end)
end

-- ========================================
-- DISCORD WEBHOOK
-- ========================================

local webhookConfig = { url = "" }
local webhookToggles = {}

local function getHttpRequestFn()
    if typeof(request) == "function" then return request end
    if typeof(http_request) == "function" then return http_request end
    if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request end
    if typeof(fluxus) == "table" and typeof(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local function sendDiscordWebhook(title, description, color3)
    if not webhookConfig.url or webhookConfig.url == "" then return end

    local reqFn = getHttpRequestFn()
    if not reqFn then
        addLog("[WEBHOOK] [!] Executor não suporta request HTTP (request/http_request/syn.request)")
        return
    end

    local c = color3 or Color3.fromRGB(0, 190, 100)
    local colorInt = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)

    local ok, body = pcall(function()
        return HttpService:JSONEncode({
            embeds = {
                { title = title, description = description, color = colorInt }
            }
        })
    end)
    if not ok then return end

    task.spawn(function()
        local sent, err = pcall(function()
            reqFn({
                Url = webhookConfig.url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)
        if sent then
            addLog("[WEBHOOK] [✓] Enviado: " .. title)
        else
            addLog("[WEBHOOK] [!] Falha ao enviar: " .. tostring(err))
        end
    end)
end

-- ========================================
-- ANTI-AFK (10 em 10 minutos, sempre rodando)
-- ========================================

local antiAfkIntervalMinutes = 10
local antiAfkJumpCount = 0

local function antiAfkDoJump()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)

    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function() humanoid.Jump = true end)
        end
    end

    antiAfkJumpCount = antiAfkJumpCount + 1
    addLog("[ANTI-AFK] Pulo #" .. antiAfkJumpCount)
end

task.spawn(function()
    while true do
        task.wait(antiAfkIntervalMinutes * 60)
        antiAfkDoJump()
    end
end)

-- ========================================
-- EventConfig (evento mais caro)
-- ========================================

local function findEventConfig()
    local eventSystem = ReplicatedStorage:FindFirstChild("EventSystem")
    if not eventSystem then
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj.Name == "EventSystem" then eventSystem = obj break end
        end
    end
    if not eventSystem then return nil end
    local moduleScript = eventSystem:FindFirstChild("EventConfig")
    if not moduleScript then return nil end
    local ok, cfg = pcall(require, moduleScript)
    if ok and type(cfg) == "table" then return cfg end
    return nil
end

local EventConfig = findEventConfig()
if EventConfig then
    local ok, allEvents = pcall(EventConfig.GetAllEvents)
    print("[+] EventConfig carregado (" .. (ok and #allEvents or 0) .. " eventos)")
else
    print("[-] EventConfig NÃO encontrado")
end

local function findMostExpensiveEvent()
    if not EventConfig then return nil end
    local ok, allEvents = pcall(EventConfig.GetAllEvents)
    if not ok or type(allEvents) ~= "table" or #allEvents == 0 then return nil end
    return allEvents[#allEvents]
end

-- Acha o evento MAIS BARATO entre os que têm o maior CashMultiplier do
-- catálogo (hoje é x10, ex: REI MILIONÁRIO por 600K) -- em vez de fixar
-- "10" (que quebraria se o jogo adicionar um multiplicador maior no
-- futuro), pega o maior CashMultiplier que existir AGORA no
-- EventConfig e escolhe o mais barato dentro desse grupo.
local function findCheapestMaxCashEvent()
    if not EventConfig then return nil end
    local ok, allEvents = pcall(EventConfig.GetAllEvents)
    if not ok or type(allEvents) ~= "table" or #allEvents == 0 then return nil end

    local maxCashMultiplier = 1
    for _, event in ipairs(allEvents) do
        local mult = tonumber(event.CashMultiplier) or 1
        if mult > maxCashMultiplier then
            maxCashMultiplier = mult
        end
    end

    local cheapest = nil
    for _, event in ipairs(allEvents) do
        local mult = tonumber(event.CashMultiplier) or 1
        if mult == maxCashMultiplier then
            local cost = tonumber(event.Cost) or math.huge
            if not cheapest or cost < (tonumber(cheapest.Cost) or math.huge) then
                cheapest = event
            end
        end
    end

    return cheapest
end

-- ========================================
-- HELPERS COMPARTILHADOS: teleporte, prompt dual-platform, clique de botão
-- ========================================

local function getPromptWorldPosition(prompt)
    local parent = prompt.Parent
    if parent and parent:IsA("Attachment") then
        return parent.WorldPosition
    elseif parent and parent:IsA("BasePart") then
        return parent.Position
    end
    return nil
end

local function teleportPlayerTo(position)
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local original = hrp.CFrame
    hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    return original
end

local function teleportPlayerBack(originalCFrame)
    if not originalCFrame then return end
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = originalCFrame end
end

-- Teleporte direto até outro jogador (aba Espectar) -- pega o
-- HumanoidRootPart de AMBOS, do seu personagem e do alvo, e te
-- posiciona um pouco ao lado dele (studs offset em X) pra não cair
-- exatamente em cima e engasgar na física do outro personagem.
local function teleportToPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        addLog("[PLAYERS] [!] Seu personagem não está carregado")
        return
    end

    local targetCharacter = targetPlayer.Character
    local targetHrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        addLog("[PLAYERS] [!] " .. targetPlayer.Name .. " não tem personagem carregado")
        return
    end

    hrp.CFrame = targetHrp.CFrame * CFrame.new(3, 0, 0)
    addLog("[PLAYERS] Teleportado até " .. targetPlayer.Name)
end

local isPcPlatform = UserInputService.KeyboardEnabled

local function triggerPromptGeneric(prompt)
    -- Prioriza fireproximityprompt (função nativa de executor) quando
    -- disponível, em qualquer plataforma: ela dispara ESSE prompt
    -- específico direto, sem passar pela tecla física. A simulação de
    -- tecla (abaixo) aperta e solta E de verdade, o que ativa QUALQUER
    -- prompt que esteja focado/no alcance no momento -- se houver mais de
    -- um prompt próximo (ex: dois slots da base ocupados perto um do
    -- outro), apertar E várias vezes seguidas pode acabar ativando
    -- prompts DIFERENTES em vez do mesmo, dando resultados ambíguos (foi
    -- o que causou um delta de +2/-2 no teste de duplicação em vez de um
    -- resultado claro de +1/-1 num único prompt).
    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, prompt)
        if ok then return true end
    end

    if isPcPlatform then
        local keyCode = prompt.KeyboardKeyCode
        if not keyCode or keyCode == Enum.KeyCode.Unknown then
            keyCode = Enum.KeyCode.E
        end
        local holdDuration = math.max(tonumber(prompt.HoldDuration) or 0, 0)
        local pressed = pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        end)
        if not pressed then return false end
        task.wait(holdDuration + 0.15)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
        return true
    end

    return false
end

local function fireAllConnections(signal)
    local ok, conns = pcall(getconnections, signal)
    if not ok or not conns or #conns == 0 then return false end
    local firedAny = false
    for _, conn in ipairs(conns) do
        local fireOk = pcall(function() conn:Fire() end)
        firedAny = firedAny or fireOk
    end
    return firedAny
end

local function simulateButtonClick(button)
    if fireAllConnections(button.MouseButton1Click) then return true end
    if fireAllConnections(button.Activated) then return true end

    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    local x = absPos.X + absSize.X / 2
    local y = absPos.Y + absSize.Y / 2

    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)

    if ok then return true end
    return pcall(function() firesignal(button.MouseButton1Click) end)
end

-- ========================================
-- ACEITAR GIFTS AUTOMATICAMENTE: quando outro jogador te manda um gift, o
-- jogo dispara GiftIncoming:OnClientEvent(...) e abre uma tela de
-- confirmação (com um botão tipo "Aceitar"/"OK"/"Accept"). Com o toggle
-- LIGADO, a gente faz os dois passos sozinho: (1) assim que o
-- GiftIncoming chega, dispara GiftAction:FireServer com as variantes de
-- nome de ação mais prováveis pra aceitar (o jogo ignora as que não
-- reconhece, então tentar várias é seguro); (2) fica de olho em QUALQUER
-- GuiButton novo que apareça dentro do PlayerGui com texto de
-- confirmação (Aceitar/Accept/OK/Confirmar/Sim/Yes) e clica sozinho,
-- cobrindo o caso de precisar confirmar na tela também. Como não temos
-- acesso ao script do jogo, essa dupla abordagem cobre os formatos mais
-- comuns sem precisar adivinhar o nome exato do remote/GUI.
-- ========================================

local function buildAutoAcceptGiftsFeature()
    local enabled = false
    local incomingConn = nil
    local guiWatchConn = nil

    local ACCEPT_ACTION_NAMES = {
        "AcceptGift", "Accept", "ConfirmGift", "Confirm", "GiftAccept", "AcceptGiftRequest",
    }

    local ACCEPT_TEXT_KEYWORDS = {
        "accept", "aceitar", "confirmar", "confirm", "aceptar", "sim", "yes", "ok",
    }

    local function tryAcceptViaRemote(...)
        if not Remotes.giftAction then return end
        local args = { ... }
        for _, actionName in ipairs(ACCEPT_ACTION_NAMES) do
            pcall(function() Remotes.giftAction:FireServer(actionName, table.unpack(args)) end)
        end
        addLog("[GIFT] [*] Gift recebido -- tentando aceitar automaticamente")
    end

    local function looksLikeAcceptButton(obj)
        if not obj:IsA("GuiButton") then return false end
        local text = tostring(obj.Text or ""):lower()
        if text == "" then return false end
        for _, keyword in ipairs(ACCEPT_TEXT_KEYWORDS) do
            if text:find(keyword, 1, true) then return true end
        end
        return false
    end

    local function watchForConfirmButton(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if looksLikeAcceptButton(obj) then
                task.wait(0.15)
                simulateButtonClick(obj)
                addLog("[GIFT] [✓] Botão de confirmação clicado automaticamente ('" .. tostring(obj.Text) .. "')")
                return
            end
        end
    end

    local function enable()
        if enabled then return end

        if Remotes.giftIncoming then
            incomingConn = Remotes.giftIncoming.OnClientEvent:Connect(function(...)
                tryAcceptViaRemote(...)
                task.spawn(function()
                    task.wait(0.3)
                    watchForConfirmButton(playerGui)
                end)
            end)
        else
            addLog("[GIFT] [!] GiftIncoming não encontrado -- só o clique automático na tela de confirmação vai funcionar")
        end

        -- Cobre o caso de a tela de confirmação aparecer sem (ou antes do)
        -- GiftIncoming disparar -- qualquer GuiButton novo que pareça um
        -- botão de aceitar/confirmar é clicado sozinho.
        guiWatchConn = playerGui.DescendantAdded:Connect(function(obj)
            if looksLikeAcceptButton(obj) then
                task.spawn(function()
                    task.wait(0.15)
                    if obj.Parent then
                        simulateButtonClick(obj)
                        addLog("[GIFT] [✓] Botão de confirmação clicado automaticamente ('" .. tostring(obj.Text) .. "')")
                    end
                end)
            end
        end)

        enabled = true
        addLog("[GIFT] [✓] Aceitar gifts automaticamente ATIVADO")
    end

    local function disable()
        if not enabled then return end

        if incomingConn then incomingConn:Disconnect() incomingConn = nil end
        if guiWatchConn then guiWatchConn:Disconnect() guiWatchConn = nil end

        enabled = false
        addLog("[GIFT] Aceitar gifts automaticamente DESATIVADO")
    end

    local function toggle()
        if enabled then disable() else enable() end
        return enabled
    end

    return {
        toggle = toggle,
        isEnabled = function() return enabled end,
    }
end

local AutoAcceptGifts = buildAutoAcceptGiftsFeature()

-- ========================================
-- OCULTAR HUD DO JOGO: esconde os ScreenGuis nativos do jogo (os ícones
-- de atalho tipo Índice/Loja/Inventário/Carros/Admin/Pintar no canto
-- esquerdo) mas tenta MANTER visível o que mostra dinheiro ganho (canto
-- inferior esquerdo, incluindo os popups "+$X" que sobem) e o
-- leaderboard (canto superior direito). Como não temos acesso ao script
-- do jogo pra saber o nome exato de cada ScreenGui, a decisão de
-- esconder ou manter é por palavra-chave no NOME do ScreenGui -- todo
-- ScreenGui encontrado (escondido ou mantido) vai pro log, então dá pra
-- ver se algo saiu errado e ajustar a lista de palavras-chave depois.
-- ========================================

local function buildHideHudFeature()
    local enabled = false
    local hiddenGuis = {}

    local KEEP_KEYWORDS = {
        "leaderboard", "rank", "placar", "top5", "top",
        "cash", "money", "grana", "currency", "coin", "moeda",
        "combo", "reward", "notification", "notif",
    }

    local OWN_GUI_NAMES = { MegaRampHub = true, AdminAbuseGui = true }

    local function shouldKeep(name)
        local lowerName = name:lower()
        for _, keyword in ipairs(KEEP_KEYWORDS) do
            if lowerName:find(keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local function enable()
        if enabled then return end
        hiddenGuis = {}

        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and not OWN_GUI_NAMES[gui.Name] then
                if gui.Enabled and not shouldKeep(gui.Name) then
                    gui.Enabled = false
                    table.insert(hiddenGuis, gui)
                    addLog("[HUD] Escondido: " .. gui.Name)
                else
                    addLog("[HUD] Mantido visível: " .. gui.Name)
                end
            end
        end

        enabled = true
        addLog("[HUD] [✓] " .. #hiddenGuis .. " GUI(s) escondida(s). Se algo sumiu ou ficou errado, olha os nomes no log acima.")
    end

    local function disable()
        if not enabled then return end

        for _, gui in ipairs(hiddenGuis) do
            if gui.Parent then
                gui.Enabled = true
            end
        end
        hiddenGuis = {}

        enabled = false
        addLog("[HUD] Restaurado -- todas as GUIs escondidas voltaram")
    end

    local function toggle()
        if enabled then disable() else enable() end
        return enabled
    end

    return {
        toggle = toggle,
        isEnabled = function() return enabled end,
    }
end

local HideHud = buildHideHudFeature()

-- ========================================
-- ADMIN ABUSE PANEL: painel de admin do próprio jogo (dá coins de evento,
-- liga 3x boxes/tree rush, manda anúncios, roda a sequência automática de
-- 30min) -- só funciona de verdade se o SERVIDOR reconhecer você como
-- admin (ele manda "AdminAccess" pelo AdminAbuseRemote confirmando isso;
-- sem essa confirmação os botões continuam existindo mas não fazem nada
-- no servidor). Código colado quase 1:1 do painel original do jogo,
-- só adaptado pra reusar os services/Remotes que o hub já tem (em vez de
-- pegar os dele próprios) e pra não travar o carregamento do hub inteiro
-- se o remote não existir (usa Remotes.adminAbuseRemote, achado via
-- findRemote, em vez de WaitForChild bloqueante).
-- ========================================

local function buildAdminAbusePanelFeature()
    local AdminAbuseRemote = Remotes.adminAbuseRemote
    if not AdminAbuseRemote then
        addLog("[ADMIN-ABUSE] [!] AdminAbuseRemote não encontrado -- painel não disponível nesse servidor")
        return {
            toggle = function() addLog("[ADMIN-ABUSE] [!] Indisponível (AdminAbuseRemote não encontrado)") end,
            isAvailable = function() return false end,
        }
    end

    local TweenService = game:GetService("TweenService")
    local PlayerGui = playerGui

    local t = {
        Active = false,
        Scope = "SERVER",
        EndsAt = 0,
        TripleBoxes = false,
        TreeMultiplier = 1,
        AutoSequence = false
    }
    local v1 = false
    local v2 = false
    local v3 = "SERVER"
    local v4 = "MANUAL"
    local v5 = 0
    local v6 = Color3.fromRGB(58, 58, 68)
    local v7 = Color3.fromRGB(205, 48, 58)
    local v8 = Color3.fromRGB(235, 58, 68)

    local function addCorner(p1, p2)
        local UICorner = Instance.new("UICorner")

        UICorner.CornerRadius = UDim.new(0, p2 or 12)
        UICorner.Parent = p1

        return UICorner
    end

    local function addStroke(p1, p2, p3, p4)
        local UIStroke = Instance.new("UIStroke")

        UIStroke.Color = if p2 then p2 else Color3.fromRGB(255, 255, 255)
        UIStroke.Thickness = p3 or 2
        UIStroke.Transparency = p4 or 0
        UIStroke.Parent = p1

        return UIStroke
    end

    local function addTextConstraint(p1, p2, p3)
        local UITextSizeConstraint = Instance.new("UITextSizeConstraint")

        UITextSizeConstraint.MinTextSize = p2 or 10
        UITextSizeConstraint.MaxTextSize = p3 or 28
        UITextSizeConstraint.Parent = p1

        return UITextSizeConstraint
    end

    local function formatTime(p1)
        local v3 = math.max(0, (math.floor(tonumber(p1) or 0)))

        return string.format("%02d:%02d", math.floor(v3 / 60), v3 % 60)
    end

    local AdminAbuseGui = Instance.new("ScreenGui")

    AdminAbuseGui.Name = "AdminAbuseGui"
    AdminAbuseGui.ResetOnSpawn = false
    AdminAbuseGui.IgnoreGuiInset = true
    AdminAbuseGui.DisplayOrder = 12000
    AdminAbuseGui.Parent = PlayerGui

    local AdminAbuseStatus = Instance.new("Frame")

    AdminAbuseStatus.Name = "AdminAbuseStatus"
    AdminAbuseStatus.AnchorPoint = Vector2.new(0.5, 1)
    AdminAbuseStatus.Position = UDim2.new(0.5, 0, 1, -28)
    AdminAbuseStatus.Size = UDim2.new(0, 360, 0, 52)
    AdminAbuseStatus.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    AdminAbuseStatus.BackgroundTransparency = 1
    AdminAbuseStatus.BorderSizePixel = 0
    AdminAbuseStatus.Visible = false
    AdminAbuseStatus.ZIndex = 100
    AdminAbuseStatus.Parent = AdminAbuseGui

    local UICorner = Instance.new("UICorner")

    UICorner.CornerRadius = UDim.new(0, 14)
    UICorner.Parent = AdminAbuseStatus

    local v9 = Color3.fromRGB(255, 80, 80)
    local UIStroke = Instance.new("UIStroke")

    UIStroke.Color = v9 or Color3.fromRGB(255, 255, 255)
    UIStroke.Thickness = 2.5
    UIStroke.Transparency = 1
    UIStroke.Parent = AdminAbuseStatus

    local v11 = UIStroke
    local TextLabel = Instance.new("TextLabel")

    TextLabel.Size = UDim2.new(1, 0, 0, 30)
    TextLabel.Position = UDim2.new(0, 0, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = "ADMIN ABUSE"
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.TextStrokeTransparency = 0.35
    TextLabel.Font = Enum.Font.GothamBlack
    TextLabel.TextScaled = true
    TextLabel.ZIndex = 101
    TextLabel.Parent = AdminAbuseStatus

    local UITextSizeConstraint = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint.MinTextSize = 12
    UITextSizeConstraint.MaxTextSize = 24
    UITextSizeConstraint.Parent = TextLabel

    local TextLabel2 = Instance.new("TextLabel")

    TextLabel2.Size = UDim2.new(1, 0, 0, 20)
    TextLabel2.Position = UDim2.new(0, 0, 0, 31)
    TextLabel2.BackgroundTransparency = 1
    TextLabel2.Text = "3X BOXES \226\128\162 TREE RUSH"
    TextLabel2.TextColor3 = Color3.fromRGB(255, 215, 90)
    TextLabel2.Font = Enum.Font.GothamBold
    TextLabel2.TextScaled = true
    TextLabel2.ZIndex = 101
    TextLabel2.Parent = AdminAbuseStatus

    local UITextSizeConstraint2 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint2.MinTextSize = 9
    UITextSizeConstraint2.MaxTextSize = 15
    UITextSizeConstraint2.Parent = TextLabel2

    local AdminAbuseAnnouncement = Instance.new("Frame")

    AdminAbuseAnnouncement.Name = "AdminAbuseAnnouncement"
    AdminAbuseAnnouncement.AnchorPoint = Vector2.new(0.5, 0.5)
    AdminAbuseAnnouncement.Position = UDim2.fromScale(0.5, 0.5)
    AdminAbuseAnnouncement.Size = UDim2.new(0, 520, 0, 82)
    AdminAbuseAnnouncement.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    AdminAbuseAnnouncement.BackgroundTransparency = 1
    AdminAbuseAnnouncement.BorderSizePixel = 0
    AdminAbuseAnnouncement.Visible = false
    AdminAbuseAnnouncement.ZIndex = 110
    AdminAbuseAnnouncement.Parent = AdminAbuseGui

    local UICorner2 = Instance.new("UICorner")

    UICorner2.CornerRadius = UDim.new(0, 16)
    UICorner2.Parent = AdminAbuseAnnouncement

    local v12 = Color3.fromRGB(255, 255, 255)
    local UIStroke2 = Instance.new("UIStroke")

    UIStroke2.Color = v12 or Color3.fromRGB(255, 255, 255)
    UIStroke2.Thickness = 3
    UIStroke2.Transparency = 1
    UIStroke2.Parent = AdminAbuseAnnouncement

    local v14 = UIStroke2
    local TextLabel3 = Instance.new("TextLabel")

    TextLabel3.Size = UDim2.new(1, -28, 1, -14)
    TextLabel3.Position = UDim2.new(0, 14, 0, 7)
    TextLabel3.BackgroundTransparency = 1
    TextLabel3.Text = ""
    TextLabel3.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel3.TextStrokeTransparency = 0.25
    TextLabel3.TextWrapped = true
    TextLabel3.Font = Enum.Font.GothamBlack
    TextLabel3.TextScaled = true
    TextLabel3.ZIndex = 111
    TextLabel3.Parent = AdminAbuseAnnouncement

    local UITextSizeConstraint3 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint3.MinTextSize = 13
    UITextSizeConstraint3.MaxTextSize = 30
    UITextSizeConstraint3.Parent = TextLabel3

    local function getAnnouncementColor(p1)
        local v1 = tostring(p1 or "INFO"):upper()

        if v1 == "COINS" then
            return Color3.fromRGB(255, 205, 55)
        end

        if v1 == "WARNING" then
            return Color3.fromRGB(255, 125, 45)
        end

        if v1 == "START" then
            return Color3.fromRGB(255, 65, 80)
        end

        if v1 == "END" then
            return Color3.fromRGB(100, 220, 255)
        end

        return Color3.fromRGB(140, 205, 255)
    end

    local function showAnnouncement(p1, p2, p3)
        v5 = v5 + 1

        local v1 = v5
        local v2 = getAnnouncementColor(p2)

        TextLabel3.Text = tostring(p1 or "")
        TextLabel3.TextColor3 = v2
        v14.Color = v2
        AdminAbuseAnnouncement.BackgroundTransparency = 1
        TextLabel3.TextTransparency = 0
        AdminAbuseAnnouncement.Visible = true

        local v3 = task.delay

        v3(math.clamp(tonumber(p3) or 3, 2, 3.2), function()
            if v1 ~= v5 then
                return
            end

            TweenService:Create(TextLabel3, TweenInfo.new(0.3), {
                TextTransparency = 1
            }):Play()
            task.wait(0.32)

            if v1 ~= v5 then
                return
            end

            AdminAbuseAnnouncement.Visible = false
            AdminAbuseAnnouncement.BackgroundTransparency = 1
            TextLabel3.TextTransparency = 0
        end)
    end

    local OpenAdminAbusePanel = Instance.new("TextButton")

    OpenAdminAbusePanel.Name = "OpenAdminAbusePanel"
    OpenAdminAbusePanel.Size = UDim2.new(0, 132, 0, 46)
    OpenAdminAbusePanel.AnchorPoint = Vector2.new(0, 0)
    OpenAdminAbusePanel.Position = UDim2.new(0, 18, 1, -170)
    OpenAdminAbusePanel.BackgroundColor3 = v6
    OpenAdminAbusePanel.BackgroundTransparency = 0.03
    OpenAdminAbusePanel.BorderSizePixel = 0
    OpenAdminAbusePanel.Text = ""
    OpenAdminAbusePanel.AutoButtonColor = false
    OpenAdminAbusePanel.Visible = false
    OpenAdminAbusePanel.ZIndex = 200
    OpenAdminAbusePanel.Parent = AdminAbuseGui

    local UICorner3 = Instance.new("UICorner")

    UICorner3.CornerRadius = UDim.new(0, 13)
    UICorner3.Parent = OpenAdminAbusePanel

    local v15 = Color3.fromRGB(255, 255, 255)
    local UIStroke3 = Instance.new("UIStroke")

    UIStroke3.Color = v15 or Color3.fromRGB(255, 255, 255)
    UIStroke3.Thickness = 1.5
    UIStroke3.Transparency = 0.5
    UIStroke3.Parent = OpenAdminAbusePanel

    local v17 = UIStroke3
    local IconBox = Instance.new("Frame")

    IconBox.Name = "IconBox"
    IconBox.Size = UDim2.new(0, 34, 0, 34)
    IconBox.Position = UDim2.new(0, 6, 0.5, -17)
    IconBox.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    IconBox.BackgroundTransparency = 0.38
    IconBox.BorderSizePixel = 0
    IconBox.ZIndex = 201
    IconBox.Parent = OpenAdminAbusePanel

    local UICorner4 = Instance.new("UICorner")

    UICorner4.CornerRadius = UDim.new(0, 10)
    UICorner4.Parent = IconBox

    local v18 = Color3.fromRGB(255, 255, 255)
    local UIStroke4 = Instance.new("UIStroke")

    UIStroke4.Color = v18 or Color3.fromRGB(255, 255, 255)
    UIStroke4.Thickness = 1
    UIStroke4.Transparency = 0.72
    UIStroke4.Parent = IconBox

    local Icon = Instance.new("TextLabel")

    Icon.Name = "Icon"
    Icon.Size = UDim2.fromScale(1, 1)
    Icon.BackgroundTransparency = 1
    Icon.Text = "A"
    Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    Icon.Font = Enum.Font.GothamBlack
    Icon.TextScaled = true
    Icon.ZIndex = 202
    Icon.Parent = IconBox

    local UITextSizeConstraint4 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint4.MinTextSize = 13
    UITextSizeConstraint4.MaxTextSize = 21
    UITextSizeConstraint4.Parent = Icon

    local Title = Instance.new("TextLabel")

    Title.Name = "Title"
    Title.Size = UDim2.new(1, -53, 0, 22)
    Title.Position = UDim2.new(0, 47, 0, 5)
    Title.BackgroundTransparency = 1
    Title.Text = "ADMIN"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextScaled = true
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.ZIndex = 201
    Title.Parent = OpenAdminAbusePanel

    local UITextSizeConstraint5 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint5.MinTextSize = 11
    UITextSizeConstraint5.MaxTextSize = 18
    UITextSizeConstraint5.Parent = Title

    local SubTitle = Instance.new("TextLabel")

    SubTitle.Name = "SubTitle"
    SubTitle.Size = UDim2.new(1, -53, 0, 12)
    SubTitle.Position = UDim2.new(0, 47, 0, 27)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "CONTROL"
    SubTitle.TextColor3 = Color3.fromRGB(205, 205, 215)
    SubTitle.Font = Enum.Font.GothamBold
    SubTitle.TextScaled = true
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.ZIndex = 201
    SubTitle.Parent = OpenAdminAbusePanel

    local UITextSizeConstraint6 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint6.MinTextSize = 7
    UITextSizeConstraint6.MaxTextSize = 10
    UITextSizeConstraint6.Parent = SubTitle

    local StateDot = Instance.new("Frame")

    StateDot.Name = "StateDot"
    StateDot.AnchorPoint = Vector2.new(1, 0.5)
    StateDot.Size = UDim2.new(0, 7, 0, 7)
    StateDot.Position = UDim2.new(1, -8, 0.5, 0)
    StateDot.BackgroundColor3 = Color3.fromRGB(155, 155, 165)
    StateDot.BorderSizePixel = 0
    StateDot.ZIndex = 202
    StateDot.Parent = OpenAdminAbusePanel

    local UICorner5 = Instance.new("UICorner")

    UICorner5.CornerRadius = UDim.new(0, 99)
    UICorner5.Parent = StateDot

    local AdminAbusePanel = Instance.new("Frame")

    AdminAbusePanel.Name = "AdminAbusePanel"
    AdminAbusePanel.AnchorPoint = Vector2.new(0.5, 0.5)
    AdminAbusePanel.Position = UDim2.fromScale(0.5, 0.5)
    AdminAbusePanel.Size = UDim2.new(0, 600, 0, 540)
    AdminAbusePanel.BackgroundColor3 = Color3.fromRGB(17, 17, 22)
    AdminAbusePanel.BorderSizePixel = 0
    AdminAbusePanel.Visible = false
    AdminAbusePanel.ZIndex = 200
    AdminAbusePanel.Parent = AdminAbuseGui

    local UICorner6 = Instance.new("UICorner")

    UICorner6.CornerRadius = UDim.new(0, 18)
    UICorner6.Parent = AdminAbusePanel

    local v20 = Color3.fromRGB(255, 75, 85)
    local UIStroke5 = Instance.new("UIStroke")

    UIStroke5.Color = if v20 then v20 else Color3.fromRGB(255, 255, 255)
    UIStroke5.Thickness = 3
    UIStroke5.Transparency = 0.1
    UIStroke5.Parent = AdminAbusePanel

    local UIScale = Instance.new("UIScale")

    UIScale.Scale = 1
    UIScale.Parent = AdminAbusePanel

    local function updatePanelScale()
        local CurrentCamera = workspace.CurrentCamera
        local v1 = workspace.CurrentCamera and CurrentCamera.ViewportSize or Vector2.new(1280, 720)

        UIScale.Scale = math.clamp(math.min(v1.X / 660, v1.Y / 600), 0.55, 1.05)

        local v6 = UserInputService.TouchEnabled or (if v1.X <= 900 then true elseif v1.Y <= 520 then true else false)
        local v8 = math.clamp(v1.X - 36, 260, 390)
        local v10 = math.clamp(v1.X - 34, 300, 560)

        if v6 then
            AdminAbuseStatus.Position = UDim2.new(0.5, 0, 1, -2)
            AdminAbuseStatus.Size = UDim2.new(0, v8, 0, 44)
            TextLabel2.Size = UDim2.new(1, 0, 0, 18)
            TextLabel2.Position = UDim2.new(0, 0, 0, 1)
            TextLabel.Size = UDim2.new(1, 0, 0, 22)
        else
            AdminAbuseStatus.Position = UDim2.new(0.5, 0, 1, 0)
            AdminAbuseStatus.Size = UDim2.new(0, v8, 0, 50)
            TextLabel2.Size = UDim2.new(1, 0, 0, 20)
            TextLabel2.Position = UDim2.new(0, 0, 0, 1)
            TextLabel.Size = UDim2.new(1, 0, 0, 28)
        end

        TextLabel.Position = UDim2.new(0, 0, 0, 22)
        AdminAbuseAnnouncement.Position = UDim2.fromScale(0.5, 0.5)
        AdminAbuseAnnouncement.Size = UDim2.new(0, v10, 0, if v6 then 76 else 82)

        local v17 = if v6 then 64 else 78
        local v18 = if v6 then 8 else 12

        OpenAdminAbusePanel.Size = UDim2.new(0, v17, 0, v17)
        OpenAdminAbusePanel.Position = UDim2.new(0, (if v6 then 14 else 20) + v17 + v18, 0, 68 + (v17 + v18) * 2)
        IconBox.Visible = false
        Title.Size = UDim2.new(1, -10, 0, (math.floor(v17 * 0.44)))
        Title.Position = UDim2.new(0, 5, 0, (math.floor(v17 * 0.18)))
        Title.TextXAlignment = Enum.TextXAlignment.Center
        SubTitle.Size = UDim2.new(1, -10, 0, (math.floor(v17 * 0.2)))
        SubTitle.Position = UDim2.new(0, 5, 0, (math.floor(v17 * 0.62)))
        SubTitle.TextXAlignment = Enum.TextXAlignment.Center
        StateDot.Position = UDim2.new(1, -7, 0, 7)
    end

    updatePanelScale()

    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePanelScale)
    end

    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        updatePanelScale()
    end)

    local TextLabel4 = Instance.new("TextLabel")

    TextLabel4.Size = UDim2.new(1, -90, 0, 52)
    TextLabel4.Position = UDim2.new(0, 18, 0, 8)
    TextLabel4.BackgroundTransparency = 1
    TextLabel4.Text = "ADMIN ABUSE PANEL"
    TextLabel4.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel4.Font = Enum.Font.GothamBlack
    TextLabel4.TextScaled = true
    TextLabel4.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel4.ZIndex = 201
    TextLabel4.Parent = AdminAbusePanel

    local UITextSizeConstraint7 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint7.MinTextSize = 16
    UITextSizeConstraint7.MaxTextSize = 30
    UITextSizeConstraint7.Parent = TextLabel4

    local TextButton = Instance.new("TextButton")

    TextButton.Size = UDim2.new(0, 58, 0, 48)
    TextButton.Position = UDim2.new(1, -70, 0, 10)
    TextButton.BackgroundColor3 = v6
    TextButton.BorderSizePixel = 0
    TextButton.Text = "X"
    TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextButton.Font = Enum.Font.GothamBlack
    TextButton.TextScaled = true
    TextButton.ZIndex = 202
    TextButton.Parent = AdminAbusePanel

    local UICorner7 = Instance.new("UICorner")

    UICorner7.CornerRadius = UDim.new(0, 12)
    UICorner7.Parent = TextButton

    local TextLabel5 = Instance.new("TextLabel")

    TextLabel5.Size = UDim2.new(0, 90, 0, 34)
    TextLabel5.Position = UDim2.new(0, 18, 0, 70)
    TextLabel5.BackgroundTransparency = 1
    TextLabel5.Text = "SCOPE:"
    TextLabel5.TextColor3 = Color3.fromRGB(195, 195, 205)
    TextLabel5.Font = Enum.Font.GothamBold
    TextLabel5.TextScaled = true
    TextLabel5.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel5.ZIndex = 201
    TextLabel5.Parent = AdminAbusePanel

    local UITextSizeConstraint8 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint8.MinTextSize = 10
    UITextSizeConstraint8.MaxTextSize = 16
    UITextSizeConstraint8.Parent = TextLabel5

    local TextButton2 = Instance.new("TextButton")

    TextButton2.Size = UDim2.new(0, 130, 0, 36)
    TextButton2.Position = UDim2.new(0, 105, 0, 68)
    TextButton2.BorderSizePixel = 0
    TextButton2.Text = "SERVER"
    TextButton2.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextButton2.Font = Enum.Font.GothamBlack
    TextButton2.TextScaled = true
    TextButton2.ZIndex = 202
    TextButton2.Parent = AdminAbusePanel

    local UICorner8 = Instance.new("UICorner")

    UICorner8.CornerRadius = UDim.new(0, 9)
    UICorner8.Parent = TextButton2

    local v22 = TextButton2:Clone()

    v22.Position = UDim2.new(0, 245, 0, 68)
    v22.Text = "GLOBAL"
    v22.Parent = AdminAbusePanel

    local TextLabel6 = Instance.new("TextLabel")

    TextLabel6.Size = UDim2.new(0, 190, 0, 34)
    TextLabel6.Position = UDim2.new(0, 385, 0, 69)
    TextLabel6.BackgroundTransparency = 1
    TextLabel6.Text = ""
    TextLabel6.TextColor3 = Color3.fromRGB(255, 195, 75)
    TextLabel6.Font = Enum.Font.GothamBold
    TextLabel6.TextScaled = true
    TextLabel6.TextWrapped = true
    TextLabel6.ZIndex = 201
    TextLabel6.Parent = AdminAbusePanel

    local UITextSizeConstraint9 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint9.MinTextSize = 8
    UITextSizeConstraint9.MaxTextSize = 13
    UITextSizeConstraint9.Parent = TextLabel6

    local TextButton3 = Instance.new("TextButton")

    TextButton3.Size = UDim2.new(0.5, -22, 0, 40)
    TextButton3.Position = UDim2.new(0, 18, 0, 116)
    TextButton3.BorderSizePixel = 0
    TextButton3.Text = "MANUAL"
    TextButton3.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextButton3.Font = Enum.Font.GothamBlack
    TextButton3.TextScaled = true
    TextButton3.ZIndex = 202
    TextButton3.Parent = AdminAbusePanel

    local UICorner9 = Instance.new("UICorner")

    UICorner9.CornerRadius = UDim.new(0, 10)
    UICorner9.Parent = TextButton3

    local v23 = TextButton3:Clone()

    v23.Position = UDim2.new(0.5, 4, 0, 116)
    v23.Text = "AUTO 30 MIN"
    v23.Parent = AdminAbusePanel

    local Frame = Instance.new("Frame")

    Frame.Size = UDim2.new(1, -36, 1, -212)
    Frame.Position = UDim2.new(0, 18, 0, 168)
    Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    Frame.BackgroundTransparency = 0.15
    Frame.BorderSizePixel = 0
    Frame.ZIndex = 201
    Frame.Parent = AdminAbusePanel

    local UICorner10 = Instance.new("UICorner")

    UICorner10.CornerRadius = UDim.new(0, 13)
    UICorner10.Parent = Frame

    local Frame2 = Instance.new("Frame")

    Frame2.Size = UDim2.fromScale(1, 1)
    Frame2.BackgroundTransparency = 1
    Frame2.ZIndex = 202
    Frame2.Parent = Frame

    local Frame3 = Instance.new("Frame")

    Frame3.Size = UDim2.fromScale(1, 1)
    Frame3.BackgroundTransparency = 1
    Frame3.Visible = false
    Frame3.ZIndex = 202
    Frame3.Parent = Frame

    local TextLabel7 = Instance.new("TextLabel")

    TextLabel7.Size = UDim2.new(1, -36, 0, 30)
    TextLabel7.Position = UDim2.new(0, 18, 1, -38)
    TextLabel7.BackgroundTransparency = 1
    TextLabel7.Text = ""
    TextLabel7.TextColor3 = Color3.fromRGB(130, 255, 165)
    TextLabel7.Font = Enum.Font.GothamBold
    TextLabel7.TextScaled = true
    TextLabel7.ZIndex = 202
    TextLabel7.Parent = AdminAbusePanel

    local UITextSizeConstraint10 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint10.MinTextSize = 9
    UITextSizeConstraint10.MaxTextSize = 14
    UITextSizeConstraint10.Parent = TextLabel7

    local function makeButton(p1, p2, p3, p4, p5, p6, p7)
        local TextButton = Instance.new("TextButton")

        TextButton.Size = UDim2.new(0, p5, 0, p6)
        TextButton.Position = UDim2.new(0, p3, 0, p4)
        TextButton.BackgroundColor3 = v6
        TextButton.BorderSizePixel = 0
        TextButton.Text = p2
        TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextButton.Font = Enum.Font.GothamBlack
        TextButton.TextScaled = true
        TextButton.TextWrapped = true
        TextButton.ZIndex = 203
        TextButton.Parent = p1

        local UICorner = Instance.new("UICorner")

        UICorner.CornerRadius = UDim.new(0, 9)
        UICorner.Parent = TextButton

        local UITextSizeConstraint = Instance.new("UITextSizeConstraint")

        UITextSizeConstraint.MinTextSize = 9
        UITextSizeConstraint.MaxTextSize = 15
        UITextSizeConstraint.Parent = TextButton

        return TextButton
    end

    local function flashActionButton(p1)
        if p1 and p1.Parent then
            p1.BackgroundColor3 = v8
            task.delay(0.18, function()
                if not (p1 and p1.Parent) then
                    return
                end

                p1.BackgroundColor3 = v6
            end)
        end
    end

    local v24 = makeButton(Frame2, "START MANUAL 30M", 12, 12, 255, 44, Color3.fromRGB(35, 165, 85))
    local v25 = makeButton(Frame2, "STOP ADMIN ABUSE", 278, 12, 255, 44, Color3.fromRGB(185, 45, 50))
    local v26 = makeButton(Frame2, "3X BOXES: OFF", 12, 68, 255, 44, Color3.fromRGB(105, 75, 220))
    local v27 = makeButton(Frame2, "TREE RUSH: OFF", 278, 68, 255, 44, Color3.fromRGB(40, 150, 75))
    local TextLabel8 = Instance.new("TextLabel")

    TextLabel8.Size = UDim2.new(1, -24, 0, 24)
    TextLabel8.Position = UDim2.new(0, 12, 0, 122)
    TextLabel8.BackgroundTransparency = 1
    TextLabel8.Text = "EVENT COIN DROPS"
    TextLabel8.TextColor3 = Color3.fromRGB(255, 215, 75)
    TextLabel8.Font = Enum.Font.GothamBlack
    TextLabel8.TextScaled = true
    TextLabel8.ZIndex = 203
    TextLabel8.Parent = Frame2

    local UITextSizeConstraint11 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint11.MinTextSize = 10
    UITextSizeConstraint11.MaxTextSize = 16
    UITextSizeConstraint11.Parent = TextLabel8

    local t2 = { "+100K EC", "+500K EC", "+1M EC", "+2M EC", "+5M EC" }

    for i, v in ipairs({ 100000, 500000, 1000000, 2000000, 5000000 }) do
        local v28, v29

        if i <= 3 then
            v28 = 12 + (i - 1) * 176
            v29 = 152
        else
            v28 = if i == 4 then 12 else 278
            v29 = 202
        end

        local v32 = makeButton(Frame2, t2[i], v28, v29, if i <= 3 then 168 else 255, 40, Color3.fromRGB(190, 135, 25))

        v32.MouseButton1Click:Connect(function()
            local v1 = v32

            if not (v1 and v1.Parent) then
                AdminAbuseRemote:FireServer("GiveEventCoins", {
                    Amount = v
                })

                return
            end

            v1.BackgroundColor3 = v8
            task.delay(0.18, function()
                if not (v1 and v1.Parent) then
                    return
                end

                v1.BackgroundColor3 = v6
            end)
            AdminAbuseRemote:FireServer("GiveEventCoins", {
                Amount = v
            })
        end)
    end

    local TextLabel9 = Instance.new("TextLabel")

    TextLabel9.Size = UDim2.new(1, -24, 0, 24)
    TextLabel9.Position = UDim2.new(0, 12, 0, 254)
    TextLabel9.BackgroundTransparency = 1
    TextLabel9.Text = "ANNOUNCEMENTS"
    TextLabel9.TextColor3 = Color3.fromRGB(135, 205, 255)
    TextLabel9.Font = Enum.Font.GothamBlack
    TextLabel9.TextScaled = true
    TextLabel9.ZIndex = 203
    TextLabel9.Parent = Frame2

    local UITextSizeConstraint12 = Instance.new("UITextSizeConstraint")

    UITextSizeConstraint12.MinTextSize = 10
    UITextSizeConstraint12.MaxTextSize = 16
    UITextSizeConstraint12.Parent = TextLabel9

    local v33 = makeButton(Frame2, "HELLO", 12, 282, 124, 39, Color3.fromRGB(50, 125, 190))
    local v34 = makeButton(Frame2, "EC SOON", 144, 282, 124, 39, Color3.fromRGB(190, 135, 25))
    local v35 = makeButton(Frame2, "5 MIN LEFT", 276, 282, 124, 39, Color3.fromRGB(210, 90, 35))
    local v36 = makeButton(Frame2, "FINAL DROP", 408, 282, 124, 39, Color3.fromRGB(190, 135, 25))

    v33.MouseButton1Click:Connect(function()
        local v1 = v33

        if not (v1 and v1.Parent) then
            AdminAbuseRemote:FireServer("AnnouncementPreset", {
                Preset = "HELLO"
            })

            return
        end

        v1.BackgroundColor3 = v8
        task.delay(0.18, function()
            if not (v1 and v1.Parent) then
                return
            end

            v1.BackgroundColor3 = v6
        end)
        AdminAbuseRemote:FireServer("AnnouncementPreset", {
            Preset = "HELLO"
        })
    end)
    v34.MouseButton1Click:Connect(function()
        local v1 = v34

        if not (v1 and v1.Parent) then
            AdminAbuseRemote:FireServer("AnnouncementPreset", {
                Preset = "EC_SOON"
            })

            return
        end

        v1.BackgroundColor3 = v8
        task.delay(0.18, function()
            if not (v1 and v1.Parent) then
                return
            end

            v1.BackgroundColor3 = v6
        end)
        AdminAbuseRemote:FireServer("AnnouncementPreset", {
            Preset = "EC_SOON"
        })
    end)
    v35.MouseButton1Click:Connect(function()
        local v1 = v35

        if not (v1 and v1.Parent) then
            AdminAbuseRemote:FireServer("AnnouncementPreset", {
                Preset = "FIVE_MINUTES"
            })

            return
        end

        v1.BackgroundColor3 = v8
        task.delay(0.18, function()
            if not (v1 and v1.Parent) then
                return
            end

            v1.BackgroundColor3 = v6
        end)
        AdminAbuseRemote:FireServer("AnnouncementPreset", {
            Preset = "FIVE_MINUTES"
        })
    end)
    v36.MouseButton1Click:Connect(function()
        local v1 = v36

        if not (v1 and v1.Parent) then
            AdminAbuseRemote:FireServer("AnnouncementPreset", {
                Preset = "FINAL_DROP"
            })

            return
        end

        v1.BackgroundColor3 = v8
        task.delay(0.18, function()
            if not (v1 and v1.Parent) then
                return
            end

            v1.BackgroundColor3 = v6
        end)
        AdminAbuseRemote:FireServer("AnnouncementPreset", {
            Preset = "FINAL_DROP"
        })
    end)

    local TextLabel10 = Instance.new("TextLabel")

    TextLabel10.Size = UDim2.new(1, -30, 0, 205)
    TextLabel10.Position = UDim2.new(0, 15, 0, 16)
    TextLabel10.BackgroundTransparency = 1
    TextLabel10.RichText = true
    TextLabel10.TextWrapped = true
    TextLabel10.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel10.TextYAlignment = Enum.TextYAlignment.Top
    TextLabel10.Font = Enum.Font.GothamBold
    TextLabel10.TextSize = 16
    TextLabel10.TextColor3 = Color3.fromRGB(220, 220, 225)
    TextLabel10.ZIndex = 203
    TextLabel10.Text = "<font color=\"#FF5666\"><b>30 MIN ADMIN ABUSE</b></font>\n\226\128\162 3X BOXES for the full event\n\226\128\162 TREE RUSH: a 3-hour tree grows in about 10 minutes\n\226\128\162 Automatic English announcements\n\226\128\162 Event Coin drops during the event\n<font color=\"#FFD34F\"><b>TOTAL AUTO DROPS: 5,000,000 EVENT COINS</b></font>\n\nPlayers choose their own events from the Event Shop."
    TextLabel10.Parent = Frame3

    local v37 = makeButton(Frame3, "START 30 MIN AUTO SEQUENCE", 15, 236, 518, 52, Color3.fromRGB(195, 45, 60))
    local v38 = makeButton(Frame3, "STOP ADMIN ABUSE", 15, 300, 518, 48, Color3.fromRGB(120, 35, 40))

    local function updateScopeButtons()
        local v1 = t.Active and tostring(t.Scope or "SERVER") or v3

        TextButton2.BackgroundColor3 = v1 == "SERVER" and v7 or v6
        v22.BackgroundColor3 = v1 == "GLOBAL" and v7 or v6

        if v2 then
            TextLabel6.Text = "STUDIO: GLOBAL = LOCAL TEST"

            return
        end

        TextLabel6.Text = if t.Active then "ACTIVE: " .. v1 or "" else ""
    end

    local function updateEffectButtons()
        local v1 = t.Active and t.TripleBoxes == true
        local Active = t.Active

        if Active then
            Active = (tonumber(t.TreeMultiplier) or 1) > 1
        end

        v26.Text = if v1 then "3X BOXES: ON" else "3X BOXES: OFF"
        v26.BackgroundColor3 = v1 and v7 or v6
        v27.Text = if Active then "TREE RUSH: ON" else "TREE RUSH: OFF"
        v27.BackgroundColor3 = Active and v7 or v6
    end

    local function updateRunButtons()
        local isActive = t.Active == true
        local v1 = if isActive then t.AutoSequence == true else isActive

        v24.BackgroundColor3 = (if isActive then not v1 else isActive) and v7 or v6
        v37.BackgroundColor3 = v1 and v7 or v6
        v25.BackgroundColor3 = v6
        v38.BackgroundColor3 = v6
        OpenAdminAbusePanel.BackgroundColor3 = isActive and v7 or v6
        SubTitle.Text = if isActive then "LIVE" else "CONTROL"
        SubTitle.TextColor3 = isActive and Color3.fromRGB(255, 225, 228) or Color3.fromRGB(205, 205, 215)
        StateDot.BackgroundColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(155, 155, 165)
        v17.Transparency = if isActive then 0.25 else 0.5
    end

    local function showTab(p1)
        v4 = if p1 == "AUTO" then "AUTO" else "MANUAL"
        Frame2.Visible = v4 == "MANUAL"
        Frame3.Visible = v4 == "AUTO"
        TextButton3.BackgroundColor3 = v4 == "MANUAL" and v7 or v6
        v23.BackgroundColor3 = v4 == "AUTO" and v7 or v6
    end

    local v39 = "MANUAL"

    Frame2.Visible = if v39 == "MANUAL" then true else false
    Frame3.Visible = if v39 == "AUTO" then true else false
    TextButton3.BackgroundColor3 = v39 == "MANUAL" and v7 or v6
    v23.BackgroundColor3 = v39 == "AUTO" and v7 or v6
    TextButton2.MouseButton1Click:Connect(function()
        if t.Active then
            return
        end

        v3 = "SERVER"

        local v1 = t.Active and tostring(t.Scope or "SERVER") or v3

        TextButton2.BackgroundColor3 = v1 == "SERVER" and v7 or v6
        v22.BackgroundColor3 = v1 == "GLOBAL" and v7 or v6

        if v2 then
            TextLabel6.Text = "STUDIO: GLOBAL = LOCAL TEST"

            return
        end

        TextLabel6.Text = if t.Active then "ACTIVE: " .. v1 or "" else ""
    end)
    v22.MouseButton1Click:Connect(function()
        if t.Active then
            return
        end

        v3 = "GLOBAL"

        local v1 = t.Active and tostring(t.Scope or "SERVER") or v3

        TextButton2.BackgroundColor3 = v1 == "SERVER" and v7 or v6
        v22.BackgroundColor3 = v1 == "GLOBAL" and v7 or v6

        if v2 then
            TextLabel6.Text = "STUDIO: GLOBAL = LOCAL TEST"

            return
        end

        TextLabel6.Text = if t.Active then "ACTIVE: " .. v1 or "" else ""
    end)
    TextButton3.MouseButton1Click:Connect(function()
        v39 = "MANUAL"
        Frame2.Visible = v39 == "MANUAL"
        Frame3.Visible = v39 == "AUTO"
        TextButton3.BackgroundColor3 = v39 == "MANUAL" and v7 or v6
        v23.BackgroundColor3 = v39 == "AUTO" and v7 or v6
    end)
    v23.MouseButton1Click:Connect(function()
        v39 = "AUTO"
        Frame2.Visible = v39 == "MANUAL"
        Frame3.Visible = v39 == "AUTO"
        TextButton3.BackgroundColor3 = v39 == "MANUAL" and v7 or v6
        v23.BackgroundColor3 = v39 == "AUTO" and v7 or v6
    end)
    OpenAdminAbusePanel.Activated:Connect(function()
        AdminAbusePanel.Visible = not AdminAbusePanel.Visible
    end)
    TextButton.MouseButton1Click:Connect(function()
        AdminAbusePanel.Visible = false
    end)
    v24.MouseButton1Click:Connect(function()
        AdminAbuseRemote:FireServer("StartManual", {
            Scope = v3
        })
    end)
    v25.MouseButton1Click:Connect(function()
        AdminAbuseRemote:FireServer("Stop")
    end)
    v38.MouseButton1Click:Connect(function()
        AdminAbuseRemote:FireServer("Stop")
    end)
    v37.MouseButton1Click:Connect(function()
        AdminAbuseRemote:FireServer("StartAuto", {
            Scope = v3
        })
    end)
    v26.MouseButton1Click:Connect(function()
        local t2 = {}

        t2.Enabled = not (t.TripleBoxes == true)
        AdminAbuseRemote:FireServer("SetTripleBoxes", t2)
    end)
    v27.MouseButton1Click:Connect(function()
        local t2 = {}

        t2.Enabled = not ((tonumber(t.TreeMultiplier) or 1) > 1)
        AdminAbuseRemote:FireServer("SetTreeRush", t2)
    end)

    local function applyState(p1)
        local v1 = if type(p1) == "table" and p1 then p1 else {}
        local t2 = {}

        t2.Active = v1.Active == true
        t2.Scope = tostring(v1.Scope or "SERVER")
        t2.EndsAt = tonumber(v1.EndsAt) or 0
        t2.StartedAt = tonumber(v1.StartedAt) or 0
        t2.TripleBoxes = v1.TripleBoxes == true
        t2.TreeMultiplier = math.max(1, tonumber(v1.TreeMultiplier) or 1)
        t2.AutoSequence = v1.AutoSequence == true
        t = t2

        if t2.Active then
            v3 = t2.Scope
        end

        local v4 = t2.Active and tostring(t2.Scope or "SERVER") or v3

        TextButton2.BackgroundColor3 = v4 == "SERVER" and v7 or v6
        v22.BackgroundColor3 = v4 == "GLOBAL" and v7 or v6

        if v2 then
            TextLabel6.Text = "STUDIO: GLOBAL = LOCAL TEST"
        else
            TextLabel6.Text = if t2.Active then "ACTIVE: " .. v4 or "" else ""
        end

        local v12 = t2.Active and t2.TripleBoxes == true
        local Active = t2.Active

        if Active then
            Active = (tonumber(t2.TreeMultiplier) or 1) > 1
        end

        v26.Text = if v12 then "3X BOXES: ON" else "3X BOXES: OFF"
        v26.BackgroundColor3 = v12 and v7 or v6
        v27.Text = if Active then "TREE RUSH: ON" else "TREE RUSH: OFF"
        v27.BackgroundColor3 = Active and v7 or v6
        updateRunButtons()
    end

    AdminAbuseRemote.OnClientEvent:Connect(function(p1, p2, p3, p4)
        if p1 == "State" then
            applyState(p2)

            return
        end

        if p1 == "AdminAccess" then
            v1 = p2 == true
            v2 = p3 == true
            OpenAdminAbusePanel.Visible = v1

            if not v1 then
                AdminAbusePanel.Visible = false
            end

            local v32 = t.Active and tostring(t.Scope or "SERVER") or v3

            TextButton2.BackgroundColor3 = v32 == "SERVER" and v7 or v6
            v22.BackgroundColor3 = v32 == "GLOBAL" and v7 or v6

            if v2 then
                TextLabel6.Text = "STUDIO: GLOBAL = LOCAL TEST"
            else
                TextLabel6.Text = if t.Active then "ACTIVE: " .. v32 or "" else ""
            end

            updateRunButtons()
        else
            if p1 == "Announcement" then
                showAnnouncement(p2, p3, p4)

                return
            end

            if p1 ~= "AdminResult" then
                return
            end

            local v12 = TextLabel7

            v12.TextColor3 = (if p2 == true then true else false) and Color3.fromRGB(130, 255, 165) or Color3.fromRGB(255, 105, 105)
            TextLabel7.Text = tostring(p3 or "")
            addLog("[ADMIN-ABUSE] " .. (p2 == true and "[✓] " or "[!] ") .. tostring(p3 or ""))

            local Text = TextLabel7.Text

            task.delay(3.5, function()
                if TextLabel7.Text ~= Text then
                    return
                end

                TextLabel7.Text = ""
            end)
        end
    end)
    task.spawn(function()
        while AdminAbuseGui.Parent do
            task.wait(0.2)

            if t.Active and t.EndsAt > os.time() then
                AdminAbuseStatus.Visible = true

                local v5 = math.max(0, (math.floor(tonumber(t.EndsAt - os.time()) or 0)))

                TextLabel.Text = "ADMIN ABUSE  \226\128\162  " .. string.format("%02d:%02d", math.floor(v5 / 60), v5 % 60)

                local t2 = {}

                if t.TripleBoxes then
                    table.insert(t2, "3X BOXES")
                end

                if t.TreeMultiplier > 1 then
                    table.insert(t2, "TREE RUSH")
                end

                TextLabel2.Text = table.concat(t2, "  \226\128\162  ")
                TextLabel2.Visible = #t2 > 0
                v11.Color = t.Scope == "GLOBAL" and Color3.fromRGB(255, 75, 85) or Color3.fromRGB(80, 180, 255)

                continue
            end

            AdminAbuseStatus.Visible = false
        end
    end)
    AdminAbuseRemote:FireServer("RequestState")
    addLog("[ADMIN-ABUSE] Painel carregado")

    local adminMaskActive = false

    local function forceAdminMask(enabled)
        if enabled then
            v1 = true
            v2 = false
            adminMaskActive = true
            OpenAdminAbusePanel.Visible = true
            AdminAbusePanel.Visible = false

            local v32 = t.Active and tostring(t.Scope or "SERVER") or v3
            TextButton2.BackgroundColor3 = v32 == "SERVER" and v7 or v6
            v22.BackgroundColor3 = v32 == "GLOBAL" and v7 or v6
            TextLabel6.Text = if t.Active then "ACTIVE: " .. v32 or "" else ""
            updateRunButtons()

            addLog("[ADMIN-ABUSE] [*] Máscara de Admin ATIVADA (client-side)")
            addLog("[BYPASS] Admin local ativado - testando exploits...")

            -- BYPASS ADICIONAL: Fazer bypass permanente enquanto máscara ativa
            task.spawn(function()
                local bypassActive = enabled
                while bypassActive and adminMaskActive do
                    -- Forçar v1=true a cada frame pra garantir que admin fica ativado
                    if adminMaskActive then
                        v1 = true
                        OpenAdminAbusePanel.Visible = true
                    end
                    task.wait(0.1)
                end
            end)
        else
            v1 = false
            adminMaskActive = false
            OpenAdminAbusePanel.Visible = false
            AdminAbusePanel.Visible = false
            updateRunButtons()
            addLog("[ADMIN-ABUSE] Máscara de Admin DESATIVADA")
        end
    end

    -- Interceptar clicks dos botões do painel quando em modo máscara admin
    local originalV24Click = v24.MouseButton1Click
    local originalV25Click = v25.MouseButton1Click
    local originalV26Click = v26.MouseButton1Click
    local originalV27Click = v27.MouseButton1Click
    local originalV37Click = v37.MouseButton1Click
    local originalV38Click = v38.MouseButton1Click

    v24.MouseButton1Click:Connect(function()
        t.Active = true
        t.Scope = v3
        t.AutoSequence = false
        t.EndsAt = os.time() + 1800
        t.StartedAt = os.time()
        applyState(t)
        addLog("[ADMIN-ABUSE] Admin Abuse MANUAL iniciado")
        -- BYPASS: SEMPRE enviar pro servidor também (bypass validation)
        pcall(function() AdminAbuseRemote:FireServer("StartManual", { Scope = v3 }) end)
    end)

    v25.MouseButton1Click:Connect(function()
        t.Active = false
        applyState(t)
        addLog("[ADMIN-ABUSE] Admin Abuse parado")
        -- BYPASS: SEMPRE enviar pro servidor também
        pcall(function() AdminAbuseRemote:FireServer("Stop") end)
    end)

    v26.MouseButton1Click:Connect(function()
        t.TripleBoxes = not (t.TripleBoxes == true)
        applyState(t)
        addLog("[ADMIN-ABUSE] 3X BOXES: " .. tostring(t.TripleBoxes))
        -- BYPASS: SEMPRE enviar pro servidor também
        pcall(function()
            local t2 = {}
            t2.Enabled = not (t.TripleBoxes == false)
            AdminAbuseRemote:FireServer("SetTripleBoxes", t2)
        end)
    end)

    v27.MouseButton1Click:Connect(function()
        t.TreeMultiplier = not ((tonumber(t.TreeMultiplier) or 1) > 1) and 3 or 1
        applyState(t)
        addLog("[ADMIN-ABUSE] TREE RUSH: " .. tostring(t.TreeMultiplier > 1))
        -- BYPASS: SEMPRE enviar pro servidor também
        pcall(function()
            local t2 = {}
            t2.Enabled = not ((tonumber(t.TreeMultiplier) or 1) <= 1)
            AdminAbuseRemote:FireServer("SetTreeRush", t2)
        end)
    end)

    v37.MouseButton1Click:Connect(function()
        t.Active = true
        t.AutoSequence = true
        t.Scope = v3
        t.EndsAt = os.time() + 1800
        t.StartedAt = os.time()
        applyState(t)
        addLog("[ADMIN-ABUSE] Admin Abuse AUTO (30min) iniciado")
        -- BYPASS: SEMPRE enviar pro servidor também
        pcall(function() AdminAbuseRemote:FireServer("StartAuto", { Scope = v3 }) end)
    end)

    v38.MouseButton1Click:Connect(function()
        t.Active = false
        applyState(t)
        addLog("[ADMIN-ABUSE] Admin Abuse parado")
        -- BYPASS: SEMPRE enviar pro servidor também
        pcall(function() AdminAbuseRemote:FireServer("Stop") end)
    end)

    return {
        toggle = function()
            AdminAbusePanel.Visible = not AdminAbusePanel.Visible
        end,
        isAvailable = function() return true end,
        forceAdminMask = forceAdminMask,
    }
end

local AdminAbusePanelFeature = buildAdminAbusePanelFeature()

-- ========================================
-- ALERTA: glitterrainbow/limited
-- ========================================

local function buildAlertFeature()

local function equipBestSlimes()
    if not Remotes.equipBestInventory then
        addLog("[!] EquipBestInventory não encontrado")
        return
    end
    pcall(function() Remotes.equipBestInventory:FireServer() end)
    addLog("[✓] EquipBestInventory disparado")
end

local function playDivineAlert()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 1
    sound.Parent = playerGui
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end

local playingDivineSequence = false
local alertKeywords = { "limitedrainbow" }

local function playDivineAlertSequence(itemName, itemValue)
    if playingDivineSequence then return end
    playingDivineSequence = true

    task.spawn(function()
        for i = 1, 3 do
            playDivineAlert()
            task.wait(0.6)
        end

        addLog("[*] " .. tostring(itemName) .. " alertado 3x, equipando os melhores slimes...")
        if equipBestSlimes then pcall(equipBestSlimes) end

        if webhookToggles.limited and webhookToggles.limited.enabled then
            sendDiscordWebhook("🌟 Item raro encontrado!", tostring(itemName) .. " (valor: " .. tostring(itemValue) .. ")", Color3.fromRGB(255, 200, 0))
        end

        playingDivineSequence = false
    end)
end

if Remotes.boxStarsReveal then
    Remotes.boxStarsReveal.OnClientEvent:Connect(function(index, revealed, rarity, name, value)
        if revealed and name then
            local lowerName = name:lower()
            for _, keyword in ipairs(alertKeywords) do
                if lowerName:find(keyword) then
                    print("[ALERTA] Item revelado: " .. name .. " (valor: " .. tostring(value) .. ")")
                    playDivineAlertSequence(name, value)
                    break
                end
            end
        end
    end)
end

return {
    keywords = alertKeywords,
    equipBest = equipBestSlimes,
}
end

local AlertFeature = buildAlertFeature()

-- ========================================
-- VENDER TODOS OS SLIMES
-- ========================================

local function buildSellAllFeature()

local latestSellList = nil

if Remotes.sellSlimeOpen then
    Remotes.sellSlimeOpen.OnClientEvent:Connect(function(list)
        latestSellList = list
    end)
end

local function findSellSlimePrompt()
    local direct = Workspace:FindFirstChild("SellSlimePrompt", true)
    if direct and direct:IsA("ProximityPrompt") then return direct end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "SellSlimePrompt" then return obj end
    end
    return nil
end

local function findSellSlimeFrame()
    return playerGui:FindFirstChild("SellSlimeFrame", true)
end

local sellingAll = false

local function sellAllSlimesBlocking()
    if not Remotes.sellSlimeAction then
        addLog("[!] SellSlimeAction não encontrado")
        return
    end
    if sellingAll then
        addLog("[!] Já está vendendo, aguarde terminar")
        return
    end
    if not latestSellList or #latestSellList == 0 then
        addLog("[!] Nenhuma lista de slimes recebida ainda.")
        return
    end

    sellingAll = true
    local countBefore = #latestSellList
    addLog("[*] Vendendo todos os " .. countBefore .. " slime(s) de uma vez...")

    -- O v4 adicionou um botão "SELL ALL" de verdade no jogo -- em vez de
    -- vender item por item (FireServer("Sell", index), um de cada vez,
    -- esperando a lista encolher a cada chamada -- lento e o motivo do
    -- loop com stuckCount/timeout antigo), agora é só uma chamada:
    -- FireServer("SellAll") vende o inventário inteiro no servidor de
    -- uma vez, exatamente como o botão SELL ALL do próprio jogo
    -- (achado no .rbxlx do v4, dentro de setupSellSlimeUI -- o botão só
    -- dispara SellSlimeActionEvent:FireServer("SellAll") e mais nada).
    pcall(function() Remotes.sellSlimeAction:FireServer("SellAll") end)

    -- Espera a lista esvaziar (ou até 3s -- folga generosa, o botão real
    -- do jogo já considera a venda concluída depois de 1.5s) antes de
    -- seguir pra fechar o painel.
    local start = tick()
    while latestSellList and #latestSellList > 0 and (tick() - start) < 3 do
        task.wait(0.05)
    end

    local sold = countBefore - (latestSellList and #latestSellList or 0)
    addLog("[+] Venda finalizada! Total vendido: " .. sold)
    sellingAll = false

    task.wait(0.2)
    local sellFrame = findSellSlimeFrame()
    if sellFrame then
        local closeBtn = sellFrame:FindFirstChild("Close", true)
        if closeBtn and closeBtn:IsA("GuiButton") then
            local ok = pcall(function() firesignal(closeBtn.MouseButton1Click) end)
            if not ok then sellFrame.Visible = false end
        else
            sellFrame.Visible = false
        end
    end

    local closeStart = tick()
    while true do
        local frame = findSellSlimeFrame()
        if not frame or not frame.Visible then break end
        if (tick() - closeStart) > 3 then
            addLog("[!] Painel de venda não confirmou fechamento, seguindo mesmo assim")
            break
        end
        task.wait(0.1)
    end
end

local function autoSellAllSlimesBlocking()
    if sellingAll then
        addLog("[!] Já está vendendo, aguarde terminar")
        return
    end

    local prompt = findSellSlimePrompt()
    if not prompt then
        addLog("[!] SellSlimePrompt não encontrado no Workspace")
        return
    end

    local promptPos = getPromptWorldPosition(prompt)
    local originalCFrame = nil
    if promptPos then
        originalCFrame = teleportPlayerTo(promptPos)
        addLog("[*] Teleportado até a área de venda")
        task.wait(0.5)
    end

    latestSellList = nil
    local fired = triggerPromptGeneric(prompt)

    if not fired then
        addLog("[!] Não consegui disparar o prompt de venda")
        teleportPlayerBack(originalCFrame)
        return
    end

    addLog("[*] Prompt disparado, aguardando lista de slimes...")

    local start = tick()
    while not latestSellList and (tick() - start) < 5 do
        task.wait(0.05)
    end

    if not latestSellList then
        addLog("[!] Timeout esperando SellSlimeOpen")
        teleportPlayerBack(originalCFrame)
        return
    end

    sellAllSlimesBlocking()

    task.wait(0.3)
    teleportPlayerBack(originalCFrame)
    addLog("[*] Voltou pra posição original (venda)")
end

local function autoSellAllSlimes()
    task.spawn(autoSellAllSlimesBlocking)
end

return {
    sellAll = autoSellAllSlimesBlocking,
    sellAllAsync = autoSellAllSlimes,
}
end

local SellAll = buildSellAllFeature()

-- ========================================
-- EVENT SHOP (compartilhado entre a aba Ramp e Bata o Slime)
-- ========================================

local EVENT_DURATION_SECONDS = 600
local EVENT_DURATION_BUFFER_SECONDS = 10

local latestEventShopPayload = nil
if Remotes.eventShopUpdate then
    Remotes.eventShopUpdate.OnClientEvent:Connect(function(payload)
        latestEventShopPayload = payload
    end)
end

local function findEventShopPrompt()
    local direct = Workspace:FindFirstChild("EventShopPrompt", true)
    if direct and direct:IsA("ProximityPrompt") then return direct end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "EventShopPrompt" then return obj end
    end
    return nil
end

-- Move o painel FÍSICO do MiniGame1Button (o mesmo trigger usado tanto
-- pela Memória quanto pelo Bata o Slime) pra cima do EventShopPrompt --
-- isso é 100% client-side (só a SUA tela vê ele nessa posição nova), mas
-- como o Roblox checa a distância do ProximityPrompt usando a posição
-- RENDERIZADA no seu client (é por isso que o prompt "E" aparece/some
-- sozinho conforme você anda), mover a Part localmente é o suficiente
-- pra conseguir disparar o prompt sem precisar sair do lugar. Agora é
-- um toggle (era automático antes) -- e desliga sozinho quando o Bata o
-- Slime inicia, porque o loop dele já ativa o evento repetidamente sem
-- teleportar (noTeleport=true) e o painel grudado no shop atrapalha.
local function buildMiniGameStickFeature()
    local enabled = false
    local saved = nil
    local statusLabel = nil

    local function setStatus(text, color)
        if statusLabel then
            statusLabel.Text = text
            statusLabel.TextColor3 = color
        end
    end

    local function enable()
        if enabled then return end

        local prompt = findEventShopPrompt()
        if not prompt then
            addLog("[MINIGAME] [!] EventShopPrompt não encontrado, não deu pra mover o painel de minigames")
            return
        end
        local shopPos = getPromptWorldPosition(prompt)
        if not shopPos then
            addLog("[MINIGAME] [!] Não consegui ler a posição do EventShopPrompt")
            return
        end

        local part = miniGameButton:IsA("BasePart") and miniGameButton or miniGameButton:FindFirstChildWhichIsA("BasePart", true)
        if not part then
            addLog("[MINIGAME] [!] MiniGame1Button não tem nenhuma BasePart pra mover")
            return
        end

        saved = { part = part, cframe = part.CFrame }
        local currentRotation = part.CFrame - part.CFrame.Position
        part.CFrame = CFrame.new(shopPos) * currentRotation

        enabled = true
        setStatus("Status: GRUDADO NO EVENTO", Color3.fromRGB(0, 220, 220))
        addLog("[MINIGAME] [✓] Painel de minigames grudado no shop de eventos (só na sua tela)")
    end

    local function disable()
        if not enabled then return end

        if saved and saved.part.Parent then
            saved.part.CFrame = saved.cframe
        end
        saved = nil

        enabled = false
        setStatus("Status: DESLIGADO (posição original)", Color3.fromRGB(100, 200, 100))
        addLog("[MINIGAME] Painel de minigames voltou pra posição original")
    end

    local function toggle()
        if enabled then disable() else enable() end
        return enabled
    end

    return {
        toggle = toggle,
        enable = enable,
        disable = disable,
        isEnabled = function() return enabled end,
        setStatusLabel = function(lbl) statusLabel = lbl end,
    }
end

local MiniGameStick = buildMiniGameStickFeature()

local function activateMostExpensiveEvent(stayAtShop, noTeleport, eventOverride)
    if not Remotes.eventShopAction then
        addLog("[EVENTO] [!] EventShopAction não encontrado")
        return false
    end

    local event = eventOverride or findMostExpensiveEvent()
    if not event then
        addLog("[EVENTO] [!] Não consegui achar o evento pra ativar")
        return false
    end

    addLog("[EVENTO] [*] Ativando evento: " .. tostring(event.Id) .. " (custo " .. tostring(event.Cost) .. ")")

    pcall(function() LocalPlayer:SetAttribute("EventShopMenuOpen", true) end)
    if Remotes.selectInventoryItem then
        pcall(function() Remotes.selectInventoryItem:FireServer(0) end)
    end

    local originalCFrame = nil
    if not noTeleport then
        local prompt = findEventShopPrompt()
        if prompt then
            local promptPos = getPromptWorldPosition(prompt)
            if promptPos then
                originalCFrame = teleportPlayerTo(promptPos)
                task.wait(0.2)
            end
        end
    end

    latestEventShopPayload = nil
    pcall(function() Remotes.eventShopAction:FireServer("RequestState") end)
    task.wait(0.1)
    pcall(function() Remotes.eventShopAction:FireServer("Activate", event.Id) end)

    local start = tick()
    local confirmed = false
    while (tick() - start) < 5 do
        if latestEventShopPayload and latestEventShopPayload.ActiveEventId == event.Id then
            confirmed = true
            break
        end
        task.wait(0.2)
    end

    if confirmed then
        addLog("[EVENTO] [✓] Evento confirmado ativo: " .. event.Id)
        if webhookToggles.event and webhookToggles.event.enabled then
            sendDiscordWebhook("🎡 Evento ativado", tostring(event.Id) .. " (custo " .. tostring(event.Cost) .. ")", Color3.fromRGB(0, 150, 255))
        end
    else
        addLog("[EVENTO] [!] Não confirmei a ativação")
    end

    if not stayAtShop then
        teleportPlayerBack(originalCFrame)
    end
    return confirmed
end

local function getActiveEventRemainingSeconds()
    if not Remotes.eventShopAction then return nil end
    latestEventShopPayload = nil
    pcall(function() Remotes.eventShopAction:FireServer("RequestState") end)
    local start = tick()
    while not latestEventShopPayload and (tick() - start) < 3 do
        task.wait(0.1)
    end
    if not latestEventShopPayload then return nil end
    if tostring(latestEventShopPayload.ActiveEventId or "") == "" then return nil end
    local endsAt = tonumber(latestEventShopPayload.ActiveEventEndsAt) or 0
    if endsAt <= 0 then return nil end
    local remaining = math.floor(endsAt - os.time())
    if remaining <= 0 then return nil end
    return remaining, latestEventShopPayload.ActiveEventId
end

local function waitWhileRunning(seconds, cfg)
    local deadline = tick() + seconds
    while cfg.running and tick() < deadline do
        task.wait(1)
    end
end

-- ========================================
-- AUTO-PAUSA (genérico, usado pelas 3 automações)
-- ========================================

local function otherPlayersCount()
    return #Players:GetPlayers() - 1
end

-- Toggle geral: liga/desliga a pausa automática quando outro jogador entra
-- na sala. Desativado, os loops ignoram totalmente outros jogadores.
local autoPauseConfig = { enabled = true }

local function makeAutoPauseGuards(cfg, getStatusLabel, startFn, stopFn, label)
    local autoResumeWhenAlone = false

    local function pauseIfRunning()
        if not autoPauseConfig.enabled then return end
        if cfg.running then
            addLog("[" .. label .. "] [!] Outro jogador entrou, pausando...")
            autoResumeWhenAlone = true
            stopFn()
            local statusLabel = getStatusLabel()
            if statusLabel then
                statusLabel.Text = t("status_paused_other")
                statusLabel.TextColor3 = Color3.fromRGB(255, 140, 0)
            end
        end
    end

    local function resumeIfWaiting()
        if autoResumeWhenAlone then
            addLog("[" .. label .. "] [*] Sozinho de novo, retomando...")
            autoResumeWhenAlone = false
            startFn()
        end
    end

    local function guardedStart()
        if autoPauseConfig.enabled and otherPlayersCount() > 0 then
            addLog("[" .. label .. "] [!] Tem outro jogador, vai iniciar quando ficar só.")
            autoResumeWhenAlone = true
            local statusLabel = getStatusLabel()
            if statusLabel then
                statusLabel.Text = t("status_paused_other")
                statusLabel.TextColor3 = Color3.fromRGB(255, 140, 0)
            end
            return
        end
        startFn()
    end

    local function guardedStop()
        autoResumeWhenAlone = false
        stopFn()
    end

    return pauseIfRunning, resumeIfWaiting, guardedStart, guardedStop
end

-- ========================================
-- ABA RAMP: ciclo do evento mais caro + JumpCar
-- ========================================

local rampStatusLabel, rampCountLabel, rampCycleLabel
-- Forward-declarado aqui (definido de verdade lá embaixo) porque
-- startMasterCycle/stopMasterCycle -- definidos
-- logo abaixo, nesta mesma aba -- precisam chamar MegaJumpInsta.enable/
-- disable, e uma função só enxerga uma local como upvalue se ela já
-- tiver sido declarada (com `local`) ANTES do texto da função -- mesmo
-- que a atribuição de valor só aconteça depois.
local MegaJumpInsta

local rampConfig = {
    running = false,
    loopDelay = 0.3,
    checkpointYOffset = 10,
    intermediateWait = 0.15,
    openBoxClicks = 10,
    openBoxClickDelay = 0.03,
    carSpawnWait = 0.6,
}

local function findJumpCarPart()
    local direct = Workspace:FindFirstChild("JumpCar", true)
    if direct and direct:IsA("BasePart") then return direct end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "JumpCar" and obj:IsA("BasePart") then return obj end
    end
    return nil
end

local jumpCarPart = findJumpCarPart()
print(jumpCarPart and ("[+] JumpCar encontrado: " .. jumpCarPart:GetFullName()) or "[-] JumpCar NÃO encontrado")

-- O jogo já renomeou o carro pelo menos uma vez (era "..._Auto", hoje é
-- "MiniCar_<numero>", ex: MiniCar_9547841947) -- confiar só no NOME quebra
-- toda vez que o jogo atualiza a nomenclatura. O jeito à prova de rename é
-- achar o carro pelo BANCO ONDE VOCÊ ESTÁ SENTADO: Humanoid.SeatPart aponta
-- pro Seat/VehicleSeat de verdade que você ocupa, e o Model ancestral dele
-- É o carro, seja qual for o nome que o jogo decidir usar. Os padrões de
-- nome antigos ficam só como fallback (personagem fora do carro, ou
-- procurando o carro de OUTRO lugar antes de entrar nele).
local function findPlayerCarModel()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        local seatModel = humanoid.SeatPart:FindFirstAncestorOfClass("Model")
        if seatModel then return seatModel end
    end

    local userName = LocalPlayer.Name

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("minicar_") or obj.Name:lower():find("auto")) then
            if obj.Name:lower():find(userName:lower()) then return obj end
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("_auto") or obj.Name:lower():find("minicar_")) then return obj end
    end

    return nil
end

local teleportCount = 0
local cycleCount = 0

local function waitForEvent(remote, timeout)
    if not remote then return false end
    local fired = false
    local conn
    conn = remote.OnClientEvent:Connect(function(...) fired = true end)

    local start = tick()
    while not fired and (tick() - start) < timeout do
        if not rampConfig.running then break end
        task.wait(0.1)
    end
    conn:Disconnect()
    return fired
end

local function waitForLaunchArgs(timeout)
    if not Remotes.clientCarLaunch then return false end
    local result = nil
    local conn
    conn = Remotes.clientCarLaunch.OnClientEvent:Connect(function(carInstance, launchVector, carName, forward, up)
        result = { car = carInstance, vector = launchVector, name = carName, forward = forward, up = up }
    end)

    local start = tick()
    while not result and (tick() - start) < timeout do
        if not rampConfig.running then break end
        task.wait(0.05)
    end
    conn:Disconnect()
    return result
end

local function moveCarTo(car, carPart, position)
    local currentRotation = carPart.CFrame - carPart.CFrame.Position
    local targetCFrame = CFrame.new(position) * currentRotation

    return pcall(function()
        if car.PrimaryPart then
            car:SetPrimaryPartCFrame(targetCFrame)
        else
            carPart.CFrame = targetCFrame
        end
    end)
end

local function clickOpenBoxMultiple()
    if not Remotes.openBoxClick then
        addLog("[RAMP] [!] OpenBoxClick não encontrado")
        return
    end

    for i = 1, rampConfig.openBoxClicks do
        if not rampConfig.running then break end
        pcall(function() Remotes.openBoxClick:FireServer() end)
        task.wait(rampConfig.openBoxClickDelay)
    end
end

-- Auto-clicker independente do ciclo automático: sempre que a caixa abrir
-- (StartBoxReveal), dispara os cliques rápidos na hora, mesmo com o Mega
-- Rampa Loop (aba de automação) desligado.
local autoBoxClickRunning = false
local function autoClickOpenBoxNow()
    if not Remotes.openBoxClick then return end
    if autoBoxClickRunning then return end
    autoBoxClickRunning = true

    for i = 1, rampConfig.openBoxClicks do
        pcall(function() Remotes.openBoxClick:FireServer() end)
        task.wait(rampConfig.openBoxClickDelay)
    end

    autoBoxClickRunning = false
end

if Remotes.startBoxReveal then
    Remotes.startBoxReveal.OnClientEvent:Connect(function()
        task.spawn(autoClickOpenBoxNow)
    end)
    addLog("[RAMP] [*] Auto-click da caixa ativo (independente do loop)")
end

local function forceTeleportToJumpCar()
    if Remotes.retryRun then
        pcall(function() Remotes.retryRun:FireServer() end)
        task.wait(rampConfig.carSpawnWait)
    end

    local jumpCar = jumpCarPart or findJumpCarPart()
    if not jumpCar then
        addLog("[RAMP] [!] Parte JumpCar não encontrada")
        return false
    end
    jumpCarPart = jumpCar

    local car = findPlayerCarModel()
    if not car then
        addLog("[RAMP] [!] Model do carro não encontrado")
        return false
    end

    local carPart = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
    if not carPart then
        addLog("[RAMP] [!] Nenhuma BasePart no carro " .. car.Name)
        return false
    end

    local currentRotation = carPart.CFrame - carPart.CFrame.Position
    local targetPosition = jumpCar.Position + Vector3.new(0, jumpCar.Size.Y / 2 + 2, 0)
    local targetCFrame = CFrame.new(targetPosition) * currentRotation

    local success, err = pcall(function()
        if car.PrimaryPart then
            car:SetPrimaryPartCFrame(targetCFrame)
        else
            carPart.CFrame = targetCFrame
        end
    end)

    if success then
        teleportCount = teleportCount + 1
        if rampCountLabel then rampCountLabel.Text = t("label_teleports_forced") .. teleportCount end
        return true
    else
        addLog("[RAMP] [!] Erro ao teleportar: " .. tostring(err))
        return false
    end
end

local function runTeleportLoopForDuration(durationSeconds)
    local deadline = tick() + durationSeconds
    addLog("[RAMP] [*] Rodando teleportes por " .. durationSeconds .. "s...")

    while rampConfig.running and tick() < deadline do
        local teleported = forceTeleportToJumpCar()

        if teleported then
            local launchData = waitForLaunchArgs(5)

            if launchData then
                -- Antigamente teleportava o carro pro checkpoint fixo
                -- (checkpointSlots) depois do pulo -- mas agora que o
                -- Mega Jump Insta já colapsa o Checkpoint 92 pra cima do
                -- CarSpawn/JumpCar, o carro já pousa em cima dele
                -- sozinho, então esse teleporte forçado não faz mais
                -- sentido (mandava o carro pra longe, pro lugar antigo).
                waitForEvent(Remotes.startBoxReveal, 8)
                -- Os cliques em si são disparados pelo listener global
                -- autoClickOpenBoxNow (StartBoxReveal.OnClientEvent), que
                -- roda sempre, com ou sem o loop ativo.
                waitForEvent(Remotes.endBoxReveal, 12)
            end
        end

        if not rampConfig.running or tick() >= deadline then break end
        task.wait(rampConfig.loopDelay)
    end

    addLog("[RAMP] [*] Janela de teleportes encerrada")
end

local function startMasterCycle()
    if rampConfig.running then return end
    rampConfig.running = true
    if rampStatusLabel then
        rampStatusLabel.Text = t("status_activating_event")
        rampStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
    addLog("[RAMP] === CICLO AUTOMÁTICO INICIADO ===")

    -- Mega Jump Insta liga junto com o ciclo (CarSpawn/JumpCar/Checkpoint
    -- 92 colapsados na posição do CarSpawn) e desliga sozinho quando o
    -- ciclo para -- inclusive na pausa automática por outro jogador, já
    -- que ela chama esse mesmo startMasterCycle/stopMasterCycle.
    if MegaJumpInsta and not MegaJumpInsta.isEnabled() then
        local pos = MegaJumpInsta.getDefaultPosition()
        MegaJumpInsta.enable(pos.X, pos.Y, pos.Z)
    end

    task.spawn(function()
        while rampConfig.running do
            local remaining, activeEventId = getActiveEventRemainingSeconds()

            if remaining then
                addLog("[RAMP] [*] Evento já ativo, restam ~" .. remaining .. "s. Retomando sem reativar.")
                if rampStatusLabel then rampStatusLabel.Text = t("status_teleporting") end
                runTeleportLoopForDuration(remaining + EVENT_DURATION_BUFFER_SECONDS)
            else
                if rampStatusLabel then rampStatusLabel.Text = t("status_activating_event") end
                activateMostExpensiveEvent()
                if not rampConfig.running then break end

                if rampStatusLabel then rampStatusLabel.Text = t("status_teleporting") end
                runTeleportLoopForDuration(EVENT_DURATION_SECONDS + EVENT_DURATION_BUFFER_SECONDS)
            end
            if not rampConfig.running then break end

            if rampStatusLabel then rampStatusLabel.Text = t("status_selling") end
            addLog("[RAMP] [*] Tempo do evento acabou, vendendo todos os slimes...")
            SellAll.sellAll()

            cycleCount = cycleCount + 1
            if rampCycleLabel then rampCycleLabel.Text = t("label_cycles_complete") .. cycleCount end

            if not rampConfig.running then break end
            task.wait(1)
        end

        if rampStatusLabel then
            rampStatusLabel.Text = t("status_stopped")
            rampStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        end
        addLog("[RAMP] === CICLO AUTOMÁTICO FINALIZADO ===")
    end)
end

local function stopMasterCycle()
    rampConfig.running = false
    addLog("[RAMP] [!] Parando ciclo automático...")
    if MegaJumpInsta and MegaJumpInsta.isEnabled() then
        MegaJumpInsta.disable()
    end
end

-- ========================================
-- DISPATCHER DO REMOTE COMPARTILHADO (Memória + Bata o Slime)
-- ========================================

local memoryToken, memoryLastRejected, memoryLastReward = nil, nil, nil
local hitSlimeToken, hitSlimeLastRejected, hitSlimeLastReward = nil, nil, nil

if Remotes.miniGameMemoryEvent then
    Remotes.miniGameMemoryEvent.OnClientEvent:Connect(function(kind, gameType, a, b, c, d)
        kind = tostring(kind or "")
        gameType = tostring(gameType or "")

        if gameType == "Memory" then
            if kind == "RoundStarted" then
                memoryToken = tostring(a or "")
            elseif kind == "RoundRejected" then
                memoryLastRejected = tostring(a or "motivo desconhecido")
                addLog("[MEMORIA] [!] Recusado: " .. memoryLastRejected)
            elseif kind == "RewardResult" then
                memoryLastReward = { success = a == true, amount = b, errorMsg = d }
                if a == true then
                    addLog("[MEMORIA] [✓] Recompensa: +" .. tostring(b))
                    if webhookToggles.memory and webhookToggles.memory.enabled then
                        sendDiscordWebhook("🧠 Memória vencida", "Recompensa: +" .. tostring(b), Color3.fromRGB(0, 190, 100))
                    end
                else
                    addLog("[MEMORIA] [!] Recompensa falhou: " .. tostring(d or "erro"))
                end
            end
        elseif gameType == "HitTheSlime" then
            if kind == "RoundStarted" then
                hitSlimeToken = tostring(a or "")
            elseif kind == "RoundRejected" then
                hitSlimeLastRejected = tostring(a or "motivo desconhecido")
                addLog("[HITSLIME] [!] Recusado: " .. hitSlimeLastRejected)
            elseif kind == "RewardResult" then
                hitSlimeLastReward = { success = a == true, amount = b, errorMsg = d }
                if a == true then
                    addLog("[HITSLIME] [✓] Recompensa: +" .. tostring(b))
                    if webhookToggles.hitslime and webhookToggles.hitslime.enabled then
                        sendDiscordWebhook("🎯 Bata o Slime vencido", "Recompensa: +" .. tostring(b), Color3.fromRGB(0, 185, 235))
                    end
                else
                    addLog("[HITSLIME] [!] Recompensa falhou: " .. tostring(d or "erro"))
                end
            end
        end
    end)
end

-- ========================================
-- ABA GAMES: Memória de Slime
-- ========================================

local memoryStatusLabel, memoryCountLabel

local memoryConfig = {
    running = false,
    completionSeconds = 14.6,
    roundCooldown = 3,
    rejectedCooldown = 15,
}

-- ========================================
-- MEMÓRIA 100% POR REMOTE, SEM ABRIR NENHUM MENU: a tentativa anterior
-- (instanciar o MemorySlimeClient real e chamar :Start() pra montar o
-- grid) não abria de verdade -- confirmado pelo usuário testando ao
-- vivo. Igual foi apontado ("não tem como fazer o mesmo que fez com o
-- hit slime.. ele nem abre o menu faz direto via server token"), o Bata
-- o Slime NUNCA abriu UI nenhuma pra jogar -- ele só troca remotes com o
-- servidor (StartRound -> RoundStarted com um ServerToken -> Progress
-- várias vezes -> WinRound), e o resultado (RewardResult) chega pelo
-- MESMO dispatcher compartilhado de cima. Lendo MemorySlimeClient.lua
-- (extraído do .rbxlx) dá pra ver que a Memória usa EXATAMENTE o mesmo
-- esqueleto por baixo do grid visual:
--
--   Start()   -> RemoteEvent:FireServer("StartRound", "Memory")
--   servidor  -> FireClient(player, "RoundStarted", "Memory", token)
--                (visto em SlimeGameClient.lua: v18:SetServerToken(token))
--   par certo -> RemoteEvent:FireServer("Progress", "Memory", token, N)
--                (N = contador de pares acertados até agora, 1, 2, 3...
--                 -- é literalmente p1.LastReportedPairs incrementando)
--   9 pares   -> RemoteEvent:FireServer("WinRound", "Memory", token)
--   servidor  -> FireClient(player, "RewardResult", "Memory", ok, valor)
--
-- O total de pares (TotalPairs) não vem do inventário do jogador -- vem
-- de contar quantos Model/BasePart existem em
-- ReplicatedStorage.MiniGame1Slimes_Client (a MESMA pasta template que
-- o jogo usa, `SlimeFolder` no construtor), limitado a 9
-- (t._getTemplates + math.min(9, #t) em MemorySlimeClient.lua) -- dá
-- pra calcular isso aqui sem abrir grid nenhum. Sem UI, sem prompt, sem
-- hub -- só os 3 remotes na ordem certa, com pausas configuráveis pra
-- não disparar "muito rápido" no servidor.
-- ========================================

local function countMemoryTotalPairs()
    local slimesFolder = ReplicatedStorage:FindFirstChild("MiniGame1Slimes_Client")
    if not slimesFolder then return 9 end

    local count = 0
    for _, v in ipairs(slimesFolder:GetChildren()) do
        if v:IsA("Model") or v:IsA("BasePart") then
            count = count + 1
        end
    end

    return math.clamp(count, 1, 9)
end

local memoryRoundCount = 0

local function runOneMemoryRound()
    memoryToken = nil
    memoryLastRejected = nil
    memoryLastReward = nil

    if not Remotes.miniGameMemoryEvent then
        addLog("[MEMORIA] [!] MiniGame1MemoryEvent não encontrado")
        return
    end

    pcall(function() Remotes.miniGameMemoryEvent:FireServer("StartRound", "Memory") end)

    local tokenStart = tick()
    while memoryConfig.running and not memoryToken and not memoryLastRejected and (tick() - tokenStart) < 5 do
        task.wait(0.1)
    end

    if not memoryToken then
        if not memoryLastRejected then
            addLog("[MEMORIA] [!] Não recebi ServerToken")
        end
        return
    end

    local totalPairs = countMemoryTotalPairs()
    local gapPerPair = math.max(memoryConfig.completionSeconds, 0) / totalPairs

    for pairIndex = 1, totalPairs do
        if not memoryConfig.running then return end
        if memoryLastRejected then break end

        task.wait(gapPerPair)
        pcall(function() Remotes.miniGameMemoryEvent:FireServer("Progress", "Memory", memoryToken, pairIndex) end)
    end

    if memoryLastRejected then
        addLog("[MEMORIA] [!] Recusado durante os pares, abortando rodada")
        return
    end

    pcall(function() Remotes.miniGameMemoryEvent:FireServer("WinRound", "Memory", memoryToken) end)

    local rewardStart = tick()
    while memoryConfig.running and not memoryLastReward and not memoryLastRejected and (tick() - rewardStart) < 6 do
        task.wait(0.2)
    end

    memoryRoundCount = memoryRoundCount + 1
    if memoryCountLabel then memoryCountLabel.Text = t("label_rounds") .. memoryRoundCount end
end

local function startMemoryLoop()
    if memoryConfig.running then return end
    memoryConfig.running = true
    if memoryStatusLabel then
        memoryStatusLabel.Text = t("status_running")
        memoryStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
    addLog("[MEMORIA] === INICIADO ===")

    task.spawn(function()
        while memoryConfig.running do
            runOneMemoryRound()
            if not memoryConfig.running then break end
            local cooldown = memoryLastRejected and memoryConfig.rejectedCooldown or memoryConfig.roundCooldown
            task.wait(cooldown)
        end
        if memoryStatusLabel then
            memoryStatusLabel.Text = t("status_stopped")
            memoryStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        end
        addLog("[MEMORIA] === FINALIZADO ===")
    end)

    task.spawn(function()
        while memoryConfig.running do
            -- Mesmo esquema do Bata o Slime: ativa o evento mais barato
            -- com o maior CashMultiplier (bônus de Cash), fica parado
            -- nele (noTeleport=true, sem sair do lugar), e reativa
            -- sozinho quando os ~10 minutos acabam.
            activateMostExpensiveEvent(true, true, findCheapestMaxCashEvent())
            if not memoryConfig.running then break end
            waitWhileRunning(EVENT_DURATION_SECONDS + EVENT_DURATION_BUFFER_SECONDS, memoryConfig)
        end
    end)
end

local function stopMemoryLoop()
    memoryConfig.running = false
    if memoryStatusLabel then
        memoryStatusLabel.Text = t("status_stopped")
        memoryStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    end
    addLog("[MEMORIA] Parando...")
end

-- ========================================
-- ABA GAMES: Bata o Slime
-- ========================================

local hitSlimeStatusLabel, hitSlimeCountLabel

local CUMULATIVE_COMPLETED_BY_LEVEL = { 30, 66, 108, 156, 212, 275, 345, 425, 515, 611 }

local hitSlimeConfig = {
    running = false,
    secondsPerRound = 18,
    roundCooldown = 3,
    rejectedCooldown = 15,
}

local hitSlimeRoundCount = 0

local function runHitSlimeAttempt()
    hitSlimeToken = nil
    hitSlimeLastRejected = nil
    hitSlimeLastReward = nil

    pcall(function() Remotes.miniGameMemoryEvent:FireServer("StartRound", "HitTheSlime") end)

    local start = tick()
    while hitSlimeConfig.running and not hitSlimeToken and not hitSlimeLastRejected and (tick() - start) < 5 do
        task.wait(0.1)
    end

    if not hitSlimeToken then
        addLog("[HITSLIME] [!] Não recebi ServerToken")
        return
    end

    for level, cumulative in ipairs(CUMULATIVE_COMPLETED_BY_LEVEL) do
        if not hitSlimeConfig.running then return end

        task.wait(hitSlimeConfig.secondsPerRound)

        pcall(function()
            Remotes.miniGameMemoryEvent:FireServer("Progress", "HitTheSlime", hitSlimeToken, level, cumulative)
        end)

        if hitSlimeLastRejected then
            addLog("[HITSLIME] [!] Recusado no nível " .. level .. ", abortando")
            return
        end
    end

    pcall(function() Remotes.miniGameMemoryEvent:FireServer("WinRound", "HitTheSlime", hitSlimeToken) end)

    local waitStart = tick()
    while hitSlimeConfig.running and not hitSlimeLastReward and (tick() - waitStart) < 6 do
        task.wait(0.2)
    end

    hitSlimeRoundCount = hitSlimeRoundCount + 1
    if hitSlimeCountLabel then hitSlimeCountLabel.Text = t("label_rounds") .. hitSlimeRoundCount end
end

local function startHitSlimeLoop()
    if hitSlimeConfig.running then return end
    hitSlimeConfig.running = true
    if MiniGameStick.isEnabled() then
        MiniGameStick.disable()
    end
    if hitSlimeStatusLabel then
        hitSlimeStatusLabel.Text = t("status_running")
        hitSlimeStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
    addLog("[HITSLIME] === INICIADO === (" .. hitSlimeConfig.secondsPerRound .. "s por nível)")

    task.spawn(function()
        while hitSlimeConfig.running do
            runHitSlimeAttempt()
            if not hitSlimeConfig.running then break end
            local cooldown = hitSlimeLastRejected and hitSlimeConfig.rejectedCooldown or hitSlimeConfig.roundCooldown
            task.wait(cooldown)
        end
        if hitSlimeStatusLabel then
            hitSlimeStatusLabel.Text = t("status_stopped")
            hitSlimeStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        end
        addLog("[HITSLIME] === FINALIZADO ===")
    end)

    task.spawn(function()
        while hitSlimeConfig.running do
            -- noTeleport=true: nem teleporta pro shop de eventos -- o
            -- Bata o Slime roda 100% por remote (não precisa estar perto
            -- de nada), e o usuário já fica parado no local de abrir o
            -- evento antes de clicar Jogar, então mover o personagem só
            -- atrapalharia. Aqui usa o evento mais barato com o maior
            -- CashMultiplier do catálogo (não o mais caro geral) -- o
            -- Bata o Slime quer o bônus de Cash, não gastar EventCoins à
            -- toa num evento caro que não ajuda a farmar mais rápido.
            activateMostExpensiveEvent(true, true, findCheapestMaxCashEvent())
            if not hitSlimeConfig.running then break end
            waitWhileRunning(EVENT_DURATION_SECONDS + EVENT_DURATION_BUFFER_SECONDS, hitSlimeConfig)
        end
    end)
end

local function stopHitSlimeLoop()
    hitSlimeConfig.running = false
    if hitSlimeStatusLabel then
        hitSlimeStatusLabel.Text = t("status_stopped")
        hitSlimeStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    end
    addLog("[HITSLIME] Parando...")
end

-- ========================================
-- CRIA OS GUARDS DE AUTO-PAUSA (só agora que start/stop de todos já existem)
-- ========================================

local rampPause, rampResume, rampGuardedStart, rampGuardedStop =
    makeAutoPauseGuards(rampConfig, function() return rampStatusLabel end, startMasterCycle, stopMasterCycle, "RAMP")

-- Memória e Bata o Slime NÃO entram na pausa automática por outro
-- jogador -- essa pausa existia porque os loops antigos teleportavam o
-- personagem pro shop de eventos (precisava "disfarçar" isso enquanto
-- tinha gente por perto). Agora os dois rodam 100% por remote, sem
-- mover ninguém, então não tem mais nada pra esconder -- ficam soltos,
-- rodando direto mesmo com outros jogadores na sala.
local memoryGuardedStart, memoryGuardedStop = startMemoryLoop, stopMemoryLoop

Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    rampPause()
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then return end
    task.wait(0.2)
    rampResume()
end)

-- ========================================
-- ABA CAM: Free Cam + ABA JOGADORES: Spectate
-- ========================================

local function buildFreecamFeature()

local freecamConfig = { active = false, baseSpeed = 60, boostMultiplier = 3 }
local freecamAnchoredHrp = nil
local freecamSavedHrpAnchored = false
local freecamSavedCameraType = Enum.CameraType.Custom
local freecamYaw, freecamPitch = 0, 0
local freecamLooking = false
local freecamConnections = {}
local freecamStatusLabel

local spectatingPlayer = nil
local playersStatusLabel

local enableFreecam, disableFreecam, toggleFreecam
local startSpectate, stopSpectate

local function freecamDisconnectAll()
    for _, conn in ipairs(freecamConnections) do
        conn:Disconnect()
    end
    freecamConnections = {}
end

local function getCharacterHrp()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

enableFreecam = function()
    if freecamConfig.active then return end
    if spectatingPlayer then stopSpectate() end

    local camera = Workspace.CurrentCamera
    freecamSavedCameraType = camera.CameraType

    local hrp = getCharacterHrp()
    if hrp then
        freecamAnchoredHrp = hrp
        freecamSavedHrpAnchored = hrp.Anchored
        hrp.Anchored = true
    end

    local lookVector = camera.CFrame.LookVector
    freecamPitch = math.asin(math.clamp(lookVector.Y, -1, 1))
    freecamYaw = math.atan2(-lookVector.X, -lookVector.Z)

    camera.CameraType = Enum.CameraType.Scriptable
    freecamConfig.active = true
    if freecamStatusLabel then
        freecamStatusLabel.Text = t("status_freecam_active")
        freecamStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
    addLog("[CAM] Freecam ativado")

    table.insert(freecamConnections, UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamLooking = true
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)
        end
    end))

    table.insert(freecamConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamLooking = false
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end))

    table.insert(freecamConnections, UserInputService.InputChanged:Connect(function(input)
        if freecamLooking and input.UserInputType == Enum.UserInputType.MouseMovement then
            freecamYaw = freecamYaw - input.Delta.X * 0.0025
            freecamPitch = math.clamp(freecamPitch - input.Delta.Y * 0.0025, -math.rad(89), math.rad(89))
        end
    end))

    table.insert(freecamConnections, RunService.RenderStepped:Connect(function(dt)
        local cam = Workspace.CurrentCamera
        local rotation = CFrame.Angles(0, freecamYaw, 0) * CFrame.Angles(freecamPitch, 0, 0)

        local moveVector = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector += Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector += Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
            moveVector += Vector3.new(0, -1, 0)
        end

        if moveVector.Magnitude > 0 then moveVector = moveVector.Unit end

        local speed = freecamConfig.baseSpeed
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            speed = speed * freecamConfig.boostMultiplier
        end

        local worldMove = rotation:VectorToWorldSpace(moveVector) * speed * dt
        cam.CFrame = CFrame.new(cam.CFrame.Position + worldMove) * rotation
    end))
end

disableFreecam = function()
    if not freecamConfig.active then return end
    freecamConfig.active = false

    freecamDisconnectAll()
    freecamLooking = false
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)

    local camera = Workspace.CurrentCamera
    camera.CameraType = freecamSavedCameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or freecamSavedCameraType

    if freecamAnchoredHrp and freecamAnchoredHrp.Parent then
        freecamAnchoredHrp.Anchored = freecamSavedHrpAnchored
    end
    freecamAnchoredHrp = nil

    if freecamStatusLabel then
        freecamStatusLabel.Text = t("status_inactive")
        freecamStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    end
    addLog("[CAM] Freecam desativado")
end

toggleFreecam = function()
    if freecamConfig.active then disableFreecam() else enableFreecam() end
end

startSpectate = function(player)
    if not player or player == LocalPlayer then return end
    if freecamConfig.active then disableFreecam() end

    local character = player.Character
    if not character then
        addLog("[PLAYERS] [!] " .. player.Name .. " não tem personagem carregado")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local camera = Workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = humanoid or character:FindFirstChild("Head") or character.PrimaryPart

    spectatingPlayer = player
    if playersStatusLabel then
        playersStatusLabel.Text = t("status_watching") .. player.Name
        playersStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
    addLog("[PLAYERS] Espectando " .. player.Name)
end

stopSpectate = function()
    if not spectatingPlayer then return end
    spectatingPlayer = nil

    local camera = Workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom
    local myChar = LocalPlayer.Character
    camera.CameraSubject = myChar and myChar:FindFirstChildOfClass("Humanoid")

    if playersStatusLabel then
        playersStatusLabel.Text = t("status_none_normal_cam")
        playersStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    end
    addLog("[PLAYERS] Spectate desativado")
end

return {
    config = freecamConfig,
    enable = enableFreecam,
    disable = disableFreecam,
    toggle = toggleFreecam,
    startSpectate = startSpectate,
    stopSpectate = stopSpectate,
    setFreecamStatusLabel = function(lbl) freecamStatusLabel = lbl end,
    setPlayersStatusLabel = function(lbl) playersStatusLabel = lbl end,
    isSpectating = function() return spectatingPlayer ~= nil end,
    getSpectatingPlayer = function() return spectatingPlayer end,
}
end

local Freecam = buildFreecamFeature()

LocalPlayer.CharacterAdded:Connect(function()
    Freecam.disable()
    if Freecam.isSpectating() then Freecam.stopSpectate() end
end)

Players.PlayerRemoving:Connect(function(player)
    if Freecam.getSpectatingPlayer() == player then Freecam.stopSpectate() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not isCurrentHubGeneration() then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        Freecam.toggle()
    end
end)

-- ========================================
-- IMPULSO DA PISTA (CARRO): segura SHIFT pra empurrar o carro pra frente
-- com força extra, solta e o impulso para na hora -- reaproveita o mesmo
-- findPlayerCarModel() já usado pelo ciclo do Ramp.
-- ========================================

local carBoostConfig = { enabled = false, force = 120, holding = false }
local carStatusLabel

local function getCarMainPart(car)
    if not car then return nil end
    return car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if not isCurrentHubGeneration() then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        carBoostConfig.holding = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not isCurrentHubGeneration() then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        carBoostConfig.holding = false
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not isCurrentHubGeneration() then return end
    if not carBoostConfig.enabled then
        if carStatusLabel then
            carStatusLabel.Text = t("status_off")
            carStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        end
        return
    end

    if not carBoostConfig.holding then
        if carStatusLabel then
            carStatusLabel.Text = t("status_on_hold_shift")
            carStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
        return
    end

    local carPart = getCarMainPart(findPlayerCarModel())
    if not carPart then
        if carStatusLabel then
            carStatusLabel.Text = t("status_on_no_car")
            carStatusLabel.TextColor3 = Color3.fromRGB(255, 140, 0)
        end
        return
    end

    local forward = carPart.CFrame.LookVector
    carPart.AssemblyLinearVelocity = carPart.AssemblyLinearVelocity + forward * carBoostConfig.force * dt

    if carStatusLabel then
        carStatusLabel.Text = t("status_boosting")
        carStatusLabel.TextColor3 = Color3.fromRGB(0, 220, 220)
    end
end)

-- ========================================
-- FLY / NO-CLIP COM O CARRO: desliga a colisão do carro inteiro e deixa
-- mover ele livremente (voando) com WASD/Space/Ctrl relativo à câmera,
-- igual o Free Cam -- mas movendo o carro (com você sentado) em vez da
-- câmera. Tudo dentro de uma função própria pra não gastar registro de
-- variável local do chunk principal.
-- ========================================

local function buildCarFlyFeature()
    local flyConfig = { active = false, speed = 90, boostMultiplier = 3 }
    local savedCollide = {}
    local connections = {}
    local statusLabel = nil

    local function disconnectAll()
        for _, conn in ipairs(connections) do conn:Disconnect() end
        connections = {}
    end

    local function setStatus(text, color)
        if statusLabel then
            statusLabel.Text = text
            statusLabel.TextColor3 = color
        end
    end

    local function enable()
        if flyConfig.active then return end
        local car = findPlayerCarModel()
        if not car then
            addLog("[FLY] [!] Model do carro não encontrado")
            return
        end

        savedCollide = {}
        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") then
                savedCollide[part] = part.CanCollide
                part.CanCollide = false
            end
        end

        flyConfig.active = true
        setStatus(t("status_flying"), Color3.fromRGB(0, 220, 220))
        addLog("[FLY] Ativado")

        connections[#connections + 1] = RunService.RenderStepped:Connect(function(dt)
            local currentCar = findPlayerCarModel()
            if not currentCar then return end
            local carPart = currentCar.PrimaryPart or currentCar:FindFirstChildWhichIsA("BasePart", true)
            if not carPart then return end

            local camera = Workspace.CurrentCamera
            local camCFrame = camera.CFrame

            local moveVector = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += Vector3.new(0, 0, -1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector += Vector3.new(0, 0, 1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector += Vector3.new(-1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += Vector3.new(1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
                moveVector += Vector3.new(0, -1, 0)
            end

            if moveVector.Magnitude == 0 then return end
            moveVector = moveVector.Unit

            local speed = flyConfig.speed
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                speed = speed * flyConfig.boostMultiplier
            end

            local worldMove = camCFrame:VectorToWorldSpace(moveVector) * speed * dt
            local currentRotation = carPart.CFrame - carPart.CFrame.Position
            local newCFrame = CFrame.new(carPart.Position + worldMove) * currentRotation

            local ok = pcall(function()
                if currentCar.PrimaryPart then
                    currentCar:SetPrimaryPartCFrame(newCFrame)
                else
                    carPart.CFrame = newCFrame
                end
            end)
            if ok then
                carPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                carPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end)
    end

    local function disable()
        if not flyConfig.active then return end
        flyConfig.active = false
        disconnectAll()

        for part, collide in pairs(savedCollide) do
            if part.Parent then
                part.CanCollide = collide
            end
        end
        savedCollide = {}

        setStatus(t("status_off"), Color3.fromRGB(100, 200, 100))
        addLog("[FLY] Desativado")
    end

    local function toggle()
        if flyConfig.active then disable() else enable() end
    end

    return {
        config = flyConfig,
        toggle = toggle,
        disable = disable,
        setStatusLabel = function(lbl) statusLabel = lbl end,
    }
end

local CarFly = buildCarFlyFeature()

-- ========================================
-- MEGA JUMP INSTA: colapsa CarSpawn + JumpCar + o checkpoint final (92,
-- o multiplicador x1000000) pro MESMO ponto, e desativa as CarResetZones
-- -- assim o carro nasce, já está "no" JumpCar e "no" checkpoint final,
-- tudo no mesmo lugar, sem percurso nenhum. 100% client-side: as parts
-- reais do jogo continuam nos lugares originais pro servidor e pros
-- outros jogadores, só a SUA cópia renderizada é que muda de posição
-- (mesma técnica do moveMiniGameButtonToEventShop, aplicada em 3 parts).
-- As CarResetZones não são destruídas de verdade -- só desligamos
-- Collide/Touch e escondemos (Transparency=1), assim dá pra desfazer
-- (Restaurar) sem precisar recarregar o script inteiro.
-- ========================================

local function buildMegaJumpInstaFeature()
    local enabled = false
    local saved = { carSpawn = nil, jumpCar = nil, checkpoint92 = nil, checkpoint92Size = nil, checkpoint92SquareDups = {}, landingZone3 = nil, resetZones = {}, jumpCarForceAttrs = {} }

    local function findCarResetZonesFolder()
        local direct = Workspace:FindFirstChild("CarResetZones", true)
        if direct then return direct end
        return nil
    end

    local function findCarSpawnPart()
        local direct = Workspace:FindFirstChild("CarSpawn", true)
        if direct and direct:IsA("BasePart") then return direct end
        return nil
    end

    local function findCheckpoint92()
        local folder = Workspace:FindFirstChild("Checkpoints", true)
        if not folder then return nil end

        -- Busca exata por nome "92" entre os filhos diretos primeiro
        -- (FindFirstChild pode devolver algo inesperado se houver mais de
        -- uma pasta "Checkpoints" no jogo -- por isso comparamos o nome
        -- manualmente em vez de confiar cegamente no primeiro achado).
        local child = nil
        for _, c in ipairs(folder:GetChildren()) do
            if c.Name == "92" then
                child = c
                break
            end
        end
        if not child then
            addLog("[MEGA-JUMP-INSTA] [!] Não achei um filho chamado '92' dentro de " .. folder:GetFullName())
            return nil
        end

        local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart", true)
        if part then
            addLog("[MEGA-JUMP-INSTA] [*] Checkpoint 92 encontrado: " .. part:GetFullName())
        end
        return part
    end

    local function findLandingZone3()
        local direct = Workspace:FindFirstChild("LandingZone3", true)
        if not direct then return nil end
        if direct:IsA("BasePart") then return direct end
        return direct:FindFirstChildWhichIsA("BasePart", true)
    end

    -- Offsets medidos direto no Studio (Properties de cada part, com o
    -- CarSpawn tomado como ponto de referência (0,0,0)):
    --   CarSpawn:     -0.108, 125.979, -1563.82
    --   JumpCar:      -0,     143.307, -1539.577  -> offset (0, +17.328, +24.243)
    --   Checkpoint 92: -0.021, 216,    -1538.844  -> offset (+0.087, +90.021, +24.976)
    -- Ou seja, o JumpCar NÃO fica no mesmo Y do CarSpawn (fica ~17 studs
    -- mais alto) e o Checkpoint 92 fica bem mais alto ainda (~90 studs),
    -- igual a rampa real do jogo -- por isso não dá pra colapsar os 3 no
    -- mesmo ponto exato, só alinhar em X/Z e respeitar essas diferenças
    -- de altura. Além de mover, também zeramos qualquer Attribute de
    -- força/impulso do JumpCar (nomes tipo Force/Power/Impulse/Speed),
    -- restaurando os valores originais no Restaurar.
    -- LandingZone3: -8.181, 186.895, -1398.538 -> offset (-8.073, +60.916, +165.282)
    -- Checkpoint 92 (novo valor): -0.021, 216, -1541.379 -> offset (+0.087, +90.021, +22.441)
    local JUMP_CAR_OFFSET = Vector3.new(0.108, 17.328, 24.243)
    local CHECKPOINT92_OFFSET = Vector3.new(0.087, 90.021, 22.441)
    local LANDING_ZONE_OFFSET = Vector3.new(-8.073, 60.916, 165.282)
    local FORCE_ATTRIBUTE_KEYWORDS = { "force", "power", "impulse", "speed", "launch", "jump" }
    -- Checkpoint 92 é minúsculo perto do JumpCar/CarSpawn -- quando tudo
    -- colapsa pro mesmo ponto, o carro acaba pousando fora da área de
    -- toque dele e triggando os checkpoints 0/1 por engano (que são bem
    -- maiores). Aumentamos o Size dele (mantendo o centro) só enquanto
    -- ativo, pra garantir que a área cubra o ponto alvo.
    local CHECKPOINT_SIZE_MULTIPLIER = 6

    -- Além de aumentar o Size do Checkpoint 92 em si, criamos mais 3
    -- cópias dele ao redor -- mais acima, mais abaixo (só um pouco, pra
    -- não ficar longe demais do chão) e mais à frente -- formando um
    -- "quadrado" de áreas de toque em volta do ponto alvo. Cada cópia
    -- dispara o MESMO MiniParkourEvent("CheckpointTouched", 92) que o
    -- original.
    local CHECKPOINT_SQUARE_OFFSETS = {
        Vector3.new(0, 40, 0),   -- mais acima
        Vector3.new(0, -15, 0),  -- mais abaixo (não tão abaixo)
        Vector3.new(0, 0, 40),   -- mais à frente
    }

    local function wireCheckpoint92DupTouched(part)
        part.CanTouch = true
        part.CanCollide = false
        part.Touched:Connect(function(hit)
            if not hit then return end
            local isMine = false
            local character = LocalPlayer.Character
            if character and hit:IsDescendantOf(character) then
                isMine = true
            else
                local model = hit:FindFirstAncestorOfClass("Model")
                isMine = model ~= nil and model:GetAttribute("OwnerUserId") == LocalPlayer.UserId
            end
            if not isMine then return end
            if not Remotes.miniParkourEvent then return end
            pcall(function() Remotes.miniParkourEvent:FireServer("CheckpointTouched", 92) end)
            addLog("[MEGA-JUMP-INSTA] Checkpoint 92 (cópia do quadrado) disparado")
        end)
    end

    local function createCheckpoint92SquareDuplicates(checkpoint92)
        local dups = {}
        for _, offset in ipairs(CHECKPOINT_SQUARE_OFFSETS) do
            local clone = checkpoint92:Clone()
            clone.Name = "92_HubSquareDup"
            clone.CFrame = checkpoint92.CFrame + offset
            clone.Parent = checkpoint92.Parent
            wireCheckpoint92DupTouched(clone)
            table.insert(dups, clone)
        end
        return dups
    end

    local function removeCheckpoint92SquareDuplicates(dups)
        for _, part in ipairs(dups) do
            if part.Parent then part:Destroy() end
        end
    end

    local function zeroOutJumpCarForce(jumpCar)
        local savedAttrs = {}
        local ok, attrs = pcall(function() return jumpCar:GetAttributes() end)
        if ok and attrs then
            for name, value in pairs(attrs) do
                if typeof(value) == "number" then
                    local lowerName = name:lower()
                    for _, keyword in ipairs(FORCE_ATTRIBUTE_KEYWORDS) do
                        if lowerName:find(keyword, 1, true) then
                            savedAttrs[name] = value
                            pcall(function() jumpCar:SetAttribute(name, 0) end)
                            addLog("[MEGA-JUMP-INSTA] [*] Attribute '" .. name .. "' (" .. tostring(value) .. ") zerado no JumpCar")
                            break
                        end
                    end
                end
            end
        end
        return savedAttrs
    end

    local function restoreJumpCarForce(jumpCar, savedAttrs)
        if not jumpCar or not jumpCar.Parent then return end
        for name, value in pairs(savedAttrs) do
            pcall(function() jumpCar:SetAttribute(name, value) end)
        end
    end

    local function enable(x, y, z)
        if enabled then return end

        local carSpawn = findCarSpawnPart()
        local jumpCar = jumpCarPart or findJumpCarPart()
        local checkpoint92 = findCheckpoint92()
        local landingZone3 = findLandingZone3()

        if not carSpawn or not jumpCar or not checkpoint92 then
            addLog("[MEGA-JUMP-INSTA] [!] Não achei tudo (CarSpawn=" .. tostring(carSpawn ~= nil)
                .. ", JumpCar=" .. tostring(jumpCar ~= nil) .. ", Checkpoint 92=" .. tostring(checkpoint92 ~= nil) .. ")")
            return
        end

        saved.carSpawn = { part = carSpawn, cframe = carSpawn.CFrame }
        saved.jumpCar = { part = jumpCar, cframe = jumpCar.CFrame }
        saved.checkpoint92 = { part = checkpoint92, cframe = checkpoint92.CFrame }
        saved.checkpoint92Size = checkpoint92.Size
        saved.landingZone3 = landingZone3 and { part = landingZone3, cframe = landingZone3.CFrame } or nil

        local target = Vector3.new(x, y, z)
        local function moveKeepingRotation(part, position)
            local rotation = part.CFrame - part.CFrame.Position
            part.CFrame = CFrame.new(position) * rotation
        end
        moveKeepingRotation(carSpawn, target)
        moveKeepingRotation(jumpCar, target + JUMP_CAR_OFFSET)
        moveKeepingRotation(checkpoint92, target + CHECKPOINT92_OFFSET)
        checkpoint92.Size = saved.checkpoint92Size * CHECKPOINT_SIZE_MULTIPLIER
        addLog("[MEGA-JUMP-INSTA] [*] Checkpoint 92 aumentado de " .. tostring(saved.checkpoint92Size) .. " pra " .. tostring(checkpoint92.Size))
        saved.checkpoint92SquareDups = createCheckpoint92SquareDuplicates(checkpoint92)
        addLog("[MEGA-JUMP-INSTA] [*] " .. #saved.checkpoint92SquareDups .. " cópias do Checkpoint 92 criadas em quadrado (acima/abaixo/frente)")
        if landingZone3 then
            moveKeepingRotation(landingZone3, target + LANDING_ZONE_OFFSET)
        else
            addLog("[MEGA-JUMP-INSTA] [!] LandingZone3 não encontrada (seguindo sem mover)")
        end

        saved.jumpCarForceAttrs = zeroOutJumpCarForce(jumpCar)

        saved.resetZones = {}
        local resetFolder = findCarResetZonesFolder()
        if resetFolder then
            for _, part in ipairs(resetFolder:GetDescendants()) do
                if part:IsA("BasePart") then
                    saved.resetZones[part] = { canCollide = part.CanCollide, canTouch = part.CanTouch, transparency = part.Transparency }
                    part.CanCollide = false
                    part.CanTouch = false
                    part.Transparency = 1
                end
            end
        else
            addLog("[MEGA-JUMP-INSTA] [!] CarResetZones não encontrado (seguindo sem desativar)")
        end

        enabled = true
        addLog("[MEGA-JUMP-INSTA] [✓] Ativado -- CarSpawn/JumpCar/Checkpoint92 movidos pra (" .. x .. ", " .. y .. ", " .. z .. "), CarResetZones desativadas (só na sua tela)")
    end

    local function disable()
        if not enabled then return end

        if saved.carSpawn and saved.carSpawn.part.Parent then saved.carSpawn.part.CFrame = saved.carSpawn.cframe end
        if saved.jumpCar and saved.jumpCar.part.Parent then saved.jumpCar.part.CFrame = saved.jumpCar.cframe end
        if saved.checkpoint92 and saved.checkpoint92.part.Parent then
            saved.checkpoint92.part.CFrame = saved.checkpoint92.cframe
            if saved.checkpoint92Size then saved.checkpoint92.part.Size = saved.checkpoint92Size end
        end
        removeCheckpoint92SquareDuplicates(saved.checkpoint92SquareDups)
        saved.checkpoint92SquareDups = {}
        if saved.landingZone3 and saved.landingZone3.part.Parent then saved.landingZone3.part.CFrame = saved.landingZone3.cframe end

        if saved.jumpCar then
            restoreJumpCarForce(saved.jumpCar.part, saved.jumpCarForceAttrs)
        end
        saved.jumpCarForceAttrs = {}

        for part, state in pairs(saved.resetZones) do
            if part.Parent then
                part.CanCollide = state.canCollide
                part.CanTouch = state.canTouch
                part.Transparency = state.transparency
            end
        end
        saved.resetZones = {}

        enabled = false
        addLog("[MEGA-JUMP-INSTA] Restaurado -- posições e CarResetZones originais de volta")
    end

    return {
        enable = enable,
        disable = disable,
        isEnabled = function() return enabled end,
        getDefaultPosition = function()
            local carSpawn = findCarSpawnPart()
            if carSpawn then return carSpawn.Position end
            return Vector3.new(0, 0, 0)
        end,
    }
end

MegaJumpInsta = buildMegaJumpInstaFeature()

-- ========================================
-- CHECKPOINT FINAL -> CHECKPOINT 1 + LANDINGZONE1 -> LANDINGZONE3: mesmo
-- toggle, dois movimentos independentes do Mega Jump Insta -- move a
-- part do ÚLTIMO checkpoint numerado (hoje é 92, mas pega dinamicamente
-- o maior número que existir na pasta Checkpoints -- se o jogo adicionar
-- 93, 94 etc no futuro, continua pegando o certo sozinho) pra cima do
-- Checkpoint 1, E a LandingZone1 pra cima da LandingZone3 (mantendo a
-- rotação original de cada uma), sem mexer em JumpCar, CarSpawn,
-- CarResetZones nem criar cópias em quadrado. 100% client-side (só a SUA
-- tela vê elas nessa posição nova).
-- ========================================

local function buildCheckpoint92To1Feature()
    local enabled = false
    local savedFinal = nil
    local savedLandingZone1 = nil

    local function findCheckpointByNumber(number)
        local folder = Workspace:FindFirstChild("Checkpoints", true)
        if not folder then return nil end
        local child = nil
        for _, c in ipairs(folder:GetChildren()) do
            if c.Name == tostring(number) then
                child = c
                break
            end
        end
        if not child then return nil end
        return child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart", true)
    end

    local function findMaxCheckpoint()
        local folder = Workspace:FindFirstChild("Checkpoints", true)
        if not folder then return nil, nil end
        local maxNumber, maxChild = nil, nil
        for _, c in ipairs(folder:GetChildren()) do
            local n = tonumber(c.Name)
            if n and (not maxNumber or n > maxNumber) then
                maxNumber, maxChild = n, c
            end
        end
        if not maxChild then return nil, nil end
        local part = maxChild:IsA("BasePart") and maxChild or maxChild:FindFirstChildWhichIsA("BasePart", true)
        return part, maxNumber
    end

    local function findLandingZoneByNumber(number)
        local direct = Workspace:FindFirstChild("LandingZone" .. number, true)
        if not direct then return nil end
        if direct:IsA("BasePart") then return direct end
        return direct:FindFirstChildWhichIsA("BasePart", true)
    end

    local function enable()
        if enabled then return end

        local checkpointFinal, finalNumber = findMaxCheckpoint()
        local checkpoint1 = findCheckpointByNumber(1)
        local landingZone1 = findLandingZoneByNumber(1)
        local landingZone3 = findLandingZoneByNumber(3)

        if not checkpointFinal or not checkpoint1 then
            addLog("[CHECKPOINT-FINAL-TO-1] [!] Não achei tudo (CheckpointFinal=" .. tostring(checkpointFinal ~= nil)
                .. ", Checkpoint1=" .. tostring(checkpoint1 ~= nil) .. ")")
            return
        end

        savedFinal = { part = checkpointFinal, cframe = checkpointFinal.CFrame }

        local rotationFinal = checkpointFinal.CFrame - checkpointFinal.CFrame.Position
        checkpointFinal.CFrame = CFrame.new(checkpoint1.Position) * rotationFinal

        if landingZone1 and landingZone3 then
            savedLandingZone1 = { part = landingZone1, cframe = landingZone1.CFrame }
            local rotationLZ = landingZone1.CFrame - landingZone1.CFrame.Position
            landingZone1.CFrame = CFrame.new(landingZone3.Position) * rotationLZ
            addLog("[CHECKPOINT-FINAL-TO-1] [✓] LandingZone1 movida pra cima da LandingZone3 (só na sua tela)")
        else
            addLog("[CHECKPOINT-FINAL-TO-1] [!] LandingZone1/LandingZone3 não encontradas (seguindo sem mover)")
        end

        enabled = true
        addLog("[CHECKPOINT-FINAL-TO-1] [✓] Checkpoint " .. finalNumber .. " (o último) movido pra cima do Checkpoint 1 (só na sua tela)")
    end

    local function disable()
        if not enabled then return end

        if savedFinal and savedFinal.part.Parent then
            savedFinal.part.CFrame = savedFinal.cframe
        end
        savedFinal = nil

        if savedLandingZone1 and savedLandingZone1.part.Parent then
            savedLandingZone1.part.CFrame = savedLandingZone1.cframe
        end
        savedLandingZone1 = nil

        enabled = false
        addLog("[CHECKPOINT-FINAL-TO-1] Restaurado -- checkpoint final e LandingZone1 de volta pro lugar original")
    end

    local function toggle()
        if enabled then disable() else enable() end
        return enabled
    end

    return {
        toggle = toggle,
        isEnabled = function() return enabled end,
    }
end

local Checkpoint92To1 = buildCheckpoint92To1Feature()

-- ========================================
-- ASMR PARKOUR - LOOP AUTOMÁTICO (aba Jogos): vasculhando o .rbxlx
-- inteiro atrás de TODOS os ProximityPrompt do mapa, achamos que o Mini
-- Parkour tem DUAS entradas físicas totalmente separadas -- uma pra
-- CARRO ("MiniParkourEnter"/"MiniParkourPrompt", do outro lado do mapa)
-- e outra só de PÉ ("MiniParkourFootEnter"/"MiniParkourFootPrompt",
-- ActionText "Play Foot Parkour", bem do lado da placa "ASMR Parkour" --
-- pasta PARKOURFOOT_SIGN). A versão anterior desse hub só procurava a
-- entrada de CARRO -- por isso SEMPRE caía no modo CAR (mesmo sem carro
-- nenhum por perto) e os checkpoints nunca validavam de verdade além do
-- 1º: a gente tava tentando andar a pé pela pista pensada pra carro, em
-- vez de entrar na pista certa (ASMR Parkour). Usando a entrada certa,
-- o próprio servidor já manda Mode="FOOT" e o nível certo -- sem
-- precisar de carro nenhum, só o personagem indo até a posição real de
-- cada checkpoint.
-- ========================================

local asmrParkourLoadedFlag = false
local asmrParkourFinishedFlag = false
local asmrParkourMenuMapName = nil

-- Confirmação REAL do servidor de qual checkpoint foi aceito -- o
-- próprio jogo manda de volta MiniParkourEvent:FireClient(player,
-- "CheckpointText", numeroAtual, total) toda vez que o SERVIDOR aceita
-- um CheckpointTouched (é esse mesmo evento que atualiza o texto
-- "CHECKPOINT X/35" na tela) -- confiar nisso em vez de só assumir que
-- "tocou = contou" é o único jeito de saber se um checkpoint foi
-- REALMENTE validado pelo servidor ou não.
local asmrParkourConfirmedCheckpoint = 0

if Remotes.miniParkourEvent then
    Remotes.miniParkourEvent.OnClientEvent:Connect(function(kind, ...)
        if kind == "LoadParkour" then
            asmrParkourLoadedFlag = true
        elseif kind == "FinishMessage" then
            asmrParkourFinishedFlag = true
        elseif kind == "OpenLevelMenu" then
            local _, levelList = ...
            asmrParkourMenuMapName = nil
            if type(levelList) == "table" then
                -- O menu de PÉ pode ter mais de um nível -- procura um
                -- cujo Título/MapName mencione "ASMR" antes de simplesmente
                -- pegar o primeiro da lista.
                local chosen = nil
                for _, entry in pairs(levelList) do
                    if type(entry) == "table" then
                        local title = tostring(entry.Title or ""):lower()
                        local mapName = tostring(entry.MapName or ""):lower()
                        if title:find("asmr", 1, true) or mapName:find("asmr", 1, true) then
                            chosen = entry
                            break
                        end
                    end
                end
                if not chosen then
                    chosen = levelList[1]
                    if chosen == nil then
                        for _, v in pairs(levelList) do chosen = v break end
                    end
                end
                if chosen then
                    asmrParkourMenuMapName = tostring(chosen.MapName or "")
                end
            end
        elseif kind == "CheckpointText" then
            local current = ...
            local num = tonumber(current)
            if num and num > asmrParkourConfirmedCheckpoint then
                asmrParkourConfirmedCheckpoint = num
            end
        end
    end)
end

local function findAsmrParkourPrompt()
    local enterPart = Workspace:FindFirstChild("MiniParkourFootEnter", true)
    if enterPart then
        local prompt = enterPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then return prompt end
    end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "MiniParkourFootPrompt" then return obj end
    end
    return nil
end

local function buildAsmrParkourFeature()
    local running = false
    local config = { startCheckpoint = 1, endCheckpoint = 32, delaySeconds = 1.5, touchSizeMultiplier = 4 }
    local statusLabel = nil

    local function setStatus(text, color)
        if statusLabel then
            statusLabel.Text = text
            statusLabel.TextColor3 = color
        end
    end

    local function findLocalCheckpointPart(checkpointsFolder, number)
        if not checkpointsFolder then return nil end
        local child = checkpointsFolder:FindFirstChild(tostring(number))
        if not child then return nil end
        if child:IsA("BasePart") then return child end
        return child:FindFirstChildWhichIsA("BasePart", true)
    end

    local function moveCharacterTo(cframe)
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        hrp.CFrame = cframe
        return true
    end

    -- Aumenta o tamanho de CADA checkpoint do clone local (só na SUA
    -- tela, client-side -- igual o Mega Jump Insta já faz com o
    -- Checkpoint 92) -- quem detecta o toque é a física do SEU client
    -- contra essa cópia local (é o Touched dela que dispara o
    -- CheckpointTouched pro servidor), então uma área maior aceita
    -- passar mais longe do centro sem precisar acertar um ponto
    -- pequeno, permitindo ir mais rápido sem cair na 2ª tentativa
    -- (recuar e atravessar) com tanta frequência.
    local function enlargeCheckpointTouchZones(checkpointsFolder, first, last)
        local multiplier = math.max(tonumber(config.touchSizeMultiplier) or 4, 1)
        local count = 0
        for number = first, last do
            local part = findLocalCheckpointPart(checkpointsFolder, number)
            if part then
                part.Size = part.Size * multiplier
                count = count + 1
            end
        end
        return count, multiplier
    end

    -- Pra CADA checkpoint, na posição REAL dele (sem mexer na part),
    -- sobe ~10 studs acima e desce por cima, sempre com o PERSONAGEM
    -- (Foot Parkour não usa carro nenhum). Se essa 1ª tentativa não
    -- confirmar, a 2ª recua um pouco
    -- ATRÁS do checkpoint (na direção oposta à dele) e atravessa por
    -- cima.
    --
    -- A confirmação é por DIFERENÇA (o contador subiu em relação ao
    -- valor de ANTES dessa tentativa específica), nunca por valor
    -- absoluto -- o jogo manda um CheckpointText inicial (ex: "1/35")
    -- só de você estar na largada, ANTES de tocar em qualquer coisa de
    -- verdade -- comparar por valor absoluto faria a gente achar que o
    -- Checkpoint 1 já tinha sido confirmado e pular ele direto pro 2.
    local function captureSequential(checkpointsFolder, first, last)
        local minWait = math.max(tonumber(config.delaySeconds) or 1.5, 1.5)

        for number = first, last do
            if not running or asmrParkourFinishedFlag then break end

            -- Atalho: com a área de toque maior, é comum passar por CIMA
            -- de um checkpoint mais à frente sem querer enquanto anda até
            -- o atual -- se o contador já mostra esse número (ou mais)
            -- como confirmado, nem tenta de novo, só segue pro próximo.
            -- (sem goto/label aqui -- esse executor não suporta essa
            -- sintaxe do Lua, dava "Incomplete statement" na hora de
            -- compilar o script inteiro.)
            if asmrParkourConfirmedCheckpoint >= number then
                addLog("[ASMR-PARKOUR] Checkpoint " .. number .. "/" .. last .. " [✓ CONFIRMADO -- já validado de passagem]")
                setStatus("Status: RODANDO (" .. number .. "/" .. last .. ")", Color3.fromRGB(255, 200, 0))
            else
                local part = findLocalCheckpointPart(checkpointsFolder, number)
                if not part then
                    addLog("[ASMR-PARKOUR] [!] Checkpoint " .. number .. " não encontrado no clone local -- pulando")
                else
                    local baseCFrame = part.CFrame
                    local rotation = baseCFrame - baseCFrame.Position
                    local before = asmrParkourConfirmedCheckpoint
                    local confirmed = false
                    local attempts = 0

                    while running and not confirmed and attempts < 2 do
                        attempts = attempts + 1

                        if attempts == 1 then
                            local highCFrame = CFrame.new(baseCFrame.Position + Vector3.new(0, 10, 0)) * rotation
                            moveCharacterTo(highCFrame)
                            task.wait(0.2)
                            moveCharacterTo(baseCFrame)
                        else
                            local backCFrame = CFrame.new(baseCFrame.Position - (rotation.LookVector * 12) + Vector3.new(0, 3, 0)) * rotation
                            moveCharacterTo(backCFrame)
                            task.wait(0.3)
                            local throughCFrame = CFrame.new(baseCFrame.Position + (rotation.LookVector * 4)) * rotation
                            moveCharacterTo(throughCFrame)
                        end

                        local waitStart = tick()
                        while running and asmrParkourConfirmedCheckpoint <= before and (tick() - waitStart) < minWait do
                            task.wait(0.1)
                        end
                        confirmed = asmrParkourConfirmedCheckpoint > before
                    end

                    if confirmed then
                        addLog("[ASMR-PARKOUR] Checkpoint " .. number .. "/" .. last .. " [✓ CONFIRMADO] (contador: " .. asmrParkourConfirmedCheckpoint .. ")")
                        setStatus("Status: RODANDO (" .. number .. "/" .. last .. ")", Color3.fromRGB(255, 200, 0))
                    else
                        addLog("[ASMR-PARKOUR] [!] Checkpoint " .. number .. "/" .. last .. " NÃO confirmado -- parando o ciclo aqui")
                        setStatus("Status: TRAVOU NO CHECKPOINT " .. number .. " (sem confirmação)", Color3.fromRGB(255, 100, 100))
                        break
                    end
                end
            end
        end
    end

    -- Disparar o prompt só ABRE a tela "Escolha um nível" -- o
    -- LocalScript real do jogo manda o servidor a resposta
    -- "OpenLevelMenu" com o Mode e a lista de níveis, e só carrega a
    -- sessão de verdade (LoadParkour) depois de mandar de volta
    -- MiniParkourEvent:FireServer("StartParkourLevel", { Mode = mode,
    -- MapName = mapName }) -- é isso que o botão "GIOCA" dispara ao ser
    -- clicado. Como essa entrada é EXCLUSIVA do Foot Parkour, forçamos
    -- Mode="FOOT" direto (o servidor já ia mandar isso de qualquer
    -- jeito por essa entrada específica).
    local function runOneCycle()
        local prompt = findAsmrParkourPrompt()
        if not prompt then
            addLog("[ASMR-PARKOUR] [!] MiniParkourFootPrompt não encontrado (MiniParkourFootEnter)")
            return false
        end

        local promptPos = getPromptWorldPosition(prompt)
        local originalCFrame = nil
        if promptPos then
            originalCFrame = teleportPlayerTo(promptPos)
            task.wait(0.3)
        end

        asmrParkourLoadedFlag = false
        asmrParkourMenuMapName = nil
        local fired = triggerPromptGeneric(prompt)
        if not fired then
            addLog("[ASMR-PARKOUR] [!] Não consegui disparar o MiniParkourFootPrompt")
            teleportPlayerBack(originalCFrame)
            return false
        end

        setStatus("Status: ABRINDO TELA DE NÍVEL...", Color3.fromRGB(255, 200, 0))
        local menuStart = tick()
        while running and not asmrParkourMenuMapName and (tick() - menuStart) < 5 do
            task.wait(0.1)
        end

        if not asmrParkourMenuMapName then
            addLog("[ASMR-PARKOUR] [!] Timeout esperando OpenLevelMenu -- tentando de novo no próximo ciclo")
            teleportPlayerBack(originalCFrame)
            return false
        end

        pcall(function()
            Remotes.miniParkourEvent:FireServer("StartParkourLevel", { Mode = "FOOT", MapName = asmrParkourMenuMapName })
        end)

        setStatus("Status: ABRINDO SESSÃO...", Color3.fromRGB(255, 200, 0))
        local loadStart = tick()
        while running and not asmrParkourLoadedFlag and (tick() - loadStart) < 10 do
            task.wait(0.1)
        end

        if not asmrParkourLoadedFlag then
            addLog("[ASMR-PARKOUR] [!] Timeout esperando LoadParkour -- tentando de novo no próximo ciclo")
            teleportPlayerBack(originalCFrame)
            return false
        end

        addLog("[ASMR-PARKOUR] [✓] Sessão aberta (" .. tostring(asmrParkourMenuMapName) .. "), capturando checkpoints...")

        -- Descarta o CheckpointText inicial (largada, ex: "1/35") antes
        -- de começar a contar de verdade -- ver comentário em
        -- captureSequential.
        task.wait(0.5)
        asmrParkourConfirmedCheckpoint = 0
        asmrParkourFinishedFlag = false

        -- O ParkourClient real clona a pista inteira só pra você em
        -- workspace.LOCAL_MINI_PARKOUR_<seu nome>, com uma pasta
        -- Checkpoints própria (peças nomeadas "1", "2", ... "35").
        local parkourClone = Workspace:FindFirstChild("LOCAL_MINI_PARKOUR_" .. LocalPlayer.Name)
        local checkpointsFolder = parkourClone and parkourClone:FindFirstChild("Checkpoints")

        local first = math.floor(config.startCheckpoint)
        local last = math.floor(config.endCheckpoint)

        if not checkpointsFolder then
            addLog("[ASMR-PARKOUR] [!] Clone local da pista (LOCAL_MINI_PARKOUR_" .. LocalPlayer.Name .. ") não encontrado -- não deu pra capturar os checkpoints")
        else
            local enlargedCount, multiplier = enlargeCheckpointTouchZones(checkpointsFolder, first, last)
            if enlargedCount > 0 then
                addLog("[ASMR-PARKOUR] [*] " .. enlargedCount .. " checkpoint(s) com área de toque aumentada (" .. multiplier .. "x, só na sua tela)")
            end
            captureSequential(checkpointsFolder, first, last)
        end

        if running and not asmrParkourFinishedFlag then
            local finishStart = tick()
            while running and not asmrParkourFinishedFlag and (tick() - finishStart) < 8 do
                task.wait(0.1)
            end
        end

        addLog(asmrParkourFinishedFlag and "[ASMR-PARKOUR] [✓] Parkour concluído!" or "[ASMR-PARKOUR] [!] Não confirmei o FinishMessage, seguindo mesmo assim")
        teleportPlayerBack(originalCFrame)
        return true
    end

    local function loopBody()
        while running do
            runOneCycle()
            if not running then break end
            setStatus("Status: RODANDO (reiniciando ciclo)", Color3.fromRGB(255, 200, 0))
            task.wait(2)
        end
        setStatus("Status: PARADO", Color3.fromRGB(100, 200, 100))
        addLog("[ASMR-PARKOUR] === LOOP FINALIZADO ===")
    end

    local function start()
        if running then return end
        if not Remotes.miniParkourEvent then
            addLog("[ASMR-PARKOUR] [!] MiniParkourEvent não encontrado")
            return
        end
        running = true
        addLog("[ASMR-PARKOUR] === LOOP INICIADO === (checkpoints " .. config.startCheckpoint .. " a " .. config.endCheckpoint .. ", " .. config.delaySeconds .. "s entre cada)")
        task.spawn(loopBody)
    end

    local function stop()
        if not running then return end
        running = false
        addLog("[ASMR-PARKOUR] [!] Parando...")
    end

    return {
        config = config,
        start = start,
        stop = stop,
        isRunning = function() return running end,
        setStatusLabel = function(lbl) statusLabel = lbl end,
    }
end

local AsmrParkourShortcut = buildAsmrParkourFeature()

-- ========================================
-- AJUSTE DO JUMPCAR (REMOVIDO): a ideia era reduzir a força do impulso
-- via Attributes do JumpCar e/ou aumentar a Density do carro pra ele não
-- pular tão longe -- mas analisando megaramp_event_loop.lua, o
-- lançamento do JumpCar NÃO é físico/local: o servidor calcula o
-- launchVector inteiro e manda pronto via ClientCarLaunch:FireClient(...)
-- (veja waitForLaunchArgs). Como quem decide "quão longe" é o servidor,
-- ANTES do client saber que o pulo vai acontecer, mudar Attributes ou
-- Density localmente não tem efeito nenhum no cálculo -- por isso essa
-- feature foi removida (confirmado pelo usuário: "mudou nada").
-- ========================================

-- ========================================
-- QUEDA RÁPIDA: já que o lançamento em si vem pronto do servidor (não dá
-- pra reduzir a distância do voo), a alternativa que FUNCIONA é acelerar
-- a QUEDA depois que o pulo já aconteceu -- durante o voo, a física do
-- carro roda com você tendo NetworkOwnership dele (é por isso que o
-- Impulso da Pista já consegue mexer em AssemblyLinearVelocity local e
-- funcionar de verdade), então dá pra somar uma velocidade extra pra
-- baixo todo Heartbeat, igual o Impulso da Pista faz pra frente. Como a
-- gravidade no Roblox não depende de massa (igual física real), isso é
-- diferente de "deixar mais pesado" (que não fazia nada) -- aqui é
-- literalmente adicionar aceleração extra pra baixo. Enquanto o carro
-- está no chão, a colisão normal do próprio jogo cancela essa velocidade
-- sozinha, então não atrapalha dirigir normalmente.
-- ========================================

local function buildExtraGravityFeature()
    local enabled = false
    local connection = nil
    local config = { extraGravity = 50 }
    local statusLabel = nil

    local function setStatus(text, color)
        if statusLabel then
            statusLabel.Text = text
            statusLabel.TextColor3 = color
        end
    end

    local function step(dt)
        local car = findPlayerCarModel()
        local carPart = car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true))
        if not carPart then return end
        carPart.AssemblyLinearVelocity = carPart.AssemblyLinearVelocity - Vector3.new(0, config.extraGravity * dt, 0)
    end

    local function enable()
        if enabled then return end
        enabled = true
        connection = RunService.Heartbeat:Connect(step)
        setStatus("Status: ATIVO (+" .. config.extraGravity .. " studs/s²)", Color3.fromRGB(0, 220, 220))
        addLog("[QUEDA-RAPIDA] [✓] Ativado -- +" .. config.extraGravity .. " studs/s² de gravidade extra enquanto no ar")
    end

    local function disable()
        if not enabled then return end
        enabled = false
        if connection then
            connection:Disconnect()
            connection = nil
        end
        setStatus("Status: DESLIGADO", Color3.fromRGB(100, 200, 100))
        addLog("[QUEDA-RAPIDA] Desativado")
    end

    local function toggle()
        if enabled then disable() else enable() end
        return enabled
    end

    return {
        config = config,
        toggle = toggle,
        isEnabled = function() return enabled end,
        setStatusLabel = function(lbl) statusLabel = lbl end,
    }
end

local ExtraGravity = buildExtraGravityFeature()

-- ========================================
-- ANIMAÇÕES CUSTOM: edita os IDs de idle/andar/correr DENTRO do script
-- "Animate" do personagem (ele tem um slot separado pra cada estado), em
-- vez de forçar uma animação por cima de tudo -- assim pular/etc continua
-- normal, só idle/andar/correr trocam.
-- ========================================

local function buildAnimFeature()

local animConfig = {
    enabled = false,
    idleId = "",
}

local function normalizeAnimId(id)
    if not id or id == "" then return nil end
    id = tostring(id)
    if not id:match("^rbxassetid://") then
        id = "rbxassetid://" .. id
    end
    return id
end

local function debugAnimateStructure()
    local character = LocalPlayer.Character
    if not character then
        addLog("[ANIM] [!] Sem personagem")
        return
    end

    local animateScript = character:FindFirstChild("Animate")
    if not animateScript then
        addLog("[ANIM] [!] Script 'Animate' NÃO existe nesse personagem")
        return
    end

    local lines = { "Estrutura do Animate (" .. animateScript.ClassName .. "):" }

    local function dump(obj, depth)
        for _, child in ipairs(obj:GetChildren()) do
            local extra = ""
            if child:IsA("Animation") then
                extra = " -> AnimationId=" .. tostring(child.AnimationId)
            elseif child:IsA("StringValue") then
                extra = " = " .. tostring(child.Value)
            end
            table.insert(lines, string.rep("  ", depth) .. child.Name .. " (" .. child.ClassName .. ")" .. extra)
            dump(child, depth + 1)
        end
    end
    dump(animateScript, 1)

    local fullText = table.concat(lines, "\n")
    print("[ANIM-DEBUG]\n" .. fullText)

    if typeof(setclipboard) == "function" then
        local copied = pcall(setclipboard, fullText)
        addLog(copied and "[ANIM] Estrutura copiada pro clipboard! (também tá no console)" or "[ANIM] [!] setclipboard falhou -- veja no console")
    else
        addLog("[ANIM] [!] Esse executor não suporta setclipboard -- veja no console mesmo")
    end
end

-- Não precisa de um CharacterAdded manual aqui: o Heartbeat watcher do
-- IDLE FORÇADO (abaixo) já detecta o personagem novo sozinho e reaplica
-- assim que ele fica parado de novo.

-- ========================================
-- IDLE FORÇADO: toca separado do resto, com prioridade Action4 (a mais
-- alta), looped, sem nunca reiniciar sozinho -- assim não briga com o
-- esquema de troca aleatória do jogo (que causava aquele "soco" voltando
-- pro idle normal). Só fica ativo enquanto o personagem tá parado de
-- verdade -- solta sozinho assim que você anda/corre/pula, pra não
-- atropelar o WalkAnim/RunAnim.
-- ========================================

local idleTrack = nil

local function stopForcedIdle()
    if idleTrack then
        pcall(function() idleTrack:Stop() end)
        idleTrack = nil
    end
end

local function applyForcedIdle()
    stopForcedIdle()

    local id = normalizeAnimId(animConfig.idleId)
    if not id then return end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = id

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = true
    track:Play()
    idleTrack = track
end

RunService.Heartbeat:Connect(function()
    if not animConfig.enabled or not animConfig.idleId or animConfig.idleId == "" then
        if idleTrack then stopForcedIdle() end
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local isStandingStill = humanoid.MoveDirection.Magnitude < 0.05
        and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
        and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall

    if isStandingStill then
        if not idleTrack or not idleTrack.IsPlaying then
            applyForcedIdle()
        end
    else
        if idleTrack then stopForcedIdle() end
    end
end)

-- Pra não precisar caçar o ID manualmente: toca o emote/animação que
-- você já tem (equipado ou comprado no jogo) e captura o que tiver
-- tocando no seu Humanoid nesse instante.
local function getCurrentPlayingAnimId()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return nil end

    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok or not tracks then return nil end

    for _, track in ipairs(tracks) do
        if track.Animation and track.Animation.AnimationId and track.Animation.AnimationId ~= "" then
            return track.Animation.AnimationId
        end
    end
    return nil
end

return {
    config = animConfig,
    debug = debugAnimateStructure,
    capture = getCurrentPlayingAnimId,
    applyIdle = applyForcedIdle,
}
end

local AnimFeature = buildAnimFeature()

-- ========================================
-- HELPERS DE WIDGET DO MENU: ficam FORA de setupMenu de propósito -- são
-- puramente genéricos (não dependem de nada específico de uma aba), e
-- cada `local function` daqui dentro de setupMenu contava como 1 dos 200
-- registros locais permitidos por função no Luau. Com o hub crescendo
-- (Checkpoint92To1, Queda Rápida, Aceitar Gifts etc.), setupMenu sozinho
-- estourou esse limite ("exceeded limit 200") -- tirando esses helpers
-- pra cá, o corpo de cada widget (Instance.new, propriedades) passa a
-- contar pro registro DESSA função, não do setupMenu.
--
-- Instances do Roblox (ScrollingFrame etc.) não aceitam campos Lua soltos
-- tipo tab._n = 0 -- por isso o contador de LayoutOrder de cada aba fica
-- numa tabela à parte, indexada pela própria Instance da aba. Reiniciada
-- no começo de cada setupMenu() (troca de idioma reconstrói tudo do
-- zero, então as Instances antigas já não são mais usadas como chave).
-- ========================================

local function buildWidgetHelpers()

local tabOrderCounters = {}

local function tabOrder(tab)
    local n = (tabOrderCounters[tab] or 0) + 1
    tabOrderCounters[tab] = n
    return n
end

local function addSectionLabel(tab, text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color or Color3.fromRGB(0, 190, 100)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.LayoutOrder = tabOrder(tab)
    lbl.Parent = tab
    return lbl
end

local function addButton(tab, text, color, height)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, height or 36)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.LayoutOrder = tabOrder(tab)
    btn.Parent = tab
    return btn
end

local function addTwoButtons(tab, textA, colorA, textB, colorB, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 36)
    row.BackgroundTransparency = 1
    row.LayoutOrder = tabOrder(tab)
    row.Parent = tab

    local a = Instance.new("TextButton")
    a.Size = UDim2.new(0.5, -4, 1, 0)
    a.BackgroundColor3 = colorA
    a.TextColor3 = Color3.new(1, 1, 1)
    a.TextSize = 12
    a.Font = Enum.Font.GothamBold
    a.Text = textA
    a.Parent = row

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -4, 1, 0)
    b.Position = UDim2.new(0.5, 4, 0, 0)
    b.BackgroundColor3 = colorB
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Text = textB
    b.Parent = row

    return a, b
end

local function addFullLabel(tab, initialText, textColor)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    lbl.TextColor3 = textColor or Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = initialText
    lbl.LayoutOrder = tabOrder(tab)
    lbl.Parent = tab
    return lbl
end

local function addTextField(tab, labelText, initialValue)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = labelText
    lbl.LayoutOrder = tabOrder(tab)
    lbl.Parent = tab

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.TextSize = 12
    box.Font = Enum.Font.Gotham
    box.Text = tostring(initialValue)
    box.ClearTextOnFocus = false
    box.LayoutOrder = tabOrder(tab)
    box.Parent = tab

    return box
end

local function addDivider(tab)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    d.BorderSizePixel = 0
    d.LayoutOrder = tabOrder(tab)
    d.Parent = tab
end

local function addInfoLabel(tab, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    lbl.TextSize = 9
    lbl.TextWrapped = true
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Text = text
    lbl.LayoutOrder = tabOrder(tab)
    lbl.Parent = tab
    return lbl
end

local function addToggleRow(tab, labelText, initialEnabled)
    local state = { enabled = initialEnabled }
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = initialEnabled and Color3.fromRGB(0, 110, 60) or Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Text = labelText
    btn.LayoutOrder = tabOrder(tab)
    btn.Parent = tab

    btn.MouseButton1Click:Connect(function()
        state.enabled = not state.enabled
        btn.BackgroundColor3 = state.enabled and Color3.fromRGB(0, 110, 60) or Color3.fromRGB(60, 60, 60)
    end)

    return state
end

-- Botão de toggle genérico pra qualquer feature no formato { toggle =
-- function() -> bool, ... } (Checkpoint92To1, ExtraGravity,
-- AutoAcceptGifts etc.) -- evita repetir o bloco inteiro de criação de
-- TextButton + MouseButton1Click pra cada uma, o que economiza registros
-- locais em setupMenu (cada bloco manual usava 1 local só pro botão).
local function addFeatureToggleButton(tab, label, feature, colorOn, colorOff, height)
    colorOn = colorOn or Color3.fromRGB(0, 130, 60)
    colorOff = colorOff or Color3.fromRGB(60, 60, 60)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, height or 30)
    btn.BackgroundColor3 = colorOff
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Text = label
    btn.LayoutOrder = tabOrder(tab)
    btn.Parent = tab

    btn.MouseButton1Click:Connect(function()
        local isEnabled = feature.toggle()
        btn.BackgroundColor3 = isEnabled and colorOn or colorOff
    end)

    return btn
end

return {
    resetCounters = function() tabOrderCounters = {} end,
    tabOrder = tabOrder,
    addSectionLabel = addSectionLabel,
    addButton = addButton,
    addTwoButtons = addTwoButtons,
    addFullLabel = addFullLabel,
    addTextField = addTextField,
    addDivider = addDivider,
    addInfoLabel = addInfoLabel,
    addToggleRow = addToggleRow,
    addFeatureToggleButton = addFeatureToggleButton,
}
end

local Widgets = buildWidgetHelpers()

-- ========================================
-- MENU: painel único responsivo com abas
--
-- Tudo isso vai dentro de uma função própria (chamada logo em seguida) só
-- por causa de um limite real do Luau: uma única função só aceita até 200
-- variáveis locais, e o resto do script (CORE) sozinho já usa quase todas.
-- Como essa função continua definida no mesmo lugar do arquivo, ela ainda
-- enxerga e escreve normalmente em tudo que já existia antes (rampStatusLabel,
-- alertKeywords, etc.) -- só isola o REGISTRO das variáveis daqui de dentro.
-- ========================================

local function setupMenu()

Widgets.resetCounters()

local hubCamera = Workspace.CurrentCamera

-- Reconstrói do zero (troca de idioma chama setupMenu() de novo) --
-- destrói a instância anterior antes de criar a nova.
local oldGui = playerGui:FindFirstChild("MegaRampHub")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MegaRampHub"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local TITLE_HEIGHT = 34
local SIDEBAR_WIDTH = 128

local frame = Instance.new("Frame")
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
frame.BorderSizePixel = 0
frame.Position = lastFramePosition
frame.Draggable = true
frame.Active = true
frame.ClipsDescendants = true
frame.Parent = screenGui

frame:GetPropertyChangedSignal("Position"):Connect(function()
    lastFramePosition = frame.Position
end)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(70, 120, 200)
outline.Thickness = 1
outline.Transparency = 0.3
outline.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
titleBar.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(120, 190, 255)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "MEGA RAMP HUB"
title.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 32, 0, TITLE_HEIGHT)
minimizeBtn.Position = UDim2.new(1, -32, 0, 0)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.TextSize = 16
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Text = "—"
minimizeBtn.Parent = titleBar

local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, TITLE_HEIGHT)
body.Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT)
body.BackgroundTransparency = 1
body.Parent = frame

local tabBar = Instance.new("ScrollingFrame")
tabBar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 3
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabBar.Parent = body

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLayout.Padding = UDim.new(0, 2)
tabBarLayout.Parent = tabBar

local contentArea = Instance.new("Frame")
contentArea.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0)
contentArea.Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0)
contentArea.BackgroundTransparency = 1
contentArea.Parent = body

local TAB_DEFS = {
    { key = "ramp", labelKey = "tab_ramp" },
    { key = "games", labelKey = "tab_games" },
    { key = "cam", labelKey = "tab_cam" },
    { key = "car", labelKey = "tab_car" },
    { key = "anim", labelKey = "tab_anim" },
    { key = "players", labelKey = "tab_players" },
    { key = "slimes", labelKey = "tab_slimes" },
    { key = "settings", labelKey = "tab_settings" },
}

local tabButtons = {}
local tabFrames = {}

local function makeTabScroll(key)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = key
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Visible = false
    scroll.Parent = contentArea

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = scroll

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = scroll

    return scroll
end

for _, def in ipairs(TAB_DEFS) do
    tabFrames[def.key] = makeTabScroll(def.key)
end

local function selectTab(key)
    lastSelectedTabKey = key
    for k, f in pairs(tabFrames) do
        f.Visible = (k == key)
    end
    for k, b in pairs(tabButtons) do
        local selected = (k == key)
        b.BackgroundColor3 = selected and Color3.fromRGB(40, 46, 60) or Color3.fromRGB(20, 20, 24)
        b.TextColor3 = selected and Color3.fromRGB(120, 190, 255) or Color3.fromRGB(190, 190, 190)
        local accent = b:FindFirstChild("Accent")
        if accent then accent.BackgroundTransparency = selected and 0 or 1 end
    end
end

for i, def in ipairs(TAB_DEFS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(190, 190, 190)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = t(def.labelKey)
    btn.LayoutOrder = i
    btn.Parent = tabBar

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 14)
    padding.Parent = btn

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    accent.BackgroundTransparency = 1
    accent.BorderSizePixel = 0
    accent.Parent = btn

    btn.MouseButton1Click:Connect(function() selectTab(def.key) end)
    tabButtons[def.key] = btn
end

-- --- ABA RAMP ---

local rampTab = tabFrames.ramp
Widgets.addSectionLabel(rampTab, t("sec_ramp_cycle"), Color3.fromRGB(255, 140, 60))
local rampStartBtn, rampStopBtn = Widgets.addTwoButtons(rampTab, t("start"), Color3.fromRGB(0, 150, 0), t("stop"), Color3.fromRGB(150, 0, 0))
local toggleAlertBtn = Widgets.addButton(rampTab, t("btn_alert_rainbow"), Color3.fromRGB(150, 100, 0), 30)
local sellAllBtn = Widgets.addButton(rampTab, t("btn_sell_all"), Color3.fromRGB(0, 150, 100), 34)

rampStatusLabel = Widgets.addFullLabel(rampTab, t("status_stopped"), Color3.fromRGB(100, 200, 100))
rampCountLabel = Widgets.addFullLabel(rampTab, t("label_teleports_forced") .. "0", Color3.fromRGB(200, 200, 255))
rampCycleLabel = Widgets.addFullLabel(rampTab, t("label_cycles_complete") .. "0", Color3.fromRGB(255, 200, 100))

local autoPauseToggleBtn = Instance.new("TextButton")
autoPauseToggleBtn.Size = UDim2.new(1, 0, 0, 26)
autoPauseToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 60)
autoPauseToggleBtn.TextColor3 = Color3.new(1, 1, 1)
autoPauseToggleBtn.TextSize = 11
autoPauseToggleBtn.Font = Enum.Font.GothamBold
autoPauseToggleBtn.Text = t("btn_auto_pause")
autoPauseToggleBtn.LayoutOrder = Widgets.tabOrder(rampTab)
autoPauseToggleBtn.Parent = rampTab
autoPauseToggleBtn.MouseButton1Click:Connect(function()
    autoPauseConfig.enabled = not autoPauseConfig.enabled
    autoPauseToggleBtn.BackgroundColor3 = autoPauseConfig.enabled and Color3.fromRGB(0, 110, 60) or Color3.fromRGB(60, 60, 60)
end)

Widgets.addInfoLabel(rampTab, "Ativa o evento mais caro, teleporta no JumpCar até acabar, vende tudo e repete sozinho até PARAR. Com a pausa automática LIGADA, os 3 loops (Ramp/Memória/Bata o Slime) pausam sozinhos se outro jogador entrar na sala e retomam quando ficar sozinho de novo. Desligada, eles ignoram outros jogadores e continuam rodando direto.")

rampStartBtn.MouseButton1Click:Connect(rampGuardedStart)
rampStopBtn.MouseButton1Click:Connect(rampGuardedStop)
toggleAlertBtn.MouseButton1Click:Connect(function()
    if AlertFeature.keywords[1] == "limitedrainbow" then
        AlertFeature.keywords[1] = "limited"
        toggleAlertBtn.Text = t("btn_alert_all_limited")
    else
        AlertFeature.keywords[1] = "limitedrainbow"
        toggleAlertBtn.Text = t("btn_alert_rainbow")
    end
end)
sellAllBtn.MouseButton1Click:Connect(function() SellAll.sellAllAsync() end)

Widgets.addInfoLabel(rampTab, "O Mega Jump Insta (CarSpawn/JumpCar/Checkpoint92/LandingZone3 colapsados na posição do CarSpawn, com a FORÇA DO IMPULSO do JumpCar zerada e 3 cópias extras do Checkpoint92 em quadrado -- acima/abaixo/frente -- pra garantir o toque) agora liga e desliga JUNTO com esse ciclo: ativa sozinho ao clicar Iniciar e desativa sozinho ao Parar (ou quando pausa automaticamente por outro jogador entrar). 100% client-side -- só a SUA tela muda.")

-- --- ABA GAMES ---

local gamesTab = tabFrames.games
Widgets.addSectionLabel(gamesTab, t("sec_memory"), Color3.fromRGB(0, 190, 100))
local memorySecondsInput = Widgets.addTextField(gamesTab, t("lbl_seconds_per_round"), memoryConfig.completionSeconds)
memorySecondsInput.FocusLost:Connect(function()
    local val = tonumber(memorySecondsInput.Text)
    if val and val >= 0 then
        memoryConfig.completionSeconds = val
    else
        memorySecondsInput.Text = tostring(memoryConfig.completionSeconds)
    end
end)

local memoryStartBtnUi, memoryStopBtnUi = Widgets.addTwoButtons(gamesTab, t("play"), Color3.fromRGB(0, 150, 0), t("stop"), Color3.fromRGB(150, 0, 0))
memoryStatusLabel = Widgets.addFullLabel(gamesTab, t("status_stopped"), Color3.fromRGB(100, 200, 100))
memoryCountLabel = Widgets.addFullLabel(gamesTab, t("label_rounds") .. "0", Color3.fromRGB(200, 200, 255))

Widgets.addInfoLabel(gamesTab, "A Memoria agora roda 100% por remote, igual o Bata o Slime -- sem abrir grid nenhum na tela. 'Segundos por rodada' e o tempo total entre pegar o ServerToken e mandar o ultimo par (reparte esse tempo igualmente entre os pares) -- 14.6s e o valor testado e aprovado, so mude se for testar outro. Igual o Bata o Slime, tambem ativa sozinha o evento mais barato com o maior CashMultiplier (bonus de Cash) e fica nele por ~10 minutos, reativando sozinha quando o tempo acaba. Editar o tempo so tem efeito na PROXIMA rodada.")

Widgets.addDivider(gamesTab)

Widgets.addFeatureToggleButton(gamesTab, "Grudar Painel de Minigames no Evento", MiniGameStick)
MiniGameStick.setStatusLabel(Widgets.addFullLabel(gamesTab, "Status: DESLIGADO (posição original)", Color3.fromRGB(100, 200, 100)))
Widgets.addInfoLabel(gamesTab, "Move o painel do MiniGame1 (usado pela Memória) pra cima do shop de eventos, só na sua tela -- desliga sozinho quando o Bata o Slime inicia (o loop dele ativa o evento sem parar e o painel grudado atrapalha).")

Widgets.addDivider(gamesTab)
Widgets.addSectionLabel(gamesTab, t("sec_hitslime"), Color3.fromRGB(0, 185, 235))
local secondsInput = Widgets.addTextField(gamesTab, t("lbl_seconds_per_round"), hitSlimeConfig.secondsPerRound)
secondsInput.FocusLost:Connect(function()
    local val = tonumber(secondsInput.Text)
    if val and val >= 0 then
        hitSlimeConfig.secondsPerRound = val
    else
        secondsInput.Text = tostring(hitSlimeConfig.secondsPerRound)
    end
end)
local hitSlimeStartBtnUi, hitSlimeStopBtnUi = Widgets.addTwoButtons(gamesTab, t("play"), Color3.fromRGB(0, 150, 0), t("stop"), Color3.fromRGB(150, 0, 0))
hitSlimeStatusLabel = Widgets.addFullLabel(gamesTab, t("status_stopped"), Color3.fromRGB(100, 200, 100))
hitSlimeCountLabel = Widgets.addFullLabel(gamesTab, t("label_rounds") .. "0", Color3.fromRGB(200, 200, 255))

Widgets.addInfoLabel(gamesTab, "Memória joga de verdade. Bata o Slime é atalho por remote (~180s totais pra não cair no \"Too fast\"). Só existe UMA rodada ativa por vez no servidor. Os dois repetem sozinhos até PARAR e pausam se outro jogador entrar.")

memoryStartBtnUi.MouseButton1Click:Connect(memoryGuardedStart)
memoryStopBtnUi.MouseButton1Click:Connect(memoryGuardedStop)
hitSlimeStartBtnUi.MouseButton1Click:Connect(startHitSlimeLoop)
hitSlimeStopBtnUi.MouseButton1Click:Connect(stopHitSlimeLoop)

Widgets.addDivider(gamesTab)
Widgets.addSectionLabel(gamesTab, "ASMR PARKOUR - LOOP AUTOMÁTICO", Color3.fromRGB(255, 140, 60))

local asmrParkourStartInput = Widgets.addTextField(gamesTab, "Checkpoint inicial:", AsmrParkourShortcut.config.startCheckpoint)
asmrParkourStartInput.FocusLost:Connect(function()
    local val = tonumber(asmrParkourStartInput.Text)
    if val and val >= 0 then
        AsmrParkourShortcut.config.startCheckpoint = val
    else
        asmrParkourStartInput.Text = tostring(AsmrParkourShortcut.config.startCheckpoint)
    end
end)

local asmrParkourEndInput = Widgets.addTextField(gamesTab, "Checkpoint final:", AsmrParkourShortcut.config.endCheckpoint)
asmrParkourEndInput.FocusLost:Connect(function()
    local val = tonumber(asmrParkourEndInput.Text)
    if val and val >= 0 then
        AsmrParkourShortcut.config.endCheckpoint = val
    else
        asmrParkourEndInput.Text = tostring(AsmrParkourShortcut.config.endCheckpoint)
    end
end)

local asmrParkourDelayInput = Widgets.addTextField(gamesTab, "Delay entre cada checkpoint (s):", AsmrParkourShortcut.config.delaySeconds)
asmrParkourDelayInput.FocusLost:Connect(function()
    local val = tonumber(asmrParkourDelayInput.Text)
    if val and val > 0 then
        AsmrParkourShortcut.config.delaySeconds = val
    else
        asmrParkourDelayInput.Text = tostring(AsmrParkourShortcut.config.delaySeconds)
    end
end)

local asmrParkourTouchSizeInput = Widgets.addTextField(gamesTab, "Multiplicador da area de toque (ex: 4):", AsmrParkourShortcut.config.touchSizeMultiplier)
asmrParkourTouchSizeInput.FocusLost:Connect(function()
    local val = tonumber(asmrParkourTouchSizeInput.Text)
    if val and val >= 1 then
        AsmrParkourShortcut.config.touchSizeMultiplier = val
    else
        asmrParkourTouchSizeInput.Text = tostring(AsmrParkourShortcut.config.touchSizeMultiplier)
    end
end)

local asmrParkourStartBtn, asmrParkourStopBtn = Widgets.addTwoButtons(gamesTab, "Iniciar", Color3.fromRGB(0, 150, 0), "Parar", Color3.fromRGB(150, 0, 0))
asmrParkourStartBtn.MouseButton1Click:Connect(function() AsmrParkourShortcut.start() end)
asmrParkourStopBtn.MouseButton1Click:Connect(function() AsmrParkourShortcut.stop() end)

AsmrParkourShortcut.setStatusLabel(Widgets.addFullLabel(gamesTab, "Status: PARADO", Color3.fromRGB(100, 200, 100)))

Widgets.addInfoLabel(gamesTab, "Usa a entrada certa do Parkour a pe (MiniParkourFootEnter/MiniParkourFootPrompt, 'Play Foot Parkour' -- achamos vasculhando TODOS os ProximityPrompt do mapa que ela e SEPARADA da entrada de carro, do outro lado do mapa, e fica do lado da placa 'ASMR Parkour'). Nao precisa de carro nenhum: teleporta o PERSONAGEM ate a posicao real de cada checkpoint do seu clone local, esperando a confirmacao real do servidor (o mesmo texto CHECKPOINT X/35 da tela) antes de avancar. Antes de comecar, aumenta a area de toque de cada checkpoint do SEU clone local (multiplicador ajustavel, so na sua tela) -- assim nao precisa acertar um ponto exato, da pra ir mais rapido sem cair na tentativa de recuo. Repete sozinho ate PARAR. O FinishMessage do jogo vem com a recompensa embutida no texto (ex: +500 CASH).")

-- --- ABA CAM ---

local camTab = tabFrames.cam
Widgets.addSectionLabel(camTab, t("sec_freecam"), Color3.fromRGB(0, 150, 255))
local speedInput = Widgets.addTextField(camTab, t("lbl_freecam_speed"), Freecam.config.baseSpeed)
speedInput.FocusLost:Connect(function()
    local val = tonumber(speedInput.Text)
    if val and val > 0 then
        Freecam.config.baseSpeed = val
    else
        speedInput.Text = tostring(Freecam.config.baseSpeed)
    end
end)
local camEnableBtn, camDisableBtn = Widgets.addTwoButtons(camTab, t("enable"), Color3.fromRGB(0, 150, 0), t("disable"), Color3.fromRGB(150, 0, 0))
Freecam.setFreecamStatusLabel(Widgets.addFullLabel(camTab, t("status_inactive"), Color3.fromRGB(100, 200, 100)))
Widgets.addInfoLabel(camTab, "Botão direito + mover = olhar. WASD move, Space/Ctrl sobe e desce, Shift acelera. F5 liga/desliga a qualquer momento, em qualquer aba. Personagem fica ancorado (parado) enquanto ativo.")

camEnableBtn.MouseButton1Click:Connect(Freecam.enable)
camDisableBtn.MouseButton1Click:Connect(Freecam.disable)

-- --- ABA CARRO ---

local carTab = tabFrames.car
Widgets.addSectionLabel(carTab, t("sec_car_boost"), Color3.fromRGB(0, 220, 220))

local carForceInput = Widgets.addTextField(carTab, t("lbl_boost_force"), carBoostConfig.force)
carForceInput.FocusLost:Connect(function()
    local val = tonumber(carForceInput.Text)
    if val and val > 0 then
        carBoostConfig.force = val
    else
        carForceInput.Text = tostring(carBoostConfig.force)
    end
end)

local carToggleBtn = Instance.new("TextButton")
carToggleBtn.Size = UDim2.new(1, 0, 0, 30)
carToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
carToggleBtn.TextColor3 = Color3.new(1, 1, 1)
carToggleBtn.TextSize = 12
carToggleBtn.Font = Enum.Font.GothamBold
carToggleBtn.Text = t("btn_enable_boost")
carToggleBtn.LayoutOrder = Widgets.tabOrder(carTab)
carToggleBtn.Parent = carTab
carToggleBtn.MouseButton1Click:Connect(function()
    carBoostConfig.enabled = not carBoostConfig.enabled
    carToggleBtn.BackgroundColor3 = carBoostConfig.enabled and Color3.fromRGB(0, 130, 60) or Color3.fromRGB(60, 60, 60)
end)

carStatusLabel = Widgets.addFullLabel(carTab, t("status_off"), Color3.fromRGB(100, 200, 100))

Widgets.addInfoLabel(carTab, "Com o impulso ATIVADO, segurar SHIFT empurra o carro pra frente com força extra a cada instante -- solta e para na hora, sem esperar desacelerar. Só funciona enquanto você está dentro do carro na pista. Ajuste a força se sentir fraco ou forte demais.")

Widgets.addDivider(carTab)
Widgets.addSectionLabel(carTab, t("sec_fly"), Color3.fromRGB(0, 220, 220))

local flyToggleBtn = Instance.new("TextButton")
flyToggleBtn.Size = UDim2.new(1, 0, 0, 30)
flyToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
flyToggleBtn.TextColor3 = Color3.new(1, 1, 1)
flyToggleBtn.TextSize = 12
flyToggleBtn.Font = Enum.Font.GothamBold
flyToggleBtn.Text = t("btn_fly_toggle")
flyToggleBtn.LayoutOrder = Widgets.tabOrder(carTab)
flyToggleBtn.Parent = carTab
flyToggleBtn.MouseButton1Click:Connect(function()
    CarFly.toggle()
    flyToggleBtn.BackgroundColor3 = CarFly.config.active and Color3.fromRGB(0, 130, 60) or Color3.fromRGB(60, 60, 60)
end)

CarFly.setStatusLabel(Widgets.addFullLabel(carTab, t("status_off"), Color3.fromRGB(100, 200, 100)))

Widgets.addInfoLabel(carTab, "Desliga a colisão do carro inteiro e deixa você voar com ele (com você sentado dentro) usando WASD/Space/Ctrl relativo à câmera, igual o Free Cam -- Shift acelera. Precisa estar dentro do carro. Desativar devolve a colisão normal.")

Widgets.addDivider(carTab)
Widgets.addSectionLabel(carTab, "CHECKPOINT FINAL -> CHECKPOINT 1", Color3.fromRGB(255, 100, 220))

Widgets.addFeatureToggleButton(carTab, "Mover Checkpoint Final pro Checkpoint 1", Checkpoint92To1)

Widgets.addInfoLabel(carTab, "Move a part do ÚLTIMO checkpoint numerado (pega dinamicamente o maior número da pasta Checkpoints -- hoje é 92, mas continua certo sozinho se o jogo adicionar 93, 94 etc no futuro) pra cima do Checkpoint 1 E a LandingZone1 pra cima da LandingZone3, mantendo a rotação original de cada uma -- independente do Mega Jump Insta, sem mexer em JumpCar/CarSpawn. 100% client-side. Desativar volta as duas pro lugar original.")

Widgets.addDivider(carTab)
Widgets.addSectionLabel(carTab, "QUEDA RÁPIDA (GRAVIDADE EXTRA NO AR)", Color3.fromRGB(0, 220, 220))

local extraGravityInput = Widgets.addTextField(carTab, "Gravidade extra (studs/s², ex: 50):", ExtraGravity.config.extraGravity)
extraGravityInput.FocusLost:Connect(function()
    local val = tonumber(extraGravityInput.Text)
    if val and val >= 0 then
        ExtraGravity.config.extraGravity = val
    else
        extraGravityInput.Text = tostring(ExtraGravity.config.extraGravity)
    end
end)

Widgets.addFeatureToggleButton(carTab, "Ativar Queda Rápida", ExtraGravity)

ExtraGravity.setStatusLabel(Widgets.addFullLabel(carTab, "Status: DESLIGADO", Color3.fromRGB(100, 200, 100)))

Widgets.addInfoLabel(carTab, "O pulo do JumpCar em si vem PRONTO do servidor (não dá pra reduzir a distância), mas a queda DEPOIS do pulo roda com física local, então isso soma uma velocidade extra pra baixo em cima do carro todo Heartbeat -- ele desce mais rápido depois de pular, sem afetar a dirigibilidade normal (a colisão com o chão já cancela essa velocidade sozinha). Editar o valor só tem efeito na PRÓXIMA vez que ativar.")

-- --- ABA ANIM ---

local animTab = tabFrames.anim
Widgets.addSectionLabel(animTab, t("sec_anim_idle"), Color3.fromRGB(255, 200, 0))

local idleBox = Widgets.addTextField(animTab, t("lbl_idle_id"), AnimFeature.config.idleId)
idleBox.FocusLost:Connect(function() AnimFeature.config.idleId = idleBox.Text end)

local captureBtn = Widgets.addButton(animTab, t("btn_capture_anim"), Color3.fromRGB(90, 90, 200), 32)
captureBtn.MouseButton1Click:Connect(function()
    local id = AnimFeature.capture()
    if id then
        AnimFeature.config.idleId = id
        idleBox.Text = id
        addLog("[ANIM] Capturado: " .. id)
    else
        addLog("[ANIM] [!] Nenhuma animação tocando agora -- toque o emote primeiro")
    end
end)

local diagBtn = Widgets.addButton(animTab, t("btn_diagnose"), Color3.fromRGB(150, 100, 0), 32)
diagBtn.MouseButton1Click:Connect(function() AnimFeature.debug() end)

local animToggleBtn = Instance.new("TextButton")
animToggleBtn.Size = UDim2.new(1, 0, 0, 30)
animToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
animToggleBtn.TextColor3 = Color3.new(1, 1, 1)
animToggleBtn.TextSize = 12
animToggleBtn.Font = Enum.Font.GothamBold
animToggleBtn.Text = t("btn_apply_idle")
animToggleBtn.LayoutOrder = Widgets.tabOrder(animTab)
animToggleBtn.Parent = animTab
animToggleBtn.MouseButton1Click:Connect(function()
    AnimFeature.config.enabled = not AnimFeature.config.enabled
    animToggleBtn.BackgroundColor3 = AnimFeature.config.enabled and Color3.fromRGB(0, 130, 60) or Color3.fromRGB(60, 60, 60)
    if AnimFeature.config.enabled then AnimFeature.applyIdle() end
end)

local animReapplyBtn = Widgets.addButton(animTab, t("btn_reapply"), Color3.fromRGB(90, 90, 200), 32)
animReapplyBtn.MouseButton1Click:Connect(function()
    AnimFeature.config.enabled = true
    animToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 60)
    AnimFeature.applyIdle()
end)

Widgets.addInfoLabel(animTab, "IDLE toca separado (prioridade alta, sem reiniciar sozinho) e só fica ativo enquanto você tá parado -- solta na hora que anda/corre/pula, então não briga com o jogo. ANDAR/CORRER voltaram a ser 100% do jogo (sem forçação). Não precisa caçar o ID: toque o emote/animação que você já tem e clique CAPTURAR pra preencher o IDLE sozinho. Só funciona com animações que você tem direito de usar -- é permissão do próprio Roblox no ID. Reaplica sozinho se você morrer/respawnar.")

-- --- ABA JOGADORES ---

local playersTab = tabFrames.players
Widgets.addSectionLabel(playersTab, t("sec_players_in_match"), Color3.fromRGB(0, 150, 255))
Freecam.setPlayersStatusLabel(Widgets.addFullLabel(playersTab, t("status_none_normal_cam"), Color3.fromRGB(100, 200, 100)))
local stopSpectateBtnUi = Widgets.addButton(playersTab, t("btn_stop_spectate"), Color3.fromRGB(150, 0, 0), 32)
stopSpectateBtnUi.MouseButton1Click:Connect(function() Freecam.stopSpectate() end)

Widgets.addInfoLabel(playersTab, "Spectate é 100% real: só muda SUA câmera pra seguir o jogador escolhido, seu personagem continua parado onde estava. NÃO dá pra ativar automações (tipo o ciclo do Mega Ramp) no client de outro jogador remotamente -- cada um precisaria rodar o próprio script pra isso.")

local rowsContainer = Instance.new("Frame")
rowsContainer.Size = UDim2.new(1, 0, 0, 0)
rowsContainer.AutomaticSize = Enum.AutomaticSize.Y
rowsContainer.BackgroundTransparency = 1
rowsContainer.LayoutOrder = Widgets.tabOrder(playersTab)
rowsContainer.Parent = playersTab

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Padding = UDim.new(0, 4)
rowsLayout.Parent = rowsContainer

local function rebuildPlayerRows()
    for _, child in ipairs(rowsContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local order = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            order = order + 1

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            row.LayoutOrder = order
            row.Parent = rowsContainer

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.4, -6, 1, 0)
            nameLbl.Position = UDim2.new(0, 6, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.TextColor3 = Color3.new(1, 1, 1)
            nameLbl.TextSize = 11
            nameLbl.Font = Enum.Font.Gotham
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Text = plr.Name
            nameLbl.Parent = row

            local tpBtn = Instance.new("TextButton")
            tpBtn.Size = UDim2.new(0.3, -6, 1, -6)
            tpBtn.Position = UDim2.new(0.4, 0, 0, 3)
            tpBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            tpBtn.TextColor3 = Color3.new(1, 1, 1)
            tpBtn.TextSize = 10
            tpBtn.Font = Enum.Font.GothamBold
            tpBtn.Text = "Teleportar"
            tpBtn.Parent = row

            tpBtn.MouseButton1Click:Connect(function()
                teleportToPlayer(plr)
            end)

            local specBtn = Instance.new("TextButton")
            specBtn.Size = UDim2.new(0.3, -6, 1, -6)
            specBtn.Position = UDim2.new(0.7, 0, 0, 3)
            specBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
            specBtn.TextColor3 = Color3.new(1, 1, 1)
            specBtn.TextSize = 10
            specBtn.Font = Enum.Font.GothamBold
            specBtn.Text = t("btn_spectate")
            specBtn.Parent = row

            specBtn.MouseButton1Click:Connect(function()
                Freecam.startSpectate(plr)
            end)
        end
    end

    if order == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 28)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLbl.TextSize = 10
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.Text = t("lbl_no_other_players")
        emptyLbl.LayoutOrder = 1
        emptyLbl.Parent = rowsContainer
    end
end

Players.PlayerAdded:Connect(function() task.wait(0.1) rebuildPlayerRows() end)
Players.PlayerRemoving:Connect(function() task.wait(0.15) rebuildPlayerRows() end)

rebuildPlayerRows()

Widgets.addDivider(playersTab)
Widgets.addSectionLabel(playersTab, t("sec_top5"), Color3.fromRGB(255, 215, 0))
Widgets.addInfoLabel(playersTab, "Vem direto do placar Top 5 que o servidor já manda pra todo mundo (remote LeaderboardUpdate) -- não precisei construir nada, só escutei o mesmo remote que o próprio jogo usa pra desenhar aquele painel.")

local leaderboardRowsContainer = Instance.new("Frame")
leaderboardRowsContainer.Size = UDim2.new(1, 0, 0, 0)
leaderboardRowsContainer.AutomaticSize = Enum.AutomaticSize.Y
leaderboardRowsContainer.BackgroundTransparency = 1
leaderboardRowsContainer.LayoutOrder = Widgets.tabOrder(playersTab)
leaderboardRowsContainer.Parent = playersTab

local leaderboardRowsLayout = Instance.new("UIListLayout")
leaderboardRowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
leaderboardRowsLayout.Padding = UDim.new(0, 3)
leaderboardRowsLayout.Parent = leaderboardRowsContainer

local function shortNumberDisplay(n)
    n = tonumber(n) or 0
    local abs = math.abs(n)
    if abs >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif abs >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif abs >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif abs >= 1e3 then
        return string.format("%.2fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

refreshLeaderboardUI = function()
    for _, child in ipairs(leaderboardRowsContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local list = latestLeaderboardData or {}
    if #list == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 20)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLbl.TextSize = 10
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.Text = t("lbl_waiting_server")
        emptyLbl.LayoutOrder = 1
        emptyLbl.Parent = leaderboardRowsContainer
        return
    end

    for i, entry in ipairs(list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        row.LayoutOrder = i
        row.Parent = leaderboardRowsContainer

        local name = tostring(entry.Name or entry.DisplayName or "?")
        if entry.VIP then name = "[VIP] " .. name end
        local cashText = "$" .. shortNumberDisplay(entry.Cash or 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 1, 0)
        lbl.Position = UDim2.new(0, 4, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.TextSize = 10
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = "#" .. tostring(entry.Position or i) .. "  " .. name .. "  —  " .. cashText
        lbl.Parent = row
    end
end

refreshLeaderboardUI()

-- --- ABA SLIMES: aceitar gifts automaticamente ---

local slimesTab = tabFrames.slimes
Widgets.addSectionLabel(slimesTab, "ACEITAR GIFTS AUTOMATICAMENTE", Color3.fromRGB(255, 140, 220))

Widgets.addFeatureToggleButton(slimesTab, "Ativar Aceitar Gifts Automaticamente", AutoAcceptGifts)

Widgets.addInfoLabel(slimesTab, "Quando alguém te manda um gift, dispara GiftAction:FireServer sozinho com as variantes de aceitar mais prováveis E clica sozinho em qualquer botão de confirmação (Aceitar/OK/Confirmar/Accept/Yes/Sim) que aparecer na tela -- cobre tanto o caso de aceitar direto por remote quanto o de precisar confirmar num popup. Desativar para de aceitar sozinho.")

-- --- ABA CONFIGURACOES ---

local settingsTab = tabFrames.settings
Widgets.addSectionLabel(settingsTab, t("settings_title"), Color3.fromRGB(120, 190, 255))

local langPtBtn = Widgets.addButton(settingsTab, "Portugues", Color3.fromRGB(60, 60, 60), 32)
local langEnBtn = Widgets.addButton(settingsTab, "English", Color3.fromRGB(60, 60, 60), 32)
local langEsBtn = Widgets.addButton(settingsTab, "Espanol", Color3.fromRGB(60, 60, 60), 32)

local langButtons = { pt = langPtBtn, en = langEnBtn, es = langEsBtn }

local function refreshLangButtons()
    for lang, btn in pairs(langButtons) do
        btn.BackgroundColor3 = (Language.current == lang) and Color3.fromRGB(0, 110, 60) or Color3.fromRGB(60, 60, 60)
    end
end
refreshLangButtons()

local function setLanguage(lang)
    Language.current = lang
    addLog("[CONFIG] Idioma definido: " .. lang .. ", reconstruindo o menu...")
    lastSelectedTabKey = "settings"
    setupMenu()
end

langPtBtn.MouseButton1Click:Connect(function() setLanguage("pt") end)
langEnBtn.MouseButton1Click:Connect(function() setLanguage("en") end)
langEsBtn.MouseButton1Click:Connect(function() setLanguage("es") end)

Widgets.addInfoLabel(settingsTab, t("settings_info"))

Widgets.addDivider(settingsTab)
Widgets.addSectionLabel(settingsTab, "OCULTAR HUD DO JOGO", Color3.fromRGB(150, 220, 255))

Widgets.addFeatureToggleButton(settingsTab, "Ocultar HUD (ícones Índice/Loja/Inventário/etc)", HideHud)

Widgets.addInfoLabel(settingsTab, "Esconde os ScreenGuis nativos do jogo (os ícones de atalho no canto esquerdo -- Índice, Loja, Inventário, Carros, Admin, Pintar) e tenta MANTER visível o que mostra dinheiro ganho (canto inferior esquerdo, incluindo os popups '+$X') e o leaderboard (canto superior direito). A decisão de esconder ou manter é por palavra-chave no NOME de cada GUI do jogo -- como não temos o código-fonte do jogo pra saber os nomes exatos, TODO ScreenGui encontrado (escondido ou mantido) aparece no log. Se algo sumiu que não devia (ou ficou visível o que devia sumir), me manda o log que eu ajusto a lista de palavras-chave. Desativar traz tudo de volta.")

Widgets.addDivider(settingsTab)
Widgets.addSectionLabel(settingsTab, "ADMIN ABUSE", Color3.fromRGB(255, 90, 100))
local openAdminAbuseBtn = Widgets.addButton(settingsTab, "Abrir/Fechar Painel Admin Abuse", Color3.fromRGB(185, 45, 50), 34)
openAdminAbuseBtn.MouseButton1Click:Connect(function() AdminAbusePanelFeature.toggle() end)

local adminMaskState = { enabled = false }
local adminMaskBtn = Instance.new("TextButton")
adminMaskBtn.Size = UDim2.new(1, 0, 0, 30)
adminMaskBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
adminMaskBtn.TextColor3 = Color3.new(1, 1, 1)
adminMaskBtn.TextSize = 12
adminMaskBtn.Font = Enum.Font.GothamBold
adminMaskBtn.Text = "Mascara Admin (Client-Side)"
adminMaskBtn.LayoutOrder = Widgets.tabOrder(settingsTab)
adminMaskBtn.Parent = settingsTab
adminMaskBtn.MouseButton1Click:Connect(function()
    adminMaskState.enabled = not adminMaskState.enabled
    adminMaskBtn.BackgroundColor3 = adminMaskState.enabled and Color3.fromRGB(0, 130, 60) or Color3.fromRGB(60, 60, 60)
    AdminAbusePanelFeature.forceAdminMask(adminMaskState.enabled)
end)

local grantAdminBtn = Widgets.addButton(settingsTab, "Solicitar AdminAccess", Color3.fromRGB(220, 100, 30), 34)
grantAdminBtn.MouseButton1Click:Connect(function()
    addLog("[ADMIN-ABUSE] Enviando GrantAdminAccess pro servidor...")
    if Remotes.adminAbuseRemote then
        Remotes.adminAbuseRemote:FireServer("GrantAdminAccess")
        addLog("[ADMIN-ABUSE] ✓ Requisição enviada (aguardando resposta do servidor)")
    else
        addLog("[ADMIN-ABUSE] [!] AdminAbuseRemote não encontrado!")
    end
end)

Widgets.addInfoLabel(settingsTab, "SERVIDOR: Atalho pro painel de admin do jogo (3x boxes, tree rush, coins, anúncios, sequência 30min). 'Solicitar AdminAccess' manda solicitação pro servidor, que valida seu UserId e responde com AdminAccess=true se você está na lista de admins.\n\nCLIENT-SIDE: 'Mascara Admin' força admin só no seu lado (sem passar pelo servidor) -- destranca todos os botões do painel pra testar. Funciona 100% localmente, mas as ações só fazem efeito de verdade se o servidor reconhecer admin de fato quando você clica.")

local triple3xBoxState = { enabled = false }
local triple3xBoxBtn = Widgets.addButton(settingsTab, "Ativar 3X Boxes (via Admin)", Color3.fromRGB(105, 75, 220), 34)
triple3xBoxBtn.MouseButton1Click:Connect(function()
    triple3xBoxState.enabled = not triple3xBoxState.enabled
    triple3xBoxBtn.BackgroundColor3 = triple3xBoxState.enabled and Color3.fromRGB(0, 130, 60) or Color3.fromRGB(105, 75, 220)
    triple3xBoxBtn.Text = triple3xBoxState.enabled and "Desativar 3X Boxes (via Admin)" or "Ativar 3X Boxes (via Admin)"
    addLog("[ADMIN-ABUSE] Enviando SetTripleBoxes(" .. tostring(triple3xBoxState.enabled) .. ") pro servidor...")
    if Remotes.adminAbuseRemote then
        pcall(function() Remotes.adminAbuseRemote:FireServer("SetTripleBoxes", { Enabled = triple3xBoxState.enabled }) end)
        addLog("[ADMIN-ABUSE] ✓ Requisição enviada (o resultado real -- se funcionou ou não -- chega logo em seguida no log, mandado pelo servidor)")
    else
        addLog("[ADMIN-ABUSE] [!] AdminAbuseRemote não encontrado!")
    end
end)
Widgets.addInfoLabel(settingsTab, "Liga/desliga o 3X Boxes direto, sem precisar abrir o painel Admin Abuse. Manda SetTripleBoxes pro servidor -- o retorno de verdade (se ativou ou foi recusado por falta de permissão) aparece automaticamente no log do hub logo depois de clicar, mandado pelo servidor via AdminResult.")

Widgets.addDivider(settingsTab)
Widgets.addSectionLabel(settingsTab, "TROCAR OUTFIT", Color3.fromRGB(0, 220, 220))

local function clonarOutfit(targetUserId)
    local targetPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == targetUserId then
            targetPlayer = player
            break
        end
    end

    if not targetPlayer then
        addLog("[OUTFIT] [!] Jogador com ID " .. targetUserId .. " não encontrado")
        return false
    end

    if not targetPlayer.Character then
        addLog("[OUTFIT] [!] Personagem do jogador não carregado ainda")
        return false
    end

    local character = LocalPlayer.Character
    if not character then
        addLog("[OUTFIT] [!] Seu personagem não carregado")
        return false
    end

    local targetCharacter = targetPlayer.Character

    local CLONABLE_CLASSES = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "BodyColors" }

    local function isClonable(inst)
        for _, className in ipairs(CLONABLE_CLASSES) do
            if inst:IsA(className) then return true end
        end
        return false
    end

    -- Remove roupas/acessórios/cor de pele antigos
    for _, child in ipairs(character:GetChildren()) do
        if isClonable(child) then
            pcall(function() child:Destroy() end)
        end
    end

    -- Clona Accessories, Shirt, Pants, ShirtGraphic e BodyColors
    local clonadosCount = 0
    for _, child in ipairs(targetCharacter:GetChildren()) do
        if isClonable(child) then
            local cloned = child:Clone()
            cloned.Parent = character
            clonadosCount = clonadosCount + 1
        end
    end

    addLog("[OUTFIT] [✓] Outfit clonado de " .. targetPlayer.Name .. " (" .. clonadosCount .. " itens)")
    return true
end

local outfitIdInput = Widgets.addTextField(settingsTab, "ID do jogador:", "")
local clonarOutfitBtn = Widgets.addButton(settingsTab, "Clonar Outfit", Color3.fromRGB(0, 180, 220), 34)

clonarOutfitBtn.MouseButton1Click:Connect(function()
    local userId = tonumber(outfitIdInput.Text)
    if userId then
        clonarOutfit(userId)
    else
        addLog("[OUTFIT] [!] ID inválido")
    end
end)

Widgets.addInfoLabel(settingsTab, "Digita o UserID de um jogador e clica 'Clonar Outfit' pra copiar suas roupas visualmente. Seu UserId permanece o mesmo (não é spoofing). Só muda a aparência visual.")

Widgets.addDivider(settingsTab)
Widgets.addSectionLabel(settingsTab, "LOG DO HUB", Color3.fromRGB(200, 200, 200))
local copyLogBtn = Widgets.addButton(settingsTab, "Copiar Log Completo (Clipboard)", Color3.fromRGB(90, 90, 200), 34)
copyLogBtn.MouseButton1Click:Connect(function() copyHubLogToClipboard() end)
Widgets.addInfoLabel(settingsTab, "Copia as últimas " .. HUB_LOG_BUFFER_MAX .. " linhas de log (com horário) pro clipboard, prontas pra colar -- assim não precisa mais de print de tela do console pra mandar o log.")

-- --- RESPONSIVO + MINIMIZAR ---

local MIN_W, MAX_W = 380, 480
local MIN_H, MAX_H = 340, 580

local expandedHeight = 420
local minimized = false

local function computeSize()
    local viewport = hubCamera.ViewportSize
    local w = math.clamp(viewport.X - 24, MIN_W, MAX_W)
    local h = math.clamp(viewport.Y - 90, MIN_H, MAX_H)
    return w, h
end

local function applyResponsiveSize()
    local w, h = computeSize()
    expandedHeight = h
    frame.Size = UDim2.new(0, w, 0, minimized and TITLE_HEIGHT or h)

    local viewport = hubCamera.ViewportSize
    local absPos = frame.AbsolutePosition
    local clampedX = math.clamp(absPos.X, 0, math.max(0, viewport.X - w))
    local clampedY = math.clamp(absPos.Y, 0, math.max(0, viewport.Y - TITLE_HEIGHT))
    if clampedX ~= absPos.X or clampedY ~= absPos.Y then
        frame.Position = UDim2.new(0, clampedX, 0, clampedY)
    end
end

applyResponsiveSize()
hubCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveSize)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, minimized and TITLE_HEIGHT or expandedHeight)
    minimizeBtn.Text = minimized and "▢" or "—"
end)

selectTab(lastSelectedTabKey)

addLog("Hub carregado. Use as abas pra navegar. F5 liga/desliga a Free Cam a qualquer momento.")
print("[+] MEGA RAMP HUB carregado!")

end

setupMenu()
