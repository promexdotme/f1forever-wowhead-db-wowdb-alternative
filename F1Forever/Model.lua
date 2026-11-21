local _, A = ...
local D = A.Data
A.index = {}
function A.Key(kind,id) return kind .. ":" .. tostring(id) end
function A.Entity(kind,id) return D[A.kindTable[kind] or ""] and D[A.kindTable[kind]][id] end
function A.Name(kind,id)
    local e = A.Entity(kind,id)
    return e and e.name or (kind .. " #" .. tostring(id))
end
function A.Item(id)
    local e = D.Items[id] or {}
    local name,link,quality,_,_,_,_,_,_,icon
    if C_Item and C_Item.GetItemInfo then name,link,quality,_,_,_,_,_,_,icon = C_Item.GetItemInfo(id) end
    return name or e.name or ("Item #"..id), link or ("item:"..id), quality or e.quality or 1, icon or e.icon or 134400
end
function A.Label(kind,id)
    if kind=="item" then
        local name,_,q = A.Item(id)
        return "|c" .. (A.colors[q+1] or "ffffffff") .. name .. "|r"
    end
    return A.Name(kind,id)
end
-- Decode a single edge as scalar values. Index stores ordinals, not edge tables.
function A.Edge(n)
    local g=D.Graph
    if not n or n<1 or n>g.count then return end
    local c=g.chunks[math.floor((n-1)/g.chunkEdges)+1]
    local p=((n-1)%g.chunkEdges)*g.stride+1; local w=g.words
    return w[c[p]],c[p+1],w[c[p+2]],c[p+3],w[c[p+4]],w[c[p+5]]
end
function A.AllEdges()
    local n=0
    return function() n=n+1; if n<=D.Graph.count then return A.Edge(n) end end
end
function A.InitializeModel()
    ForeverDB_Config = ForeverDB_Config or {}
    if ForeverDB_Config.epProfile == nil then ForeverDB_Config.epProfile = "My spec" end
    if ForeverDB_Config.showAlliance == nil then ForeverDB_Config.showAlliance = true end
    if ForeverDB_Config.showHorde == nil then ForeverDB_Config.showHorde = true end
    ForeverDB_Favorites = ForeverDB_Favorites or {nextID=2,lists={{id=1,name="My Favorites",entries={}}}}
    A.index={}
    A.professionCatalogs={}
    A.questLinks=nil
    for n=1,D.Graph.count do
        local ft,fi,tt,ti=A.Edge(n)
        local a,b=A.Key(ft,fi),A.Key(tt,ti)
        A.index[a]=A.index[a] or {}; table.insert(A.index[a],n)
        if a~=b then A.index[b]=A.index[b] or {}; table.insert(A.index[b],n) end
    end
end
function A.RelationMatches(n,kind,id,filter)
    local ft,fi,tt,ti,relation=A.Edge(n)
    local incoming=tt==kind and ti==id
    if filter=="All" then return true end
    if filter=="Drops" then return relation=="Drops" end
    if filter=="Vendors" then return relation=="Sells" end
    if filter=="Contained in" then return relation=="Contains" and incoming end
    if filter=="Contains" then return relation=="Contains" and not incoming end
    if filter=="Quests" then return ft=="quest" or tt=="quest" end
    if filter=="Crafted by" then return relation=="Crafts" and incoming end
    if filter=="Creates" then return relation=="Crafts" and not incoming end
    if filter=="Reagents" then return relation=="Reagent" and incoming end
    if filter=="Used for" then return relation=="Reagent" and not incoming end
    if filter=="Learned from" then return relation=="Teaches" or relation=="CraftingTeacher" end
    return false
end
function A.RelationshipTabs(kind,id)
    local groups={"All","Drops","Vendors","Contained in","Contains","Quests","Crafted by","Creates","Used for","Reagents","Learned from"}
    local labels=kind=="item" and {Drops="Dropped by",Vendors="Sold by",Quests="Quest links",["Crafted by"]="Created by",["Used for"]="Reagent for",["Learned from"]="Taught by"} or {}
    local out={}
    for _,group in ipairs(groups) do
        local count=0
        for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do if A.RelationMatches(n,kind,id,group) then count=count+1 end end
        if count>0 then out[#out+1]={value=group,label=(labels[group] or group).." ("..count..")",count=count} end
    end
    return out
end
function A.RelationLabel(relation,incoming)
    local labels={CraftingTeacher={"Teaches crafting of: ","Recipe taught by: "},Drops={"Drops: ","Dropped by: "},Sells={"Sells: ","Sold by: "},Contains={"Contains: ","Contained in: "},Rewards={"Rewards: ","Quest reward: "},Starts={"Starts quest: ","Quest giver: "},Ends={"Completes quest: ","Turn in to: "},Crafts={"Creates: ","Crafted by: "},Reagent={"Used for: ","Reagent: "},Teaches={"Teaches: ","Learned from: "}}
    local pair=labels[relation]; return pair and pair[incoming and 2 or 1] or (relation..": ")
end
function A.ValidPoint(x,y)
    return type(x)=="number" and type(y)=="number" and x==x and y==y and x>=0 and x<=100 and y>=0 and y<=100
end
function A.NPCLocation(id,mapID)
    local e=A.Entity("npc",id); if not e then return end
    local zones={}; for area in pairs(e.spawns or {}) do zones[#zones+1]=area end; table.sort(zones)
    for _,area in ipairs(zones) do
        for _,p in ipairs(e.spawns[area]) do if A.ValidPoint(p[1],p[2]) and D.Maps[area] and (not mapID or D.Maps[area]==mapID) then return area,p[1],p[2] end end
    end
end
function A.NameMatches(name,query,id)
    query=string.lower((query or ""):match("^%s*(.-)%s*$"))
    if query=="" then return true end
    if tonumber(query) then return id==tonumber(query) end
    name=string.lower(name or "")
    for term in query:gmatch("%S+") do if not name:find(term,1,true) then return false end end
    return true
end
function A.Search(kind,query,gear)
    local found={}; query=string.lower(query or "")
    for id,e in pairs(D[A.kindTable[kind]] or {}) do
        if (not gear or (e.slot or 0)>0) and A.NameMatches(e.name,query,id) then
            found[#found+1]={id=id,kind=kind,name=e.name}
        end
    end
    table.sort(found,function(a,b) if a.name==b.name then return a.id<b.id end return a.name<b.name end)
    return found
end
function A.NewList(name)
    name=(name or ""):match("^%s*(.-)%s*$")
    if name=="" then return end
    local s=ForeverDB_Favorites
    local l={id=s.nextID,name=name:sub(1,60),entries={}}
    s.nextID=s.nextID+1; s.lists[#s.lists+1]=l
    return l
end
function A.ToggleFavorite(list,kind,id)
    local key=A.Key(kind,id)
    if list.entries[key] then list.entries[key]=nil; return false end
    list.entries[key]={kind=kind,id=id,status="Wanted"}; return true
end
function A.QuestDone(id)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) or false
end
function A.ChainProgress(chain)
    local done,total=0,0
    for _,step in ipairs(chain.steps) do total=total+1; if A.QuestDone(step.id) then done=done+1 end end
    return done,total
end
function A.FactionVisible(faction)
    if faction=="Alliance" or faction=="A" then return ForeverDB_Config.showAlliance ~= false end
    if faction=="Horde" or faction=="H" then return ForeverDB_Config.showHorde ~= false end
    return true -- Shared and unknown records remain visible.
end
function A.QuestVisible(id)
    local q=A.Data.Quests[id]
    local faction=q and q.faction
    if not faction or faction=="Unknown" then faction=((A.Data.QuestGuide or {})[id] or {}).faction end
    return q and A.FactionVisible(faction) and not (ForeverDB_Config.hideCompletedQuests and A.QuestDone(id))
end
-- Class capability only: no spec/stat, level or currently trained-skill assumptions.
A.LootClasses={{"WARRIOR","Warrior",1},{"PALADIN","Paladin",2},{"HUNTER","Hunter",4},
    {"ROGUE","Rogue",8},{"PRIEST","Priest",16},{"SHAMAN","Shaman",64},
    {"MAGE","Mage",128},{"WARLOCK","Warlock",256},{"DRUID","Druid",1024}}
function A.LootClassFilter()
    return ForeverDB_Config.journalClass or "SELF"
end
function A.SetLootClassFilter(value)
    local valid=value=="SELF" or value=="ALL"
    for _,c in ipairs(A.LootClasses) do if value==c[1] then valid=true end end
    ForeverDB_Config.journalClass=valid and value or "SELF"
end
function A.ItemClassMatches(id,selection)
    selection=selection or A.LootClassFilter()
    if selection=="ALL" then return true end
    if selection=="SELF" then if not UnitClass then return true end;local _,token=UnitClass("player");selection=token end
    local mask=(D.ItemClasses or {})[id]
    if mask==nil then return true end
    for _,c in ipairs(A.LootClasses) do
        if c[1]==selection then return math.floor(mask/c[3])%2==1 end
    end
    return true
end
function A.Matches(kind,id,filter,quality,slot)
    local e=A.Entity(kind,id)
    if not e then return false end
    if kind=="quest" and not A.QuestVisible(id) then return false end
    if kind=="npc" and not A.FactionVisible(e.faction) then return false end
    if kind=="item" then
        if quality and quality~="All qualities" and (e.quality or 1)~=quality then return false end
        if slot and slot~="All slots" and (e.slot or 0)~=slot then return false end
        if filter=="Gear" then return (e.slot or 0)>0 end
        if filter=="Recipes" then return (e.cls or e.class)==9 end
    end
    if filter=="Completed" then return A.QuestDone(id) end
    if filter=="Not completed" then return not A.QuestDone(id) end
    local relations={Drops="Drops",Vendors="Sells",Containers="Contains",Quests="Rewards"}
    local wanted=relations[filter]
    if filter=="Quests" and (kind=="npc" or kind=="object") then
        for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do local _,_,tt=A.Edge(n); if tt=="quest" then return true end end
        return false
    end
    if wanted then
        for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do local _,_,_,_,rel=A.Edge(n); if rel==wanted then return true end end
        return false
    end
    return true
end

-- Full profession reference from existing graph, independent of leveling routes.
-- A seller qualifies through a recorded reagent sale or an explicit profession supplies title.
local supplyCache={}
function A.ProfessionSuppliers(profession)
    if supplyCache[profession] then return supplyCache[profession] end
    local sellers,materials={},{}
    for _,r in pairs(D.Recipes) do
        if profession=="All" or r.profession==profession then
            for item in pairs(r.reagents or {}) do materials[item]=true end
        end
    end
    for item in pairs(materials) do
        for _,edge in ipairs(A.index[A.Key("item",item)] or {}) do
            local ft,fi,tt,ti,k=A.Edge(edge)
            if k=="Sells" and ft=="npc" and tt=="item" and ti==item then sellers[fi]=true end
        end
    end
    for id,n in pairs(D.NPCs) do
        local title=n.title or ""
        if title:find("Supplies",1,true) and (profession=="All" or title:find(profession,1,true)) then sellers[id]=true end
    end
    supplyCache[profession]=sellers
    return sellers
end

function A.ProfessionNPCArea(npc,mapID)
    if not npc then return end
    if npc.zone and D.Maps[npc.zone]==mapID and mapID then return npc.zone end
    for area in pairs(npc.spawns or {}) do
        if D.Maps[area]==mapID and mapID then return area end
    end
end

function A.ProfessionCatalog(profession)
    A.professionCatalogs=A.professionCatalogs or {}
    if A.professionCatalogs[profession] then return A.professionCatalogs[profession] end
    local c={recipes={},manuals={},items={},trainers={},vendors={},quests={}}
    for id,r in pairs(D.Recipes) do if r.profession==profession then c.recipes[id]=true end end
    local membership=(D.ProfessionIndexes or {})[profession] or {}
    local kinds={recipes="recipe",manuals="item",items="item",trainers="npc",quests="quest"}
    for group,ids in pairs(membership) do
        for _,id in ipairs(ids) do if A.Entity(kinds[group],id) then c[group][id]=true end end
    end
    for ft,fi,tt,ti,k in A.AllEdges() do
        if tt=="recipe" and c.recipes[ti] then
            if k=="Teaches" and ft=="npc" then c.trainers[fi]=true
            elseif k=="Teaches" and ft=="item" then c.manuals[fi]=true
            elseif ft=="quest" then c.quests[fi]=true end
        elseif ft=="recipe" and c.recipes[fi] then
            if k=="Crafts" and tt=="item" then c.items[ti]=true
            elseif tt=="quest" then c.quests[ti]=true end
        end
    end
    for id,n in pairs(D.NPCs) do if n.trainerProfession==profession then c.trainers[id]=true end end
    for id in pairs(c.manuals) do
        for _,n in ipairs(A.index[A.Key("item",id)] or {}) do
            local ft,fi,tt,ti,k=A.Edge(n)
            if tt=="item" and ti==id then
                if k=="Sells" and ft=="npc" then c.vendors[fi]=true
                elseif k=="Rewards" and ft=="quest" then c.quests[fi]=true end
            elseif ft=="item" and fi==id and k=="Starts" and tt=="quest" then c.quests[ti]=true end
        end
    end
    -- Supplement graph-backed quest membership with explicitly linked guide unlocks.
    local extra=(D.SecondaryGuides or {})[profession]
    for _,entry in ipairs(extra and extra.training or {}) do
        for _,ref in ipairs(entry.refs or {}) do if ref.kind=="quest" and D.Quests[ref.id] then c.quests[ref.id]=true end end
    end
    for id in pairs(A.ProfessionSuppliers(profession)) do c.vendors[id]=true end
    A.professionCatalogs[profession]=c
    return c
end

-- Typed quest dependencies. Availability restrictions are deliberately not unlocks.
function A.BuildQuestLinks()
    local before,after={},{}
    local seen={}
    local function add(parent,child,kind)
        if type(parent)~="number" or parent<=0 or type(child)~="number" or child<=0 then return end
        local key=parent..":"..child..":"..kind
        if seen[key] then return end;seen[key]=true
        before[child]=before[child] or {};after[parent]=after[parent] or {}
        before[child][#before[child]+1]={id=parent,kind=kind}
        after[parent][#after[parent]+1]={id=child,kind=kind}
    end
    for id,q in pairs(D.Quests) do
        for _,p in ipairs(q.allPrerequisites or {}) do add(p,id,"ALL required") end
        for _,p in ipairs(q.anyPrerequisites or {}) do add(p,id,#q.anyPrerequisites>1 and "ANY one" or "Requires") end
        for _,child in ipairs(q.childQuests or {}) do
            local has=false;for _,r in ipairs(after[id] or {}) do if r.id==child then has=true end end
            if not has then add(id,child,"Recorded unlock") end
        end
        if q.parentQuest then add(q.parentQuest,id,"Must be active") end
        if q.availableStartingWith then add(q.availableStartingWith,id,"Active or completed") end
        if q.breadcrumbForQuestId then add(id,q.breadcrumbForQuestId,"Optional breadcrumb") end
        for _,p in ipairs(q.breadcrumbs or {}) do add(p,id,"Optional breadcrumb") end
    end
    for _,index in ipairs({before,after}) do for _,rows in pairs(index) do table.sort(rows,function(a,b) if a.id==b.id then return a.kind<b.kind end;return a.id<b.id end) end end
    A.questLinks={before=before,after=after}
    return A.questLinks
end
function A.QuestTrace(id,limit)
    local links=A.questLinks or A.BuildQuestLinks()
    limit=limit or 60
    local out={before={},after={},truncated=false,cycle=false,maxDepth=0}
    local count=0
    local function collect(index,target,postorder)
        local seen={[id]=true};local path={[id]=true}
        local function visit(current,depth)
            for _,edge in ipairs(index[current] or {}) do
                if path[edge.id] then out.cycle=true
                elseif not seen[edge.id] then
                    if count>=limit or depth>12 then out.truncated=true
                    else
                        seen[edge.id]=true;count=count+1;path[edge.id]=true
                        local row={id=edge.id,depth=depth,kind=edge.kind,missing=not D.Quests[edge.id]}
                        out.maxDepth=math.max(out.maxDepth,depth)
                        if not postorder then target[#target+1]=row end
                        visit(edge.id,depth+1)
                        if postorder then target[#target+1]=row end
                        path[edge.id]=nil
                    end
                end
            end
        end
        visit(id,1)
    end
    collect(links.before,out.before,true);collect(links.after,out.after,false)
    return out
end
-- Walk downstream independently so a long prerequisite chain cannot consume the outcome budget.
function A.QuestOutcomes(id)
    local after=(A.questLinks or A.BuildQuestLinks()).after
    local result={ends={},next={},grants={},limited=false}
    local queue,seen={id},{[id]=true}
    local nextSeen={}
    for _,edge in ipairs(after[id] or {}) do
        if not nextSeen[edge.id] then
            nextSeen[edge.id]=true
            result.next[#result.next+1]=edge
        end
    end
    local pos=1
    while pos<=#queue do
        local qid=queue[pos];pos=pos+1
        local edges=after[qid]
        if not edges or #edges==0 then result.ends[#result.ends+1]=qid end
        for _,edge in ipairs(edges or {}) do
            if not seen[edge.id] then
                if #queue>=60 then result.limited=true
                else seen[edge.id]=true;queue[#queue+1]=edge.id end
            end
        end
    end
    for _,entries in pairs(D.ClassQuestUnlocks or {}) do
        for _,entry in ipairs(entries) do
            if seen[entry.questID] and entry.spellID then result.grants[#result.grants+1]=entry end
        end
    end
    return result
end
function A.DungeonQuestRoots(name)
    local rows=(D.DungeonQuests or {})[name] or {}
    local direct,ancestors={},{}
    for _,id in ipairs((D.DungeonQuestTargets or {})[name] or {}) do direct[id]=true end
    for _,id in ipairs(rows) do
        ancestors[id]={}
        local trace=A.QuestTrace(id)
        if not trace.truncated and not trace.cycle then
            for _,step in ipairs(trace.before) do ancestors[id][step.id]=true end
        end
    end
    local result={}
    for _,id in ipairs(rows) do
        local preparation=false
        if not direct[id] then
            for _,target in ipairs(rows) do
                if target~=id and ancestors[target][id] and not ancestors[id][target] then preparation=true;break end
            end
        end
        if not preparation then result[#result+1]=id end
    end
    return result
end
function A.QuestItemRewards(id)
    local ids,seen={},{}
    for _,n in ipairs(A.index[A.Key("quest",id)] or {}) do
        local ft,fi,tt,ti,k=A.Edge(n)
        if ft=="quest" and fi==id and tt=="item" and k=="Rewards" and not seen[ti] then seen[ti]=true;ids[#ids+1]=ti end
    end
    table.sort(ids);return ids
end

-- Progress is character state, never inferred from the selected browser target.
function A.QuestActive(id)
    if C_QuestLog and C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id)==true end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return (C_QuestLog.GetLogIndexForQuestID(id) or 0)>0 end
    return false
end
local questClasses={{1,"Warrior","WARRIOR"},{2,"Paladin","PALADIN"},{4,"Hunter","HUNTER"},{8,"Rogue","ROGUE"},{16,"Priest","PRIEST"},{64,"Shaman","SHAMAN"},{128,"Mage","MAGE"},{256,"Warlock","WARLOCK"},{1024,"Druid","DRUID"}}
function A.QuestClassLabel(q)
    local mask=q and q.classMask
    if type(mask)~="number" or mask<=0 then return nil end
    local names={};local known=0
    for _,class in ipairs(questClasses) do
        if math.floor(mask/class[1])%2==1 then names[#names+1]=class[2];known=known+class[1] end
    end
    if known~=mask then names[#names+1]="Other class restriction" end
    if #names==1 then return names[1].." only" end
    return "Classes: "..table.concat(names,", ")
end
function A.QuestClassAllowed(q)
    if not q or not q.classMask or q.classMask<=0 or not UnitClass then return true end
    local _,token=UnitClass("player")
    for _,class in ipairs(questClasses) do if class[3]==token then return math.floor(q.classMask/class[1])%2==1 end end
    return true
end
function A.QuestProgress(id)
    if A.QuestActive(id) then return "In your quest log" end
    if A.QuestDone(id) then return "Completed" end
    local q=D.Quests[id]
    if not q or not A.FactionVisible(q.faction) then return "Not completed" end
    if not A.QuestClassAllowed(q) then return "Different class" end
    for _,p in ipairs(q.allPrerequisites or {}) do if p<=0 or not A.QuestDone(p) then return "Not completed" end end
    if #(q.anyPrerequisites or {})>0 then
        local satisfied=false
        for _,p in ipairs(q.anyPrerequisites) do if p>0 and A.QuestDone(p) then satisfied=true end end
        if not satisfied then return "Not completed" end
    end
    for _,p in ipairs(q.exclusiveTo or {}) do if A.QuestDone(p) or A.QuestActive(p) then return "Alternative branch" end end
    if q.parentQuest and not A.QuestActive(q.parentQuest) then return "Not completed" end
    if q.availableStartingWith and not (A.QuestActive(q.availableStartingWith) or A.QuestDone(q.availableStartingWith)) then return "Not completed" end
    for _,key in ipairs({"unavailableWhenQuestActiveOrComplete","disabledByQuest"}) do
        local other=q[key];if other and (A.QuestActive(other) or A.QuestDone(other)) then return "Restricted by another quest" end
    end
    if q.availableUntilCompleted and A.QuestDone(q.availableUntilCompleted) then return "Restricted by another quest" end
    local links=A.questLinks or A.BuildQuestLinks()
    for _,edge in ipairs(links.before[id] or {}) do
        if edge.kind=="Recorded unlock" and not A.QuestDone(edge.id) then return "Not completed" end
    end
    return "Next recorded step"
end
-- Count direct mandatory requirements, not every optional/alternative ancestor.
function A.UnmetQuestRequirements(id)
    local q=D.Quests[id] or {};local count=0;local known=true;local seen={}
    for _,pid in ipairs(q.allPrerequisites or {}) do
        if not seen[pid] then
            seen[pid]=true
            if pid<=0 or not D.Quests[pid] then known=false
            elseif not A.QuestDone(pid) then count=count+1 end
        end
    end
    if #(q.anyPrerequisites or {})>0 then
        local satisfied=false;local groupKnown=true
        for _,pid in ipairs(q.anyPrerequisites) do
            if pid>0 and A.QuestDone(pid) then satisfied=true end
            if pid<=0 or not D.Quests[pid] then groupKnown=false end
        end
        if not satisfied then
            if groupKnown then count=count+1 else known=false end
        end
    end
    return count,known
end
