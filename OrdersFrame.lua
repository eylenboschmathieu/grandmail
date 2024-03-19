local addon, core = ...
local MasterFrame = core.MasterFrame

core.OrdersFrame = CreateFrame("FRAME", nil, MasterFrame, "Krozu_ScrollFrame")
local OrdersFrame = core.OrdersFrame
local ScrollFrame = OrdersFrame.ScrollFrame
OrdersFrame.AddOrderButton = CreateFrame("BUTTON", nil, OrdersFrame, "BackdropTemplate")
local AddOrderButton = OrdersFrame.AddOrderButton

OrdersFrame.BackButton = CreateFrame("BUTTON", nil, OrdersFrame, "BackdropTemplate")
local BackButton = OrdersFrame.BackButton

local L, db = core.L

--[[================

	Constants

==================]]

-- If these values get updated, also update them in CharactersFrame.ButtonPool, button type 2
local buttonWidth, buttonHeight, buttonOffsetX, buttonOffsetY, nButtonsShown, nButtonsPerRow = 208, 82, 4, 6, 15, 3
local round = (nButtonsPerRow - 1) / nButtonsPerRow
local scrollStep = buttonHeight + buttonOffsetY -- Scrollstep for moving up 1 row of buttons
local frameWidth, frameHeight = nButtonsPerRow * (buttonWidth + buttonOffsetX) + buttonOffsetX + 16, math.floor(nButtonsShown / nButtonsPerRow + round) * scrollStep + buttonOffsetY
local scrollchildWidth = nButtonsPerRow * (buttonWidth + buttonOffsetX) + buttonOffsetX

--[[================

	User Interface

==================]]

do -- OrdersFrame
	OrdersFrame:SetBackdropColor(0, 0, 0, .2)
	OrdersFrame:SetSize(frameWidth, frameHeight)
	OrdersFrame:SetPoint("TOPLEFT", core.CharactersFrame, "TOPRIGHT", 4, 0)
	OrdersFrame:SetScrollStep(scrollStep * 2)
	
	OrdersFrame.SelectedOrder = false
	OrdersFrame.CurrentRecipient = false
	OrdersFrame.OrderButtons = {}
	
	function OrdersFrame:Init()
		db = core.db or {}
		self:Refresh()
	end
	
	function OrdersFrame:Clear()
		local btnList = self.OrderButtons
		for i,btn in ipairs(btnList) do
			core.ButtonPool:Release(btn)
		end
		wipe(btnList)
	end
	
	function OrdersFrame:Refresh() -- Returns the newest order button
		local Orders = db.Orders[core.myRealm]
		self:Clear()
		
		if not Orders then -- if Orders == nil, no orders are created for this realm/faction
			return
		end
		
		local btnList = self.OrderButtons
		if core.State == "ORDER_OVERVIEW" or core.State == "ORDER_CREATION" then
			local SelectedCharacter = core.GetSelectedCharacter()
			
			core.InfoFrame:SetCharacter(SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"])
			Orders = Orders[SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]]
			
			if not Orders then
				OrdersFrame:GetScrollChild():Hide()
				return
			else
				OrdersFrame:GetScrollChild():Show()
			end
			
			for _,orderName in ipairs(Orders) do
				local b = core.ButtonPool:Acquire(2)
				b:SetText(orderName)
				b.OrderName = orderName
				btnList[#btnList + 1] = b
			end
			
			if core.State == "ORDER_CREATION" then
				btnList[#btnList + 1] = core.ButtonPool:Acquire(2)
			end
		elseif core.State == "ORDER_EDIT" or core.State == "ENTRY_CREATION" then
			self.BackButton:Show()
			
			self.AddOrderButton:ClearAllPoints()
			self.AddOrderButton:SetPoint("LEFT", self.BackButton, "RIGHT", 4, 0)
			
			local SelectedCharacter = core.GetSelectedCharacter(true)
			Orders = Orders[SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]]
			
			local Order = Orders[self.SelectedOrder]
			
			for _,recipient in ipairs(Order) do
				local b = core.ButtonPool:Acquire(2)
				if Order[recipient] and type(Order[recipient]) == "table" and Order[recipient].Gold then
					b.Gold = Order[recipient].Gold
					b:SetText(string.format("%s\n\n"..GOLD_AMOUNT_TEXTURE, recipient, Order[recipient].Gold))
				else
					b:SetText(recipient)
				end
				b.Recipient = recipient
				b.EntryDB = Order
				btnList[#btnList + 1] = b
			end
		elseif core.State == "ENTRY_EDIT" then
			return
		end
		
		local buttonWidthWithOffset, xOffset, yOffset = buttonWidth + buttonOffsetX
		local scrollchild = OrdersFrame:GetScrollChild()
		
		for i,btn in pairs(btnList) do
			btn:ClearAllPoints()
			xOffset = buttonOffsetX + math.floor((i - 1) % 3) * buttonWidthWithOffset
			yOffset = buttonOffsetY + math.floor((i - 1) / 3) * scrollStep
			btn:SetPoint(
				"TOPLEFT",
				--scrollchild,
				--"TOPLEFT",
				xOffset,
				-yOffset)
			btn:SetBackdropBorderColor(0, 0, 0, 1)
			btn:Show()
		end
		OrdersFrame:GetScrollChild():SetSize(scrollchildWidth, math.floor(#btnList / 3 + round) * scrollStep + buttonOffsetY)
		
		return btnList[#btnList]
	end
end

do -- AddOrderButton
	AddOrderButton:SetSize(160, 24)
	AddOrderButton:SetPoint("BOTTOMLEFT", OrdersFrame, "TOPLEFT", 0, 4)
	AddOrderButton:SetBackdrop(core.defaultBackdrop)
	AddOrderButton:SetBackdropColor(.4, .4, .4, .2)
	AddOrderButton:SetBackdropBorderColor(0, 0, 0, 1)
	
	AddOrderButton:SetText(PROFESSIONS_CRAFTING_FORM_CREATE_ORDER)
	local fs = AddOrderButton:GetFontString()
	fs:SetFont(core.fontPath, 16)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetPoint("LEFT", 32, 0)
	
	local tex = AddOrderButton:CreateTexture()
	AddOrderButton.texture = tex;
	tex:SetAtlas("communities-icon-addgroupplus")
	tex:SetSize(18, 18)
	tex:SetPoint("LEFT", 5, 0)
	
	AddOrderButton.TooltipText = true
	
	AddOrderButton:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(core.classColour))
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if core.State == "ORDER_EDIT" then
			GameTooltip:AddLine(L["ADD_RECIPIENT"])
		elseif core.State == "ORDER_OVERVIEW" then
			GameTooltip:AddLine(L["TOOLTIP_ADD_MAIL_INFO"])
		end
		GameTooltip:Show()
	end)
	AddOrderButton:SetScript("OnLeave", core.Scripts.OnLeave)
	AddOrderButton:SetScript("OnClick", function(self)
		if core.State == "ORDER_OVERVIEW" then
			core.State = "ORDER_CREATION"
			
			local character = core.GetSelectedCharacter()
			character = character and character.CharacterName or L["GLOBAL"]
			
			db.Orders[core.myRealm] = db.Orders[core.myRealm] or {}
			local Orders = db.Orders[core.myRealm]
			
			Orders[character] = Orders[character] or {} -- indices == Sequential order of orders, keys == table of orders
			
			MasterFrame.EditBox.AssociatedButton = OrdersFrame:Refresh()
			MasterFrame.EditBox:Show()
			
			local l,h = OrdersFrame:GetMinMaxValues()
			OrdersFrame:SetValue(h)
		elseif core.State == "ORDER_EDIT" then
			core.State = "ENTRY_CREATION"
			
			
			local SelectedCharacter = core.GetSelectedCharacter(true)
			local Order = db.Orders[core.myRealm][SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]][OrdersFrame.SelectedOrder]
			local recip = core.GetSelectedCharacter()
			
			if not recip or (SelectedCharacter and SelectedCharacter.CharacterName == recip.CharacterName) then
				core.State = "ORDER_EDIT"
				UIErrorsFrame:AddExternalErrorMessage(L["SELECT_RECIPIENT"])
				return
			end
			
			if Order[recip.CharacterName] then -- Already has an entry for this recip
				core.State = "ORDER_EDIT"
				UIErrorsFrame:AddExternalErrorMessage(string.format("", recip.CharacterName))
				return
			end
			
			Order[#Order + 1] = recip.CharacterName
			Order[recip.CharacterName] = true -- Defaulting
			OrdersFrame:Refresh()
			core.State = "ORDER_EDIT"
		end
	end)
end

do -- BackButton
	BackButton:SetSize(48, 24)
	BackButton:SetPoint("BOTTOMLEFT", OrdersFrame, "TOPLEFT", 0, 4)
	BackButton:SetBackdrop(core.defaultBackdrop)
	BackButton:SetBackdropColor(.4, .4, .4, .2)
	BackButton:SetBackdropBorderColor(0, 0, 0, 1)
	BackButton:Hide()
	
	BackButton.TooltipText = L["BACK_TO_ORDER"]
	BackButton.TooltipAnchor = "ANCHOR_LEFT"
	
	local tex1 = BackButton:CreateTexture()
	BackButton.texture1 = tex1;
	tex1:SetTexture("Interface\\Buttons\\SquareButtonTextures")
	tex1:SetTexCoord(.453125,.640625,.203125,.015625)
	tex1:SetRotation(4.7123)
	tex1:SetSize(16, 16)
	tex1:SetPoint("RIGHT", BackButton, "CENTER", -2, 0)
	
	local tex2 = BackButton:CreateTexture()
	BackButton.texture2 = tex2;
	tex2:SetTexture("Interface\\Buttons\\SquareButtonTextures")
	tex2:SetTexCoord(.453125,.640625,.203125,.015625)
	tex2:SetRotation(4.7123)
	tex2:SetSize(16, 16)
	tex2:SetPoint("LEFT", BackButton, "CENTER", 2, 0)
	
	BackButton:SetScript("OnEnter", core.Scripts.OnEnter)
	BackButton:SetScript("OnLeave", core.Scripts.OnLeave)
	BackButton:SetScript("OnClick", function(self) -- Saves the filter data when return to list of recipients
		if core.State == "ORDER_EDIT" then
			core.State = "ORDER_OVERVIEW"
			self:Hide()
			core.CharactersFrame.AddCharacterButton:Show()
			AddOrderButton:ClearAllPoints()
			AddOrderButton:SetPoint("BOTTOMLEFT", OrdersFrame, "TOPLEFT", 0, 4)
			AddOrderButton:SetText(PROFESSIONS_CRAFTING_FORM_CREATE_ORDER)
			
			core.InfoFrame:SetOrder(false)
			
			-- If a character is selected, unselect it
			local SelectedCharacter = core.GetSelectedCharacter()
			if SelectedCharacter then
				SelectedCharacter:SetBackdropBorderColor(0, 0, 0, 0)
			end
			
			-- Restore SelectedCharacter from Memory
			local SelectedCharacter = core.GetSelectedCharacter(true) -- Get the selected character from memory
			core.SetSelectedCharacter(SelectedCharacter) 
			if SelectedCharacter then -- If the selected character ~= GLOBAL, select it
				SelectedCharacter:SetBackdropBorderColor(RAID_CLASS_COLORS[SelectedCharacter.CharacterClass]:GetRGBA())
			end
			
			OrdersFrame:Refresh()
		elseif core.State == "ENTRY_EDIT" then
			core.State = "ORDER_EDIT"
			
			-- Save Data
			-- ftype -> AND == 1, OR == 2, NOT == 3, Filter == 4
			-- Example: 2(1(4(3:8)4(7:1))1(4(3:127)4(1:1))4(1:2))
			--[[	2(						-- Top level "OR"
						1(					-- "AND"
							4(3:8)			-- Filter
							4(7:1)			-- Filter
						)
						1(					-- "AND"
							4(3:127)		-- Filter
							4(1:1)			-- Name Filter - "SomeString"
						)
						4(1:2)				-- Name Filter - "SomeOtherString"
					)
					
					[1] = "SomeString"
					[2] = "SomeOtherString"
			]]
			
			local data = {}
			local function Serialize(widget)
				local groupType = widget.groupType
				local dataStr = string.format("%s(%%s)", groupType)
				local str = ""
				
				if groupType < 4 then -- 1->3 are groups, 4 is filters
					for _,v in ipairs(widget.Children) do
						str = str..Serialize(v)
					end
				else
					local filterType = widget.filterType
					if filterType == 1 then -- Save strings separately
						data[#data + 1] = core.Filters[1]:LoadData(widget, true)
						dataStr = string.format(dataStr, filterType..":"..#data)
					else
						dataStr = string.format(dataStr, filterType..":"..core.Filters[filterType]:LoadData(widget, true))
					end
				end
				return string.format(dataStr, str)
			end
			data["data"] = Serialize(OrdersFrame.TopLevel)
			
			OrdersFrame.TopLevel.CurrentEntry[OrdersFrame.CurrentRecipient] = data
			
			-- Clean up the entry frames
			local function Cleanup(f)
				for _,v in ipairs(f.Children) do
					if v.groupType < 4 then
						Cleanup(v)
						core.FramePool:Release(v)
					else
						core.FilterPool:Release(v)
					end
				end
				wipe(f.Children)
			end
			Cleanup(OrdersFrame.TopLevel)
			OrdersFrame.TopLevel:UpdateFrameHeight()
			------
			
			core.InfoFrame:SetRecipient(false)
			AddOrderButton:Show()
			OrdersFrame.TopLevel:Hide()
			OrdersFrame:Refresh()
		elseif core.State == "FILTER_CREATE" or core.State == "FILTER_EDIT" then
			UIErrorsFrame:AddExternalErrorMessage(L["CONFIGURE_FILTER"])
		end
	end)
end