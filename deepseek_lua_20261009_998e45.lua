--// TOXIC 👑 x FAMILY HS — FUSION V2 (FIX ICONOS + ANTI-DUPLICADOS)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ============================================================
-- ANTI-DUPLICADOS (restaurado de Family HS)
-- ============================================================
local function clearAlign(root)
    if not root then return end
    for _, n in ipairs({"ToxicAtt","ToxicPos","ToxicOri","FarmAttachment","FarmPosition","FarmOrientation"}) do
        local c = root:FindFirstChild(n)
        if c then c:Destroy() end
    end
    pcall(function()
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
    end)
end

local function FullDestruction()
    _G.Toggles = _G.Toggles or {}
    for k in pairs(_G.Toggles) do _G.Toggles[k] = false end

    if _G.Fusion_FarmLoop then _G.Fusion_FarmLoop:Disconnect(); _G.Fusion_FarmLoop = nil end
    if _G.Fusion_SpawnConn then _G.Fusion_SpawnConn:Disconnect(); _G.Fusion_SpawnConn = nil end
    if _G.Fusion_WalkingFling then _G.Fusion_WalkingFling:Disconnect(); _G.Fusion_WalkingFling = nil end
    if _G.Fusion_AntiFling then _G.Fusion_AntiFling:Disconnect(); _G.Fusion_AntiFling = nil end

    if _G.Fusion_MobileGui then
        pcall(function() _G.Fusion_MobileGui:Destroy() end)
        _G.Fusion_MobileGui = nil
    end

    if LP and LP.Character then
        clearAlign(LP.Character:FindFirstChild("HumanoidRootPart"))
    end
end

FullDestruction() -- limpia ejecución anterior antes de crear la nueva UI

-- ============================================================
-- WINDUI (misma URL que usa TOXIC — release)
-- ============================================================
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "TOXIC HS FUSION",
    Icon = "crown",
    Author = "TOXIC 👑 x Family HS",
    Folder = "ToxicHub",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Amber",
    Resizable = true,
    SideBarWidth = 180,
    ScrollBarEnabled = true,
})

-- ============================================================
-- VARIABLES GLOBALES
-- ============================================================
local TargetNames = {}
local PTg = {}
local BangSpeed = 1
local AntiFlingConnection = nil
local WalkingFlingConnection = nil
local OffsetX, OffsetY, OffsetZ = 0, 0, 1.1
local BangShakeEnabled = false

local autofarmEnabled = false
local orbitDistance = 4.0
local orbitHeight = 2.6
local orbitSpeed = 2.0
local targetSwitchInterval = 5.0
local lastSwitchTime = 0
local validTargetsList = {}
local currentTargetIndex = 1
local targetPlayer = nil

local SavedCheckpoint = nil
local autoResetEnabled = false
local autoResetInterval = 30
local lastResetTime = tick()

local mobileButton = nil
local mobileButtonEnabled = false
local mobileButtonDragEnabled = false
local bangModeEnabled = false

local refrescandoLista = false
local mapaNombres = {}

local Toggles = {
    Bang=false, MouthBang=false, Headsit=false, FrontHeadsit=false,
    Orbit=false, WalkingFling=false, Noclip=false, FlyWalk=false,
    AntiVoid=false, AntiBangV1=false, AntiBangV2=false,
    AntiFling=false, AntiSit=false, AntiAFK=false
}
_G.Toggles = Toggles

-- ============================================================
-- HELPERS
-- ============================================================
local function Notificar(t, m, d)
    pcall(function()
        WindUI:Notify({Title=t, Content=m, Duration=d or 3})
    end)
end

local function ObtenerJugadores()
    local lista = {}
    mapaNombres = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            local fmt = p.Name .. "| " .. p.DisplayName
            table.insert(lista, fmt)
            mapaNombres[fmt] = p.Name
        end
    end
    return lista
end

local function ExtraerNombresReales(val)
    local nombres = {}
    if type(val) == "table" then
        for _, v in ipairs(val) do table.insert(nombres, mapaNombres[v] or v) end
    elseif type(val) == "string" then
        table.insert(nombres, mapaNombres[val] or val)
    end
    return nombres
end

local function matchFilter(p)
    if #PTg == 0 then return true end
    local n, d = p.Name:lower(), p.DisplayName:lower()
    for _, t in ipairs(PTg) do
        if n:find(t,1,true) or d:find(t,1,true) then return true end
    end
    return false
end

local function ObtenerObjetivosValidos()
    local validos = {}
    local function push(p)
        if p and p ~= LP and matchFilter(p)
           and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validos, p)
        end
    end
    if #TargetNames > 0 then
        for _, name in ipairs(TargetNames) do push(Players:FindFirstChild(name)) end
    else
        for _, p in ipairs(Players:GetPlayers()) do push(p) end
    end
    return validos
end

-- ============================================================
-- ALIGN PHYSICS (Family HS)
-- ============================================================
local function getOrCreateAlign(root)
    local att = root:FindFirstChild("ToxicAtt")
    if not att then att = Instance.new("Attachment"); att.Name = "ToxicAtt"; att.Parent = root end
    local ap = root:FindFirstChild("ToxicPos")
    if not ap then
        ap = Instance.new("AlignPosition")
        ap.Name = "ToxicPos"
        ap.Mode = Enum.PositionAlignmentMode.OneAttachment
        ap.Attachment0 = att
        ap.MaxForce = 1e6
        ap.Responsiveness = 150
        ap.Parent = root
    end
    local ao = root:FindFirstChild("ToxicOri")
    if not ao then
        ao = Instance.new("AlignOrientation")
        ao.Name = "ToxicOri"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.MaxTorque = 1e6
        ao.Responsiveness = 150
        ao.Parent = root
    end
    return att, ap, ao
end

local function clearAllAligns()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    clearAlign(hrp)
end

local function isAnyPositionModeActive()
    return Toggles.Bang or Toggles.MouthBang or Toggles.Headsit
        or Toggles.FrontHeadsit or Toggles.Orbit or autofarmEnabled
end

local function applyAlign(targetCF, offsetVec, lookAtPos)
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local _, ap, ao = getOrCreateAlign(myHrp)
    ap.Position = (targetCF * CFrame.new(offsetVec.X, offsetVec.Y, offsetVec.Z)).Position
    if lookAtPos then ao.CFrame = CFrame.lookAt(myHrp.Position, lookAtPos) end
end

-- ============================================================
-- TABS (iconos simples para que la sidebar renderice)
-- ============================================================
local function safeTab(cfg)
    local ok, tab = pcall(function() return Window:Tab(cfg) end)
    if ok then return tab end
    return nil
end

local TrollTab   = safeTab({Title="TROLL",   Icon="skull"})
local FarmTab    = safeTab({Title="AUTOFARM",Icon="target"})
local CheckTab   = safeTab({Title="CHECKPOINT",Icon="map-pin"})
local MobileTab  = safeTab({Title="MOBILE",  Icon="smartphone"})
local DefenceTab = safeTab({Title="DEFENCE", Icon="shield"})

if not TrollTab then
    Notificar("ERROR", "WindUI no pudo crear pestañas. Revisa la versión.", 6)
    return
end

-- ============================================================
-- TROLL: DROPDOWN + FILTRO
-- ============================================================
local DropdownTargets = TrollTab:Dropdown({
    Title = "Fijar Objetivos (Multi)",
    Desc = "Selecciona jugadores del dropdown. El filtro es opcional.",
    Values = ObtenerJugadores(),
    Value = nil,
    AllowNone = true,
    Multi = true,
    Callback = function(val)
        if refrescandoLista then return end
        if val == nil then TargetNames = {}
        else TargetNames = ExtraerNombresReales(val) end
        if #TargetNames == 0 then
            Notificar("✅ Objetivos Limpios", "Sin objetivos.", 3)
        else
            local n = table.concat(TargetNames, ", ")
            if #n > 50 then n = string.sub(n,1,50).."..." end
            Notificar("🎯 Objetivos ("..#TargetNames..")", n, 3)
        end
    end
})

TrollTab:Input({
    Title = "Filtro por nombre (opcional)",
    Desc = "Separa por espacios. Vacío = sin filtro.",
    Placeholder = "Ej: nat pro123",
    Callback = function(text)
        PTg = {}
        if text and text:gsub("%s+","") ~= "" then
            for x in string.gmatch(text:lower(), "%S+") do table.insert(PTg, x) end
        end
        lastSwitchTime = 0
    end
})

local function SincronizarDropdown()
    if not DropdownTargets then return end
    local sel = {}
    for fmt, real in pairs(mapaNombres) do
        for _, t in ipairs(TargetNames) do
            if t == real then table.insert(sel, fmt); break end
        end
    end
    pcall(function()
        if #sel == 0 then DropdownTargets:SetValue(nil)
        else DropdownTargets:SetValue(sel) end
    end)
end

TrollTab:Button({
    Title = "🧹 Limpiar Selección",
    Color = Color3.fromRGB(180,40,40),
    Callback = function()
        refrescandoLista = true
        TargetNames = {}
        pcall(function() DropdownTargets:SetValue(nil) end)
        task.wait(0.1); refrescandoLista = false
        Notificar("🧹 Reset", "Objetivos desmarcados.", 3)
    end
})

TrollTab:Button({
    Title = "🔄 Actualizar Lista",
    Callback = function()
        refrescandoLista = true
        local nv = ObtenerJugadores()
        if DropdownTargets.SetOptions then DropdownTargets:SetOptions(nv)
        elseif DropdownTargets.Refresh then DropdownTargets:Refresh(nv) end
        task.wait(0.1); SincronizarDropdown(); refrescandoLista = false
        Notificar("🔄 Actualizado", "Jugadores: "..#nv, 3)
    end
})

-- ============================================================
-- OFFSETS X/Y/Z
-- ============================================================
local OffsetGroup = TrollTab:Group({})
OffsetGroup:Input({Title="X", Placeholder="0", Value="0", Width=60,
    Callback=function(v) OffsetX = tonumber(v) or 0 end})
OffsetGroup:Space()
OffsetGroup:Input({Title="Y", Placeholder="0", Value="0", Width=60,
    Callback=function(v) OffsetY = tonumber(v) or 0 end})
OffsetGroup:Space()
OffsetGroup:Input({Title="Z", Placeholder="1.1", Value="1.1", Width=60,
    Callback=function(v) OffsetZ = tonumber(v) or 1.1 end})

-- ============================================================
-- CONTROLES GENERALES
-- ============================================================
TrollTab:Input({Title="SPEED", Desc="Default: 1", Placeholder="1",
    Callback=function(v) BangSpeed = tonumber(v) or 1 end})

TrollTab:Toggle({Title="Bang Shake (Animación)", Value=false,
    Callback=function(v) BangShakeEnabled = v end})

TrollTab:Button({Title="GOTO TARGET", Desc="Ir al primer objetivo",
    Callback=function()
        local tg = ObtenerObjetivosValidos()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if #tg > 0 and hrp and tg[1].Character then
            clearAlign(hrp)
            hrp.CFrame = tg[1].Character.HumanoidRootPart.CFrame
        end
    end})

TrollTab:Toggle({Title="VIEW TARGET", Value=false,
    Callback=function(v)
        local tg = ObtenerObjetivosValidos()
        if v and #tg > 0 and tg[1].Character then
            workspace.CurrentCamera.CameraSubject = tg[1].Character:FindFirstChildOfClass("Humanoid")
        else
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then workspace.CurrentCamera.CameraSubject = h end
        end
    end})

TrollTab:Button({Title="OP MULTI FLING GUI 💀",
    Callback=function()
        loadstring(game:HttpGet("https://pastefy.app/dEA5eS1L/raw"))()
    end})

-- ============================================================
-- MODOS (todos usan AlignPosition)
-- ============================================================
TrollTab:Toggle({Title="BANG", Desc="Multi-Target (Física Align)", Value=false,
    Callback=function(value)
        Toggles.Bang = value
        task.spawn(function()
            while Toggles.Bang and task.wait() do
                pcall(function()
                    local tg = ObtenerObjetivosValidos()
                    if #tg == 0 then return end
                    for _, t in ipairs(tg) do
                        if not Toggles.Bang then break end
                        local tHrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
                        if tHrp then
                            local shake = 0
                            if BangShakeEnabled then
                                shake = math.sin(tick()*(BangSpeed*5))*0.8
                            end
                            applyAlign(tHrp.CFrame, Vector3.new(OffsetX, OffsetY, OffsetZ+shake), tHrp.Position)
                        end
                        task.wait(0.03)
                    end
                end)
            end
            if not isAnyPositionModeActive() then clearAllAligns() end
        end)
    end})

TrollTab:Toggle({Title="MOUTH BANG", Desc="Multi-Target", Value=false,
    Callback=function(value)
        Toggles.MouthBang = value
        task.spawn(function()
            while Toggles.MouthBang and task.wait() do
                pcall(function()
                    local tg = ObtenerObjetivosValidos()
                    if #tg == 0 then return end
                    for _, t in ipairs(tg) do
                        if not Toggles.MouthBang then break end
                        local h = t.Character and t.Character:FindFirstChild("Head")
                        if h then
                            local sh = math.sin(tick()*(BangSpeed*5))*0.8
                            applyAlign(h.CFrame, Vector3.new(OffsetX, OffsetY+0.2, OffsetZ-1.2-sh), h.Position)
                        end
                        task.wait(0.03)
                    end
                end)
            end
            if not isAnyPositionModeActive() then clearAllAligns() end
        end)
    end})

TrollTab:Toggle({Title="HEADSIT", Desc="Multi-Target", Value=false,
    Callback=function(value)
        Toggles.Headsit = value
        task.spawn(function()
            while Toggles.Headsit and task.wait() do
                pcall(function()
                    local tg = ObtenerObjetivosValidos()
                    if #tg == 0 then return end
                    for _, t in ipairs(tg) do
                        if not Toggles.Headsit then break end
                        local h = t.Character and t.Character:FindFirstChild("Head")
                        if h then
                            local sh = math.sin(tick()*(BangSpeed*5))*0.5
                            applyAlign(h.CFrame, Vector3.new(OffsetX, OffsetY+0.5+sh, OffsetZ), h.Position)
                        end
                        task.wait(0.03)
                    end
                end)
            end
            if not isAnyPositionModeActive() then clearAllAligns() end
        end)
    end})

TrollTab:Toggle({Title="FRONTHEADSIT", Desc="Multi-Target", Value=false,
    Callback=function(value)
        Toggles.FrontHeadsit = value
        task.spawn(function()
            while Toggles.FrontHeadsit and task.wait() do
                pcall(function()
                    local tg = ObtenerObjetivosValidos()
                    if #tg == 0 then return end
                    for _, t in ipairs(tg) do
                        if not Toggles.FrontHeadsit then break end
                        local h = t.Character and t.Character:FindFirstChild("Head")
                        if h then
                            local sh = math.sin(tick()*(BangSpeed*5))*0.5
                            applyAlign(h.CFrame, Vector3.new(OffsetX, OffsetY+0.4, OffsetZ-0.2-sh), h.Position)
                        end
                        task.wait(0.03)
                    end
                end)
            end
            if not isAnyPositionModeActive() then clearAllAligns() end
        end)
    end})

TrollTab:Toggle({Title="ORBIT", Desc="Multi-Target", Value=false,
    Callback=function(value)
        Toggles.Orbit = value
        task.spawn(function()
            local angle = 0
            while Toggles.Orbit and task.wait() do
                pcall(function()
                    local tg = ObtenerObjetivosValidos()
                    if #tg == 0 then return end
                    angle = angle + (0.05*BangSpeed)
                    local sum = Vector3.zero
                    for _, t in ipairs(tg) do sum = sum + t.Character.HumanoidRootPart.Position end
                    local center = sum / #tg
                    local cf = CFrame.new(center) * CFrame.Angles(0, angle, 0)
                    applyAlign(cf, Vector3.new(OffsetX, OffsetY, 5+OffsetZ), center)
                end)
            end
            if not isAnyPositionModeActive() then clearAllAligns() end
        end)
    end})

TrollTab:Toggle({Title="WALKING FLING", Value=false,
    Callback=function(value)
        Toggles.WalkingFling = value
        if value then
            WalkingFlingConnection = RunService.Heartbeat:Connect(function()
                pcall(function()
                    if not Toggles.WalkingFling then return end
                    for _, pl in pairs(Players:GetPlayers()) do
                        if pl ~= LP and pl.Character then
                            for _, p in pairs(pl.Character:GetDescendants()) do
                                if p:IsA("BasePart") then p.CanCollide = false end
                            end
                        end
                    end
                    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = LP.Character.HumanoidRootPart
                        local s = 100000
                        local old = hrp.Velocity
                        hrp.Velocity = Vector3.new(s,s,s)
                        for _, v in pairs(LP.Character:GetDescendants()) do
                            if v:IsA("BasePart") then v.CanCollide = false end
                        end
                        RunService.RenderStepped:Wait()
                        hrp.Velocity = old
                    end
                end)
            end)
            _G.Fusion_WalkingFling = WalkingFlingConnection
        else
            if WalkingFlingConnection then
                WalkingFlingConnection:Disconnect(); WalkingFlingConnection = nil
                _G.Fusion_WalkingFling = nil
            end
        end
    end})

-- ============================================================
-- AUTOFARM (Family HS)
-- ============================================================
local function updateValidTargets() validTargetsList = ObtenerObjetivosValidos() end

local function handleAutofarm()
    if not autofarmEnabled then return end
    local myChar = LP.Character
    if not myChar then return end
    local hum = myChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    if tick() - lastSwitchTime >= targetSwitchInterval then
        updateValidTargets()
        if #validTargetsList > 0 then
            currentTargetIndex = currentTargetIndex + 1
            if currentTargetIndex > #validTargetsList then currentTargetIndex = 1 end
            targetPlayer = validTargetsList[currentTargetIndex]
            lastSwitchTime = tick()
        else targetPlayer = nil end
    end

    if not targetPlayer or not targetPlayer.Character
       or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        lastSwitchTime = 0; return
    end

    local tHrp = targetPlayer.Character.HumanoidRootPart
    if bangModeEnabled then
        applyAlign(tHrp.CFrame, Vector3.new(OffsetX, orbitHeight, -orbitDistance), tHrp.Position)
        return
    end
    local angle = tick() * orbitSpeed
    local offset = Vector3.new(
        math.sin(angle)*orbitDistance,
        orbitHeight,
        math.cos(angle)*orbitDistance
    )
    applyAlign(tHrp.CFrame, offset, tHrp.Position)
end

local function handleSafety()
    if not autofarmEnabled then return end
    local char = LP.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then hum.PlatformStand = false; hum.Sit = false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root.Position.Y < -25 then
        root.Velocity = Vector3.new(root.Velocity.X*0.5, 70, root.Velocity.Z*0.5)
    end
end

local function forceReset()
    if LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.Health = 0; h:ChangeState(Enum.HumanoidStateType.Dead) end
        LP.Character:BreakJoints()
    end
end

local function handleAutoReset()
    if not autoResetEnabled or autoResetInterval <= 0 then return end
    local char = LP.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 and tick() - lastResetTime >= autoResetInterval then
            forceReset(); lastResetTime = tick()
        end
    end
end

_G.Fusion_FarmLoop = RunService.Heartbeat:Connect(function()
    handleAutofarm(); handleSafety(); handleAutoReset()
end)

_G.Fusion_SpawnConn = LP.CharacterAdded:Connect(function(char)
    lastResetTime = tick()
    if autofarmEnabled then
        task.wait(1.5)
        Notificar("Respawneado", "Retomando Autofarm...", 3)
    end
    if SavedCheckpoint then
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then task.wait(0.2); root.CFrame = CFrame.new(SavedCheckpoint) end
    end
end)

if FarmTab then
    FarmTab:Input({Title="Distancia de la Órbita", Placeholder="4",
        Callback=function(t) local n=tonumber(t); if n then orbitDistance=n end end})
    FarmTab:Input({Title="Altura de la Órbita", Placeholder="2.6",
        Callback=function(t) local n=tonumber(t); if n then orbitHeight=n end end})
    FarmTab:Input({Title="Velocidad de la Órbita", Placeholder="2",
        Callback=function(t) local n=tonumber(t); if n then orbitSpeed=n end end})
    FarmTab:Input({Title="Tiempo entre targets", Placeholder="5",
        Callback=function(t) local n=tonumber(t); if n and n>0 then targetSwitchInterval=n end end})
    FarmTab:Toggle({Title="Modo Bang Fijo", Desc="No orbita, se queda fijo al frente", Value=false,
        Callback=function(s) bangModeEnabled = s end})
    FarmTab:Toggle({Title="Activar Autofarm", Value=false,
        Callback=function(s)
            autofarmEnabled = s
            if s then
                lastSwitchTime = 0
                Notificar("Autofarm ON", "Iniciando rotación.", 3)
            else
                targetPlayer = nil
                if not isAnyPositionModeActive() then clearAllAligns() end
                Notificar("Autofarm OFF", "Detenido.", 2)
            end
        end})
end

-- ============================================================
-- CHECKPOINT
-- ============================================================
if CheckTab then
    CheckTab:Toggle({Title="Activar Auto Reset", Value=false,
        Callback=function(s) autoResetEnabled = s; if s then lastResetTime = tick() end end})
    CheckTab:Input({Title="Tiempo Auto Reset (s)", Placeholder="30",
        Callback=function(t) local n=tonumber(t); if n and n>0 then autoResetInterval=n end end})
    CheckTab:Button({Title="💀 Forzar Reset Ahora", Callback=function() forceReset() end})
    CheckTab:Button({Title="📍 Save Checkpoint",
        Callback=function()
            local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if r then SavedCheckpoint = r.Position; Notificar("Checkpoint", "Guardado.", 3) end
        end})
    CheckTab:Button({Title="🗑️ Clear Checkpoint",
        Callback=function() SavedCheckpoint = nil; Notificar("Checkpoint", "Eliminado.", 3) end})
    CheckTab:Button({Title="🔵 Modo Auto Farm AFK 🔵",
        Callback=function()
            Notificar("AFK", "Iniciando Auto Farm ATI...", 3)
            loadstring(game:HttpGet("https://pastebin.com/raw/wyMSZ29R"))()
        end})
end

-- ============================================================
-- MOBILE BUTTON
-- ============================================================
local function createMobileButton()
    if _G.Fusion_MobileGui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "FusionMobileButton"
    gui.Parent = LP:WaitForChild("PlayerGui")
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    _G.Fusion_MobileGui = gui

    mobileButton = Instance.new("TextButton")
    mobileButton.Size = UDim2.new(0,60,0,45)
    mobileButton.Position = UDim2.fromScale(0.66, 0.65)
    mobileButton.BackgroundColor3 = bangModeEnabled and Color3.fromRGB(37,122,247) or Color3.fromRGB(100,100,100)
    mobileButton.BackgroundTransparency = 0.4
    mobileButton.Text = bangModeEnabled and "BANG\nON" or "BANG\nOFF"
    mobileButton.TextColor3 = Color3.new(1,1,1)
    mobileButton.Font = Enum.Font.GothamBold
    mobileButton.TextSize = 12
    mobileButton.AutoButtonColor = false
    mobileButton.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = mobileButton

    mobileButton.MouseButton1Click:Connect(function()
        bangModeEnabled = not bangModeEnabled
        mobileButton.Text = bangModeEnabled and "BANG\nON" or "BANG\nOFF"
        mobileButton.BackgroundColor3 = bangModeEnabled and Color3.fromRGB(37,122,247) or Color3.fromRGB(100,100,100)
        Notificar("Modo Bang", bangModeEnabled and "Activado" or "Desactivado", 2)
    end)

    local dragging, dragInput, dragStart, startPos
    mobileButton.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch)
           and mobileButtonDragEnabled then
            dragging = true; dragStart = input.Position; startPos = mobileButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    mobileButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and mobileButtonDragEnabled then
            local d = input.Position - dragStart
            mobileButton.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function destroyMobileButton()
    if _G.Fusion_MobileGui then
        _G.Fusion_MobileGui:Destroy(); _G.Fusion_MobileGui = nil; mobileButton = nil
    end
end

if MobileTab then
    MobileTab:Toggle({Title="Mostrar Botón Móvil", Value=false,
        Callback=function(s) mobileButtonEnabled=s; if s then createMobileButton() else destroyMobileButton() end end})
    MobileTab:Toggle({Title="Arrastrar Botón", Value=false,
        Callback=function(s) mobileButtonDragEnabled=s end})
end

-- ============================================================
-- DEFENCE
-- ============================================================
if DefenceTab then
    DefenceTab:Button({Title="CHOCO EDITION SPAM 👑",
        Callback=function()
            loadstring(game:HttpGet(("https://gist.githubusercontent.com/TOXIC-8535/3fb7f2ed806ebe14d31ec8fa87abdf6a/raw/2e5c81dda577d72b2b2b9e00b43477b784a742e0/Choco%2520edition%2520spammer"),true))()
        end})

    local SafeSpotGui, SafeSpotBaseplate, teleported, originalPosition = nil,nil,false,nil
    DefenceTab:Toggle({Title="Safe Spot", Value=false,
        Callback=function(value)
            if value then
                local tp = Vector3.new(5000,1000,5000)
                SafeSpotBaseplate = Instance.new("Part")
                SafeSpotBaseplate.Size = Vector3.new(100,1,100)
                SafeSpotBaseplate.Position = tp - Vector3.new(0,5,0)
                SafeSpotBaseplate.Anchored = true
                SafeSpotBaseplate.BrickColor = BrickColor.new("Earth green")
                SafeSpotBaseplate.Parent = workspace

                local pg = LP:WaitForChild("PlayerGui")
                SafeSpotGui = Instance.new("ScreenGui")
                SafeSpotGui.Name = "TeleportGui"; SafeSpotGui.ResetOnSpawn = false
                SafeSpotGui.Parent = pg

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0,50,0,50); btn.Position = UDim2.new(0,150,0,10)
                btn.BackgroundColor3 = Color3.fromRGB(0,200,0)
                btn.Text = "TP"; btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.GothamBold; btn.TextSize = 20
                btn.Parent = SafeSpotGui
                local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    if not teleported then
                        originalPosition = hrp.Position
                        hrp.CFrame = CFrame.new(tp); teleported = true
                        btn.BackgroundColor3 = Color3.fromRGB(255,0,0); btn.Text = "BACK"
                    else
                        if originalPosition then hrp.CFrame = CFrame.new(originalPosition) end
                        teleported = false
                        btn.BackgroundColor3 = Color3.fromRGB(0,200,0); btn.Text = "TP"
                    end
                end)
            else
                if SafeSpotGui then SafeSpotGui:Destroy(); SafeSpotGui=nil end
                if SafeSpotBaseplate then SafeSpotBaseplate:Destroy(); SafeSpotBaseplate=nil end
                if teleported and originalPosition and LP.Character then
                    local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(originalPosition) end
                    teleported = false
                end
            end
        end})

    DefenceTab:Toggle({Title="Anti Void", Value=false,
        Callback=function(v)
            Toggles.AntiVoid = v
            task.spawn(function()
                while Toggles.AntiVoid and task.wait() do
                    pcall(function()
                        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and hrp.Position.Y < -15 then
                            hrp.Velocity = Vector3.zero
                            hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
                        end
                    end)
                end
            end)
        end})

    DefenceTab:Toggle({Title="Anti Bang V1", Value=false,
        Callback=function(v)
            Toggles.AntiBangV1 = v
            task.spawn(function()
                while Toggles.AntiBangV1 do
                    task.wait(0.1)
                    pcall(function()
                        local char = LP.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            for _, op in pairs(Players:GetPlayers()) do
                                if op ~= LP and op.Character and op.Character:FindFirstChild("HumanoidRootPart") then
                                    local mp = char.HumanoidRootPart.Position
                                    local op2 = op.Character.HumanoidRootPart.Position
                                    if (mp-op2).Magnitude < 3.5 then
                                        local dir = (mp-op2).Unit
                                        char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame
                                            + Vector3.new(dir.X*20, 0, dir.Z*20)
                                    end
                                end
                            end
                        end
                    end)
                end
            end)
        end})

    DefenceTab:Toggle({Title="Anti Bang V2 (TP)", Value=false,
        Callback=function(v)
            Toggles.AntiBangV2 = v
            task.spawn(function()
                while Toggles.AntiBangV2 do
                    pcall(function()
                        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if not hrp then return end
                        local g = hrp.CFrame
                        hrp.CFrame = g * CFrame.new(0,1000,0); task.wait(0.1)
                        if not Toggles.AntiBangV2 then return end
                        hrp.CFrame = g; task.wait(0.1)
                        if not Toggles.AntiBangV2 then return end
                        hrp.CFrame = g * CFrame.new(0,-1000,0); task.wait(0.1)
                        if not Toggles.AntiBangV2 then return end
                        hrp.CFrame = g; task.wait(0.1)
                    end)
                end
            end)
        end})

    DefenceTab:Toggle({Title="Anti Fling", Value=false,
        Callback=function(v)
            Toggles.AntiFling = v
            if v then
                AntiFlingConnection = RunService.Stepped:Connect(function()
                    pcall(function()
                        for _, pl in pairs(Players:GetPlayers()) do
                            if pl ~= LP and pl.Character then
                                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                                if hrp and not hrp.Anchored then
                                    hrp.CustomPhysicalProperties = PhysicalProperties.new(0,0,0,0,0)
                                    hrp.CanCollide = false
                                    if hrp.Velocity.Magnitude > 100 or hrp.RotVelocity.Magnitude > 100 then
                                        hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero
                                    end
                                end
                            end
                        end
                    end)
                end)
                _G.Fusion_AntiFling = AntiFlingConnection
            else
                if AntiFlingConnection then
                    AntiFlingConnection:Disconnect(); AntiFlingConnection = nil
                    _G.Fusion_AntiFling = nil
                end
            end
        end})

    DefenceTab:Toggle({Title="Anti Sit", Value=false,
        Callback=function(v)
            Toggles.AntiSit = v
            task.spawn(function()
                while Toggles.AntiSit and task.wait() do
                    pcall(function()
                        local h = LP.Character and LP.Character:FindFirstChild("Humanoid")
                        if h and h.Sit then h.Jump = true end
                    end)
                end
            end)
        end})
end

-- ============================================================
-- NOTIFICACIÓN FINAL
-- ============================================================
WindUI:Notify({
    Title = "TOXIC HS FUSION 👑",
    Content = "Fusión cargada 💀 (Anti-Duplicados activo)",
    Duration = 5,
})

-- ============================================================
-- LIMPIEZA AL CERRAR
-- ============================================================
task.spawn(function()
    task.wait(2)
    local ui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui") or LP:WaitForChild("PlayerGui")
    local mainGui = nil
    for _, obj in ipairs(ui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text == "TOXIC HS FUSION" then
            mainGui = obj:FindFirstAncestorWhichIsA("ScreenGui")
            break
        end
    end
    if mainGui then
        mainGui.Destroying:Connect(function()
            FullDestruction()
            pcall(function()
                if LP and LP.Character then
                    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.WalkSpeed = 16
                        hum.PlatformStand = false
                        workspace.CurrentCamera.CameraSubject = hum
                    end
                end
            end)
        end)
    end
end)