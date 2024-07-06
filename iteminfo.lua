local L = LibStub("AceLocale-3.0"):GetLocale("LootGuardClassic", true)

function LGC:GET_ITEM_INFO_RECEIVED(event, itemID, success)
	-- disabled?
    if not LGC.db.profile.enabled then
	  return
	end

	-- sadly, GetItemInfo does not always work, especially when the item wasn't seen since last restart, it will turn up nil on many values, until... GET_ITEM_INFO_RECEIVED was fired.
	-- But there is no blocking wait for an event. I would have to script a function to run when GET_ITEM_INFO_RECEIVED was received, and let that function handle what I wanted to do with the Item info
	-- Waiting alone proved not to be a good choice. So meh, populating a to do list GET_ITEM_INFO_RECEIVED_TodoList for this event

	-- don't fire on Every event. Give it 2 seconds to catch up
	if LGC.GET_ITEM_INFO_Timer == nil then
		LGC.GET_ITEM_INFO_Timer = LGC:ScheduleTimer("GET_ITEM_INFO_RECEIVED_DelayedHandler", 2, event, itemID, success)
	end
end


function LGC:GET_ITEM_INFO_RECEIVED_DelayedHandler(event, itemID, success)
	-- reset marker, so new GET_ITEM_INFO_RECEIVED will fire this up again (with 2 seconds delay)
	LGC.GET_ITEM_INFO_Timer = nil

	local t = time()

	-- ignore items after a time of 10sec
	for id,start in pairs(LGC.GET_ITEM_INFO_RECEIVED_NotYetReady) do
		if t > start+10	then
			LGC:Print(L["Waited 10sec for itemID id to be resolved. Giving up on this item."](id))
			LGC.GET_ITEM_INFO_RECEIVED_NotYetReady[id] = nil
			LGC.GET_ITEM_INFO_RECEIVED_IgnoreIDs[id] = t
		end
	end

	-- this event gets a lot of calls, so debug is very chatty here
	-- only configurable in code therefore
	local debug = false

	for todoid,todo in pairs(LGC.GET_ITEM_INFO_RECEIVED_TodoList) do

		if debug then LGC:Print("GET_ITEM_INFO_RECEIVED for " .. itemID); end
		if debug then LGC:Print("Looking into " .. tprint(todo)); end

		local foundAllIDs = true
		local itemlinks = {}

		-- search for all needed IDs
		for dummy,looking_for_id in pairs(todo["needed_itemids"]) do
			if LGC.GET_ITEM_INFO_RECEIVED_IgnoreIDs[looking_for_id] == nil then

				if tonumber(looking_for_id) > 0 then
					if debug then LGC:Print("Tying to get ID " .. looking_for_id); end
					local itemName, itemLink = GetItemInfo(looking_for_id)
					if itemLink then
						if debug then LGC:Print("Found " .. looking_for_id .. " as " .. itemLink); end
						table.insert(itemlinks, itemLink)
					else
						if debug then LGC:Print("Not yet ready: " .. looking_for_id); end
						if LGC.GET_ITEM_INFO_RECEIVED_NotYetReady[looking_for_id] == nil then LGC.GET_ITEM_INFO_RECEIVED_NotYetReady[looking_for_id] = t end
						foundAllIDs = false
					end
				end -- tonumber

			end -- ignore
		end

		if (foundAllIDs) then
			if debug then LGC:Print("Calling function with itemlinks " .. tprint(itemlinks) .. " and vars " .. tprint(todo["vars"])); end
			todo["todo"](itemlinks,todo["vars"])
			LGC.GET_ITEM_INFO_RECEIVED_TodoList[todoid] = nil -- remove from todo list
		end

	end

end
