local L = LibStub("AceLocale-3.0"):GetLocale("LootGuardClassic", true)

-- query functions

function LGC:QueryUser(username, whisperto)
	local priotab = LGC.db.profile.priorities[username]

	if not priotab then
		SendChatMessage(L["No priorities found for playerOrItem"](username), "WHISPER", nil, whisperto)

	else
		local linktab = {}
		for dummy,prio in pairs(priotab) do

			local itemName, itemLink = GetItemInfo(prio)
			table.insert(linktab, itemLink)
		end
		local whisperlinks = table.concat(linktab, ", ")
		SendChatMessage(L["Priorities of username: list"](username, whisperlinks), "WHISPER", nil, whisperto)
	end
end

function LGC:QueryItem(item, whisperto)
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(item)
	local itemID = select(3, strfind(itemLink, "item:(%d+)"))

	local prios = {}

	for username,userprio in pairs(LGC.db.profile.priorities) do
		for pr,item in pairs(userprio) do
			if tonumber(item) == tonumber(itemID) then
				table.insert(prios, username .. " (" .. pr .. ")")
			end
		end
	end

	if table.getn(prios) > 0 then
		SendChatMessage(L["itemLink on Prio at userpriolist"](itemLink, table.concat(prios, ", ").." Total: "..table.getn(prios)), "WHISPER", nil, whisperto)
	else
		SendChatMessage(L["No priorities found for playerOrItem"](itemLink), "WHISPER", nil, whisperto)
	end

end


function LGC:CHAT_MSG_WHISPER(event, text, sender)
	-- disabled?
    if not LGC.db.profile.enabled then
	  return
	end

	-- sender may contain "-REALM"
	sender = strsplit("-", sender)

	if LGC.db.profile.queryself and string.upper(text) == "PRIO" then
		return LGC:QueryUser(sender, sender)
	end

	local cmd, qry = strsplit(" ", text, 2)
	cmd = string.upper(cmd)

	if cmd == "PRIO" then

		local function strcamel(s)
			return string.upper(string.sub(s,1,1)) .. string.lower(string.sub(s,2))
		end

		if qry and UnitInRaid(qry) and LGC.db.profile.queryraid then
			return LGC:QueryUser(strcamel(qry), sender)
		end

		if qry and GetItemInfo(qry) and LGC.db.profile.queryitems then
			return LGC:QueryItem(qry, sender)
		end

	end

	-- not returned yet? See if we are accepting new whispers
	if LGC.db.profile.acceptwhisperprios then
		LGC:ParseWhisperLine(sender, text)
	end

end
