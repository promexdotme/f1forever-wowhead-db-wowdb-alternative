local _,A=...
local D=A.Data
local slots={[1]="Head",[2]="Neck",[3]="Shoulder",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",[9]="Wrist",[10]="Hands",[11]="Finger",[12]="Trinket",[13]="One-hand",[14]="Shield",[15]="Ranged",[16]="Back",[17]="Two-hand",[20]="Chest",[21]="Main hand",[22]="Off hand weapon",[23]="Held off hand",[25]="Ranged",[26]="Ranged",[28]="Relic"}
A.ProbeSlots=slots
A.ProbeSlotOrder={"Head","Neck","Shoulder","Back","Chest","Wrist","Hands","Waist","Legs","Feet","Finger","Trinket","One-hand","Main hand","Two-hand","Off hand weapon","Shield","Held off hand","Ranged","Relic"}

-- Rankings are generated offline. Live observations become eligible in the next export.
function A.ProbeRankingStatus(id)
    local _,build=GetBuildInfo()
    if D.ProbeSeedBuild=="offline-cache" then
        return D.ScoredProbeIDs[id] and "Outside this top 10" or "No offline score"
    end
    if tostring(build)==D.ProbeSeedBuild and D.ScoredProbeIDs[id] then return "Outside scored top 10" end
    local active=ForeverDB_Config.shoulderProbeCache
    if active and tostring(active.build)==tostring(build) and active.items[id] then return "Cached for offline scoring" end
    return "Awaiting probe"
end

function A.ProbeRankings(profile,model)
    local _,build=GetBuildInfo()
    local ranks=D.ProbeLists[profile]
    if (D.ProbeSeedBuild=="offline-cache" or tostring(build)==D.ProbeSeedBuild) and ranks then
        return ranks[model] or {},D.ProbeNotes,ranks.count
    end
    return {},{},0
end
