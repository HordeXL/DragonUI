local addon = select(2, ...);

-- Create addon object using AceAddon
addon.core = LibStub("AceAddon-3.0"):NewAddon("DragonUI", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");

-- Function to recursively copy tables
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

function addon.core:OnInitialize()
    -- Replace the temporary addon.db with the real AceDB
    addon.db = LibStub("AceDB-3.0"):New("DragonUIDB", addon.defaults);

    -- Force defaults to be written to profile (check for specific key that should always exist)
    if not addon.db.profile.mainbars or not addon.db.profile.mainbars.scale_actionbar then
        -- Copy all defaults to profile to ensure they exist in SavedVariables
        deepCopy(addon.defaults.profile, addon.db.profile);
    end

    -- Register callbacks for configuration changes
    addon.db.RegisterCallback(addon, "OnProfileChanged", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileCopied", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileReset", "RefreshConfig");

    -- Now we can safely create and register options
    addon.options = addon:CreateOptionsTable();

    -- Inject AceDBOptions into the profiles section
    local profilesOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db);
    addon.options.args.profiles = profilesOptions;
    addon.options.args.profiles.order = 10;

    LibStub("AceConfig-3.0"):RegisterOptionsTable("DragonUI", addon.options);
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DragonUI", "DragonUI");

    -- Setup custom window size that's resistant to refreshes
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    if AceConfigDialog then
        -- Track if user has manually resized the window
        local userHasResized = false
        local defaultWidth, defaultHeight = 900, 600

        -- Hook into the status table system that manages window state
        local function setupDragonUIWindowSize()
            local configFrame = AceConfigDialog.OpenFrames["DragonUI"]
            if configFrame and configFrame.frame then
                -- Check if user has manually resized (status table contains user's size)
                local statusWidth = configFrame.status.width
                local statusHeight = configFrame.status.height

                -- If status has size and it's different from our default, user has resized
                if statusWidth and statusHeight then
                    if statusWidth ~= defaultWidth or statusHeight ~= defaultHeight then
                        userHasResized = true
                    end
                end

                -- Only apply our custom size if user hasn't manually resized
                if not userHasResized then
                    configFrame.frame:SetWidth(defaultWidth)
                    configFrame.frame:SetHeight(defaultHeight)
                    configFrame.frame:ClearAllPoints()
                    configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

                    -- Update AceGUI's internal size tracking
                    configFrame.status.width = defaultWidth
                    configFrame.status.height = defaultHeight
                else
                    -- User has resized, just maintain their size and center position
                    configFrame.frame:ClearAllPoints()
                    configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end
        end

        -- Hook the status table application (runs on every refresh)
        local originalSetStatusTable = AceConfigDialog.SetStatusTable
        AceConfigDialog.SetStatusTable = function(self, appName, statusTable)
            local result = originalSetStatusTable(self, appName, statusTable)

            if appName == "DragonUI" then
                -- Apply our custom size after status is set
                setupDragonUIWindowSize()
            end

            return result
        end

        -- Hook the initial Open to set size immediately
        local originalOpen = AceConfigDialog.Open
        AceConfigDialog.Open = function(self, appName, ...)
            local result = originalOpen(self, appName, ...)

            if appName == "DragonUI" then
                -- Reset user resize flag on new window opening
                userHasResized = false
                -- Apply size IMMEDIATELY without delay
                setupDragonUIWindowSize()
            end

            return result
        end
    end

    -- Apply current profile configuration immediately
    -- This ensures the profile is loaded when the addon starts
    addon:RefreshConfig();
end

-- Callback function that refreshes all modules when configuration changes
function addon:RefreshConfig()
    -- Initialize cooldown system if it hasn't been already
    if addon.InitializeCooldowns then
        addon.InitializeCooldowns()
    end

    local failed = {};

    -- Try to apply each configuration and track failures
    if addon.RefreshMainbars then
        local success, err = pcall(addon.RefreshMainbars);
        if not success then
            table.insert(failed, "RefreshMainbars")
        end
    end

    if addon.RefreshButtons then
        local success, err = pcall(addon.RefreshButtons);
        if not success then
            table.insert(failed, "RefreshButtons")
        end
    end

    if addon.RefreshMicromenu then
        local success, err = pcall(addon.RefreshMicromenu);
        if not success then
            table.insert(failed, "RefreshMicromenu")
        end
    end

    if addon.RefreshMinimap then
        local success, err = pcall(addon.RefreshMinimap);
        if not success then
            table.insert(failed, "RefreshMinimap")
        end
    end

    if addon.RefreshTargetFrame then
        local success, err = pcall(addon.RefreshTargetFrame);
        if not success then
            table.insert(failed, "RefreshTargetFrame")
        end
    end

    if addon.RefreshFocusFrame then
        local success, err = pcall(addon.RefreshFocusFrame);
        if not success then
            table.insert(failed, "RefreshFocusFrame")
        end
    end

    if addon.RefreshPartyFrames then
        local success, err = pcall(addon.RefreshPartyFrames);
        if not success then
            table.insert(failed, "RefreshPartyFrames")
        end
    end

    if addon.RefreshStance then
        local success, err = pcall(addon.RefreshStance);
        if not success then
            table.insert(failed, "RefreshStance")
        end
    end

    if addon.RefreshPetbar then
        local success, err = pcall(addon.RefreshPetbar);
        if not success then
            table.insert(failed, "RefreshPetbar")
        end
    end

    if addon.RefreshVehicle then
        local success, err = pcall(addon.RefreshVehicle);
        if not success then
            table.insert(failed, "RefreshVehicle")
        end
    end

    if addon.RefreshMulticast then
        local success, err = pcall(addon.RefreshMulticast);
        if not success then
            table.insert(failed, "RefreshMulticast")
        end
    end

    if addon.RefreshCooldowns then
        local success, err = pcall(addon.RefreshCooldowns);
        if not success then
            table.insert(failed, "RefreshCooldowns")
        end
    end

    if addon.RefreshXpRepBarPosition then
        pcall(addon.RefreshXpRepBarPosition)
    end

    if addon.RefreshRepBarPosition then
        pcall(addon.RefreshRepBarPosition)
    end

    if addon.RefreshMinimapTime then
        local success, err = pcall(addon.RefreshMinimapTime);
        if not success then
            table.insert(failed, "RefreshMinimapTime")
        end
    end

    -- If some configurations failed, retry them after 2 seconds
    if #failed > 0 then
        addon.core:ScheduleTimer(function()
            for _, funcName in ipairs(failed) do
                if addon[funcName] then
                    pcall(addon[funcName]);
                end
            end
        end, 2);
    end
end

function addon.core:OnEnable()
    -- Register slash commands
    self:RegisterChatCommand("dragonui", "SlashCommand");
    self:RegisterChatCommand("pi", "SlashCommand");

    -- Fire custom event to signal that DragonUI is fully initialized
    -- This ensures modules get the correct config values
    self:SendMessage("DRAGONUI_READY");
end

function addon.core:SlashCommand(input)
    if not input or input:trim() == "" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "config" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "edit" or input:lower() == "editor" then
        if addon.EditorMode then
            addon.EditorMode:Toggle();
        else
            self:Print("Editor mode not available. Make sure the editor_mode module is loaded.");
        end
    elseif input:lower() == "debug" or input:lower() == "test" then
        -- ✅ COMANDO DE DIAGNÓSTICO DEL SISTEMA CENTRALIZADO
        self:Print("=== DragonUI Centralized System Debug ===");
        
        if addon.EditableFrames then
            self:Print("Registered frames: " .. tostring(addon:tcount(addon.EditableFrames)));
            for name, frameData in pairs(addon.EditableFrames) do
                local frameStatus = frameData.frame and "OK" or "MISSING"
                local configPath = table.concat(frameData.configPath, ".")
                self:Print("  - " .. name .. " (frame: " .. frameStatus .. ", config: " .. configPath .. ")");
            end
        else
            self:Print("ERROR: No EditableFrames table found!");
        end
        
        if addon.db and addon.db.profile.widgets then
            self:Print("Database widgets:");
            for widgetName, widgetData in pairs(addon.db.profile.widgets) do
                self:Print("  - " .. widgetName .. ": " .. (widgetData.anchor or "NONE") .. " (" .. (widgetData.posX or 0) .. "," .. (widgetData.posY or 0) .. ")");
            end
        else
            self:Print("ERROR: No widgets in database!");
        end
    else
        self:Print("Commands:");
        self:Print("/dragonui config - Open configuration");
        self:Print("/dragonui edit - Toggle editor mode for moving UI elements");
        self:Print("/dragonui debug - Show centralized system debug info");
    end
end

---------------------------------------------------
-- FUNCIONES GLOBALES PARA EL SISTEMA DE MOVILIDAD 
---------------------------------------------------

-- ✅ FUNCIÓN AUXILIAR PARA CONTAR ELEMENTOS EN TABLA
function addon:tcount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)

    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')

    -- ✅ TEXTURA VERDE COMO RETAILUI
    do
        local texture = frame:CreateTexture(nil, 'BACKGROUND')
        texture:SetAllPoints(frame)
        -- ✅ CAMBIO: Usar textura sólida en lugar de border_buttons.tga
        texture:SetTexture(0, 1, 0, 0.3) -- Verde semi-transparente
        texture:Hide()
        frame.editorTexture = texture

        
    end

    -- ✅ TEXTO COMO RETAILUI
    do
        local fontString = frame:CreateFontString(nil, "BORDER", 'GameFontNormal')
        fontString:SetAllPoints(frame)
        fontString:SetText(frameName)
        fontString:Hide()
        frame.editorText = fontString
    end

    return frame
end

-- ✅ FRAMES REGISTRY COMO RETAILUI
addon.frames = {}

function ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    frame.editorTexture:Hide()
    frame.editorText:Hide()

    if addon.frames[frame] then
        for _, target in pairs(addon.frames[frame]) do
            target:SetAlpha(1)
        end
        addon.frames[frame] = nil
    end
end

function HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame.editorTexture:Show()
    frame.editorText:Show()

    addon.frames[frame] = {}
    exclude = exclude or {}

    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(addon.frames[frame], target)
    end
end

function SaveUIFramePosition(frame, configPath1, configPath2)
    if not frame then
        print("|cFFFF0000[DragonUI]|r SaveUIFramePosition: frame is nil")
        return
    end

    local anchor, _, relativePoint, posX, posY = frame:GetPoint(1) -- Primer punto

    -- ✅ MANEJAR RUTAS ANIDADAS (widgets.player)
    if configPath2 then
        -- Caso: SaveUIFramePosition(frame, "widgets", "player")
        if not addon.db.profile[configPath1] then
            addon.db.profile[configPath1] = {}
        end

        if not addon.db.profile[configPath1][configPath2] then
            addon.db.profile[configPath1][configPath2] = {}
        end

        addon.db.profile[configPath1][configPath2].anchor = anchor or "CENTER"
        addon.db.profile[configPath1][configPath2].posX = posX or 0
        addon.db.profile[configPath1][configPath2].posY = posY or 0

        print(string.format("[DragonUI] %s.%s position saved: %s (%.0f, %.0f)", 
              configPath1, configPath2, anchor or "CENTER", posX or 0, posY or 0))
    else
        -- Caso: SaveUIFramePosition(frame, "minimap") - compatibilidad hacia atrás
        local widgetName = configPath1
        
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end

        if not addon.db.profile.widgets[widgetName] then
            addon.db.profile.widgets[widgetName] = {}
        end

        addon.db.profile.widgets[widgetName].anchor = anchor or "CENTER"
        addon.db.profile.widgets[widgetName].posX = posX or 0
        addon.db.profile.widgets[widgetName].posY = posY or 0

        print(string.format("[DragonUI] %s position saved: %s (%.0f, %.0f)", 
              widgetName, anchor or "CENTER", posX or 0, posY or 0))
    end
end

function CheckSettingsExists(moduleInstance, widgets)
    for _, widget in pairs(widgets) do
        if not addon.db.profile.widgets[widget] then
            moduleInstance:LoadDefaultSettings()
            break
        end
    end
    moduleInstance:UpdateWidgets()
end

function ApplyUIFramePosition(frame, configPath)
    if not frame or not configPath then
        return
    end

    local section, key = configPath:match("([^%.]+)%.([^%.]+)")
    if not section or not key then
        return
    end

    local config = addon.db.profile[section] and addon.db.profile[section][key]
    if not config or not config.override then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(config.anchor or "CENTER", UIParent, config.anchorParent or "CENTER", config.x or 0, config.y or 0)
end

function CheckSettingsExists(moduleTable, configPaths)
    local needsDefaults = false

    for _, configPath in pairs(configPaths) do
        local section, key = configPath:match("([^%.]+)%.([^%.]+)")
        if section and key then
            if not addon.db.profile[section] or not addon.db.profile[section][key] then
                needsDefaults = true
                break
            end
        end
    end

    if needsDefaults and moduleTable.LoadDefaultSettings then
        moduleTable:LoadDefaultSettings()
    end

    if moduleTable.UpdateWidgets then
        moduleTable:UpdateWidgets()
    end
end

---------------------------------------------------
-- SISTEMA CENTRALIZADO DE FRAMES EDITABLES (EXTENDIDO)
---------------------------------------------------

-- ✅ REGISTRO GLOBAL DE TODOS LOS FRAMES EDITABLES
addon.EditableFrames = {}

-- ✅ FUNCIÓN PARA REGISTRAR FRAMES AUTOMÁTICAMENTE
function addon:RegisterEditableFrame(frameInfo)
    local frameData = {
        name = frameInfo.name,                    -- "player", "minimap", "target"
        frame = frameInfo.frame,                  -- El frame auxiliar
        blizzardFrame = frameInfo.blizzardFrame,  -- ✅ NUEVO: Frame real de Blizzard (opcional)
        configPath = frameInfo.configPath,       -- {"widgets", "player"} o {"unitframe", "target"}
        onShow = frameInfo.onShow,               -- Función opcional al mostrar editor
        onHide = frameInfo.onHide,               -- Función opcional al ocultar editor
        -- ✅ NUEVO: Funciones para mostrar/ocultar con datos fake
        showTest = frameInfo.showTest,           -- Función para mostrar con datos fake
        hideTest = frameInfo.hideTest,           -- Función para ocultar frame fake
        hasTarget = frameInfo.hasTarget,         -- Función para verificar si debe estar visible
        module = frameInfo.module                -- Referencia al módulo
    }
    
    self.EditableFrames[frameInfo.name] = frameData
    print("|cFF00FF00[DragonUI]|r Registered editable frame:", frameInfo.name)
end

-- ✅ FUNCIÓN PARA MOSTRAR TODOS LOS FRAMES EN EDITOR MODE
function addon:ShowAllEditableFrames()
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            HideUIFrame(frameData.frame) -- Mostrar overlay verde
            
            -- ✅ NUEVO: Mostrar frame con datos fake si es necesario
            if frameData.showTest then
                frameData.showTest()
            end
            
            if frameData.onShow then
                frameData.onShow()
            end
        end
    end
    print("|cFF00FF00[DragonUI]|r All editable frames shown for editing")
end

-- ✅ FUNCIÓN PARA OCULTAR TODOS LOS FRAMES Y GUARDAR POSICIONES
function addon:HideAllEditableFrames(refresh)
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            ShowUIFrame(frameData.frame) -- Ocultar overlay verde
            
            -- ✅ NUEVO: Ocultar frame fake si no debe estar visible
            if frameData.hideTest then
                frameData.hideTest()
            end
            
            if refresh then
                -- Guardar posición automáticamente
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                
                if frameData.onHide then
                    frameData.onHide()
                end
            end
        end
    end
    print("|cFF00FF00[DragonUI]|r All editable frames hidden, positions saved")
end

-- ✅ FUNCIÓN PARA VERIFICAR SI UN FRAME DEBE ESTAR VISIBLE
function addon:ShouldFrameBeVisible(frameName)
    local frameData = self.EditableFrames[frameName]
    if not frameData then return false end
    
    if frameData.hasTarget then
        return frameData.hasTarget()
    end
    
    -- Por defecto, los frames siempre están visibles (player, minimap)
    return true
end

-- ✅ FUNCIÓN PARA OBTENER INFORMACIÓN DE UN FRAME REGISTRADO
function addon:GetEditableFrameInfo(frameName)
    return self.EditableFrames[frameName]
end

-- ✅ EXPORTAR CreateUIFrame AL NAMESPACE ADDON PARA COMPATIBILIDAD
addon.CreateUIFrame = CreateUIFrame

---------------------------------------------------
---------------------------------------------------
