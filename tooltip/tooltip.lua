local WHITE_TEXT = "|cffffffff%s|r"
local TooltipCache = {}

GameTooltip:HookScript("OnHide", function(self)
end)

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    if self:IsForbidden() then return end

    if not LGC then return end
    if not LGC.db then return end
    if not LGC.db.profile then return end

    if not LGC.db.profile.enabled then return end
    if not LGC.db.profile.showitemtooltip then return end

    local _, item = self:GetItem()

    if not item then return end

    if not TooltipCache[item] then
        TooltipCache[item] = tonumber(strmatch(item, "item:(%d+)"))
    end

    item = TooltipCache[item]

    if item then
        if (LGC.db.profile.debug) then
            self:AddDoubleLine("Item ID (Prio3 Debug)", format(WHITE_TEXT, item))

            -- Count priorities
            local prioCount = 0
            if LGC.db.profile.priorities then
                for user, prios in pairs(LGC.db.profile.priorities) do
                    prioCount = prioCount + 1
                end
            end
            self:AddDoubleLine("Total Users", format(WHITE_TEXT, prioCount))
        end

        local cancatenedUserPrios = {}

        if LGC.db.profile.priorities then
            for user, prios in pairs(LGC.db.profile.priorities) do
                for index = 1, 3 do
                    local prio = prios[index]

                    if prio and (tonumber(prio) == tonumber(item)) then
                        if (cancatenedUserPrios[index] == nil or cancatenedUserPrios[index] == "") then
                            cancatenedUserPrios[index] = "";
                        else
                            cancatenedUserPrios[index] = cancatenedUserPrios[index] .. ", ";
                        end
                        cancatenedUserPrios[index] = cancatenedUserPrios[index] .. user
                    end
                end
            end
        end

        for index = 1, 3 do
            if cancatenedUserPrios[index] and (string.len(cancatenedUserPrios[index]) > 0) then
                self:AddDoubleLine("Prio " .. index, format(WHITE_TEXT, cancatenedUserPrios[index]))
            end
        end
    end
end)
