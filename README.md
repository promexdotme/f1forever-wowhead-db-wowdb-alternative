# F1-Forever — an in-game WoW database

Hover an item, NPC or quest and press **F1**. F1-Forever opens a Wowhead-style database inside World of Warcraft: Forever. Follow a drop to its boss, a recipe to its vendor, or a dungeon quest back to the step you still need.

**[Install F1-Forever on CurseForge](https://www.curseforge.com/wow/addons/f1-forever)** · [10.1.4 release notes](CHANGELOG.md)

## Looking for a Wowhead DB or WowDB alternative?

If you usually tab out to answer “Where does this come from?”, start with the same item in game. Search by name or ID, then follow its recorded connections. For a recipe, that can mean checking what it makes, which reagents it needs, who sells or teaches it, and where to find that NPC. Locations with recorded coordinates can open a map pin. Coverage varies by item and faction.

![F1-Forever item relationships in the game client](screenshots/sources.webp)

## Is this drop worth rolling on?

Choose your spec and slot under **BiS & Talents**. The 10.1.4 release ranks up to ten items per slot using Forever item stats and WoWSims weights. Toggle between full hit value and already capped. Blue-bordered rows also surface crafted tier pieces. Consider their set bonuses separately when choosing what to wear.

![Balance Druid glove rankings showing tier pieces, scores and item sources](screenshots/gear.webp)

## What do I need before this dungeon?

Open **Gear Journal**, choose a dungeon and expand a quest. The chain shows completed steps and the quest currently in your log. The Profession Guides cover recipes, reagents and recorded trainers or vendors.

![Scarlet Monastery quest chain showing completed prerequisites and the active step](screenshots/quests.webp)

## Install and open

Install the Forever edition from the CurseForge link above and enable **F1 Forever** at character selection. Type **/f1** to open the browser. If another action uses F1, open **Settings & Credits** to change the binding.

## Repository contents and credits

The [Lua source](F1Forever/) contains the browser UI, relationship lookup, item probing and tooltip comparison modules from the shipped 10.1.4 release. The installable addon, including generated data tables, guides and artwork, is distributed on CurseForge. GitHub's **Download ZIP** provides this source snapshot.

F1-Forever is an independent addon by **Sarcasm**. Wowhead and WowDB are referenced for comparison. The project draws on Forever client data, [WoWSims Forever](https://github.com/wowsims/forever), [QuestieDB](https://github.com/Questie/QuestieDB) and [Napalmsteak's item caches](https://github.com/Napalmsteak/WoW-Classic-Item-Caches).

Found a missing source or incorrect connection? Open a GitHub issue with the item or NPC name or ID, the Forever client version, and what you observed in game.
