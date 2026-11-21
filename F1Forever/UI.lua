local _, A = ...
local D=A.Data
local ui, render, selectTab, menu
local state={tab="Loot Journal",journalLanding=true,query="",page=1,history={},future={},expanded={},filter="All",list=1,pageFilter="All",quality="All qualities",slot="All slots",relation="All"}
-- One bounded browser history shared by every page; controls stay in the footer.
local navCurrent,navRestoring,navRendering
local navKeys={"tab","journalLanding","journalCollection","collectionPage","collectionSet","journalCustomize","journal","boss","journalQuest",
    "questTree","questTreeDungeon","questFocus","questFocusStep","questFocusRoot","questTrace","questMode",
    "query","page","edgePage","pageFilter","quality","slot","relation","searchScope","dungeonLevel",
    "professionZone","professionView","professionRange","profession","guideSection","bisClass","bisSpec","talentClass",
    "talentSpec","talentBuild","list","filter"}
local function copyNav(v)
    if type(v)~="table" then return v end
    local t={};for k,x in pairs(v) do t[k]=copyNav(x) end;return t
end
local function navSnapshot()
    local t={};for _,k in ipairs(navKeys) do t[k]=state[k] end
    t.entity=copyNav(state.entity);t.expanded=copyNav(state.expanded)
    return t
end
local function sameNav(a,b)
    if not a or not b then return false end
    if a.tab=="Recipes" and b.tab=="Recipes" and a.pageFilter~=b.pageFilter then return false end
    if a.tab==b.tab and a.journalCustomize and b.journalCustomize then return true end
    local routeKeys={"tab","journalLanding","journalCollection","collectionPage","collectionSet","journalCustomize","journal","boss","questTree","questFocusStep","questTrace","questMode","page","edgePage","relation","professionView","guideSection","bisClass","bisSpec","list"}
    for _,k in ipairs(routeKeys) do if a[k]~=b[k] then return false end end
    return (a.entity and a.entity.kind)==(b.entity and b.entity.kind) and (a.entity and a.entity.id)==(b.entity and b.entity.id)
end
function A.CaptureNavigationScroll()
    if not navCurrent or not ui or navRendering or navRestoring then return end
    local y=ui.detailScroll and ui.detailScroll:GetVerticalScroll()
    local r=ui.journalRailScroll and ui.journalRailScroll:GetVerticalScroll()
    navCurrent.scroll=type(y)=="number" and y or 0;navCurrent.railScroll=type(r)=="number" and r or 0
end
local function pushNav(stack,v)
    stack[#stack+1]=v;if #stack>80 then table.remove(stack,1) end
end
function A.Navigate(direction)
    if menu then menu:Hide() end
    A.CaptureNavigationScroll()
    local source=direction=="back" and state.history or state.future
    local dest=direction=="back" and state.future or state.history
    local target=table.remove(source);if not target then return end
    if navCurrent then pushNav(dest,navCurrent) end
    navRestoring=true
    for _,k in ipairs(navKeys) do state[k]=target[k] end
    state.entity=copyNav(target.entity);state.expanded=copyNav(target.expanded or {})
    ui.search:SetText(state.query or "");navCurrent=target
    render()
    ui.detailScroll:SetVerticalScroll(target.scroll or 0)
    ui.journalRailScroll:SetVerticalScroll(target.railScroll or 0)
    navRestoring=false
end
local PAGE_ROWS=13
local tabs={"Gear Journal","BiS & Talents","Profession Guides","Quests & Attunements","Database","Settings & Credits"}
local destinations={["Profession Guides"]="Profession Guides",["Settings & Credits"]="Overview",["Gear Journal"]="Loot Journal",Database="Database",["Quests & Attunements"]="Attunements",["BiS & Talents"]="Class Guides"}
local function navGroup(tab)
    if tab=="Class Guides" then return "BiS & Talents" end
    if tab=="Overview" or tab=="Settings" then return "Settings & Credits" end
    if tab=="Loot Journal" then return "Gear Journal" end
    if tab=="Items" or tab=="Gear" or tab=="NPCs" or tab=="Objects" or tab=="Recipes" then return "Database" end
    if tab=="Quests" or tab=="Attunements" then return "Quests & Attunements" end
    return tab
end
local databasePages={{"Items","All items"},{"Gear","Equipment"},{"Recipes","Professions"},{"NPCs","NPCs"},{"Objects","Objects & Containers"}}
local questPages={{"Quests","Quest database"},{"Attunements","Attunements & chains"}}

local Style={
    -- Obsidian near-black neutrals with Arcane Slate blue highlights. Gold is kept for headings.
    Canvas={.031,.031,.039,1},
    CanvasBorder={.204,.204,.227,1},
    HeaderBg={0,0,0,1},
    PanelBg={.059,.059,.067,1},
    PanelBorder={.125,.125,.133,1},
    PanelHeader={.086,.086,.094,1},
    RowEven={.086,.086,.094,1},
    RowOdd={.098,.098,.106,1},
    RowPassive={.071,.071,.078,1},
    RowSelected={.090,.239,.431,.96},
    RowSelectedBorder={.306,.651,1,1},
    RowBorder={.125,.125,.133,1},
    HeadingBg={0,0,0,0},
    HeadingBorder={0,0,0,0},
    HeadingRule={.204,.204,.227,1},
    TableHeaderBg={.071,.071,.078,1},
    TableHeaderBorder={.125,.125,.133,1},
    ButtonBg={.141,.141,.153,1},
    ButtonBorder={.204,.204,.227,1},
    ButtonHoverBg={.18,.18,.19,1},
    ButtonHoverBorder={.306,.651,1,1},
    TabActiveBg={.090,.239,.431,1},
    TabActiveBorder={.306,.651,1,1},
    Accent={.306,.651,1,1},
    Bullet={.306,.651,1,1},
    Title={.95,.96,1,1},
    Note={.663,.663,.682,1},
    NavLabel={.58,.63,.71,1},
    Gold={1.0,.824,.353,1},
    Cyan={.16,.52,.88,1},
    Jade={.20,.83,.60,1},
    Muted={.663,.663,.682,1},
}
A.Style=Style
-- Small blue square bullet drawn from a native white texture (no font glyph needed).
local BULLET="|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:78:166:255|t "
A.Bullet=BULLET
-- Arial Narrow ships with every client; fall back to the default small font if it fails to load.
local NarrowFont="GameFontHighlightSmall"
if CreateFont then
    local f=CreateFont("F1ForeverNarrowFont")
    if f and f.SetFont and pcall(f.SetFont,f,"Fonts\\ARIALN.TTF",13,"") then
        if f.GetFont and not f:GetFont() then NarrowFont="GameFontHighlightSmall" else NarrowFont="F1ForeverNarrowFont" end
        if f.SetTextColor then f:SetTextColor(.94,.94,.95,1) end
    end
end
local function applyGradient(tex,orientation,r1,g1,b1,a1,r2,g2,b2,a2)
    tex:SetColorTexture(1,1,1,1)
    if CreateColor and tex.SetGradient then
        local c1,c2=CreateColor(r1,g1,b1,a1),CreateColor(r2,g2,b2,a2)
        local ok=pcall(tex.SetGradient,tex,orientation,orientation=="VERTICAL" and c2 or c1,orientation=="VERTICAL" and c1 or c2)
        if ok then return end
    end
    if tex.SetGradientAlpha then
        local ok=pcall(tex.SetGradientAlpha,tex,orientation,orientation=="VERTICAL" and r2 or r1,orientation=="VERTICAL" and g2 or g1,orientation=="VERTICAL" and b2 or b1,orientation=="VERTICAL" and a2 or a1,orientation=="VERTICAL" and r1 or r2,orientation=="VERTICAL" and g1 or g2,orientation=="VERTICAL" and b1 or b2,orientation=="VERTICAL" and a1 or a2)
        if ok then return end
    end
    tex:SetColorTexture((r1+r2)*.5,(g1+g2)*.5,(b1+b2)*.5,(a1+a2)*.5)
end
local function styleScrollBar(scrollFrame)
    if not scrollFrame or not scrollFrame.ScrollBar or scrollFrame.styledScrollBar then return end
    scrollFrame.styledScrollBar=true
    local sb=scrollFrame.ScrollBar
    local name=sb.GetName and sb:GetName()
    local up=(sb.ScrollUpButton) or (name and _G[name.."ScrollUpButton"])
    local down=(sb.ScrollDownButton) or (name and _G[name.."ScrollDownButton"])
    if up then up:Hide();up:SetAlpha(0);up:EnableMouse(false);up:SetSize(1,1) end
    if down then down:Hide();down:SetAlpha(0);down:EnableMouse(false);down:SetSize(1,1) end
    for _,region in ipairs({sb:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType()=="Texture" and region~=sb:GetThumbTexture() then
            region:Hide()
        end
    end
    sb:SetWidth(8)
    sb:ClearAllPoints()
    sb:SetPoint("TOPRIGHT",scrollFrame,"TOPRIGHT",16,-2)
    sb:SetPoint("BOTTOMRIGHT",scrollFrame,"BOTTOMRIGHT",16,2)
    local track=sb:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints(sb)
    track:SetColorTexture(.03,.03,.035,.85)
    local thumb=sb:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetWidth(6)
        thumb:SetVertexColor(.30,.30,.30,.92)
        sb:HookScript("OnEnter",function() thumb:SetVertexColor(1.0,.82,.00,.95) end)
        sb:HookScript("OnLeave",function() thumb:SetVertexColor(.30,.30,.30,.92) end)
    end
end
local qualityRGB={
    [0]={.62,.62,.62},
    [1]={.88,.90,.94},
    [2]={.12,1.0,.00},
    [3]={.00,.44,.87},
    [4]={.64,.21,.93},
    [5]={1.0,.50,.00},
    [6]={.90,.80,.50},
}
local professionIcons={
    Alchemy="Interface\\Icons\\Trade_Alchemy",
    Blacksmithing="Interface\\Icons\\Trade_BlackSmithing",
    Cooking="Interface\\Icons\\INV_Misc_Food_15",
    Enchanting="Interface\\Icons\\Trade_Engraving",
    Engineering="Interface\\Icons\\Trade_Engineering",
    ["First Aid"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    Fishing="Interface\\Icons\\Trade_Fishing",
    Herbalism="Interface\\Icons\\Trade_Herbalism",
    Leatherworking="Interface\\Icons\\Trade_LeatherWorking",
    Mining="Interface\\Icons\\Trade_Mining",
    Skinning="Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    Tailoring="Interface\\Icons\\Trade_Tailoring",
}
local function skillColor(skill)
    skill=tonumber(skill) or 0
    if skill<=75 then return "|cff72e6a0"
    elseif skill<=150 then return "|cffffd166"
    elseif skill<=225 then return "|cffff9f43"
    else return "|cffa335ee" end
end
local ICONS="Interface\\AddOns\\F1Forever\\Media\\Icons\\"
local function entityVisuals(kind,id,text)
    if kind=="item" then
        local _,_,q,icon=A.Item(id)
        local c=qualityRGB[q or 1] or qualityRGB[1]
        return icon,c[1],c[2],c[3],.08,.92,.08,.92
    elseif kind=="recipe" then
        local e=D.Recipes and D.Recipes[id]
        local icon=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or (GetSpellTexture and GetSpellTexture(id))
        if not icon and A.index then
            for _,n in ipairs(A.index[A.Key("recipe",id)] or {}) do
                local ft,fi,tt,ti,rel=A.Edge(n)
                if ft=="recipe" and fi==id and rel=="Crafts" and tt=="item" then
                    local _,_,_,itIcon=A.Item(ti); icon=itIcon; break
                end
            end
        end
        if not icon then icon=(e and professionIcons[e.profession]) or "Interface\\Icons\\INV_Scroll_03" end
        return icon,.90,.66,.23,.08,.92,.08,.92
    elseif kind=="npc" then
        local e=A.Entity("npc",id)
        local f=e and e.faction
        local r,g,b=.27,.80,.92
        if f=="A" or f=="Alliance" then r,g,b=.28,.60,.98
        elseif f=="H" or f=="Horde" then r,g,b=.92,.30,.30 end
        if e and e.trainerProfession and professionIcons[e.trainerProfession] then
            return professionIcons[e.trainerProfession],r,g,b,.08,.92,.08,.92
        elseif f=="A" or f=="Alliance" then
            return "Interface\\TargetingFrame\\UI-PVP-Alliance",r,g,b,.05,.60,.05,.60
        elseif f=="H" or f=="Horde" then
            return "Interface\\TargetingFrame\\UI-PVP-Horde",r,g,b,.05,.60,.05,.60
        end
        return "Interface\\GossipFrame\\ChatBubbleGossipIcon",r,g,b,0,1,0,1
    elseif kind=="quest" then
        -- Line icons are tinted (10th value); each state has its own shape as well as a colour.
        if A.QuestDone(id) then
            return ICONS.."QuestDone",.37,.83,.60,0,1,0,1,false,{.37,.83,.60}
        elseif A.QuestActive and A.QuestActive(id) then
            return ICONS.."QuestActive",.33,.86,.96,0,1,0,1,false,{.33,.86,.96}
        end
        -- Not started is neutral: no "!" that would imply the quest is available.
        return ICONS.."QuestNone",.44,.44,.46,0,1,0,1,false,{.50,.50,.53}
    elseif kind=="object" then
        return "Interface\\Icons\\INV_Box_01",.68,.55,.95,.08,.92,.08,.92
    elseif type(text)=="string" then
        local prof=text:match("^([%a%s]+)%s+•")
        if prof and professionIcons[prof] then
            return professionIcons[prof],.90,.66,.23,.08,.92,.08,.92
        end
    end
end
local function isFavorited(kind,id)
    if not kind or not id or not ForeverDB_Favorites or not ForeverDB_Favorites.lists then return false end
    local k=A.Key(kind,id)
    for _,l in ipairs(ForeverDB_Favorites.lists) do
        if l.entries and l.entries[k] then return true end
    end
    return false
end

local function sorted(t)
    local keys={}; for k in pairs(t or {}) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end); return keys
end
local function label(parent,text,x,y,width,font)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
    return f
end
local function button(parent,text,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width,27); b:SetPoint("TOPLEFT",x,y)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b:SetBackdropColor(unpack(Style.ButtonBg)); b:SetBackdropBorderColor(unpack(Style.ButtonBorder))
    b.caption=label(b,text,8,-7,width-16,"GameFontHighlightSmall")
    b.caption:ClearAllPoints(); b.caption:SetPoint("CENTER",b,"CENTER",0,0);b.caption:SetJustifyH("CENTER")
    b.caption:SetJustifyH("CENTER"); b.caption:SetJustifyV("MIDDLE")
    function b:SetText(s) self.caption:SetText(s) end
    b:SetScript("OnEnter",function(self)
        self:SetBackdropColor(unpack(Style.ButtonHoverBg))
        self:SetBackdropBorderColor(unpack(Style.ButtonHoverBorder))
    end)
    b:SetScript("OnLeave",function(self)
        if self.isActiveTab then
            self:SetBackdropColor(unpack(Style.TabActiveBg))
            self:SetBackdropBorderColor(unpack(Style.TabActiveBorder))
        else
            self:SetBackdropColor(unpack(Style.ButtonBg))
            self:SetBackdropBorderColor(unpack(Style.ButtonBorder))
        end
    end)
    b:SetText(text); b:SetScript("OnClick",function(self,...) A.CaptureNavigationScroll();callback(self,...) end)
    b:SetScript("OnMouseDown",function() A.CaptureNavigationScroll() end)
    return b
end
local function styleEditBox(eb)
    local regions=eb.GetRegions and {eb:GetRegions()} or {}
    for _,region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType()=="Texture" then region:Hide() end
    end
    if not eb.bgFrame then
        local bg=CreateFrame("Frame",nil,eb,"BackdropTemplate")
        bg:SetPoint("TOPLEFT",eb,"TOPLEFT",-2,0)
        bg:SetPoint("BOTTOMRIGHT",eb,"BOTTOMRIGHT",2,0)
        local lvl=eb.GetFrameLevel and eb:GetFrameLevel()
        if type(lvl)=="number" then bg:SetFrameLevel(math.max(1,lvl-1)) end
        bg:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        bg:SetBackdropColor(unpack(Style.ButtonBg))
        bg:SetBackdropBorderColor(unpack(Style.ButtonBorder))
        eb.bgFrame=bg
    end
    eb:SetTextInsets(8,8,0,0)
    eb:HookScript("OnEditFocusGained",function(self)
        if self.bgFrame then self.bgFrame:SetBackdropBorderColor(unpack(Style.Accent)) end
    end)
    eb:HookScript("OnEditFocusLost",function(self)
        if self.bgFrame then self.bgFrame:SetBackdropBorderColor(unpack(Style.ButtonBorder)) end
    end)
end
local function choose(anchor,options,callback,selectedIndex)
    if menu and menu:IsShown() and menu.anchor==anchor then menu:Hide();return end
    if menu then menu:Hide() end
    menu=CreateFrame("Frame",nil,ui or UIParent,"BackdropTemplate")
    local popup=menu
    popup.anchor=anchor
    local function mouseDown()
        return IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) or false
    end
    local wasDown=mouseDown()
    popup:SetScript("OnUpdate",function(self,elapsed)
        if not anchor:IsShown() then self:Hide();return end
        local overMenu=self:IsMouseOver()
        local overAnchor=anchor:IsMouseOver()
        local down=mouseDown()
        if down and not wasDown and not overMenu and not overAnchor then self:Hide();return end
        wasDown=down
    end)
    menu:SetFrameStrata("TOOLTIP"); menu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2)
    local menuWidth=math.max(220,anchor:GetWidth())
    menu:SetSize(menuWidth,math.min(#options,16)*29+8); menu:SetClampedToScreen(true)
    menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    menu:SetBackdropColor(unpack(Style.RowEven)); menu:SetBackdropBorderColor(unpack(Style.CanvasBorder))
    local rows={}; local offset=math.max(0,math.min(math.max(0,#options-16),(selectedIndex or 1)-16))
    local function update()
        for i,b in ipairs(rows) do
            local o=options[offset+i]; b.value=type(o)=="table" and o[1] or o
            b:SetText(type(o)=="table" and o[2] or o)
        end
    end
    for i=1,math.min(#options,16) do
        local b=button(menu,"",4,-4-(i-1)*29,menuWidth-8,function(self) popup:Hide(); callback(self.value) end)
        rows[i]=b
    end
    menu:EnableMouseWheel(true); menu:SetScript("OnMouseWheel",function(_,delta) offset=math.max(0,math.min(#options-#rows,offset-delta)); update() end)
    update(); menu:Show()
end
local function backdrop(f,r,g,b,br,bg,bb)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(r,g,b,.98); f:SetBackdropBorderColor(br or Style.PanelBorder[1],bg or Style.PanelBorder[2],bb or Style.PanelBorder[3],1)
end
local function clear(panel)
    panel.used=0; panel.y=0
    for _,r in ipairs(panel.rows) do
        r:Hide()
        if r.nativePortrait then r.nativePortrait:Hide() end
        if r.portraitFrame then r.portraitFrame:Hide() end
        if r.levelBadge then r.levelBadge:Hide() end
        if r.meta then r.meta:Hide() end
        for _,b in pairs(r.controls or {}) do
            b:Hide()
            if b.picture then b.picture:Hide() end
            if b.fadeOverlay then b.fadeOverlay:Hide() end
            if b.levelBadge then b.levelBadge:Hide() end
        end
    end
end
local function row(panel,text,callback,kind,id,indent,height)
    panel.used=panel.used+1
    local r=panel.rows[panel.used]
    if not r then
        r=CreateFrame("Button",nil,panel,"BackdropTemplate")
        r:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8","ADD")
        r.accent=r:CreateTexture(nil,"OVERLAY")
        r.accent:SetPoint("TOPLEFT",r,"TOPLEFT",0,-1)
        r.accent:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",0,1)
        r.accent:SetWidth(3)
        r.iconBorder=r:CreateTexture(nil,"BACKGROUND",nil,2)
        r.iconBorder:SetSize(24,24); r.iconBorder:SetPoint("LEFT",8,0)
        r.icon=r:CreateTexture(nil,"ARTWORK")
        r.icon:SetSize(22,22); r.icon:SetPoint("CENTER",r.iconBorder,"CENTER",0,0)
        r.text=r:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        r.text:SetJustifyH("LEFT"); r.text:SetJustifyV("MIDDLE")
        panel.rows[panel.used]=r
    end
    local highlight=r:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(.20,.20,.20,(callback or kind) and .35 or 0) end
    if r.SetHyperlinksEnabled then r:SetHyperlinksEnabled(false) end
    r:SetScript("OnHyperlinkEnter",nil);r:SetScript("OnHyperlinkLeave",nil);r:SetScript("OnHyperlinkClick",nil)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT",indent or 0,-panel.y)
    local rowH=height or 30
    r:SetSize(panel:GetWidth()-(indent or 0),rowH)
    r.f1RankRow=nil
    if r.tierBadge then r.tierBadge:Hide() end
    r.kind=kind; r.id=id; r.text:ClearAllPoints()
    if r.nativePortrait then r.nativePortrait:Hide() end
    if r.portraitFrame then r.portraitFrame:Hide() end
    if r.levelBadge then r.levelBadge:Hide() end
    if r.rule then r.rule:Hide() end
    r.iconBorder:ClearAllPoints();r.iconBorder:SetPoint("LEFT",8,0);r.iconBorder:SetSize(24,24)
    r.icon:ClearAllPoints();r.icon:SetPoint("CENTER",r.iconBorder,"CENTER",0,0);r.icon:SetSize(22,22)
    r.text:SetFontObject("GameFontHighlight"); r.text:SetTextColor(.94,.94,.95,1)
    if r.meta then
        r.meta:Hide()
        r.meta:SetFontObject("GameFontDisableSmall")
        r.meta:SetTextColor(unpack(Style.Muted))
    end
    local isBar=(text=="" and not kind and not callback)
    local selected=kind and id and state.entity and state.entity.kind==kind and state.entity.id==id
    if isBar and rowH<=40 then
        r:SetBackdropColor(0,0,0,0); r:SetBackdropBorderColor(0,0,0,0)
        r.accent:Hide(); r.icon:Hide(); r.iconBorder:Hide()
    else
        if selected then
            r:SetBackdropColor(unpack(Style.RowSelected))
            r:SetBackdropBorderColor(unpack(Style.RowSelectedBorder))
        elseif isBar then
            r:SetBackdropColor(unpack(Style.PanelBg))
            r:SetBackdropBorderColor(unpack(Style.PanelBorder))
        elseif not callback and not kind then
            r:SetBackdropColor(unpack(Style.RowPassive))
            r:SetBackdropBorderColor(unpack(Style.RowBorder))
        elseif panel.used%2==0 then
            r:SetBackdropColor(unpack(Style.RowEven))
            r:SetBackdropBorderColor(unpack(Style.RowBorder))
        else
            r:SetBackdropColor(unpack(Style.RowOdd))
            r:SetBackdropBorderColor(unpack(Style.RowBorder))
        end
        local iconTex,ar,ag,ab,tl,tr,tt,tb,dim,tint=entityVisuals(kind,id,text)
        -- Pooled icons can carry a dimmed state from an earlier row.
        r.icon:SetVertexColor(1,1,1,dim and .55 or 1)
        if r.icon.SetDesaturated then r.icon:SetDesaturated(dim and true or false) end
        if selected then ar,ag,ab=Style.Accent[1],Style.Accent[2],Style.Accent[3] end
        if not ar then
            if callback then ar,ag,ab=.30,.33,.40
            else ar,ag,ab=.26,.26,.28 end
        end
        if isBar then r.accent:Hide() else
            r.accent:SetWidth(3); r.accent:SetColorTexture(ar,ag,ab,1); r.accent:Show()
        end
        if iconTex then
            r.iconBorder:SetColorTexture(ar,ag,ab,.95); r.iconBorder:Show()
            r.icon:SetTexture(iconTex); r.icon:SetTexCoord(tl or .08,tr or .92,tt or .08,tb or .92); r.icon:Show()
            if tint then r.iconBorder:Hide();r.icon:SetVertexColor(tint[1],tint[2],tint[3],1) end
            r.text:SetPoint("LEFT",38,0)
            r.text:SetWidth(r:GetWidth()-48)
        else
            r.icon:Hide(); r.iconBorder:Hide()
            r.text:SetPoint("LEFT",12,0)
            r.text:SetWidth(r:GetWidth()-22)
        end
    end
    if kind=="npc" and callback then text="|cffffd100"..text.."|r  |cffffd100›|r"
    elseif kind=="recipe" and callback and not text:find("|c",1,true) then text="|cffffd100"..text.."|r" end
    r.text:SetText(text)
    r:SetScript("OnClick",function(_,mouse)
        A.CaptureNavigationScroll()
        if mouse=="RightButton" and kind then
            local options={}
            for _,l in ipairs(ForeverDB_Favorites.lists) do options[#options+1]={l,(l.entries[A.Key(kind,id)] and "[x] " or "[ ] ")..l.name} end
            choose(r,options,function(l) A.ToggleFavorite(l,kind,id); render() end)
        elseif kind=="item" and IsModifiedClick and IsModifiedClick("CHATLINK") then
            local _,link=A.Item(id); if HandleModifiedItemClick then HandleModifiedItemClick(link) end
        elseif callback then callback(mouse) end
    end)
    r:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r:SetScript("OnEnter",function(self)
        A.hovered=kind and {kind=kind,id=id} or nil
        if kind=="item" then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..id); if A.AddLookupHint then A.AddLookupHint(GameTooltip) end; GameTooltip:Show()
            if IsShiftKeyDown() and GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
        elseif kind=="npc" or kind=="quest" or kind=="object" then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(A.Name(kind,id))
            if A.AddLookupHint then GameTooltip.f1LookupHint=nil;A.AddLookupHint(GameTooltip) end
            GameTooltip:Show()
        elseif kind=="recipe" then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("spell:"..id); if A.AddLookupHint then A.AddLookupHint(GameTooltip) end; GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave",function() A.hovered=nil; GameTooltip:Hide() end)
    r:Show(); panel.y=panel.y+rowH+3; panel:SetHeight(math.max(1,panel.y))
    return r
end
-- Render only visible portraits; keep the skull below as a missing-asset fallback.
local function nativeBossPortrait(r,npcID,size)
    local displayID=((D.JournalVisuals or {}).bossDisplays or {})[npcID]
    if not displayID or type(SetPortraitTextureFromCreatureDisplayID)~="function" then return false end
    local portrait=r.nativePortrait
    if not portrait then portrait=r:CreateTexture(nil,"OVERLAY");r.nativePortrait=portrait end
    portrait:ClearAllPoints();portrait:SetPoint("LEFT",r,"LEFT",8,0);portrait:SetSize(size,size);portrait:SetTexCoord(0,1,0,1)
    if portrait.displayID~=displayID then
        portrait:SetTexture(nil)
        local ok=pcall(SetPortraitTextureFromCreatureDisplayID,portrait,displayID)
        portrait.displayID=ok and displayID or nil
    end
    local texture=portrait:GetTexture()
    if not texture or texture==0 or texture=="" then portrait:Hide();return false end
    portrait:Show();return true
end
local function frameBossSlot(r,size,level)
    if not r.portraitFrame then
        local f=CreateFrame("Frame",nil,r,"BackdropTemplate")
        f:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        f:SetBackdropBorderColor(.42,.35,.18,.95)
        r.portraitFrame=f
    end
    r.portraitFrame:ClearAllPoints()
    r.portraitFrame:SetPoint("LEFT",r,"LEFT",8,0)
    r.portraitFrame:SetSize(size,size)
    r.portraitFrame:SetFrameLevel(r:GetFrameLevel()+2)
    r.portraitFrame:Show()
    r.iconBorder:Hide()
    r.icon:ClearAllPoints();r.icon:SetPoint("CENTER",r.portraitFrame,"CENTER",0,0)
    if r.nativePortrait and r.nativePortrait:IsShown() then
        r.icon:Hide()
        r.nativePortrait:ClearAllPoints();r.nativePortrait:SetPoint("TOPLEFT",r.portraitFrame,"TOPLEFT",1,-1);r.nativePortrait:SetPoint("BOTTOMRIGHT",r.portraitFrame,"BOTTOMRIGHT",-1,1)
    end
    if level and level>0 then
        if not r.levelBadge then
            local b=CreateFrame("Frame",nil,r,"BackdropTemplate")
            b:SetSize(24,15)
            b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            b:SetBackdropColor(.04,.04,.05,.96)
            b:SetBackdropBorderColor(1.0,.82,.00,.85)
            b.text=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            b.text:SetPoint("CENTER",0,0)
            r.levelBadge=b
        end
        r.levelBadge:ClearAllPoints();r.levelBadge:SetPoint("BOTTOMLEFT",r.portraitFrame,"BOTTOMLEFT",-2,-2)
        r.levelBadge:SetFrameLevel(r:GetFrameLevel()+3)
        r.levelBadge.text:SetText("|cffffd100"..level.."|r")
        r.levelBadge:Show()
    end
end
local function text(s,height)
    local r=row(ui.detail,s,nil,nil,nil,0,height or 50)
    r.text:SetTextColor(.88,.88,.90,1)
    return r
end
-- Section header: gold text over a thin grey rule, no filled box.
local function headingRule(r)
    if not r.rule then r.rule=r:CreateTexture(nil,"ARTWORK") end
    r.rule:ClearAllPoints();r.rule:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",0,2);r.rule:SetPoint("BOTTOMRIGHT",r,"BOTTOMRIGHT",0,2);r.rule:SetHeight(1)
    r.rule:SetColorTexture(unpack(Style.HeadingRule));r.rule:Show()
    r:SetBackdropColor(unpack(Style.HeadingBg));r:SetBackdropBorderColor(unpack(Style.HeadingBorder))
    r.accent:Hide()
end
local function heading(s)
    if ui.detail.y>0 then ui.detail.y=ui.detail.y+8 end
    local r=row(ui.detail,"|cffffd100"..s.."|r",nil,nil,nil,0,30)
    headingRule(r)
    r.text:SetFontObject("GameFontNormal");r.text:ClearAllPoints();r.text:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",2,8);r.text:SetWidth(r:GetWidth()-8)
    return r
end
-- Page title: large white text over the same thin rule.
local function titleStyle(r)
    headingRule(r)
    r.text:SetTextColor(unpack(Style.Title))
end
local function link(kind,id,prefix,indent,stayHere)
    local callback
    if not stayHere then callback=function() A.Open(kind,id) end end
    local r=row(ui.detail,(prefix and ("|cffa3a3a8"..prefix.."|r") or "")..A.Label(kind,id),callback,kind,id,indent)
    r.text:SetWidth(r:GetWidth()-155)
    if not r.meta then
        r.meta=label(r,"",0,0,120,"GameFontDisableSmall")
        r.meta:SetJustifyH("RIGHT"); r.meta:SetJustifyV("MIDDLE")
    end
    r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT",r,"RIGHT",-12,0); r.meta:SetWidth(120)
    r.meta:SetText(""); r.meta:Show()
    return r
end
-- Shared horizontal tabs, wrapping for long encounter lists.
local function tabStyle(b,active)
    b.isActiveTab=active
    if active then
        b:SetBackdropColor(unpack(Style.TabActiveBg))
        b:SetBackdropBorderColor(unpack(Style.TabActiveBorder))
    else
        b:SetBackdropColor(unpack(Style.ButtonBg))
        b:SetBackdropBorderColor(unpack(Style.ButtonBorder))
    end
    if not b.activeLine then
        b.activeLine=b:CreateTexture(nil,"OVERLAY")
        b.activeLine:SetPoint("BOTTOMLEFT",1,1); b.activeLine:SetPoint("BOTTOMRIGHT",-1,1); b.activeLine:SetHeight(3)
    end
    if b.navigationImage then
        local c=active and Style.Accent or Style.NavLabel
        b.navigationImage:SetVertexColor(c[1],c[2],c[3],1)
        if b.navigationGlow then b.navigationGlow:SetAlpha(active and .9 or .35) end
        b:SetBackdropColor(unpack(Style.PanelBg));b:SetBackdropBorderColor(unpack(Style.ButtonBorder))
        b.activeLine:SetColorTexture(unpack(Style.Accent))
        local t=active and Style.Title or Style.NavLabel
        b.caption:SetTextColor(t[1],t[2],t[3],1)
    else
        b.activeLine:SetColorTexture(unpack(Style.Accent))
        b.caption:SetTextColor(active and 1 or .88,active and .82 or .88,active and .00 or .90,1)
    end
    if active then b.activeLine:Show() else b.activeLine:Hide() end
end
local function resetControl(b)
    -- Pool entries can change from selected tabs into ordinary action buttons.
    tabStyle(b,false)
    if b.picture then b.picture:Hide() end
    if b.levelBadge then b.levelBadge:Hide() end
    -- Quest table cells change caption fonts; restore the default role on reuse.
    b.caption:SetFontObject("GameFontHighlightSmall")
    b.caption:ClearAllPoints(); b.caption:SetPoint("CENTER",b,"CENTER",0,0);b.caption:SetJustifyH("CENTER")
    b.caption:SetJustifyH("CENTER"); b.caption:SetJustifyV("MIDDLE")
    b:SetScript("OnEnter",function(self)
        self:SetBackdropColor(unpack(Style.ButtonHoverBg))
        self:SetBackdropBorderColor(unpack(Style.ButtonHoverBorder))
    end)
    b:SetScript("OnLeave",function(self)
        if self.isActiveTab then
            self:SetBackdropColor(unpack(Style.TabActiveBg))
            self:SetBackdropBorderColor(unpack(Style.TabActiveBorder))
        else
            self:SetBackdropColor(unpack(Style.ButtonBg))
            self:SetBackdropBorderColor(unpack(Style.ButtonBorder))
        end
    end)
end
local function tabStrip(entries,selected,callback,columns,panel)
    panel=panel or ui.detail
    columns=columns or 4
    local width=panel:GetWidth()/columns
    for i=1,#entries,columns do
        local base=row(panel,"",nil,nil,nil,0,34)
        base.controls=base.controls or {}
        for j=0,columns-1 do
            local entry=entries[i+j]
            if entry then
                local b=base.controls[j+1]
                if not b then b=button(base,"",0,0,width-3,function(self) callback(self.value) end); base.controls[j+1]=b end
                resetControl(b)
                b:ClearAllPoints(); b:SetPoint("TOPLEFT",j*width,0); b:SetSize(width-3,32)
                b.caption:SetWidth(width-18)
                b.value=entry.value; b:SetText(entry.label); b:SetScript("OnClick",function(self) callback(self.value) end)
                tabStyle(b,selected==entry.value); b:Show()
            end
        end
    end
end
local function tableHeader(left,right)
    local r=row(ui.detail,"|cffa3a3a8"..left.."|r",nil,nil,nil,0,28)
    r:SetBackdropColor(unpack(Style.TableHeaderBg))
    r:SetBackdropBorderColor(unpack(Style.TableHeaderBorder))
    r.accent:Hide()
    r.text:SetFontObject("GameFontHighlightSmall")
    if not r.meta then
        r.meta=label(r,"",0,0,170,"GameFontHighlightSmall")
        r.meta:SetJustifyH("RIGHT"); r.meta:SetJustifyV("MIDDLE")
    end
    r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT",r,"RIGHT",-76,0); r.meta:SetWidth(170)
    r.meta:SetText("|cffa3a3a8"..(right or "").."|r"); r.meta:Show()
end
local function copyText(value)
    ui.copy:SetText(value); ui.copy:Show(); ui.copy:SetFocus(); ui.copy:HighlightText()
end
local function favoriteButton(r,kind,id)
    r.controls=r.controls or {}
    local fav=r.controls[8]
    if not fav then fav=button(r,"+ Fav",0,0,58,function() end);r.controls[8]=fav end
    resetControl(fav)
    local saved=isFavorited(kind,id)
    fav:ClearAllPoints();fav:SetPoint("RIGHT",r,"RIGHT",-6,0);fav:SetSize(58,22)
    fav:SetText("+ Fav");fav.caption:SetWidth(48);tabStyle(fav,saved)
    fav:SetScript("OnClick",function(self)
        local options={}
        for _,list in ipairs(ForeverDB_Favorites.lists) do options[#options+1]={list,(list.entries[A.Key(kind,id)] and "[x] " or "[ ] ")..list.name} end
        choose(self,options,function(list) A.ToggleFavorite(list,kind,id);render() end)
    end);fav:Show();r.text:SetWidth(r:GetWidth()-106)
end
local function questRoleCards(questID,indent,only)
    indent=indent or 0
    local seen={}
    for _,role in ipairs({{"Starts","Quest giver"},{"Ends","Turn in"}}) do if not only or only==role[1] then
        local targets={}
        for _,n in ipairs(A.index[A.Key("quest",questID)] or {}) do
            local ft,fi,tt,ti,relation=A.Edge(n)
            local key=role[1]..":"..ft..":"..fi
            if tt=="quest" and ti==questID and relation==role[1] and not seen[key] then
                seen[key]=true;targets[#targets+1]={kind=ft,id=fi}
            end
        end
        for _,target in ipairs(targets) do
            local kind,id=target.kind,target.id
            local e=A.Entity(kind,id) or {}
            local pins={}
            for _,area in ipairs(sorted(e.spawns)) do
                for _,point in ipairs(e.spawns[area]) do
                    if A.ValidPoint(point[1],point[2]) and D.Maps[area] then
                        pins[#pins+1]={{area=area,x=point[1],y=point[2]},((C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)) or tostring(area)).." • "..point[1]..", "..point[2]}
                    end
                end
            end
            local other,ids={},{}
            for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do
                local ft,fi,tt,ti,relation=A.Edge(n)
                if ft==kind and fi==id and tt=="quest" and ti~=questID and (relation=="Starts" or relation=="Ends") and not ids[ti] and A.QuestVisible(ti) then ids[ti]=true;other[#other+1]=ti end
            end
            table.sort(other,function(a,b) return A.Name("quest",a)<A.Name("quest",b) end)
            local location=pins[1] and ("  •  "..pins[1][2]) or ""
            local r=row(ui.detail,"|cffbbbbbb"..role[2]..":|r "..A.Name(kind,id)..location,nil,kind,id,indent,ui.detail:GetWidth()<=720 and 56 or 38)
            r.text:SetWidth(r:GetWidth()-230);r.controls=r.controls or {}
            local function action(index,caption,width,right,callback)
                local control=r.controls[index]
                if not control then control=button(r,caption,0,0,width,callback);r.controls[index]=control end
                resetControl(control)
                control:ClearAllPoints();control:SetPoint("RIGHT",r,"RIGHT",right,0);control:SetSize(width,25);control.caption:SetWidth(width-12)
                control:SetText(caption);control:SetScript("OnClick",callback);tabStyle(control,false);control:Show()
            end
            if #pins>0 then action(1,"Pin",55,-155,function(self)
                local function pin(p) A.Pin(p.area,p.x,p.y) end
                if #pins==1 then pin(pins[1][1]) else choose(self,pins,pin) end
            end) end
            local key="giver-quests:"..questID..":"..kind..":"..id
            if kind=="npc" and #other>0 then action(2,(state.expanded[key] and "Hide quests" or "More quests").." ("..#other..")",145,-4,function() state.expanded[key]=not state.expanded[key];render() end) end
            if state.expanded[key] then
                for _,qid in ipairs(other) do
                    local qkey=key..":"..qid
                    row(ui.detail,(state.expanded[qkey] and "[-] " or "[+] ")..A.Name("quest",qid),function() state.expanded[qkey]=not state.expanded[qkey];render() end,"quest",qid,indent+18,28)
                    if state.expanded[qkey] then
                        row(ui.detail,A.QuestDone(qid) and "Completed" or "Not completed",nil,nil,nil,indent+36,26)
                        for _,objective in ipairs((D.Quests[qid] or {}).objectives or {}) do row(ui.detail,objective,nil,nil,nil,indent+36,54) end
                    end
                end
            end
        end
    end end
end
local function changeKeybinding()
    if InCombatLockdown() then A.Message("Change the contextual key after combat.");return end
    local dialog=ui.keyDialog
    if not dialog then
        dialog=CreateFrame("Frame",nil,ui,"BackdropTemplate");ui.keyDialog=dialog
        dialog:SetSize(440,160);dialog:SetPoint("CENTER");dialog:SetFrameStrata("DIALOG")
        backdrop(dialog,.06,.08,.10);dialog:EnableMouse(true)
        dialog.title=label(dialog,"Press a key combination • Escape cancels",16,-18,410)
        dialog.value=label(dialog,"",16,-54,410)
        button(dialog,"Save binding",16,-118,190,function()
            if dialog.key and A.Bind(dialog.key) then dialog:Hide();render() end
        end)
        button(dialog,"Cancel",225,-118,190,function() dialog:Hide() end)
        dialog:SetScript("OnKeyDown",function(self,key)
            if key=="ESCAPE" then self:Hide();return end
            if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
            local combo=(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")..(IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
            self.key=combo
            local existing=GetBindingAction(combo)
            self.value:SetText(combo..((existing and existing~="" and existing~="CLICK ForeverDBHelpButton:LeftButton") and (" • replaces "..existing) or ""))
        end)
        dialog:SetScript("OnHide",function(self) self:EnableKeyboard(false);self.key=nil end)
    end
    dialog.key=nil;dialog.value:SetText("Press your preferred key, then click Save.")
    dialog:EnableKeyboard(true);dialog:SetPropagateKeyboardInput(false);dialog:Show()
end
function A.OpenBindingSettings()
    A.Show();selectTab("Overview");changeKeybinding()
end
local comparisonBase,browserProfile
local comparisonLoads=CreateFrame("Frame")
comparisonLoads:RegisterEvent("GET_ITEM_INFO_RECEIVED")
comparisonLoads:SetScript("OnEvent",function(_,_,id,success)
    if success and comparisonBase and ui and ui:IsShown() and state.entity and state.entity.kind=="item"
        and (id==comparisonBase or id==state.entity.id) then render() end
end)
local function epPicker(label,selection,callback)
    local control=row(ui.detail,label.." • "..(selection or "My spec").."  v",function() end)
    control:SetScript("OnClick",function(self) choose(self,A.EPOptions(),function(value) callback(value);render() end) end)
end
local function compareItem(id)
    if comparisonBase then
        epPicker("Comparison profile",browserProfile or ForeverDB_Config.epProfile,function(v) browserProfile=v end)
        local benchmark=A.EPBenchmark(id,browserProfile)
        if benchmark then text(benchmark,30) end
        if comparisonBase~=id then
            local delta,name,_,proc=A.EPCompare("item:"..id,"item:"..comparisonBase,browserProfile)
            text(A.Label("item",id).." vs "..A.Label("item",comparisonBase).." • "..(delta and string.format("%+.1f weighted points • %s",delta,name) or name)..(proc and " • "..proc or ""),34)
        end
    end
    row(ui.detail,comparisonBase==id and "Clear comparison item" or "Use as comparison item",function()
        comparisonBase=comparisonBase~=id and id or nil;render()
    end)
    if comparisonBase==id then text("Open another item in Database to compare this slot.",28) end
    local group=row(ui.detail,"Check group or guild upgrades  v",function() end)
    group:SetScript("OnClick",function(self)
        choose(self,{{"GROUP","Party or raid"},{"GUILD","Guild"}},function(channel) A.StartUpgradeCheck(id,channel) end)
    end)
end
local function entityDetail(kind,id)
    local e=A.Entity(kind,id)
    local suffix=""
    if e and e.level and e.level>0 then
        suffix="  |cff999999"..(kind=="item" and "iLvl " or "Lv ")..e.level
        if kind=="npc" and e.maxLevel and e.maxLevel>e.level then suffix=suffix.."–"..e.maxLevel end
        if kind=="item" and e.required and e.required>0 then suffix=suffix.." / requires "..e.required end
        suffix=suffix.."|r"
    end
    heading(A.Label(kind,id)..suffix)
    favoriteButton(ui.detail.rows[ui.detail.used],kind,id)

    if not e then text("This entity is not in the current Forever snapshot. The live tooltip may still be available."); return end
    if kind=="item" and (e.slot or 0)>0 then compareItem(id) end
    if kind=="npc" and e.trainerProfession then
        text(e.trainerProfession.." trainer"..(e.faction and e.faction~="" and (" • "..(({A="Alliance",H="Horde",AH="Both factions"})[e.faction] or e.faction)) or ""),30)
        if not e.trainerRecipesRecorded then text("This trainer's recipe list is being expanded in upcoming updates. Check back soon!",38) end
        for _,rank in ipairs(e.professionRanks or {}) do
            local r=row(ui.detail,"|cffbbbbbbProfession training:|r "..rank.name.." — "..rank.rank..(rank.requiredSkill and (" • Skill "..rank.requiredSkill) or ""),nil,nil,nil,0,30)
            r:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("spell:"..rank.spellID);GameTooltip:Show()
            end)
        end
    end
    if kind=="recipe" and e.profession then text(e.profession..(e.skill and (" • Required skill "..e.skill) or "")..(#(e.acquisition or {})>0 and (" • "..table.concat(e.acquisition,", ")) or ""),32) end
    if kind=="item" then
        row(ui.detail,"Hover for native tooltip / Shift to compare",nil,"item",id,0,30)
    elseif kind=="quest" then
        local requirements,options={},{}
        for _,group in ipairs({{"allPrerequisites","Requires all: "},{"anyPrerequisites","Requires one: "}}) do
            local names={}
            for _,qid in ipairs(e[group[1]] or {}) do names[#names+1]=A.Name("quest",qid);options[#options+1]={qid,A.Name("quest",qid)} end
            if #names>0 then requirements[#requirements+1]=group[2]..table.concat(names,", ") end
        end
        local summary=(A.QuestDone(id) and "|cff72e6a0Completed|r" or "Not completed")
        if A.QuestClassLabel(e) then summary=summary.." • "..A.QuestClassLabel(e) end
        if e.required and e.required>0 then summary=summary.." • Requires level "..e.required end
        if #requirements>0 then summary=summary.."  •  |cffbbbbbb"..table.concat(requirements," • ").."|r" end
        local status=row(ui.detail,summary,nil,nil,nil,0,30)
        if #options>0 then status:SetScript("OnClick",function(self) choose(self,options,function(qid) A.Open("quest",qid) end) end) end
        local h=status.text:GetStringHeight();if type(h)=="number" and h>22 then status:SetHeight(h+8);ui.detail.y=ui.detail.y+h-22 end
        questRoleCards(id)
        if #(e.objectives or {})>0 then heading("Objectives") end
        for _,objective in ipairs(e.objectives or {}) do text(objective,54) end
        local rewards={}
        for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do
            local ft,fi,tt,ti,relation=A.Edge(n)
            if relation~="Starts" and relation~="Ends" then rewards[#rewards+1]=n end
        end
        if #rewards>0 then
            heading("Quest links")
            for _,n in ipairs(rewards) do
                local ft,fi,tt,ti,relation=A.Edge(n);local incoming=tt==kind and ti==id
                link(incoming and ft or tt,incoming and fi or ti,A.RelationLabel(relation,incoming))
            end
        end
        return
    elseif kind=="npc" then
        heading("Locations")
        local count=0
        for _,area in ipairs(sorted(e.spawns)) do
            local points=e.spawns[area]
            for _,p in ipairs(points) do
                local areaID,x,y=area,p[1],p[2]
                local name=(C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)) or ("Area "..areaID)
                if A.ValidPoint(x,y) and D.Maps[areaID] then
                    row(ui.detail,string.format("%s • %.1f, %.1f • Show pin",name,x,y),function() A.Pin(areaID,x,y) end)
                    count=count+1
                end
                if count>=12 then break end
            end
            if count>=12 then break end
        end
        local observed=e.observedLocation
        if observed and A.ValidPoint(observed.x,observed.y) then
            row(ui.detail,string.format("%s • %.1f, %.1f • Observed nearby • Show pin",observed.zone or "Location",observed.x,observed.y),function() A.PinMap(observed.map,observed.x,observed.y) end)
            count=count+1
        end
        if count==0 then text("No verified coordinates in this snapshot.",30) end
        if count>=12 then text("Showing the first 12 recorded locations.",26) end
    end

    heading("Relationships")
    local relationTabs=A.RelationshipTabs(kind,id)
    local valid=false
    for _,tab in ipairs(relationTabs) do if tab.value==state.relation then valid=true end end
    if not valid then state.relation="All";state.edgePage=1 end
    tabStrip(relationTabs,state.relation,function(group) state.relation=group; state.edgePage=1; render() end,math.max(1,math.min(4,#relationTabs)))
    local edges={}
    for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do
        if A.RelationMatches(n,kind,id,state.relation) then edges[#edges+1]=n end
    end
    local start=state.edgePage or 1
    for i=start,math.min(#edges,start+59) do
        local ft,fi,tt,ti,relation=A.Edge(edges[i])
        local incoming=tt==kind and ti==id
        local targetKind,targetID=tt,ti
        if incoming then targetKind,targetID=ft,fi end
        local prefix=A.RelationLabel(relation,incoming)
        if relation=="Reagent" then
            local recipe=D.Recipes[ti]; local amount=recipe and recipe.reagents and recipe.reagents[fi]
            if amount then prefix=prefix.."x"..amount.." • " end
        end
        local rr=link(targetKind,targetID,nil)
        rr.text:SetWidth(rr:GetWidth()-170)
        rr.meta:SetWidth(145); rr.meta:ClearAllPoints(); rr.meta:SetPoint("RIGHT",rr,"RIGHT",-8,0)
        rr.meta:SetText(prefix:gsub(": $", ""))
        local enter=rr:GetScript("OnEnter")
        rr:SetScript("OnEnter",function(self)
            if enter then enter(self) end
            if targetKind~="item" then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(A.Name(targetKind,targetID)) end
            GameTooltip:Show()
        end)


    end
    if #edges==0 then
        if state.relation=="Crafted by" or state.relation=="Used for" or state.relation=="Learned from" then
            text("No relationship recorded here. Client-defined crafting is available where supported; trainer and acquisition coverage remains partial.",80)
        else text("No relationship recorded in this section yet. This does not mean the item is unobtainable or that this source type cannot apply.",60) end
    end
    if #edges>60 then
        text("Relationships "..start.."–"..math.min(#edges,start+59).." of "..#edges,24)
        if start>1 then
            row(ui.detail,"Previous relationships page",function()
                state.edgePage=start-60;ui.detailScroll:SetVerticalScroll(0);render()
            end)
        end
        if start+60<=#edges then
            row(ui.detail,"Next relationships page",function()
                state.edgePage=start+60;ui.detailScroll:SetVerticalScroll(0);render()
            end)
        end
    end

end
local function drawTalentTrees(c,b)
    -- Three read-only trees; source row/column positions are retained.
    local maxRow=1
    for _,t in ipairs(b.talents) do maxRow=math.max(maxRow,t.row) end
    local canvas=row(ui.detail,"",nil,nil,nil,0,55+maxRow*54)
    canvas.controls=canvas.controls or {}
    local width=ui.detail:GetWidth()/3
    for ti,name in ipairs(c.specs) do
        local head=canvas.controls[ti]
        if not head then head=button(canvas,"",0,0,width-6,function() end);canvas.controls[ti]=head end
        resetControl(head)
        local total=0;for _,t in ipairs(b.talents) do if t.treeIndex==ti then total=total+t.rank end end
        head:ClearAllPoints();head:SetPoint("TOPLEFT",(ti-1)*width+3,0);head:SetSize(width-6,28);head.caption:SetWidth(width-22)
        head:SetText(name.." ("..total..")");head:SetScript("OnClick",nil);tabStyle(head,false);head:Show()
    end
    for i,t in ipairs(b.talents) do
        local node=canvas.controls[i+3]
        if not node then
            node=button(canvas,"",0,0,42,function() end);canvas.controls[i+3]=node
        end
        if node.activeLine then node.activeLine:Hide() end
        if not node.picture then
            node.picture=node:CreateTexture(nil,"ARTWORK");node.picture:SetPoint("TOPLEFT",3,-3);node.picture:SetSize(36,36)
        end
        node.caption:SetDrawLayer("OVERLAY");node.caption:ClearAllPoints();node.caption:SetPoint("BOTTOM",node,"BOTTOM",0,2)
        node:ClearAllPoints();node:SetPoint("TOPLEFT",(t.treeIndex-1)*width+35+(t.col-1)*(width-70)/4,-36-(t.row-1)*54)
        node:SetSize(42,46);node.caption:SetWidth(42)
        node.picture:SetTexture("Interface\\Icons\\"..(t.icon or "INV_Misc_QuestionMark"));node.picture:SetDesaturated(t.rank==0);node.picture:Show()
        node:SetBackdropBorderColor(t.rank>0 and .1 or .25,t.rank>0 and .65 or .25,t.rank>0 and 1 or .25,1)
        node:SetText((t.rank>0 and "|cff33ccff" or "|cff999999")..t.rank.."/"..t.max.."|r")
        node:SetScript("OnClick",nil)
        node:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if t.spell then GameTooltip:SetHyperlink("spell:"..t.spell) else GameTooltip:SetText(t.name) end
            GameTooltip:AddLine("Build allocation: "..t.rank.."/"..t.max,1,1,1);GameTooltip:Show()
        end)
        node:SetScript("OnLeave",function() GameTooltip:Hide() end);node:Show()
    end
end
local function talentGuide(embedded)
    local classes=D.TalentGuides or {}
    local options={}; for _,key in ipairs(sorted(classes)) do options[#options+1]={key,classes[key].name} end
    local playerClass=UnitClass and select(2,UnitClass("player"))
    state.talentClass=state.talentClass or playerClass or "WARRIOR"
    local c=classes[state.talentClass]; if not c then text("Talent guides unavailable.");return end
    local specs={};for _,name in ipairs(c.specs) do specs[#specs+1]={value=name,label=name} end
    specs[#specs+1]={value="__quests",label="Trainer / quests"}
    state.talentSpec=state.talentSpec or c.specs[1]
    if not embedded then
    local bar=row(ui.detail,"",nil,nil,nil,0,36);bar.controls=bar.controls or {}
    local width=ui.detail:GetWidth()/5
    for i=1,5 do
        local control=bar.controls[i]
        if not control then control=button(bar,"",0,0,width-3,function() end);bar.controls[i]=control end
        resetControl(control)
        control:ClearAllPoints();control:SetPoint("TOPLEFT",(i-1)*width,0);control:SetSize(width-3,36);control.caption:SetWidth(width-20)
        if i==1 then
            control:SetText(c.name.."  v")
            control:SetScript("OnClick",function(self) choose(self,options,function(value) state.talentClass=value;state.talentSpec=nil;state.talentBuild=nil;render() end) end)
            tabStyle(control,false)
        else
            local entry=specs[i-1];control:SetText(entry.label);control.value=entry.value
            control:SetScript("OnClick",function(self) state.talentSpec=self.value;state.talentBuild=nil;render() end)
            tabStyle(control,state.talentSpec==entry.value)
        end
        control:Show()
    end
    end
    if state.talentSpec=="__quests" then
        heading("Class quest unlocks")
        tableHeader("ABILITY","LEVEL")
        for _,q in ipairs(c.quests) do local r=row(ui.detail,q.name);r.text:SetText(q.name.."  —  Level "..tostring(q.level or "?")) end
        text("Quest IDs, pickup NPCs and full chains are not linked here yet. See Attunements for recorded quest chains.",50)
        if #c.quests==0 then text("No class quest unlocks recorded here yet.",32) end
        return
    end
    local builds={}
    for i,b in ipairs(c.builds) do if b.spec==state.talentSpec then builds[#builds+1]={value=i,label="Popular #"..b.rank.." • "..b.points} end end
    if #builds==0 then text("No popular sample recorded for this specialization yet.",40);return end
    state.talentBuild=state.talentBuild or builds[1].value
    if not embedded then tabStrip(builds,state.talentBuild,function(value) state.talentBuild=value;render() end,3) end
    local b=c.builds[state.talentBuild]
    heading(c.name.." • "..b.spec.." • Level "..b.level)
    text("Popular sample • read-only • not a final recommendation. Snapshot: November 2026.",32)
    drawTalentTrees(c,b)
end
local function guideReference(ref)
    if type(ref)~="table" or type(ref.id)~="number" or ref.id<=0 then return end
    if ref.kind=="item" or ref.kind=="npc" or ref.kind=="quest" then link(ref.kind,ref.id);return end
    if ref.kind=="spell" then
        local target="spell:"..ref.id
        local r=row(ui.detail,"|cff71d5ff"..(ref.label or "View spell").."|r",function() if SetItemRef then SetItemRef(target,ref.label or "Spell","LeftButton") end end)
        r:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(target);GameTooltip:Show() end)
    end
end
local function inlineGuideLink(ref)
    local caption=ref.label or A.Name(ref.kind,ref.id)
    local color="ff71d5ff"
    local texture=""
    if ref.kind=="item" then
        local name,_,quality,icon=A.Item(ref.id)
        caption=name;color=A.colors[quality+1] or "ffffffff"
        texture="|T"..tostring(icon)..":16:16:0:0|t "
    end
    return "|c"..color.."|H"..ref.kind..":"..ref.id.."|h"..texture.."["..caption.."]|h|r"
end
local function guideLine(content,rankRow,tier)
    local r=row(ui.detail,content,nil,nil,nil,0,28)
    if tier then
        r:SetBackdropBorderColor(.22,.59,1,1)
        r.accent:SetColorTexture(.22,.59,1,1)
        if not r.tierBadge then
            r.tierBadge=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            r.tierBadge:SetPoint("RIGHT",r,"RIGHT",-12,0)
            r.tierBadge:SetTextColor(.4,.77,1)
            r.tierBadge:SetText("Tier")
        end
        r.tierBadge:Show()
        r.text:SetWidth(r:GetWidth()-66)
    end
    r.f1RankRow=rankRow
    if r.SetHyperlinksEnabled then r:SetHyperlinksEnabled(true) end
    r:SetScript("OnHyperlinkEnter",function(self,target)
        local kind,id=target:match("^(%a+):(%d+)");id=tonumber(id)
        A.hovered=kind and kind~="spell" and {kind=kind,id=id} or nil
        if kind=="spell" or kind=="item" or kind=="quest" then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(target)
            if rankRow and rankRow.id==id then
                local title=GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
                if A.Safe(title) and (not title or title=="" or title==RETRIEVING_ITEM_INFO or title==RETRIEVING_DATA) then
                    GameTooltip:AddLine(A.Name("item",id),1,.82,0)
                    GameTooltip:AddLine("Saved ranking stats",.4,.8,1)
                    GameTooltip:AddLine(D.RankedStatSummary[id],1,1,1,true)
                end
                if A.AddRankRowLine then A.AddRankRowLine(GameTooltip,rankRow) end
                A.AddLookupHint(GameTooltip)
            end
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnHyperlinkLeave",function() A.hovered=nil;GameTooltip:Hide() end)
    r:SetScript("OnHyperlinkClick",function(_,target,caption,mouse)
        local kind,id=target:match("^(%a+):(%d+)");id=tonumber(id)
        if kind=="spell" then if SetItemRef then SetItemRef(target,caption,mouse) end
        elseif id then A.Open(kind,id) end
    end)
    local h=r.text:GetStringHeight()
    if type(h)=="number" and h>20 then local extra=h-20;r:SetHeight(28+extra);ui.detail.y=ui.detail.y+extra end
end
local function bisGuide()
    local byClass={}
    for _,g in ipairs(A.Guides) do byClass[g.class]=byClass[g.class] or {};table.insert(byClass[g.class],g) end
    local classToken=UnitClass and select(2,UnitClass("player"))
    local classData=classToken and D.TalentGuides and D.TalentGuides[classToken]
    state.bisClass=state.bisClass or (classData and classData.name) or "Warrior"
    local specs=byClass[state.bisClass] or {};local selected
    for _,g in ipairs(specs) do if g.spec==state.bisSpec then selected=g end end
    if not selected then selected=specs[1];state.bisSpec=selected and selected.spec end
    if not selected then return end
    state.guideSection=state.guideSection or "BiS"
    local guide
    for _,g in ipairs((D.ClassBible or {})[selected.class] or {}) do
        local spec=g.spec
        if spec=="Feral" then spec=g.role=="Tank" and "Feral Bear" or "Feral Cat" end
        if spec==selected.spec then guide=g end
    end
    local token
    for k,c in pairs(D.TalentGuides or {}) do if c.name==selected.class then token=k end end
    local talentSpec=selected.spec
    if talentSpec=="Feral Cat" or talentSpec=="Feral Bear" then talentSpec="Feral Combat" end
    local buildOptions={};local labels={}
    local choices,known={},{}
    local verified=(D.ArticleBuilds or {})[selected.class.."/"..selected.spec] or {}
    local nodes=(D.ArticleNodes or {})[selected.class] or {}
    for _,article in ipairs(verified) do
        choices[#choices+1]=article
        known[article.ranks]=true
    end
    for _,existing in ipairs(guide and guide.talents or {}) do
        if existing.allocation then
            local bySpell={}
            for _,node in ipairs(existing.allocation.talents) do bySpell[node.spell]=node.rank end
            local digits={}
            for i,node in ipairs(nodes) do digits[i]=tostring(bySpell[node.spell] or 0) end
            if not known[table.concat(digits)] then choices[#choices+1]=existing end
        end
    end
    for i,t in ipairs(choices) do
        local key="g:"..i;local caption=t.name
        buildOptions[#buildOptions+1]={key,caption};labels[key]=caption
    end
    if not labels[state.guideChoice] then state.guideChoice=buildOptions[1] and buildOptions[1][1] end
    local specOptions={};for _,g in ipairs(specs) do specOptions[#specOptions+1]=g.spec end
    local sections={{value="BiS",label="BiS Gear"},{value="Talents",label="Talents & Builds"},{value="Enchants",label="Enchants & Consumes"},{value="Guide",label="General Guide"}}
    local selectors={
        {state.bisClass,sorted(byClass),function(v) state.bisClass=v;state.bisSpec=nil;state.guideChoice=nil end},
        {state.bisSpec,specOptions,function(v) state.bisSpec=v;state.guideChoice=nil end},
    }
    local ranked,profile,rankNotes,probeCount
    if state.guideSection=="BiS" then
        local presets={}
        for name,p in pairs(D.StatProfiles or {}) do
            if p.class==selected.class:upper() and p.spec==selected.spec then
                presets[#presets+1]=name
            end
        end
        table.sort(presets)
        if #presets>0 then
            local _,playerProfile=A.EPProfile()
            local key=selected.class.."/"..selected.spec
            state.gearSources=state.gearSources or {}
            profile=state.gearSources[key] or (D.StatProfiles[playerProfile] and D.StatProfiles[playerProfile].spec==selected.spec
                and D.StatProfiles[playerProfile].class==selected.class:upper() and playerProfile) or presets[1]
            local choices={}
            for _,name in ipairs(presets) do choices[#choices+1]={name,"Ranked • "..name:match(" / ([^/]+)$")} end
            choices[#choices+1]={"Guide lists","Guide lists"}
            selectors[#selectors+1]={profile=="Guide lists" and profile or ("Ranked • "..profile:match(" / ([^/]+)$")),choices,function(v) state.gearSources[key]=v end}
            if profile~="Guide lists" then
                local model=state.rankHit or "all hit usable"
                selectors[#selectors+1]={model=="already capped" and "Hit capped" or "Full hit value",{{"already capped","Hit capped"},{"all hit usable","Full hit value"}},function(v) state.rankHit=v end}
                ranked,rankNotes,probeCount=A.ProbeRankings(profile,model)
            end
        end
    end
    local panel=ui.bisHeader:IsShown() and ui.bisHeader or ui.detail
    local bar=row(panel,"",nil,nil,nil,0,30);bar.controls=bar.controls or {}
    local width=panel:GetWidth()/#selectors
    for i,entry in ipairs(selectors) do
        local control=bar.controls[i]
        if not control then control=button(bar,"",0,0,width-3,function() end);bar.controls[i]=control end
        resetControl(control)
        control:ClearAllPoints();control:SetPoint("TOPLEFT",(i-1)*width,0);control:SetSize(width-3,30);control.caption:SetWidth(width-20)
        control:SetText(entry[1].."  v");tabStyle(control,false)
        control:SetScript("OnClick",function(self) choose(self,entry[2],function(value) entry[3](value);ui.detailScroll:SetVerticalScroll(0);render() end) end)
        control:Show()
    end
    tabStrip(sections,state.guideSection,function(v) state.guideSection=v;ui.detailScroll:SetVerticalScroll(0);render() end,4,panel)
    if state.guideSection=="BiS" then
        heading(selected.class.." • "..selected.spec)
        local options={}
        for _,option in ipairs(D.SpecGear[selected.class.."/"..selected.spec] or {}) do
            local tier=D.TierOwner and D.TierOwner[option[3]]
            if not tier or tier==selected.class:upper() then options[#options+1]=option end
        end
        local tiers={}
        for _,group in ipairs(D.JournalTiers or {}) do
            for _,id in ipairs(group[2]) do
                local item=D.Items[id]
                local slot=item and A.ProbeSlots[item.slot]
                if slot and D.TierOwner[id]==selected.class:upper() then
                    tiers[slot]=tiers[slot] or {}
                    table.insert(tiers[slot],{id=id,set=group[1]})
                end
            end
        end
        local function tierRows(slot,details)
            local shown={}
            for _,piece in ipairs(tiers[slot] or {}) do
                local entry=details[piece.id]
                guideLine(inlineGuideLink({kind="item",id=piece.id}).."   •   "..piece.set..
                    (entry and entry.caption or ""),entry and entry.rank,true)
                shown[piece.id]=true
            end
            return shown
        end
        if ranked then
            local sourceByID={}
            for _,option in ipairs(options) do
                if option[5] and option[5]~="" and option[5]~="-" then sourceByID[option[3]]=option[5] end
            end
            local slotOrder=A.ProbeSlotOrder
            if not ranked[state.rankedSlot] and not tiers[state.rankedSlot] then
                state.rankedSlot=nil
                for _,slot in ipairs(slotOrder) do if ranked[slot] or tiers[slot] then state.rankedSlot=slot;break end end
            end
            for _,slot in ipairs(slotOrder) do
                if ranked[slot] or tiers[slot] then
                    local chosen=slot
                    row(ui.journalRail,(slot==state.rankedSlot and "|cffffd100" or "")..slot.."|r",function()
                        state.rankedSlot=chosen;ui.detailScroll:SetVerticalScroll(0);render()
                    end,nil,nil,0,28)
                end
            end
            heading((state.rankedSlot or "Gear").." • F1 weighted rankings")
            guideLine(probeCount.." eligible items scored offline • Level 60 weights • Set bonuses and procs unscored.")
            local picks=ranked[state.rankedSlot] or {}
            local details={}
            for i=1,#picks,2 do
                local id=picks[i]
                local notes=rankNotes[id]
                details[id]={caption=string.format("   •   #%d   •   %.2f points",(i+1)/2,picks[i+1])
                    ..(sourceByID[id] and ("   •   "..sourceByID[id]) or "")..(notes and ("   •   "..notes) or ""),
                    rank={id=id,profile=profile,rank=(i+1)/2,points=picks[i+1],slot=state.rankedSlot,model=state.rankHit or "all hit usable"}}
            end
            local shown=tierRows(state.rankedSlot,details)
            if #picks==0 then text("No scored items for this slot.",42) end
            for i=1,#picks,2 do
                local id=picks[i]
                if not shown[id] then guideLine(inlineGuideLink({kind="item",id=id})..details[id].caption,details[id].rank) end
            end
            return
        end
        heading("Guide lists")
        if not profile then guideLine("This specialization has no numeric weight profile for F1 weighted rankings yet.") end
        local slots={}
        for _,option in ipairs(options) do slots[option[1]]=true end
        local ordered,byGuide={},{}
        local guideArmor={Head="Head Armor",Shoulder="Shoulder Armor",Chest="Chest Armor",Hands="Hand Armor",
            Wrist="Wrist Armor",Waist="Waist Armor",Legs="Leg Armor",Feet="Feet Armor",Back="Back Armor"}
        for _,option in ipairs(options) do
            if slots[option[1]] then
                ordered[#ordered+1]=option[1]
                slots[option[1]]=false
            end
        end
        for _,slot in ipairs(A.ProbeSlotOrder) do
            if tiers[slot] then
                local label=guideArmor[slot] or slot
                byGuide[label]=slot
                if slots[label]==nil then ordered[#ordered+1]=label end
                slots[label]=false
            end
        end
        if slots[state.bisSlot]==nil then state.bisSlot=ordered[1] end
        for _,slot in ipairs(ordered) do
                row(ui.journalRail,(state.bisSlot==slot and "|cffffd100" or "")..slot.."|r",function()
                    state.bisSlot=slot;ui.detailScroll:SetVerticalScroll(0);render()
                end,nil,nil,0,28)
        end
        if state.bisSlot then heading(state.bisSlot) end
        local details={}
        for _,option in ipairs(options) do
            if option[1]==state.bisSlot then
                local src=option[5]
                details[option[3]]={caption="   •   "..option[2]..(src and src~="" and src~="-" and "   •   "..src or "")}
            end
        end
        local shown=tierRows(byGuide[state.bisSlot],details)
        for _,option in ipairs(options) do
            if option[1]==state.bisSlot and not shown[option[3]] then
                local source=option[5]
                guideLine(inlineGuideLink({kind="item",id=option[3],label=option[4]}).."   •   "..option[2]..
                    (source and source~="" and source~="-" and "   •   "..source or ""))
            end
        end
        if #options==0 then text("The saved Forever guide has no published item choices for this specialization yet.",42) end
    elseif state.guideSection=="Enchants" then
        heading("Level 60 enchants & consumables")
        local picks=(D.CapConsumables or {})[selected.class.."/"..selected.spec]
        if not picks then text("Guide capture pending.",32)
        elseif #picks==0 then text("The guide currently lists leveling advice only.",32) end
        local lastBand
        for _,pick in ipairs(picks or {}) do
            if lastBand~=pick[1] then heading("Level "..pick[1]);lastBand=pick[1] end
            local content=pick[3]
            local cursor=1
            for i=4,#pick do
                local ref=pick[i]
                local first,last=content:find(ref[3],cursor,true)
                if first then
                    local link=inlineGuideLink({kind=ref[1],id=ref[2],label=ref[3]})
                    content=content:sub(1,first-1)..link..content:sub(last+1)
                    cursor=first+#link
                end
            end
            guideLine(pick[2].."   "..content)
        end
    elseif state.guideSection=="Guide" then
        heading(selected.class.." • "..selected.spec.." • Guide preview")
        if not guide then text("Detailed guide coming soon.",28) else
            guideLine("|cff33ccffStats:|r "..guide.stats)
            heading("Rotation")
            for _,step in ipairs(guide.rotation) do
                local content=type(step)=="table" and (step.text or "") or step
                if type(step)=="table" then
                    for _,ref in ipairs(step.refs or {}) do
                        local name=ref.label or ""
                        local first,last=content:find(name,1,true)
                        if name~="" and first then content=content:sub(1,first-1)..inlineGuideLink(ref)..content:sub(last+1) end
                    end
                end
                guideLine(content)
            end
        end
        heading("Class quests & unlocks")
        local unlocks=(D.ClassQuestUnlocks and D.ClassQuestUnlocks[token]) or (guide and guide.unlocks) or (D.TalentGuides[token] and D.TalentGuides[token].quests) or {}
        if #unlocks==0 then guideLine("No class quests or unlocks recorded yet.") end
        for _,q in ipairs(unlocks) do
            local caption=q.spellID and inlineGuideLink({kind="spell",id=q.spellID,label=q.name}) or (q.name or "Unlock")
            caption=caption.." • Level "..tostring(q.level or "?")
            if q.raceIDs then caption=caption.." • Race-specific chain" end
            if q.questID then caption=caption.." • "..inlineGuideLink({kind="quest",id=q.questID}) end
            if q.npcID then caption=caption.." • "..inlineGuideLink({kind="npc",id=q.npcID}) end
            guideLine(caption)
        end

    else
        local token
        for k,c in pairs(D.TalentGuides or {}) do if c.name==selected.class then token=k end end
        local spec=selected.spec
        if spec=="Feral Cat" or spec=="Feral Bear" then spec="Feral Combat" end
        local desired=state.guideSection=="Trainer / quests" and "__quests" or spec
        if state.talentClass~=token or state.talentSpec~=desired then state.talentBuild=nil end
        state.talentClass=token;state.talentSpec=desired
        if state.guideSection=="Talents" and state.guideChoice then
            local typ,index=state.guideChoice:match("^(%a):(%d+)$");index=tonumber(index)
            if typ=="g" then
                local t=choices[index]
                if t then
                    local choices={}
                    for _,option in ipairs(buildOptions) do
                        choices[#choices+1]={value=option[1],label=option[2]}
                    end
                    tabStrip(choices,state.guideChoice,function(value)
                        state.guideChoice=value;ui.detailScroll:SetVerticalScroll(0);render()
                    end,math.min(4,#choices))
                    if t.ranks and not t.allocation then
                        local talents={}
                        for i,node in ipairs(nodes) do
                            local talent={}
                            for k,v in pairs(node) do talent[k]=v end
                            talent.rank=tonumber(t.ranks:sub(i,i))
                            talents[i]=talent
                        end
                        t.allocation={talents=talents}
                    end
                    if t.allocation then drawTalentTrees(D.TalentGuides[token],t.allocation)
                    else text(t.unavailable or "Talent tree unavailable for this build.",40) end
                end
                return
            end
            state.talentBuild=index
        end
        text("No imported talent build available for this specialization yet.",36)
    end
end
local function guideDetail(g)
    heading(g.class.." • "..g.spec)
    text(g.role.."  |  "..g.status,32)
    heading("Short guide"); text(g.overview,80)
    heading("Stat priorities"); text(g.stats,95)
    heading("Potential talents"); text(g.talents,110)
    heading("BiS — coming later")
    text("Gear lists will be published when level 60 dungeon loot is confirmed and the builds have been simulated. This draft does not rank items as best in slot.",80)
    heading("Read the current Forever sources")
    row(ui.detail,"Copy Icy Veins Forever guide link",function() copyText(g.url) end)
    row(ui.detail,"Copy Wowhead Forever class guides link",function() copyText("https://www.wowhead.com/forever/guides/classes/"..string.lower(g.class)) end)
    row(ui.detail,"Copy Forever talent calculator link",function() copyText("https://www.wowhead.com/forever/talent-calc/"..string.lower(g.class)) end)
    text("Provisional notes are starting points, not simulated stat weights or a final talent allocation. Review date: 9 November 2026.",65)
end
local function journalQuest(id,indent,trail)
    indent=indent or 0;trail=trail or {}
    if trail[id] or indent>108 then return end
    local path={};for k,v in pairs(trail) do path[k]=v end;path[id]=true
    local key="journal:"..tostring(state.journal or "profession")..":"..id
    local q=D.Quests[id]
    local faction=q and q.faction or "Unknown"
    local restriction=A.QuestClassLabel(q)
    if faction=="Both" then faction="Both factions" end
    local color=faction=="Alliance" and "|cff80baff" or faction=="Horde" and "|cffff8585" or "|cffbbbbbb"
    local r=row(ui.detail,(state.expanded[key] and "[-] " or "[+] ")..A.Name("quest",id).."  "..color..faction.."|r"..(restriction and (" • "..restriction) or "")..(A.QuestDone(id) and "  |cff72e6a0Done|r" or ""),function()
        state.expanded[key]=not state.expanded[key];render()
    end,"quest",id,indent,30)
    favoriteButton(r,"quest",id)
    if not state.expanded[key] then return end
    row(ui.detail,"Trace chain • F1 Quest",function() A.TraceQuest(id) end,nil,nil,indent+18,28)
    row(ui.detail,(A.QuestDone(id) and "|cff72e6a0Completed|r" or "Not completed")..(q and q.level and (" • Quest level "..q.level) or "")..(q and q.required and q.required>0 and (" • Requires level "..q.required) or ""),nil,nil,nil,indent+18,26)
    for _,objective in ipairs(q and q.objectives or {}) do row(ui.detail,objective,nil,nil,nil,indent+18,48) end
    questRoleCards(id,indent+18)
    for _,group in ipairs({{"allPrerequisites","Requires all:"},{"anyPrerequisites","Requires one:"}}) do
        local prerequisites=q and q[group[1]] or {}
        if #prerequisites>0 then row(ui.detail,group[2],nil,nil,nil,indent+18,26) end
        for _,qid in ipairs(prerequisites) do journalQuest(qid,indent+18,path) end
    end
end
-- Gear Journal quests: compact table plus a focus view (chain rail + selected step).
-- Missing data stays unresolved; nothing here implies a quest is available.
local QuestColor={done="|cff72e6a0",active="|cff69cfff",restricted="|cffff7070",reason="|cffff8888",open="|cffffd100",muted="|cffa3a3a8"}
local QuestTable={xs={366,412,500,566,620},widths={40,84,62,50,250},nameX=38,nameW=322}
local function fitRow(panel,r,minH,pad)
    -- Grow or shrink the last row to its wrapped text; keep the fixed height if the API is unavailable.
    local h=r.text.GetStringHeight and r.text:GetStringHeight()
    if type(h)~="number" or h<=0 then return r end
    local want=math.max(minH,math.ceil(h)+(pad or 14))
    local current=r:GetHeight() or want
    if want~=current then r:SetHeight(want);panel.y=panel.y+(want-current);panel:SetHeight(math.max(1,panel.y)) end
    return r
end
local function questSideText(side)
    local icon=side=="Alliance" and "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:14:0:0|t " or side=="Horde" and "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:0:0|t " or ""
    return icon..(side=="Alliance" and "|cff80bcff" or side=="Horde" and "|cffff8888" or "|cffd9d9df")..side.."|r"
end
local function questState(id)
    local q=D.Quests[id] or {}
    local guide=(D.QuestGuide or {})[id] or {}
    local s={q=q,guide=guide,recorded=D.Quests[id]~=nil}
    s.side=q.faction
    if not s.side or s.side=="Unknown" then s.side=guide.faction or "—" end
    s.done=A.QuestDone(id);s.active=A.QuestActive(id)
    s.hasChain=(#(q.allPrerequisites or {})>0 or #(q.anyPrerequisites or {})>0 or (guide.marker and guide.marker:find("Pre",1,true))) and true or false
    s.unmet=A.UnmetQuestRequirements(id)
    local playerLevel=UnitLevel and UnitLevel("player")
    local playerSide=UnitFactionGroup and UnitFactionGroup("player")
    s.lowLevel=type(playerLevel)=="number" and q.required and q.required>playerLevel or false
    s.wrongSide=playerSide and (s.side=="Alliance" or s.side=="Horde") and s.side~=playerSide or false
    s.classBlocked=not A.QuestClassAllowed(q)
    s.chainBlocked=s.hasChain and s.unmet>0
    local progress=A.QuestProgress(id)
    local blocked=s.lowLevel or s.wrongSide or s.classBlocked or s.chainBlocked or progress=="Alternative branch" or progress=="Restricted by another quest"
    s.restricted=blocked and not s.done and not s.active or false
    if s.restricted then
        s.reason=s.lowLevel and ("Requires level "..q.required) or s.wrongSide and (s.side.." only") or s.classBlocked and "Different class" or s.chainBlocked and ("Requires "..s.unmet.." prereq"..(s.unmet==1 and "" or "s")) or progress
    end
    s.color=s.done and QuestColor.done or s.active and QuestColor.active or s.restricted and QuestColor.restricted or QuestColor.open
    return s
end
local function questStarts(id)
    local names,pins,startID={}, {},nil
    for _,n in ipairs(A.index[A.Key("quest",id)] or {}) do
        local ft,fi,tt,ti,kind=A.Edge(n)
        if kind=="Starts" and tt=="quest" and ti==id then
            names[#names+1]=A.Name(ft,fi);if ft=="npc" and not startID then startID=fi end
            local giver=A.Entity(ft,fi)
            for _,area in ipairs(sorted(giver and giver.spawns)) do
                for _,point in ipairs(giver.spawns[area]) do
                    if D.Maps[area] and A.ValidPoint(point[1],point[2]) then
                        pins[#pins+1]={{area=area,x=point[1],y=point[2]},A.Name(ft,fi).." • "..point[1]..", "..point[2]}
                    end
                end
            end
        end
    end
    local zone
    if startID then
        local npc=D.NPCs[startID];local areas=sorted(npc and npc.spawns)
        if areas[1] then zone=(C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areas[1])) or tostring(areas[1]) end
    end
    return names,pins,startID,zone
end
-- Action slots 9/10 stay clear of table cells (1-5), series pins (7) and favorites (8).
local function questActions(r,id,pins,showTrace,blocked,height)
    r.controls=r.controls or {}
    if #pins>0 then
        local pin=r.controls[9]
        if not pin then pin=button(r,"Pin",0,0,62,function() end);r.controls[9]=pin end
        resetControl(pin);pin:ClearAllPoints();pin:SetPoint("RIGHT",r,"RIGHT",-8,0);pin:SetSize(62,height);pin:SetText("Pin")
        pin:SetScript("OnClick",function(self)
            local function put(p) A.Pin(p.area,p.x,p.y) end
            if #pins==1 then put(pins[1][1]) else choose(self,pins,put) end
        end);pin:Show()
    end
    if showTrace then
        local traceBtn=r.controls[10]
        if not traceBtn then traceBtn=button(r,"Trace",0,0,62,function() end);r.controls[10]=traceBtn end
        resetControl(traceBtn)
        traceBtn:ClearAllPoints();traceBtn:SetPoint("RIGHT",r,"RIGHT",#pins>0 and -76 or -8,0);traceBtn:SetSize(62,height)
        traceBtn:SetText(blocked and "|cffff8888Trace|r" or "|cffffd100Trace|r")
        if blocked then traceBtn:SetBackdropColor(.24,.08,.10,1);traceBtn:SetBackdropBorderColor(.78,.24,.28,1) end
        traceBtn:SetScript("OnClick",function() A.TraceQuest(id) end);traceBtn:Show()
    end
end
local function openQuestFocus(id)
    -- From the table: switch to the tree, expand this quest and show it on the right.
    state.journalQuest=id;state.questTree=true;state.questTreeDungeon=state.journal
    state.questFocus=id;state.questFocusStep=id;state.questFocusRoot=id;state.railScrollToFocus=true
    local y=ui.detailScroll:GetVerticalScroll();state.questTableScroll=type(y)=="number" and y or 0
    ui.detailScroll:SetVerticalScroll(0);render()
end
local function closeQuestFocus()
    state.questTree=nil;state.questFocus=nil;state.questFocusStep=nil;state.questFocusRoot=nil
    render();ui.detailScroll:SetVerticalScroll(state.questTableScroll or 0)
end
local function questFocusValid()
    if not state.questTree then return false end
    if state.tab~="Loot Journal" or state.boss~="__quests" or state.questTreeDungeon~=state.journal or state.journalLanding~=false or state.journalCustomize then
        state.questTree=nil;state.questFocus=nil;state.questFocusStep=nil;state.questFocusRoot=nil;return false
    end
    local roots,any={},false
    for _,id in ipairs(A.DungeonQuestRoots(state.journal)) do if A.QuestVisible(id) then roots[id]=true;any=true end end
    if not any then state.questTree=nil;state.questFocus=nil;state.questFocusStep=nil;state.questFocusRoot=nil;return false end
    if state.questFocus and not roots[state.questFocus] then state.questFocus=nil end
    if state.questFocusRoot and not roots[state.questFocusRoot] then state.questFocusRoot=nil;state.questFocusStep=nil end
    return true
end
-- One table row per dungeon quest; clicking it opens the focus view.
local function questTableRow(id)
    local s=questState(id);local q=s.q
    local names,pins,startID,zone=questStarts(id)
    local second=s.restricted and (QuestColor.reason..s.reason.."|r") or (A.QuestClassLabel(q) and (QuestColor.muted..A.QuestClassLabel(q).."|r")) or nil
    local height=second and 46 or 34
    local r=row(ui.detail,s.color..A.Name("quest",id).."|r"..(second and ("\n"..second) or ""),function() openQuestFocus(id) end,"quest",id,0,height)
    r.text:ClearAllPoints();r.text:SetPoint("LEFT",QuestTable.nameX,0);r.text:SetWidth(QuestTable.nameW)
    if s.restricted then r.accent:SetColorTexture(.95,.28,.30,1);r:SetBackdropBorderColor(.48,.16,.18,.95) end
    local pre=""
    if s.hasChain then pre=(s.unmet>0 and not s.done and not s.active) and ("|cffff5555Pre ("..s.unmet..")|r") or "|cffffd100Pre|r" end
    local share=s.guide.share or "?"
    local startText
    if #names==0 then startText=QuestColor.muted.."Not recorded|r"
    else startText="|cff80cfff"..names[1]..(#names>1 and (" +"..(#names-1)) or "").."|r"..(zone and ("\n"..QuestColor.muted..zone.."|r") or "") end
    local values={(s.lowLevel and "|cffff7070" or "|cffe5e5e5")..tostring(q.required or "?").."|r",questSideText(s.side),pre,(share=="?" and QuestColor.muted or "|cffd9d9df")..share.."|r",startText}
    r.controls=r.controls or {}
    for i,value in ipairs(values) do
        local b=r.controls[i]
        if not b then b=button(r,"",0,0,QuestTable.widths[i],function() end);r.controls[i]=b end
        resetControl(b);b:ClearAllPoints();b:SetPoint("LEFT",r,"LEFT",QuestTable.xs[i],0);b:SetSize(QuestTable.widths[i],height-6);b:SetText(value)
        b.caption:SetFontObject(i==5 and "GameFontHighlightSmall" or NarrowFont);b:SetBackdropColor(0,0,0,0);b:SetBackdropBorderColor(0,0,0,0)
        if i==5 then
            b.caption:ClearAllPoints();b.caption:SetPoint("LEFT",b,"LEFT",4,0);b.caption:SetPoint("RIGHT",b,"RIGHT",-4,0);b.caption:SetJustifyH("LEFT")
        end
        if i==5 and #names>0 then
            b:SetScript("OnEnter",function(self)
                self:SetBackdropColor(.18,.22,.28,.45)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Starts")
                for _,name in ipairs(names) do GameTooltip:AddLine(name,.50,.81,1) end
                if zone then GameTooltip:AddLine(zone,.65,.65,.68) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function(self) self:SetBackdropColor(0,0,0,0);self:SetBackdropBorderColor(0,0,0,0);GameTooltip:Hide() end)
        else
            b:SetScript("OnEnter",nil);b:SetScript("OnLeave",nil)
        end
        b:SetScript("OnClick",function() if i==5 and startID then A.Open("npc",startID) else openQuestFocus(id) end end);b:Show()
    end
    questActions(r,id,pins,s.hasChain,s.chainBlocked,28)
    return r
end
local railKindTag={["Optional breadcrumb"]="optional",["ANY one"]="one of several",["Must be active"]="must be active",["Active or completed"]="active or completed",["Recorded unlock"]="recorded unlock"}
local function uniqueChain(id,trace)
    trace=trace or A.QuestTrace(id)
    local before,after,seen={},{},{[id]=true}
    for _,entry in ipairs(trace.before) do if not seen[entry.id] then before[#before+1]=entry;seen[entry.id]=true end end
    for _,entry in ipairs(trace.after) do if not seen[entry.id] then after[#after+1]=entry;seen[entry.id]=true end end
    return before,after,trace
end
-- Left column: every dungeon quest stays listed; the open one expands its recorded chain inline.
local function questTreeRail(visible)
    local rail=ui.journalRail
    local function pick(step,root) state.questFocusStep=step;state.questFocusRoot=root;ui.detailScroll:SetVerticalScroll(0);render() end
    local function mark(r,qid,s)
        if state.questFocusStep==qid then
            r:SetBackdropColor(unpack(Style.RowSelected));r:SetBackdropBorderColor(unpack(Style.RowSelectedBorder));r.accent:SetColorTexture(unpack(Style.Bullet))
        elseif s.restricted then r.accent:SetColorTexture(.95,.28,.30,1) end
    end
    local function label(caption)
        local g=row(rail,caption,nil,nil,nil,22,20)
        g:SetBackdropColor(0,0,0,0);g:SetBackdropBorderColor(0,0,0,0);g.accent:Hide();g.text:SetFontObject("GameFontNormalSmall")
        return g
    end
    local function child(n,qid,tag,root)
        local quest=D.Quests[qid]
        if quest and not A.FactionVisible(quest.faction) then row(rail,n..". [Faction-filtered step]",nil,nil,nil,22,26);return end
        local s=questState(qid)
        local second=(not s.recorded and "Not recorded in this snapshot") or s.reason or tag
        local caption=s.color..n..". "..A.Name("quest",qid).."|r"..(s.active and (" "..QuestColor.active.."< YOU ARE HERE|r") or "")..(second and ("\n"..(s.reason and QuestColor.reason or QuestColor.muted)..second.."|r") or "")
        local r=row(rail,caption,function() pick(qid,root) end,"quest",qid,22,second and 40 or 28)
        fitRow(rail,r,second and 40 or 28,10)
        mark(r,qid,s)
    end
    for _,id in ipairs(visible) do
        local s=questState(id);local open=state.questFocus==id
        if open and state.railScrollToFocus then state.railScrollTarget=math.max(0,rail.y-34);state.railScrollToFocus=nil end
        local second=s.reason or A.QuestClassLabel(s.q)
        local caption=(open and "[-] " or "[+] ")..s.color..A.Name("quest",id).."|r"..(second and ("\n"..(s.reason and QuestColor.reason or QuestColor.muted)..second.."|r") or "")
        local r=row(rail,caption,function()
            -- First click opens and selects; clicking the open, selected quest folds its chain.
            if state.questFocus==id and state.questFocusStep==id then state.questFocus=nil else state.questFocus=id end
            pick(id,id)
        end,"quest",id,0,second and 46 or 34)
        fitRow(rail,r,second and 46 or 34,12)
        mark(r,id,s)
        if open then
            local before,after,trace=uniqueChain(id)
            local n=0
            if #before>0 then label("|cffffd100Before this quest|r") end
            for _,entry in ipairs(before) do n=n+1;child(n,entry.id,railKindTag[entry.kind],id) end
            if #after>0 then label("|cffffd100Unlocks|r") end
            for _,entry in ipairs(after) do n=n+1;child(n,entry.id,railKindTag[entry.kind],id) end
            if #before==0 and #after==0 then label(QuestColor.muted.."No recorded chain links|r") end
            if trace.truncated then fitRow(rail,label(QuestColor.muted.."Long chain shortened; use Trace for more.|r"),20,8) end
            if trace.cycle then fitRow(rail,label(QuestColor.muted.."Circular links shown once.|r"),20,8) end
        end
    end
end
-- Right side: one step explained, quick-facts style.
local function questFocusDetail(qid,targetID)
    if not qid then text(QuestColor.muted.."Select a quest on the left. Click a quest again to fold its chain.|r",40);return end
    local s=questState(qid);local q=s.q
    local names,pins=questStarts(qid)
    local subtitle="Dungeon quest"
    if targetID and qid~=targetID then
        local before,after=uniqueChain(targetID);subtitle="Linked to "..A.Name("quest",targetID)
        for i,entry in ipairs(before) do if entry.id==qid then subtitle="Step "..i.." of "..#before.." before "..A.Name("quest",targetID) end end
        for _,entry in ipairs(after) do if entry.id==qid then subtitle="Unlocked after "..A.Name("quest",targetID) end end
    end
    local title=row(ui.detail,"|cffffffff"..A.Name("quest",qid).."|r\n"..QuestColor.muted..subtitle.."|r",nil,nil,nil,0,54)
    titleStyle(title)
    title.text:SetFontObject("GameFontNormalLarge");title.text:ClearAllPoints();title.text:SetPoint("LEFT",4,0);title.text:SetWidth(title:GetWidth()-180)
    questActions(title,qid,pins,true,s.chainBlocked,28)
    -- Where the quest starts comes first; the turn-in follows the objective.
    questRoleCards(qid,0,"Starts")
    if not s.recorded then text("Quest details not recorded in this snapshot.",30);return end
    local facts={}
    if q.required then facts[#facts+1]="Requires level "..((s.lowLevel and "|cffff7070" or "|cffffffff")..q.required.."|r") end
    facts[#facts+1]=questSideText(s.side)
    if q.level and q.level>0 then facts[#facts+1]="Quest level "..q.level end
    if A.QuestClassLabel(q) then facts[#facts+1]=A.QuestClassLabel(q) end
    if s.guide.share or qid==targetID then facts[#facts+1]="Share "..(s.guide.share or "?") end
    if q.repeatable then facts[#facts+1]="Repeatable" end
    fitRow(ui.detail,text(BULLET..table.concat(facts,"    "..BULLET),30),30,14)
    local status=s.done and (QuestColor.done.."Completed|r") or s.active and (QuestColor.active.."In your quest log|r") or s.restricted and (QuestColor.reason..(s.lowLevel and "Your level is below the requirement" or s.reason).."|r") or (QuestColor.muted.."Not started|r")
    if s.hasChain and not s.done and not s.active then
        status=status.."  •  "..(s.unmet>0 and ("|cffff5555"..s.unmet.." unfinished recorded prerequisite"..(s.unmet==1 and "" or "s").."|r") or (QuestColor.muted.."Has recorded prerequisites|r"))
    end
    text(status,30)
    local requirements={}
    for _,group in ipairs({{"allPrerequisites","Requires all: "},{"anyPrerequisites","Requires one of: "}}) do
        local list={}
        for _,pid in ipairs(q[group[1]] or {}) do list[#list+1]=pid>0 and A.Name("quest",pid) or "Special prerequisite (unresolved)" end
        if #list>0 then requirements[#requirements+1]=group[2]..table.concat(list,", ") end
    end
    if #requirements>0 then fitRow(ui.detail,text(table.concat(requirements,"\n"),30),30,14) end
    if #(q.objectives or {})>0 then
        heading("Objective")
        for _,objective in ipairs(q.objectives) do fitRow(ui.detail,text(objective,34),34,16) end
    end
    questRoleCards(qid,0,"Ends")
    local rewards={};for _,iid in ipairs(A.QuestItemRewards(qid)) do rewards[#rewards+1]=inlineGuideLink({kind="item",id=iid}) end
    if #rewards>0 then guideLine("Recorded item rewards: "..table.concat(rewards," • ")) end
    fitRow(ui.detail,text(QuestColor.muted.."Progress comes from your quest log. Missing records do not prove a quest is unavailable.|r",30),30,14)
end
local function questOutcomeView(id)
    local outcomes=A.QuestOutcomes(id)
    heading(A.Name("quest",id))
    local function visible(qid)
        return not D.Quests[qid] or A.FactionVisible(D.Quests[qid].faction)
    end
    local function open(qid) A.OpenQuestOutcomes(qid) end
    for _,qid in ipairs(outcomes.ends) do
        if visible(qid) then
            heading("Last recorded step • "..A.Name("quest",qid))
            local rewards={}
            for _,iid in ipairs(A.QuestItemRewards(qid)) do
                rewards[#rewards+1]=inlineGuideLink({kind="item",id=iid})
            end
            if #rewards>0 then guideLine("Item rewards • "..table.concat(rewards,"  "))
            else guideLine("No item reward recorded for this step.") end
        end
    end
    for _,entry in ipairs(outcomes.grants) do
        if visible(entry.questID) then
            guideLine("Class unlock • "..inlineGuideLink({kind="spell",id=entry.spellID,label=entry.name}).." • "..A.Name("quest",entry.questID))
        end
    end
    if #outcomes.next>0 then
        heading("Immediate follow-ups")
        for _,edge in ipairs(outcomes.next) do
            local qid=edge.id
            if visible(qid) then row(ui.detail,A.Name("quest",qid).." • "..edge.kind,function() open(qid) end,"quest",qid,0,30) end
        end
    else guideLine("No follow-up recorded.") end
    if #outcomes.ends==0 or outcomes.limited then guideLine("Only part of the chain is known or visible in this trace.") end
    row(ui.detail,"[+] Expand quest chain",function() state.questMode="chain";ui.detailScroll:SetVerticalScroll(0);render() end,nil,nil,0,32)
end
local function questTraceView(id)
    ui.title:SetText("F1 Quest");ui.page:SetText("")
    if state.questMode=="outcomes" then questOutcomeView(id);return end
    local fromJournal=state.questTrace~=nil
    tabStrip({{value="chain",label="F1 Quest • Chain"},{value="details",label="Quest details"}},state.questMode or "chain",function(value)
        state.questMode=value;ui.detailScroll:SetVerticalScroll(0);render()
    end,2)
    if state.questMode=="details" then entityDetail("quest",id);return end
    local trace=A.QuestTrace(id)
    local function focus(qid)
        if fromJournal then state.questTrace=qid else state.entity={kind="quest",id=qid} end
        ui.detailScroll:SetVerticalScroll(0);render()
    end
    local function requirements(q)
        local parts={}
        for _,group in ipairs({{"allPrerequisites","ALL required: "},{"anyPrerequisites","ANY one: "},{"exclusiveTo","Exclusive with: "}}) do
            local names={}
            for _,qid in ipairs(q[group[1]] or {}) do names[#names+1]=qid>0 and A.Name("quest",qid) or "Special prerequisite (unresolved)" end
            if #names>0 then parts[#parts+1]=group[2]..table.concat(names,", ") end
        end
        if q.parentQuest then parts[#parts+1]="Must be active: "..A.Name("quest",q.parentQuest) end
        if q.unavailableWhenQuestActiveOrComplete then parts[#parts+1]="Unavailable once active/completed: "..A.Name("quest",q.unavailableWhenQuestActiveOrComplete) end
        if q.availableUntilCompleted then parts[#parts+1]="Available until completed: "..A.Name("quest",q.availableUntilCompleted) end
        if q.disabledByQuest then parts[#parts+1]="Unavailable while active: "..A.Name("quest",q.disabledByQuest) end
        if #parts>0 then guideLine(table.concat(parts," • ")) end
    end
    local function node(qid,indent,relation,current)
        local q=D.Quests[qid]
        if not current and q and not A.FactionVisible(q.faction) then
            row(ui.detail,"["..q.faction.." step hidden by faction settings]",nil,nil,nil,indent,26)
            return
        end
        if not current and state.traceHideCompleted and A.QuestDone(qid) then return end
        local caption=(A.QuestDone(qid) and "|cff72e6a0[Done]|r " or "[ ] ")..A.Name("quest",qid)
        if current then caption=caption.."  |cffffd166< TARGET QUEST|r" end
        local progress=A.QuestProgress(qid)
        if progress=="In your quest log" then caption=caption.."  |cff72e6a0< IN YOUR QUEST LOG|r"
        elseif progress=="Different class" then caption=caption.."  |cff999999< "..(A.QuestClassLabel(q) or "Different class").."|r"
        elseif progress=="Next recorded step" then caption=caption.."  |cffbbbbbb< NEXT RECORDED STEP|r" end
        if q and q.repeatable then caption=caption.."  |cff999999Repeatable|r" end
        local r=row(ui.detail,caption,function() focus(qid) end,"quest",qid,indent,32)
        favoriteButton(r,"quest",qid)
        if relation then row(ui.detail,relation,nil,nil,nil,indent,24) end
        if not q then row(ui.detail,"Quest details missing from this snapshot.",nil,nil,nil,indent,26);return end
        local info={}
        if q.level and q.level>0 then info[#info+1]="Quest level "..q.level end
        if q.required and q.required>0 then info[#info+1]="Requires level "..q.required end
        if q.faction and q.faction~="Unknown" then info[#info+1]=q.faction=="Both" and "Both factions" or q.faction end
        if A.QuestClassLabel(q) then info[#info+1]=A.QuestClassLabel(q) end
        if current then
            if #info>0 then guideLine(table.concat(info," • ")) end
            for _,objective in ipairs(q.objectives or {}) do guideLine(objective) end
            requirements(q);questRoleCards(qid,indent)
        elseif #(q.allPrerequisites or {})>1 or #(q.anyPrerequisites or {})>1 or #(q.exclusiveTo or {})>0 then requirements(q) end
        local rewards={}
        for _,iid in ipairs(A.QuestItemRewards(qid)) do rewards[#rewards+1]=inlineGuideLink({kind="item",id=iid}) end
        if #rewards>0 then guideLine("Recorded item rewards: "..table.concat(rewards," • ")) end
    end
    row(ui.detail,(state.traceHideCompleted and "[x] " or "[ ] ").."Hide completed steps",function() state.traceHideCompleted=not state.traceHideCompleted;render() end,nil,nil,0,26)
    text("Target highlights what you are looking for. Progress comes from your quest log and completed steps. Next recorded steps may still have level or other requirements.",32)
    if #trace.before>0 then
        heading("Before this quest")
        for _,e in ipairs(trace.before) do node(e.id,math.min(72,(trace.maxDepth-e.depth)*12),e.kind,false) end
    end
    heading("Target quest")
    node(id,0,nil,true)
    if #trace.after>0 then
        heading("Unlocks & follow-ups")
        for _,e in ipairs(trace.after) do node(e.id,math.min(72,(e.depth-1)*12),e.kind,false) end
    else text("No further quest links recorded. This is not confirmation that the chain ends here.",32) end
    if trace.truncated then text("Long chain: showing a bounded section. Select a quest to continue tracing.",32) end
    if trace.cycle then text("Repeated or circular links detected; each step is shown once per direction.",32) end
end

local function factionLabel(faction)
    if faction=="Alliance" then return "|cff80baffAlliance|r" end
    if faction=="Horde" then return "|cffff8585Horde|r" end
    return "|cffccccccNeutral|r"
end
local function attuneDetail(g)
    heading(g.name)
    text(factionLabel(g.faction)..((g.level or 0)>0 and ("  •  Level "..g.level) or "").."  •  Click a quest to expand.",30)
    text("Includes class unlocks, keys and optional quests; not all are entry requirements.",36)
    for ci,original in ipairs(g.chains) do
        local c={title=original.title,steps={}}
        for _,step in ipairs(original.steps) do if A.QuestVisible(step.id) then c.steps[#c.steps+1]=step end end
        if #c.steps>0 then
        local key="attune:"..tostring(state.attune)..":"..ci
        local done,total=A.ChainProgress(c)
        local single=#c.steps==1
        if not single then
            row(ui.detail,(state.expanded[key] and "[-] " or "[+] ")..c.title.."  ("..done.."/"..total..")",function()
                state.expanded[key]=not state.expanded[key]; render()
            end,nil,nil,0,32)
        end
        if single or state.expanded[key] then
            for si,s in ipairs(c.steps) do
                local skey=key..":"..si
                local indent=single and 0 or 18
                row(ui.detail,(state.expanded[skey] and "[-] " or "[+] ")..(A.QuestDone(s.id) and "|cff72e6a0[Done]|r " or "[ ] ")..(single and "" or (si..". "))..s.name,function()
                    state.expanded[skey]=not state.expanded[skey]; render()
                end,nil,nil,indent,32)
                if state.expanded[skey] then
                    local q=D.Quests[s.id]
                    questRoleCards(s.id,indent+18)
                    for _,obj in ipairs((q and q.objectives) or s.objs or {}) do row(ui.detail,obj,nil,nil,nil,indent+18,65) end
                    row(ui.detail,"View quest details",function() A.Open("quest",s.id) end,nil,nil,indent+18)
                end
            end
        end
        end
    end
end
local function databaseBrowser()
    return navGroup(state.tab)=="Database"
end
local navigationArt={["Settings & Credits"]="Home",["Gear Journal"]="Dungeons",["BiS & Talents"]="Classes",["Profession Guides"]="Professions",["Quests & Attunements"]="Quests",Database="Database",loot="Dungeons",class="Classes",profession="Professions",quest="Quests",database="Database"}
local navIcons={["Gear Journal"]="NavGear",["Class Guides"]="NavClass",["BiS & Talents"]="NavClass",["Profession Guides"]="NavProfession",["Quests & Attunements"]="NavQuest",Database="NavDatabase",["Settings & Credits"]="NavSettings"}
local navGlow={["Gear Journal"]={.16,.36,.60},["Class Guides"]={.29,.23,.60},["BiS & Talents"]={.29,.23,.60},["Profession Guides"]={.16,.43,.54},["Quests & Attunements"]={.18,.35,.63},Database={.14,.38,.48},["Settings & Credits"]={.23,.27,.38}}
local function illustratedButton(button,key)
    local glow=button:CreateTexture(nil,"BACKGROUND",nil,1)
    glow:SetTexture(ICONS.."Glow");glow:SetTexCoord(.05,.95,.5,1)
    glow:SetPoint("TOPLEFT",1,-1);glow:SetPoint("BOTTOMRIGHT",-1,1)
    local c=navGlow[key] or {.2,.3,.5};glow:SetVertexColor(c[1],c[2],c[3],1)
    local icon=button:CreateTexture(nil,"ARTWORK")
    icon:SetTexture(ICONS..(navIcons[key] or "NavGear"));icon:SetTexCoord(0,1,0,1)
    icon:SetSize(26,26);icon:SetPoint("LEFT",12,0)
    button.navigationImage=icon;button.navigationGlow=glow
    button.caption:ClearAllPoints();button.caption:SetPoint("LEFT",icon,"RIGHT",10,0);button.caption:SetWidth(button:GetWidth()-56)
    button.caption:SetJustifyH("LEFT");button.caption:SetFontObject("GameFontHighlight")
    button:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(Style.Accent)) end)
    button:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(Style.ButtonBorder)) end)
end
local function homeLanding()
    local banner=row(ui.detail,"|cffffd100F1 FOREVER|r  |cffa3a3a8by Sarcasm|r",nil,nil,nil,0,46)
    banner:SetBackdropColor(.10,.10,.105,1)
    banner:SetBackdropBorderColor(unpack(Style.HeadingBorder))
    banner.accent:SetWidth(4); banner.accent:SetColorTexture(unpack(Style.Gold)); banner.accent:Show()
    banner.text:SetFontObject("GameFontNormalLarge")
    text("Your in-game reference. Find loot, plan a profession, explore a class, or follow a quest.",30)

end
local function professionZoneName(id)
    local info=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    return info and info.name or ("Map "..id)
end
local function playerProfessionZone()
    local id=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    -- Floor maps may belong to a city or zone that owns the recorded NPC spawns.
    for depth=1,8 do
        if not id or id==0 then return end
        if ui.professionMaps[id] then return id end
        local info=C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        if not info or info.mapType==3 then return id end
        id=info.parentMapID
    end
end
local function professionTabs()
    if state.tab=="Recipes" then
        tabStrip({{value="Guide",label="Profession Guides"},{value="Recipes",label="Recipes"},{value="Trainers",label="Trainers"},{value="Vendors",label="Vendors"}},state.professionView or "Recipes",function(value)
            state.professionView=value;state.searchScope="This page";state.entity=nil;state.page=1;ui.detailScroll:SetVerticalScroll(0);render()
        end,4)
    end
end
local function secondaryGuide(profession,data)
    state.secondarySection=state.secondarySection or {}
    local section=state.secondarySection[profession] or "Training"
    if section=="Leveling" then section="Training" end
    tabStrip({{value="Recipes",label=profession=="Fishing" and "Fishing extras" or "Recorded recipes"},{value="Training",label="Training & Unlocks"},{value="Shopping",label="What to buy"},{value="Quests",label="Profession quests"},{value="Trainers",label="Trainer locations"}},section,function(value)
        state.secondarySection[profession]=value;ui.detailScroll:SetVerticalScroll(0);render()
    end,5)
    local function npcEntry(id,location)
        local area,x,y=A.NPCLocation(id,section=="Trainers" and ui.activeProfessionMap or nil)
        guideLine(inlineGuideLink({kind="npc",id=id})..(location and (" • "..location) or ""))
        if area and A.ValidPoint(x,y) then
            row(ui.detail,string.format("Map pin • %.1f, %.1f",x,y),function() A.Pin(area,x,y) end,nil,nil,nil,0,26)
        end
    end
    if section=="Shopping" then
        text("Recorded sellers for books, recipes and supplies. Check vendor stock and prices in-game. Skill stages are guide suggestions.",48)
        local shown=0
        for _,entry in ipairs(data.shopping or {}) do
            if A.FactionVisible(entry.faction) and A.NameMatches(A.Name("item",entry.item),state.query,entry.item) then
                shown=shown+1;heading(entry.stage.." • "..entry.faction.." • "..entry.category)
                link("item",entry.item)
                npcEntry(entry.npc)
            end
        end
        if shown==0 then text("No reviewed purchases match. Recipe pages may have additional recorded sources.",40) end
        return true
    elseif section=="Quests" then
        text("Open a quest for recorded requirements, objectives, rewards and its F1 Quest chain. Shared and unknown factions follow your Settings choices.",48)
        for _,id in ipairs(data.quests or {}) do if A.QuestVisible(id) and A.NameMatches(A.Name("quest",id),state.query,id) then link("quest",id) end end
        return true
    elseif section=="Training" then
        for _,entry in ipairs(data.training) do
            heading(entry.title);guideLine(entry.text)
            local refs={}
            for _,ref in ipairs(entry.refs or {}) do
                if ref.kind=="npc" then npcEntry(ref.id) else refs[#refs+1]=inlineGuideLink(ref) end
            end
            if #refs>0 then guideLine(table.concat(refs,"  •  ")) end
        end
        return true
    elseif section=="Trainers" then
        for _,npc in ipairs(data.trainers) do
            local entity=D.NPCs[npc.id]
            if (not ui.activeProfessionMap or A.ProfessionNPCArea(entity,ui.activeProfessionMap)) and A.FactionVisible(entity and entity.faction) and (A.NameMatches(A.Name("npc",npc.id),state.query,npc.id) or A.NameMatches(npc.location,state.query)) then npcEntry(npc.id,npc.location) end
        end
        return true
    elseif section=="Recipes" then
        for _,recipe in ipairs(data.recipes) do
            if A.NameMatches(recipe.name,state.query,recipe.id) then
                guideLine((recipe.skill and ("|cffbbbbbbSkill "..recipe.skill.."|r  •  ") or "")..inlineGuideLink({kind=recipe.compiled and "recipe" or "spell",id=recipe.id,label=recipe.name}))
                local refs={}
                for _,ref in ipairs(recipe.refs or {}) do refs[#refs+1]=inlineGuideLink(ref) end
                guideLine(recipe.acquisition..(#refs>0 and ("  •  "..table.concat(refs,"  •  ")) or ""))
                local compiled=D.Recipes[recipe.id];local materials={}
                if compiled then for _,id in ipairs(sorted(compiled.reagents)) do materials[#materials+1]=inlineGuideLink({kind="item",id=id}).." × "..compiled.reagents[id] end end
                if #materials>0 then guideLine("Reagents: "..table.concat(materials,"  •  ")) end
            end
        end
        return true
    end
    return false
end
local function listPager(key, pages, count)
    local current=state[key]
    ui.page:SetText(pages>1 and ("Page "..current.." / "..pages.."  •  "..count.." results") or (count.." results"))
    ui.page:Show()
    if pages<=1 then return end
    ui.changeListPage=function(delta)
        local target=current+delta
        if target<1 or target>pages then return end
        state[key]=target
        ui.detailScroll:SetVerticalScroll(0)
        render()
    end
    for index,b in ipairs({ui.previous,ui.next}) do
        local enabled=(index==1 and current>1) or (index==2 and current<pages)
        b:SetEnabled(enabled)
        b:SetAlpha(enabled and 1 or .35)
        b:Show()
    end
end
local function professionReference(profession)
    local c=A.ProfessionCatalog(profession)
    state.professionSections=state.professionSections or {}
    local section=state.professionSections[profession] or "Leveling"
    local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
    local tabs={{value="Leveling",label="Leveling"},{value="recipes",label="All recipes ("..count(c.recipes)..")"},{value="manuals",label="Recipe books ("..count(c.manuals)..")"},{value="items",label="Crafted items ("..count(c.items)..")"},{value="trainers",label="Trainers ("..count(c.trainers)..")"},{value="vendors",label="Vendors ("..count(c.vendors)..")"},{value="quests",label="Quests & unlocks ("..count(c.quests)..")"}}
    local extra=(D.SecondaryGuides or {})[profession]
    if extra then tabs[#tabs+1]={value="notes",label="Field notes"} end
    tabStrip(tabs,section,function(value) state.professionSections[profession]=value;state.referencePage=1;ui.detailScroll:SetVerticalScroll(0);render() end,#tabs)
    if section=="notes" and extra then secondaryGuide(profession,extra);return true end
    if section=="Leveling" then return false end
    local function source(kind,id,prefix)
        if kind=="quest" then journalQuest(id);return end
        local caption=(prefix or "")..inlineGuideLink({kind=kind,id=id})
        local area,x,y
        if kind=="npc" then
            area,x,y=A.NPCLocation(id,(section=="trainers" or section=="vendors") and ui.activeProfessionMap or nil)
            local n=D.NPCs[id]
            if n and n.faction then caption=caption.." • "..(({A="Alliance",H="Horde",AH="Both"})[n.faction] or n.faction) end
            if area then caption=caption.." • "..((C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)) or tostring(area))..string.format(" %.1f, %.1f",x,y) end
        end
        guideLine(caption)
        if area then row(ui.detail,"Show pin",function() A.Pin(area,x,y) end,nil,nil,18,24) end
    end
    local function acquisitions(kind,id)
        local found=false
        for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do
            local ft,fi,tt,ti,k=A.Edge(n)
            if tt==kind and ti==id and (k=="Teaches" or k=="Sells" or k=="Drops" or k=="Contains" or k=="Rewards") then
                found=true;source(ft,fi,A.RelationLabel(k,true))
                if ft=="item" and k=="Teaches" then
                    for _,sn in ipairs(A.index[A.Key("item",fi)] or {}) do
                        local st,si,dt,di,sk=A.Edge(sn)
                        if dt=="item" and di==fi and (sk=="Sells" or sk=="Drops" or sk=="Contains" or sk=="Rewards") then source(st,si,A.RelationLabel(sk,true)) end
                    end
                end
            end
        end
        if not found then text("Acquisition details are being added. A missing source does not mean unavailable.",30) end
    end
    local kind=section=="recipes" and "recipe" or section=="quests" and "quest" or (section=="trainers" or section=="vendors") and "npc" or "item"
    local low,high
    if section=="recipes" then
        tabStrip({{value="All skills",label="All skills"},{value="1–75",label="1–75"},{value="75–150",label="75–150"},{value="150–225",label="150–225"},{value="225–300",label="225–300"}},state.professionRange or "All skills",function(value) state.professionRange=value;state.referencePage=1;render() end,5)
        low,high=(state.professionRange or ""):match("(%d+)%D+(%d+)");low=tonumber(low);high=tonumber(high)
    end
    local ids={}
    for id in pairs(c[section] or {}) do
        local e=A.Entity(kind,id)
        if (kind~="npc" or not ui.activeProfessionMap or A.ProfessionNPCArea(e,ui.activeProfessionMap)) and (not low or (e and e.skill and e.skill>=low and e.skill<=high)) and A.NameMatches(A.Name(kind,id),state.query,id) and (kind~="quest" or A.QuestVisible(id)) and (kind~="npc" or A.FactionVisible(e and (({A="Alliance",H="Horde",AH="Both"})[e.faction] or e.faction))) then ids[#ids+1]=id end
    end
    table.sort(ids,function(a,b)
        local x,y=A.Entity(kind,a),A.Entity(kind,b)
        if kind=="recipe" and (x.skill or 9999)~=(y.skill or 9999) then return (x.skill or 9999)<(y.skill or 9999) end
        return A.Name(kind,a)<A.Name(kind,b)
    end)
    local pages=math.max(1,math.ceil(#ids/40));state.referencePage=math.min(state.referencePage or 1,pages)
    listPager("referencePage",pages,#ids)
    for pos=(state.referencePage-1)*40+1,math.min(#ids,state.referencePage*40) do
        local id=ids[pos];local e=A.Entity(kind,id);local key="profession:"..profession..":"..section..":"..id
        if kind=="quest" then journalQuest(id)
        else
            local r=row(ui.detail,(state.expanded[key] and "[-] " or "[+] ")..A.Label(kind,id)..(e and e.skill and (" • Skill "..e.skill) or ""),function() state.expanded[key]=not state.expanded[key];render() end,kind,id,0,30)
            favoriteButton(r,kind,id)
            if state.expanded[key] then
                if kind=="recipe" then
                    local mats={};for _,iid in ipairs(sorted(e.reagents)) do mats[#mats+1]=inlineGuideLink({kind="item",id=iid}).." × "..e.reagents[iid] end
                    if #mats>0 then guideLine("Reagents: "..table.concat(mats," • ")) end
                    for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do local ft,fi,tt,ti,k=A.Edge(n);if ft=="recipe" and fi==id and k=="Crafts" then source(tt,ti,"Creates: ") end end
                    acquisitions(kind,id)
                elseif kind=="npc" then
                    source(kind,id)
                    for _,rank in ipairs(e and e.professionRanks or {}) do guideLine(inlineGuideLink({kind="spell",id=rank.spellID,label=rank.name.." — "..rank.rank})..(rank.requiredSkill and (" • Skill "..rank.requiredSkill) or "")) end
                    local found=false
                    for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do
                        local ft,fi,tt,ti,k=A.Edge(n)
                        if ft=="npc" and fi==id and ((k=="Teaches" and tt=="recipe" and c.recipes[ti]) or (k=="Sells" and tt=="item" and c.manuals[ti])) then found=true;source(tt,ti,A.RelationLabel(k,false)) end
                    end
                    if not found then text("Service details are being added in updates.",28) end
                elseif section=="items" then
                    for _,n in ipairs(A.index[A.Key(kind,id)] or {}) do local ft,fi,tt,ti,k=A.Edge(n);if tt=="item" and ti==id and k=="Crafts" and c.recipes[fi] then source(ft,fi,"Created by: ");acquisitions(ft,fi) end end
                else acquisitions(kind,id) end
            end
        end
    end
    if #ids==0 then text("No recorded entries match. More relationships will be added as they are verified.",35) end
    return true
end

-- These are guide directions. Keep disputed doctor services out of the trainer database.
-- Rank-specific directions from the Forever WoW-professions guides.
-- Keep these leveling hints separate from captured NPC training services.
local rankVisits={
    Alchemy={Expert={{4160,"Darnassus"}},Artisan={{7948,"Feathermoon Stronghold, Feralas"},{1386,"Stonard, Swamp of Sorrows"}}},
    Blacksmithing={Artisan={{2836,"Booty Bay, Stranglethorn Vale"}}},
    Enchanting={Artisan={{11073,"Uldaman, Badlands. Clear her room to make her appear"}}},
    Engineering={Expert={{5174,"Ironforge"}},Artisan={{8736,"Gadgetzan, Tanaris, outside the inn"}}},
    Leatherworking={Journeyman={{5564,"Stormwind City"}},Expert={{4212,"Darnassus"}},
        Artisan={{11097,"Aerie Peak, The Hinterlands"},{11098,"Camp Mojache, Feralas"}}},
    Tailoring={Expert={{1346,"Stormwind City"}},Artisan={{11052,"Theramore, Dustwallow Marsh"},{2399,"Tarren Mill, Hillsbrad Foothills"}}}
}
local function levelingTip(profession,stage)
    local function ref(kind,id) return inlineGuideLink({kind=kind,id=id}) end
    local function side(faction,content)
        if A.FactionVisible(faction) then guideLine(faction.." • "..content) end
    end
    if profession=="First Aid" and stage==3 then
        guideLine("Read "..ref("item",16084).." to raise your cap to 225. Buy the next two manuals on the same trip.")
        side("Alliance",ref("npc",2805).." in Stromgarde Keep, Arathi Highlands.")
        side("Horde",ref("npc",13476).." in Brackenwall Village, Dustwallow Marsh.")
        guideLine("At 180 read "..ref("item",16112)..". At 210 read "..ref("item",16113)..".")
    elseif profession=="First Aid" and stage==4 then
        guideLine("At character level 35 and First Aid 225, complete your faction’s Triage quest to raise your cap to 300.")
        side("Alliance",ref("quest",6624).." with "..ref("npc",12939).." in Theramore, Dustwallow Marsh.")
        side("Horde",ref("quest",6622).." with "..ref("npc",12920).." in Hammerfall, Arathi Highlands.")

    elseif profession=="Fishing" and stage==3 then
        guideLine("Buy "..ref("item",16083).." from "..ref("npc",2626).." in Booty Bay, Stranglethorn Vale. Read it to raise your cap to 225.")
    elseif profession=="Fishing" and stage==4 then
        guideLine("At level 35 and Fishing 225, visit "..ref("npc",12919).." in Dustwallow Marsh. Accept "..ref("quest",6607)..", catch the four quest fish and return to him.")
    elseif profession=="Cooking" and stage==3 then
        guideLine("Read "..ref("item",16072).." to raise your Cooking cap to 225.")
        side("Alliance",ref("npc",3955).." sells the book in Ashenvale.")
        side("Horde",ref("npc",12033).." sells the book in Shadowprey Village, Desolace.")
    elseif profession=="Cooking" and stage==4 then
        guideLine("At level 35 and Cooking 225, take "..ref("quest",6610).." from "..ref("npc",8125).." in Gadgetzan, Tanaris.")
        guideLine("Bring 12 "..ref("item",12207)..", 10 "..ref("item",7974).." and 20 "..ref("item",8932)..".")
    else
        local rank=({"Apprentice","Journeyman","Expert","Artisan"})[stage]
        local cap=({75,150,225,300})[stage]
        guideLine("Learn "..rank.." "..profession.." to raise your skill cap to "..cap..".")
        local shown={}
        local labels={A="Alliance",H="Horde",AH="Both factions"}
        local visits=rankVisits[profession] and rankVisits[profession][rank]
        for _,visit in ipairs(visits or {}) do
            local npc=D.NPCs[visit[1]]
            if npc and A.FactionVisible(npc.faction) then
                local label=labels[npc.faction] or "Trainer"
                guideLine(label.." • "..ref("npc",visit[1]).." in "..visit[2])
                shown[label]=true
            end
        end
        if visits and stage==4 then guideLine("You can learn Artisan at character level 35 and profession skill 200.") end
        for _,id in ipairs(sorted(A.ProfessionCatalog(profession).trainers)) do
            local n=D.NPCs[id]
            for _,service in ipairs(n and n.professionRanks or {}) do
                if service.name==profession and service.rank and service.rank:match("^%s*(.-)%s*$")==rank and A.FactionVisible(n.faction) then
                    local faction=labels[n.faction] or "Trainer"
                    if not shown[faction] then
                        shown[faction]=true
                        local area=A.NPCLocation(id)
                        local map=area and D.Maps[area]
                        guideLine(faction.." • "..ref("npc",id)..(map and (" in "..professionZoneName(map)) or "")..(service.requiredSkill and (" • Available at skill "..service.requiredSkill) or ""))
                    end
                end
            end
        end
        if not next(shown) then
            row(ui.detail,"Browse "..profession.." trainers and check available ranks",function()
                state.professionSections[profession]="trainers";state.referencePage=1
                ui.detailScroll:SetVerticalScroll(0);render()
            end)
        end
    end
end
local function professionGuide()
    professionTabs()
    ui.page:SetText("")
    local guides={}
    for name,steps in pairs(D.ProfessionGuides or {}) do guides[name]=steps end
    for _,r in pairs(D.Recipes) do if r.profession then guides[r.profession]=guides[r.profession] or {} end end
    for _,n in pairs(D.NPCs) do if n.trainerProfession then guides[n.trainerProfession]=guides[n.trainerProfession] or {} end end
    for name in pairs(D.SecondaryGuides or {}) do guides[name]=guides[name] or {} end
    local profession=state.pageFilter
    if profession=="All" then
        heading("Profession Guides")
        local names=sorted(professionIcons)
        local width=ui.detail:GetWidth()/4
        for i=1,#names,4 do
            local base=row(ui.detail,"",nil,nil,nil,0,84)
            base.controls=base.controls or {}
            for col=0,3 do
                local name=names[i+col]
                if name then
                    local chosen=name
                    local b=base.controls[col+1]
                    if not b then b=button(base,"",0,0,width-6,function() end);base.controls[col+1]=b end
                    resetControl(b)
                    b:ClearAllPoints();b:SetPoint("TOPLEFT",col*width,0);b:SetSize(width-6,78)
                    b:SetText(name);b.professionTile=name
                    b.picture=b.picture or b:CreateTexture(nil,"ARTWORK")
                    b.picture:ClearAllPoints();b.picture:SetPoint("LEFT",12,0);b.picture:SetSize(42,42)
                    b.picture:SetTexture(professionIcons[name]);b.picture:SetTexCoord(.08,.92,.08,.92);b.picture:Show()
                    b.caption:ClearAllPoints();b.caption:SetPoint("LEFT",64,0);b.caption:SetWidth(width-80);b.caption:SetJustifyH("LEFT")
                    b:SetScript("OnClick",function()
                        A.CaptureNavigationScroll();state.professionSections=state.professionSections or {};state.professionSections[chosen]="Leveling";state.pageFilter=chosen;state.professionRange="All skills"
                        ui.detailScroll:SetVerticalScroll(0);render()
                    end)
                    b:Show()
                end
            end
        end
        return
    end
    heading(profession.." • Profession reference")
    if professionReference(profession) then return end
    local steps=guides[profession] or {}
    local fishing=profession=="Fishing" and D.SecondaryGuides and D.SecondaryGuides.Fishing
    local ranges={{value="All skills",label="All skills"},{value="1–75",label="1–75"},{value="75–150",label="75–150"},{value="150–225",label="150–225"},{value="225–300",label="225–300"}}
    tabStrip(ranges,state.professionRange or "All skills",function(value) state.professionRange=value;ui.detailScroll:SetVerticalScroll(0);render() end,5)
    local low,high=(state.professionRange or ""):match("(%d+)%D+(%d+)")
    low=tonumber(low)
    local count=0
    for stage=1,4 do
        local first=({1,75,150,225})[stage]
        local last=stage*75
        if not low or low==first then
            heading(first.."–"..last.." • "..({"Apprentice","Journeyman","Expert","Artisan"})[stage])
            levelingTip(profession,stage)
            for _,route in ipairs(fishing and fishing.routes or {}) do
                if route.low<last and route.high>first and A.NameMatches(route.text,state.query) then
                    guideLine(route.low.."–"..route.high.." • "..route.text);count=count+1
                end
            end
            for _,step in ipairs(steps) do
                if step.low<last and (step.low>=first or (stage==1 and step.low==0) or (low and step.high>first)) and (A.NameMatches(step.name,state.query,step.id) or A.NameMatches(step.materials,state.query)) then
                    count=count+1
                    guideLine("|cffbbbbbb"..step.low.."–"..step.high.."|r  •  "..inlineGuideLink({kind=step.kind,id=step.id,label=step.name})..(step.crafts and ("  × "..step.crafts.." crafts") or ""))
                    if profession=="First Aid" and (step.low==240 or step.low==260 or step.low==290) then
                        guideLine("At skill "..step.low..", the guide directs you back to your Triage doctor for this bandage.")
                    end
                    local materials=step.materials
                    -- Substitute known material labels once, without interpreting names as Lua patterns.
                    local pieces={}; local cursor=1
                    while cursor<=#materials do
                        local first,last,chosen
                        for _,ref in ipairs(step.materialLinks or {}) do
                            local a,b=materials:find(ref.name,cursor,true)
                            if a and (not first or a<first) then first,last,chosen=a,b,ref end
                        end
                        if not first then pieces[#pieces+1]=materials:sub(cursor);break end
                        pieces[#pieces+1]=materials:sub(cursor,first-1)
                        pieces[#pieces+1]=inlineGuideLink({kind="item",id=chosen.id,label=chosen.name})
                        cursor=last+1
                    end
                    guideLine("Materials: "..table.concat(pieces))
                end
            end
        end
    end
    if count==0 and state.query~="" then text("No recorded steps match this search.",30) end
end
local function listRows(entries)
    local last=math.max(1,math.ceil(#entries/PAGE_ROWS)); state.page=math.min(state.page,last)
    state.results=entries
    local browser=databaseBrowser()
    if browser and state.entity then return end
    if browser or ui.leftPanel:IsShown() then listPager("page",last,#entries) end
    if browser then professionTabs() end
    for i=(state.page-1)*PAGE_ROWS+1,math.min(#entries,state.page*PAGE_ROWS) do
        local e=entries[i]
        local r=row(browser and ui.detail or ui.list,e.label or (e.kind and A.Label(e.kind,e.id)) or e.name,function(mouse)
            if e.action then e.action(mouse) else A.Open(e.kind,e.id) end
        end,e.kind,e.id,0,29)
        r.text:SetWidth(r:GetWidth()-105)
        if not r.meta then
            r.meta=label(r,"",0,0,70,"GameFontDisableSmall")
            r.meta:SetJustifyH("RIGHT"); r.meta:SetJustifyV("MIDDLE")
        end
        local entity=e.kind and A.Entity(e.kind,e.id)
        local shortMeta=""
        if e.faction then shortMeta=factionLabel(e.faction)
        elseif entity then
            if e.kind=="quest" and A.QuestDone(e.id) then shortMeta="|cff34d399Done|r"
            elseif entity.skill then shortMeta=skillColor(entity.skill).."Sk "..entity.skill.."|r"
            elseif entity.level and entity.level>0 then shortMeta="|cffffd100Lv "..entity.level.."|r" end
        end
        r.meta:SetText(shortMeta); r.meta:Show()
        if browser then
            local fields={}
            if entity then
                if entity.profession or entity.trainerProfession then
                    fields[#fields+1]="|cffffd100"..(entity.profession or entity.trainerProfession).."|r"
                end
                if e.kind=="npc" and entity.faction then
                    local fl=({A="|cff60a5faAlliance|r",Alliance="|cff60a5faAlliance|r",H="|cfff87171Horde|r",Horde="|cfff87171Horde|r",AH="|cffa3a3a8Both|r"})[entity.faction]
                    if fl then fields[#fields+1]=fl end
                end
                local areas=sorted(entity.spawns)
                if e.kind=="npc" and ui.activeProfessionMap then areas[1]=A.ProfessionNPCArea(entity,ui.activeProfessionMap) or areas[1] end
                if areas[1] then
                    fields[#fields+1]="|cffa3a3a8"..((C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areas[1])) or tostring(areas[1])).."|r"
                end
                if e.kind=="quest" and A.QuestDone(e.id) then
                    fields[#fields+1]="|cff34d399Completed|r"
                end
                if entity.skill then
                    fields[#fields+1]=skillColor(entity.skill).."Skill "..entity.skill.."|r"
                elseif entity.level and entity.level>0 then
                    fields[#fields+1]="|cffffd100"..(e.kind=="item" and "iLvl " or "Lv ")..entity.level.."|r"
                end
                if e.kind=="item" and entity.required and entity.required>0 then
                    fields[#fields+1]="|cffa3a3a8Req "..entity.required.."|r"
                end
            end
            r.text:SetWidth(r:GetWidth()-420);r.meta:ClearAllPoints();r.meta:SetPoint("RIGHT",r,"RIGHT",-12,0);r.meta:SetWidth(390);r.meta:SetText(table.concat(fields,"  •  "));r.meta:SetJustifyH("RIGHT")
        else
            r.meta:ClearAllPoints();r.meta:SetPoint("RIGHT",r,"RIGHT",-10,0);r.meta:SetWidth(72)
        end
        if e.faction then
            if e.faction=="Alliance" then
                r:SetBackdropColor(.07,.11,.18,.98); r.accent:SetColorTexture(.28,.60,.98,1); r.accent:Show()
            elseif e.faction=="Horde" then
                r:SetBackdropColor(.18,.08,.09,.98); r.accent:SetColorTexture(.92,.30,.30,1); r.accent:Show()
            else
                r:SetBackdropColor(.10,.10,.11,.98); r.accent:SetColorTexture(unpack(Style.Gold)); r.accent:Show()
            end
        end
    end
end
local function filterEntries(entries)
    local out={}; local q=string.lower(state.query)
    for _,e in ipairs(entries) do if A.NameMatches(e.name or e.label,q,e.id) then out[#out+1]=e end end
    return out
end
local qualities={{"All qualities","All qualities"},{0,"Poor"},{1,"Common"},{2,"Uncommon"},{3,"Rare"},{4,"Epic"},{5,"Legendary"}}
local slots={{"All slots","All slots"},{1,"Head"},{2,"Neck"},{3,"Shoulder"},{5,"Chest"},{6,"Waist"},{7,"Legs"},{8,"Feet"},{9,"Wrist"},{10,"Hands"},{11,"Finger"},{12,"Trinket"},{16,"Back"},{13,"One-hand"},{17,"Two-hand"},{21,"Main hand"},{22,"Off hand"},{14,"Shield"},{15,"Ranged"},{28,"Relic"},{18,"Bag"}}
local pageFilters={Items={"All","Gear","Recipes","Drops","Vendors","Containers","Quests"},Gear={"All","Drops","Vendors","Quests"},NPCs={"All","Drops","Vendors","Quests"},Quests={"All","Completed","Not completed"},Objects={"All","Containers","Quests"},Recipes={"All","Vendors","Drops","Quests"},Attunements={"All","Alliance","Horde","Both"}}
local function choiceLabel(options,value)
    for _,o in ipairs(options) do if type(o)=="table" and o[1]==value then return o[2] end end
    return tostring(value)
end
local levelOptions={"All levels","My level","10–19","20–29","30–39","40–49","50–60","Unknown range"}
function A.DungeonMatchesLevel(name,filter,playerLevel)
    if not filter or filter=="All levels" then return true end
    local range=(D.DungeonLevels or {})[name]
    if filter=="Unknown range" then return not range end
    if not range then return false end
    local low,high
    if filter=="My level" then low=playerLevel or (UnitLevel and UnitLevel("player")); high=low
    else low,high=filter:match("(%d+)%D+(%d+)"); low=tonumber(low);high=tonumber(high) end
    return low and high and range.min<=high and range.max>=low or false
end
local function dungeonLabel(name)
    local r=(D.DungeonLevels or {})[name]
    return name..(r and (" ("..r.min.."–"..r.max..")") or " (?)")
end
local function journalMatches(name)
    if A.NameMatches(name,state.query) then return true end
    for boss,items in pairs(D.Journal[name] or {}) do
        if A.NameMatches(boss,state.query) then return true end
        for _,id in ipairs(items) do if A.NameMatches(A.Name("item",id),state.query,id) then return true end end
    end
    for _,id in ipairs((D.DungeonQuests or {})[name] or {}) do if A.NameMatches(A.Name("quest",id),state.query,id) then return true end end
    return false
end
local function journalPreferences()
    ForeverDB_Config.journalHidden=ForeverDB_Config.journalHidden or {}
    ForeverDB_Config.journalSectionsHidden=ForeverDB_Config.journalSectionsHidden or {}
    return ForeverDB_Config.journalHidden,ForeverDB_Config.journalSectionsHidden
end
function A.JournalVisible(name)
    local hidden,sections=journalPreferences()
    return not hidden[name] and not sections.dungeons
end
function A.JournalDirectory(includeHidden)
    local names={}
    for name in pairs(D.Journal) do
        if includeHidden or (A.JournalVisible(name) and A.DungeonMatchesLevel(name,state.dungeonLevel) and journalMatches(name)) then names[#names+1]=name end
    end
    table.sort(names,function(a,b)
        local x,y=(D.DungeonLevels or {})[a],(D.DungeonLevels or {})[b]
        local ax,by=x and x.max or -1,y and y.max or -1
        if ax~=by then return ax>by end
        local al,bl=x and x.min or -1,y and y.min or -1
        if al~=bl then return al>bl end
        return a<b
    end)
    return names
end
local function journalSearchActive()
    return state.tab=="Loot Journal" and not state.entity and not state.questTrace and not state.journalCustomize
end
local function selectJournalSuggestion(name)
    if not name or not D.Journal[name] then return end
    state.query="";state.journal=name;state.journalLanding=false;state.boss=nil;state.journalQuest=nil
    state.searchScope="This page";ui.search:SetText(name);ui.search:ClearFocus()
    if menu then menu:Hide() end
    ui.suggestionNames=nil;ui.detailScroll:SetVerticalScroll(0);render()
end
local function journalSuggestions(delta)
    if not journalSearchActive() then return end
    local names=A.JournalDirectory();ui.suggestionNames=names
    ui.suggestionIndex=math.max(1,math.min(#names,(delta and (ui.suggestionIndex or 1)+delta) or 1))
    local options={}
    for i,name in ipairs(names) do options[#options+1]={name,(i==ui.suggestionIndex and "> " or "")..dungeonLabel(name)} end
    if #options==0 then options={{false,"No matching dungeons"}} end
    if menu then menu:Hide() end
    choose(ui.search,options,selectJournalSuggestion,ui.suggestionIndex)
end
local function journalCustomization()
    local hidden,sections=journalPreferences()
    heading("Customize Gear Journal")
    text("Choose what appears in the directory and quick switch. Database and F1 lookups keep all records.",42)
    local function checkbox(caption,checked,callback)
        local r=row(ui.detail,"",nil,nil,nil,0,34);r.controls=r.controls or {}
        local c=r.controls.visibility
        if not c then c=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate");c.label=c:CreateFontString(nil,"OVERLAY","GameFontNormal");c.label:SetPoint("LEFT",c,"RIGHT",6,0);r.controls.visibility=c end
        c:ClearAllPoints();c:SetPoint("LEFT",r,"LEFT",6,0);c:SetSize(28,28);c:SetChecked(checked);c.label:SetText(caption);c:SetScript("OnClick",function(self) callback(self:GetChecked());render() end);c:Show()
    end
    heading("Sections")
    checkbox("Dungeons & Raids",not sections.dungeons,function(on) sections.dungeons=not on end)
    tabStrip({{value="show",label="Show all sections"},{value="hide",label="Hide all sections"},{value="reset",label="Restore defaults"}},nil,function(v)
        if v=="reset" then ForeverDB_Config.journalHidden={};ForeverDB_Config.journalSectionsHidden={}
        else sections.dungeons=v=="hide" end
        render()
    end,3)
    heading("Dungeons & Raids")
    tabStrip({{value="show",label="Show all dungeons"},{value="hide",label="Hide all dungeons"}},nil,function(v)
        for name in pairs(D.Journal) do hidden[name]=v=="hide" or nil end;render()
    end,2)
    for _,name in ipairs(A.JournalDirectory(true)) do checkbox(dungeonLabel(name),not hidden[name],function(on) hidden[name]=not on end) end
end
local function journalLanding()
    local mode=state.journalCollection or "Dungeons"
    local entries={}
    for _,name in ipairs({"Dungeons","Tiers","Specials","On-use items"}) do entries[#entries+1]={label=name,value=name} end
    tabStrip(entries,mode,function(v)
        A.CaptureNavigationScroll();state.journalCollection=v;state.collectionPage=1;state.collectionSet=nil
        ui.detailScroll:SetVerticalScroll(0);render()
    end,4)
    if mode~="Dungeons" then
        ui.search:Hide();ui.searchHint:Hide();ui.searchButton:Hide();ui.journalDropdown:Hide()
        ui.levelFilter:Hide();ui.journalCustomizeButton:Hide()
        if mode=="Tiers" then
            heading("Crafted Artisan's Tier • one piece can be equipped")
            for _,tier in ipairs(D.JournalTiers) do
                local open=state.collectionSet==tier[1]
                row(ui.detail,(open and "[-] " or "[+] ")..tier[1],function()
                    if open then state.collectionSet=nil else state.collectionSet=tier[1] end
                    render()
                end)
                if open then
                    for _,id in ipairs(tier[2]) do guideLine(inlineGuideLink({kind="item",id=id})) end
                    for _,bonus in ipairs(tier[3]) do text(bonus,44) end
                end
            end
        else
            local records=mode=="Specials" and D.JournalSpecials or D.JournalOnUse
            local pages=math.max(1,math.ceil(#records/20))
            local page=math.min(state.collectionPage or 1,pages)
            heading((mode=="Specials" and "Creature-specific effects" or "Equipment with on-use effects").." • "..page.." / "..pages)
            local nav={}
            if page>1 then nav[#nav+1]={label="Previous page",value=page-1} end
            if page<pages then nav[#nav+1]={label="Next page",value=page+1} end
            if #nav>0 then tabStrip(nav,nil,function(v) state.collectionPage=v;ui.detailScroll:SetVerticalScroll(0);render() end,2) end
            for i=(page-1)*20+1,math.min(page*20,#records) do
                guideLine(inlineGuideLink({kind="item",id=records[i][1]}).."  •  "..records[i][2])
            end
        end
        return
    end
    local names=A.JournalDirectory()
    if #names==0 then text("No visible dungeons match. Change the search or level filter, or restore entries in Customize Gear Journal.",60);return end
    for i=1,#names,2 do
        local base=row(ui.detail,"",nil,nil,nil,0,86);base.controls=base.controls or {}
        for col=0,1 do
            local name=names[i+col]
            if name then
                local b=base.controls[col+1]
                if not b then b=button(base,"",0,0,500,function() end);base.controls[col+1]=b end
                resetControl(b);local width=(ui.detail:GetWidth()-10)/2
                b:ClearAllPoints();b:SetPoint("TOPLEFT",col*(width+10),0);b:SetSize(width,80)
                b.caption:ClearAllPoints();b.caption:SetPoint("LEFT",b,"LEFT",124,0);b.caption:SetWidth(width-136-84);b.caption:SetJustifyH("LEFT")
                b.caption:SetFontObject("GameFontHighlight")
                local count=0;for _,id in ipairs(A.DungeonQuestRoots(name)) do if A.QuestVisible(id) then count=count+1 end end
                local bossCount=0;for _ in pairs(D.Journal[name] or {}) do bossCount=bossCount+1 end
                b:SetText("|cffffd100"..name.."|r\n|cffa3a3a8"..bossCount.." bosses  •  "..count.." quest chains|r")
                -- Level range as a badge, matching the framed boss level badges.
                if not b.levelBadge then
                    local badge=CreateFrame("Frame",nil,b,"BackdropTemplate")
                    badge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
                    badge:SetBackdropColor(.04,.04,.05,.96);badge:SetBackdropBorderColor(1.0,.82,.00,.85)
                    badge.text=badge:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");badge.text:SetPoint("CENTER",0,0)
                    b.levelBadge=badge
                end
                local range=(D.DungeonLevels or {})[name]
                b.levelBadge:ClearAllPoints();b.levelBadge:SetPoint("RIGHT",b,"RIGHT",-12,0);b.levelBadge:SetSize(64,20)
                b.levelBadge:SetFrameLevel((b:GetFrameLevel() or 1)+2)
                b.levelBadge.text:SetText(range and ("|cffffd100"..range.min.."–"..range.max.."|r") or "|cffa3a3a8Level ?|r")
                b.levelBadge:Show()
                if not b.picture then b.picture=b:CreateTexture(nil,"ARTWORK") end
                b.picture:ClearAllPoints();b.picture:SetPoint("LEFT",b,"LEFT",6,0);b.picture:SetSize(108,66)
                local art=((D.JournalVisuals or {}).dungeonTextures or {})[name]
                if art and b.picture:SetTexture(art) then b.picture:SetTexCoord(.05,.95,.27,.83)
                else b.picture:SetTexture("Interface\\AddOns\\F1Forever\\Media\\Navigation\\Dungeons.tga");b.picture:SetTexCoord(0,1,42/256,213/256) end
                b.picture:Show();b:Show();b:SetScript("OnClick",function()
                    state.directoryScroll=ui.detailScroll:GetVerticalScroll();state.journal=name;state.journalLanding=false;state.boss=nil;state.journalQuest=nil
                    ui.detailScroll:SetVerticalScroll(0);render()
                end)
            end
        end
    end
end
local function refreshFilters()
    ui.classSelf:Hide();ui.classArrow:Hide()
    local options=pageFilters[state.tab]
    if state.tab=="Class Guides" or state.tab=="Talents" or state.tab=="BiS" then options={"All","Druid","Hunter","Mage","Paladin","Priest","Rogue","Shaman","Warlock","Warrior"} end
    if state.tab=="Loot Journal" then
        options={"All"}
        for _,name in ipairs(A.JournalDirectory()) do options[#options+1]={name,dungeonLabel(name)} end
        if state.journal and not A.JournalVisible(state.journal) then state.journal=nil;state.journalLanding=true end
        if state.journalLanding==false and (not state.journal or not A.DungeonMatchesLevel(state.journal,state.dungeonLevel) or not journalMatches(state.journal)) then
            state.journal=options[2] and options[2][1] or nil;state.boss=nil
        end
        ui.levelFilter:Show();ui.levelFilter:SetText(state.dungeonLevel or "All levels")
    else ui.levelFilter:Hide() end
    if state.tab=="Favorites" then options={"All","Items","Gear","NPCs","Recipes","Quests","Other"} end
    if state.tab=="Talents" or state.tab=="BiS" or state.tab=="Class Guides" then options=nil end
    if state.tab=="Recipes" then
        options={"All"};local seen={}
        for _,recipe in pairs(D.Recipes) do if recipe.profession then seen[recipe.profession]=true end end
        for _,npc in pairs(D.NPCs) do if npc.trainerProfession then seen[npc.trainerProfession]=true end end
        for _,name in ipairs(sorted(seen)) do options[#options+1]=name end
    end
    ui.filterOptions=options
    if options then ui.filter:Show(); ui.filter:SetText("Filter: "..(state.tab=="Favorites" and state.filter or state.pageFilter).."  v") else ui.filter:Hide() end
    local itemPage=state.tab=="Items" or state.tab=="Gear" or state.tab=="Recipes" or state.tab=="Loot Journal"
    if itemPage then
        ui.quality:Show(); ui.slot:Show()
        ui.quality:SetText(choiceLabel(qualities,state.quality).."  v"); ui.slot:SetText(choiceLabel(slots,state.slot).."  v")
    else ui.quality:Hide(); ui.slot:Hide() end
    if state.tab=="Loot Journal" then ui.quality:Hide() end
    if state.tab=="Recipes" then ui.quality:Hide();ui.slot:Show();ui.slot:SetText((state.professionView or "Recipes").."  v") end
    if options then ui.reset:Show() else ui.reset:Hide() end
    ui.listMetaHeader:SetText(state.tab=="Attunements" and "FACTION" or "LEVEL")
    ui.listMetaHeader:Show()
    local globalSearch=state.searchScope=="All database" and state.query~=""
    local browser=databaseBrowser()
    local wide=state.questTrace or (state.entity and state.entity.kind=="quest") or browser or (not globalSearch and (state.tab=="Overview" or state.tab=="Settings" or state.tab=="Loot Journal" or state.tab=="Talents" or state.tab=="BiS" or state.tab=="Class Guides"))
    local topY=(state.tab=="Class Guides" or navGroup(state.tab)=="Settings & Credits") and -115 or -223
    local panelH=(state.tab=="Class Guides" or navGroup(state.tab)=="Settings & Credits") and 605 or 497
    ui.leftPanel:ClearAllPoints(); ui.leftPanel:SetPoint("TOPLEFT",20,-223); ui.leftPanel:SetSize(335,497)
    ui.rightPanel:ClearAllPoints(); ui.rightPanel:SetPoint("TOPLEFT",wide and 20 or 365,topY); ui.rightPanel:SetSize(wide and 1060 or 715,panelH)
    ui.detailScroll:ClearAllPoints(); ui.detailScroll:SetPoint("TOPLEFT",wide and 30 or 375,topY-32); ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52)
    ui.detail:SetWidth(wide and 1015 or 670)
    if wide then ui.leftPanel:Hide(); ui.previous:Hide(); ui.next:Hide() else ui.leftPanel:Show(); ui.previous:Show(); ui.next:Show() end
    local function place(control,x,y,w)
        control:ClearAllPoints();control:SetPoint("TOPLEFT",ui,"TOPLEFT",x,y);control:SetWidth(w)
        if control.caption then control.caption:SetWidth(w-16) end
    end
    place(ui.category,20,-113,335);place(ui.search,22,-149,238);place(ui.searchButton,266,-149,68);place(ui.searchScope,342,-149,125)
    place(ui.filter,20,-185,335);place(ui.quality,365,-185,160);place(ui.slot,533,-185,160);place(ui.reset,701,-185,130)
    place(ui.levelFilter,365,-185,160)
    ui.resultsButton:Hide();ui.footerNote:Show()
    ui.zoneButton:Hide()
    ui.activeProfessionMap=nil
    if state.tab=="Recipes" then
        ui.professionMaps=ui.professionMaps or {}
        if not next(ui.professionMaps) then for _,id in pairs(D.Maps) do ui.professionMaps[id]=true end end
        local mine=not state.professionZone
        local map=state.professionZone
        if mine then map=playerProfessionZone() end
        if type(map)=="number" then ui.activeProfessionMap=map end
        local caption=mine and (map and ("My zone • "..professionZoneName(map)) or "My zone unavailable • All zones") or
            (map=="All" and "All zones" or professionZoneName(map))
        ui.zoneButton:SetText(caption.."  v");tabStyle(ui.zoneButton,mine)
        place(ui.zoneButton,746,-119,232);ui.zoneButton:Show()
    end
    if browser then
        place(ui.category,20,-119,158);place(ui.search,188,-119,196);place(ui.searchButton,392,-119,66);place(ui.searchScope,466,-119,112)
        place(ui.filter,586,-119,152);place(ui.quality,746,-119,112);place(ui.slot,866,-119,112);place(ui.reset,986,-119,94)
        ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",20,-157);ui.rightPanel:SetSize(1060,523)
        ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",30,-189);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,90)
        if state.tab=="Recipes" then ui.slot:Hide() end
        if state.entity then ui.resultsButton:Show();ui.previous:Hide();ui.next:Hide();ui.page:Hide()
        else ui.previous:Show();ui.next:Show();ui.page:Show() end
        ui.footerNote:Hide()
    else ui.page:Show() end
    local journal=state.tab=="Loot Journal" and not state.entity and not state.questTrace and not globalSearch
    ui.bisHeader:Hide();ui.journalHeader:Hide();ui.journalRailScroll:Hide();ui.journalSearchLabel:Hide()
    ui.journalCustomizeButton:Hide();ui.journalSectionLabel:Hide();ui.rightHead:Show()
    ui.brandLabel:Show();ui.versionLabel:Show()
    ui.journalDropdown:Hide()
    ui.journalRailScroll:ClearAllPoints()
    if state.tab=="Class Guides" and state.guideSection=="BiS" and not state.entity and not globalSearch then
        ui.bisHeader:ClearAllPoints();ui.bisHeader:SetPoint("TOPLEFT",20,topY);ui.bisHeader:Show()
        local contentY=topY-77
        ui.rightHead:Hide()
        ui.journalRailScroll:SetPoint("TOPLEFT",20,contentY-4)
        ui.journalRailScroll:SetSize(300,panelH-81);ui.journalRailScroll:Show()
        ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",350,contentY);ui.rightPanel:SetSize(730,panelH-77)
        ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",360,contentY-4);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52)
        ui.detail:SetWidth(700)
    else
        ui.journalRailScroll:SetPoint("TOPLEFT",20,-269);ui.journalRailScroll:SetSize(300,451)
    end
    if journal and state.journalLanding==false and not state.journalCustomize then
        place(ui.search,20,-119,230);place(ui.searchButton,258,-119,68);place(ui.searchScope,334,-119,125)
        place(ui.filter,467,-119,280);place(ui.levelFilter,755,-119,120);place(ui.slot,883,-119,100);place(ui.reset,991,-119,89)
        ui.filter:SetText((state.journal or "Choose dungeon").."  v")
        ui.leftPanel:Hide();ui.previous:Hide();ui.next:Hide();ui.page:Hide()
        ui.journalHeader:Show();ui.journalRailScroll:Show()
        -- Reset rail scroll when switching between boss list and a quest's chain, not when picking a step.
        local railKey=(state.boss=="__quests" and questFocusValid()) and "questtree" or "bosses"
        if state.railDungeon~=state.journal or state.railKey~=railKey then
            ui.journalRailScroll:SetVerticalScroll(0);state.railDungeon=state.journal;state.railKey=railKey
        end
        -- The boss title or step title heads the panel; the generic DETAILS band is not repeated.
        ui.rightHead:Hide()
        ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",350,-269);ui.rightPanel:SetSize(730,451)
        ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",360,-277);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52)
        ui.detail:SetWidth(700)
    end
    if journal and (state.journalLanding~=false or state.journalCustomize) then
        place(ui.levelFilter,210,-119,160)
        ui.filter:Hide();ui.slot:Hide();ui.reset:Hide();ui.previous:Hide();ui.next:Hide();ui.page:Hide()
        ui.rightHead:Hide()
        ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",20,-159);ui.rightPanel:SetSize(1060,561)
        ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",30,-165);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52);ui.detail:SetWidth(1015)
        if not state.journalCustomize then ui.journalCustomizeButton:Show();ui.journalSectionLabel:Show() end
        if state.journalCustomize then
            ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",20,-115);ui.rightPanel:SetSize(1060,605)
            ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",30,-147);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52)
        end
    else ui.search:SetHeight(27) end
    if journal then
        ui.brandLabel:Hide();ui.versionLabel:Hide()
        place(ui.search,28,-119,390);ui.search:SetHeight(28)
        place(ui.journalDropdown,420,-119,30);if not state.journalCustomize then ui.journalDropdown:Show() end
        place(ui.searchScope,340,-119,110)
        ui.journalSectionLabel:Hide()
        place(ui.levelFilter,470,-119,160)
        if state.journalLanding==false and not state.journalCustomize then
            ui.filter:Hide();place(ui.levelFilter,470,-119,160);place(ui.slot,635,-119,125);place(ui.reset,942,-119,115)
            if state.boss~="__quests" then
                place(ui.classSelf,770,-119,130);place(ui.classArrow,902,-119,28)
                local selection=A.LootClassFilter()
                local label=selection=="SELF" and "Self" or "All classes"
                for _,c in ipairs(A.LootClasses) do if selection==c[1] then label=c[2] end end
                ui.classSelf:SetText(label);ui.classSelf:Show();ui.classArrow:Show()
                tabStyle(ui.classSelf,selection=="SELF")
            end
            -- Slot only filters loot; Reset appears once something differs from the defaults.
            if state.boss=="__quests" then ui.slot:Hide() end
            local changed=A.LootClassFilter()~="SELF" or (state.dungeonLevel and state.dungeonLevel~="All levels") or (state.slot and state.slot~="All slots") or (state.query and state.query~="")
            if changed then ui.reset:Show() else ui.reset:Hide() end
            if state.boss=="__quests" and not questFocusValid() then
                ui.journalRailScroll:Hide();ui.rightHead:Hide()
                ui.rightPanel:ClearAllPoints();ui.rightPanel:SetPoint("TOPLEFT",20,-269);ui.rightPanel:SetSize(1060,451)
                ui.detailScroll:ClearAllPoints();ui.detailScroll:SetPoint("TOPLEFT",30,-275);ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52);ui.detail:SetWidth(1015)
            end
        end
    end
    local activeNav=(state.tab=="Recipes" and state.professionView=="Guide") and "Profession Guides" or navGroup(state.tab)
    for tab,b in pairs(ui.nav) do tabStyle(b,activeNav==tab) end
    local group=navGroup(state.tab)
    ui.categoryOptions=group=="Database" and databasePages or nil
    for tab,control in pairs(ui.questNav) do
        if group=="Quests & Attunements" then control:Show();tabStyle(control,state.tab==tab) else control:Hide() end
    end
    if ui.categoryOptions then
        ui.category:Show();local caption=state.tab
        for _,v in ipairs(ui.categoryOptions) do if v[1]==state.tab then caption=v[2] end end
        ui.category:SetText(caption.."  v")
    else ui.category:Hide() end
end
local function favorites()
    local entries={}
    for _,list in ipairs(ForeverDB_Favorites.lists) do
        local l=list
        entries[#entries+1]={name=l.name,action=function() state.list=l.id; state.entity=nil; render() end}
    end
    listRows(entries)
    local list
    for _,l in ipairs(ForeverDB_Favorites.lists) do if l.id==state.list then list=l end end
    if not list then text("Create a named list above to get started."); return end
    heading(list.name)
    text("Right-click an entry to manage its list memberships. Items can belong to multiple lists. Click an item status to change it.",62)
    local fs={"All","Items","Gear","NPCs","Recipes","Quests","Other"}
    row(ui.detail,"Filter: "..state.filter.." • Click to change",function()
        for i,f in ipairs(fs) do if f==state.filter then state.filter=fs[i%#fs+1]; break end end
        render()
    end)
    for _,key in ipairs(sorted(list.entries)) do
        local e=list.entries[key]; local item=e.kind=="item" and D.Items[e.id]
        local f=state.filter
        local visible=f=="All" or (f=="Items" and item) or (f=="Gear" and item and (item.slot or 0)>0) or (f=="Recipes" and item and (item.cls or item.class)==9) or (f=="NPCs" and e.kind=="npc") or (f=="Quests" and e.kind=="quest") or (f=="Other" and e.kind=="object")
        if visible and A.NameMatches(A.Name(e.kind,e.id),state.query,e.id) then
            row(ui.detail,A.Label(e.kind,e.id),function(mouse)
                if mouse=="RightButton" then list.entries[key]=nil; render() else A.Open(e.kind,e.id) end
            end,e.kind,e.id)
            if item then row(ui.detail,"    Status: "..e.status,function()
                e.status=e.status=="Wanted" and "Obtained" or e.status=="Obtained" and "Equipped" or "Wanted"; render()
            end) end
        end
    end
end
local function renderContent()
    if not ui then return end
    A.hovered=nil
    clear(ui.list); clear(ui.detail); clear(ui.journalHeader); clear(ui.bisHeader); clear(ui.journalRail); ui.copy:Hide()
    refreshFilters()
    ui.changeListPage=nil
    ui.previous:Hide();ui.next:Hide();ui.page:Hide()
    ui.title:SetText("|cffffffff"..((state.tab=="Recipes" and state.professionView=="Guide") and "Profession Guides" or navGroup(state.tab)).."|r"); ui.listName:Hide(); ui.newList:Hide(); ui.renameList:Hide()
    if state.tab=="Class Guides" or navGroup(state.tab)=="Settings & Credits" then ui.search:Hide();ui.searchButton:Hide();ui.searchHint:Hide();ui.searchScope:Hide()
    else ui.searchScope:Show();ui.searchScope:SetText((state.searchScope or "This page").."  v");ui.search:Show();ui.searchButton:Show();if state.tab=="Favorites" then ui.searchHint:Hide() else ui.searchHint:Show() end end
    if state.tab=="Loot Journal" then
        ui.searchHint:Hide()
        ui.searchScope:Hide()
        if not state.entity and not state.questTrace and not (state.searchScope=="All database" and state.query~="") then ui.searchButton:Hide() end
        if state.journalLanding~=false or state.journalCustomize then ui.searchScope:Hide() end
        if state.journalCustomize then ui.search:Hide();ui.searchButton:Hide();ui.levelFilter:Hide() end
    end
    if state.questTrace or (state.entity and state.entity.kind=="quest") then
        questTraceView(state.questTrace or state.entity.id);return
    end
    if state.searchScope=="All database" and state.query~="" then
        local found={}
        for _,kind in ipairs({"item","npc","quest","object","recipe"}) do
            for _,e in ipairs(A.Search(kind,state.query,false)) do
                e.label=A.Label(kind,e.id).."  |cffa3a3a8("..kind..")|r";found[#found+1]=e
            end
        end
        table.sort(found,function(a,b) if a.name==b.name then return a.kind<b.kind end return a.name<b.name end)
        listRows(found)
        if not databaseBrowser() and not state.entity then heading("Search all database");text("Items, NPCs, quests, objects and recipes • "..#found.." matches",30) end
    elseif state.tab=="Recipes" and state.professionView=="Guide" and not state.entity then
        professionGuide()
    elseif state.tab=="Favorites" then
        ui.listName:Show(); ui.newList:Show(); ui.renameList:Show()
        favorites()
    elseif state.tab=="Items" or state.tab=="Gear" or state.tab=="NPCs" or state.tab=="Quests" or state.tab=="Objects" or state.tab=="Recipes" then
        local kinds={Items="item",Gear="item",NPCs="npc",Quests="quest",Objects="object",Recipes="item"}
        local found={}
        for _,e in ipairs(A.Search(kinds[state.tab],state.query,state.tab=="Gear")) do
            if A.Matches(e.kind,e.id,state.pageFilter,state.quality,state.slot) then found[#found+1]=e end
        end
        if state.tab=="Recipes" then
            local selected={};found={}
            for id,recipe in pairs(D.Recipes) do
                if state.pageFilter=="All" or recipe.profession==state.pageFilter then selected[id]=true end
            end
            local view=state.professionView or "Recipes"
            if view=="Recipes" then
                for _,e in ipairs(A.Search("recipe",state.query,false)) do
                    if selected[e.id] then
                        local recipe=D.Recipes[e.id]
                        e.label="|cfff6d365"..e.name.."|r"..(recipe.skill and ("  "..skillColor(recipe.skill).."("..recipe.skill..")|r") or "")
                        found[#found+1]=e
                    end
                end
            else
                local scrolls,npcSet={},{}
                for ft,fi,tt,ti,relation in A.AllEdges() do
                    if relation=="Teaches" and tt=="recipe" and selected[ti] then
                        if ft=="item" then scrolls[fi]=true elseif ft=="npc" and view=="Trainers" then npcSet[fi]=true end
                    end
                end
                if view=="Vendors" then
                    for ft,fi,tt,ti,relation in A.AllEdges() do
                        if relation=="Sells" and ft=="npc" and tt=="item" and scrolls[ti] then npcSet[fi]=true end
                    end
                end
                if view=="Trainers" then
                    for id,npc in pairs(D.NPCs) do
                        if npc.trainerProfession and (state.pageFilter=="All" or state.pageFilter==npc.trainerProfession) then npcSet[id]=true end
                    end
                end
                if view=="Vendors" then
                    for id in pairs(A.ProfessionSuppliers(state.pageFilter)) do npcSet[id]=true end
                end
                for _,e in ipairs(A.Search("npc",state.query,false)) do
                    if npcSet[e.id] and (not ui.activeProfessionMap or A.ProfessionNPCArea(D.NPCs[e.id],ui.activeProfessionMap)) then
                        found[#found+1]=e
                    end
                end
            end
        end
        listRows(found)
        if #found==0 and (state.professionView=="Trainers" or state.professionView=="Vendors") and state.tab=="Recipes" and ui.activeProfessionMap and not state.entity then
            text("No recorded matches in "..professionZoneName(ui.activeProfessionMap)..". Choose All zones to search farther.",32)
        end
        if not databaseBrowser() and not state.entity and state.tab=="Recipes" then heading("Professions");text("Choose a profession and browse recipes, known trainers or recipe vendors. Select an entry for reagents, acquisition links and available map pins.",62);text("Trainer coverage is incomplete across factions. Missing trainers may still teach a recipe. Required skill is shown when known.",38)
        elseif not databaseBrowser() and not state.entity then heading("Explore Forever"); text("Search by name or ID, then select an entry. Use the relationship links to move between loot, vendors, containers and quests.",85) end
    elseif state.tab=="Loot Journal" then
        ui.page:SetText("")
        if state.journalCustomize then journalCustomization();return end
        if state.journalLanding~=false then journalLanding();return end
        if not state.journal then journalLanding();return end
        local info=(D.DungeonDetails or {})[state.journal] or {}
        local bosses=sorted(D.Journal[state.journal])
        local order={};for i,name in ipairs(info.bossOrder or {}) do order[name]=i end
        table.sort(bosses,function(a,b) local x,y=order[a] or 999,order[b] or 999;if x==y then return a<b end;return x<y end)
        local detailPanel=ui.detail;ui.detail=ui.journalHeader
        local banner=row(ui.detail,"|cffffffff"..dungeonLabel(state.journal).."|r",nil,nil,nil,0,66)
        banner:SetBackdropColor(unpack(Style.Canvas));banner:SetBackdropBorderColor(unpack(Style.PanelBorder))
        banner.controls=banner.controls or {}
        local art=banner.controls[1]
        if not art then art=button(banner,"",0,0,340,function() end);banner.controls[1]=art end
        resetControl(art);art:ClearAllPoints();art:SetPoint("TOPLEFT",banner,"TOPLEFT",1,-1);art:SetPoint("BOTTOMLEFT",banner,"BOTTOMLEFT",1,1);art:SetWidth(340);art:SetText("")
        art:SetFrameLevel(banner:GetFrameLevel())
        art:SetBackdropColor(0,0,0,0);art:SetBackdropBorderColor(0,0,0,0)
        if art.sheen then art.sheen:Hide() end
        if art.topHighlight then art.topHighlight:Hide() end
        art:SetScript("OnEnter",nil);art:SetScript("OnLeave",nil)
        art:SetScript("OnClick",nil)
        if not art.picture then art.picture=art:CreateTexture(nil,"BACKGROUND") end
        art.picture:SetDrawLayer("BACKGROUND")
        -- The addon's own art is always drawn underneath, so a native texture that loads blank still leaves a picture.
        art.picture:ClearAllPoints();art.picture:SetAllPoints(art);art.picture:SetTexture("Interface\\AddOns\\F1Forever\\Media\\Navigation\\Dungeons.tga");art.picture:SetTexCoord(0,1,42/256,213/256);art.picture:SetVertexColor(.80,.82,.86,1);art.picture:Show()
        if not art.nativePicture then art.nativePicture=art:CreateTexture(nil,"BACKGROUND",nil,1) end
        art.nativePicture:Hide()
        local nativeArt=((D.JournalVisuals or {}).dungeonTextures or {})[state.journal]
        if nativeArt then
            art.nativePicture:ClearAllPoints();art.nativePicture:SetAllPoints(art)
            local ok=art.nativePicture:SetTexture(nativeArt)
            if ok~=false then art.nativePicture:SetTexCoord(.04,.96,.28,.70);art.nativePicture:SetVertexColor(1,1,1,1);art.nativePicture:Show() end
        end
        if not art.fadeOverlay then
            art.fadeOverlay=art:CreateTexture(nil,"BORDER")
            art.fadeOverlay:SetAllPoints(art)
            applyGradient(art.fadeOverlay,"HORIZONTAL",.063,.063,.063,.12,.063,.063,.063,1.0)
        end
        if not art.fadeBottom then
            art.fadeBottom=art:CreateTexture(nil,"BORDER",nil,1)
            art.fadeBottom:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT",0,0);art.fadeBottom:SetPoint("BOTTOMRIGHT",art,"BOTTOMRIGHT",0,0);art.fadeBottom:SetHeight(28)
            applyGradient(art.fadeBottom,"VERTICAL",.063,.063,.063,.85,.063,.063,.063,0)
        end
        art.fadeBottom:Show()
        art.fadeOverlay:SetDrawLayer("BORDER")
        art.fadeOverlay:Show();art:Show()
        banner.text:SetDrawLayer("OVERLAY")
        banner.text:ClearAllPoints();banner.text:SetPoint("LEFT",banner,"LEFT",210,0);banner.text:SetWidth(banner:GetWidth()-375)
        banner.text:SetShadowOffset(1,-1);banner.text:SetShadowColor(0,0,0,1)
        local questCount=0;for _,id in ipairs(A.DungeonQuestRoots(state.journal)) do if A.QuestVisible(id) then questCount=questCount+1 end end
        banner.text:SetText("|cffffd100"..dungeonLabel(state.journal).."|r\n|cffa3a3a8"..#bosses.." bosses  •  "..questCount.." quest chains|r")
        if info.entrance then
            local pin=banner.controls[2]
            if not pin then pin=button(banner,"Entrance map",0,0,136,function() end);banner.controls[2]=pin end
            resetControl(pin);pin:ClearAllPoints();pin:SetPoint("RIGHT",banner,"RIGHT",-8,0);pin:SetSize(136,30);pin:SetText("Entrance map")
            pin:SetScript("OnClick",function() local e=info.entrance;A.PinMap(e.map,e.x,e.y) end);pin:Show()
        end
        local back=banner.controls[3]
        if not back then back=button(banner,"All dungeons",0,0,136,function() end);banner.controls[3]=back end
        resetControl(back);back:ClearAllPoints();back:SetPoint("RIGHT",banner,"RIGHT",-8,-18);back:SetSize(136,25);back:SetText("All dungeons")
        back:SetScript("OnClick",function() state.journalLanding=true;render();ui.detailScroll:SetVerticalScroll(state.directoryScroll or 0) end);back:Show()
        if banner.controls[2] and info.entrance then banner.controls[2]:ClearAllPoints();banner.controls[2]:SetPoint("RIGHT",banner,"RIGHT",-8,16);banner.controls[2]:SetHeight(25) end
        local entries={}
        for _,boss in ipairs(bosses) do
            local matches=A.NameMatches(state.journal,state.query) or A.NameMatches(boss,state.query)
            for _,id in ipairs(D.Journal[state.journal][boss]) do if A.NameMatches(A.Name("item",id),state.query,id) then matches=true;break end end
            if matches then entries[#entries+1]={value=boss,label=boss} end
        end
        local dungeonQuests={}
        for _,id in ipairs(A.DungeonQuestRoots(state.journal)) do if A.QuestVisible(id) then dungeonQuests[#dungeonQuests+1]=id end end
        local bossVisible=state.boss=="__quests"
        for _,entry in ipairs(entries) do if entry.value==state.boss then bossVisible=true end end
        if not bossVisible then state.boss=entries[1] and entries[1].value or "__loot" end
        local section=(state.boss=="__quests") and state.boss or "__loot"
        tabStrip({{value="__loot",label="Bosses & Loot ("..#entries..")"},{value="__quests",label="Quests ("..#dungeonQuests..")"}},section,function(value)
            state.boss=value=="__loot" and ((D.Journal[state.journal] or {})[state.lastJournalBoss] and state.lastJournalBoss or (entries[1] and entries[1].value)) or value
            state.questTree=nil;state.questFocus=nil;state.questFocusStep=nil;state.questFocusRoot=nil
            ui.detailScroll:SetVerticalScroll(0);render()
        end,2)
        ui.detail=detailPanel
        local function railEntry(caption,selected,action,kind,id)
            local r=row(ui.journalRail,caption,action,kind,id,0,58)
            if selected then r:SetBackdropColor(unpack(Style.RowSelected));r:SetBackdropBorderColor(unpack(Style.RowSelectedBorder));r.accent:SetColorTexture(unpack(Style.Bullet)) end
            return r
        end
        local visibleQuests={}
        for _,id in ipairs(dungeonQuests) do
            if A.NameMatches(A.Name("quest",id),state.query,id) or A.NameMatches(state.journal,state.query) then visibleQuests[#visibleQuests+1]=id end
        end
        local tree=state.boss=="__quests" and questFocusValid()
        if tree then
            questTreeRail(visibleQuests)
        elseif state.boss~="__quests" then
            for _,entry in ipairs(entries) do
                local boss=entry.value
                local nid=(info.bossIDs or {})[boss];local npc=nid and D.NPCs[nid]
                local lvl=npc and npc.level and npc.level>0 and npc.level or nil
                local r=railEntry(boss.."\n|cffa3a3a8"..#(D.Journal[state.journal][boss] or {}).." recorded items|r",state.boss==boss,function() state.boss=boss;ui.detailScroll:SetVerticalScroll(0);render() end)
                r.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull");r.icon:SetTexCoord(0,1,0,1);r.icon:SetSize(24,24);r.icon:Show()
                nativeBossPortrait(r,nid,44)
                frameBossSlot(r,44,lvl)
                r.text:ClearAllPoints();r.text:SetPoint("LEFT",62,0);r.text:SetWidth(r:GetWidth()-72)
            end
        end
        if state.boss=="__quests" and tree then
            questFocusDetail(state.questFocusStep,state.questFocusRoot)
        elseif state.boss=="__quests" then
            fitRow(ui.detail,text("|cffa3a3a8Click a quest to open its chain  •  Level = minimum required  •  |cffffd100Pre|r|cffa3a3a8 = recorded prerequisites (|r|cffff5555red|r|cffa3a3a8 = unfinished)  •  Pin = quest giver|r",28),28,12)
            local h=row(ui.detail,"|cffffd100Quest|r",nil,nil,nil,0,26)
            h:SetBackdropColor(unpack(Style.TableHeaderBg));h:SetBackdropBorderColor(unpack(Style.TableHeaderBorder))
            h.text:SetFontObject("GameFontNormalSmall");h.text:ClearAllPoints();h.text:SetPoint("LEFT",QuestTable.nameX,0);h.text:SetWidth(QuestTable.nameW)
            h.controls=h.controls or {}
            local titles={"Lvl","Side","Pre","Share","Starts"}
            for i,title in ipairs(titles) do
                local b=h.controls[i];if not b then b=button(h,"",0,0,QuestTable.widths[i],function() end);h.controls[i]=b end
                resetControl(b);b:ClearAllPoints();b:SetPoint("LEFT",h,"LEFT",QuestTable.xs[i],0);b:SetSize(QuestTable.widths[i],22);b:SetText("|cffffd100"..title.."|r");b:SetScript("OnClick",nil);b:Show()
                b.caption:SetFontObject("GameFontNormalSmall");b:SetBackdropColor(0,0,0,0);b:SetBackdropBorderColor(0,0,0,0);b:SetScript("OnEnter",nil);b:SetScript("OnLeave",nil)
                if i==5 then b.caption:ClearAllPoints();b.caption:SetPoint("LEFT",b,"LEFT",4,0);b.caption:SetJustifyH("LEFT") end
            end
            for _,id in ipairs(visibleQuests) do questTableRow(id) end
            if #visibleQuests==0 then text("No recorded dungeon quests match your search and faction filters.",40) end
        elseif #entries==0 then
            text("No recorded encounters match your search.",38)
        else
            state.lastJournalBoss=state.boss
            local nid=(info.bossIDs or {})[state.boss]
            local npc=nid and D.NPCs[nid]
            local bossTitle=row(ui.detail,"|cffffffff"..(state.boss or "Choose an encounter").."|r",nil,nil,nil,0,66)
            titleStyle(bossTitle)
            bossTitle.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull");bossTitle.icon:SetTexCoord(0,1,0,1);bossTitle.icon:SetSize(28,28);bossTitle.icon:Show()
            nativeBossPortrait(bossTitle,nid,52)
            frameBossSlot(bossTitle,52,npc and npc.level)
            bossTitle.text:ClearAllPoints();bossTitle.text:SetPoint("LEFT",72,0);bossTitle.text:SetWidth(bossTitle:GetWidth()-84);bossTitle.text:SetFontObject("GameFontNormalLarge")
            if nid then
                local npc=D.NPCs[nid]
                local level=npc and npc.level and npc.level>0 and (" • Level "..npc.level) or ""
                row(ui.detail,"NPC details • "..A.Name("npc",nid)..level.."  ›",function() A.Open("npc",nid) end,nil,nil,0,30)
            end
            tableHeader("ITEM","TYPE / SLOT")
            local loot=(D.Journal[state.journal] or {})[state.boss] or {}
            local shown=0
            for _,id in ipairs(loot) do
                local query=string.lower(state.query)
                if A.ItemClassMatches(id) and A.Matches("item",id,"All","All qualities",state.slot) and (A.NameMatches(A.Name("item",id),query,id) or (query~="" and (A.NameMatches(state.journal,query) or A.NameMatches(state.boss,query)))) then
                shown=shown+1
                local r=link("item",id,nil,nil,true)
                local extra=52-r:GetHeight();r:SetHeight(52);ui.detail.y=ui.detail.y+extra;ui.detail:SetHeight(ui.detail.y)
                r.icon:SetSize(34,34);r.iconBorder:SetSize(36,36);r.text:ClearAllPoints();r.text:SetPoint("LEFT",52,0)
                r.controls=r.controls or {}
                local fav=r.controls[1]
                if not fav then fav=button(r,"+ Fav",0,0,58,function() end);r.controls[1]=fav end
                resetControl(fav)
                local saved=isFavorited("item",id)
                fav:ClearAllPoints();fav:SetPoint("RIGHT",r,"RIGHT",-6,0);fav:SetSize(58,22);fav:SetText("+ Fav");fav.caption:SetWidth(48);tabStyle(fav,saved)
                fav:SetScript("OnClick",function(self)
                    local options={}
                    for _,list in ipairs(ForeverDB_Favorites.lists) do options[#options+1]={list,(list.entries[A.Key("item",id)] and "[x] " or "[ ] ")..list.name} end
                    choose(self,options,function(list) A.ToggleFavorite(list,"item",id);render() end)
                end);fav:Show()
                local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
                local subtype,slot
                if getInfo then local _,_,_,_,_,_,sub,_,equip=getInfo(id); subtype=sub; slot=equip end
                r.text:SetWidth(r:GetWidth()-260)
                r.meta:SetWidth(170); r.meta:ClearAllPoints(); r.meta:SetPoint("RIGHT",r,"RIGHT",-76,0)
                r.meta:SetText(subtype or (slot and _G[slot]) or "—")
                end
            end
            if #loot>0 and shown==0 then text("No loot matches these filters.",32) end
            if #loot==0 then text("Loot not recorded yet.",32) end
        end
    elseif state.tab=="Attunements" then
        local entries={}
        for i,g in ipairs(D.Attunements) do local id=i; local visible=false;for _,c in ipairs(g.chains) do for _,step in ipairs(c.steps) do if A.QuestVisible(step.id) then visible=true;break end end end; if visible and A.FactionVisible(g.faction) and (state.pageFilter=="All" or g.faction==state.pageFilter or (state.pageFilter=="Both" and (g.faction=="" or g.faction=="Both"))) then entries[#entries+1]={name=g.name,faction=g.faction or "Both",action=function() state.attune=id; state.entity=nil; render() end} end end
        listRows(filterEntries(entries))
        if state.attune then attuneDetail(D.Attunements[state.attune]) else heading("Attunements & dungeon quests"); text("Select a guide. Quest completion is read from this character. Each chain and each quest expands separately.",70) end
    elseif state.tab=="Class Guides" or state.tab=="BiS" then
        ui.page:SetText("");bisGuide()
    elseif state.tab=="Talents" then
        ui.page:SetText("");talentGuide()
    elseif state.tab=="Class Guides" or state.tab=="Talents" or state.tab=="BiS" then
        local entries={}
        for i,g in ipairs(A.Guides) do local id=i; if state.pageFilter=="All" or state.pageFilter==g.class then entries[#entries+1]={name=g.class.." • "..g.spec,action=function() state.guide=id; state.entity=nil; render() end} end end
        listRows(filterEntries(entries))
        if state.guide then guideDetail(A.Guides[state.guide]) else
            heading(state.tab); text("Select a class and specialization to see its draft guide, stat considerations, talent resources and BiS status.",75)
            text("BiS lists will follow when level 60 dungeon loot is confirmed and simulated. No final gear rankings are included in this draft.",75)
        end
    elseif state.tab=="Settings" or state.tab=="Overview" then
        ui.page:SetText("")
        heading("Settings")
        text("Hover an item or NPC for contextual help. Key: "..(GetBindingKey("CLICK ForeverDBHelpButton:LeftButton") or "Unbound"),32)
        local controls=row(ui.detail,"",nil,nil,nil,0,34);controls.controls=controls.controls or {}
        local actions={{"Change keybinding",changeKeybinding},{"Reset to F1",function() A.Bind("F1");render() end},{"Clear binding",function() A.Bind(nil);render() end}}
        for i,entry in ipairs(actions) do
            local control=controls.controls[i]
            if not control then control=button(controls,"",0,0,180,function() end);controls.controls[i]=control end
            resetControl(control)
            control:ClearAllPoints();control:SetPoint("TOPLEFT",(i-1)*190,0);control:SetSize(180,30);control.caption:SetWidth(164)
            control:SetText(entry[1]);control:SetScript("OnClick",entry[2]);tabStyle(control,false);control:Show()
        end

        row(ui.detail,"Customize Gear Journal",function() state.tab="Loot Journal";state.entity=nil;state.questTrace=nil;state.journalCustomize=true;state.searchScope="This page";ui.detailScroll:SetVerticalScroll(0);render() end)
        heading("Gear comparisons")
        row(ui.detail,"Show BiS rankings in item tooltips • "..(ForeverDB_Config.showRankTooltips~=false and "On" or "Off"),function()
            ForeverDB_Config.showRankTooltips=ForeverDB_Config.showRankTooltips==false
            render()
        end)
        row(ui.detail,"Show weighted comparisons in item tooltips • "..(ForeverDB_Config.showComparisonTooltips~=false and "On" or "Off"),function()
            ForeverDB_Config.showComparisonTooltips=ForeverDB_Config.showComparisonTooltips==false
            render()
        end)
        epPicker("Tooltip profile",ForeverDB_Config.epProfile,function(v) ForeverDB_Config.epProfile=v end)
        row(ui.detail,"Share my slot estimate with party or guild • "..(ForeverDB_Config.epShare and "On" or "Off"),function()
            ForeverDB_Config.epShare=not ForeverDB_Config.epShare;render()
        end)
        heading("Quality of Life")
        local factionRow=row(ui.detail,"Show:",nil,nil,nil,0,34)
        factionRow.controls=factionRow.controls or {}
        for i,entry in ipairs({{"Alliance","showAlliance"},{"Horde","showHorde"}}) do
            local key=entry[2]
            local check=factionRow.controls["faction"..i]
            if not check then
                check=CreateFrame("CheckButton",nil,factionRow,"UICheckButtonTemplate")
                check.label=check:CreateFontString(nil,"OVERLAY","GameFontNormal")
                check.label:SetPoint("LEFT",check,"RIGHT",4,0)
                factionRow.controls["faction"..i]=check
            end
            check:ClearAllPoints();check:SetPoint("LEFT",factionRow,"LEFT",80+(i-1)*170,0);check:SetSize(28,28)
            check.label:SetText(entry[1]);check:SetChecked(ForeverDB_Config[key] ~= false)
            check:SetScript("OnClick",function(self) ForeverDB_Config[key]=self:GetChecked() and true or false;state.attune=nil;render() end)
            check:Show()
        end
        row(ui.detail,(ForeverDB_Config.hideCompletedQuests and "[x] " or "[ ] ").."Hide completed quests while browsing",function()
            ForeverDB_Config.hideCompletedQuests=not ForeverDB_Config.hideCompletedQuests;state.attune=nil;render()
        end,nil,nil,nil,0,30)
        text("Shared and unknown factions remain visible. Favorites: use + Fav or right-click an entry.",32)
        homeLanding()
        heading("Early release - database expanding")
        text("Item sources, professions, trainers and locations are still being collected and verified. Coverage varies by profession and faction. Updates are planned every few days as new data passes review.",62)
        heading("Credits & contact")
        text("By Sarcasm • Wild Sarcasm on Forever USA • Discord @sarcasm",32)
        text("Version "..A.version,26)
    else
        ui.page:SetText("")
        heading("Your Forever field guide")
        text("Hover an item or NPC and press |cffffd166F1|r to open its page. Browse the journal, follow item and NPC relationships, and build named Favorites lists.",85)
        heading("Lean draft: where to get it")
        text("Dropped by, sold by, quest rewards, containers and source locations. Native tooltips supply item stats. Client-defined crafting, reagents and recipe-scroll teaching are linked; drop rates and disenchanting are deferred.",95)
        heading("A first draft, built to grow")
        text("Some locations and acquisition details still need live confirmation. Report missing or incorrect content so we can improve the next build.",105)
        heading("Class guides, talents & BiS")
        text("Every class and spec has a home here. Provisional notes and talent resources come first; gear lists follow confirmed level 60 dungeon loot and simulation.",80)
        heading("F1 Forever by Sarcasm")
        text("Forever "..A.version.."\nWild Sarcasm on Forever USA\nDiscord: |cffc4b5fd@sarcasm|r",75)
        heading("Credits")
        text("Created by Sarcasm. Thanks to Questie contributors, WoWSims Forever client-data tools, Napalmsteak's WoW Classic Item Caches, and community testers and contributors. Source details and acknowledgments are maintained with the project documentation.",75)
    end
    if state.entity then clear(ui.detail); if databaseBrowser() then professionTabs() end; entityDetail(state.entity.kind,state.entity.id) end
end
local function updateDetailScrolling()
    if not ui or not ui.detail then return end
    local scroll=ui.detailScroll
    local overflow=ui.detail:GetHeight()>scroll:GetHeight()+1
    scroll:EnableMouseWheel(overflow)
    if scroll.ScrollBar then
        if overflow then scroll.ScrollBar:Show() else scroll.ScrollBar:Hide() end
    end
    if not overflow then scroll:SetVerticalScroll(0) end
end
render=function()
    navRendering=true
    renderContent()
    local nextView=navSnapshot()
    if not navRestoring then
        if navCurrent and not sameNav(navCurrent,nextView) then
            pushNav(state.history,navCurrent);state.future={}
        elseif navCurrent then
            nextView.scroll=navCurrent.scroll;nextView.railScroll=navCurrent.railScroll
        end
        navCurrent=nextView
    end
    ui.navBack:SetEnabled(#state.history>0);ui.navForward:SetEnabled(#state.future>0)
    ui.navBack:SetAlpha(#state.history>0 and 1 or .35);ui.navForward:SetAlpha(#state.future>0 and 1 or .35)
    ui.resultsButton:Hide()
    if ui and ui.updateSearchPlaceholder then ui.updateSearchPlaceholder() end
    -- Finalize even when a content branch returns early (quest trace/empty results).
    if ui and ui.detailScroll.UpdateScrollChildRect then ui.detailScroll:UpdateScrollChildRect() end
    updateDetailScrolling()
    if ui and ui.journalRailScroll:IsShown() then
        local scroll=ui.journalRailScroll
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        local overflow=ui.journalRail:GetHeight()>scroll:GetHeight()+1
        scroll:EnableMouseWheel(overflow)
        if scroll.ScrollBar then if overflow then scroll.ScrollBar:Show() else scroll.ScrollBar:Hide() end end
        if not overflow then scroll:SetVerticalScroll(0) end
        -- Opening a quest from the table scrolls the tree to it once.
        if state.railScrollTarget then
            local target=state.railScrollTarget;state.railScrollTarget=nil
            local maximum=scroll:GetVerticalScrollRange()
            if overflow and type(maximum)=="number" then scroll:SetVerticalScroll(math.min(maximum,target)) end
        end
    end
    navRendering=false
end
selectTab=function(tab)
    if menu then menu:Hide() end
    state.searchScope=tab=="Database" and "All database" or "This page"
    if tab=="Database" then tab="Items" end
    if tab=="Profession Guides" then tab="Recipes";state.professionView="Guide";state.professionRange="All skills" end
    if tab=="Class Guides" then state.guideSection="BiS" end
    state.questTrace=nil;state.questMode="chain"
    if tab=="Loot Journal" then state.journalLanding=true;state.journalCustomize=nil;state.searchScope="This page" end
    state.tab=tab; state.page=1; state.entity=nil; state.query=""; state.edgePage=1; state.pageFilter="All"; state.quality="All qualities"; state.slot="All slots"; state.relation="All"
    ui.search:SetText(""); ui.detailScroll:SetVerticalScroll(0); render()
end
function A.Open(kind,id,back)
    A.CaptureNavigationScroll()
    A.Show()
    state.questTrace=nil;state.questMode="chain"
    if databaseBrowser() and not state.entity then local scroll=ui.detailScroll:GetVerticalScroll();state.resultsScroll=type(scroll)=="number" and scroll or 0 end
    state.entity={kind=kind,id=id}; state.edgePage=1; state.relation="All"
    ui.detailScroll:SetVerticalScroll(0); render()
end
function A.OpenQuestOutcomes(id)
    A.CaptureNavigationScroll()
    A.Show()
    state.questTrace=id;state.questMode="outcomes"
    ui.detailScroll:SetVerticalScroll(0);render()
end
function A.TraceQuest(id)
    A.CaptureNavigationScroll()
    A.Show()
    if not state.questTrace then local y=ui.detailScroll:GetVerticalScroll();state.traceReturnScroll=type(y)=="number" and y or 0 end
    state.questTrace=id;state.questMode="chain";ui.detailScroll:SetVerticalScroll(0);render()
end
function A.OpenContext(kind,id)
    if kind=="quest" and (state.tab=="Loot Journal" or state.tab=="Attunements") then A.TraceQuest(id);return end
    A.Show()
    state.tab=({item="Items",npc="NPCs",quest="Quests",object="Objects"})[kind] or "Items"
    state.pageFilter="All"; state.quality="All qualities"; state.slot="All slots"
    state.searchScope="This page";state.query=tostring(id); state.page=1; ui.search:SetText(state.query)
    A.Open(kind,id)
end
A.GetView=function() return state end
function A.Show()
    if ui then ui:Show(); return end
    ui=CreateFrame("Frame","ForeverDBWindow",UIParent,"BackdropTemplate")
    A.window=ui; ui:SetSize(1100,765); ui:SetPoint("CENTER"); ui:SetFrameStrata("DIALOG")
    ui:SetClampedToScreen(true); ui:SetMovable(true); ui:EnableMouse(true); ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart",ui.StartMoving); ui:SetScript("OnDragStop",ui.StopMovingOrSizing)
    backdrop(ui,Style.Canvas[1],Style.Canvas[2],Style.Canvas[3],Style.CanvasBorder[1],Style.CanvasBorder[2],Style.CanvasBorder[3])
    ui:SetBackdropColor(unpack(Style.Canvas))
    local headerBar=CreateFrame("Frame",nil,ui,"BackdropTemplate")
    headerBar:SetPoint("TOPLEFT",1,-1); headerBar:SetPoint("TOPRIGHT",-1,-1); headerBar:SetHeight(44)
    headerBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    headerBar:SetBackdropColor(unpack(Style.HeaderBg))
    local headerLine=headerBar:CreateTexture(nil,"OVERLAY")
    headerLine:SetPoint("BOTTOMLEFT",0,0); headerLine:SetPoint("BOTTOMRIGHT",0,0); headerLine:SetHeight(2)
    headerLine:SetColorTexture(unpack(Style.CanvasBorder));headerLine:SetHeight(1)
    local fit=math.min(1,(UIParent:GetWidth()-20)/1100,(UIParent:GetHeight()-20)/765)
    if fit<1 then ui:SetScale(math.max(.5,fit)) end
    table.insert(UISpecialFrames,"ForeverDBWindow")
    ui.brandLabel=label(ui,"|cffffd100F1 FOREVER|r  |cffa3a3a8by Sarcasm|r",20,-13,420,"GameFontNormalLarge")
    ui.versionLabel=label(ui,"|cff8a8a90FOREVER  •  "..A.version.."|r",310,-16,280,"GameFontDisableSmall")
    local close=CreateFrame("Button",nil,ui,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
    ui.nav={}
    for i,tab in ipairs(tabs) do
        local t=tab;local control=button(ui,t,20+(i-1)*177,-52,173,function() selectTab(destinations[t]) end)
        ui.nav[t]=control;control:SetHeight(52)
        illustratedButton(control,t)
    end
    ui.category=button(ui,"",20,-113,335,function(self) choose(self,ui.categoryOptions,function(value) selectTab(value) end) end)
    ui.questNav={}
    ui.questNav.Attunements=button(ui,"Attunes",20,-113,164,function() selectTab("Attunements") end)
    ui.questNav.Quests=button(ui,"Quests",191,-113,164,function() selectTab("Quests") end)
    ui.resultsButton=button(ui,"< Results",20,-729,145,function()
        state.entity=nil;render();ui.detailScroll:SetVerticalScroll(state.resultsScroll or 0)
    end)
    ui.title=label(ui,"Overview",760,-13,290,"GameFontNormalLarge")
    ui.title:SetJustifyH("RIGHT")
    ui.search=CreateFrame("EditBox",nil,ui,"InputBoxTemplate"); ui.search:SetSize(238,27); ui.search:SetPoint("TOPLEFT",22,-149); ui.search:SetAutoFocus(false)
    styleEditBox(ui.search)
    -- Placeholder explains the search; hidden while focused or when text is present.
    ui.searchPlaceholder=ui.search:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ui.searchPlaceholder:SetPoint("LEFT",ui.search,"LEFT",8,0);ui.searchPlaceholder:SetJustifyH("LEFT")
    ui.searchPlaceholder:SetTextColor(.55,.55,.58,1)
    function ui.updateSearchPlaceholder()
        local p=ui.searchPlaceholder
        if not p then return end
        p:SetWidth(math.max(40,(ui.search:GetWidth() or 200)-16))
        p:SetText(state.tab=="Loot Journal" and "Search dungeons, bosses, loot or quests" or "Search by name or ID")
        if ui.search:GetText()=="" and not ui.search.hasFocus then p:Show() else p:Hide() end
    end
    ui.search:HookScript("OnEditFocusLost",function(self) self.hasFocus=false;ui.updateSearchPlaceholder() end)
    ui.search:SetScript("OnEnterPressed",function(self)
        if journalSearchActive() and menu and menu:IsShown() and menu.anchor==self and ui.suggestionNames then selectJournalSuggestion(ui.suggestionNames[ui.suggestionIndex or 1]);return end
        state.query=self:GetText(); state.page=1;state.entity=nil; self:ClearFocus(); render()
    end)
    ui.search:SetScript("OnEscapePressed",function(self) if menu then menu:Hide() end;ui.suggestionNames=nil;self:ClearFocus() end)
    ui.search:SetScript("OnEditFocusGained",function(self)
        self.hasFocus=true;ui.updateSearchPlaceholder()
        -- Selecting the shown dungeon name lets typing replace it instead of appending.
        if journalSearchActive() and self:GetText()~="" and self.HighlightText then self:HighlightText() end
        if journalSearchActive() then journalSuggestions() end
    end)
    ui.search:SetScript("OnArrowPressed",function(_,key) if journalSearchActive() then journalSuggestions(key=="UP" and -1 or 1) end end)
    ui.search:SetScript("OnTabPressed",function() if journalSearchActive() and ui.suggestionNames then selectJournalSuggestion(ui.suggestionNames[ui.suggestionIndex or 1]) end end)
    ui.journalDropdown=button(ui,"v",420,-119,30,function()
        if menu and menu:IsShown() and menu.anchor==ui.search then menu:Hide();return end
        ui.search:SetFocus();journalSuggestions()
    end)
    ui.searchButton=button(ui,"Search",266,-149,68,function() state.query=ui.search:GetText(); state.page=1;state.entity=nil; ui.search:ClearFocus(); render() end)
    ui.searchHint=label(ui,"",478,-156,80,"GameFontDisableSmall")
    ui.searchScope=button(ui,"This page  v",342,-149,125,function(self)
        choose(self,{"This page","All database"},function(value) state.searchScope=value;state.page=1;state.entity=nil;render() end)
    end)
    local searchGeneration=0
    ui.search:SetScript("OnTextChanged",function(self,userInput)
        ui.updateSearchPlaceholder()
        if not userInput then return end
        searchGeneration=searchGeneration+1;local generation=searchGeneration;local tab=state.tab;local value=self:GetText()
        C_Timer.After(.2,function()
            if generation~=searchGeneration or state.tab~=tab or ui.search:GetText()~=value then return end
            state.query=value;state.page=1;state.entity=nil
            if menu then menu:Hide() end
            render()
            if journalSearchActive() then journalSuggestions() end
        end)
    end)
    ui.navBar=CreateFrame("Frame",nil,ui)
    ui.navBar:SetSize(240,30);ui.navBar:SetPoint("BOTTOM",ui,"BOTTOM",0,16)
    ui.navBack=button(ui.navBar,"History back",0,0,112,function() A.Navigate("back") end);ui.navBack:Show()
    ui.navForward=button(ui.navBar,"History forward",128,0,112,function() A.Navigate("forward") end);ui.navForward:Show();ui.navBar:Show()
    for _,b in ipairs({ui.navBack,ui.navForward}) do
        b:SetBackdropBorderColor(.15,.60,1,1)
        b:SetScript("OnEnter",function(self)
            self:SetBackdropColor(unpack(Style.ButtonHoverBg));self:SetBackdropBorderColor(1,.82,0,1)
        end)
        b:SetScript("OnLeave",function(self)
            self:SetBackdropColor(unpack(Style.ButtonBg));self:SetBackdropBorderColor(.15,.60,1,1)
        end)
    end
    ui:HookScript("OnUpdate",function() A.CaptureNavigationScroll() end)
    ui.filter=button(ui,"Filter: All",20,-185,335,function(self) choose(self,ui.filterOptions,function(value) if state.tab=="Favorites" then state.filter=value else state.pageFilter=value end; if state.tab=="Loot Journal" then state.journal=value~="All" and value or nil;state.journalLanding=value=="All"; state.boss=nil end; state.page=1; state.entity=nil; render() end) end)
    ui.levelFilter=button(ui,"All levels",365,-185,160,function(self)
        choose(self,levelOptions,function(value) state.dungeonLevel=value;state.pageFilter="All";state.entity=nil;state.boss=nil;ui.detailScroll:SetVerticalScroll(0);render() end)
    end)
    ui.quality=button(ui,"All qualities",365,-185,160,function(self) choose(self,qualities,function(value) state.quality=value; state.page=1; state.entity=nil; render() end) end)
    ui.slot=button(ui,"All slots",533,-185,160,function(self) if state.tab=="Recipes" then choose(self,{"Recipes","Trainers","Vendors"},function(value) state.professionView=value;state.page=1;state.entity=nil;render() end);return end; choose(self,slots,function(value) state.slot=value; state.page=1; state.entity=nil; render() end) end)
    ui.classSelf=button(ui,"Self",770,-119,130,function()
        A.SetLootClassFilter(A.LootClassFilter()=="SELF" and "ALL" or "SELF")
        ui.detailScroll:SetVerticalScroll(0);render()
    end)
    ui.classSelf:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        local class=UnitClass("player") or "your class"
        GameTooltip:SetText("Class loot filter")
        GameTooltip:AddLine("Self: "..class..". Click to toggle Self / All; another class returns to Self.",1,1,1,true)
        GameTooltip:AddLine("Arrow selects a class. Shows class restrictions and learnable equipment types, not stat recommendations. Unknown items remain visible.",.75,.75,.75,true)
        GameTooltip:Show()
    end)
    ui.classSelf:SetScript("OnLeave",function() GameTooltip:Hide() end)
    ui.classArrow=button(ui,"v",902,-119,28,function()
        if menu and menu:IsShown() then menu:Hide();return end
        menu=CreateFrame("Frame",nil,ui,"BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP");menu:SetClampedToScreen(true)
        menu:SetPoint("TOPRIGHT",ui.classArrow,"BOTTOMRIGHT",0,-4);menu:SetSize(282,192)
        backdrop(menu,.065,.065,.065)
        local popup=menu
        label(menu,"Show loot usable by",10,-8,260,"GameFontNormalSmall")
        local options={{"SELF","Self ("..(UnitClass("player") or "player")..")"},{"ALL","All classes"}}
        for _,c in ipairs(A.LootClasses) do options[#options+1]={c[1],c[2]} end
        for i,o in ipairs(options) do
            local value=o[1];local selected=A.LootClassFilter()==value
            local b=button(popup,(selected and "• " or "")..o[2],8+((i-1)%2)*135,-28-math.floor((i-1)/2)*26,131,function()
                popup:Hide();A.SetLootClassFilter(value);ui.detailScroll:SetVerticalScroll(0);render()
            end)
            b:SetHeight(23);tabStyle(b,selected)
        end
        local wasDown=IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        popup:SetScript("OnUpdate",function(self)
            local down=IsMouseButtonDown and IsMouseButtonDown("LeftButton")
            if down and not wasDown and not self:IsMouseOver() and not ui.classArrow:IsMouseOver() then self:Hide() end
            wasDown=down
        end)
        popup:Show()
    end)
    ui.zoneButton=button(ui,"My zone",746,-119,232,function(self)
        local options={{"my","My zone"},{"All","All zones"}}
        local maps={}
        for id in pairs(ui.professionMaps or {}) do maps[#maps+1]={id,professionZoneName(id)} end
        table.sort(maps,function(a,b) return a[2]<b[2] end)
        for _,entry in ipairs(maps) do options[#options+1]=entry end
        choose(self,options,function(value)
            state.professionZone=value
            if value=="my" then state.professionZone=nil end
            state.searchScope="This page";state.page=1;state.referencePage=1
            ui.detailScroll:SetVerticalScroll(0);render()
        end)
    end)
    ui.reset=button(ui,"Reset filters",701,-185,130,function() if state.tab=="Recipes" then state.professionZone=nil end; if state.tab=="Loot Journal" then A.SetLootClassFilter("SELF") end; state.pageFilter="All"; state.dungeonLevel="All levels"; state.quality="All qualities"; state.slot="All slots"; state.query=""; state.page=1;state.entity=nil; ui.search:SetText(""); render() end)
    ui.leftPanel=CreateFrame("Frame",nil,ui,"BackdropTemplate"); ui.leftPanel:SetPoint("TOPLEFT",20,-223); ui.leftPanel:SetSize(335,497); backdrop(ui.leftPanel,Style.PanelBg[1],Style.PanelBg[2],Style.PanelBg[3]);ui.leftPanel:SetBackdropColor(unpack(Style.PanelBg));ui.leftPanel:SetBackdropBorderColor(0,0,0,0)
    ui.rightPanel=CreateFrame("Frame",nil,ui,"BackdropTemplate"); ui.rightPanel:SetPoint("TOPLEFT",365,-223); ui.rightPanel:SetSize(715,497); backdrop(ui.rightPanel,Style.PanelBg[1],Style.PanelBg[2],Style.PanelBg[3]);ui.rightPanel:SetBackdropColor(unpack(Style.PanelBg));ui.rightPanel:SetBackdropBorderColor(0,0,0,0)
    local leftHead=CreateFrame("Frame",nil,ui.leftPanel,"BackdropTemplate")
    leftHead:SetPoint("TOPLEFT",1,-1); leftHead:SetPoint("TOPRIGHT",-1,-1); leftHead:SetHeight(26)
    leftHead:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); leftHead:SetBackdropColor(unpack(Style.PanelHeader))
    label(leftHead,"|cffa3a3a8BROWSE|r",10,-7,160,"GameFontDisableSmall")
    ui.listMetaHeader=label(leftHead,"",250,-7,75,"GameFontDisableSmall"); ui.listMetaHeader:SetJustifyH("RIGHT")
    local rightHead=CreateFrame("Frame",nil,ui.rightPanel,"BackdropTemplate")
    ui.rightHead=rightHead
    rightHead:SetPoint("TOPLEFT",1,-1); rightHead:SetPoint("TOPRIGHT",-1,-1); rightHead:SetHeight(26)
    rightHead:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); rightHead:SetBackdropColor(unpack(Style.PanelHeader))
    label(rightHead,"|cffa3a3a8DETAILS|r",12,-7,500,"GameFontDisableSmall")
    ui.list=CreateFrame("Frame",nil,ui.leftPanel); ui.list:SetPoint("TOPLEFT",6,-32); ui.list:SetSize(323,1); ui.list.rows={}
    ui.detailScroll=CreateFrame("ScrollFrame",nil,ui,"UIPanelScrollFrameTemplate")
    ui.detailScroll:SetPoint("TOPLEFT",375,-255); ui.detailScroll:SetPoint("BOTTOMRIGHT",-42,52)
    styleScrollBar(ui.detailScroll)
    ui.detailScroll:EnableMouseWheel(true)
    ui.detailScroll:HookScript("OnScrollRangeChanged",updateDetailScrolling)
    ui.detailScroll:SetScript("OnMouseWheel",function(self,delta)
        local sb=self.ScrollBar
        if sb and sb.GetValue and sb.SetValue then
            sb:SetValue(math.max(0,(sb:GetValue() or 0)-delta*60))
        else
            local cur=type(self:GetVerticalScroll())=="number" and self:GetVerticalScroll() or 0
            local max=type(self:GetVerticalScrollRange())=="number" and self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0,math.min(max,cur-delta*60)))
        end
    end)
    ui.detail=CreateFrame("Frame",nil,ui.detailScroll); ui.detail:SetSize(670,1); ui.detail.rows={}; ui.detailScroll:SetScrollChild(ui.detail)
    ui.journalSearchLabel=label(ui,"Search dungeons, bosses or loot",240,-113,480,"GameFontDisableSmall")
    ui.journalSearchLabel:SetJustifyH("CENTER")
    ui.journalSectionLabel=label(ui,"Dungeons & Raids",30,-126,170,"GameFontNormal")
    ui.journalCustomizeButton=button(ui,"Customize Gear Journal",850,-119,220,function()
        state.journalCustomize=true;ui.detailScroll:SetVerticalScroll(0);render()
    end)
    ui.bisHeader=CreateFrame("Frame",nil,ui);ui.bisHeader:SetSize(1060,72);ui.bisHeader.rows={};ui.bisHeader:Hide()
    ui.journalHeader=CreateFrame("Frame",nil,ui);ui.journalHeader:SetPoint("TOPLEFT",20,-159);ui.journalHeader:SetSize(1060,102);ui.journalHeader.rows={}
    ui.journalRailScroll=CreateFrame("ScrollFrame",nil,ui,"UIPanelScrollFrameTemplate")
    ui.journalRailScroll:SetPoint("TOPLEFT",20,-269);ui.journalRailScroll:SetSize(300,451)
    styleScrollBar(ui.journalRailScroll)
    ui.journalRailScroll:EnableMouseWheel(true)
    ui.journalRailScroll:SetScript("OnMouseWheel",function(self,delta)
        local cur=self:GetVerticalScroll() or 0;local maximum=self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0,math.min(maximum,cur-delta*54)))
    end)
    ui.journalRail=CreateFrame("Frame",nil,ui.journalRailScroll);ui.journalRail:SetSize(300,1);ui.journalRail.rows={}
    ui.journalRailScroll:SetScrollChild(ui.journalRail)
    ui.previous=button(ui,"Previous page",30,-687,106,function() if ui.changeListPage then ui.changeListPage(-1) end end)
    ui.next=button(ui,"Next page",142,-687,94,function() if ui.changeListPage then ui.changeListPage(1) end end)
    ui.page=label(ui,"",244,-694,230,"GameFontDisableSmall")
    ui.footerNote=label(ui,"|cffffd100F1 FOREVER|r  •  Right-click for Favorites",26,-737,370,"GameFontDisableSmall")
    ui.listName=CreateFrame("EditBox",nil,ui,"InputBoxTemplate"); ui.listName:SetPoint("TOPLEFT",480,-149); ui.listName:SetSize(165,27); ui.listName:SetAutoFocus(false)
    styleEditBox(ui.listName)
    ui.listName:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    ui.newList=button(ui,"New list",655,-149,90,function()
        local l=A.NewList(ui.listName:GetText()); if l then state.list=l.id; ui.listName:SetText(""); ui.listName:ClearFocus(); render() end
    end)
    ui.renameList=button(ui,"Rename",753,-149,90,function()
        local name=ui.listName:GetText():match("^%s*(.-)%s*$")
        if name~="" then for _,l in ipairs(ForeverDB_Favorites.lists) do if l.id==state.list then l.name=name:sub(1,60) end end end
        ui.listName:ClearFocus(); render()
    end)
    ui.copy=CreateFrame("EditBox",nil,ui,"InputBoxTemplate"); ui.copy:SetPoint("BOTTOMLEFT",375,14); ui.copy:SetSize(460,27); ui.copy:SetAutoFocus(false)
    styleEditBox(ui.copy)
    ui.copy:SetScript("OnEscapePressed",function(self) self:ClearFocus(); self:Hide() end)
    render()
end
A.Refresh=function() if ui and ui:IsShown() then render() end end
