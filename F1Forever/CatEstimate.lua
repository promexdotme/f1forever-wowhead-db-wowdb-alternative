local _, A = ...
local profiles=A.Data.StatProfiles
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
    INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_2HWEAPON={16},
    INVTYPE_WEAPON={16},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},
    INVTYPE_HOLDABLE={17},INVTYPE_RELIC={18},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18}}
local trees={DRUID={"Balance","Feral","Restoration"},HUNTER={"Beast Mastery","Marksmanship","Survival"},PALADIN={"Holy","Protection","Retribution"},
    PRIEST={"Discipline","Holy","Shadow"},ROGUE={"Assassination","Combat","Subtlety"},
    SHAMAN={"Elemental","Enhancement","Restoration"},WARRIOR={"Arms","Fury","Protection"}}
local preferred={Balance="P1",Survival="Weave",Retribution="Unsealed Wrath",Combat="Combat Sinister",
    Discipline="Disc Raid Healing",Holy="Holy Raid Healing",Protection="Pre-BiS (Defense Cap)"}
local options={}
local talentCache={}
local specEvents=CreateFrame("Frame")
specEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
specEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
specEvents:SetScript("OnEvent",function() talentCache={} end)
for name in pairs(profiles) do options[#options+1]=name end
table.sort(options)
function A.EPOptions()
    local list={"My spec","Off"}
    for _,name in ipairs(options) do list[#list+1]=name end
    return list
end
function A.EPProfile(selection)
    selection=selection or ForeverDB_Config.epProfile or "My spec"
    if selection~="My spec" then return profiles[selection],selection end
    local _,class=UnitClass("player")
    if not trees[class] then return nil,"No Forever preset" end
    local highest,best=0,nil
    if talentCache[class] then best=talentCache[class] else
    for tree=1,3 do
        local points=0
        if GetNumTalents and GetTalentInfo then
            for i=1,(GetNumTalents(tree) or 0) do
                local rank=select(5,GetTalentInfo(tree,i))
                points=points+(tonumber(rank) or 0)
            end
        end
        if points>highest then highest,best=points,tree elseif points==highest then best=nil end
    end
    talentCache[class]=best
    end
    if not best then return nil,"Choose a spec in Settings" end
    local spec=trees[class][best]
    if spec=="Feral" then
        local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
        local form=GetShapeshiftFormID and GetShapeshiftFormID()
        if role=="TANK" or form==5 or form==8 then spec="Feral Bear"
        elseif role=="DAMAGER" or form==1 then spec="Feral Cat"
        else return nil,"Choose Feral Cat or Bear in Settings" end
    end
    for _,name in ipairs(options) do
        local p=profiles[name]
        if p.class==class and p.spec==spec and (not preferred[spec] or name:sub(-#preferred[spec])==preferred[spec]) then return p,name end
    end
    return nil,"No Forever preset for "..spec
end
local keys={Strength="STRENGTH",Agility="AGILITY",Stamina="STAMINA",Intellect="INTELLECT",Spirit="SPIRIT",
    AttackPower="ATTACK_POWER",RangedAttackPower="RANGED_ATTACK_POWER",FeralAttackPower="FERAL_ATTACK_POWER",
    FeralCombatSkill="FERAL_COMBAT_SKILL",HitRating="HIT_RATING",CritRating="CRIT_RATING",
    HasteRating="HASTE_RATING",ArmorPenetration="ARMOR_PENETRATION_RATING",ExpertiseRating="EXPERTISE_RATING",
    DefenseRating="DEFENSE_SKILL_RATING",DodgeRating="DODGE_RATING",ParryRating="PARRY_RATING",BlockRating="BLOCK_RATING",
    BlockValue="BLOCK_VALUE",Health="HEALTH",Armor="BASE_ARMOR",BonusArmor="EXTRA_ARMOR",PhysicalDamage="PHYSICAL_DAMAGE",
    MP5="MANA_REGENERATION",SpellDamage="SPELL_DAMAGE_DONE",HealingPower="SPELL_HEALING_DONE",SpellPiercing="SPELL_PENETRATION",
    FireDamage="FIRE_SPELL_DAMAGE",ShadowDamage="SHADOW_SPELL_DAMAGE",ArcaneDamage="ARCANE_SPELL_DAMAGE",
    HolyDamage="HOLY_SPELL_DAMAGE",NatureDamage="NATURE_SPELL_DAMAGE"}
A.ProbeStatKeys=keys
local function info(link)
    return (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(link)
end
-- WoWSims Forever e2b55ab, sim/core/target.go and ui/sim/constants/mechanics.ts.
-- Sheet percentages and simulator rating points use different units.
local simRatingPerPercent=10
local hitCache={}
local function hitItem(link)
    if hitCache[link] then return unpack(hitCache[link]) end
    local read=C_Item and C_Item.GetItemStats or GetItemStats
    local stats=read and read(link)
    local tip=C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    if not A.Safe(stats) or type(stats)~="table" or not tip or not A.Safe(tip.lines) or not tip.lines or #tip.lines==0 then return end
    local cached=C_Item and C_Item.IsItemDataCachedByID
    if cached and not cached((info(link))) then return end
    local pct,skill=nil,stats.ITEM_MOD_FERAL_COMBAT_SKILL_SHORT
    local raw=stats.ITEM_MOD_HIT_RATING_SHORT
    local melee=stats.ITEM_MOD_HIT_MELEE_RATING_SHORT
    if not A.Safe(raw) or not A.Safe(melee) or not A.Safe(skill) then return end
    for _,line in ipairs(tip.lines) do
        if not A.Safe(line) or not A.Safe(line.leftText) then return end
        local s=type(line.leftText)=="string" and line.leftText:lower():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or ""
        if s:match("^equip:") and not s:find(" for %d") then
            if s:find("chance to hit") and not s:find("critical") and (not s:find("spell") or s:find("attack")) then
                local value=tonumber((s:match("by (%d+%.?%d*)%%")))
                if not value then return end
                pct=(pct or 0)+value
            end
            if not skill and s:find("feral combat") then skill=tonumber((s:match("by (%d+)"))) end
        end
    end
    local itemRating=(raw and raw~=0) and raw or melee or 0
    if not pct and itemRating~=0 then
        local cr=CR_HIT_MELEE
        local rating=cr and GetCombatRating and GetCombatRating(cr)
        local bonus=cr and GetCombatRatingBonus and GetCombatRatingBonus(cr)
        if not A.Safe(rating) or not A.Safe(bonus) or not rating or rating<=0 or not bonus or bonus<=0 then return end
        pct=itemRating*bonus/rating
        -- A character-derived conversion can change with level.
        return pct,skill or 0,raw or 0
    end
    hitCache[link]={pct or 0,skill or 0,raw or 0}
    return unpack(hitCache[link])
end
local snapshot
local hitEvents=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_EQUIPMENT_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED"}) do hitEvents:RegisterEvent(event) end
hitEvents:SetScript("OnEvent",function() snapshot=nil;hitCache={} end)
local function equippedHit()
    if not snapshot then
        local gear,skill=0,0
        for slot=1,18 do
            if slot~=4 then
                local link=GetInventoryItemLink("player",slot)
                if not A.Safe(link) then return end
                if link then
                    local pct,bonus=hitItem(link)
                    if not pct then return end
                    gear,skill=gear+pct,skill+bonus
                elseif GetInventoryItemID and GetInventoryItemID("player",slot) then return end
            end
        end
        snapshot={gear,skill}
    end
    local cr=CR_HIT_MELEE
    local rating=cr and GetCombatRatingBonus and GetCombatRatingBonus(cr)
    local modifier=GetHitModifier and GetHitModifier()
    if A.Safe(rating) and A.Safe(modifier) and type(rating)=="number" and type(modifier)=="number"
        and rating+modifier>=snapshot[1]-.01 then return rating+modifier,snapshot[2],"sheet" end
    return snapshot[1],snapshot[2],"gear only"
end
local function feralCap(diff,skill)
    local gap=5*diff-skill
    return math.max(0,5+gap*(gap>10 and .2 or .1))
end
local function cappedSwap(candidate,old,delta,profile)
    local gain,newSkill,newRaw=hitItem(candidate)
    local loss,oldSkill,oldRaw=hitItem(old)
    if not gain or not loss then return delta end
    if gain==loss and newSkill==oldSkill then return delta+profile.weights.HitRating*(oldRaw-newRaw) end
    local before,skill,source=equippedHit()
    if not before then return delta,"Hit changed • preset score" end
    local diff=UnitLevel("player")>=60 and 3 or 0
    local oldCap=feralCap(diff,skill)
    local cap=feralCap(diff,skill-oldSkill+newSkill)
    local after=before+gain-loss
    -- Skill already has its own preset weight. Value the hit change at the new cap.
    local useful=math.min(cap,after)-math.min(cap,before)
    delta=delta+profile.weights.HitRating*(useful*simRatingPerPercent-newRaw+oldRaw)
    local gap=cap-after
    if after==before and cap==oldCap then return delta end
    local status=math.abs(gap)<.005 and "at cap" or string.format("%.1f%% %s",math.abs(gap),gap>0 and "short" or "to spare")
    local label=source=="gear only" and "Gear hit" or "Hit"
    return delta,string.format("%s %.1f%% → %.1f%% • %s",label,before,after,status)
end
local function score(link,p,slot)
    local cached=C_Item and C_Item.IsItemDataCachedByID
    local id=info(link)
    if not id then return end
    if cached and not cached(id) then C_Item.RequestLoadItemDataByID(id);return end
    local getStats=C_Item and C_Item.GetItemStats or GetItemStats
    if not getStats then return end
    local stats=getStats(link)
    if not A.Safe(stats) or type(stats)~="table" then return end
    local w=p.weights
    local total,recognized=0,false
    local function add(n,weight)
        if not A.Safe(n) or type(n)~="number" then return end
        total=total+n*(weight or 0);recognized=true
    end
    for name,key in pairs(keys) do add(stats["ITEM_MOD_"..key.."_SHORT"],w[name]) end
    local generic=stats.ITEM_MOD_SPELL_POWER_SHORT
    if not stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT then add(generic,w.SpellDamage) end
    if not stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT then add(generic,w.HealingPower) end
    local dps=stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    local weight=slot==16 and w.MainHandDps or slot==17 and w.OffHandDps or slot==18 and w.RangedDps
    local data=C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    local ap,armor
    local proc=(A.Data.ItemProcs or {})[id]
    for _,line in ipairs(data and data.lines or {}) do
        local s=line.leftText
        if A.Safe(s) and type(s)=="string" then
            s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            if not proc and (s:find("^Chance on hit:") or (ITEM_SPELL_TRIGGER_ONPROC and ITEM_SPELL_TRIGGER_ONPROC~="" and s:find(ITEM_SPELL_TRIGGER_ONPROC,1,true)==1)) then proc=true end
            ap=ap or tonumber(s:match("^Equip:%s*%+(%d+) Attack Power%.?$") or s:match("^Equip: Increases attack power by (%d+)%.?$"))
            armor=armor or tonumber((s:match("^(%d+) Armor$")))
            dps=dps or tonumber((s:match("%(([%d%.]+) damage per second%)")))
        end
    end
    if not stats.ITEM_MOD_ATTACK_POWER_SHORT then add(ap,w.AttackPower) end
    if not stats.ITEM_MOD_BASE_ARMOR_SHORT and not stats.ITEM_MOD_EXTRA_ARMOR_SHORT then add(armor,w.Armor) end
    if weight and weight~=0 and select(6,info(link))==2 then
        if not dps then return end
        add(dps,weight)
    end
    local procStatus
    if proc then
        procStatus="proc unscored"
        if id==279480 and type(proc)=="table" and p.spec=="Feral Cat" then
            -- Cat profile weights are DPS/stat. Sustained single-target reference:
            -- one eligible landed paw swing/s, no special rolls; allow bleed refreshes.
            local chance=proc.ppm/60
            local ticks=0
            for t=proc.period,proc.duration,proc.period do ticks=ticks+(1-chance)^t end
            total=total+chance*proc.damage*ticks
            procStatus="proc estimated"
        end
    end
    if recognized then return total,procStatus end
end
function A.EPCompare(candidate,baseline,selection,slot,emptyOffhand)
    local p,name=A.EPProfile(selection)
    if not p then return nil,name end
    local id,_,_,where=info(candidate)
    local tier=A.Data.TierOwner and A.Data.TierOwner[id]
    if tier and tier~=p.class then return nil,"Other class tier" end
    local old,_,_,before=info(baseline)
    if not slots[where] or not slots[before] or slots[where][1]~=slots[before][1] then return nil,"Choose two items for the same slot" end
    if slots[where][1]==16 and not emptyOffhand and (where=="INVTYPE_2HWEAPON")~=(before=="INVTYPE_2HWEAPON") then return nil,"Compare complete weapon sets" end
    if not A.ItemClassMatches(id,p.class) or not A.ItemClassMatches(old,p.class) then return nil,"Class restriction" end
    slot=slot or slots[where][1]
    local a,procA=score(candidate,p,slot)
    local b,procB=score(baseline,p,slot)
    if not a or not b then return nil,"Insufficient readable stats" end
    local status=procA or procB
    if procA and procB and procA~=procB then status="one proc estimated, one unscored" end
    return a-b,name,b,status
end
local function equipped(link,selection,visitor)
    local _,_,_,where=info(link)
    for _,slot in ipairs(slots[where] or {}) do
        local old=GetInventoryItemLink("player",slot)
        if A.Safe(old) and old then
            local emptyOffhand=false
            if slot==16 then
                local offhand=GetInventoryItemLink("player",17)
                emptyOffhand=A.Safe(offhand) and offhand==nil and (not GetInventoryItemID or not GetInventoryItemID("player",17))
            end
            local delta,name,base,status=A.EPCompare(link,old,selection,slot,emptyOffhand)
            visitor(delta,name,base,slot,old,status)
        end
    end
end
local verdictColor={Upgrade={.30,.72,1},Downgrade={1,.38,.38},Even={.78,.78,.78}}
local function tooltip(tip)
    if not ForeverDB_Config or ForeverDB_Config.showComparisonTooltips==false or ForeverDB_Config.epProfile=="Off" then return end
    local _,link=tip:GetItem()
    if not A.Safe(link) or type(link)~="string" or tip.f1CatLink==link then return end
    local p,name=A.EPProfile()
    if not p then return end
    local shown=false
    local _,class=UnitClass("player")
    local feral=class=="DRUID" and (p.spec=="Feral Cat" or p.spec=="Feral Bear")
    equipped(link,name,function(delta,reason,base,slot,old,procStatus)
        if not delta and reason=="Compare complete weapon sets" then
            tip:AddLine(name,1,.82,0)
            tip:AddLine("Compare both weapon slots",.78,.78,.78)
            shown=true
        end
        if delta and link~=old then
            local hitLine
            if feral then delta,hitLine=cappedSwap(link,old,delta,p) end
            if not shown then tip:AddLine(name,1,.82,0);shown=true end
            local verdict=math.abs(delta)<.05 and "Even" or (delta>0 and "Upgrade" or "Downgrade")
            local paired=({[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2"})[slot]
            local result=string.format("%s%s %+.1f weighted points",paired and paired.." • " or "",verdict,delta)
            if procStatus then result=result.." • "..procStatus end
            tip:AddLine(result,unpack(verdictColor[verdict]))
            if hitLine then tip:AddLine(hitLine,.75,.84,.92) end
        end
    end)
    if shown then tip.f1CatLink=link end
end
function A.CatComparison(tip)
    pcall(tooltip,tip)
end
function A.EPBenchmark(id,selection)
    local p,name=A.EPProfile(selection)
    if not p then return end
    local class=name:match("^([^ ]+)")
    local list=A.Data.SpecGear[class.."/"..p.spec]
    local item=A.Entity("item",id)
    if not item then return end
    for _,r in ipairs(list or {}) do
        if r[2]=="BiS" and (not r[6] or r[6]=="") then
            local ref=A.Entity("item",r[3])
            if ref and ref.slot==item.slot then
                local delta,_,base=A.EPCompare("item:"..id,"item:"..r[3],name)
                if delta and base>0 then return string.format("%.1f%% of %s • guide BiS slot score",100*(base+delta)/base,r[4]) end
            end
        end
    end
end
A.EPEquipped=equipped
