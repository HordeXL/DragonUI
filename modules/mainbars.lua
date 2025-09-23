local addon = select(2, ...)
addon._dir = "Interface\\AddOns\\DragonUI\\assets\\"
-- ============================================================================
-- CONFIGURATION FUNCTIONS (ALWAYS AVAILABLE)
-- ============================================================================

local function GetModuleConfig()
    return addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.mainbars
end

local function IsModuleEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled
end
-- ============================================================================
-- PET BAR FUNCTION (ALWAYS AVAILABLE)
-- ============================================================================

-- Update pet bar visibility and positioning
function addon.UpdatePetBarVisibility()
    if InCombatLockdown() then
        return
    end

    local petBar = PetActionBarFrame
    if not petBar then
        return
    end

    -- Check if player has a pet or is in a vehicle
    local hasPet = UnitExists("pet") and UnitIsVisible("pet")
    local inVehicle = UnitInVehicle("player")
    local hasVehicleActionBar = HasVehicleActionBar and HasVehicleActionBar()

    -- Show pet bar if player has a pet or relevant vehicle controls
    if hasPet or (inVehicle and hasVehicleActionBar) then
        if not petBar:IsShown() then
            petBar:Show()
        end

        -- Ensure proper positioning and scaling
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if db and db.scale_petbar then
            petBar:SetScale(db.scale_petbar)
        end

        -- Update pet action buttons
        for i = 1, NUM_PET_ACTION_SLOTS do
            local button = _G["PetActionButton" .. i]
            if button then
                button:Show()
            end
        end
    else
        -- Hide pet bar when no pet and not in vehicle
        if petBar:IsShown() then
            petBar:Hide()
        end
    end
end

-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================
-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================

-- Check if module is enabled when addon loads
local function InitializeMainbars()
    if not IsModuleEnabled() then
        return -- DO NOTHING if disabled
    end

    -- ============================================================================
    -- EVERYTHING BELOW ONLY RUNS IF MODULE IS ENABLED
    -- ============================================================================

    -- MODULE STATE TRACKING
    local MainbarsModule = {
        initialized = false,
        applied = false,
        originalStates = {},
        registeredEvents = {},
        hooks = {},
        stateDrivers = {},
        frames = {},
        eventFrames = {},
        originalScales = {},
        originalPositions = {},
        originalTextures = {},
        originalVisibility = {},
        actionBarFrames = nil
    }

    -- CORE COMPONENTS
    local config = addon.config;
    local event = addon.package;
    local do_action = addon.functions;
    local select = select;
    local pairs = pairs;
    local ipairs = ipairs;
    local format = string.format;
    local UIParent = UIParent;
    local hooksecurefunc = hooksecurefunc;
    local UnitFactionGroup = UnitFactionGroup;
    local _G = getfenv(0);

    -- constants
    local faction = UnitFactionGroup('player');
    local MainMenuBarMixin = {};
    local pUiMainBar = CreateFrame('Frame', 'pUiMainBar', UIParent, 'MainMenuBarUiTemplate');

    local pUiMainBarArt = CreateFrame('Frame', 'pUiMainBarArt', pUiMainBar);

    -- ACTION BAR SYSTEM
    addon.ActionBarFrames = {
        mainbar = nil,
        rightbar = nil,
        leftbar = nil,
        bottombarleft = nil,
        bottombarright = nil,
        repexpbar = nil
    }

    -- Set initial scale and properties
    pUiMainBar:SetScale(config.mainbars.scale_actionbar);
    pUiMainBarArt:SetFrameStrata('HIGH');
    pUiMainBarArt:SetFrameLevel(pUiMainBar:GetFrameLevel() + 4);
    pUiMainBarArt:SetAllPoints(pUiMainBar);

    -- ============================================================================
    -- ALL THE MAINBARS FUNCTIONS (ONLY WHEN ENABLED)
    -- ============================================================================

    local function UpdateGryphonStyle()
        if not MainMenuBarLeftEndCap or not MainMenuBarRightEndCap then
            return
        end

        local db_style = addon.db and addon.db.profile and addon.db.profile.style
        if not db_style then
            db_style = config.style
        end

        local faction = UnitFactionGroup('player')

        if db_style.gryphons == 'old' then
            MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -85, -22)
            MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 84, -22)
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-right', true)
            MainMenuBarLeftEndCap:Show()
            MainMenuBarRightEndCap:Show()
        elseif db_style.gryphons == 'new' then
            MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -94, -23)
            MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 95, -23)
            if faction == 'Alliance' then
                MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-left', true)
                MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-right', true)
            else
                MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-left', true)
                MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-right', true)
            end
            MainMenuBarLeftEndCap:Show()
            MainMenuBarRightEndCap:Show()
        elseif db_style.gryphons == 'flying' then
            MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -80, -21)
            MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 80, -21)
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-right', true)
            MainMenuBarLeftEndCap:Show()
            MainMenuBarRightEndCap:Show()
        else
            MainMenuBarLeftEndCap:Hide()
            MainMenuBarRightEndCap:Hide()
        end
    end

    -- ============================================================================
    -- ORIGINAL STATE STORAGE
    -- ============================================================================

    local function StoreOriginalMainbarStates()
        -- Store MainMenuBar state
        if MainMenuBar then
            MainbarsModule.originalStates.MainMenuBar = {
                parent = MainMenuBar:GetParent(),
                scale = MainMenuBar:GetScale(),
                points = {},
                mouseEnabled = MainMenuBar:IsMouseEnabled(),
                movable = MainMenuBar:IsMovable(),
                userPlaced = MainMenuBar:IsUserPlaced()
            }
            for i = 1, MainMenuBar:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = MainMenuBar:GetPoint(i)
                table.insert(MainbarsModule.originalStates.MainMenuBar.points,
                    {point, relativeTo, relativePoint, xOfs, yOfs})
            end
        end

        -- Store other action bars states
        local bars = {MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight, PetActionBarFrame}
        for _, bar in pairs(bars) do
            if bar then
                local name = bar:GetName()
                MainbarsModule.originalStates[name] = {
                    parent = bar:GetParent(),
                    scale = bar:GetScale(),
                    points = {},
                    mouseEnabled = bar:IsMouseEnabled(),
                    movable = bar:IsMovable(),
                    userPlaced = bar:IsUserPlaced()
                }
                for i = 1, bar:GetNumPoints() do
                    local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint(i)
                    table.insert(MainbarsModule.originalStates[name].points,
                        {point, relativeTo, relativePoint, xOfs, yOfs})
                end
            end
        end
    end

    -- ============================================================================
    -- RESTORE ORIGINAL STATE (When disabled)
    -- ============================================================================

    local function RestoreMainbarsSystem()
        if not MainbarsModule.applied then
            return
        end

        -- Hide DragonUI frames
        if MainbarsModule.frames.pUiMainBar then
            MainbarsModule.frames.pUiMainBar:Hide()
            MainbarsModule.frames.pUiMainBar = nil
        end
        if MainbarsModule.frames.pUiMainBarArt then
            MainbarsModule.frames.pUiMainBarArt:Hide()
            MainbarsModule.frames.pUiMainBarArt = nil
        end

        -- Clear ActionBarFrames
        if MainbarsModule.actionBarFrames then
            for name, frame in pairs(MainbarsModule.actionBarFrames) do
                if frame and frame.Hide then
                    frame:Hide()
                end
            end
            MainbarsModule.actionBarFrames = nil
            addon.ActionBarFrames = nil
        end

        -- Restore original states
        for frameName, state in pairs(MainbarsModule.originalStates) do
            local frame = _G[frameName]
            if frame and state then
                frame:SetParent(state.parent or UIParent)
                frame:SetScale(state.scale or 1.0)
                frame:ClearAllPoints()
                if state.points and #state.points > 0 then
                    for _, pointData in pairs(state.points) do
                        frame:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
                    end
                else
                    -- Default positioning for action bars
                    if frameName == "MainMenuBar" then
                        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
                    elseif frameName == "MultiBarRight" then
                        frame:SetPoint("RIGHT", UIParent, "RIGHT", -6, 0)
                    elseif frameName == "MultiBarLeft" then
                        frame:SetPoint("RIGHT", MultiBarRight, "LEFT", -6, 0)
                    elseif frameName == "MultiBarBottomLeft" then
                        frame:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", 0, 6)
                    elseif frameName == "MultiBarBottomRight" then
                        frame:SetPoint("BOTTOMLEFT", MultiBarBottomLeftButton1, "TOPLEFT", 0, 6)
                    end
                end
                frame:EnableMouse(state.mouseEnabled ~= false)
                frame:SetMovable(state.movable ~= false)
                frame:SetUserPlaced(state.userPlaced == true)
            end
        end

        -- Show action bars
        local bars = {MainMenuBar, MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight}
        for _, bar in pairs(bars) do
            if bar then
                bar:Show()
            end
        end

        MainbarsModule.originalStates = {}
        MainbarsModule.applied = false
       
    end

    -- ============================================================================
    -- CORE MAINBAR FUNCTIONS (From working code)
    -- ============================================================================

    function MainMenuBarMixin:actionbutton_setup()
        for _, obj in ipairs({MainMenuBar:GetChildren(), MainMenuBarArtFrame:GetChildren()}) do
            obj:SetParent(pUiMainBar)
        end

        for index = 1, NUM_ACTIONBAR_BUTTONS do
            pUiMainBar:SetFrameRef('ActionButton' .. index, _G['ActionButton' .. index])
        end

        for index = 1, NUM_ACTIONBAR_BUTTONS - 1 do
            local ActionButtons = _G['ActionButton' .. index]
            do_action.SetThreeSlice(ActionButtons);
        end

        for index = 2, NUM_ACTIONBAR_BUTTONS do
            local ActionButtons = _G['ActionButton' .. index]
            ActionButtons:SetParent(pUiMainBar)
            ActionButtons:SetClearPoint('LEFT', _G['ActionButton' .. (index - 1)], 'RIGHT', 7, 0)

            local BottomLeftButtons = _G['MultiBarBottomLeftButton' .. index]
            BottomLeftButtons:SetClearPoint('LEFT', _G['MultiBarBottomLeftButton' .. (index - 1)], 'RIGHT', 7, 0)

            local BottomRightButtons = _G['MultiBarBottomRightButton' .. index]
            BottomRightButtons:SetClearPoint('LEFT', _G['MultiBarBottomRightButton' .. (index - 1)], 'RIGHT', 7, 0)

            local BonusActionButtons = _G['BonusActionButton' .. index]
            BonusActionButtons:SetClearPoint('LEFT', _G['BonusActionButton' .. (index - 1)], 'RIGHT', 7, 0)
        end
    end

    function MainMenuBarMixin:actionbar_art_setup()
        -- setup art frames
        MainMenuBarArtFrame:SetParent(pUiMainBar)
        for _, art in pairs({MainMenuBarLeftEndCap, MainMenuBarRightEndCap}) do
            art:SetParent(pUiMainBarArt)
            art:SetDrawLayer('ARTWORK')
        end

        -- apply background settings
        self:update_main_bar_background()

        -- apply gryphon styling
        UpdateGryphonStyle()
    end

    function MainMenuBarMixin:update_main_bar_background()
        local alpha = (addon.db and addon.db.profile and addon.db.profile.buttons and
                          addon.db.profile.buttons.hide_main_bar_background) and 0 or 1

        -- handle button background textures
        for i = 1, NUM_ACTIONBAR_BUTTONS do
            local button = _G["ActionButton" .. i]
            if button then
                if button.NormalTexture then
                    button.NormalTexture:SetAlpha(alpha)
                end
                for j = 1, button:GetNumRegions() do
                    local region = select(j, button:GetRegions())
                    if region and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" and
                        region ~= button:GetNormalTexture() then
                        region:SetAlpha(alpha)
                    end
                end
            end
        end

        if pUiMainBar then
            -- hide loose textures within pUiMainBar
            for i = 1, pUiMainBar:GetNumRegions() do
                local region = select(i, pUiMainBar:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texPath = region:GetTexture()
                    if texPath and not string.find(texPath, "ICON") then
                        region:SetAlpha(alpha)
                    end
                end
            end

            -- hide child frame textures with protection for UI elements
            for i = 1, pUiMainBar:GetNumChildren() do
                local child = select(i, pUiMainBar:GetChildren())
                local name = child and child:GetName()

                -- protect important UI elements from being hidden
                if child and name ~= "pUiMainBarArt" and not string.find(name or "", "ActionButton") and name ~=
                    "MultiBarBottomLeft" and name ~= "MultiBarBottomRight" and name ~= "MicroButtonAndBagsBar" and
                    not string.find(name or "", "MicroButton") and not string.find(name or "", "Bag") and name ~=
                    "CharacterMicroButton" and name ~= "SpellbookMicroButton" and name ~= "TalentMicroButton" and name ~=
                    "AchievementMicroButton" and name ~= "bagsFrame" and name ~= "MainMenuBarBackpackButton" and name ~=
                    "QuestLogMicroButton" and name ~= "SocialsMicroButton" and name ~= "PVPMicroButton" and name ~=
                    "LFGMicroButton" and name ~= "MainMenuMicroButton" and name ~= "HelpMicroButton" and name ~=
                    "MainMenuExpBar" and name ~= "ReputationWatchBar" then

                    for j = 1, child:GetNumRegions() do
                        local region = select(j, child:GetRegions())
                        if region and region:GetObjectType() == "Texture" then
                            region:SetAlpha(alpha)
                        end
                    end
                end
            end
        end
    end

    function MainMenuBarMixin:actionbar_setup()
        ActionButton1:SetParent(pUiMainBar)
        ActionButton1:SetClearPoint('BOTTOMLEFT', pUiMainBar, 2, 2)

        if config.buttons.pages.show then
            do_action.SetNumPagesButton(ActionBarUpButton, pUiMainBarArt, 'pageuparrow', 8)
            do_action.SetNumPagesButton(ActionBarDownButton, pUiMainBarArt, 'pagedownarrow', -14)

            MainMenuBarPageNumber:SetParent(pUiMainBarArt)
            MainMenuBarPageNumber:SetClearPoint('CENTER', ActionBarDownButton, -1, 12)
            local pagesFont = config.buttons.pages.font
            MainMenuBarPageNumber:SetFont(pagesFont[1], pagesFont[2], pagesFont[3])
            MainMenuBarPageNumber:SetShadowColor(0, 0, 0, 1)
            MainMenuBarPageNumber:SetShadowOffset(1.2, -1.2)
            MainMenuBarPageNumber:SetDrawLayer('OVERLAY', 7)
        else
            ActionBarUpButton:Hide();
            ActionBarDownButton:Hide();
            MainMenuBarPageNumber:Hide();
        end

        MultiBarBottomRight:EnableMouse(false)
        MultiBarRight:SetScale(config.mainbars.scale_rightbar)
        MultiBarLeft:SetScale(config.mainbars.scale_leftbar)
        if MultiBarBottomLeft then
            MultiBarBottomLeft:SetScale(config.mainbars.scale_bottomleft or 0.9)
        end
        if MultiBarBottomRight then
            MultiBarBottomRight:SetScale(config.mainbars.scale_bottomright or 0.9)
        end
    end

    function addon.PositionActionBars()
        if InCombatLockdown() then
            return
        end

        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if not db then
            return
        end

        -- Configure MultiBarRight orientation
        if MultiBarRight then
            if db.right.horizontal then
                -- Horizontal mode: buttons go from left to right
                for i = 2, 12 do
                    local button = _G["MultiBarRightButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("LEFT", _G["MultiBarRightButton" .. (i - 1)], "RIGHT", 7, 0)
                    end
                end
            else
                -- Vertical mode: buttons go from top to bottom (default)
                for i = 2, 12 do
                    local button = _G["MultiBarRightButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("TOP", _G["MultiBarRightButton" .. (i - 1)], "BOTTOM", 0, -7)
                    end
                end
            end
        end

        -- Configure MultiBarLeft orientation
        if MultiBarLeft then
            if db.left.horizontal then
                -- Horizontal mode: buttons go from left to right
                for i = 2, 12 do
                    local button = _G["MultiBarLeftButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("LEFT", _G["MultiBarLeftButton" .. (i - 1)], "RIGHT", 7, 0)
                    end
                end
            else
                -- Vertical mode: buttons go from top to bottom (default)
                for i = 2, 12 do
                    local button = _G["MultiBarLeftButton" .. i]
                    if button then
                        button:ClearAllPoints()
                        button:SetPoint("TOP", _G["MultiBarLeftButton" .. (i - 1)], "BOTTOM", 0, -7)
                    end
                end
            end
        end
    end

    function MainMenuBarMixin:statusbar_setup()
        -- Setup pet bar initial configuration
        if PetActionBarFrame then
            -- Ensure pet bar uses correct scale from config
            local db = addon.db and addon.db.profile and addon.db.profile.mainbars
            if db and db.scale_petbar then
                PetActionBarFrame:SetScale(db.scale_petbar)
            elseif config.mainbars.scale_petbar then
                PetActionBarFrame:SetScale(config.mainbars.scale_petbar)
            end

            -- Enable mouse interaction
            PetActionBarFrame:EnableMouse(true)
        end
        
        -- Initial setup for XP/Rep bars with NEW style sizes
        if MainMenuExpBar then
            MainMenuExpBar:SetClearPoint('BOTTOM', UIParent, 0, 6)
            MainMenuExpBar:SetFrameLevel(1) -- Lower level for editor overlay visibility
            -- Set NEW style size immediately
            MainMenuExpBar:SetSize(537, 10)
            
            if MainMenuBarExpText then
                MainMenuBarExpText:SetParent(MainMenuExpBar)
                -- Text will be positioned later based on style
            end
        end
        
        -- Setup reputation bar with NEW style sizes
        if ReputationWatchBar then
            ReputationWatchBar:SetFrameLevel(1) -- Lower level for editor overlay visibility
            -- Set NEW style size immediately
            ReputationWatchBar:SetSize(537, 10)
            
            if ReputationWatchStatusBar then
                -- Set NEW style size for status bar too
                ReputationWatchStatusBar:SetSize(537, 10)
                
                -- CRITICAL: Configure reputation text properly from the start
                if ReputationWatchStatusBarText then
                    -- Ensure correct parent
                    ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
                    -- Set reasonable layering - not excessively high
                    ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
                    -- Position for NEW style (offset +1)
                    ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
                    -- IMPORTANT: Hide by default (only show on hover)
                    ReputationWatchStatusBarText:Hide()
                end
            end
        end
    end


    -- Connect XP/Rep bars to the editor system
    local function ConnectBarsToEditor()
    if not addon.ActionBarFrames.repexpbar then
        return
    end

    local mainMenuExpBar = MainMenuExpBar
    if mainMenuExpBar then
        mainMenuExpBar:SetParent(addon.ActionBarFrames.repexpbar)
        mainMenuExpBar:ClearAllPoints()
        mainMenuExpBar:SetSize(537, 10)
        mainMenuExpBar:SetFrameLevel(1)
        mainMenuExpBar:SetScale(0.9)
        mainMenuExpBar:SetFrameStrata("MEDIUM")
        
        -- COMPORTAMIENTO CORRECTO: Posición inicial
        mainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, 0)
    end

    local repWatchBar = ReputationWatchBar
    if repWatchBar then
        repWatchBar:SetParent(addon.ActionBarFrames.repexpbar)
        repWatchBar:ClearAllPoints()
        repWatchBar:SetSize(537, 10)
        repWatchBar:SetScale(0.9)
        repWatchBar:SetFrameLevel(1)
        repWatchBar:SetFrameStrata("MEDIUM")
        
        -- COMPORTAMIENTO CORRECTO: Rep va arriba, luego UpdateBarPositions ajusta XP
        repWatchBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, 0)
        
        if ReputationWatchStatusBar then
            ReputationWatchStatusBar:SetSize(537, 10)
            
            if ReputationWatchStatusBarText then
                ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
                ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
                ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
                ReputationWatchStatusBarText:Hide()
            end
        end
    end
end

    -- Force reputation text configuration (ensures text is properly configured but hidden by default)
    local function ForceReputationTextConfiguration()
        if ReputationWatchStatusBarText and ReputationWatchStatusBar then
            -- Force correct parent
            ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
            -- Force reasonable layering - not excessively high
            ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
            -- Force correct positioning for NEW style
            ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
            -- IMPORTANT: Hide by default - only show on hover (Blizzard handles this)
            ReputationWatchStatusBarText:Hide()
        end
    end

    -- Update bar positioning when needed
    local function UpdateBarPositions()
    if not addon.ActionBarFrames.repexpbar then
        return
    end

    local mainMenuExpBar = MainMenuExpBar
    local repWatchBar = ReputationWatchBar
    
    if repWatchBar and repWatchBar:IsShown() then
        -- Cuando Rep está visible: Rep toma la posición original de XP (centro)
        repWatchBar:ClearAllPoints()
        repWatchBar:SetSize(537, 10)
        repWatchBar:SetScale(0.9)
        repWatchBar:SetFrameLevel(1)
        repWatchBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, -3)
        
        -- XP se mueve hacia abajo
        if mainMenuExpBar then
            mainMenuExpBar:ClearAllPoints()
            mainMenuExpBar:SetSize(537, 10)
            mainMenuExpBar:SetFrameLevel(1)
            mainMenuExpBar:SetScale(0.9)
            mainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, -22)
        end
        
        if ReputationWatchStatusBar then
            ReputationWatchStatusBar:SetSize(537, 10)
            
            if ReputationWatchStatusBarText then
                ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
                ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
                ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
                ReputationWatchStatusBarText:Hide()
            end
        end
    else
        -- Cuando Rep NO está visible: XP vuelve al centro
        if mainMenuExpBar then
            mainMenuExpBar:ClearAllPoints()
            mainMenuExpBar:SetSize(537, 10)
            mainMenuExpBar:SetFrameLevel(1)
            mainMenuExpBar:SetScale(0.9)
            mainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.repexpbar, "CENTER", 0, 0)
        end
    end
end
    local function RemoveBlizzardFrames()
        local blizzFrames = {MainMenuBarPerformanceBar, MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2,
                             MainMenuBarTexture3, MainMenuBarMaxLevelBar, ReputationXPBarTexture1,
                             ReputationXPBarTexture2, ReputationXPBarTexture3, ReputationWatchBarTexture1,
                             ReputationWatchBarTexture2, ReputationWatchBarTexture3, MainMenuXPBarTexture1,
                             MainMenuXPBarTexture2, MainMenuXPBarTexture3, SlidingActionBarTexture0,
                             SlidingActionBarTexture1, BonusActionBarTexture0, BonusActionBarTexture1,
                             ShapeshiftBarLeft, ShapeshiftBarMiddle, ShapeshiftBarRight, PossessBackground1,
                             PossessBackground2}

        for _, frame in pairs(blizzFrames) do
            if frame then
                frame:SetAlpha(0)
            end
        end

        if MainMenuBar then
            MainMenuBar:EnableMouse(false)
        end
        if ShapeshiftBarFrame then
            ShapeshiftBarFrame:EnableMouse(false)
        end
        if PossessBarFrame then
            PossessBarFrame:EnableMouse(false)
        end
        if PetActionBarFrame then
            PetActionBarFrame:EnableMouse(false)
        end
        if MultiCastActionBarFrame then
            MultiCastActionBarFrame:EnableMouse(false)
        end
    end


    function MainMenuBarMixin:initialize()
        self:actionbutton_setup();
        self:actionbar_setup();
        self:actionbar_art_setup();
        self:statusbar_setup();
    end

    -- Create action bar container frames (RetailUI pattern)
    local function CreateActionBarFrames()
        -- Main bar - create a NEW container frame instead of using pUiMainBar directly
        addon.ActionBarFrames.mainbar = addon.CreateUIFrame(pUiMainBar:GetWidth(), pUiMainBar:GetHeight(), "MainBar")

        -- Create other action bar containers
        addon.ActionBarFrames.rightbar = addon.CreateUIFrame(40, 490, "RightBar")
        addon.ActionBarFrames.leftbar = addon.CreateUIFrame(40, 490, "LeftBar")
        addon.ActionBarFrames.bottombarleft = addon.CreateUIFrame(490, 40, "BottomBarLeft")
        addon.ActionBarFrames.bottombarright = addon.CreateUIFrame(490, 40, "BottomBarRight")

        -- RepExp bar container (RetailUI pattern)
        addon.ActionBarFrames.repexpbar = addon.CreateUIFrame(addon.ActionBarFrames.mainbar:GetWidth(), 10, "RepExpBar")
    end

    -- Position action bars to their container frames (initialization only - safe during addon load)
    local function PositionActionBarsToContainers_Initial()
        -- Position main bar - anchor pUiMainBar to its container
        if pUiMainBar and addon.ActionBarFrames.mainbar then
            pUiMainBar:SetParent(UIParent)
            pUiMainBar:ClearAllPoints()
            pUiMainBar:SetPoint("CENTER", addon.ActionBarFrames.mainbar, "CENTER")
        end

        -- Position right bar
        if MultiBarRight and addon.ActionBarFrames.rightbar then
            MultiBarRight:SetParent(UIParent)
            MultiBarRight:ClearAllPoints()
            MultiBarRight:SetPoint("CENTER", addon.ActionBarFrames.rightbar, "CENTER")
        end

        -- Position left bar
        if MultiBarLeft and addon.ActionBarFrames.leftbar then
            MultiBarLeft:SetParent(UIParent)
            MultiBarLeft:ClearAllPoints()
            MultiBarLeft:SetPoint("CENTER", addon.ActionBarFrames.leftbar, "CENTER")
        end

        -- Position bottom left bar
        if MultiBarBottomLeft and addon.ActionBarFrames.bottombarleft then
            MultiBarBottomLeft:SetParent(UIParent)
            MultiBarBottomLeft:ClearAllPoints()
            MultiBarBottomLeft:SetPoint("CENTER", addon.ActionBarFrames.bottombarleft, "CENTER")
        end

        -- Position bottom right bar
        if MultiBarBottomRight and addon.ActionBarFrames.bottombarright then
            MultiBarBottomRight:SetParent(UIParent)
            MultiBarBottomRight:ClearAllPoints()
            MultiBarBottomRight:SetPoint("CENTER", addon.ActionBarFrames.bottombarright, "CENTER")
        end
    end

    -- Position action bars to their container frames
    local function PositionActionBarsToContainers()
        -- Only proceed if not in combat to avoid taint
        if InCombatLockdown() then
            return
        end

        -- Use the initial function for runtime positioning
        PositionActionBarsToContainers_Initial()
    end

    -- Apply saved positions from database (RetailUI pattern)
    local function ApplyActionBarPositions()
        -- Safe containers can be positioned anytime - no combat check needed
        if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
            return
        end

        local widgets = addon.db.profile.widgets

        -- Apply mainbar container position (safe to do anytime)
        if widgets.mainbar and addon.ActionBarFrames.mainbar then
            local config = widgets.mainbar
            if config.anchor then
                addon.ActionBarFrames.mainbar:ClearAllPoints()
                addon.ActionBarFrames.mainbar:SetPoint(config.anchor, config.posX, config.posY)
            end
        end

        -- Apply other bar positions
        local barConfigs = {{
            frame = addon.ActionBarFrames.rightbar,
            config = widgets.rightbar,
            default = {"RIGHT", -10, -70}
        }, {
            frame = addon.ActionBarFrames.leftbar,
            config = widgets.leftbar,
            default = {"RIGHT", -45, -70}
        }, {
            frame = addon.ActionBarFrames.bottombarleft,
            config = widgets.bottombarleft,
            default = {"BOTTOM", 0, 120}
        }, {
            frame = addon.ActionBarFrames.bottombarright,
            config = widgets.bottombarright,
            default = {"BOTTOM", 0, 160}
        }, -- RetailUI pattern: RepExp bar positioning
        {
            frame = addon.ActionBarFrames.repexpbar,
            config = widgets.repexpbar,
            default = {"BOTTOM", 0, 35}
        }}

        for _, barData in ipairs(barConfigs) do
            if barData.frame and barData.config and barData.config.anchor then
                local config = barData.config
                barData.frame:ClearAllPoints()
                barData.frame:SetPoint(config.anchor, config.posX, config.posY)
            elseif barData.frame then
                -- Apply default position
                local default = barData.default
                barData.frame:ClearAllPoints()
                barData.frame:SetPoint(default[1], UIParent, default[1], default[2], default[3])
            end
        end
    end

    -- Register action bar frames with the centralized system (RetailUI pattern)
    local function RegisterActionBarFrames()
        -- Register all action bar frames
        local frameRegistrations = {{
            name = "mainbar",
            frame = addon.ActionBarFrames.mainbar,
            blizzardFrame = MainMenuBar,
            configPath = {"widgets", "mainbar"}
        }, {
            name = "rightbar",
            frame = addon.ActionBarFrames.rightbar,
            blizzardFrame = MultiBarRight,
            configPath = {"widgets", "rightbar"}
        }, {
            name = "leftbar",
            frame = addon.ActionBarFrames.leftbar,
            blizzardFrame = MultiBarLeft,
            configPath = {"widgets", "leftbar"}
        }, {
            name = "bottombarleft",
            frame = addon.ActionBarFrames.bottombarleft,
            blizzardFrame = MultiBarBottomLeft,
            configPath = {"widgets", "bottombarleft"}
        }, {
            name = "bottombarright",
            frame = addon.ActionBarFrames.bottombarright,
            blizzardFrame = MultiBarBottomRight,
            configPath = {"widgets", "bottombarright"}
        }, -- RetailUI pattern: RepExp bar registration
        {
            name = "repexpbar",
            frame = addon.ActionBarFrames.repexpbar,
            blizzardFrame = nil,
            configPath = {"widgets", "repexpbar"}
        }}

        for _, registration in ipairs(frameRegistrations) do
            if registration.frame then
                addon:RegisterEditableFrame({
                    name = registration.name,
                    frame = registration.frame,
                    blizzardFrame = registration.blizzardFrame,
                    configPath = registration.configPath,
                    module = addon.MainBars
                })
            end
        end
    end

    -- Hook drag events to ensure action bars follow their containers
    local function SetupActionBarDragHandlers()
        -- Add drag end handlers to reposition action bars
        for name, frame in pairs(addon.ActionBarFrames) do
            -- Exclude bars that don't need repositioning after drag
            if frame and name ~= "mainbar" then
                frame:HookScript("OnDragStop", function(self)
                    addon.core:ScheduleTimer(function()
                        -- RetailUI Pattern: Only reposition if not in combat
                        PositionActionBarsToContainers()
                    end, 0.1)
                end)
            end
        end
    end

    -- update position for secondary action bars - LEGACY FUNCTION
    function addon.RefreshUpperActionBarsPosition()
        if not MultiBarBottomLeftButton1 or not MultiBarBottomRight then
            return
        end

        -- calculate offset based on background visibility
        local yOffset1, yOffset2
        if addon.db and addon.db.profile.buttons.hide_main_bar_background then
            -- values when background is hidden
            yOffset1 = 45
            yOffset2 = 8
        else
            -- default values when background is visible
            yOffset1 = 48
            yOffset2 = 8
        end
    end

  

    -- Apply the mainbars system
    local function ApplyMainbarsSystem()
        if MainbarsModule.applied then
            return
        end

      
        MainMenuBarMixin:initialize()
        addon.pUiMainBar = pUiMainBar

        CreateActionBarFrames()
        ApplyActionBarPositions()
        RegisterActionBarFrames()

        -- ENSURE GRYPHONS ARE ABOVE ALL ACTION BARS
        addon.core:ScheduleTimer(function()
            if pUiMainBarArt then
                -- Get the highest frame level from action bars
                local maxLevel = 1
                local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight}
                for _, bar in pairs(bars) do
                    if bar then
                        maxLevel = math.max(maxLevel, bar:GetFrameLevel())
                    end
                end
                
                -- Set gryphon art frame level higher than all bars
                pUiMainBarArt:SetFrameLevel(maxLevel + 10)
            end
        end, 0.1)

        -- Set up hooks for XP/Rep bars - RESTORED FUNCTIONALITY
        -- Connect bars to editor system first
        ConnectBarsToEditor()
        
        -- Force reputation text configuration
        ForceReputationTextConfiguration()
        
        -- Hook for maintaining editor connection
        hooksecurefunc('MainMenuExpBar_Update', UpdateBarPositions)
        hooksecurefunc('ReputationWatchBar_Update', UpdateBarPositions)
        
        -- Add the essential ReputationWatchBar_Update hook for styling only
        hooksecurefunc('ReputationWatchBar_Update', function()
            local name = GetWatchedFactionInfo()
            if name and ReputationWatchBar then
                -- Update editor positioning only if using editor system
                if addon.ActionBarFrames.repexpbar then
                    UpdateBarPositions()
                end
                
                -- Configure reputation status bar for NEW style only
                if ReputationWatchStatusBar then
                    ReputationWatchStatusBar:SetHeight(10)
                    ReputationWatchStatusBar:SetClearPoint('TOPLEFT', ReputationWatchBar, 0, 3)
                    
                    -- Set size to match NEW style (537x10)
                    ReputationWatchStatusBar:SetSize(537, 10)
                    
                    if ReputationWatchStatusBarBackground then
                        ReputationWatchStatusBarBackground:SetAllPoints(ReputationWatchStatusBar)
                    end
                    
                    -- Text positioning for NEW style with FIXED layering
                    if ReputationWatchStatusBarText then
                        -- NEW style text positioning (offset +1)
                        ReputationWatchStatusBarText:SetClearPoint('CENTER', ReputationWatchStatusBar, 'CENTER', 0, 1)
                        
                        -- Reasonable layering - not excessively high
                        ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 2)
                    end
                end
            end
        end)


        -- Position action bars immediately
        PositionActionBarsToContainers_Initial()

        -- Set up drag handlers
        addon.core:ScheduleTimer(function()
            SetupActionBarDragHandlers()
        end, 0.2)

        -- Store module state
        MainbarsModule.frames.pUiMainBar = pUiMainBar
        MainbarsModule.frames.pUiMainBarArt = pUiMainBarArt
        MainbarsModule.actionBarFrames = addon.ActionBarFrames
        MainbarsModule.applied = true
    end

    -- Initialize immediately since we're already enabled
    ApplyMainbarsSystem()

    -- Set up event handlers - NEW style only system
    local function ApplyDragonUIExpRepBarStyling()
        -- Always use NEW style system only
        
        -- Setup both exp and rep bars with NEW styling system
        for _, bar in pairs({MainMenuExpBar, ReputationWatchStatusBar}) do
            if bar then
                bar:GetStatusBarTexture():SetDrawLayer('BORDER')
                
                -- Create status texture if it doesn't exist
                if not bar.status then
                    bar.status = bar:CreateTexture(nil, 'ARTWORK')
                end
                
                -- Always apply NEW style (537x10 size)
                bar:SetSize(537, 10)
                bar.status:SetPoint('CENTER', 0, -2)
                bar.status:set_atlas('ui-hud-experiencebar-round', true)
                
                -- Apply custom textures for reputation bar
                if bar == ReputationWatchStatusBar then
                    bar:SetStatusBarTexture(addon._dir .. 'statusbarfill.tga')
                    if ReputationWatchStatusBarBackground then
                        ReputationWatchStatusBarBackground:set_atlas('ui-hud-experiencebar-background', true)
                    end
                end
            end
        end
        
        -- Apply background styling for NEW style for MainMenuExpBar
        if MainMenuExpBar then
            -- Ensure MainMenuExpBar is properly centered
            MainMenuExpBar:ClearAllPoints()
            if addon.ActionBarFrames.repexpbar then
                MainMenuExpBar:SetPoint('CENTER', addon.ActionBarFrames.repexpbar, 'CENTER', 0, 0)
            end
            
            for _, obj in pairs({MainMenuExpBar:GetRegions()}) do
                if obj:GetObjectType() == 'Texture' and obj:GetDrawLayer() == 'BACKGROUND' then
                    obj:set_atlas('ui-hud-experiencebar-background', true)
                end
            end
        end
    end

    local function ApplyModernExpBarVisual()
        local exhaustionStateID = GetRestState()
        local mainMenuExpBar = MainMenuExpBar
        
        if not mainMenuExpBar then
            return
        end
        
        -- Always apply NEW style custom texture system
        mainMenuExpBar:SetStatusBarTexture(addon._dir .. "uiexperiencebar")
        mainMenuExpBar:SetStatusBarColor(1, 1, 1, 1)
        
        -- Configure ExhaustionLevelFillBar
        if ExhaustionLevelFillBar then
            ExhaustionLevelFillBar:SetHeight(mainMenuExpBar:GetHeight())
            ExhaustionLevelFillBar:set_atlas('ui-hud-experiencebar-fill-prediction')
        end
        
        -- Apply exhaustion-based TexCoords
        if exhaustionStateID == 1 then
            -- Rested state
            mainMenuExpBar:GetStatusBarTexture():SetTexCoord(574/2048, 1137/2048, 34/64, 43/64)
            if ExhaustionLevelFillBar then
                ExhaustionLevelFillBar:SetVertexColor(0.0, 0, 1, 0.45)
            end
        elseif exhaustionStateID == 2 then
            -- Tired state
            mainMenuExpBar:GetStatusBarTexture():SetTexCoord(1/2048, 570/2048, 42/64, 51/64)
            if ExhaustionLevelFillBar then
                ExhaustionLevelFillBar:SetVertexColor(0.58, 0.0, 0.55, 0.45)
            end
        else
            -- Normal state
            mainMenuExpBar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
        end
        
        -- Never show ExhaustionTick (as requested)
        if ExhaustionTick then
            ExhaustionTick:Hide()
        end
    end
    -- Single event handler for addon initialization
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    initFrame:RegisterEvent("UPDATE_FACTION")
    initFrame:RegisterEvent("PET_BAR_UPDATE")
    initFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
    initFrame:RegisterEvent("UNIT_PET")
    initFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    initFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    initFrame:RegisterEvent("PLAYER_LOGIN")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Apply initial styling setup
            addon.core:ScheduleTimer(function()
                ApplyDragonUIExpRepBarStyling()
                ApplyModernExpBarVisual()
                ForceReputationTextConfiguration()
            end, 0.2)
        elseif event == "UPDATE_EXHAUSTION" then
            -- Update exhaustion state only
            ApplyModernExpBarVisual()
            ForceReputationTextConfiguration()
        end
    end)

    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "DragonUI" then
            -- Initialize basic components immediately
            if IsModuleEnabled() then
                ApplyMainbarsSystem()
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Apply XP/Rep bar styling and connect to editor
            addon.core:ScheduleTimer(function()
                if IsModuleEnabled() then
                    -- Remove interfering Blizzard textures FIRST
                    RemoveBlizzardFrames()

                    -- Connect bars to editor system
                    ConnectBarsToEditor()

                    -- Apply DragonUI styling system (from OLD)
                    ApplyDragonUIExpRepBarStyling()

                    -- Apply modern exhaustion system
                    ApplyModernExpBarVisual()

                    -- Force reputation text configuration
                    ForceReputationTextConfiguration()

                    -- Update positions
                    UpdateBarPositions()

                    -- Hide text by default
                    if MainMenuBarExpText then
                        MainMenuBarExpText:Hide()
                    end
                    if ReputationWatchBarText then
                        ReputationWatchBarText:Hide()
                    end
                end
            end, 0.1)

            -- Initialize pet bar visibility
            addon.core:ScheduleTimer(function()
                if IsModuleEnabled() then
                    addon.UpdatePetBarVisibility()
                end
            end, 1.0)

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        elseif event == "PLAYER_LOGIN" then
            -- Set up profile callbacks
            addon.core:ScheduleTimer(function()
                if addon.db then
                    addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                        addon.core:ScheduleTimer(function()
                            addon.RefreshMainbarsSystem()
                        end, 0.1)
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                        addon.core:ScheduleTimer(function()
                            addon.RefreshMainbarsSystem()
                        end, 0.1)
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileReset", function()
                        addon.core:ScheduleTimer(function()
                            addon.RefreshMainbarsSystem()
                        end, 0.1)
                    end)

                    -- Initial refresh
                    addon.RefreshMainbarsSystem()
                end
            end, 2)

            self:UnregisterEvent("PLAYER_LOGIN")

        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Reposition when combat ends
            if IsModuleEnabled() then
                addon.core:ScheduleTimer(function()
                    ApplyActionBarPositions()
                    PositionActionBarsToContainers()
                end, 0.1)
            end

        elseif event == "UPDATE_FACTION" then
            -- Update reputation bar when watched faction changes
            if IsModuleEnabled() then
                addon.core:ScheduleTimer(function()
                    ApplyDragonUIExpRepBarStyling()
                    ForceReputationTextConfiguration()
                    UpdateBarPositions()
                end, 0.1)
            end

        elseif event == "PET_BAR_UPDATE" or event == "PET_BAR_UPDATE_COOLDOWN" or event == "UNIT_PET" then
            -- Handle pet bar visibility and updates
            if IsModuleEnabled() and (arg1 == "player" or not arg1) then
                addon.core:ScheduleTimer(function()
                    addon.UpdatePetBarVisibility()
                end, 0.1)
            end

        elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            -- Handle vehicle events that affect pet bar
            if IsModuleEnabled() and arg1 == "player" then
                addon.core:ScheduleTimer(function()
                    addon.UpdatePetBarVisibility()
                end, 0.2)
            end
        end
    end)

end

-- ============================================================================
-- INITIALIZATION CONTROL
-- ============================================================================

-- Event frame to handle initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Solo inicializar si está habilitado
        InitializeMainbars()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Backup check
        InitializeMainbars()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Public API for options
function addon.RefreshMainbarsSystem()
  
end
