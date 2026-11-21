local _, A = ...
A.version = "10.1.4"
A.Data = {}
A.kindTable = {item="Items", npc="NPCs", quest="Quests", object="Objects", recipe="Recipes"}
A.colors = {"ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80"}
function A.Safe(v)
    return not (issecretvalue and issecretvalue(v))
end
function A.Message(text) print("|cff45d9df[F1 Forever]|r " .. text) end
