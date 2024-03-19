local addon, core = ...
local MasterFrame = core.MasterFrame
local MailDelay = .5
local L, db = core.L
local CR -- coroutine

core.SendFrame = CreateFrame("FRAME", nil, SendMailFrame, "Krozu_ScrollFrame")
local SendFrame = core.SendFrame
local SendButton = CreateFrame("BUTTON", nil, SendMailFrame, "BackdropTemplate")

--[[================

	Constants

==================]]

-- If these values get updated, also update them in CharactersFrame.ButtonPool, button type 3
local buttonWidth, buttonHeight, buttonOffsetX, buttonOffsetY, nButtonsShown, nButtonsPerRow = 208, 56, 4, 4, 12, 2
local round = (nButtonsPerRow - 1) / nButtonsPerRow
local scrollStep = buttonHeight + buttonOffsetY -- Scrollstep for moving up 1 row of buttons
local frameWidth, frameHeight = nButtonsPerRow * (buttonWidth + buttonOffsetX) + buttonOffsetX + 16, math.floor(nButtonsShown / nButtonsPerRow + round) * (scrollStep + buttonOffsetY) + buttonOffsetY
local scrollchildWidth = nButtonsPerRow * (buttonWidth + buttonOffsetX) + buttonOffsetX

------ Stores bag, slot and amount data for required items
	local Items = {itemIDs = {}}

	function Items:Add(itemID, b, s, Amount, filter) -- Save the num filter if there is one
		-- print(string.format("    Items:Add(%s, %s, %s, %s), %s", itemID, b, s, Amount, filter and filter.Amount or "nil"))
		if Amount <= 0 then return end
		local item
		
		if not self[itemID] then
			self.itemIDs[#self.itemIDs + 1] = itemID
			self[itemID] = {
				["MaxStackSize"] = select(8, GetItemInfo(itemID)),
				["Total"] = Amount,
				["SendType"] = 3, -- 0 == All, 1 == All except n, 2 == SelectedAmount, 3 == Starting Position
				["SendAmount"] = 0, -- Amount to send
				["Filter"] = filter,
				{b, s, Amount}
			}
			item = self[itemID]
		else
			item = self[itemID]
			item.Total = item.Total + Amount
			
			for i, data in self:IterateItem(itemID) do
				if b == data[1] and s == data[2] then
					data[3] = data[3] + Amount
					-- print(string.format("MaxStackSize: %d, Total: %d, SendType: %d, SendAmount: %d", item.MaxStackSize, item.Total, item.SendType, item.SendAmount))
					return
				end
			end
			
			table.insert(item, {b, s, Amount}) -- Fresh
		end
		
		if filter and item.SendType > 0 then -- Priority: All > All- > SelectedAmount
			if filter ~= item.Filter and not item.flaggedForWarning then
				item.flaggedForWarning = true -- Only show the warning once for this item
				print(L["INVALID_GROUP_OR_FILTER5"])
				print(L["UNWANTED_BEHAVIOUR"]..tostring(C_Item.GetItemName(ItemLocation:CreateFromBagAndSlot(b, s))))
			end
			
			local filterAmount, itemSendType = filter.FilterAmount, item.SendType
			local sendType = filterAmount > 0 and 2 or (filterAmount < 0 and 1 or -1) -- if this is -1, something went wrong
			
			if sendType < itemSendType then -- if the sendType changes, update the associated filter too
				item.SendType = sendType
				item.Filter = filter
			elseif sendType == itemSendType then -- Filter may need updating if the amounts kept/sent change
				if itemSendType == 1 then -- All-
					-- When holding on to items, if there are multiple negative amount filters, keep whichever one keeps the most items
					-- Can get a bit fucky if the user starts using different amount filters with the same items
					if item.Filter.FilterAmount > filterAmount then
						item.Filter = filter
					end
				elseif itemSendType == 2 then -- SelectedAmount
					-- When sending a set amount of items, if there are multiple amount filters, keep whichever one that sends the most items
					if item.Filter.FilterAmount < filterAmount then
						item.Filter = filter
					end
				end
			end
		else -- Send everything, no need for filter
			item.SendType = 0
			item.Filter = nil
		end
		-- print(string.format("MaxStackSize: %d, Total: %d, SendType: %d, SendAmount: %d", item.MaxStackSize, item.Total, item.SendType, item.SendAmount))
	end

	function Items:Remove(itemID, b, s, Amount)
		if not self[itemID] then return end
		
		for i, data in self:IterateItem(itemID) do
			if b == data[1] and s == data[2] then
				local item = self[itemID]
				if Amount > 0 then
					data[3] = data[3] - Amount
					item.Total = item.Total - Amount
						
					if data[3] == 0 then
						table.remove(item, i)
					end
				else
					item.Total = item.Total - data[3]
					table.remove(item, i)
				end
				
				if item.Total == 0 then
					for j=1,#self.itemIDs do
						if self.itemIDs[j] == itemID then
							table.remove(self.itemIDs, j)
						end
					end
					item = nil
				end
				
				return
			end
		end
	end
		
	function Items:Reset()
		local itemIDs = self.itemIDs
		for i=1,#itemIDs do
			self[itemIDs[i]] = nil
		end
		wipe(self.itemIDs)
	end

	function Items:Iterator() -- iterates over all the items, returning all (ID, Item) entries
		local iterID, ID = 1
		return function()
			repeat
				ID = self.itemIDs[iterID]
				if self[ID] then
					iterID = iterID + 1
					return ID, self[ID]
				end
			until not self[ID]
		end
	end

	function Items:IterateItem(id)
		return function(item, i)
			i = i + 1
			if item[i] then
				return i, item[i]
			end
		end, self[id] or {}, 0
	end
------

local EmptyContainerSlots
local function GetEmptyContainerSlots() -- Ignoring the reagent bag for restacking
	local t = {}
	for b=0,NUM_BAG_FRAMES do
		for s=1,ContainerFrame_GetContainerNumSlots(b) do
			if not C_Container.GetContainerItemInfo(b,s) then
				table.insert(t, {b, s})
			end
		end
	end
	return t
end

-- Tooltip Scanning
local Tooltip = CreateFrame("GameTooltip", nil, nil, "GameTooltipTemplate")
Tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local QUALITY = PROFESSIONS_CRAFTING_FORM_OUTPUT_QUALITY:sub(1,-3)

-- Dragonflight Gems
	-- See Entries.lua for the gem order
	local gemIDs = { -- All gem ID's (rare and epic, with quality 1)
		-- Air
		[192953] = 0x1,
		[192917] = 0x2,
		[192959] = 0x4,
		[192933] = 0x8,
		[192971] = 0x10,
		-- Earth
		[192946] = 0x20,
		[192920] = 0x40,
		[192965] = 0x80,
		[192936] = 0x100,
		[192974] = 0x200,
		-- Fire
		[192943] = 0x400,
		[192926] = 0x800,
		[192956] = 0x1000,
		[192929] = 0x2000,
		[192968] = 0x4000,
		-- Frost
		[192950] = 0x8000,
		[192923] = 0x10000,
		[192962] = 0x20000,
		[192940] = 0x40000,
		[192977] = 0x80000,
		-- Primal
		[192983] = 0x100000,
		[192980] = 0x200000,
		[192986] = 0x400000,
		[192989] = 0x800000
	}
------

function core.GetTooltipInfo(b, s, info, ...)
	local line
	-- info: string descriptor of what info needs scanning, eg. BINDTYPE, RARITY
	-- check if {b,s} exists before calling this function
	-- Extend as needed
	
	--[[ if string.starts(info, "PET_") then -- Getting battle pet info from tooltips is a little weird
		local i, speciesID
		if info == "PET_TYPE" then
			i = 3
		end
		
		if i then
			speciesID = select(3, Tooltip:SetBagItem(b, s))
			return select(i, C_PetJournal.GetPetInfoBySpeciesID(speciesID))
		end
		
		return 0
	end]]
	
	Tooltip:SetBagItem(b, s)
	Tooltip:Show()
	
	if info == "GEM_DRAGONFLIGHT" then
		local itemID, rarity = ...
		local hex = 0
		
		if rarity == 4 and itemID >= 192980 and itemID <= 192991 then -- Primal gems
			return primalColor[math.floor((itemID - 192980) / 3)] or 0 -- Dirty hack to get its color
		elseif rarity == 3 then -- Elemental gems
			local line = Tooltip.TextLeft2:GetText()
			local e, c = line:sub(11, #line-2):match("^(%a+)%s(%a+)$") -- skip the first 11 symbols, is text color
			return bit.band(gemElement[gemElement[e]] or 0, gemColor[gemColor[c]] or 0)
		end
		
		return 0
	end
	
	local t = {
		["BINDTYPE"] = {
			[ITEM_BIND_ON_EQUIP] = 1,
			[ITEM_BIND_ON_PICKUP] = 2,
			[ITEM_BIND_ON_USE] = 3,
			[ITEM_BIND_QUEST] = 4,
			[ITEM_BIND_TO_ACCOUNT] = 5,
			[ITEM_BIND_TO_BNETACCOUNT] = 6,
			[ITEM_BNETACCOUNTBOUND] = 7
		},
	}
	for i=1, Tooltip:NumLines() do
		line = Tooltip["TextLeft"..i]:GetText()
		-- print(line)
		if info == "BINDTYPE" and t.BINDTYPE[line or ""] then
			return t.BINDTYPE[line]
		end
	
		if info == "QUALITY" and string.starts(line, QUALITY) then
			return (line:match(".*:Professions%-Icon%-Quality%-Tier(%d).*")) or 0
		end
	end
	return 0
end

local Filters = {
	[1] = function(data) -- Name
		return {
			Name = data,
			Check = function(self, itemID, b, s)
				return self.Name == C_Item.GetItemName(ItemLocation:CreateFromBagAndSlot(b, s))
			end
		}
	end,
	[2] = function(data) -- Amount
		return {
			Amount = data, -- Used later to keep track of how items are handled
			FilterAmount = data, -- Used by the filter, is constant
			Check = function(self, itemID, b, s)
				if self.FilterAmount > 0 then -- Send an exact amount
					return true, self -- How much that actually gets sent is handled later ("Check" phase)
				elseif self.FilterAmount < 0 then -- Filter is negative number, sort out the amount to send in the next step, just add everything for now
					self.Amount = self.Amount + C_Container.GetContainerItemInfo(b, s).stackCount -- Using Amount to keep track of how many items I need to send
					return true, self
				else
					return false -- self.FilterAmout == 0, send none of the items
				end
			end
		}
	end,
	[3] = function(data) -- Expansion
		local f, t = bit.band(data, 0xf), bit.rshift(data, 4)
		return {
			From = f,
			To = t,
			Check = function(self, itemID)
				local expac = itemID and select(15, GetItemInfo(itemID)) or -1
				
				return self.From <= expac and expac <= self.To
			end
		}
	end,
	[4] = function(data) -- Rarity
		local f, t = bit.band(data, 0xf), bit.rshift(data, 4)
		return {
			From = f,
			To = t,
			Check = function(self, itemID, b, s)
				local cii = C_Container.GetContainerItemInfo(b, s)
				local rarity = cii and cii.quality or -1 -- if the item has no quality property(-1), return false. Still says quality as the key value because dragonflight quality wasn't a thing pre DF
				return self.From <= rarity and rarity <= self.To
			end
		}
	end,
	[5] = function(data) -- Quality
		local f, t = bit.band(data, 0x7), bit.rshift(data, 3)
		return {
			From = f,
			To = t,
			Check = function(self, itemID, b, s)
				local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or -1 -- if the item has no quality property(-1), return false
				return self.From <= quality and quality <= self.To
			end
		}
	end,
	[6] = function(data) -- Item Level
		local f, t = bit.band(data, 0x3ff), bit.rshift(data, 10)
		return {
			From = f,
			To = t,
			Check = function(self, itemID, b, s)
				local ilvl = GetDetailedItemLevelInfo(C_Container.GetContainerItemLink(b, s) or 0) or -1 -- if the item has no itemlevel property(-1), return false
				return self.From <= ilvl and ilvl <= self.To
			end
		}
	end,
	[7] = function(data) -- Transmog
		return {
			-- /run local link= C_Container.GetContainerItemLink(1, 20) local aID,sID=C_TransmogCollection.GetItemInfo(link) print(link, aID,sID) local b=select(5, C_TransmogCollection.GetAppearanceSourceInfo(aID)) print(link, b or false)
			
			flag = data == 1 and true or false,
			Check = function(self, itemID, b, s)
				local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(C_Container.GetContainerItemLink(b, s) or 0)
				
				if appearanceID and sourceID then
					if sourceID then
						local a=C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
						local b=select(5, C_TransmogCollection.GetAppearanceSourceInfo(sourceID))
						return self.flag == ((a and a.appearanceIsCollected) or b)
						-- This seems to work? other than the weird chest armor with no sourceID, need to test this after update!!!!!!!!!
						-- In fact, the chest may no longer be obtainable, would explain something
					else
						return true
					end
			
			--[[ OLD
					local source = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
					local t = {}
					for _,id in pairs(source) do
						t[id] = C_TransmogCollection.GetSourceInfo(id)
					end
					
					local isCollected = false
					for id, info in pairs(t) do
						if info.isCollected then
							isCollected = true
							break
						end
					end
					return self.flag == isCollected
				]]
				else
					local invType = select(4, GetItemInfoInstant(itemID))
					if invType == "INVTYPE_TRINKET" or invType == "INVTYPE_FINGER" or invType == "INVTYPE_NECK" then
						return true
					end
					return false
				end
			end
		}
	end,
	[8] = function(data) -- Consumables
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[1] = bit.band(0x1, self.Data) > 0, -- Potion
					[2] = bit.band(0x2, self.Data) > 0, -- Elixir
					[3] = bit.band(0x4, self.Data) > 0, -- Flask & Phial
					[5] = bit.band(0x8, self.Data) > 0, -- Food & Drink
					[9] = bit.band(0x10, self.Data) > 0, -- Vantus Rune
					[8] = bit.band(0x20, self.Data) > 0, -- Other
				}
				
				local c,sc
				if core.CorrectionList[itemID] then
					-- Correcting Scopes(is set as Consumable-(Other | Explosives & Devices)) to ItemEnhancement-TwoHandedWeapon
					c, sc = unpack(core.CorrectionList[itemID]) 
				else
					c, sc = select(6, GetItemInfoInstant(itemID))
				end
				
				if c == 0 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,
	[9] = function(data) -- Gems
		return {
			Data = data,
			Check = function(self, itemID, b, s)
				local c, sc = select(6, GetItemInfoInstant(itemID))
				if c == 3 then
					local ii = {GetItemInfo(itemID)}
					if sc ~= 9 and ii[15] < 9 then -- sc == 9 -> subClass: Other | ii[15] < 9 -> Everything before Dragonflight
						local t = { -- Got 8 bits left to play with after DF gems, just enough for pre-DF gems
							[0] = bit.band(0x1000000, self.Data) > 0, -- Int
							[1] = bit.band(0x2000000, self.Data) > 0, -- Agi
							[2] = bit.band(0x4000000, self.Data) > 0, -- Strength
							[3] = bit.band(0x8000000, self.Data) > 0, -- Stamina
							-- [4] -- Spirit
							[5] = bit.band(0x10000000, self.Data) > 0, -- Crit
							[6] = bit.band(0x20000000, self.Data) > 0, -- Mastery
							[7] = bit.band(0x40000000, self.Data) > 0, -- Haste
							[8] = bit.band(0x80000000, self.Data) > 0, -- Vers
						}
						return t[sc] or false
					else -- Dragonflight gems
						local quality = (C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 0) - 1
						if quality >= 0 then
							return bit.band(self.Data, gemIDs[itemID - quality] or 0) > 0 -- Bit of a hack using the quality of the item to get its base ID
						else
							return false
						end
					end
				else
					return false
				end
			end
		}
	end,
	[10] = function(data) -- Item Enhancement
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[0] = bit.band(0x1, self.Data) > 0, -- Head
					[1] = bit.band(0x2, self.Data) > 0, -- Neck
					[2] = bit.band(0x4, self.Data) > 0, -- Shoulder
					[3] = bit.band(0x8, self.Data) > 0, -- Cloak
					[4] = bit.band(0x10, self.Data) > 0, -- Chest
					[5] = bit.band(0x20, self.Data) > 0, -- Wrist
					[6] = bit.band(0x40, self.Data) > 0, -- Hands
					[7] = bit.band(0x80, self.Data) > 0, -- Waist
					[8] = bit.band(0x100, self.Data) > 0, -- Legs
					[9] = bit.band(0x200, self.Data) > 0, -- Feet
					[10] = bit.band(0x400, self.Data) > 0, -- Finger
					[11] = bit.band(0x800, self.Data) > 0, -- Weapon
					[12] = bit.band(0x1000, self.Data) > 0, -- Twohanded Weapon
					[13] = bit.band(0x2000, self.Data) > 0, -- Offhand
				}
				local c,sc
				if core.CorrectionList[itemID] then
					-- Correcting Scopes(is set as Consumable-Explosives & Devices) to ItemEnhancement-TwoHandedWeapon
					c, sc = unpack(core.CorrectionList[itemID]) 
				else
					c, sc = select(6, GetItemInfoInstant(itemID))
				end
				if c == 8 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,
	--[[[10] = function(data) -- Glyph
		return {
			-- Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock, Monk, Druid, Demon Hunter
			Data = data,
			Check = function(self, itemID)
				local t = {
					[1] = bit.band(0x1, self.Data) > 0,
					[2] = bit.band(0x2, self.Data) > 0,
					[3] = bit.band(0x4, self.Data) > 0,
					[4] = bit.band(0x8, self.Data) > 0,
					[5] = bit.band(0x10, self.Data) > 0,
					[6] = bit.band(0x20, self.Data) > 0,
					[7] = bit.band(0x40, self.Data) > 0,
					[8] = bit.band(0x80, self.Data) > 0,
					[9] = bit.band(0x100, self.Data) > 0,
					[10] = bit.band(0x200, self.Data) > 0,
					[11] = bit.band(0x400, self.Data) > 0,
					[12] = bit.band(0x800, self.Data) > 0,
				}
				local c, sc = select(6, GetItemInfoInstant(itemID))
				if c == 16 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,]]
	[11] = function(data) -- Armor Slot
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					["INVTYPE_HEAD"] = bit.band(0x1, self.Data) > 0,
					["INVTYPE_NECK"] = bit.band(0x2, self.Data) > 0,
					["INVTYPE_SHOULDER"] = bit.band(0x4, self.Data) > 0,
					["INVTYPE_CLOAK"] = bit.band(0x8, self.Data) > 0,
					["INVTYPE_CHEST"] = bit.band(0x10, self.Data) > 0,
					["INVTYPE_ROBE"] = bit.band(0x10, self.Data) > 0,
					["INVTYPE_WRIST"] = bit.band(0x20, self.Data) > 0,
					["INVTYPE_HAND"] = bit.band(0x40, self.Data) > 0,
					["INVTYPE_WAIST"] = bit.band(0x80, self.Data) > 0,
					["INVTYPE_LEGS"] = bit.band(0x100, self.Data) > 0,
					["INVTYPE_FEET"] = bit.band(0x200, self.Data) > 0,
					["INVTYPE_FINGER"] = bit.band(0x400, self.Data) > 0,
					["INVTYPE_TRINKET"] = bit.band(0x800, self.Data) > 0,
				}
				local equipLoc,_,c = select(4, GetItemInfoInstant(itemID))
				if c == 4 then
					return t[equipLoc] or false
				else
					return false
				end
			end
		}
	end,
	[12] = function(data) -- Armor Type
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[1] = bit.band(0x1, self.Data) > 0, -- Cloth
					[2] = bit.band(0x2, self.Data) > 0, -- Leather
					[3] = bit.band(0x4, self.Data) > 0, -- Mail
					[4] = bit.band(0x8, self.Data) > 0, -- Plate
				}
				local c, sc = select(6, GetItemInfoInstant(itemID))
				if c == 4 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,
	[13] = function(data) -- Weapon Type
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[0] = bit.band(0x4, self.Data) > 0, -- One-Handed Axes
					[1] = bit.band(0x8, self.Data) > 0, -- Two-handed Axes
					[2] = bit.band(0x100, self.Data) > 0, -- Bows
					[3] = bit.band(0x400, self.Data) > 0, -- Guns
					[4] = bit.band(0x10, self.Data) > 0, -- One-Handed Maces
					[5] = bit.band(0x20, self.Data) > 0, -- Two-Handed Maces
					[6] = bit.band(0x800, self.Data) > 0, -- Polearms
					[7] = bit.band(0x1, self.Data) > 0, -- One-handed Swords
					[8] = bit.band(0x2, self.Data) > 0, -- Two-handed Swords
					[9] = bit.band(0x1000, self.Data) > 0, -- Warglaives
					[10] = bit.band(0x40, self.Data) > 0, -- Staves
					[13] = bit.band(0x4000, self.Data) > 0, -- First Weapons
					[15] = bit.band(0x2000, self.Data) > 0, -- Daggers
					[18] = bit.band(0x200, self.Data) > 0, -- Crossbows
					[19] = bit.band(0x80, self.Data) > 0,  -- Wands
				}
				local t_ = {
					[6] = bit.band(0x8000, self.Data) > 0, -- Shields
					["INVTYPE_HOLDABLE"] = bit.band(0x10000, self.Data) > 0
				}
				
				local equipLoc, _, c, sc = select(4, GetItemInfoInstant(itemID))
				
				if c == 2 then
					return t[sc] or false
				elseif c == 4 then -- Bliz sees shields and offhands as armor, this turns them into weapons
					return t_[sc] or t_[equipLoc] or false
				else
					return false
				end
			end
		}
	end,
	[14] = function(data) -- Tradeskill
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[4] = bit.band(0x40, self.Data) > 0, -- Jewelcrafting
					[5] = bit.band(0x1, self.Data) > 0, -- Cloth
					[6] = bit.band(0x2, self.Data) > 0, -- Leather
					[7] = bit.band(0x4, self.Data) > 0, -- Metal & Stone
					[8] = bit.band(0x80, self.Data) > 0, -- Cooking
					[9] = bit.band(0x8, self.Data) > 0, -- Herb
					[10] = bit.band(0x100, self.Data) > 0, -- Elemental
					[11] = bit.band(0x200, self.Data) > 0, -- Other
					[12] = bit.band(0x10, self.Data) > 0, -- Enchanting
					[16] = bit.band(0x20, self.Data) > 0, -- Inscription
					[18] = bit.band(0x400, self.Data) > 0, -- Optional Reagents
					[19] = bit.band(0x800, self.Data) > 0 -- Finishing Reagents
				}
				local c, sc = select(6, GetItemInfoInstant(itemID))
				if c == 7 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,
	[15] = function(data) -- Recipes
		return {
			Data = data,
			Check = function(self, itemID)
				local t = {
					[1] = bit.band(0x1, self.Data) > 0, -- Leatherworking
					[2] = bit.band(0x2, self.Data) > 0, -- Tailoring
					[3] = bit.band(0x4, self.Data) > 0, -- Engineering
					[4] = bit.band(0x8, self.Data) > 0, -- Blacksmithing
					[6] = bit.band(0x10, self.Data) > 0, -- Alchemy
					[8] = bit.band(0x20, self.Data) > 0, -- Enchanting
					[10] = bit.band(0x40, self.Data) > 0, -- Jewelcrafting
					[11] = bit.band(0x80, self.Data) > 0, -- Inscription
				}
				local c, sc = select(6, GetItemInfoInstant(itemID))
				if c == 9 then
					return t[sc] or false
				else
					return false
				end
			end
		}
	end,
	--[[[16] = function(data) -- Battle Pets
		return {
			Data = data,
			Check = function(self, itemID, b, s)
				local t = {
					[1] = bit.band(0x1, self.Data) > 0,
					[2] = bit.band(0x2, self.Data) > 0,
					[3] = bit.band(0x4, self.Data) > 0,
					[4] = bit.band(0x8, self.Data) > 0,
					[5] = bit.band(0x10, self.Data) > 0,
					[6] = bit.band(0x20, self.Data) > 0,
					[7] = bit.band(0x40, self.Data) > 0,
					[8] = bit.band(0x80, self.Data) > 0,
					[9] = bit.band(0x100, self.Data) > 0,
					[10] = bit.band(0x200, self.Data) > 0,
				}
				local c = select(6, GetItemInfoInstant(itemID))
				if c == 17 then
					return t[core.GetTooltipInfo(b, s, "PET_TYPE")] or false
				else
					return false
				end
			end
		}
	end,]]
}

local Groups = {
	[1] = function() -- And
		return {
			Check = function(self, itemID, b, s)
				local flag, num
				for i,v in ipairs(self) do
					flag, num = v:Check(itemID, b, s)
					if not flag then
						return false
					end
				end
				return true, num
			end
		}
	end,
	[2] = function() -- Or
		return {
			Check = function(self, itemID, b, s)
				local flag, num
				for i,v in ipairs(self) do
					flag, num = v:Check(itemID, b, s)
					if flag then
						return true, num
					end
				end
				if #self > 0 then
					return false
				else -- if the group is empty, return true
					return true
				end
			end
		}
	end,
	[3] = function() -- Not
		return {
			Check = function(self, itemID, b, s)
				if self[1] then
					local flag, num = self[1]:Check(itemID, b ,s)
					return not flag, num
				else
					return true
				end
			end
		}
	end
}

local lastState
core.HookFunctionToEvent("MAIL_CLOSED", function()
	core.State = lastState or core.State
	lastState = nil
	core.UnhookAllFunctionsFromEvent("PLAYER_MONEY")
	core.UnhookAllFunctionsFromEvent("MAIL_FAILED")
	core.UnhookAllFunctionsFromEvent("ITEM_UNLOCKED")
	core.UnhookAllFunctionsFromEvent("SECURE_TRANSFER_CANCEL")
	CR = nil
end)

--[[===========

	Sending

=============]]

local function Deserialize(entry)
	-- print("  Deserialize")
	local SuperFilter = Groups[2]()
	
	if type(entry) == "table" then
		local pStart, pEnd, fType, fData, par, Type -- Pattern Start, Pattern End, Filter Type, Filter Data, parenthesis
		local serial = select(3, entry.data:find("^%d%((.*)%)$"))
		local currentGroup = SuperFilter
		local iterator, Stack = 1, {
			[1] = currentGroup
		}
		local nData = 0
		local hasNumberFilter = false
		
		while iterator <= #serial do
			pStart, pEnd, par, Type = serial:find("^(%)?)(%d*)", iterator)
			
			if par == "" then
				Type = tonumber(Type)
				if Type == 4 then -- Filter
					pStart, pEnd, par, Type = serial:find("^%d+%((%d+):(-?%d+)%)", pStart)
					fType, fData = tonumber(par), tonumber(Type)
					
					-- Do filter specific stuff here
						if fType == 1 then -- Name Filter
							fData = entry[fData]
						elseif fType == 2 then -- Number filter
							hasNumberFilter = true
							nData = fData
						end
					------
					
					if fType ~= 2 then -- Number Filters are last in groups, for reasons.
						table.insert(currentGroup, Filters[fType](fData))
						-- print(string.format("    CreateFilter(%q, %q)", fType, fData))
					end
					iterator = pEnd + 1
				else -- Group
					table.insert(currentGroup, Groups[Type]())
					currentGroup = currentGroup[#currentGroup]
					table.insert(Stack, currentGroup)
					iterator = pStart + 2
					-- print(string.format("    CreateGroup(%q)", Type))
				end
			else
				if hasNumberFilter then
					hasNumberFilter = false
					table.insert(currentGroup, Filters[2](nData))
					-- print(string.format("    CreateFilter(%q, %q)", 2, nData))
					nData = 0
				end
				table.remove(Stack)
				currentGroup = Stack[#Stack]
				iterator = pStart + 1
			end
		end
	end
	
	return SuperFilter
end

local function ScanBags(SuperFilter)
	-- print("  Scan")
	Items:Reset()
	for b=0,NUM_TOTAL_BAG_FRAMES do
		for s=1, C_Container.GetContainerNumSlots(b) do
			local info = C_Container.GetContainerItemInfo(b, s)
			
			if info and info.itemID and not info.isFiltered and not info.isBound then -- check if inventory item is grayed out, or soulbound
				local flag, filter = SuperFilter:Check(info.itemID, b, s)
				if flag then
					-- print(C_Item.GetItemName(ItemLocation:CreateFromBagAndSlot(b, s)), info.itemID, b, s, info.stackCount, filter)
					Items:Add(info.itemID, b, s, info.stackCount, filter)
				end
			end
		end
	end
end

local function CreateActions()
	-- print("  CreateActions")
	EmptyContainerSlots = GetEmptyContainerSlots()
	local Actions = {}
	--[[	Actions has an indexed list containing the following:
				
				[1] = Type of action -> "ADD" | "SPLIT" | "MERGE"
				
				ADD -> [2] = BagID, [3] = SlotID -- Add items to the mail
				
				SPLIT -> [2] = SourceBagID, [3] SourceSlotID, [4] = SplitAmount, [5] = DestinationBagID, [6] = DestinationSlotID -- Split stack into other stack(s) or a fresh one
				
				MERGE -> [2] = SourceBagID, [3] SourceSlotID, [4] = MergeAmount, [5] = DestinationBagID, [6] = DestinationSlotID, isConsumed = bool -- Merge the source into the destination

			
			Table returned by Items:Iterator contains the following:
			
				data[1] = BagID, data[2] = Slot ID, data[3] = StackSize
	]]
	
	for id, item in Items:Iterator() do
		local data
		-- print("id:", id,"-", item.SendAmount or "nil")
		while item.SendAmount ~= 0 do
			data = item[1] -- Possibly deleted every loop
			-- print(string.format("  Bag: %d, Slot: %d, Amount: %s", data[1], data[2], data[3]))
			if item.SendAmount == data[3] then -- Item in stack is the exact amount that needs sending
				table.insert(Actions, {"ADD", data[1], data[2]})
				table.remove(item, 1)
				break
			elseif item.SendAmount < data[3] then -- Items in stack are more than needs sending
				-- print("#",item.SendAmount, item.Total, data[3])
				local lookup_iterator = 2
				local lookup = item[lookup_iterator] -- lookup is simply the next (or whatever index) up in the list after the item we're processing
				local split = data[3] - item.SendAmount -- Whatever we don't need to send after splitting
				
				while lookup do
					if lookup[3] + split > item.MaxStackSize then -- Merging the remainder into another stack, but overcapping it
						local freeSpace = item.MaxStackSize - lookup[3] -- Free space in the target stack
						Items:Remove(id, data[1], data[2], freeSpace)
						table.insert(Actions, {"SPLIT", data[1], data[2], freeSpace, lookup[1], lookup[2]}) -- Split {split} of {data[1], data[2]} into {lookup[1], lookup[2]}
						split = split - freeSpace
						lookup_iterator = lookup_iterator + 1
						lookup = item[lookup_iterator]
					else -- Merging the remainder into another stack without overcapping it
						Items:Remove(id, data[1], data[2], split)
						table.insert(Actions, {"SPLIT", data[1], data[2], split, lookup[1], lookup[2]}) -- Split {split} of {data[1], data[2]} into {lookup[1], lookup[2]}
						split = 0
						lookup = nil
					end
				end
				
				if split > 0 then -- No other stacks were found to put the remainder in, put it in an empty bag slot
					if #EmptyContainerSlots == 0 then
						UIErrorsFrame:AddExternalErrorMessage(L["EMPTY_BAG_SLOTS_NEEDED"])
						return false
					end
					local b, s = unpack(table.remove(EmptyContainerSlots))
					table.insert(Actions, {"SPLIT", data[1], data[2], split, b, s}) -- Split {split} of {data[1], data[2]} into {b, s}
					Items:Add(id, b, s, split)
				end
				item.SendAmount = 0
				table.insert(Actions, {"ADD", data[1], data[2]})
				table.remove(item, 1)
			elseif item.SendAmount > data[3] then -- Merge stacks
				local topUpAmount -- amount needed to fill source stack to requirements (or max stacksize)
				if item.SendAmount > item.MaxStackSize then -- Amount to send exceeds the max stack size
					topUpAmount = item.MaxStackSize - data[3]
					item.SendAmount = item.SendAmount - item.MaxStackSize
				else
					topUpAmount = item.SendAmount - data[3]
					item.SendAmount = 0
				end
				
				if topUpAmount > 0 then -- topUpAmount is 0 when the stacksize is maxstacksize, but demand is more than maxstacksize
					local lookup_iterator = 2
					local lookup = item[lookup_iterator] -- lookup is simply the next (or whatever index) up in the list after the item we're processing
					
					-- isConsumed is whether or not the source stack gets completely absorbed by the target stack
					-- true == Two stacks become ONE, false == Two stacks stay TWO
					while lookup do
						if lookup[3] == topUpAmount then
							table.insert(Actions, {"MERGE", lookup[1], lookup[2], topUpAmount, data[1], data[2], ["isConsumed"] = true})
							table.remove(item, lookup_iterator)
							break
						elseif lookup[3] > topUpAmount then
							table.insert(Actions, {"MERGE", lookup[1], lookup[2], topUpAmount, data[1], data[2], ["isConsumed"] = false})
							lookup[3] = lookup[3] - topUpAmount
							break
						else -- lookup[3] < topUpAmount -- source stack was fully absorbed, but wasn't enough to satisfy demand
							data[3] = data[3] + lookup[3]
							topUpAmount = topUpAmount - lookup[3]
							table.insert(Actions, {"MERGE", lookup[1], lookup[2], lookup[3], data[1], data[2], ["isConsumed"] = true})
							table.remove(item, lookup_iterator)
							lookup = item[lookup_iterator]
						end
					end
				end
				table.insert(Actions, {"ADD", data[1], data[2]})
				table.remove(item, 1)
			end
		end
	end
	
	return Actions
end

local function ProcessActions(Actions, OrderName, recipient)
	-- print("  ProcessActions")
	local ItemsInBatch, b, s = 0
	local function Resume_Batching(b_, s_)
		-- print("Resume Batching:", b or "nil", b_ or "nil", s or "nil", s_ or "nil")
		if b == b_ and s == s_ then
			core.UnhookFunctionFromEvent("ITEM_UNLOCKED", Resume_Batching)
			C_Timer.After(MailDelay, function() coroutine.resume(CR) end)
		end
	end
	
	local function Resume_Send(event)
		core.UnhookFunctionFromEvent("PLAYER_MONEY", Resume_Send)
		core.UnhookFunctionFromEvent("MAIL_FAILED", Resume_Send)
		core.UnhookFunctionFromEvent("SECURE_TRANSFER_CANCEL", Resume_Send)
		if event == "MAIL_FAILED" or event == "SECURE_TRANSFER_CANCEL" then -- Recipient does not exist, or was cancelled
			ClearSendMail()
		elseif event == "PLAYER_MONEY" then
			print(string.format(L["MAIL_FROM_TO"], addon, OrderName, recipient))
		end
		C_Timer.After(MailDelay, function() if CR then coroutine.resume(CR) end end) -- The 'if' statement is there for when the mail frame gets closed while the securepopup is active
	end
	
	local function Send()
		-- Currently breaking due to an attempt to send mail to a character that is unknown (SECURE_TRANSFER_CONFIRM_SEND_MAIL)
		-- If the character doesn't exist it fires the 'MAIL_FAILED' event and moves on just fine.
		-- If the character does exist the function proceeds as intended.
		-- However, if the player presses 'Cancel', the 'PLAYER_MONEY' or 'MAIL_FAILED' or 'SECURE_TRANSFER_CANCEL' events never
		-- fire meaning that, in the end, 'State' stays on 'SENDING_MAIL' permanently.
		-- Closing and reopening the mail frame fixes this.
		-- tldr; Don't talk to strangers.
		
-- Bug report
-- 
-- Pressing 'Cancel' in the 'SecureFrame' when mailing to a stranger doesn't fire the 'SECURE_TRANSFER_CANCEL' event.
--
		core.HookFunctionToEvent("PLAYER_MONEY", Resume_Send)
		core.HookFunctionToEvent("MAIL_FAILED", Resume_Send)
		core.HookFunctionToEvent("SECURE_TRANSFER_CANCEL", Resume_Send) -- Currently does nothing, should trigger when pressing cancel on secureframe
		SendMail(recipient, string.format("%s(%s)", addon, OrderName))
		print(string.format(L["MAIL_FROM_TO"], addon, OrderName, recipient))
		coroutine.yield()
	end
	
	local Action
	for i=1,#Actions do
		Action = Actions[i]
		if Action[1] == "ADD" then
			-- print(Action[1])
			C_Container.UseContainerItem(Action[2], Action[3])
			ItemsInBatch = ItemsInBatch + 1
			if ItemsInBatch == 12 then
				-- print("Batch ready!")
				ItemsInBatch = 0
				if GetMoney() < 360 then -- 360 = maximum cost for sending mail
					UIErrorsFrame:AddExternalErrorMessage(L["SEND_MAIL_MONEY_SHORTAGE"])
					ClearSendMail()
					core.State = lastState
					return false
				end
				Send()
			end
		elseif Action[1] == "SPLIT" then
			-- print(Action[1])
			core.HookFunctionToEvent("ITEM_UNLOCKED", Resume_Batching)
			b, s = Action[2], Action[3]
			C_Container.SplitContainerItem(Action[2], Action[3], Action[4])
			C_Container.PickupContainerItem(Action[5], Action[6])
			coroutine.yield()
		elseif Action[1] == "MERGE" then
			-- Merging 2 stacks into 1 fires ITEM_UNLOCKED event for target slot, keeping 2 stacks fires it for the source slot
			core.HookFunctionToEvent("ITEM_UNLOCKED", Resume_Batching)
			if Action.isConsumed then
				b, s = Action[5], Action[6]
			else -- Action.isConsumed == false
				b, s = Action[2], Action[3]
			end
			C_Container.SplitContainerItem(Action[2], Action[3], Action[4])
			C_Container.PickupContainerItem(Action[5], Action[6])
			coroutine.yield()
		end
	end
	
	if ItemsInBatch > 0 then
		if GetMoney() < ItemsInBatch * 30 then -- 30c per item
			UIErrorsFrame:AddExternalErrorMessage(L["SEND_MAIL_MONEY_SHORTAGE"])
			ClearSendMail()
			core.State = lastState
			return false
		end
		Send()
	end
	
	return true
end

local function SendOrder(button)
	if core.State == "SENDING_MAIL" then return end
	
	lastState = core.State
	core.State = "SENDING_MAIL"
	ClearSendMail()
	-- Pressing 'Cancel' on the secure prompt causes no more events to fire, which means 'State' never switches from 'SENDING_MAIL'
	
	local OrderName, Order, SuperFilter = button:GetText(), button.db
	local myName = UnitName("player")
	
	-- print("Coroutine start", #Order)
	CR = coroutine.create(function()
		for _,recipient in ipairs(Order) do -- Loop Recipients
			if recipient ~= myName then
				-- If the top filter is empty and a money value is assigned to this recipient, chances are this is used for money transfer only
				-- This prevents every single item from being sent over
				if not (Order[recipient].data == "2()" and Order[recipient].Gold) then
					-- Deserialize and construct the SuperFilter for this recipient
						SuperFilter = Deserialize(Order[recipient])
					------
					
					-- Scan bags and find the items we need using the created SuperFilter
						if ScanBags(SuperFilter) == false then
							print(string.format("%s - %s", addon, L["SEND_MAIL_SPLIT_SPACE"]))
							core.State = lastState
							lastState = nil
							return
						end
					------
					
					-- print("  Check")
					-- Sanity checks for Items -- Checking if theres enough items, if the number is negative or 0, and so on
					-- Primarily used for the amount filter
						for id, item in Items:Iterator() do
							if item.SendType == 0 then -- Send All
								item.SendAmount = item.Total
							elseif item.SendType == 1 then -- Send all but %d
								if item.Filter.Amount > 0 then -- Filter.Amount -> amount of items that still need sending
									item.SendAmount = min(item.Filter.Amount, item.Total) -- eg. 6 = 8 + (-2)
									item.Filter.Amount = item.Filter.Amount - item.SendAmount
								end
							elseif item.SendType == 2 then -- Send SelectedAmount
								if item.Total <= item.Filter.Amount then
									item.SendAmount = item.Total
									item.Filter.Amount = item.Filter.Amount - item.Total
								else
									item.SendAmount = item.Filter.Amount
									item.Filter.Amount = 0
								end
							end
							-- print(id, item.SendType, item.SendAmount)
						end
					------
					
					-- Loop through items and figure out what to do with them
						local Actions = CreateActions()
						if Actions == false then
							print(string.format("%s - %s", addon, L["SEND_MAIL_MONEY_SHORTAGE"]))
							core.State = lastState
							lastState = nil
							return
						end
						
						-- for i,v in ipairs(Actions) do
							-- print(v[1], v[2], v[3], v[4] or "", v[5] or "", v[6] or "", v.isConsumed)
						-- end	
					------
					
					-- Process Actions and send
						if ProcessActions(Actions, OrderName, recipient) == false then
							print(string.format("%s - %s", addon, L["SEND_MAIL_SPLIT_SPACE"]))
							core.State = lastState
							lastState = nil
							return
						end
					------
				end -- If order.data == "2()"
			 -- Send gold, if any is set
				if Order[recipient] and type(Order[recipient]) == "table" and Order[recipient].Gold then
					local gold = Order[recipient].Gold * 10000
					if gold < 0 then -- Send all but x
						gold = GetMoney() + (gold - 30) -- 30 for sending cost
					end
					
					local function Send(event)
						core.UnhookFunctionFromEvent("PLAYER_MONEY", Send)
						core.UnhookFunctionFromEvent("MAIL_FAILED", Send)
						core.UnhookFunctionFromEvent("SECURE_TRANSFER_CANCEL", Send)
						if event == "MAIL_FAILED" or event == "SECURE_TRANSFER_CANCEL" then -- Recipient does not exist, or was cancelled
							ClearSendMail()
						elseif event == "PLAYER_MONEY" then
							print(string.format(L["MAIL_FROM_TO"], addon, OrderName, recipient))
						end
						C_Timer.After(MailDelay, function() if CR then coroutine.resume(CR) end end) -- The 'if' statement is there for when the mail frame gets closed while the securepopup is active
					end
					
					if gold > 0 then
						core.HookFunctionToEvent("PLAYER_MONEY", Send)
						core.HookFunctionToEvent("MAIL_FAILED", Send)
						core.HookFunctionToEvent("SECURE_TRANSFER_CANCEL", Send)
						
						SetSendMailMoney(gold)
						print(string.format(L["MAIL_FROM_TO"].." "..GOLD_AMOUNT_TEXTURE, addon, OrderName, recipient, math.floor(gold / 10000)))
						SendMail(recipient, string.format("%s(%s)", addon, OrderName))
						coroutine.yield()
					else
						print(string.format("%s - %s", addon, L["SEND_MAIL_MONEY_SHORTAGE"]))
					end
				end -- If has Gold
			end -- if recip ~= thisCharacter
		end -- End loop recipients
		print(string.format("%s - %s", addon, L["SENDING_FINISHED"]))
		core.State = lastState
		lastState = nil
	end)
	coroutine.resume(CR)
end
core.SendOrder = SendOrder

--[[================

	User Interface

==================]]

do -- OrdersFrame
	SendFrame:SetBackdropColor(.1, .1, .1, .95)
	SendFrame:SetBackdropBorderColor(0, 0, 0, 1)
	SendFrame:SetSize(frameWidth, frameHeight)
	SendFrame:SetScrollStep(scrollStep * 2)
	SendFrame:SetPoint("LEFT", MailFrame, "RIGHT", 8, 0)
	SendFrame:Hide()
	
	function SendFrame:Init()
		db = core.db or {}
	end
	function SendFrame:Refresh()
		local scrollchild = SendFrame:GetScrollChild()
		local Orders = db.Orders[core.myRealm]
		self.Buttons:Clear()
		
		local gOrders, cOrders = Orders[L["GLOBAL"]] or {}, Orders[GetUnitName("player")] or {}
		
		if #gOrders == 0 and #cOrders == 0 then
			return
		end
		
		local btn
		for _,orderName in ipairs(gOrders) do
			btn = core.ButtonPool:Acquire(3)
			btn:SetText(orderName)
			btn.db = gOrders[orderName]
			table.insert(self.Buttons, btn)
		end
		
		for _,orderName in ipairs(cOrders) do
			btn = core.ButtonPool:Acquire(3)
			btn:SetText(orderName)
			btn.db = cOrders[orderName]
			table.insert(self.Buttons, btn)
		end
		
		if #gOrders > 0 then
			scrollchild.Global:Show()
		else
			scrollchild.Global:Hide()
		end
		
		local xOffset, yOffset, xOffsetRight = buttonOffsetX, -16, buttonWidth + buttonOffsetX * 2 -- +28 starting offset for the first button
		local isCharacterOrder
		for i, btn in ipairs(self.Buttons) do
			i = isCharacterOrder and i + 1 or i
			if i % 2 == 0 then
				xOffset = xOffsetRight
			else
				xOffset = buttonOffsetX
				yOffset = yOffset + buttonHeight + buttonOffsetY
			end
			
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", xOffset, -yOffset)	
			btn:Show()
			
			if i == #gOrders then
				if #cOrders > 0 then
					if i % 2 == 1 then
						yOffset = yOffset + buttonHeight + buttonOffsetY
						isCharacterOrder = true
					end
					
					scrollchild.Character:SetPoint("TOPLEFT", 16, -(yOffset + 12))
					scrollchild.Character:Show()
					yOffset = yOffset - 16
				else
					scrollchild.Character:Hide()
				end
			end
		end
		
		scrollchild:SetSize(scrollchildWidth, yOffset + buttonHeight + buttonOffsetY)
	end
	SendFrame.Buttons = {
		Clear = function(self)
			for i=1,#self do
				core.ButtonPool:Release(self[i])
				self[i] = nil
			end
		end
	}
	
	SendFrame:SetScript("OnShow", function(self)
		self:Refresh()
	end)
end

do -- SendButton
	SendButton:SetBackdrop(core.defaultBackdrop)
	SendButton:SetBackdropColor(.4, .4, .4, .2)
	SendButton:SetBackdropBorderColor(0, 0, 0, 1)
	SendButton:SetSize(32, 32)
	SendButton:SetPoint("BOTTOMRIGHT", SendMailCancelButton, "TOPRIGHT", -8, 8)
	SendButton:RegisterForClicks("AnyUp")
	
	SendButton.TooltipText = L["MAIL_FRAME_TOOLTIP"]
	SendButton.OnClick = function(self, mouseButton)
		if mouseButton == "LeftButton" then
			if SendFrame:IsShown() then
				SendFrame:Hide()
			else
				if MasterFrame:IsShown() then
					MasterFrame:Hide()
				end
				SendFrame:Show()
			end
		else
			if SendFrame:IsShown() then
				SendFrame:Hide()
			end
			MasterFrame:Show()
		end
	end
	
	local tex = SendButton:CreateTexture()
	SendButton.texture = tex;
	tex:SetTexture(136459)
	tex:SetSize(24, 24)
	tex:SetPoint("CENTER")
	
	SendButton:SetScript("OnEnter", core.Scripts.OnEnter)
	SendButton:SetScript("OnLeave", core.Scripts.OnLeave)
	SendButton:SetScript("OnClick", SendButton.OnClick)
end

do -- Fontstrings GLOBAL & CHARACTER
	local scrollchild = SendFrame:GetScrollChild()
	scrollchild.Global = scrollchild:CreateFontString()
	local fs = scrollchild.Global
	fs:SetPoint("TOPLEFT", 16, -12)
	
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetFont(core.fontPath, 16, "")
	fs:SetText(L["GLOBAL"])
	
	scrollchild.Character = scrollchild:CreateFontString()
	local fs = scrollchild.Character
	
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetFont(core.fontPath, 16, "")
	fs:SetText(CHARACTER)
end
