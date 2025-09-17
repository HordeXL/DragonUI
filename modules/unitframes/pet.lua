-- ===============================================================
-- DRAGONUI PET FRAME MODULE - OPTIMIZED WITH TEXT SYSTEM
-- ===============================================================
local addon = select(2, ...)
local PetFrameModule = {}
addon.PetFrameModule = PetFrameModule

-- ===============================================================
-- LOCALIZED API REFERENCES
-- ===============================================================
local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitExists = UnitExists
local UnitPowerType = UnitPowerType
local hooksecurefunc = hooksecurefunc

-- ===============================================================
-- MODULE CONSTANTS
-- ===============================================================
local TEXTURE_PATH = 'Interface\\Addons\\DragonUI\\Textures\\'
local UNITFRAME_PATH = TEXTURE_PATH .. 'Unitframe\\'
local ATLAS_TEXTURE = TEXTURE_PATH .. 'uiunitframe'
local TOT_BASE = 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-'

local POWER_TEXTURES = {
    MANA = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Mana',
    FOCUS = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Focus',
    RAGE = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Rage',
    ENERGY = UNITFRAME_PATH .. TOT_BASE .. 'Bar-Energy',
    RUNIC_POWER = UNITFRAME_PATH .. TOT_BASE .. 'Bar-RunicPower'
}

local COMBAT_TEX_COORDS = {0.3095703125, 0.4208984375, 0.3125, 0.404296875}

-- ===============================================================
-- ANIMACIONES COMBAT PULSE
-- ===============================================================

-- ✅ CONFIGURACIÓN PARA PULSO DE COLOR
local COMBAT_PULSE_SETTINGS = {
    speed = 9,              -- Velocidad del latido
    minIntensity = 0.3,     -- Intensidad mínima del rojo (0.4 = rojo oscuro)
    maxIntensity = 0.7,     -- Intensidad máxima del rojo (1.0 = rojo brillante)
    enabled = true          -- Activar/desactivar animación
}

-- ✅ VARIABLE DE ESTADO
local combatPulseTimer = 0


-- ===============================================================
-- NUEVA FUNCIÓN DE ANIMACIÓN CON CAMBIO DE COLOR
-- ===============================================================
local function AnimatePetCombatPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end
    
    local texture = _G.PetAttackModeTexture
    if not texture or not texture:IsVisible() then
        return
    end
    
    -- Incrementar timer
    combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)
    
    -- Calcular intensidad del rojo usando función seno
    local intensity = COMBAT_PULSE_SETTINGS.minIntensity + 
                     (COMBAT_PULSE_SETTINGS.maxIntensity - COMBAT_PULSE_SETTINGS.minIntensity) * 
                     (math.sin(combatPulseTimer) * 0.5 + 0.5)
    
    -- ✅ CAMBIAR COLOR EN LUGAR DE ALPHA
    texture:SetVertexColor(intensity, 0.0, 0.0, 1.0)
end

-- ===============================================================
-- MODULE STATE
-- ===============================================================
local moduleState = {
    frame = {},
    hooks = {},
    textSystem = nil
}

-- ===============================================================
-- UTILITY FUNCTIONS
-- ===============================================================
local function noop() end

-- ===============================================================
-- FRAME POSITIONING
-- ===============================================================
local function ApplyFramePositioning()
    local config = addon.db and addon.db.profile.unitframe.pet
    if not config or not PetFrame then return end
    
    PetFrame:SetScale(config.scale or 1.0)
    
    -- ✅ PRIORIDAD: Usar anchor frame si existe (sistema centralizado)
    if PetFrameModule.anchor then
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
        print("|cFF00FF00[DragonUI]|r Pet frame positioned relative to anchor")
    elseif config.override then
        -- ✅ FALLBACK: Sistema legacy de configuración manual
        PetFrame:ClearAllPoints()
        local anchor = config.anchorFrame and _G[config.anchorFrame] or UIParent
        PetFrame:SetPoint(
            config.anchor or "TOPRIGHT",
            anchor,
            config.anchorParent or "BOTTOMRIGHT",
            config.x or 0,
            config.y or 0
        )
        PetFrame:SetMovable(true)
        PetFrame:EnableMouse(true)
        print("|cFF00FF00[DragonUI]|r Pet frame positioned via legacy override")
    else
        print("|cFF00FF00[DragonUI]|r Pet frame using default Blizzard positioning")
    end
end

-- ===============================================================
-- POWER BAR MANAGEMENT
-- ===============================================================
local function UpdatePowerBarTexture()
    if not UnitExists("pet") or not PetFrameManaBar then return end
    
    local _, powerType = UnitPowerType('pet')
    local texture = POWER_TEXTURES[powerType]
    
    if texture then
        local statusBar = PetFrameManaBar:GetStatusBarTexture()
        statusBar:SetTexture(texture)
        statusBar:SetVertexColor(1, 1, 1, 1)
    end
end

-- ===============================================================
-- COMBAT MODE TEXTURE
-- ===============================================================
local function ConfigureCombatMode()
    local texture = _G.PetAttackModeTexture
    if not texture then return end
    
    texture:SetTexture(ATLAS_TEXTURE)
    texture:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    texture:SetVertexColor(1.0, 0.0, 0.0, 1.0)  -- Color inicial
    texture:SetBlendMode("ADD")
    texture:SetAlpha(0.8)  -- Alpha fijo
    texture:SetDrawLayer("OVERLAY", 9)
    texture:ClearAllPoints()
    texture:SetPoint('CENTER', PetFrame, 'CENTER', -7, -2)
    texture:SetSize(114, 47)
    
    -- ✅ REINICIAR TIMER
    combatPulseTimer = 0
end

-- ===============================================================
-- FUNCIÓN OnUpdate PARA EL PET FRAME
-- ===============================================================
local function PetFrame_OnUpdate(self, elapsed)
    local success, err = pcall(function()
        AnimatePetCombatPulse(elapsed)
    end)
    
    if not success then
        print("|cFFFF0000[DragonUI PetFrame]|r Error in OnUpdate:", err)
    end
end

-- ===============================================================
-- THREAT GLOW SYSTEM 
-- ===============================================================
local function ConfigurePetThreatGlow()
    -- ✅ El pet frame usa PetFrameFlash para el threat glow
    local threatFlash = _G.PetFrameFlash
    if not threatFlash then return end
    
    -- ✅ APLICAR TU TEXTURA PERSONALIZADA
    threatFlash:SetTexture(ATLAS_TEXTURE)  
    threatFlash:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    -- ✅ COORDENADAS DE TEXTURA (ajustar según tu textura)
    -- Formato: left, right, top, bottom (valores entre 0 y 1)
   
    
    -- ✅ CONFIGURACIÓN VISUAL
    threatFlash:SetBlendMode("ADD")  -- Efecto luminoso
    threatFlash:SetAlpha(0.7)  -- Transparencia
    threatFlash:SetDrawLayer("OVERLAY", 10)  -- Por encima de todo
    
    -- ✅ POSICIONAMIENTO PARA PET FRAME
    threatFlash:ClearAllPoints()
    threatFlash:SetPoint("CENTER", PetFrame, "CENTER", -7, -2)  
    threatFlash:SetSize(114, 47)  
end
-- ===============================================================
-- FRAME SETUP
-- ===============================================================
local function SetupFrameElement(parent, name, layer, texture, point, size)
    local element = parent:CreateTexture(name)
    element:SetDrawLayer(layer[1], layer[2])
    element:SetTexture(texture)
    element:SetPoint(unpack(point))
    if size then element:SetSize(unpack(size)) end
    return element
end

local function SetupStatusBar(bar, point, size, texture)
    bar:ClearAllPoints()
    bar:SetPoint(unpack(point))
    bar:SetSize(unpack(size))
    if texture then
        bar:GetStatusBarTexture():SetTexture(texture)
        bar:SetStatusBarColor(1, 1, 1, 1)
        bar.SetStatusBarColor = noop
    end
end

-- ===============================================================
-- MAIN FRAME REPLACEMENT
-- ===============================================================
local function ReplaceBlizzardPetFrame()
    local petFrame = PetFrame
    if not petFrame then return end

    if not moduleState.hooks.onUpdate then
        petFrame:SetScript("OnUpdate", PetFrame_OnUpdate)
        moduleState.hooks.onUpdate = true
        print("|cFF00FF00[DragonUI PetFrame]|r Combat pulse animation enabled")
    end
    
    ApplyFramePositioning()
    
    -- Hide original Blizzard texture
    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()
    
    -- Hide original text elements to avoid conflicts
    if PetFrameHealthBarText then PetFrameHealthBarText:Hide() end
    if PetFrameManaBarText then PetFrameManaBarText:Hide() end
    
    -- Setup portrait
    local portrait = PetPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(34, 34)
        portrait:SetDrawLayer('BACKGROUND')
    end
    
    -- Create DragonUI elements if needed
    if not moduleState.frame.background then
        moduleState.frame.background = SetupFrameElement(
            petFrame,
            'DragonUIPetFrameBackground',
            {'BACKGROUND', 1},
            TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND',
            {'LEFT', portrait, 'CENTER', -24, -10}
        )
    end
    
    if not moduleState.frame.border then
        moduleState.frame.border = SetupFrameElement(
            PetFrameHealthBar,
            'DragonUIPetFrameBorder',
            {'OVERLAY', 6},
            TEXTURE_PATH .. TOT_BASE .. 'BORDER',
            {'LEFT', portrait, 'CENTER', -24, -10}
        )
    end
    
    -- Setup health bar
    SetupStatusBar(
        PetFrameHealthBar,
        {'LEFT', portrait, 'RIGHT', 2, 0},
        {70.5, 10},
        UNITFRAME_PATH .. TOT_BASE .. 'Bar-Health'
    )
    
    -- Setup mana bar
    SetupStatusBar(
        PetFrameManaBar,
        {'LEFT', portrait, 'RIGHT', -1, -10},
        {74, 7.5}
    )
    UpdatePowerBarTexture()
    
    -- Configure combat mode
    ConfigureCombatMode()
    if not moduleState.hooks.combatMode then
        hooksecurefunc(_G.PetAttackModeTexture, "Show", function(self)
            ConfigureCombatMode()
        end)
        
        -- ✅ MODIFICAR EL HOOK DE SetVertexColor PARA NO INTERFERIR
        hooksecurefunc(_G.PetAttackModeTexture, "SetVertexColor", function(self, r, g, b, a)
            -- Solo intervenir si no es nuestro rango de colores del pulso
            if not COMBAT_PULSE_SETTINGS.enabled then
                if r ~= 1.0 or g ~= 0.0 or b ~= 0.0 then
                    self:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                end
            end
            -- Si el pulso está activo, dejamos que la animación controle el color
        end)
        
        moduleState.hooks.combatMode = true
    end

    -- Configurar threat glow personalizado
    if not moduleState.hooks.threatGlow then
        ConfigurePetThreatGlow()
        
        -- ✅ HOOK para mantener la configuración
        hooksecurefunc(_G.PetFrameFlash, "Show", ConfigurePetThreatGlow)
        
        moduleState.hooks.threatGlow = true
    end
    
    -- Setup pet name positioning
    if PetName then
        PetName:ClearAllPoints()
        PetName:SetPoint("CENTER", petFrame, "CENTER", 10, 13)
        PetName:SetJustifyH("LEFT")
        PetName:SetWidth(65)
        PetName:SetDrawLayer("OVERLAY")
    end
    
    -- Position happiness icon
    local happiness = _G[petFrame:GetName() .. 'Happiness']
    if happiness then
        happiness:ClearAllPoints()
        happiness:SetPoint("LEFT", petFrame, "RIGHT", -10, -5)
    end
    
    -- ===============================================================
    -- INTEGRATE TEXT SYSTEM
    -- ===============================================================
    if addon.TextSystem then
        print("|cFF00FF00[DragonUI PetFrame]|r Integrating with TextSystem...")
        
        -- Setup the advanced text system for pet frame
        moduleState.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "pet",                 -- frameType
            "pet",                 -- unit
            petFrame,              -- parentFrame
            PetFrameHealthBar,     -- healthBar
            PetFrameManaBar,       -- manaBar
            "PetFrame"             -- prefix
        )
        
        print("|cFF00FF00[DragonUI PetFrame]|r TextSystem integration complete!")
    else
        print("|cFFFF0000[DragonUI PetFrame]|r TextSystem not available, using fallback...")
    end
end

-- ===============================================================
-- UPDATE HANDLER
-- ===============================================================
local function OnPetFrameUpdate()
    -- Refresh textures
    if moduleState.frame.background then
        moduleState.frame.background:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND')
    end
    if moduleState.frame.border then
        moduleState.frame.border:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BORDER')
    end
    
    UpdatePowerBarTexture()
    ConfigureCombatMode()
    ConfigurePetThreatGlow()
    
    -- Update text system if available
    if moduleState.textSystem and moduleState.textSystem.update then
        moduleState.textSystem.update()
    end
end

-- ===============================================================
-- MODULE INTERFACE
-- ===============================================================
function PetFrameModule:OnEnable()
    if not moduleState.hooks.petUpdate then
        hooksecurefunc('PetFrame_Update', OnPetFrameUpdate)
        moduleState.hooks.petUpdate = true
    end
end

function PetFrameModule:OnDisable()
    if moduleState.textSystem and moduleState.textSystem.clear then
        moduleState.textSystem.clear()
    end
end

function PetFrameModule:PLAYER_ENTERING_WORLD()
    ReplaceBlizzardPetFrame()
end

-- ===============================================================
-- REFRESH FUNCTION FOR OPTIONS
-- ===============================================================
function addon.RefreshPetFrame()
    if UnitExists("pet") then
        OnPetFrameUpdate()
        print("|cFF00FF00[DragonUI]|r Pet frame refreshed")
    end
end

-- ===============================================================
-- EVENT HANDLING
-- ===============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        PetFrameModule:OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PetFrameModule:PLAYER_ENTERING_WORLD()
    end
end)

-- ===============================================================
-- MODULE INITIALIZATION COMPLETE
-- ===============================================================

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Variables para el sistema centralizado
PetFrameModule.anchor = nil
PetFrameModule.initialized = false

-- Create auxiliary frame for anchoring (como party.lua y castbar.lua)
local function CreatePetAnchorFrame()
    if PetFrameModule.anchor then
        return PetFrameModule.anchor
    end

    -- ✅ USAR FUNCIÓN CENTRALIZADA DE CORE.LUA
    PetFrameModule.anchor = addon.CreateUIFrame(128, 64, "PetFrame")
    
    -- ✅ PERSONALIZAR TEXTO PARA PET FRAME
    if PetFrameModule.anchor.editorText then
        PetFrameModule.anchor.editorText:SetText("Pet Frame")
    end
    
    return PetFrameModule.anchor
end

-- ✅ FUNCIÓN PARA APLICAR POSICIÓN DESDE WIDGETS (COMO party.lua)
local function ApplyWidgetPosition()
    if not PetFrameModule.anchor then
        print("|cFFFF0000[DragonUI]|r Pet anchor frame not created")
        return
    end

    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        print("|cFFFF0000[DragonUI]|r No widgets configuration found")
        return
    end
    
    local widgetConfig = addon.db.profile.widgets.pet
    
    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local anchor = widgetConfig.anchor or "TOPRIGHT"
        PetFrameModule.anchor:ClearAllPoints()
        PetFrameModule.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
        print("|cFF00FF00[DragonUI]|r Pet frame positioned via widgets:", anchor, widgetConfig.posX, widgetConfig.posY)
    else
        -- ✅ POSICIÓN POR DEFECTO COMO RETAILUI (esquina superior derecha)
        PetFrameModule.anchor:ClearAllPoints()
        PetFrameModule.anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -150)
        print("|cFF00FF00[DragonUI]|r Pet frame positioned with defaults: TOPRIGHT -50 -150")
    end
end

-- ✅ FUNCIONES REQUERIDAS POR EL SISTEMA CENTRALIZADO
function PetFrameModule:LoadDefaultSettings()
    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN WIDGETS
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.pet then
        addon.db.profile.widgets.pet = {
            anchor = "TOPRIGHT",
            posX = -50,
            posY = -150
        }
        print("|cFF00FF00[DragonUI]|r Pet frame: Created default widget settings")
    end
    
    -- ✅ ASEGURAR QUE EXISTE LA CONFIGURACIÓN EN UNITFRAME.PET
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end
    
    if not addon.db.profile.unitframe.pet then
        -- La configuración del pet ya debería existir en database.lua
        print("|cFF00FF00[DragonUI]|r Pet frame: Using existing unitframe.pet settings")
    end
end

function PetFrameModule:UpdateWidgets()
    ApplyWidgetPosition()
    -- ✅ REPOSICIONAR EL PET FRAME RELATIVO AL ANCHOR ACTUALIZADO
    if not InCombatLockdown() then
        -- El pet frame debería seguir al anchor
        ApplyFramePositioning()
    end
end

-- ✅ FUNCIÓN PARA VERIFICAR SI EL PET FRAME DEBE ESTAR VISIBLE
-- SIGUIENDO A RETAILUI: Siempre visible en editor, NO filtrado por clases
local function ShouldPetFrameBeVisible()
    -- RetailUI siempre permite editar el PET frame independientemente de la clase
    return true
end

-- ✅ FUNCIONES DE TESTEO PARA EL EDITOR
local function ShowPetFrameTest()
    -- Mostrar el PET frame aunque no haya mascota
    if PetFrame then
        PetFrame:Show()
        
        -- Simular que hay una mascota para el test
        if PetName then
            PetName:SetText("Test Pet")
            PetName:Show()
        end
        
        if PetPortrait then
            PetPortrait:Show()
        end
        
        if PetFrameHealthBar then
            PetFrameHealthBar:SetMinMaxValues(0, 100)
            PetFrameHealthBar:SetValue(75)
            PetFrameHealthBar:Show()
        end
        
        if PetFrameManaBar then
            PetFrameManaBar:SetMinMaxValues(0, 100)
            PetFrameManaBar:SetValue(50)
            PetFrameManaBar:Show()
        end
    end
end

local function HidePetFrameTest()
    -- Ocultar el PET frame de prueba si no hay mascota real
    if PetFrame and not UnitExists("pet") then
        PetFrame:Hide()
    end
end

-- ✅ FUNCIÓN DE INICIALIZACIÓN DEL SISTEMA CENTRALIZADO
local function InitializePetFrameForEditor()
    -- Crear el anchor frame
    CreatePetAnchorFrame()
    
    -- ✅ REGISTRO COMPLETO CON TODAS LAS FUNCIONES (COMO party.lua y castbar.lua)
    addon:RegisterEditableFrame({
        name = "PetFrame",
        frame = PetFrameModule.anchor,
        configPath = {"widgets", "pet"},  -- ✅ Array como otros módulos
        hasTarget = ShouldPetFrameBeVisible,  -- ✅ Siempre true (como RetailUI)
        showTest = ShowPetFrameTest,  -- ✅ Minúscula como party.lua
        hideTest = HidePetFrameTest,  -- ✅ Minúscula como party.lua
        onHide = function() PetFrameModule:UpdateWidgets() end,  -- ✅ Para aplicar cambios
        LoadDefaultSettings = function() PetFrameModule:LoadDefaultSettings() end,
        UpdateWidgets = function() PetFrameModule:UpdateWidgets() end
    })
    
    PetFrameModule.initialized = true
    print("|cFF00FF00[DragonUI]|r Pet frame registered with centralized system")
end

-- ✅ INICIALIZACIÓN
InitializePetFrameForEditor()

-- ✅ LISTENER PARA CUANDO EL ADDON ESTÉ COMPLETAMENTE CARGADO
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Aplicar posición del widget cuando el addon esté listo
        if PetFrameModule.UpdateWidgets then
            PetFrameModule:UpdateWidgets()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

print("|cFF00FF00[DragonUI]|r Pet Frame module loaded successfully - CENTRALIZED SYSTEM")