-- Init
	local addon, core = ...
	local EVENTFRAME = CreateFrame("FRAME")
	local L, db, dbc
	local GrandMail_SlashCmdList = {}
	local DEBUG = false
	
	L = core.L[GetLocale()] or core.L["enUS"]
	core.L = L
	
	local MasterFrame, CharactersFrame, OrdersFrame
	
	core.State = "ADDON_START"
	core.classColour = {RAID_CLASS_COLORS[select(2, UnitClass("player"))]:GetRGBA()}
	core.Scripts = {
		OnEnter = function(self) -- Generic OnEnter script
			self:SetBackdropBorderColor(unpack(core.classColour))
			if self.TooltipText then
				GameTooltip:SetOwner(self, self.TooltipAnchor or "ANCHOR_RIGHT")
				GameTooltip:AddLine(self.TooltipText)
				GameTooltip:Show()
			end
		end,
		OnLeave = function(self) -- Generic OnLeave script
			self:SetBackdropBorderColor(0, 0, 0, 1)
			if self.TooltipText then
				GameTooltip:Hide()
			end
		end,
		OnEscapePressed = function(self) -- Used for MasterFrame.EditBox
			local SelectedCharacter, state = core.GetSelectedCharacter(), core.State
			if state == "CHARACTER_CREATION" then
				core.ButtonPool:Release(SelectedCharacter)
				core.SetSelectedCharacter(false)
				self:Hide()
				CharactersFrame:Refresh()
			elseif state == "CHARACTER_EDIT" then
				self.AssociatedButton:Show()
				self.AssociatedButton = false
				self:Hide()
			elseif state == "ORDER_CREATION" then
				self:Hide()
			--elseif state == "ENTRY_CREATION" then
				--
			elseif state == "ENTRY_SET_GOLD" then
				self.AssociatedButton = false
				self:Hide()
				return
			end
			core.State = "ORDER_OVERVIEW"
			OrdersFrame:Refresh()
		end,
	}

	if not string.starts then
		function string.starts(str, start)
			return string.sub(str, 1, string.len(start)) == start
		end
	end
	
	if DEBUG then
		function core.trunc(f, n)
			n = 10^(n or 0)
			return math.floor(n * f + .5) / n
		end
	end
------

-------- Event Handling
do
	local function insert(t, f) -- t:insert(f)
		if f and type(f) == "function" then
			if not rawget(t._funcs, f) then -- New function
				t._indices[#t._indices + 1] = f
				t._funcs[f] = #t._indices
			end
		end
	end
	
	local function remove(t, f) -- t:remove(f)
		if f then
			table.remove(t._indices, t._funcs[f])
			t._funcs[f] = nil
		end
	end	
	
	local function size(t) -- t:size()
		return #t._indices
	end
	
	local function pairs(t) -- t:pairs()
		local i = 0
		return function()
			i = i + 1
			local f = t[i]
			if f then
				return i, f
			end
		end
	end
	
	local function new(isCustomEvent) -- OrderedEvents = {_indices = {}, _funcs = {}, isCustomEvent = false}
		local t = {_indices={}, _funcs={}, isCustomEvent=isCustomEvent, insert=insert, remove=remove, size=size, pairs=pairs}
		return setmetatable(t, {
			-- __len = function(t) print("__len") return #t._indices end, -- Does not work in lua 5.1
			-- __pairs = Events.pairs, -- Does not work in lua 5.1
			__index = t._indices
		})
	end

	function core.HookFunctionToEvent(event, func, isCustomEvent) -- STRING, function, BOOLEAN
		if not func then return end
		local e = EVENTFRAME[event]
		
		if not e then
			if not isCustomEvent then
				EVENTFRAME:RegisterEvent(event)
			end
			EVENTFRAME[event] = new(isCustomEvent and true or false)
			e = EVENTFRAME[event]
		end
		e:insert(func)
	end
	
	function core.UnhookFunctionFromEvent(event, func) -- STRING, function
		local e = EVENTFRAME[event]
		if e then
			e:remove(func)
			if e:size() == 0 then
				if not e.isCustomEvent then
					EVENTFRAME:UnregisterEvent(event)
				end
				EVENTFRAME[event] = nil
			end
		end
	end
	
	function core.UnhookAllFunctionsFromEvent(event)
		local e = EVENTFRAME[event]
		if e then
			if not e.isCustomEvent then
				EVENTFRAME:UnregisterEvent(event)
			end
			EVENTFRAME[event] = nil
		end
	end
	
	function core.FireEvent(event, ...) -- Event followed by args
		if EVENTFRAME[event] then
			--print(event)
			for k,v in EVENTFRAME[event]:pairs() do
				v(...)
			end
		end
	end
end
------

-- Slash Commands
	function core.AddSlashCommand(command, func)
		if not(command and func) then return end
		if GrandMail_SlashCmdList[command] then print("Debug: Command already exists") end
		GrandMail_SlashCmdList[string.lower(command)] = func
	end
	
	SLASH_GRANDMAIL_ADDON1 = "/grandmail"
	function SlashCmdList.GRANDMAIL_ADDON(msg)
		if not core.myRealm then
			print("\124cffcc0000"..L["CHOOSE_FACTION"])
			return
		end
	
		msg = string.lower(msg)
		if msg ~= "" then
			local args = {}
			local i, arg = 1
			repeat
				arg, msg= string.match(msg, "^([%-%+%a%d_]*) ?(.*)")
				print(string.format("\"%s\", \"%s\"", arg, msg))
				args[i] = arg
				i = i + 1
			until msg == ""
			
			if #args > 0 and GrandMail_SlashCmdList[args[1]] then
				GrandMail_SlashCmdList[args[1]](unpack(args, 2, #args))
			else
				for k,v in pairs(GrandMail_SlashCmdList) do
					print("/grandmail", k)
				end
			end
		else -- No arguments provided
			if MasterFrame:IsShown() then
				MasterFrame:Hide()
			else
				MasterFrame:Show()
			end
		end
	end
	
	GrandMail_OnAddonCompartmentClick = function(addonName, buttonName)
		if MasterFrame:IsShown() then
			MasterFrame:Hide()
		else
			MasterFrame:Show()
		end
	end
------

-- Functions
	local function PLAYER_LOGIN()
		if UnitFactionGroup("player") == "Neutral" then -- Damn pandas...
			UIErrorsFrame:AddExternalErrorMessage(L["CHOOSE_FACTION"])
			core.HookFunctionToEvent("NEUTRAL_FACTION_SELECT_RESULT", PLAYER_LOGIN)
			return
		end
		core.UnhookFunctionFromEvent("NEUTRAL_FACTION_SELECT_RESULT", PLAYER_LOGIN)
		
		--##########################################
		--####									####
		--####  DELETE THIS IN RELEASE VERSION  #### overrides print
		--####									####
		--##########################################
		if DEBUG then
			for i=1, NUM_CHAT_WINDOWS do
				if "Addon" == GetChatWindowInfo(i) then
					print = function(...)
						local t, str = {...},{}
						for i=1,#t do
							str[i] = tostring(t[i])
						end
						Chat_GetChatFrame(i):AddMessage(strjoin(" ", unpack(str))) end
					break
				end
			end
		end
		------
		
		local ADDON_VERSION = tonumber(GetAddOnMetadata("GrandMail", "Version")) -- Pull the version number from the .toc file
		
		if not KROZU_GRANDMAIL_DB then
			KROZU_GRANDMAIL_DB = {Version = ADDON_VERSION, Characters = {}, Orders = {}}
		end
		
		db, dbc = KROZU_GRANDMAIL_DB, KROZU_GRANDMAIL_DBC
		
		core.db = db
		core.dbc = dbc
		
		--core.myRealm = string.format("%s_%s" ,GetNormalizedRealmName(), UnitFactionGroup('player')) -- old
		core.myRealm = GetNormalizedRealmName()
		
		-- Cleanup for old versions
			if db.Version < ADDON_VERSION then
				if db.Version < 2 then
					-- Migrate Characters
					local newT = {}
					for rfName, data in pairs(db.Characters) do -- Update Realm names to no longer have faction association
						local realm, faction = rfName:match("^(%S+)_(%S+)$")
						newT[realm] = newT[realm] or {}
						for i, characterData in ipairs(data) do
							characterData.Faction = faction
							table.insert(newT[realm], characterData)
						end
						db.Characters[rfName] = nil
					end
					db.Characters = newT
					
					-- Migrate Orders
					newT = {}
					for rfName, realmData in pairs(db.Orders) do -- Update Realm names to no longer have faction association
						local realm = rfName:match("^(%S+)_")
						if newT[realm] then -- Already exists after migrating the other faction
							for orderCharacter, orderData in pairs(db.Orders[rfName]) do
								if newT[realm][orderCharacter] then -- Should only really happen for GLOBAL
									for i=1,#orderData do
										local orderName, orderData = orderData[i], orderData[orderData[i]]
										if newT[realm][orderCharacter][orderName] then
											orderName = orderName.."_1"
										end
										table.insert(newT[realm][orderCharacter], orderName)
										newT[realm][orderCharacter][orderName] = orderData
									end
								else
									newT[realm][orderCharacter] = orderData
								end
							end
						else
							newT[realm] = realmData
						end
						db.Orders[rfName] = nil
					end
					db.Orders = newT
				end
			
				db.Version = ADDON_VERSION
				print(string.format(L["ADDON_UPDATED"], addon))
			end
		------
		
		MasterFrame = core.MasterFrame
		CharactersFrame = core.CharactersFrame
		OrdersFrame = core.OrdersFrame
		
		MasterFrame:Init()
		CharactersFrame:Init()
		OrdersFrame:Init()
		core.SendFrame:Init()
		core.InfoFrame:Init()
	end

	local function OnEvent(_, event, ...)
		core.FireEvent(event, ...)
	end
------

-- Scripts
	EVENTFRAME:SetScript("OnEvent", OnEvent)
------

-- Events
	core.HookFunctionToEvent("PLAYER_LOGIN", PLAYER_LOGIN)
	
	-- core.HookFunctionToEvent("SECURE_TRANSFER_CANCEL", function() print("SECURE_TRANSFER_CANCEL") end)
------

-- Static Popup Boxes
	StaticPopupDialogs["GRANDMAIL_DELETE_CHARACTER"] = {
		text = L["DELETE_CHARACTER_CONFIRMATION"],
		button1 = DELETE,
		button2 = CANCEL,
		OnAccept = function(self, del, btn)
			for i,v in ipairs(db.Characters[core.myRealm]) do
				if v.Name == btn.CharacterName then
					table.remove(db.Characters[core.myRealm], i)
					break
				end
			end
			
			-- Remove this character from all orders
			local Orders = db.Orders[core.myRealm]
			if Orders then
				Orders[btn.CharacterName] = nil
				for _,CharacterOrders in pairs(Orders) do
					for i,Ordername in ipairs(CharacterOrders) do
						local Order = CharacterOrders[Ordername]
						for i,recip in ipairs(Order) do
							if recip == btn.CharacterName then
								table.remove(Order, i)
								Order[btn.CharacterName] = nil
							end
						end
					end
				end
			end
			
			local CharacterButtons = CharactersFrame.CharacterButtons
			for i=1,#CharacterButtons do
				if CharacterButtons[i] == btn then
					table.remove(CharacterButtons, i)
					break
				end
			end
			if core.GetSelectedCharacter() == btn then
				core.SetSelectedCharacter(false)
			end
			
			btn.CharacterName = nil
			btn.CharacterClass = nil
			core.ButtonPool:Release(btn)
			CharactersFrame:Refresh()
			del:Hide()
			core.State = "ORDER_OVERVIEW"
			OrdersFrame:Refresh()
		end,
		OnCancel = function()
			core.State = "ORDER_OVERVIEW"
		end,
		showAlert = false,
		timout = 0,
		hideOnEscape = true,
	}
	StaticPopupDialogs["GRANDMAIL_DELETE_ORDER"] = {
		text = L["DELETE_ORDER_CONFIRMATION"],
		button1 = DELETE,
		button2 = CANCEL,
		OnAccept = function(self, del, b)
			core.State = "ORDER_OVERVIEW"
			local SelectedCharacter = core.GetSelectedCharacter()
			SelectedCharacter = SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]
			local Orders = db.Orders[core.myRealm][SelectedCharacter]
			
			for i,v in ipairs(Orders) do
				if v == b.OrderName then
					table.remove(Orders, i)
					Orders[v] = nil
					break
				end
			end
			
			if #Orders == 0 then -- Character has no orders, delete character from the Orders db
				db.Orders[core.myRealm][SelectedCharacter] = nil
			end
			
			OrdersFrame:Refresh()
			del:Hide()
		end,
		OnCancel = function()
			core.State = "ORDER_OVERVIEW"
		end,
		showAlert = false,
		timout = 0,
		hideOnEscape = true,
	}
	StaticPopupDialogs["GRANDMAIL_DELETE_RECIPIENT"] = {
		text = L["DELETE_RECIPIENT_CONFIRMATION"],
		button1 = DELETE,
		button2 = CANCEL,
		OnAccept = function(self, del, btn)
			core.State = "ORDER_EDIT"
			local SelectedCharacter = core.GetSelectedCharacter(true)
			local Order = db.Orders[core.myRealm][SelectedCharacter and SelectedCharacter.CharacterName or L["GLOBAL"]][OrdersFrame.SelectedOrder]
			
			for i,v in ipairs(Order) do -- Find the specific order for this character
				if v == btn.Recipient then
					table.remove(Order, i)
					Order[v] = nil
					btn.Recipient = nil
					btn.EntryID = nil
					OrdersFrame:Refresh()
					del:Hide()
					break
				end
			end
		end,
		OnCancel = function()
			core.State = "ORDER_EDIT"
		end,
		showAlert = false,
		timout = 0,
		hideOnEscape = true,
	}
------