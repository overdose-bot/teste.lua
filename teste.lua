local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

-- Configurações da API
local API_BASE_URL = "http://192.168.1.7:8000"
local CHECK_INTERVAL = 5

-- Variáveis globais
local lastMessageIds = {}
local activeNotifications = {}
local notificationQueue = {}
local isChecking = false
local mainGui = nil
local isTryingToJoin = false
local currentJobId = nil
local attemptCount = 0
local maxAttempts = 6

-- Canais disponíveis (serão carregados da API)
local availableChannels = {}
local selectedChannels = {}

-- Estado do sistema
local systemInitialized = false
local channelSelectionGui = nil
local isShowingNotification = false

-- Função auxiliar para contar canais selecionados
local function getSelectedChannelsCount()
    local count = 0
    for _ in pairs(selectedChannels) do
        count = count + 1
    end
    return count
end

local function leaveServer()
    local player = Players.LocalPlayer
    if not player then return false end
    
    print("🚪 Saindo do servidor...")
    
    local success1, err1 = pcall(function()
        player:Kick("Saindo do servidor")
    end)
    
    if success1 then
        print("✅ Saiu do servidor via Kick")
        return true
    end
    
    local success2, err2 = pcall(function()
        TeleportService:Teleport(0, player)
    end)
    
    if success2 then
        print("✅ Saiu do servidor via Teleport")
        return true
    end
    
    warn("❌ Todos os métodos falharam para sair do servidor")
    return false
end

local function showTempMessage(message, color)
    local player = Players.LocalPlayer
    if not player or not player:FindFirstChild("PlayerGui") then return end
    
    local tempGui = Instance.new("ScreenGui")
    tempGui.Name = "TempMessage"
    tempGui.Parent = player.PlayerGui
    tempGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(0.5, -150, 0.8, -30)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    frame.BorderSizePixel = 0
    frame.Parent = tempGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    spawn(function()
        wait(3)
        if tempGui and tempGui.Parent then
            tempGui:Destroy()
        end
    end)
end

local function tryJoinServer(jobId)
    if isTryingToJoin then
        print("⚠️ Já está tentando entrar em outro servidor")
        return
    end
    
    isTryingToJoin = true
    currentJobId = jobId
    attemptCount = 0
    
    print("🎯 Iniciando " .. maxAttempts .. " tentativas para entrar no Job ID: " .. jobId)
    print("💡 Pressione K para parar as tentativas")
    
    local player = Players.LocalPlayer
    if not player then
        isTryingToJoin = false
        return
    end
    
    local function attemptJoin()
        if not isTryingToJoin then 
            print("🛑 Tentativas canceladas pelo usuário")
            return 
        end
        
        attemptCount = attemptCount + 1
        
        if attemptCount > maxAttempts then
            print("❌ Limite de " .. maxAttempts .. " tentativas atingido")
            isTryingToJoin = false
            showTempMessage("Limite de " .. maxAttempts .. " tentativas atingido", Color3.fromRGB(255, 100, 100))
            return
        end
        
        print("🔄 Tentativa " .. attemptCount .. "/" .. maxAttempts .. " para entrar no servidor...")
        showTempMessage("Tentativa " .. attemptCount .. "/" .. maxAttempts, Color3.fromRGB(255, 255, 100))
        
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
        end)
        
        if success then
            print("✅ Conexão estabelecida na tentativa " .. attemptCount .. "/" .. maxAttempts)
            isTryingToJoin = false
            showTempMessage("Conectado na tentativa " .. attemptCount, Color3.fromRGB(100, 255, 100))
        else
            print("❌ Tentativa " .. attemptCount .. "/" .. maxAttempts .. " falhou: " .. tostring(err))
            
            if isTryingToJoin and attemptCount < maxAttempts then
                wait(2)
                attemptJoin()
            elseif attemptCount >= maxAttempts then
                print("❌ Todas as " .. maxAttempts .. " tentativas falharam")
                isTryingToJoin = false
                showTempMessage("Todas as " .. maxAttempts .. " tentativas falharam", Color3.fromRGB(255, 100, 100))
            end
        end
    end
    
    spawn(attemptJoin)
end

local function createNotification(brainrotData)
    local player = Players.LocalPlayer
    if not player or not player:FindFirstChild("PlayerGui") then 
        print("❌ Player ou PlayerGui não encontrado")
        return nil
    end
    
    print("🎯 Criando notificação para: " .. brainrotData.name)
    
    local success, notificationGui = pcall(function()
        -- Criar GUI da notificação
        local gui = Instance.new("ScreenGui")
        gui.Name = "BrainrotNotificationGUI_" .. HttpService:GenerateGUID(false)
        gui.Parent = player.PlayerGui
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        -- Frame principal da notificação
        local notificationFrame = Instance.new("Frame")
        notificationFrame.Size = UDim2.new(0, 350, 0, 120)
        notificationFrame.Position = UDim2.new(1, 400, 0.7, 0)
        notificationFrame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
        notificationFrame.BorderSizePixel = 0
        notificationFrame.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = notificationFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(114, 137, 218)
        stroke.Thickness = 3
        stroke.Parent = notificationFrame
        
        -- Ícone
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.Position = UDim2.new(0, 15, 0, 15)
        icon.BackgroundTransparency = 1
        icon.Text = "💰"
        icon.TextColor3 = Color3.fromRGB(255, 215, 0)
        icon.TextSize = 30
        icon.Font = Enum.Font.GothamBold
        icon.Parent = notificationFrame
        
        -- Informações do brainrot
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 240, 0, 30)
        nameLabel.Position = UDim2.new(0, 85, 0, 15)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = brainrotData.name or "Nome não disponível"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 16
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = notificationFrame
        
        local rateLabel = Instance.new("TextLabel")
        rateLabel.Size = UDim2.new(0, 240, 0, 25)
        rateLabel.Position = UDim2.new(0, 85, 0, 45)
        rateLabel.BackgroundTransparency = 1
        rateLabel.Text = "💰 " .. (brainrotData.rate or "N/A") .. "/s"
        rateLabel.TextColor3 = Color3.fromRGB(87, 242, 135)
        rateLabel.TextSize = 14
        rateLabel.Font = Enum.Font.GothamBold
        rateLabel.TextXAlignment = Enum.TextXAlignment.Left
        rateLabel.Parent = notificationFrame
        
        local jobLabel = Instance.new("TextLabel")
        jobLabel.Size = UDim2.new(0, 240, 0, 20)
        jobLabel.Position = UDim2.new(0, 85, 0, 70)
        jobLabel.BackgroundTransparency = 1
        jobLabel.Text = "🎯 " .. string.sub(brainrotData.jobId or "unknown", 1, 8) .. "..."
        jobLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        jobLabel.TextSize = 12
        jobLabel.Font = Enum.Font.Gotham
        jobLabel.TextXAlignment = Enum.TextXAlignment.Left
        jobLabel.Parent = notificationFrame
        
        -- Botão de ação
        local actionButton = Instance.new("TextButton")
        actionButton.Size = UDim2.new(0, 120, 0, 30)
        actionButton.Position = UDim2.new(0, 200, 0, 80)
        actionButton.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
        actionButton.Text = "🎮 ENTRAR"
        actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        actionButton.TextSize = 12
        actionButton.Font = Enum.Font.GothamBold
        actionButton.Parent = notificationFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = actionButton
        
        -- Botão de fechar
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 30, 0, 30)
        closeButton.Position = UDim2.new(1, -35, 0, 5)
        closeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        closeButton.Text = "X"
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.TextSize = 14
        closeButton.Font = Enum.Font.GothamBold
        closeButton.Parent = notificationFrame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
        closeCorner.Parent = closeButton
        
        -- Barra de progresso
        local progressBar = Instance.new("Frame")
        progressBar.Size = UDim2.new(1, -20, 0, 4)
        progressBar.Position = UDim2.new(0, 10, 1, -8)
        progressBar.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
        progressBar.BorderSizePixel = 0
        progressBar.Parent = notificationFrame
        
        local progressCorner = Instance.new("UICorner")
        progressCorner.CornerRadius = UDim.new(0, 2)
        progressCorner.Parent = progressBar
        
        -- Animação de entrada
        local targetPosition = UDim2.new(1, -370, 0.7, 0)
        local startPosition = UDim2.new(1, 400, 0.7, 0)
        
        notificationFrame.Position = startPosition
        
        local tweenIn = TweenService:Create(notificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = targetPosition
        })
        
        tweenIn:Play()
        
        -- Ação do botão entrar
        actionButton.MouseButton1Click:Connect(function()
            print("🎮 Tentando entrar no brainrot: " .. brainrotData.name)
            actionButton.Text = "⏳"
            actionButton.BackgroundColor3 = Color3.fromRGB(250, 166, 26)
            
            if brainrotData.jobId then
                tryJoinServer(brainrotData.jobId)
            else
                print("❌ Job ID não disponível")
            end
        end)
        
        -- Ação do botão fechar
        closeButton.MouseButton1Click:Connect(function()
            if gui and gui.Parent then
                local tweenOut = TweenService:Create(notificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                    Position = startPosition
                })
                
                tweenOut:Play()
                tweenOut.Completed:Wait()
                gui:Destroy()
                isShowingNotification = false
                print("📭 Notificação fechada pelo usuário")
            end
        end)
        
        -- Efeitos hover
        actionButton.MouseEnter:Connect(function()
            actionButton.BackgroundColor3 = Color3.fromRGB(134, 157, 238)
        end)
        
        actionButton.MouseLeave:Connect(function()
            if actionButton.Text == "🎮 ENTRAR" then
                actionButton.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
            end
        end)
        
        closeButton.MouseEnter:Connect(function()
            closeButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
        end)
        
        closeButton.MouseLeave:Connect(function()
            closeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end)
        
        -- Animação da barra de progresso e auto-remover
        spawn(function()
            local duration = 10
            local startTime = tick()
            
            while tick() - startTime < duration do
                if not gui or not gui.Parent then break end
                
                local elapsed = tick() - startTime
                local progress = 1 - (elapsed / duration)
                
                progressBar.Size = UDim2.new(progress, -20, 0, 4)
                
                if elapsed > duration - 3 then
                    progressBar.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
                end
                
                wait(0.1)
            end
            
            -- Auto-remover após o tempo
            if gui and gui.Parent then
                local tweenOut = TweenService:Create(notificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                    Position = startPosition
                })
                
                tweenOut:Play()
                tweenOut.Completed:Wait()
                gui:Destroy()
                isShowingNotification = false
                print("⏰ Notificação removida automaticamente")
            end
        end)
        
        return gui
    end)
    
    if success then
        isShowingNotification = true
        print("✅ Notificação criada com sucesso!")
        return notificationGui
    else
        print("❌ ERRO ao criar notificação: " .. tostring(notificationGui))
        isShowingNotification = false
        return nil
    end
end



-- Função para processar a fila de notificações - VERSÃO CORRIGIDA
local function processNotificationQueue()
    if #notificationQueue == 0 then
        return
    end
    
    print("🔍 ProcessNotificationQueue - Fila: " .. #notificationQueue .. " itens")
    
    if isShowingNotification then
        print("⏳ Já mostrando notificação, aguardando...")
        return
    end
    
    local brainrotData = notificationQueue[1]
    
    if not brainrotData then
        table.remove(notificationQueue, 1)
        return
    end
    
    print("🎯 Processando notificação da fila:")
    print("   🏷️  Nome: " .. tostring(brainrotData.name))
    print("   💰 Taxa: " .. tostring(brainrotData.rate))
    print("   🎯 Job ID: " .. tostring(brainrotData.jobId))
    
    -- Tentar criar a notificação
    local notificationGui = createNotification(brainrotData)
    
    if notificationGui then
        print("✅ Notificação exibida com SUCESSO!")
        table.remove(notificationQueue, 1)
        
        -- Mostrar mensagem temporária
        showTempMessage("💰 " .. brainrotData.name .. " - " .. brainrotData.rate .. "/s", Color3.fromRGB(87, 242, 135))
        
        -- Adicionar ao histórico
        table.insert(activeNotifications, {
            name = brainrotData.name,
            rate = brainrotData.rate,
            jobId = brainrotData.jobId,
            timestamp = os.time()
        })
        
        -- Limitar histórico
        if #activeNotifications > 10 then
            table.remove(activeNotifications, 1)
        end
    else
        print("❌ Falha ao exibir notificação, mantendo na fila")
        -- Não remover da fila se falhou, tentará novamente
    end
    
    print("📊 Fila atualizada: " .. #notificationQueue .. " notificações restantes")
end

-- Sistema de input para teclas
local function setupInputListener()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.T then
            print("🎯 Tecla T pressionada - Saindo do servidor")
            leaveServer()
        end
        
        if input.KeyCode == Enum.KeyCode.K then
            print("🎯 Tecla K pressionada - Parando tentativas")
            stopTryingToJoin()
        end
    end)
end

local function createLeaveButton()
    local player = Players.LocalPlayer
    if not player then return end
    
    if not player:FindFirstChild("PlayerGui") then
        player:WaitForChild("PlayerGui", 5)
    end
    
    if not player.PlayerGui then return end
    
    if mainGui then 
        mainGui:Destroy()
        mainGui = nil
    end
    
    mainGui = Instance.new("ScreenGui")
    mainGui.Name = "BrainrotLeaveGUI"
    mainGui.Parent = player.PlayerGui
    mainGui.ResetOnSpawn = false
    mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Botão principal (estático)
    local leaveButton = Instance.new("TextButton")
    leaveButton.Size = UDim2.new(0, 60, 0, 60)
    leaveButton.Position = UDim2.new(0, 20, 0, 20)
    leaveButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
    leaveButton.Text = "🦵"
    leaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    leaveButton.TextSize = 24
    leaveButton.Font = Enum.Font.GothamBold
    leaveButton.ZIndex = 2
    leaveButton.Parent = mainGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = leaveButton
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(150, 40, 40)
    stroke.Thickness = 2
    stroke.Parent = leaveButton
    
    -- Tooltip
    local tooltip = Instance.new("TextLabel")
    tooltip.Size = UDim2.new(0, 120, 0, 30)
    tooltip.Position = UDim2.new(0, 70, 0, 15)
    tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    tooltip.Text = "SAIR DO SERVIDOR"
    tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltip.TextSize = 12
    tooltip.Font = Enum.Font.GothamBold
    tooltip.Visible = false
    tooltip.Parent = mainGui
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 6)
    tooltipCorner.Parent = tooltip
    
    -- Efeitos hover
    leaveButton.MouseEnter:Connect(function()
        leaveButton.BackgroundColor3 = Color3.fromRGB(209, 59, 61)
        tooltip.Visible = true
        leaveButton.Text = "🚪"
    end)
    
    leaveButton.MouseLeave:Connect(function()
        leaveButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
        tooltip.Visible = false
        leaveButton.Text = "🦵"
    end)
    
    -- Ação do botão
    leaveButton.MouseButton1Click:Connect(function()
        print("🎯 Botão de sair clicado")
        leaveButton.Text = "⏳"
        leaveButton.BackgroundColor3 = Color3.fromRGB(250, 166, 26)
        
        local success = leaveServer()
        
        if success then
            leaveButton.Text = "✅"
            leaveButton.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
        else
            leaveButton.Text = "❌"
            leaveButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
            wait(1.5)
            leaveButton.Text = "🦵"
            leaveButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
        end
    end)
    
    return mainGui
end

local function initializeMainSystem()
    if systemInitialized then 
        print("⚠️ Sistema já inicializado")
        return 
    end
    
    systemInitialized = true
    
    print("🚀 INICIANDO SISTEMA PRINCIPAL...")
    print("📡 Canais selecionados:")
    for channelId in pairs(selectedChannels) do
        print("   - " .. channelId)
    end
    
    -- 1. Criar botão de sair
    createLeaveButton()
    
    -- 2. Configurar listener das teclas
    setupInputListener()
    
    -- 3. Mostrar mensagem de boas-vindas
    showTempMessage("Sistema iniciado! " .. getSelectedChannelsCount() .. " canais ativos", Color3.fromRGB(87, 242, 135))
    
    -- 4. LIMPAR CACHE - só depois que o sistema está pronto
    spawn(function()
        wait(1)
        print("🗑️ Iniciando limpeza do cache...")
        clearMessageCache()
    end)
    
    -- 5. Loop principal de verificação de mensagens
    spawn(function()
        wait(3) -- Esperar 3 segundos antes da primeira busca
        
        print("🔄 INICIANDO LOOP PRINCIPAL DE BUSCA...")
        
        while systemInitialized do
            pcall(function()
                print("\n--- EXECUTANDO BUSCA AUTOMÁTICA ---")
                fetchNewMessages()
            end)
            wait(CHECK_INTERVAL)
        end
    end)
    
    -- 6. Processar notificações em tempo real
    spawn(function()
        print("🔄 INICIANDO PROCESSAMENTO DE NOTIFICAÇÕES...")
        
        while systemInitialized do
            pcall(processNotificationQueue)
            wait(0.5) -- Verificar mais frequentemente
        end
    end)
    
    -- 7. Forçar primeira busca após inicialização completa
    spawn(function()
        wait(5) -- Esperar 5 segundos para tudo estar pronto
        print("🎯 EXECUTANDO PRIMEIRA BUSCA APÓS INICIALIZAÇÃO...")
        forceRefreshMessages()
    end)
    
    print("✅ SISTEMA PRINCIPAL INICIALIZADO COM SUCESSO!")
end

-- Função HTTP compatível com Xeno Executor
local function makeAPIRequest(endpoint)
    if not endpoint then return nil end
    
    local fullUrl = API_BASE_URL .. endpoint
    print("📡 Fazendo requisição para: " .. fullUrl)
    
    -- Método 1: Usando syn.request (Xeno Executor)
    if syn and syn.request then
        local success, result = pcall(function()
            local response = syn.request({
                Url = fullUrl,
                Method = "GET",
                Headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            
            if response and response.Success and response.Body then
                return HttpService:JSONDecode(response.Body)
            end
        end)
        
        if success then return result end
    end
    
    -- Método 2: Usando request
    if request then
        local success, result = pcall(function()
            local response = request({
                Url = fullUrl,
                Method = "GET"
            })
            
            if response and response.Body then
                return HttpService:JSONDecode(response.Body)
            end
        end)
        
        if success then return result end
    end
    
    -- Método 3: Usando game:HttpGet
    local success, result = pcall(function()
        local response = game:HttpGet(fullUrl)
        if response then
            return HttpService:JSONDecode(response)
        end
    end)
    
    if success then return result end
    
    return nil
end

-- Função para criar menu de seleção de canais
local function createChannelSelectionMenu()
    local player = Players.LocalPlayer
    if not player then return end
    
    -- Esperar pelo PlayerGui
    if not player:FindFirstChild("PlayerGui") then
        player:WaitForChild("PlayerGui", 5)
    end
    
    if not player.PlayerGui then return end
    
    -- Remover GUI antiga se existir
    if channelSelectionGui then 
        channelSelectionGui:Destroy()
        channelSelectionGui = nil
    end
    
    -- GUI de seleção
    channelSelectionGui = Instance.new("ScreenGui")
    channelSelectionGui.Name = "ChannelSelectionGUI"
    channelSelectionGui.Parent = player.PlayerGui
    channelSelectionGui.ResetOnSpawn = false
    channelSelectionGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Fundo escuro semi-transparente
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.Position = UDim2.new(0, 0, 0, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.3
    background.BorderSizePixel = 0
    background.Parent = channelSelectionGui
    
    -- Frame principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = channelSelectionGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(88, 101, 242)
    stroke.Thickness = 3
    stroke.Parent = mainFrame
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 60)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🔔 SELECIONE OS CANAIS"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -20, 0, 40)
    subtitle.Position = UDim2.new(0, 10, 0, 60)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Escolha até 4 canais para receber notificações:"
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = mainFrame
    
    -- Container para os checkboxes
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 0, 300)
    scrollFrame.Position = UDim2.new(0, 10, 0, 110)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(64, 68, 75)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scrollFrame
    
    -- Contador de seleção
    local counterLabel = Instance.new("TextLabel")
    counterLabel.Size = UDim2.new(1, -20, 0, 30)
    counterLabel.Position = UDim2.new(0, 10, 0, 420)
    counterLabel.BackgroundTransparency = 1
    counterLabel.Text = "Selecionados: 0/4"
    counterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    counterLabel.TextSize = 16
    counterLabel.Font = Enum.Font.GothamBold
    counterLabel.Parent = mainFrame
    
    -- Botão confirmar
    local confirmButton = Instance.new("TextButton")
    confirmButton.Size = UDim2.new(1, -20, 0, 50)
    confirmButton.Position = UDim2.new(0, 10, 0, 460)
    confirmButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
    confirmButton.Text = "✅ CONFIRMAR SELEÇÃO"
    confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmButton.TextSize = 16
    confirmButton.Font = Enum.Font.GothamBold
    confirmButton.Parent = mainFrame
    
    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 8)
    confirmCorner.Parent = confirmButton
    
    -- Função para atualizar contador
    local function updateCounter()
        local count = getSelectedChannelsCount()
        counterLabel.Text = "Selecionados: " .. count .. "/4"
        
        if count > 0 then
            confirmButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
            confirmButton.Text = "✅ CONFIRMAR (" .. count .. " CANAIS)"
        else
            confirmButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            confirmButton.Text = "SELECIONE PELO MENOS 1 CANAL"
        end
    end
    
    -- Carregar canais disponíveis
    local channelsInfo = makeAPIRequest("/api/channels")
    if channelsInfo and channelsInfo.success then
        availableChannels = {}
        
        -- Criar checkboxes para cada canal
        local yPosition = 10
        for _, channel in ipairs(channelsInfo.channels) do
            local channelFrame = Instance.new("Frame")
            channelFrame.Size = UDim2.new(1, -20, 0, 50)
            channelFrame.Position = UDim2.new(0, 10, 0, yPosition)
            channelFrame.BackgroundColor3 = Color3.fromRGB(54, 57, 63)
            channelFrame.BorderSizePixel = 0
            channelFrame.Parent = scrollFrame
            
            local channelCorner = Instance.new("UICorner")
            channelCorner.CornerRadius = UDim.new(0, 6)
            channelCorner.Parent = channelFrame
            
            -- Checkbox
            local checkbox = Instance.new("TextButton")
            checkbox.Size = UDim2.new(0, 30, 0, 30)
            checkbox.Position = UDim2.new(0, 10, 0, 10)
            checkbox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            checkbox.Text = "◻️"
            checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkbox.TextSize = 16
            checkbox.Font = Enum.Font.GothamBold
            checkbox.Parent = channelFrame
            
            local checkboxCorner = Instance.new("UICorner")
            checkboxCorner.CornerRadius = UDim.new(0, 6)
            checkboxCorner.Parent = checkbox
            
            -- Info do canal
            local channelInfo = Instance.new("TextLabel")
            channelInfo.Size = UDim2.new(1, -50, 1, -10)
            channelInfo.Position = UDim2.new(0, 50, 0, 5)
            channelInfo.BackgroundTransparency = 1
            channelInfo.Text = "Canal " .. string.sub(channel.channel_id, 1, 8) .. "...\nStatus: " .. channel.status .. " • Mensagens: " .. channel.messages_available
            channelInfo.TextColor3 = Color3.fromRGB(220, 220, 220)
            channelInfo.TextSize = 12
            channelInfo.TextXAlignment = Enum.TextXAlignment.Left
            channelInfo.Font = Enum.Font.Gotham
            channelInfo.Parent = channelFrame
            
            -- Armazenar informações do canal
            availableChannels[channel.channel_id] = {
                frame = channelFrame,
                checkbox = checkbox,
                info = channelInfo,
                status = channel.status
            }
            
            -- Evento de clique no checkbox
            checkbox.MouseButton1Click:Connect(function()
                if selectedChannels[channel.channel_id] then
                    -- Desmarcar
                    selectedChannels[channel.channel_id] = nil
                    checkbox.Text = "◻️"
                    checkbox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                    channelFrame.BackgroundColor3 = Color3.fromRGB(54, 57, 63)
                else
                    -- Verificar limite
                    local count = getSelectedChannelsCount()
                    
                    if count < 4 then
                        -- Marcar
                        selectedChannels[channel.channel_id] = true
                        checkbox.Text = "✅"
                        checkbox.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
                        channelFrame.BackgroundColor3 = Color3.fromRGB(64, 68, 75)
                    else
                        -- Limite atingido
                        checkbox.Text = "❌"
                        checkbox.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
                        wait(0.5)
                        checkbox.Text = "◻️"
                        checkbox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                    end
                end
                updateCounter()
            end)
            
            yPosition = yPosition + 60
        end
        
        -- Atualizar tamanho do canvas
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition + 10)
    else
        -- Fallback se não conseguir carregar canais
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Size = UDim2.new(1, -20, 1, -20)
        errorLabel.Position = UDim2.new(0, 10, 0, 10)
        errorLabel.BackgroundTransparency = 1
        errorLabel.Text = "❌ Não foi possível carregar os canais\nVerifique se a API está online"
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 14
        errorLabel.TextWrapped = true
        errorLabel.Parent = scrollFrame
    end
    
    -- Evento do botão confirmar
    confirmButton.MouseButton1Click:Connect(function()
        local count = getSelectedChannelsCount()
        
        if count > 0 then
            print("✅ Canais selecionados: " .. count)
            for channelId in pairs(selectedChannels) do
                print("   - " .. channelId)
            end
            
            -- Fechar menu de seleção
            channelSelectionGui:Destroy()
            channelSelectionGui = nil
            
            -- Iniciar sistema principal
            initializeMainSystem()
        else
            -- Efeito de erro
            confirmButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
            confirmButton.Text = "❌ SELECIONE PELO MENOS 1 CANAL"
            wait(1)
            updateCounter()
        end
    end)
    
    -- Botão selecionar todos
    local selectAllButton = Instance.new("TextButton")
    selectAllButton.Size = UDim2.new(0.45, 0, 0, 30)
    selectAllButton.Position = UDim2.new(0.025, 0, 0, 420)
    selectAllButton.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
    selectAllButton.Text = "📥 SELECIONAR TODOS"
    selectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllButton.TextSize = 12
    selectAllButton.Font = Enum.Font.GothamBold
    selectAllButton.Parent = mainFrame
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 6)
    selectAllCorner.Parent = selectAllButton
    
    selectAllButton.MouseButton1Click:Connect(function()
        local count = 0
        for channelId, channelData in pairs(availableChannels) do
            if count < 4 then
                selectedChannels[channelId] = true
                channelData.checkbox.Text = "✅"
                channelData.checkbox.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
                channelData.frame.BackgroundColor3 = Color3.fromRGB(64, 68, 75)
                count = count + 1
            end
        end
        updateCounter()
    end)
    
    -- Botão limpar seleção
    local clearButton = Instance.new("TextButton")
    clearButton.Size = UDim2.new(0.45, 0, 0, 30)
    clearButton.Position = UDim2.new(0.525, 0, 0, 420)
    clearButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
    clearButton.Text = "🗑️ LIMPAR TUDO"
    clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearButton.TextSize = 12
    clearButton.Font = Enum.Font.GothamBold
    clearButton.Parent = mainFrame
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 6)
    clearCorner.Parent = clearButton
    
    clearButton.MouseButton1Click:Connect(function()
        selectedChannels = {}
        for channelId, channelData in pairs(availableChannels) do
            channelData.checkbox.Text = "◻️"
            channelData.checkbox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            channelData.frame.BackgroundColor3 = Color3.fromRGB(54, 57, 63)
        end
        updateCounter()
    end)
    
    -- Inicializar contador
    updateCounter()
    
    return channelSelectionGui
end

-- Função para parar as tentativas
local function stopTryingToJoin()
    if isTryingToJoin then
        isTryingToJoin = false
        print("🛑 Tentativas paradas pelo usuário na tentativa " .. attemptCount .. "/" .. maxAttempts)
        showTempMessage("Tentativas paradas (" .. attemptCount .. "/" .. maxAttempts .. ")", Color3.fromRGB(255, 150, 50))
        currentJobId = nil
    else
        print("ℹ️ Nenhuma tentativa em andamento")
    end
end


local function fetchNewMessages()
    if isChecking then 
        print("⚠️ Busca já em andamento, ignorando...")
        return 
    end
    
    -- Verificar se há canais selecionados
    if getSelectedChannelsCount() == 0 then
        print("❌ Nenhum canal selecionado, ignorando busca")
        return
    end
    
    isChecking = true
    
    print("🔄 BUSCA INICIADA (modo agressivo)...")
    print("📡 Canais selecionados: " .. getSelectedChannelsCount())
    
    -- SEMPRE buscar sem last_message_ids para forçar busca completa
    local endpoint = "/api/messages/new"
    print("🎯 Buscando TODAS as mensagens (ignorando cache)")
    
    -- Fazer requisição
    local response = makeAPIRequest(endpoint)
    
    if response then
        if response.success then
            print("📨 " .. response.message)
            print("📊 Total de mensagens na resposta: " .. #response.new_messages)
            
            local newMessagesCount = 0
            
            for i, notification in ipairs(response.new_messages) do
                print("   🔍 Analisando notificação " .. i .. "...")
                print("      Canal: " .. notification.channel_id)
                print("      Nome: " .. notification.brainrot_name)
                print("      Taxa: " .. notification.generation_rate)
                print("      Job ID: " .. notification.job_id)
                
                -- Verificar se o canal está selecionado
                if selectedChannels[notification.channel_id] then
                    print("      ✅ Canal selecionado - PROCESSANDO")
                    
                    -- SEMPRE adicionar à fila (ignorar se já foi processada)
                    table.insert(notificationQueue, {
                        name = notification.brainrot_name,
                        rate = notification.generation_rate,
                        jobId = notification.job_id,
                        messageId = notification.message_id,
                        channelId = notification.channel_id
                    })
                    
                    -- Atualizar último ID
                    lastMessageIds[notification.channel_id] = notification.message_id
                    newMessagesCount = newMessagesCount + 1
                    print("      📥 ADICIONADA NA FILA")
                else
                    print("      ❌ Canal não selecionado - IGNORANDO")
                end
            end
            
            if newMessagesCount > 0 then
                print("🎯 " .. newMessagesCount .. " notificações adicionadas na fila!")
                print("📊 Tamanho total da fila: " .. #notificationQueue)
                
                -- Forçar processamento imediato
                print("🚀 Forçando processamento da fila...")
                processNotificationQueue()
            else
                print("ℹ️ Nenhuma notificação encontrada para os canais selecionados")
            end
        else
            print("❌ API retornou erro: " .. tostring(response.message))
        end
    else
        print("❌ Falha na comunicação com a API")
    end
    
    isChecking = false
    print("✅ BUSCA FINALIZADA")
    print("📊 Fila atual: " .. #notificationQueue .. " notificações")
end

-- Função para limpar o cache de mensagens processadas
local function clearMessageCache()
    print("🗑️ LIMPANDO CACHE DE MENSAGENS...")
    lastMessageIds = {}
    notificationQueue = {}
    
    -- Limpar cache para cada canal selecionado
    for channelId in pairs(selectedChannels) do
        lastMessageIds[channelId] = nil
    end
    
    print("✅ Cache limpo! Últimos IDs resetados:")
    for channelId in pairs(lastMessageIds) do
        print("   - " .. channelId .. ": " .. tostring(lastMessageIds[channelId]))
    end
end

-- Função para forçar uma busca IGNORANDO o cache
local function forceRefreshMessages()
    print("🔄 FORÇANDO BUSCA COMPLETA (ignorando cache)...")
    
    -- Limpar cache primeiro
    clearMessageCache()
    
    -- Fazer busca forçada
    fetchNewMessages()
end

-- Tornar funções globais
getgenv().clearMessageCache = clearMessageCache
getgenv().forceRefreshMessages = forceRefreshMessages

-- Inicialização do script
local function initialize()
    print("🎮 Script Brainrot carregado!")
    print("⏳ Aguardando seleção de canais...")
    wait(2)
    createChannelSelectionMenu()
end

local function testNotification()
    table.insert(notificationQueue, {
        name = "TESTE Los Tipi Tacos",
        rate = "2M",
        jobId = "5ab7c5e4-35a1-4552-8264-4cbdd6aab1f6",
        channelId = "1418386444610830477"
    })
    print("✅ Notificação de teste adicionada!")
end

spawn(initialize)

getgenv().testNotification = testNotification
print("Iniciado!")
