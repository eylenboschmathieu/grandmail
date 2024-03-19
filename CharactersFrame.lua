local addon, core = ...
local MasterFrame = core.MasterFrame

core.CharactersFrame = CreateFrame("FRAME", nil, MasterFrame, "Krozu_ScrollFrame")
local CharactersFrame = core.CharactersFrame
local ScrollFrame = CharactersFrame.ScrollFrame
local Scrollchild = CharactersFrame:GetScrollChild()
CharactersFrame.AddCharacterButton = CreateFrame("BUTTON", nil, CharactersFrame, "BackdropTemplate")
local AddCharacterButton = CharactersFrame.AddCharacterButton

local L, ClassList, db = core.L, {}

--[[================

	Constants

==================]]

local buttonWidth, buttonHeight, buttonOffsetX, buttonOffsetY, nButtonsShown = 176, 35, 4, 4, 14
local scrollStep = buttonHeight + buttonOffsetY -- Scrollstep for moving up 1 button
local frameWidth, frameHeight = buttonWidth + (2 * buttonOffsetX) + 16, nButtonsShown * scrollStep + buttonOffsetY
local scrollchildWidth = buttonWidth + 2 * buttonOffsetX

--[[================

	Helper functions

==================]]

core.GetSelectedCharacter = function(flag)
	-- If flag == true, return the character in memory
	if flag then
		return CharactersFrame.SelectedCharacterMemory
	else
		return CharactersFrame.SelectedCharacter
	end
end

core.SetSelectedCharacter = function(arg)
	-- If arg == true, set the character memory to SelectedCharacter, and set SelectedCharacter to false
	-- If arg == (false or table), set SelectedCharacter to arg. False means no character is selected.
	if arg == true then
		CharactersFrame.SelectedCharacterMemory = CharactersFrame.SelectedCharacter
		CharactersFrame.SelectedCharacter = false
	else
		CharactersFrame.SelectedCharacter = arg
	end
end

--[[================

	Widget Pool

==================]]

core.ButtonPool = core.CreateWidgetPool(nil, -- parent, createFunc, acquireFunc, releaseFunc
		function() -- createFunc
			local btn = CreateFrame("BUTTON", nil, nil, "BackdropTemplate")
			
			btn:SetBackdrop(core.defaultBackdrop)
			btn:SetBackdropColor(0, 0, 0, 0)
			btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			
			btn:SetText(" ")
			local fs = btn:GetFontString()
			fs:SetFont(core.fontPath, 12)
			fs:SetJustifyH("LEFT")
			fs:SetTextColor(1, 1, 1, 1)
			fs:SetPoint("LEFT", 6, 0)
			
			local tex = btn:CreateTexture()
			btn.FactionBadge = tex
			tex:SetSize(30, 35)
			tex:SetPoint("RIGHT", -3, 0)
			
			btn.Type = 0
			return btn
		end,
		function(btn, Type, characterClass, characterFaction) -- acquireFunc
			Type = Type or 0
			btn.Type = Type
			
			if Type == 1 then -- Character Buttons
				btn:SetParent(Scrollchild)
				btn:SetSize(buttonWidth, buttonHeight)
				btn:SetBackdropColor(0, 0, 0, 0)
				btn:SetBackdropBorderColor(0, 0, 0, 0)
				
				btn:GetFontString():SetWidth(buttonWidth - 38)
				
				btn.CharacterClass = characterClass
				btn.CharacterFaction = characterFaction
				if characterFaction == "Alliance" then
					btn.FactionBadge:SetAtlas("pvpqueue-sidebar-honorbar-badge-alliance");
				else
					btn.FactionBadge:SetAtlas("pvpqueue-sidebar-honorbar-badge-horde");
				end
				btn.FactionBadge:Show()
				
				btn:SetScript("OnEnter", function(self)
					self:SetBackdropBorderColor(RAID_CLASS_COLORS[btn.CharacterClass]:GetRGBA())
					
					if core.State == "ORDER_OVERVIEW" then
						local del = core.MasterFrame.DeleteButton
						del:ClearAllPoints()
						del:SetPoint("RIGHT", self, "RIGHT", -6, 0)
						del:SetFrameLevel(self:GetFrameLevel() + 1)
						del.AssociatedButton = self
						del:Show()
						self.FactionBadge:Hide()
					end
				end)				
				btn:SetScript("OnLeave", function(self)
					if self ~= CharactersFrame.SelectedCharacter and GetMouseFocus() ~= core.MasterFrame.DeleteButton then
						self:SetBackdropBorderColor(0, 0, 0, 0)
						core.MasterFrame.DeleteButton.AssociatedButton = false
						core.MasterFrame.DeleteButton:Hide()
						self.FactionBadge:Show()
					end
				end)				
				btn:SetScript("OnClick", function(self, mouseButton)
					local state = core.State
					if mouseButton == "LeftButton" and (state == "ORDER_OVERVIEW" or state == "ORDER_EDIT") then
						if CharactersFrame.SelectedCharacter and CharactersFrame.SelectedCharacter ~= self then
							CharactersFrame.SelectedCharacter:SetBackdropBorderColor(0, 0, 0, 0)
							CharactersFrame.SelectedCharacter.FactionBadge:Show()
						end
						if CharactersFrame.SelectedCharacter == self then
							CharactersFrame.SelectedCharacter = false
						else
							CharactersFrame.SelectedCharacter = self
						end
						
						if state == "ORDER_OVERVIEW" then
							core.OrdersFrame:Refresh()
						end
					elseif mouseButton == "RightButton" and state == "ORDER_OVERVIEW" then -- Rename character
						core.State = "CHARACTER_EDIT"
						self:Hide()
						core.MasterFrame.EditBox.AssociatedButton = self
						core.MasterFrame.EditBox:Show()
					end
				end)
			elseif Type == 2 then -- Order Buttons
				btn:SetParent(core.OrdersFrame:GetScrollChild())
				btn:SetHeight(82)
				btn:SetWidth(208)
				btn:SetBackdropColor(.2, .2, .2, .5)
				btn:SetBackdropBorderColor(0, 0, 0, 1)
				
				btn:GetFontString():SetWidth(170)
				btn:GetFontString():SetTextColor(1, 1, 1, 1)
				
				btn:SetScript("OnEnter", function(self)
					self:SetBackdropBorderColor(unpack(core.classColour))
					if core.State == "ORDER_OVERVIEW" or core.State == "ORDER_EDIT" then
						local del = core.MasterFrame.DeleteButton
						del:ClearAllPoints()
						del:SetPoint("RIGHT", self, "RIGHT", -6, 0)
						del:SetFrameLevel(self:GetFrameLevel() + 1)
						del.AssociatedButton = self
						del:Show()
					end
					
				end)
				btn:SetScript("OnLeave", function(self)
					if GetMouseFocus() ~= core.MasterFrame.DeleteButton then
						self:SetBackdropBorderColor(0, 0, 0, 1)
						core.MasterFrame.DeleteButton.AssociatedButton = false
						core.MasterFrame.DeleteButton:Hide()
					end
				end)
				btn:SetScript("OnClick", function(self, mouseButton)
					if core.State == "ORDER_OVERVIEW" then
						core.State = "ORDER_EDIT"
						AddCharacterButton:Hide()
						
						core.OrdersFrame.SelectedOrder = self:GetText()
						core.OrdersFrame.AddOrderButton:SetText(L["ADD_RECIPIENT"])
						
						core.InfoFrame:SetOrder(core.OrdersFrame.SelectedOrder)
						local SelectedCharacter = core.GetSelectedCharacter()
						if SelectedCharacter then
							SelectedCharacter:SetBackdropBorderColor(0, 0, 0, 0)
						end
						core.SetSelectedCharacter(true)
						core.OrdersFrame:Refresh()
					elseif core.State == "ORDER_EDIT" then
						if mouseButton == "LeftButton" then -- Enter the entry
							core.State = "ENTRY_EDIT"
							core.OrdersFrame:SetScrollStep(172)
							core.InfoFrame:SetRecipient(self.Recipient)
							
							core.OrdersFrame.AddOrderButton:Hide()
							core.OrdersFrame.CurrentRecipient = self.Recipient
							core.OrdersFrame.TopLevel.CurrentEntry = self.EntryDB
							
							core.State = "ENTRY_LOAD"
							
							-- Deserialize
							local entry = self.EntryDB[self.Recipient]
							if type(entry) == "table" then
								local pStart, pEnd, fType, fData, par, groupType -- Pattern Start, Pattern End, Group Type, Filter Data, parenthesis
								local frame = core.OrdersFrame.TopLevel
								local serial = select(3, entry.data:find("^%d%((.*)%)$"))
								local iterator, Stack = 1, {
									[1] = frame
								}
								
								while iterator <= #serial do
									pStart, pEnd, par, groupType = serial:find("^(%)?)(%d*)", iterator)
									
									if par == "" then
										groupType = tonumber(groupType)
										if groupType == 4 then -- Filter
											pStart, pEnd, par, groupType = serial:find("^%d+%((%d+):(-?%d+)%)", pStart)
											fType, fData = tonumber(par), tonumber(groupType)
											if fType == 1 then -- Name Filter
												fData = entry[fData]
											end
											core.Entries.CreateFilter(frame, fType, fData) -- parent, filterType, filterData
											iterator = pEnd + 1
										else -- Group
											iterator = pStart + 2
											frame = core.Entries.CreateGroup(groupType, frame)
											Stack[#Stack + 1] = frame
										end
									else
										Stack[#Stack] = nil
										frame = Stack[#Stack]
										iterator = pStart + 1
									end
								end
							end
						else -- Add a gold value to this recipient
							-- GOLD_AMOUNT_TEXTURE
							core.State = "ENTRY_SET_GOLD"
							self:GetFontString():Hide()
							MasterFrame.EditBox.AssociatedButton = self
							MasterFrame.EditBox:Show()
							return
						end
						
						core.State = "ENTRY_EDIT"
						
						core.OrdersFrame.TopLevel:Show()
						core.OrdersFrame:Refresh()
					end
				end)
			elseif Type == 3 then -- SendMail Buttons
				btn:SetParent(core.SendFrame:GetScrollChild())
				btn:SetHeight(56)
				btn:SetWidth(208)
				btn:SetBackdropColor(.2, .2, .2, 1)
				btn:SetBackdropBorderColor(0, 0, 0, 1)
				
				btn:GetFontString():SetWidth(200)
				btn:GetFontString():SetTextColor(1, 1, 1, 1)
				
				btn:SetScript("OnEnter", core.Scripts.OnEnter)
				btn:SetScript("OnLeave", core.Scripts.OnLeave)
				btn:SetScript("OnClick", core.SendOrder)
			end
		end,
		function(btn) -- bType: 1 == Characer, 2 == Order | Recipient, 3 == SendOrder
			btn:SetText("")
			btn:Hide()
			if btn.Type == 1 then
				btn.CharacterClass = nil
				btn.CharacterName = nil
				btn.CharacterFaction = nil
				btn.FactionBadge:Hide()
			elseif btn.Type == 2 then
				btn.OrderName = nil
				btn.Recipient = nil
				btn.EntryDB = nil
			elseif btn.Type == 3 then
				btn.db = nil
			end
		end)

--[[================

	User Interface

==================]]

do -- CharactersFrame (ScrollFrame)
	CharactersFrame:SetBackdropColor(0, 0, 0, .2)
	CharactersFrame:SetSize(frameWidth, frameHeight)
	CharactersFrame:SetPoint("BOTTOMLEFT", 4, 4)
	CharactersFrame:SetScrollStep(scrollStep * 4)
	
	CharactersFrame.SelectedCharacter = false
	CharactersFrame.SelectedCharacterMemory = false
	CharactersFrame.CharacterButtons = {}
	
	function CharactersFrame:Init() -- Load character data (GLOBAL) on player login
		db = core.db
		if db.Characters[core.myRealm] then
			local Characters, btnList = db.Characters[core.myRealm], self.CharacterButtons
			for i,characterData in ipairs(Characters) do
				local btn = core.ButtonPool:Acquire(1, characterData.Class, characterData.Faction)
				btn.CharacterName = characterData.Name
				btn.CharacterClass = characterData.Class
				btn.CharacterFaction = characterData.Faction
				
				btnList[#btnList + 1] = btn
			end
			
			self:Refresh()
		end
	end
	
	function CharactersFrame:Hide()
		for _,btn in ipairs(self.CharacterButtons) do
			btn:Hide()
		end
	end
	
	function CharactersFrame:Refresh()
		local btnList = self.CharacterButtons
		for i,btn in ipairs(btnList) do
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", buttonOffsetX, -buttonOffsetY - scrollStep * (i - 1))
			btn:SetText(btn.CharacterName)
			btn:GetFontString():SetTextColor(RAID_CLASS_COLORS[btn.CharacterClass]:GetRGBA())
			btn:Show()
		end
		Scrollchild:SetSize(scrollchildWidth, #btnList * scrollStep + buttonOffsetY)
	end
end

do -- AddCharacterButton
	AddCharacterButton:SetSize(scrollchildWidth, 22)
	AddCharacterButton:SetPoint("BOTTOMLEFT", CharactersFrame, "TOPLEFT", 0, 4)
	AddCharacterButton:SetBackdrop(core.defaultBackdrop)
	AddCharacterButton:SetBackdropColor(.4, .4, .4, .2)
	AddCharacterButton:SetBackdropBorderColor(0, 0, 0, 1)
	
	AddCharacterButton:SetText(L["ADD_CHARACTER"])
	local fs = AddCharacterButton:GetFontString()
	fs:SetFont(core.fontPath, 16)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("LEFT", 32, 0)
	
	local tex = AddCharacterButton:CreateTexture()
	AddCharacterButton.texture = tex;
	tex:SetTexture([[Interface\FriendsFrame\Battlenet-Battleneticon]])
	tex:SetSize(20, 20)
	tex:SetTexCoord(.16, .84, .16, .84)
	tex:SetPoint("LEFT", 1, 0)
	
	AddCharacterButton:SetScript("OnEnter", core.Scripts.OnEnter)
	AddCharacterButton:SetScript("OnLeave", core.Scripts.OnLeave)
	AddCharacterButton:SetScript("OnClick", function(self)
		if core.State == "ORDER_OVERVIEW" then
			core.State = "CHARACTER_CREATION"
			CharactersFrame:Hide() -- Overriden the base Hide
			MasterFrame.DeleteButton:Hide()
			
			for i=1,#ClassList do
				ClassList[i]:Show()
			end
		end
	end)
	
end

do -- Class and Faction select
	local OnClick_Class = function(self)
		for i=1,#ClassList do
			ClassList[i]:Hide()
		end
		
		CharactersFrame.AllianceButton.Class = self.Class
		CharactersFrame.HordeButton.Class = self.Class
		
		CharactersFrame.AllianceButton:Show()
		CharactersFrame.HordeButton:Show()
	end
	
	local OnClick_Faction = function(self)
		local btn = core.ButtonPool:Acquire(1, self.Class, self.Faction)
		core.SetSelectedCharacter(btn)
		
		CharactersFrame.AllianceButton:Hide()
		CharactersFrame.HordeButton:Hide()
		
		MasterFrame.EditBox.AssociatedButton = btn
		MasterFrame.EditBox:Show()
	end
	
	local OnHide_Faction = function(self)
		self.Class = nil
	end
	
	local OnLeave_Faction = function(self)
		self:SetBackdropBorderColor(0, 0, 0, 0)
	end
	
	for i=1,MAX_CLASSES do
		local btn = CreateFrame("BUTTON", nil, CharactersFrame, "BackdropTemplate")
		btn.Class = CLASS_SORT_ORDER[i]
		btn:Hide()
		btn:SetSize(166, 32)
		btn:SetPoint("TOP", i > 1 and ClassList[i - 1] or CharactersFrame, i > 1 and "BOTTOM" or "TOP", 0, -4)
		btn:SetBackdrop(core.defaultBackdrop)
		btn:SetBackdropColor(0, 0, 0, 0)
		btn:SetBackdropBorderColor(0, 0, 0, 0)
		btn:SetText(CLASS_SORT_ORDER[i])
		local fs = btn:GetFontString()
		fs:SetFont(core.fontPath, 16)
		fs:SetJustifyH("LEFT")
		fs:SetTextColor(RAID_CLASS_COLORS[btn.Class]:GetRGBA())
		fs:SetPoint("LEFT", 4, 0)
		btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(RAID_CLASS_COLORS[self.Class]:GetRGBA()) end)
		btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 0) end)
		btn:SetScript("OnClick", OnClick_Class)
		
		ClassList[i] = btn
	end
	
	local btn = CreateFrame("BUTTON", nil, CharactersFrame, "BackdropTemplate")
	CharactersFrame.AllianceButton = btn
	btn:Hide()
	btn:SetSize(118,138)
	btn:SetPoint("TOP", 0, -32)
	btn:SetBackdrop(core.defaultBackdrop)
	btn:SetBackdropColor(0, 0, 0, 0)
	btn:SetBackdropBorderColor(0, 0, 0, 0)
	
	btn.Faction = "Alliance"
	
	btn:SetScript("OnEnter", core.Scripts.OnEnter)
	btn:SetScript("OnLeave", OnLeave_Faction)
	btn:SetScript("OnClick", OnClick_Faction)
	btn:SetScript("OnHide", OnHide_Faction)
	
	btn.tex = btn:CreateTexture()
	btn.tex:SetSize(118, 138)
	btn.tex:SetPoint("CENTER")
	btn.tex:SetAtlas("pvpqueue-sidebar-honorbar-badge-alliance")
	
	btn = CreateFrame("BUTTON", nil, CharactersFrame, "BackdropTemplate")
	CharactersFrame.HordeButton = btn
	btn:Hide()
	btn:SetSize(118,138)
	btn:SetPoint("TOP", CharactersFrame.AllianceButton, "BOTTOM", 0, -32)
	btn:SetBackdrop(core.defaultBackdrop)
	btn:SetBackdropColor(0, 0, 0, 0)
	btn:SetBackdropBorderColor(0, 0, 0, 0)
	
	btn.Faction = "Horde"
	
	btn:SetScript("OnEnter", core.Scripts.OnEnter)
	btn:SetScript("OnLeave", OnLeave_Faction)
	btn:SetScript("OnClick", OnClick_Faction)
	btn:SetScript("OnHide", OnHide_Faction)
	
	btn.tex = btn:CreateTexture()
	btn.tex:SetSize(118, 138)
	btn.tex:SetPoint("CENTER")
	btn.tex:SetAtlas("pvpqueue-sidebar-honorbar-badge-horde")
end
