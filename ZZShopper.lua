ZZShopper = {}

ZZShopper.name             = "ZZShopper"
ZZShopper.version          = "3.0.1"
ZZShopper.savedVarVersion  = 1
ZZShopper.is_recording     = false


local FILTER_TYPE_ID_ZZSHOPPER = 104

-- Return commafied integer number "123,456", or "?" if nil.
function ZZShopper.ToMoney(x)
    if not x then return "?" end
    return ZO_CurrencyControl_FormatCurrency(ZZShopper.round(x), false)
end

function ZZShopper.round(f)
    if not f then return f end
    return math.floor(0.5+f)
end


function ZZShopper.InitAGSIntegration()
    if ZZShopper.ags_init_started then return end
    ZZShopper.ags_init_started = true
    local AGS = AwesomeGuildStore   -- for less typing
    if not (    AGS
            and AGS.GetAPIVersion
            and AGS.GetAPIVersion() == 3) then
        return
    end

    local filter_class = ZZShopper.AGS_CreateFilterClass()

    CALLBACK_MANAGER:RegisterCallback(
                 AGS.OnInitializeFiltersCallbackName
            or AGS.AfterInitialSetupCallbackName
          ,
        function(tradingHouseWrapper)
            local tradingHouse       = tradingHouseWrapper.tradingHouse
            local browseItemsControl = tradingHouse.m_browseItems
            local common             = browseItemsControl:GetNamedChild("Common")
            local filter             = filter_class:New('ZZShopper', tradingHouseWrapper)
            ZZShopper.filter         = filter
            tradingHouseWrapper:RegisterFilter(filter)
            tradingHouseWrapper:AttachFilter(filter)
            tradingHouseWrapper.searchTab.categoryFilter:UpdateSubfilterVisibility() -- small hack to ensure that the order is correct
        end)
end

-- begin editor inheritance from Master Merchant -----------------------------

function ZZShopper.AGS_CreateFilterClass()
    local gettext               = LibStub("LibGetText")("AwesomeGuildStore").gettext
    local FilterBase            = AwesomeGuildStore.FilterBase
    local ZZShopper_AGSFilter   = FilterBase:Subclass()
    local LINE_SPACING          = 4

    function ZZShopper_AGSFilter:New(name, tradingHouseWrapper, ...)
                        -- FilterBase.New() internally calls
                        --   InitializeBase(), creating container control
                        --      and resetButton
                        --   Initialize() overridable
        return FilterBase.New(self, FILTER_TYPE_ID_ZZSHOPPER, name, tradingHouseWrapper, ...)
    end

    function ZZShopper_AGSFilter:Initialize(name, tradingHouseWrapper)
        local tradingHouse = tradingHouseWrapper.tradingHouse
        local saveData  = tradingHouseWrapper.saveData
        local container = self.container

                        -- Red (pink!) title for our portion of
                        -- the filter sidebar.
        local label = container:CreateControl(name .. "Label", CT_LABEL)
        label:SetFont("ZoFontWinH4")
        label:SetText("ZZShopper")
        self:SetLabelControl(label)

                        -- Enable/Disable checkbox.
        local button = WINDOW_MANAGER:CreateControlFromVirtual(
                              name.."Button"
                            , container
                            , "ZO_DefaultButton")
        ZZShopper.button = button
        button:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 4)
        button:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
        container:SetHeight(label:GetHeight() + 32)
        button:SetText("Start Recording")
        button:SetHandler("OnClicked", function(...)
                self:ToggleRecording()
                end)
        container:SetHeight(  label:GetHeight() + LINE_SPACING
                            + 28 )

        local tooltipText = gettext("Reset <<1>> Filter", label:GetText():gsub(":", ""))
        self.resetButton:SetTooltipText(tooltipText)
    end

    function ZZShopper_AGSFilter:IsEnabled()
        return ZZShopper.is_recording
    end

    function ZZShopper_AGSFilter:SetEnabled(enabled)
        ZZShopper.is_recording = enabled
    end

    function ZZShopper_AGSFilter:ToggleRecording()
        ZZShopper.is_recording = not ZZShopper.is_recording
        self:HandleChange()
    end

    function ZZShopper_AGSFilter:HandleChange()
        self:UpdateButtonText()
        FilterBase.HandleChange(self)
    end

    function ZZShopper_AGSFilter:UpdateButtonText()
        if not ZZShopper.button then return end
        if self:IsEnabled() then
            ZZShopper.button:SetText("Stop Recording")
        else
            ZZShopper.button:SetText("Start Recording")
        end
    end

    function ZZShopper_AGSFilter:BeforeRebuildSearchResultsPage(tradingHouseWrapper)
        if(not self:IsDefault()) then
            return true
        end
        return false
    end

    function ZZShopper_AGSFilter:ApplyFilterValues(filterArray)
        -- do nothing here as we want to filter on the result page
    end

    function ZZShopper_AGSFilter:FilterPageResult(index, icon, name, quality, stackCount, sellerName, timeRemaining, purchasePrice)
        -- do stuff
        d(name)
        return true
    end

    function ZZShopper_AGSFilter:Reset()
        self:SetEnabled(false)
        self:UpdateButtonText()
    end

    function ZZShopper_AGSFilter:IsDefault()
        return not self:IsEnabled()
    end

    function ZZShopper_AGSFilter:Serialize()
        local e = self:IsEnabled()
        if e then
            return "1"
        end
        return ""
    end

    function ZZShopper_AGSFilter:Deserialize(state)
        local text   = state
        local number = tonumber(text)
        if number then
            -- cb enable
        else
            -- cb disable
        end
    end

    function ZZShopper_AGSFilter:GetTooltipText(state)
                        -- Return a list of { label, text } tuples
                        -- that appear in the AGS search history.
        local tip_line_list = {}

        local text   = state
        local number = tonumber(text)
        if number then
            local line = { label = "ZZShopper logging"
                         , text  = "enabled"
                         }
            table.insert(tip_line_list, line)
        end
        return tip_line_list
    end

    return ZZShopper_AGSFilter
end

-- Init ----------------------------------------------------------------------

function ZZShopper.OnAddOnLoaded(event, addonName)
    if addonName ~= ZZShopper.name then return end
    if not ZZShopper.version then return end
    ZZShopper:Initialize()
end

function ZZShopper:Initialize()
    self.savedVariables = ZO_SavedVars:New(
                              "ZZShopperVars"
                            , self.savedVarVersion
                            , nil
                            , self.default
                            )
    self.InitAGSIntegration()
end

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZShopper.name
                              , EVENT_ADD_ON_LOADED
                              , ZZShopper.OnAddOnLoaded
                              )

