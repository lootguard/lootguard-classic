local L = LibStub("AceLocale-3.0"):GetLocale("LootGuardClassic", true)

-- Loot handling functions
-- triggers

-- if you loot yourself
function LGC:LOOT_OPENED()
	-- disabled or not ml?
    if not LGC.db.profile.enabled or not LGC:isUserMasterLooter() then
        return
    end

	-- only if announcement from loot window is ok
    if not LGC.db.profile.lootwindow then
	  return
	end

	-- only works in raid, unless debugging
	if not UnitInRaid("player") and not LGC.db.profile.debug then
	  return
	end

	-- look if priorities are defined
	if tempty(LGC.db.profile.priorities) then
		if LGC.onetimenotifications["prio_unset"] == nil then
			LGC:Print(L["No priorities defined."])
			LGC.onetimenotifications["prio_unset"] = 1
		end
		LGC:Debug("Leaving LOOT_OPENED because of LGC.db.profile.priorities")
		return
	end

	-- process the event
	local loot = GetLootInfo()
	local numLootItems = GetNumLootItems();

	-- look for maximum quality (for No prio announces)
	local maxQuality = "a"

	local reportLinks = {}

	-- might not work out with "faster autoloot" addons like Leatrix
	-- so get the itemlinks as fast as possible, then do other stuff
	for i=1,numLootItems do
		local itemLink = GetLootSlotLink(i)
		if itemLink then
			table.insert(reportLinks, itemLink)
		end
	end

    -- search for item level (e.g. epics) to determine if we print output
	for dummy,itemLink in pairs(reportLinks) do
		if itemLink then
			-- if no itemLink, it's most likely money

			local d, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2 = strsplit(":", itemLink)

            -- check for disenchant mats
			if LGC.db.profile.ignoredisenchants then
				local i = tonumber(itemId)
				if i == 20725 or i == 14344 -- Nexus Crystal / Large Briliant Shard
				or i == 22450 or i == 22449 -- Void Crystal / Large Prismatic Shard
				or i == 34057 or i == 34052 -- Abyss Crystal / Dream Shard
				then
					LGC:Debug("Leaving LOOT_OPENED because of found disenchant materials")
					return
				end
			end

			-- identifying quality by color...
			-- Only other option would be GetItemInfo, but that might not be fully loaded, so I would have to create call to wait and look into it later, and... well, PITA

			if d == "\124cffff8000\124Hitem" then  if maxQuality < "f" then maxQuality = "f" end end -- LEGENDARY
			if d == "\124cffa335ee\124Hitem" then  if maxQuality < "e" then maxQuality = "e" end end -- Epic
			if d == "\124cff0070dd\124Hitem" then  if maxQuality < "d" then maxQuality = "d" end end -- Rare
			if d == "\124cff1eff00\124Hitem" then  if maxQuality < "c" then maxQuality = "c" end end -- Uncommon
			if d == "\124cffffffff\124Hitem" then  if maxQuality < "b" then maxQuality = "b" end end -- Common

		end
	end

	-- handle loot
	for dummy,itemLink in pairs(reportLinks) do
		LGC:HandleLoot(itemLink, maxQuality)
	end

end

-- if someone loots without PM active
function LGC:START_LOOT_ROLL(eventname, rollID, rollTime, lootHandle)
	-- disabled or not ml?
    if not LGC.db.profile.enabled or not LGC:isUserMasterLooter() then
        return
    end

	-- only works in raid, unless debugging
	if not UnitInRaid("player") and not LGC.db.profile.debug then
	  return
	end

	-- look if priorities are defined
	if tempty(LGC.db.profile.priorities) then
		if LGC.onetimenotifications["prio_unset"] == nil then
			LGC:Print(L["No priorities defined."])
			LGC.onetimenotifications["prio_unset"] = 1
		end
		LGC:Debug("Leaving START_LOOT_ROLL because of LGC.db.profile.priorities")
		return
	end

	-- will only react to epics

	local texture, name, count, quality, bop = GetLootRollItemInfo(rollID)
	local itemLink = GetLootRollItemLink(rollID)

	if quality >= 4 or bop then
		LGC:Print("Found loot roll for " .. itemLink)
		-- use "maximum quality z" item, so it will always post
		LGC:HandleLoot(itemLink, "z")
	end

end

-- if someone posts something on Raid Warning (commonly asking for rolls)
function LGC:CHAT_MSG_RAID_WARNING(event, text, sender)
	-- disabled or not ml?
    if not LGC.db.profile.enabled or not LGC:isUserMasterLooter() then
        return
    end

	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	-- itemLink looks like |cff9d9d9d|Hitem:3299::::::::20:257::::::|h[Fractured Canine]|h|r

	-- TODO: avoid race condition
	-- sending out notification first and waiting for AceTimer: Might collide as well
	-- will need to clear priorisation WHO will send out.
	-- send random number, and send answer if you will not post
	-- highest number wins, so only lower numbers need to send they won't participate

	local id = text:match("|Hitem:(%d+):")

	if id then
		LGC:Debug("Received Raid Warning for item " .. id)

		-- ignore Onyxia Scale Cloak if configured
		if LGC.db.profile.ignorescalecloak and tonumber(id) == 15138 then
			LGC:Debug("Ignoring Onyxia Scale Cloak")
			return nil
		end
		-- ignore Drakefire Amulet if configured
		if LGC.db.profile.ignoredrakefire and tonumber(id) == 16309 then
			LGC:Debug("Ignoring Drakefire Amulet")
			return nil
		end

		-- announce to other addon that we want to react to raidwarning, but only if we would send something out actually
		if LGC.db.profile.raidannounce then

			LGC.doReactToRaidWarning = true
			local commmsg = { command = "RAIDWARNING", item = id, addon = LGC.addon_id, version = LGC.versionString }
			LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "ALERT")

			-- invoce AceTimer to wait 1 second before posting
			LGC:ScheduleTimer("reactToRaidWarning", 1, id, sender)

		end

	end

end


function LGC:reactToRaidWarning(id, sender)

	-- look if priorities are defined
	if tempty(LGC.db.profile.priorities) then
		if LGC.onetimenotifications["prio_unset"] == nil then
			LGC:Print(L["No priorities defined."])
			LGC.onetimenotifications["prio_unset"] = 1
		end
		LGC:Debug("Leaving reactToRaidWarning because of LGC.db.profile.priorities")
		return
	end


	if LGC.doReactToRaidWarning then
		local _, itemLink = GetItemInfo(id) -- might not return item link right away

		if itemLink then
			-- use "maximum quality z" item, so it will always post
			LGC:HandleLoot(itemLink, "z")
		else
			-- well, we COULD match the whole itemLink
			-- deferred handling
			local t = {
				needed_itemids = { id },
				vars = { u = sender },
				todo = function(itemlinks,vars)
					for _, itemlink in pairs(itemlinks) do
						-- use "maximum quality z" item, so it will always post
						LGC:HandleLoot(itemlink, "z")
					end
				end,
			}
			table.insert(LGC.GET_ITEM_INFO_RECEIVED_TodoList, t)
		end

	end

end

function LGC:postLastBossMessage()
	LGC:Print(L["Congratulations on finishing the Raid!"])
	LGC:Print(L["Thank you for using LGC."])
	LGC:Print(L["If you like it, Allaister on EU-Everlook (Alliance) is gladly taking donations!"])

	LGC:ScheduleTimer("postLastBossMessageUIOne", 1)
	LGC:ScheduleTimer("postLastBossMessageUITwo", 4)
	LGC:ScheduleTimer("postLastBossMessageUIThree", 7)
end

function LGC:postLastBossMessageUIOne()
	UIErrorsFrame:AddMessage(L["Congratulations on finishing the Raid!"])
end
function LGC:postLastBossMessageUITwo()
	UIErrorsFrame:AddMessage(L["Thank you for using LGC."])
end
function LGC:postLastBossMessageUIThree()
	UIErrorsFrame:AddMessage(L["If you like it, Allaister on EU-Everlook (Alliance) is gladly taking donations!"])
end


-- handling

function LGC:HandleLoot(itemLink, qualityFound)

	-- Loot found, but no itemLink: most likely money
	if itemLink == nil then
		return
	end

	-- look if priorities are defined
	if tempty(LGC.db.profile.priorities) then
		if LGC.onetimenotifications["prio_unset"] == nil then
			LGC:Print(L["No priorities defined."])
			LGC.onetimenotifications["prio_unset"] = 1
		end
		LGC:Debug("Leaving HandleLoot because of LGC.db.profile.priorities")
		return
	end

	local _, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2 = strsplit(":", itemLink)
	-- bad argument, might be gold? (or copper, here)

    if tonumber(itemId) == 29434 then
	  -- badge of justice, ignore
	  return
	end

	if LGC.onetimenotifications["finalboss"] == nil then
		local i = tonumber(itemId)

		if 	   i == 19802 -- Heart of Hakkar
			or i == 21220 -- Head of Ossirian the Unscarred
			or i == 18422 or i == 18423 -- Head of Onyxia
			or i == 19002 or i == 19003 -- Head of Nefarian
			or i == 21221 -- Eye of C'thun
			or i == 22520 -- Phylactery of Kel'Thuzad
			or i == 16946 or i == 16901 or i == 16915 or i == 16930 or i == 16922 or i == 16909 or i == 16962 or i == 16938 or i == 16954 -- Ragnaros has no head... So, T2 legs. All of them.
			or i == 29759 or i == 29761 or i == 29760 -- Prince Malchezaar T4-Heads
			or i == 29767 or i == 29765 or i == 29766 -- Gruul T4-Leggings
			or i == 32385 or i == 32386 -- Magtheridon's Head
			or i == 30244 or i == 30243 or i == 30242 -- Vashj T5-Heads
			or i == 32405 -- Kaelthas Verdant Sphere
			or i == 31097 or i == 31095 or i == 31096 -- Archimond T6-Heads
			or i == 31091 or i == 31089 or i == 31090 -- Illidan T6-Chests
			or i == 33102 -- Blood of Zul'jin
			-- sunwell: puh, that'll be all items from Kil'Jaeden? Let's leave it out for now
			-- WOTLK: Need to find best possible option. new Onyxia, Anub'arak, Lich King, Kel'Thuzad, Malygos.
			-- all have a bunch of items, but no specific "trigger" item. I don't want to insert full loot tables, for N10, H10, N25, H25...
			-- maybe I have to work with kills, not loots, to find a trigger for last boss message...
		then
			LGC:ScheduleTimer("postLastBossMessage", 12)
			LGC.onetimenotifications["finalboss"] = i
		end
	end


	-- ignore re-opened
	-- re-open is processed by Item

	-- initialization of tables
	if LGC.db.profile.lootlastopened == nil then
		LGC.db.profile.lootlastopened = {}
	end
	if LGC.db.profile.lootlastopened[itemId] == nil then
		LGC.db.profile.lootlastopened[itemId] = 0
	end

	if LGC.db.profile.ignorereopen == nil then
		LGC.db.profile.ignorereopen = 0
	end

	local outputSent = false

	if LGC.db.profile.lootlastopened[itemId] + LGC.db.profile.ignorereopen < time() then
	-- enough time has passed, not ignored.

		-- build local prio list
		local itemprios = {
			p0 = {},
			p1 = {},
			p2 = {},
			p3 = {}
		}

		-- iterate over priority table
		for user, prios in pairs(LGC.db.profile.priorities) do

			-- table always has 3 elements
			if (tonumber(prios[1]) == tonumber(itemId)) then
				table.insert(itemprios.p1, user)
			end

			if (tonumber(prios[2]) == tonumber(itemId)) then
				table.insert(itemprios.p2, user)
			end

			if (tonumber(prios[3]) == tonumber(itemId)) then
				table.insert(itemprios.p3, user)
			end

			-- Extra entry for prio 0
			if LGC.db.profile.prio0 then
				if  tonumber(prios[1]) == tonumber(itemId) and
					tonumber(prios[2]) == tonumber(itemId) and
					tonumber(prios[3]) == tonumber(itemId) then
						table.insert(itemprios.p0, user)

						-- if a user has Prio0, remove him from Prio 1,2,3 outputs
						LGC:tRemoveValue(itemprios.p1, user)
						LGC:tRemoveValue(itemprios.p2, user)
						LGC:tRemoveValue(itemprios.p3, user)
				end
			end

		end

		if table.getn(itemprios.p0) == 0 and table.getn(itemprios.p1) == 0 and table.getn(itemprios.p2) == 0 and table.getn(itemprios.p3) == 0 then
			if LGC.db.profile.noprioannounce then
				if (qualityFound >= LGC.db.profile.noprioannounce_quality) or LGC.db.profile.noprioannounce_noepic then
					if itemLink then
						outputSent = LGC:Output(L["No priorities found for playerOrItem"](itemLink))	or outputSent
					end
				end
			end
		end

		if table.getn(itemprios.p0) > 0 then
			outputSent = LGC:Announce(itemLink, 0, itemprios.p0) or outputSent
		end
		if table.getn(itemprios.p1) > 0 then
			outputSent = LGC:Announce(itemLink, 1, itemprios.p1, (table.getn(itemprios.p0) > 0)) or outputSent
		end
		if table.getn(itemprios.p2) > 0 then
			outputSent = LGC:Announce(itemLink, 2, itemprios.p2, (table.getn(itemprios.p0)+table.getn(itemprios.p1) > 0)) or outputSent
		end
		if table.getn(itemprios.p3) > 0 then
			outputSent = LGC:Announce(itemLink, 3, itemprios.p3, (table.getn(itemprios.p0)+table.getn(itemprios.p1)+table.getn(itemprios.p2) > 0)) or outputSent
		end

	else
		LGC:Debug("DEBUG: Item " .. itemLink .. " ignored because of mute time setting")
	end

	-- send only notification if you actually outputted something. Otherwise, someelse else might want to output, even if you don't have it enabled
	if LGC.db.profile.comm_enable_item and outputSent then
		local commmsg = { command = "ITEM", item = itemId, itemlink = itemLink, ignore = LGC.db.profile.ignorereopen, addon = LGC.addon_id, version = LGC.versionString }
		LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "ALERT")
	end

	LGC.db.profile.lootlastopened[itemId] = time()

end


-- outputs

function LGC:Output(msg)
	if LGC.db.profile.raidannounce and UnitInRaid("player") then
		SendChatMessage(msg, "RAID")
		return true
	else
		LGC:Print(msg)
		return false
	end
end

function LGC:Announce(itemLink, prio, chars, hasPreviousPrio)

	-- output to raid or print to user
	local msg = L["itemLink is at priority for users"](itemLink, prio, chars)

	local ret = LGC:Output(msg)

	-- whisper to characters
	local whispermsg = L["itemlink dropped. You have this on priority x."](itemLink, prio)

	-- add request to roll, if more than one user and no one has a higher priority
	-- yes, this will ignore the fact you might have to roll if higher priority users already got that item on another drop. But well, this doesn't happen very often.
	if not hasPreviousPrio and table.getn(chars) >= 2 then whispermsg = whispermsg .. " " .. L["You will need to /roll when item is up."] end

	if LGC.db.profile.charannounce then
		for dummy, chr in pairs(chars) do
			-- whisper if target char is in RAID. In debug mode whisper only to your own player char
			if (UnitInRaid(chr)) or (LGC.db.profile.debug and chr == UnitName("player")) then
				SendChatMessage(whispermsg, "WHISPER", nil, chr);
			else
				LGC:Debug("DEBUG: " .. chr .. " not in raid, will not send out whisper notification")
			end
		end
	end

	return ret

end