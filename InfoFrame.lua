local addon, core = ...
local L, MasterFrame = core.L, core.MasterFrame
local InfoFrame = CreateFrame("FRAME", "GrandMailMasterFrame", MasterFrame, "BackdropTemplate")
core.InfoFrame = InfoFrame

--[[================

	User Interface

==================]]

do -- InfoFrame
	InfoFrame:SetSize(655, 84)
	InfoFrame:SetBackdrop(core.defaultBackdrop)
	InfoFrame:SetBackdropColor(0, 0, 0, .3)
	InfoFrame:SetBackdropBorderColor(0, 0, 0, .5)
	
	function InfoFrame:Init()
		InfoFrame:SetPoint("BOTTOMLEFT", core.CharactersFrame, "BOTTOMRIGHT", 4, 0)
		InfoFrame:SetPoint("TOPRIGHT", core.OrdersFrame, "BOTTOMRIGHT", 0, -4)
	end
	function InfoFrame:SetCharacter(character)
		if character then
			self.Character:SetText(CHARACTER..": "..character)
		else
			self.Character:SetText("")
		end
	end
	function InfoFrame:SetOrder(order)
		if order then
			self.Order:SetText(L["ORDER_NAME"]..": "..order)
		else
			self.Order:SetText(L["ORDER_NAME"]..": /")
		end
	end
	function InfoFrame:SetRecipient(recip)
		if recip then
			self.Recipient:SetText(L["RECIPIENT"]..": "..recip)
		else
			self.Recipient:SetText(L["RECIPIENT"]..": /")
		end
	end

 -- Character Fontstring
	InfoFrame.Character = InfoFrame:CreateFontString()
	InfoFrame.Character:SetPoint("TOPLEFT", InfoFrame, "TOPLEFT", 16, -14)
	InfoFrame.Character:SetTextColor(1, 1, 1, 1)
	InfoFrame.Character:SetFont(core.fontPath, 16, "")
	InfoFrame.Character:SetText(CHARACTER..": GLOBAL")

 -- Order Fontstring
	InfoFrame.Order = InfoFrame:CreateFontString()
	InfoFrame.Order:SetPoint("TOPLEFT", InfoFrame.Character, "BOTTOMLEFT", 0, -14)
	InfoFrame.Order:SetTextColor(1, 1, 1, 1)
	InfoFrame.Order:SetFont(core.fontPath, 16, "")
	InfoFrame.Order:SetText(L["ORDER_NAME"]..": /")

 -- Recipient Fontstring
	InfoFrame.Recipient = InfoFrame:CreateFontString()
	InfoFrame.Recipient:SetPoint("TOPLEFT", InfoFrame.Order, "BOTTOMLEFT", 0, -14)
	InfoFrame.Recipient:SetTextColor(1, 1, 1, 1)
	InfoFrame.Recipient:SetFont(core.fontPath, 16, "")
	InfoFrame.Recipient:SetText(L["RECIPIENT"]..": /")
end
