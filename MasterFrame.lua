local addon, core = ...
local ShowTooltipItemInfo = false
local L, db = core.L

local MasterFrame = CreateFrame("FRAME", "GrandMailMasterFrame", UIParent, "BackdropTemplate")
core.MasterFrame = MasterFrame
MasterFrame.Title = MasterFrame:CreateFontString()
MasterFrame.CloseButton = CreateFrame("BUTTON", nil, MasterFrame, "BackdropTemplate")
MasterFrame.EditBox = CreateFrame("EDITBOX", nil, MasterFrame, "BackdropTemplate")
MasterFrame.DeleteButton = CreateFrame("BUTTON", nil, MasterFrame, "BackdropTemplate")
MasterFrame.ToggleTooltipButton = CreateFrame("BUTTON", nil, MasterFrame, "BackdropTemplate")

local MINIMUM_CHARACTER_NAME_LENGTH = 2

--[[================

	User Interface

==================]]

do -- MasterFrame
	-- MasterFrame:Hide()
	table.insert(UISpecialFrames, "GrandMailMasterFrame") -- Enables the escape key to close the frame
	MasterFrame:SetSize(868, 616)
	MasterFrame:SetToplevel(true)
	MasterFrame:SetPoint("CENTER")
	MasterFrame:SetBackdrop(core.defaultBackdrop)
	MasterFrame:SetBackdropColor(.1, .1, .1, .9)
	MasterFrame:SetBackdropBorderColor(0, 0, 0, 1)

	MasterFrame:SetMovable(true)
	MasterFrame:EnableMouse(true)
	MasterFrame:RegisterForDrag("LeftButton")
	MasterFrame:SetScript("OnDragStart", MasterFrame.StartMoving)
	MasterFrame:SetScript("OnDragStop", MasterFrame.StopMovingOrSizing)

	function MasterFrame:Init()
		db = core.db
		core.State = "ORDER_OVERVIEW"
	end
end

do -- Title
	MasterFrame.Title:SetSize(128, 32)
	MasterFrame.Title:SetPoint("TOP", MasterFrame, "TOP", 0, -4)
	
	MasterFrame.Title:SetTextColor(1, 1, 1, 1)
	MasterFrame.Title:SetFont(core.fontPath, 16, "")
	MasterFrame.Title:SetText(addon)
end

do -- Close Button
	MasterFrame.CloseButton:SetSize(24, 24)
	MasterFrame.CloseButton:SetPoint("TOPRIGHT", MasterFrame, "TOPRIGHT", -4, -4)
	MasterFrame.CloseButton:SetBackdrop(core.defaultBackdrop)
	MasterFrame.CloseButton:SetBackdropBorderColor(0, 0, 0, 1)
	MasterFrame.CloseButton:SetBackdropColor(0, 0, 0, 0)
	
	MasterFrame.CloseButton:SetScript("OnEnter", core.Scripts.OnEnter)
	MasterFrame.CloseButton:SetScript("OnLeave", core.Scripts.OnLeave)
	MasterFrame.CloseButton:SetScript("OnClick", function() MasterFrame:Hide() end)
	
	local tex = MasterFrame.CloseButton:CreateTexture()
	tex:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
	tex:SetSize(22, 22)
	tex:SetPoint("CENTER")
end

do -- EditBox
	MasterFrame.EditBox:SetBackdrop(core.defaultBackdrop)
	MasterFrame.EditBox:SetTextInsets(4, 4, 0, 0)
	MasterFrame.EditBox:SetBackdropColor(1, 1, 1, .2)
	MasterFrame.EditBox:SetAutoFocus(false)
	MasterFrame.EditBox:SetNumeric(false)
	MasterFrame.EditBox:SetFont(core.fontPath, 12, "")
	MasterFrame.EditBox:Hide()
	
	MasterFrame.EditBox.AssociatedButton = false
	
	MasterFrame.EditBox:SetScript("OnEscapePressed",  core.Scripts.OnEscapePressed)
	MasterFrame.EditBox:SetScript("OnEditFocusGained", EditBox_HighlightText)
	MasterFrame.EditBox:SetScript("OnShow", function(self) -- Recipient and EntryDB are required when setting a gold value
		self:ClearAllPoints()
		self:SetText("")
		if core.State == "CHARACTER_CREATION" then
			self:SetPoint("TOPLEFT", core.CharactersFrame, "TOPLEFT", 4, -4)
			self:SetFrameLevel(core.CharactersFrame:GetFrameLevel() + 1)
			self:SetSize(176, 35)
		elseif core.State == "CHARACTER_EDIT" then
			self:SetPoint("LEFT", self.AssociatedButton, "LEFT", 0, 0)
			self:SetFrameLevel(self.AssociatedButton:GetFrameLevel() + 1)
			self:SetSize(176, 35)
		elseif core.State == "ORDER_CREATION" or core.State == "ENTRY_SET_GOLD" then
			self:SetPoint("LEFT", self.AssociatedButton, "LEFT", 0, 0)
			self:SetFrameLevel(self.AssociatedButton:GetFrameLevel() + 1)
			self:SetSize(208, 82)
			if core.State == "ENTRY_SET_GOLD" then
				self:SetText("Set Gold amount")
			end
		end
		
		self:SetFocus()
	end)
	MasterFrame.EditBox:SetScript("OnHide", function(self)
		self:SetText("")
		self:ClearFocus()
		self.AssociatedButton = false
		self.EntryDB = nil
		self.Recipient = nil
	end)
	MasterFrame.EditBox:SetScript("OnEnterPressed", function(self)
		if core.State == "CHARACTER_CREATION" then
			local name = self:GetText():gsub("%s+", "")
			if #name < MINIMUM_CHARACTER_NAME_LENGTH or name == L["GLOBAL"] then
				return
			end
			
			local SelectedCharacter = self.AssociatedButton
			SelectedCharacter.CharacterName = name
			db.Characters[core.myRealm] = db.Characters[core.myRealm] or {}
			
			for _,v in ipairs(db.Characters[core.myRealm]) do -- Check for duplicates
				if v.Name == SelectedCharacter.CharacterName then
					print(L["DUPLICATE_CHARACTER"])
					UIErrorsFrame:AddExternalErrorMessage(L["DUPLICATE_CHARACTER"])
					core.Scripts.OnEscapePressed(self)
					return
				end
			end
			
			core.CharactersFrame.CharacterButtons[#core.CharactersFrame.CharacterButtons + 1] = SelectedCharacter
			table.insert(db.Characters[core.myRealm], {Name = name, Class = SelectedCharacter.CharacterClass, Faction = SelectedCharacter.CharacterFaction})
			
			SelectedCharacter:SetText(name)
			SelectedCharacter:GetFontString():SetTextColor(RAID_CLASS_COLORS[SelectedCharacter.CharacterClass]:GetRGBA())
			
			core.SetSelectedCharacter(false)
			
			core.CharactersFrame:Refresh()
		elseif core.State == "CHARACTER_EDIT" then
			local newName = self:GetText():gsub("%s+", "")
			local SelectedCharacter = self.AssociatedButton
			local oldName = SelectedCharacter.CharacterName
			if newName == "" or newName == oldName or #newName < MINIMUM_CHARACTER_NAME_LENGTH or newName == L["GLOBAL"] then
				core.Scripts.OnEscapePressed(self)
				return
			end
			local isDuplicate, index = false, 0
			
			for i,v in ipairs(db.Characters[core.myRealm]) do -- Check for duplicate names on this server
				if v.Name == newName then
					isDuplicate = true
				elseif v.Name == oldName then
					index = i
				end
			end
			
			if isDuplicate then
				UIErrorsFrame:AddExternalErrorMessage(L["DUPLICATE_CHARACTER"])
				core.Scripts.OnEscapePressed(self)
				return
			else
				-- print(string.format("Modified %s to %s", oldName, newName)) -- DEBUG
				db.Characters[core.myRealm][index].Name = newName
			end
			
			SelectedCharacter.CharacterName = newName
			
			-- Update the name in ALL the orders on this server
			local realmOrders = db.Orders[core.myRealm]
			if realmOrders then
				for characterName,characterData in pairs(realmOrders) do
					for orderIndex,orderName in ipairs(characterData) do
						local orderData = characterData[orderName]
						for recipIndex,recipName in ipairs(orderData) do
							if recipName == oldName then
								orderData[recipIndex] = newName
								orderData[newName] = orderData[oldName]
								orderData[oldName] = nil
								-- print(string.format("GrandMail: Updated %s.%s.%s", characterName, orderName, recipName))
								break
							end
						end
					end
				end
				if realmOrders[oldName] then
					realmOrders[newName] = realmOrders[oldName]
					realmOrders[oldName] = nil
				end
			end
			
			SelectedCharacter:SetText(newName)
			SelectedCharacter:Show()
		elseif core.State == "ORDER_CREATION" then
			local SelectedOrder = self.AssociatedButton
			local SelectedCharacter = core.GetSelectedCharacter()
			SelectedOrder.OrderName = self:GetText():match("^%s*(.-)%s*$")
			if SelectedOrder.OrderName == "" then UIErrorsFrame:AddExternalErrorMessage(L["ORDER_REQUIRES_NAME"]) return end
			
			local Orders = db.Orders[core.myRealm][SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]]
			
			if Orders[SelectedOrder.OrderName] then
				UIErrorsFrame:AddExternalErrorMessage(L["DUPLICATE_ORDER"])
				core.Scripts.OnEscapePressed(self)
				return
			end
			Orders[#Orders + 1] = SelectedOrder.OrderName
			Orders[SelectedOrder.OrderName] = {} -- 1 == Sequential order of entries, 2 == Table of entries
			
			SelectedOrder:SetText(SelectedOrder.OrderName)
		elseif core.State == "ENTRY_SET_GOLD" then
			local SelectedRecipient = self.AssociatedButton
			
			local gold = tonumber(self:GetText()) or 0
			if gold < -1000000000 or gold > 1000000000 then -- Gold cap(?)
				UIErrorsFrame:AddExternalErrorMessage(L["BELOW_GOLD_MINIMUM"])
				core.Scripts.OnEscapePressed(self)
				SelectedRecipient:GetFontString():Show()
				core.State = "ORDER_EDIT"
				return
			end
			
			if gold == 0 then
				SelectedRecipient.Gold = nil
				SelectedRecipient:GetFontString():SetText(SelectedRecipient.Recipient)
				SelectedRecipient.EntryDB[SelectedRecipient.Recipient].Gold = nil
			else
				SelectedRecipient.Gold = gold
				SelectedRecipient:GetFontString():SetText(string.format("%s\n\n"..GOLD_AMOUNT_TEXTURE, SelectedRecipient.Recipient, gold))
				SelectedRecipient.EntryDB[SelectedRecipient.Recipient].Gold = gold
			end
			SelectedRecipient:GetFontString():Show()
			
			core.State = "ORDER_EDIT"
			self.AssociatedButton = false
			self:Hide()
			return
		end
		
		core.State = "ORDER_OVERVIEW"
		self.AssociatedButton = false
		self:Hide()
	end)
end

do -- Delete Button
	MasterFrame.DeleteButton:SetSize(24, 24)
	MasterFrame.DeleteButton:SetBackdrop(core.defaultBackdrop)
	MasterFrame.DeleteButton:SetBackdropColor(0, 0, 0, 0)
	MasterFrame.DeleteButton:SetBackdropBorderColor(0, 0, 0, 0)
	
	MasterFrame.DeleteButton.AssociatedButton = false
	
	MasterFrame.DeleteButton:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(core.classColour))
		if self.FactionBadge then
			self.FactionBadge:Hide()
		end
	end)
	MasterFrame.DeleteButton:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0, 0, 0, 0)
		if GetMouseFocus() ~= self.AssociatedButton then
			MasterFrame.DeleteButton:Hide()
			if core.GetSelectedCharacter() ~= self.AssociatedButton then
				self.AssociatedButton:SetBackdropBorderColor(0, 0, 0, 0)
			end
			if self.AssociatedButton.FactionBadge then 
				self.AssociatedButton.FactionBadge:Show()
			end
		end
	end)
	MasterFrame.DeleteButton:SetScript("OnClick", function(self)
		local dialog
		if core.State == "ORDER_OVERVIEW" then
			if self.AssociatedButton.CharacterName then -- Delete Character
				core.State = "POPUP_DELETE_CHARACTER"
				dialog = StaticPopup_Show("GRANDMAIL_DELETE_CHARACTER")
			elseif self.AssociatedButton.OrderName then -- Delete Order
				core.State = "POPUP_DELETE_ORDER"
				dialog = StaticPopup_Show("GRANDMAIL_DELETE_ORDER")
			end
		elseif core.State == "ORDER_EDIT" then -- Delete recipient
			core.State = "POPUP_DELETE_RECIPIENT"
			dialog = StaticPopup_Show("GRANDMAIL_DELETE_RECIPIENT")
		end
		
		if dialog then
			dialog.data = self
			dialog.data2 = self.AssociatedButton
		end
	end)
	
	local tex = MasterFrame.DeleteButton:CreateTexture()
	tex:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
	tex:SetSize(18, 18)
	tex:SetPoint("CENTER")
end

do -- ToggleTooltipItemInfo
	MasterFrame.ToggleTooltipButton:SetSize(24, 24)
	MasterFrame.ToggleTooltipButton:SetPoint("RIGHT", MasterFrame.CloseButton, "LEFT", -4, 0)
	MasterFrame.ToggleTooltipButton:SetBackdrop(core.defaultBackdrop)
	MasterFrame.ToggleTooltipButton:SetBackdropBorderColor(0, 0, 0, 1)
	
	MasterFrame.ToggleTooltipButton.TooltipText = L["TOGGLE_TOOLTIP_INFO"]
	
	MasterFrame.ToggleTooltipButton:SetScript("OnEnter", core.Scripts.OnEnter)
	MasterFrame.ToggleTooltipButton:SetScript("OnLeave", core.Scripts.OnLeave)
	MasterFrame.ToggleTooltipButton:SetScript("OnClick", function(self)
		ShowTooltipItemInfo = not ShowTooltipItemInfo
		if ShowTooltipItemInfo then
			ActionButton_ShowOverlayGlow(self)
		else
			ActionButton_HideOverlayGlow(self)
		end
	end)
	
	local tex = MasterFrame.ToggleTooltipButton:CreateTexture()
	tex:SetTexture([[Interface\Icons\Trade_Engineering]])
	tex:SetTexCoord(.1, .9, .1, .9)
	tex:SetSize(22, 22)
	tex:SetPoint("CENTER")
end

local TooltipInfo_Transmog = function(link, itemID)
	local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(link or 0)
	local collected = nil
	-- /run print("appearanceID, sourceID")print(C_TransmogCollection.GetItemInfo("link"))
	-- /run print("SourceIds") local t=C_TransmogCollection.GetAllAppearanceSources(70292)for i,v in ipairs(t) do print(i,v) end
	-- /run local t=C_TransmogCollection.GetSourceInfo(168732) print("isCollected", t and t.isCollected or false)
	-- /run local t=C_TransmogCollection.GetAppearanceSources(180977) print(t and t.itemID or 0)
	-- /run print("Appearance collected")local t=C_TransmogCollection.GetAppearanceInfoBySource(sourceID)print(t and t.appearanceIsCollected or "nil")
	-- /run local t=C_TransmogCollection.GetSourceItemID(168729) print(t)
	
	-- /run local a,s=C_TransmogCollection.GetItemInfo("link") if s then local t=C_TransmogCollection.GetAppearanceInfoBySource(s)print(t and t.appearanceIsCollected or "nil") else print("s=nil") end
	
	if appearanceID and sourceID then
		-- print(string.format("%s aID: %d, sID: %d, collected: %s", link, appearanceID, sourceID), collected or "nil")
		
		GameTooltip:AddDoubleLine("Transmog known_1", tostring(select(5, C_TransmogCollection.GetAppearanceSourceInfo(sourceID))))
		GameTooltip:AddDoubleLine("Transmog known_2", tostring(C_TransmogCollection.PlayerKnowsSource(sourceID)))
		
		local temp = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
		GameTooltip:AddDoubleLine("Transmog known_3", temp and tostring(temp.appearanceIsCollected) or "nil")
	
		local sourceIDs = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
		local t = {}
		
		for i,sourceID in ipairs(sourceIDs) do
			t[sourceID] = C_TransmogCollection.GetSourceInfo(sourceID)
		end
		
		local isCollected = false
		for sourceID, info in pairs(t) do
			if info.isCollected then
				isCollected = true
				break
			end
		end
		collected = isCollected
	else
		local invType = select(4, GetItemInfoInstant(itemID))
		if invType == "INVTYPE_TRINKET" or invType == "INVTYPE_FINGER" or invType == "INVTYPE_NECK" then
			collected = true
		else
			collected = false
		end
	end
	
	GameTooltip:AddDoubleLine("Transmog known_4", tostring(collected))
	GameTooltip:AddDoubleLine("Transmog known_5", tostring(C_TransmogCollection.PlayerHasTransmog(itemID)))
	GameTooltip:AddDoubleLine("Transmog known_6", tostring(C_TransmogCollection.PlayerHasTransmog(itemID, sourceID)))
	GameTooltip:AddDoubleLine("Transmog known_7", tostring(C_TransmogCollection.PlayerHasTransmogByItemInfo(itemID)))
end

local function AddTooltipItemInfo(itemLink, isItemRefTooltip, b, s)
	if ShowTooltipItemInfo and itemLink then
		local itemID = GetItemInfoInstant(itemLink)
		if itemID then
			local GameTooltip = isItemRefTooltip and ItemRefTooltip or GameTooltip
			local ii = {GetItemInfo(itemID)}
			GameTooltip:AddLine("\n")
			if b and s then
				GameTooltip:AddDoubleLine(BANK_BAG, string.format("%d/%s", b ,s))
			end
			GameTooltip:AddDoubleLine(L["ITEM_ID"], itemID)
			if ii[3] then GameTooltip:AddDoubleLine(RARITY, core.Filters[4].StringTable[ii[3]]) end
			if ii[4] then GameTooltip:AddDoubleLine(STAT_AVERAGE_ITEM_LEVEL, GetDetailedItemLevelInfo(itemLink)) end
			if ii[6] and ii[7] then
				local c,sc
				if core.CorrectionList[itemID] then
					local cl = core.CorrectionList[itemID]
					c = GetItemClassInfo(cl[1])
					sc = GetItemSubClassInfo(cl[1], cl[2])
				else
					c = ii[6]
					sc = ii[7]
				end
				GameTooltip:AddDoubleLine(L["ITEM_TYPE_TOOLTIP"], c)
				GameTooltip:AddDoubleLine(L["ITEM_SUB_TYPE"], sc)
			end
			if ii[8] then GameTooltip:AddDoubleLine(L["MAX_STACK_COUNT"], ii[8]) end
			if ii[9] ~= "" then GameTooltip:AddDoubleLine(L["EQUIP_LOCATION"], _G[ii[9]]) end
			if ii[15] then GameTooltip:AddDoubleLine(EXPANSION_FILTER_TEXT, core.Filters[3].StringTable[ii[15]]) end
			
			GameTooltip:Show()
		end
	end
end
hooksecurefunc(GameTooltip, "SetBagItem", function(_, b, s) -- Currently not working in retail
	local t = C_Container.GetContainerItemInfo(b, s)
	if t then
		AddTooltipItemInfo(t.hyperlink, nil, b, s)
	end
end)
hooksecurefunc(GameTooltip, "SetMerchantItem", function(_, slot)
	AddTooltipItemInfo(GetMerchantItemLink(slot))
end)
hooksecurefunc(GameTooltip, "SetRecipeReagentItem", function(_, recipeID, slotIndex) -- Reagents with no quality
	AddTooltipItemInfo(C_TradeSkillUI.GetRecipeFixedReagentItemLink(recipeID, slotIndex))
end)
-- hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(self, recipeID) -- Currently not working in retail
	-- AddTooltipItemInfo(C_TradeSkillUI.GetRecipeItemLink(recipeID))
-- end)
-- ItemRefSetHyperlink
hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(_, link)
	AddTooltipItemInfo(link, true)
end)
--hooksecurefunc(Professions, "SetupQualityReagentTooltip", function(slot) -- Reagents with quality
--	AddTooltipItemInfo(slot.Button:GetItemLink())
--end)
--hooksecurefunc(Professions, "AddCommonOptionalTooltipInfo", function(item) -- Titan Matrices, Stat Missives, etc
--	AddTooltipItemInfo(item:GetItemLink())
--end)

--hooksecurefunc(C_TradeSkillUI, "SetTooltipRecipeReagentItem", function(_, recipeID, reagentIndex)
--	AddTooltipItemInfo(C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex))
--end)
