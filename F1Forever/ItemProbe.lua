local _, A = ...
local baseline, request = nil, 0

local function read(fn, ...)
    if type(fn) ~= "function" then return nil, "API unavailable" end
    local ok, value, second = pcall(fn, ...)
    if not ok then return nil, "API call failed" end
    if not A.Safe(value) or not A.Safe(second) then return nil, "restricted" end
    if value == nil then return nil, "no value returned" end
    return value, nil, second
end

-- Classic clients can render a hyperlink even when the structured tooltip API is absent.
local reader
local function renderedLines(link)
    if not CreateFrame or not UIParent then return {} end
    if not reader then
        reader=CreateFrame("GameTooltip","F1ForeverProbeReader",UIParent,"GameTooltipTemplate")
    end
    reader:SetOwner(UIParent,"ANCHOR_NONE")
    reader:ClearLines()
    local ok=pcall(reader.SetHyperlink,reader,link)
    local lines={}
    if ok then
        for index=1,reader:NumLines() do
            local parts={}
            for _,side in ipairs({"Left","Right"}) do
                local region=_G["F1ForeverProbeReaderText"..side..index]
                if region and region:IsShown() then
                    local value=read(region.GetText,region)
                    if type(value)=="string" and value~="" then parts[#parts+1]=value end
                end
            end
            if #parts>0 then lines[#lines+1]=table.concat(parts,"  ") end
        end
    end
    reader:Hide()
    return lines
end

local function inspect(link)
    local item = {link=link, stats={}, lines={}}
    local stats, status = read(C_Item and C_Item.GetItemStats or GetItemStats, link)
    item.statStatus = status
    if not status and type(stats)~="table" then item.statStatus="unexpected response" end
    if type(stats) == "table" then
        for key, value in pairs(stats) do
            if A.Safe(key) and A.Safe(value) and type(key)=="string" and type(value)=="number" then
                item.stats[key] = value
            end
        end
    end
    item.spell, item.spellStatus, item.spellID = read(C_Item and C_Item.GetItemSpell or GetItemSpell, link)
    local tip
    tip, item.tipStatus = read(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
    if tip and A.Safe(tip.lines) and type(tip.lines)=="table" then
        for _, line in ipairs(tip.lines) do
            if A.Safe(line) then
                local parts = {}
                for _, key in ipairs({"leftText","rightText"}) do
                    local value = line[key]
                    if A.Safe(value) and type(value)=="string" and value~="" then parts[#parts+1]=value end
                end
                if #parts>0 then item.lines[#item.lines+1]=table.concat(parts,"  ") end
            end
        end
    end
    if #item.lines==0 then
        item.lines=renderedLines(link)
        if #item.lines>0 then item.tipStatus=nil end
    end
    if #item.lines==0 and not item.tipStatus then item.tipStatus="no readable lines" end
    return item
end

local function report(item, first)
    A.Message((first and "B • " or "A • ")..item.link)
    local keys, seen = {}, {}
    for key in pairs(item.stats) do keys[#keys+1]=key;seen[key]=true end
    if first then
        for key in pairs(first.stats) do if not seen[key] then keys[#keys+1]=key end end
    end
    table.sort(keys)
    if item.statStatus or not next(item.stats) then print("Stats • "..(item.statStatus or "no numeric fields returned")) end
    for _,key in ipairs(keys) do
        local value = item.stats[key]
        local label = type(_G[key])=="string" and _G[key] or key
        local line = label.."  "..(value or "—")
        if first then
            local old = first.stats[key]
            line = label.."  "..(old or "—").." → "..(value or "—")
            if old and value then line=line..string.format(" (%+g)",value-old) end
        end
        print(line)
    end
    print("Item spell • "..(item.spell and (item.spell.." (#"..tostring(item.spellID)..")") or item.spellStatus))
    print("Client tooltip • "..(#item.lines>0 and table.concat(item.lines,"\n") or item.tipStatus or "no readable lines"))
end

-- Developer collection is opt-in. Save base items separately from the hover probe log.
local activeScan,lastScan
local function currentProbeCache()
    local _,build=GetBuildInfo()
    local cache=ForeverDB_Config.shoulderProbeCache
    if not cache or tostring(cache.build)~=tostring(build) then
        cache={build=build,items={}}
        ForeverDB_Config.shoulderProbeCache=cache
    end
    cache.unresolved=cache.unresolved or {}
    return cache
end
local function scanGear(onlyShoulders)
    if activeScan then A.Message("Gear scan already running.");return end
    local cache=currentProbeCache()
    local ids={}
    for id,record in pairs(A.Data.Items) do
        local old=cache.items[id]
        if A.ProbeSlots[record.slot] and (not onlyShoulders or record.slot==3) and (record.required or 0)<=60 and (not old or time()-old.at>=30*86400) then
            ids[#ids+1]=id
        end
    end
    table.sort(ids,function(a,b)
        local x,y=A.Data.Items[a],A.Data.Items[b]
        if (x.quality or 0)~=(y.quality or 0) then return (x.quality or 0)>(y.quality or 0) end
        return a>b
    end)
    local scan={total=#ids,saved=0,missing=0,noName=0,noStats=0,noTooltip=0,retriedSaved=0,recovered=0,started=GetTime()}
    activeScan=scan;lastScan=scan
    local pos,pending=1,{}
    -- Keep a small window of item requests in flight. Each tick does at most
    -- one tooltip inspection, including when several server responses arrive together.
    local function tick()
        if activeScan~=scan then return end
        if InCombatLockdown and InCombatLockdown() then
            scan.combat=true;C_Timer.After(1,tick);return
        end
        scan.combat=false
        local delay=GetFramerate and GetFramerate()<35 and .5 or .18
        local now=GetTime()
        local id,entry
        if ids[pos] and #pending<4 then
            id=ids[pos];pos=pos+1
        else
            for i,waiting in ipairs(pending) do
                if waiting.retryAt<=now then
                    entry=table.remove(pending,i);id=entry.id;break
                end
            end
        end
        if id then
            local link="item:"..id
            local name,nameStatus=read(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
            if type(name)~="string" or name=="" then name=nil end
            local sample=name and inspect(link)
            if sample and not sample.statStatus and #sample.lines>0 then
                cache.items[id]={at=time(),item=sample}
                if entry then scan.retriedSaved=scan.retriedSaved+1 end
                if cache.unresolved[id] then scan.recovered=scan.recovered+1;cache.unresolved[id]=nil end
                scan.saved=scan.saved+1
            elseif not entry or now<entry.deadline then
                if not entry then
                    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
                    entry={id=id,started=now,deadline=now+4,attempts=0}
                end
                entry.attempts=entry.attempts+1
                entry.retryAt=now+.65;pending[#pending+1]=entry
            else
                local failure={at=time(),attempts=entry.attempts+1,elapsedSeconds=math.floor(now-entry.started+.5)}
                if not name then
                    failure.noName=nameStatus or "empty name"
                    scan.noName=scan.noName+1
                else
                    failure.noStats=sample.statStatus
                    failure.noTooltip=sample.tipStatus
                    if failure.noStats then scan.noStats=scan.noStats+1 end
                    if failure.noTooltip then scan.noTooltip=scan.noTooltip+1 end
                end
                cache.unresolved[id]=failure
                scan.missing=scan.missing+1
            end
        end
        if not ids[pos] and #pending==0 then
            activeScan=nil;scan.finished=GetTime()
            A.Message(string.format("Gear scan finished. %d saved, %d unresolved.",scan.saved,scan.missing))
            return
        end
        C_Timer.After(delay,tick)
    end
    A.Message(#ids.." gear items queued. /f1 probe stop pauses collection.")
    tick()
end

function A.ItemProbe(arg)
    arg=(arg or ""):match("^%s*(.-)%s*$")
    if arg=="shoulders" or arg=="gear" then scanGear(arg=="shoulders");return end
    if arg=="status" then
        local scan=activeScan or lastScan
        local cached=0
        local current=ForeverDB_Config.shoulderProbeCache
        local _,build=GetBuildInfo()
        if current and tostring(current.build)==tostring(build) then
            for _ in pairs(current.items) do cached=cached+1 end
        end
        if not scan then
            local names,stats,tips=0,0,0
            if current and tostring(current.build)==tostring(build) then
                for _,f in pairs(current.unresolved or {}) do
                    if f.noName then names=names+1 end
                    if f.noStats then stats=stats+1 end
                    if f.noTooltip then tips=tips+1 end
                end
            end
            A.Message(string.format("Scan idle • %d cached • outstanding: no name %d, no stats %d, no tooltip %d",cached,names,stats,tips))
            return
        end
        local done=scan.saved+scan.missing
        local elapsed=math.max(.01,(scan.finished or GetTime())-scan.started)
        local remaining=scan.total-done
        local status=activeScan and (scan.combat and "Paused in combat" or "Scanning") or (remaining==0 and "Finished" or "Stopped")
        local eta=""
        if activeScan then
            eta=done>=5 and string.format(" • %.0f/min • ~%d min left",done*60/elapsed,math.ceil(remaining*elapsed/done/60)) or " • estimating time"
        end
        A.Message(string.format("%s • %d/%d checked • %d remaining • %d saved • %d unresolved%s • %d cached total",
            status,done,scan.total,remaining,scan.saved,scan.missing,eta,cached))
        A.Message(string.format("This run • no name %d • no stats %d • no tooltip %d • saved after retry %d • previously unresolved now saved %d",
            scan.noName,scan.noStats,scan.noTooltip,scan.retriedSaved,scan.recovered))
        return
    end
    if arg=="stop" then
        if activeScan then activeScan.finished=GetTime();activeScan=nil end
        A.Message("Scan stopped. Completed items are cached.");return
    end
    if arg=="reset" then request=request+1;baseline=nil;A.Message("Item comparison cleared.");return end
    local link
    local recipeID
    if arg=="" then
        if A.hovered and A.hovered.kind=="recipe" then recipeID=A.hovered.id
        elseif GameTooltip and GameTooltip:IsShown() then
            local _,hovered=GameTooltip:GetItem()
            if A.Safe(hovered) then link=hovered end
        end
    elseif arg:match("^%d+$") then
        local id=tonumber(arg)
        if not A.Data.Items[id] and A.Data.Recipes and A.Data.Recipes[id] then recipeID=id
        else link="item:"..id end
    elseif arg:match("^spell:%d+$") then recipeID=tonumber(arg:match("%d+"))
    elseif arg:match("|Hitem:%d+") or arg:match("^item:%d+") then link=arg end
    if recipeID then link="spell:"..recipeID end
    if not link then A.Message("Hover a database recipe or enter an item link or ID.");return end
    request=request+1
    local serial=request
    local started=GetTime()
    local attempts=0
    local deadline=started+4
    local baseID=tonumber(link:match("^item:(%d+)$"))
    if baseID and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(baseID) end
    local function ready()
        if request~=serial then return end
        attempts=attempts+1
        local name,status,resolved
        local item
        if recipeID then
            item={link=link,stats={},lines=renderedLines(link),statStatus="recipe tooltip",spellStatus="recipe"}
        else
            name,status,resolved=read(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
            item=inspect(link)
        end
        local title=item.lines[1]
        local readable=title and title~=RETRIEVING_ITEM_INFO and title~=RETRIEVING_DATA and title~="Retrieving item information"
        if not readable or (not recipeID and (not name or item.statStatus)) then
            if GetTime()<deadline then C_Timer.After(.65,ready);return end
        end
        if not readable then
            if baseID then
                currentProbeCache().unresolved[baseID]={at=time(),manual=true,attempts=attempts,
                    elapsedSeconds=math.floor(GetTime()-started+.5),noName=not name and (status or "empty name") or nil,
                    noStats=item.statStatus,noTooltip=item.tipStatus or "no readable tooltip"}
            end
            A.Message(link.." unavailable • "..(item.tipStatus or "no readable tooltip")..(status and (" • "..status) or ""))
            return
        end
        if recipeID then
            A.Message("Recipe preview saved • spell "..recipeID)
        elseif baseID and A.Data.Items[baseID] and name and not item.statStatus then
            local cache=currentProbeCache()
            cache.items[baseID]={at=time(),item=item}
            cache.unresolved[baseID]=nil
        elseif not name or item.statStatus then
            A.Message("Partial item observation saved • "..(status or item.statStatus or "missing data"))
        end
        if resolved then
            local reported={}
            for k,v in pairs(item) do reported[k]=v end
            item=reported;item.link=resolved
        end
        local samples=ForeverDB_Config.itemProbeLog or {}
        ForeverDB_Config.itemProbeLog=samples
        local _, build=GetBuildInfo()
        samples[#samples+1]={at=time(), build=build, input=link, item=item, baselineLink=baseline and baseline.link}
        if #samples>100 then table.remove(samples,1) end
        if recipeID then print(table.concat(item.lines,"\n"));return end
        report(item,baseline)
        if not baseline then baseline=item;A.Message("A saved. Probe another item for B. /f1 probe reset clears A.") end
    end
    ready()
end
