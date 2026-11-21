local name,A=...
local action="CLICK ForeverDBHelpButton:LeftButton"
local ready=false
function A.Bind(key)
    if InCombatLockdown() then A.Message("Change the contextual key after combat."); return false end
    if key then key=string.upper(key) end
    -- Validate/set the requested key before removing old bindings.
    local old={GetBindingKey(action)}
    if key and not SetBindingClick(key,"ForeverDBHelpButton","LeftButton") then A.Message("That key could not be bound."); return false end
    for _,k in ipairs(old) do if k~=key then SetBinding(k) end end
    SaveBindings(GetCurrentBindingSet())
    ForeverDB_Config.bindingInitialized=true
    return true
end
function A.Pin(area,x,y)
    return A.PinMap(A.Data.Maps[area],x,y)
end
function A.PinMap(map,x,y)
    if InCombatLockdown() then A.Message("Open a map pin after combat."); return false end
    if not map or map<=0 or not A.ValidPoint(x,y) then
        A.Message("No verified map destination for this location."); return false
    end
    if not (C_Map and C_Map.SetUserWaypoint and C_Map.CanSetUserWaypointOnMap and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        A.Message("Native waypoints are unavailable on this client."); return false
    end
    if not C_Map.CanSetUserWaypointOnMap(map) then A.Message("This map does not support a user waypoint."); return false end
    local ok=pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map,x/100,y/100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
    if not ok then A.Message("The client could not place this waypoint."); return false end
    -- Forever's native entry point initializes the full map and its controls.
    -- Never change WorldMapFrame strata/levels: map addons manage child layers.
    local openMap=(C_Map and C_Map.OpenWorldMap) or OpenWorldMap
    if openMap then
        local opened=pcall(openMap,map)
        if opened then
            if A.window then A.window:Hide() end
        else
            A.Message("Waypoint placed, but the map could not open. Open your map manually."); return true
        end
    else
        A.Message("Waypoint placed. Open your map to view it."); return true
    end
    A.Message("Waypoint placed. Map "..map..string.format(" at %.1f, %.1f",x,y)); return true
end
-- Use the actual binding, including when F1 belongs to another addon.
function A.AddLookupHint(tip)
    if not tip or tip.f1LookupHint then return end
    tip.f1LookupHint=true
    local key=GetBindingKey(action)
    tip:AddLine(key and ("Press "..key.." • F1-Forever") or "F1-Forever: type /f1 to set your lookup key",.35,.78,1,true)
end
-- Invert the published spec lists once, on the first item tooltip.
local gearByItem
local function tooltipGearIndex()
    local index={}
    local specs={}
    for spec in pairs(A.Data.SpecGear or {}) do specs[#specs+1]=spec end
    table.sort(specs)
    for _,spec in ipairs(specs) do
        for _,option in ipairs(A.Data.SpecGear[spec]) do
            local id=option[3]
            local tier=A.Data.TierOwner and A.Data.TierOwner[id]
            if not tier or tier==spec:match("^[^/]+"):upper() then
            local rows=index[id] or {}
            index[id]=rows
            local label=option[2]
            if option[1]:match("^Guide loadout") or option[1]=="Guide table" then
                label=option[1].." ("..label..")"
            end
            if option[6] and option[6]~="" then label=label.." ("..option[6]..")" end
            local last=rows[#rows]
            if not last or last.spec~=spec then
                last={spec=spec,labels={}}
                rows[#rows+1]=last
            end
            local duplicate=false
            for _,existing in ipairs(last.labels) do
                if existing==label then duplicate=true;break end
            end
            if not duplicate then last.labels[#last.labels+1]=label end
            end
        end
    end
    return index
end
function A.AddRankRowLine(tip,row)
    if ForeverDB_Config and ForeverDB_Config.showRankTooltips==false then return end
    if tip.f1GearItem==row.id then return end
    tip:AddLine(string.format("F1-Forever • %s • #%d %s • %.2f points (%s)",
        row.profile,row.rank,row.slot,row.points,row.model),.35,.8,1)
    tip.f1GearItem=row.id
end
local function addGearLines(tip,id)
    if ForeverDB_Config and ForeverDB_Config.showRankTooltips==false then return end
    if not A.Safe(id) or type(id)~="number" or tip.f1GearItem==id then return end
    local owner=tip==GameTooltip and tip.GetOwner and tip:GetOwner()
    local row=owner and owner.f1RankRow
    if row then
        if row.id==id then A.AddRankRowLine(tip,row) end
        return
    end
    local item=A.Data.Items[id]
    local slot=item and A.ProbeSlots[item.slot]
    if slot and ForeverDB_Config then
        local p,profile=A.EPProfile()
        if p then
            local tier=A.Data.TierOwner and A.Data.TierOwner[id]
            if tier and tier~=p.class then
                tip:AddLine("F1-Forever • "..tier:sub(1,1)..tier:sub(2):lower().." set • excluded from "..p.spec.." rankings",.62,.72,.84)
                tip.f1GearItem=id
                return
            end
            local model=A.GetView().rankHit or "all hit usable"
            local rankings=A.ProbeRankings(profile,model)
            local picks=rankings[slot] or {}
            for i=1,#picks,2 do
                if picks[i]==id then
                    tip:AddLine(string.format("F1-Forever • %s • #%d %s • %.1f points (%s)",p.spec,(i+1)/2,slot,picks[i+1],model),.35,.8,1)
                    tip.f1GearItem=id
                    return
                end
            end
            if A.ItemClassMatches(id,p.class) then
                local status=A.ProbeRankingStatus(id)
                tip:AddLine("F1-Forever • "..p.spec.." • "..status,.62,.72,.84)
                tip.f1GearItem=id
                return
            end
        end
    end
    gearByItem=gearByItem or tooltipGearIndex()
    local rows=gearByItem[id]
    if not rows then return end
    tip.f1GearItem=id
    tip:AddLine("F1-Forever • BiS guide lists",1,.82,0)
    for _,r in ipairs(rows) do
        local class,spec=r.spec:match("^([^/]+)/(.+)$")
        local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class:upper()]
        tip:AddDoubleLine(class.." • "..spec,table.concat(r.labels,", "),color and color.r or 1,
            color and color.g or 1,color and color.b or 1,1,1,1)
    end
end
local function installLookupHints()
    for _,tip in pairs({GameTooltip,ItemRefTooltip,ShoppingTooltip1,ShoppingTooltip2}) do
        if tip and tip.HookScript then
            tip:HookScript("OnTooltipCleared",function(t) t.f1LookupHint=nil;t.f1GearItem=nil;t.f1CatLink=nil end)
            local function item(t)
                local _,link=t:GetItem()
                if A.Safe(link) and type(link)=="string" then
                    local id=tonumber(link:match("item:(%d+)"))
                    if id then
                        addGearLines(t,id)
                        if t==GameTooltip or t==ItemRefTooltip then A.CatComparison(t);A.AddLookupHint(t) end
                    end
                end
            end
            -- Legacy clients expose these scripts; modern clients use TooltipDataProcessor.
            if tip.HasScript and tip:HasScript("OnTooltipSetItem") then tip:HookScript("OnTooltipSetItem",item) end
            if tip.HasScript and tip:HasScript("OnTooltipSetUnit") then
                tip:HookScript("OnTooltipSetUnit",function(t)
                    local _,unit=t:GetUnit();local guid=unit and UnitGUID(unit)
                    if A.Safe(guid) and type(guid)=="string" and (guid:match("^Creature%-") or guid:match("^Vehicle%-")) then A.AddLookupHint(t) end
                end)
            end
        end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(t,data)
            if t==GameTooltip or t==ItemRefTooltip or t==ShoppingTooltip1 or t==ShoppingTooltip2 then
                if data then addGearLines(t,data.id) end
            end
            if t==GameTooltip or t==ItemRefTooltip then A.CatComparison(t);A.AddLookupHint(t) end
        end)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(t)
            if t~=GameTooltip then return end
            local _,unit=t:GetUnit();local guid=unit and UnitGUID(unit)
            if A.Safe(guid) and type(guid)=="string" and (guid:match("^Creature%-") or guid:match("^Vehicle%-")) then A.AddLookupHint(t) end
        end)
    end
end
local function positiveID(id)
    if A.Safe(id) and type(id)=="number" and id>0 then return id end
end
local function logQuest(index)
    if not positiveID(index) then return end
    if C_QuestLog and C_QuestLog.GetInfo then
        local info=C_QuestLog.GetInfo(index)
        if info then
            if not info.isHeader then return positiveID(info.questID) end
            return
        end
    end
    if GetQuestLogTitle then
        local _,_,_,header,_,_,_,id=GetQuestLogTitle(index)
        if not header then return positiveID(id) end
    end
end
local function questModule(module)
    return module and (module==QuestObjectiveTracker or module==CampaignQuestObjectiveTracker
        or module==WorldQuestObjectiveTracker)
end
local function hoveredQuest()
    local frame
    if GetMouseFoci then frame=(GetMouseFoci() or {})[1]
    elseif GetMouseFocus then frame=GetMouseFocus() end
    if not frame then return end
    local start=frame
    local mapRowID
    for depth=1,24 do
        if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
        if frame==WorldFrame or frame==UIParent then break end
        local name=frame.GetName and frame:GetName()
        if name and name:match("^linePool%d+$") and (frame.mode=="quest" or frame.mode=="objective") then
            local q=frame.Quest
            local data=QuestieLoader and QuestieLoader._modules and QuestieLoader._modules.TrackerData
            if q and data and data.GetQuest and data.GetQuest(q.Id)==q then return positiveID(q.Id) end
            return
        end
        if name and name:match("^QuestLogTitle%d+$") and frame.GetID and FauxScrollFrame_GetOffset then
            return logQuest(frame:GetID()+FauxScrollFrame_GetOffset(QuestLogListScrollFrame))
        end
        if frame==QuestLogDetailScrollFrame then
            return logQuest(GetQuestLogSelection and GetQuestLogSelection())
        end
        local block=frame.parentBlock or frame
        if questModule(block.parentModule) then return positiveID(block.id) end
        mapRowID=mapRowID or positiveID(frame.questID)
        if frame==QuestMapFrame then return mapRowID end
        if questModule(frame) or frame==ObjectiveTrackerFrame then break end
        frame=frame.GetParent and frame:GetParent()
    end
    -- Non-interactive objective text may leave the tracker or world as mouse focus.
    if questModule(frame) or frame==ObjectiveTrackerFrame or start==WorldFrame or start==UIParent then
        for _,module in pairs({QuestObjectiveTracker,CampaignQuestObjectiveTracker,WorldQuestObjectiveTracker}) do
            if module:IsVisible() and module:IsMouseOver() then
                for _,pool in pairs(module.usedBlocks or {}) do
                    for _,block in pairs(pool) do
                        if block:IsVisible() and block:IsMouseOver() then return positiveID(block.id) end
                    end
                end
            end
        end
    end
    if (start==QuestLogFrame or start==UIParent) and QuestLogDetailScrollFrame and
        QuestLogDetailScrollFrame:IsVisible() and QuestLogDetailScrollFrame:IsMouseOver() then
        return logQuest(GetQuestLogSelection and GetQuestLogSelection())
    end
end
local function context()
    if not ready then return end
    if A.hovered then A.OpenContext(A.hovered.kind,A.hovered.id); return end
    for _,tip in ipairs({GameTooltip}) do
        if tip and tip:IsShown() and tip.GetItem then
            local _,link=tip:GetItem()
            if A.Safe(link) and type(link)=="string" then
                local id=tonumber(link:match("item:(%d+)")); if id then A.OpenContext("item",id); return end
            end
        end
    end
    local ok,questID=pcall(hoveredQuest)
    if ok and questID then A.OpenQuestOutcomes(questID);return end
    if UnitExists("mouseover") then
        local guid=UnitGUID("mouseover")
        if A.Safe(guid) and type(guid)=="string" then
            local kind,_,_,_,_,id=strsplit("-",guid)
            if (kind=="Creature" or kind=="Vehicle") and tonumber(id) then A.OpenContext("npc",tonumber(id)); return end
        end
    end
    if ItemRefTooltip and ItemRefTooltip:IsShown() and ItemRefTooltip:IsMouseOver() then
        local _,link=ItemRefTooltip:GetItem()
        if A.Safe(link) and type(link)=="string" then
            local id=tonumber(link:match("item:(%d+)")); if id then A.OpenContext("item",id); return end
        end
    end
    A.Show()
end
local help=CreateFrame("Button","ForeverDBHelpButton",UIParent)
help:SetScript("OnClick",context)
local function registerBindingSettings()
    if A.bindingSettingsPanel then return end
    local panel=CreateFrame("Frame",nil,UIParent)
    panel.name="F1 Forever";panel:Hide();A.bindingSettingsPanel=panel
    local function caption(text,y,font)
        local label=panel:CreateFontString(nil,"ARTWORK",font or "GameFontHighlight")
        label:SetPoint("TOPLEFT",16,y);label:SetWidth(520);label:SetJustifyH("LEFT");label:SetText(text)
        return label
    end
    caption("F1 Forever — Access & Keybinding",-18,"GameFontNormalLarge")
    caption("Type /f1 if F1 is already bound, then use Settings & Credits > Change keybinding.\nYou can also change the binding using the button below.",-54)
    local current=caption("",-108)
    panel:SetScript("OnShow",function() current:SetText("Current key: "..(GetBindingKey(action) or "Unbound").."  •  Browser command: /f1") end)
    local function control(text,x,callback)
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",x,-145);b:SetSize(195,28);b:SetText(text);b:SetScript("OnClick",callback)
    end
    local function dismissSettings()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    end
    control("Open F1 Forever",16,function() dismissSettings();A.Show() end)
    control("Change keybinding",225,function() dismissSettings();A.OpenBindingSettings() end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category=Settings.RegisterCanvasLayoutCategory(panel,panel.name)
        Settings.RegisterAddOnCategory(category);A.settingsCategory=category
    elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local refreshPending=false
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED" and addon==name then
        local version=GetBuildInfo()
        if not version or not version:match("^1%.60%.") then A.Message("This build is for the Forever client."); return end
        A.InitializeModel(); ready=true
        installLookupHints()
        SLASH_FOREVERDB1="/f1"
        SLASH_FOREVERDB3="/fdb"
        registerBindingSettings()
        local oldLoaded=C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("wowheadDB")
        if not oldLoaded then SLASH_FOREVERDB2="/wh" end
        SlashCmdList.FOREVERDB=function(msg)
            local command,key=msg:match("^(%S+)%s*(.-)%s*$")
            if command=="cat" then
                if key=="on" or key=="off" then ForeverDB_Config.epProfile=key=="on" and "Druid / Feral Cat / Hybrid reference" or "Off" end
                A.Message("Gear estimate • "..(ForeverDB_Config.epProfile or "My spec"))
                return
            end
            if command=="probe" then A.ItemProbe(key);return end
            if command=="bind" then A.Bind(key~="" and key or nil); return end
            if A.window and A.window:IsShown() then A.window:Hide() else A.Show() end
        end
    elseif event=="PLAYER_LOGIN" and ready then
        if not ForeverDB_Config.bindingInitialized then
            ForeverDB_Config.previousF1Action=GetBindingAction("F1")
            local existing=GetBindingAction("F1")
            if not existing or existing=="" or existing==action then A.Bind("F1")
            else ForeverDB_Config.bindingInitialized=true end
        end
        local key=GetBindingKey(action)
        A.Message(key and ("Hover an item, NPC or quest and press "..key.." • /f1 to open") or "Type /f1 to set your hover key for items, NPCs and quests")
        A.Message("Tooltips score gear upgrades with WoWSims weights • Discord @sarcasm")
    elseif ready and A.window and A.window:IsShown() and not refreshPending then
        refreshPending=true
        C_Timer.After(.2,function() refreshPending=false; A.Refresh() end)
    end
end)
