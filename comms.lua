local L = LibStub("AceLocale-3.0"):GetLocale("LootGuardClassic", true)

function LGC:sendPriorities()
	if LGC.db.profile.comm_enable_prio then
		local commmsg = { command = "SEND_PRIORITIES", prios = LGC.db.profile.priorities, importtime = self.db.profile.prioimporttime, addon = LGC.addon_id, version = LGC.versionString }
		LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")
	end
end

function LGC:requestPing()
	local commmsg = { command = "PING", addon = LGC.addon_id, version = LGC.versionString }
	LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")
end

function LGC:sendPong()
	local commmsg = { command = "PONG", addon = LGC.addon_id, version = LGC.versionString }
	LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")
end

function LGC:PARTY_LOOT_METHOD_CHANGED()
	if LGC:isUserMasterLooter() then
		self.addon_id = 1000001
	else
		self.addon_id = random(1, 999999)
		if #self.versionString > 9 then self.addon_id = 1000000 end
	end
end

function LGC:GROUP_ROSTER_UPDATE()
	-- request priorities if entering a new raid

	if UnitInParty("player") and not LGC.previousGroupState then
		LGC:requestPing()

		-- joined group: request Prio data
		if LGC.db.profile.enabled then
			local commmsg = { command = "REQUEST_PRIORITIES", addon = LGC.addon_id, version = LGC.versionString }
			LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")

			-- if no prio data received after 10sec, ask to disable Addon
			local current = time()
			LGC:ScheduleTimer("reactToRequestPriorities", 10, current)
		else
			LGC:Print(L["LootGuard Classic addon is currently disabled."])
		end

	end

	LGC.previousGroupState = UnitInParty("player")

	-- look into Loot Method
	LGC:PARTY_LOOT_METHOD_CHANGED()
end

function LGC:reactToRequestPriorities(requested)
	if LGC.db.profile.receivedPriorities < requested then
		-- didn't receive priorities after requesting them
		LGC:askToDisable(L["You joined a new group. I looked for other LootGuard Classic addons, but found none. If this is not a Prio3 group, do you want to disable your addon or at least clear old priorities?"])
	end
end

function LGC:reactToVersionMatch(usr)
	if math.random(5) == 1 then
		DoEmote("CHEER", usr)
		LGC.onetimenotifications["masterversion"] = 1
		LGC:ScheduleTimer("unreactToVersionMatch", 600)
	end
end

function LGC:unreactToVersionMatch()
	LGC.onetimenotifications["masterversion"] = 0
end


function LGC:OnCommReceived(prefix, message, distribution, sender)
	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	-- don't react to own messages
	if sender == UnitName("player") then
		return 0
	end

    local success, deserialized = LGC:Deserialize(message);

	-- first thing we'll do: Note down the version
	if success then
		local remoteversion = deserialized["version"]
		if remoteversion then
			local remversion = strsub(remoteversion, 1, 9)
			LGC.raidversions[sender] = remversion
		end
	end

	-- disabled? get out here. Only thing that happened was recording the version in raid
    if not LGC.db.profile.enabled then
	  return
	end

	-- every thing else get handled if (if not disabled)
    if success then

	    local remoteversion = deserialized["version"]
		if remoteversion then
		    local remversion = strsub(remoteversion, 1, 9)
			if (remversion > LGC.versionString) and (LGC.onetimenotifications["version"] == nil) then
				LGC:Print(L["Newer version found at user: version. Please update your addon."](sender, remversion))
				LGC.onetimenotifications["version"] = 1
			end
			if (#remoteversion > 9) and (strsub(remoteversion, 10, 22) == "-VNzGurNhgube") and (LGC.onetimenotifications["masterversion"] == nil) then
				LGC:ScheduleTimer("reactToVersionMatch", 3, sender)
			end
		end

		if LGC.db.profile.debug then
			LGC:Print(distribution .. " message from " .. sender .. ": " .. deserialized["command"])
		end

		-- another addon handled an Item
		if (deserialized["command"] == "ITEM") and (LGC.db.profile.comm_enable_item) then
			-- mark as handled just now and set ignore time to maximum of yours and remote time
			if LGC.db.profile.debug then
				-- only announce in debug mode: You will have seen the raid notification anyway, most likely
				LGC:Print(L["sender handled notification for item"](sender, deserialized["itemlink"]))
			end
			LGC.db.profile.lootlastopened[deserialized["item"]] = time()
			LGC.db.profile.ignorereopen = max(LGC.db.profile.ignorereopen, deserialized["ignore"])
		end

		-- RAIDWARNING
		if deserialized["command"] == "RAIDWARNING" then
			-- another add stated they want to react to a raidwarning. Let the highest id one win.
			if deserialized["addon"] >= LGC.addon_id then
				LGC.doReactToRaidWarning = false
				LGC:Debug(sender .. " wants to react to Raid Warning, and has a higher ID, so " .. sender .. " will go ahead.")
			else
				LGC:Debug(sender .. " wants to react to Raid Warning, but has a lower ID, so I will go ahead.")
			end
		end

		-- RECEIVED_PRIORITIES
		if deserialized["command"] == "RECEIVED_PRIORITIES" then
			LGC:Print(L["sender received priorities and answered"](sender, L[deserialized["answer"]]))
		end

		-- SEND_PRIORITIES
		if (deserialized["command"] == "SEND_PRIORITIES") and (LGC.db.profile.comm_enable_prio) then

			if LGC:isUserMasterLooter() then
				local newPriorities = deserialized["prios"]
				local newReceived = time()
				LGC:Print(L["Received new priorities sent from sender, but I am Master Looter"](sender))
				LGC:askToAcceptIncomingPriorities(sender, newPriorities, newReceived)

			else
				-- no master looting is used, or player is not master looter
				LGC.db.profile.priorities = deserialized["prios"]
				LGC.db.profile.receivedPriorities = time()
				LGC:Print(L["Accepted new priorities sent from sender"](sender))
				local commmsg = { command = "RECEIVED_PRIORITIES", answer = "accepted", addon = LGC.addon_id, version = LGC.versionString }
				LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")
			end
		end

		-- REQUEST_PRIORITIES
		if (deserialized["command"] == "REQUEST_PRIORITIES") and (LGC.db.profile.comm_enable_prio) then
			LGC:sendPriorities()
		end

		if (deserialized["command"] == "PING") then
			LGC:Debug("Got PING request from " .. sender)
			LGC:sendPong()
		end

		if (deserialized["command"] == "PONG") then
			LGC:Debug("Seen PONG answer from " .. sender)
		end

	else
		if LGC.db.profile.debug then
			LGC:Print("ERROR: " .. distribution .. " message from " .. sender .. ": cannot be deserialized")
		end
	end
end