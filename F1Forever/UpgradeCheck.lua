local _,A=...
local prefix="F1GearEP1"
local pending,lastRequest
local replied={}
local function available(channel)
    if channel=="GUILD" then return IsInGuild and IsInGuild() end
    if channel=="INSTANCE_CHAT" then return IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end
    if channel=="RAID" then return IsInRaid and IsInRaid() end
    return channel=="PARTY" and IsInGroup and IsInGroup()
end
local function myGain(id)
    local p,name=A.EPProfile()
    local _,class=UnitClass("player")
    if not p or p.class~=class then return end
    local own=A.EPProfile("My spec")
    if own and p.spec~=own.spec then return end
    local item=A.Entity("item",id)
    if not item or (item.required or 0)>UnitLevel("player") then return end
    local usable=C_Item and C_Item.IsEquippableItem or IsEquippableItem
    local link="item:"..id
    if not usable or not usable(link) then return end
    local best
    A.EPEquipped(link,name,function(delta,_,baseline)
        if delta and baseline>0 then
            local pct=100*delta/baseline
            if not best or pct>best then best=pct end
        end
    end)
    return best
end
function A.StartUpgradeCheck(id,channel)
    if channel=="GROUP" then
        if LE_PARTY_CATEGORY_INSTANCE and available("INSTANCE_CHAT") then channel="INSTANCE_CHAT"
        elseif available("RAID") then channel="RAID" else channel="PARTY" end
    end
    if not available(channel) or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then A.Message("Channel unavailable");return end
    local now=GetTime()
    if lastRequest and now-lastRequest<15 then A.Message("Wait 15 seconds between upgrade checks");return end
    local token=tostring(math.floor(now*1000))
    lastRequest=now
    pending={id=id,token=token,channel=channel,untilTime=now+12,results={}}
    local check=pending
    C_ChatInfo.SendAddonMessage(prefix,"Q "..token.." "..id,channel)
    C_Timer.After(12,function()
        local rows={}
        for player,gain in pairs(check.results) do rows[#rows+1]={player,gain} end
        table.sort(rows,function(a,b) return a[2]>b[2] end)
        ForeverDB_Config.lastUpgradeCheck={item=id,time=time(),results=rows}
        A.Message("Upgrade check • "..A.Label("item",id).." • "..#rows.." opt-in replies")
        for _,r in ipairs(rows) do A.Message(string.format("%s   %+.1f%% slot score",r[1],r[2])) end
    end)
end
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    local events=CreateFrame("Frame")
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:SetScript("OnEvent",function(_,_,key,msg,channel,sender)
        if key~=prefix or not A.Safe(msg) or not A.Safe(sender) or not ForeverDB_Config then return end
        local now=GetTime()
        local token,id=msg:match("^Q (%d+) (%d+)$")
        if token and #token<=16 and #id<=9 and ForeverDB_Config.epShare and available(channel) then
            if replied[sender] and now-replied[sender]<14 then return end
            replied[sender]=now
            local function reply()
                if not ForeverDB_Config.epShare or not available(channel) or GetTime()-now>10 then return end
                local gain=myGain(tonumber(id))
                if gain then C_ChatInfo.SendAddonMessage(prefix,string.format("R %s %s %.2f",token,id,gain),"WHISPER",sender) end
            end
            if Item and Item.CreateFromItemID and A.Entity("item",tonumber(id)) then
                Item:CreateFromItemID(tonumber(id)):ContinueOnItemLoad(reply)
            else reply() end
        elseif channel=="WHISPER" and pending and now<=pending.untilTime then
            local t,i,g=msg:match("^R (%d+) (%d+) (%-?%d+%.?%d*)$")
            if t==pending.token and tonumber(i)==pending.id and tonumber(g) then pending.results[sender]=tonumber(g) end
        end
    end)
end
