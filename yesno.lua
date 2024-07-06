local L = LibStub("AceLocale-3.0"):GetLocale("LootGuardClassic", true)

function LGC:createTwoDialogFrame(title, text, onetxt, one, twotxt, two)
	local AceGUI = LibStub("AceGUI-3.0")

	local f = AceGUI:Create("Window")
	f:SetTitle(title)
	f:SetStatusText("")
	f:SetLayout("Flow")
	f:SetWidth(400)
	f:SetHeight(100)
	f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)

	-- close on escape
	_G["Prio3LGC.twodialogframe"] = f.frame
	tinsert(UISpecialFrames, "Prio3LGC.twodialogframe")

	local txt = AceGUI:Create("Label")
	txt:SetText(text)
	txt:SetRelativeWidth(1)
	f:AddChild(txt)

	local button1 = AceGUI:Create("Button")
	button1:SetText(onetxt)
	button1:SetRelativeWidth(0.5)
	button1:SetCallback("OnClick", function()
		one()
	end)
	f:AddChild(button1)

	local button2 = AceGUI:Create("Button")
	button2:SetText(twotxt)
	button2:SetRelativeWidth(0.5)
	button2:SetCallback("OnClick", function()
		two()
	end)
	f:AddChild(button2)

	return f
end


function LGC:createThreeDialogFrame(title, text, onetxt, one, twotxt, two, threetxt, three)
	local AceGUI = LibStub("AceGUI-3.0")

	local f = AceGUI:Create("Window")
	f:SetTitle(title)
	f:SetStatusText("")
	f:SetLayout("Flow")
	f:SetWidth(400)
	f:SetHeight(150)
	f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)

	-- close on escape
	_G["Prio3LGC.threedialogframe"] = f.frame
	tinsert(UISpecialFrames, "Prio3LGC.threedialogframe")

	local txt = AceGUI:Create("Label")
	txt:SetText(text)
	txt:SetRelativeWidth(1)
	f:AddChild(txt)

	local button1 = AceGUI:Create("Button")
	button1:SetText(onetxt)
	button1:SetRelativeWidth(0.33)
	button1:SetCallback("OnClick", function()
		one()
	end)
	f:AddChild(button1)

	local button2 = AceGUI:Create("Button")
	button2:SetText(twotxt)
	button2:SetRelativeWidth(0.33)
	button2:SetCallback("OnClick", function()
		two()
	end)
	f:AddChild(button2)

	local button3 = AceGUI:Create("Button")
	button3:SetText(threetxt)
	button3:SetRelativeWidth(0.33)
	button3:SetCallback("OnClick", function()
		three()
	end)
	f:AddChild(button3)


	return f
end


function LGC:askToDisable(question)
	LGC.askframe = nil

	local yes = function()
		LGC.askframe:Hide()
		LGC.db.profile.enabled = false
		LGC:Print(L["Prio3 addon is currently disabled."])
	end

	local clear = function()
		LGC.askframe:Hide()
		LGC.db.profile.priorities = {}
		LGC:Print(L["No priorities defined."])
	end

	local no = function()
		LGC.askframe:Hide()
		-- do nothing
	end

	LGC.askframe = LGC:createThreeDialogFrame("Disable Addon?", question, L["Disable"], yes, L["Clear priorities"], clear, L["Keep on"], no)
	LGC.askframe:Show()
end



function LGC:askToAcceptIncomingPriorities(sender, newPriorities, newReceived)
	LGC.askIncomingPrioframe = nil

	LGC.askIncomingPrioYesValues = { sender = sender, newPriorities = newPriorities, newReceived = newReceived }
	local yes = function()
		LGC.askIncomingPrioframe:Hide()
		LGC.db.profile.priorities = LGC.askIncomingPrioYesValues["newPriorities"]
		LGC.db.profile.receivedPriorities = LGC.askIncomingPrioYesValues["newReceived"]
		LGC:Print(L["Accepted new priorities sent from sender"](LGC.askIncomingPrioYesValues["sender"]))
		local commmsg = { command = "RECEIVED_PRIORITIES", answer = "accepted", addon = LGC.addon_id, version = LGC.versionString }
		LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")
	end

	local no = function()
		LGC.askIncomingPrioframe:Hide()
		-- send my own priorities to superseed the rogue sender
		local commmsg = { command = "RECEIVED_PRIORITIES", answer = "rejected as Master Looter", addon = LGC.addon_id, version = LGC.versionString }
		LGC:SendCommMessage(LGC.commPrefix, LGC:Serialize(commmsg), "RAID", nil, "NORMAL")

		LGC:sendPriorities()
	end
	LGC.askIncomingPrioframe = LGC:createTwoDialogFrame(L["Received Priorities"], L["Received new priorities sent from sender, but I am Master Looter"](sender), L["Accept incoming"], yes, L["Reject and keep mine"], no)
	LGC.askIncomingPrioframe:Show()

end