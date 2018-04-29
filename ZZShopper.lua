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

        ZZShopper.InitData()
        return false
    end

    function ZZShopper_AGSFilter:ApplyFilterValues(filterArray)
        -- do nothing here as we want to filter on the result page
    end

    function ZZShopper_AGSFilter:FilterPageResult(index, icon, name, quality, stackCount, sellerName, timeRemaining, purchasePrice)
        ZZShopper.RememberCurrentGuild()
        ZZShopper.RememberListing({ ["item_name"] = name
                                  , ["index"]     = index
                                  , ["stack_ct"]  = stackCount
                                  , ["price"]     = purchasePrice
                                  })
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

-- Data ----------------------------------------------------------------------

function ZZShopper.InitData()
                        -- Recently inited? Don't do it again.
    local sv          = ZZShopper.savedVariables -- for less typing
    local now_ts_sec  = GetTimeStamp()
    local HOURS       = 3600
    local too_old_sec = now_ts_sec - 6*HOURS
    if sv.start_ts_sec and too_old_sec < sv.start_ts_sec then
        return
    end

d("About to reset. start:"..tostring(sv.start_ts_sec).." too_old:"..tostring(too_old_sec))
    sv.start_ts_sec = now_ts_sec
    ZZShopper.ResetAllData()
d("Reset. new start:"..tostring(sv.start_ts_sec))
end

function ZZShopper.ResetAllData()
    local sv = ZZShopper.savedVariables
    sv.guild = {}
    sv.guild_ct = 0
    sv.listings = {}
    ZZShopper.RememberOwnGuilds()
end

function ZZShopper.RememberOwnGuilds()
    for i = 1,5 do
        local guild_id   = GetGuildId(i)
        local guild_name = GetGuildName(guild_id)
        ZZShopper.RememberGuild(guild_name, "--member--")
    end
end

function ZZShopper.RememberGuild(guild_name, city_name)
    local self = ZZShopper
    self.savedVariables.guild = self.savedVariables.guild or {}
    local guild_ct = self.savedVariables.guild_ct or 0
    local index    = guild_ct + 1

                        -- Already known? Nothing more to do.
    if self.savedVariables.guild[guild_name] then
        return self.savedVariables.guild[guild_name].index
    end

    self.savedVariables.guild[guild_name] = {
          name  = guild_name
        , city  = city_name
        , index = index
        }
    self.savedVariables.guild_ct = index
    return index
end

function ZZShopper.RememberCurrentGuild()
    local _, guild_name, _ = GetCurrentTradingHouseGuildDetails()
    local zone_index = GetCurrentMapZoneIndex()
    local zone_name  = GetZoneNameByIndex(zone_index)
    ZZShopper.current_guild_index = ZZShopper.RememberGuild(guild_name, zone_name)
end

function ZZShopper.RememberListing(args)
    if not (args.item_name and args.price) then return end

    local sv = ZZShopper.savedVariables -- for less typing
    local gi = ZZShopper.current_guild_index
    sv.listings = sv.listings or {}
    sv.listings[args.item_name]     = sv.listings[args.item_name]     or {}
    sv.listings[args.item_name][gi] = sv.listings[args.item_name][gi] or ""

    local item_str = tostring(args.stack_ct).."@"..tostring(args.price)
    if sv.listings[args.item_name][gi] == "" then
        sv.listings[args.item_name][gi] = item_str
    else
        sv.listings[args.item_name][gi] = sv.listings[args.item_name][gi] .. "\t" .. item_str
    end
end

function ZZShopper.DumpStats()
    local sv = ZZShopper.savedVariables
    local guild_index_set = {}
    local item_ct = 0
    for item_name, guild_list in pairs(sv.listings or {}) do
        for guild_index, row in pairs(guild_list) do
            guild_index_set[guild_index] = 1
        end
        item_ct = item_ct + 1
    end
    local guild_ct = 0
    for k,v in pairs(guild_index_set) do
        guild_ct = guild_ct + 1
    end
    d(string.format("ZZShopper: guild_ct:%d  item_ct:%d", guild_ct, item_ct))
end

function ZZShopper.SlashCommand(arg1)
    local arg = arg1:lower()
    if arg == "reset" then
        ZZShopper.ResetAllData()
        d("ZZShopper: all data reset.")
        return
    end

    if arg == "stats" then
        ZZShopper.DumpStats()
        return
    end

    d("/zzshopper stats : dump current listing stats")
    d("/zzshopper reset : forget everything")
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

SLASH_COMMANDS["/zzshopper"] = ZZShopper.SlashCommand
