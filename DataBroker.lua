------------------------------------------------------------
-- PlayedTime by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, addon = ...;

local LibDataBroker = LibStub("LibDataBroker-1.1");
local LibQTip       = LibStub("LibQTip-1.0");

local MODULE_ICON       = "Interface\\Icons\\Achievement_ChallengeMode_BlackRockDepot_Hourglass";
local TEX_MODULE_ICON   = ("|T%s:14:14:0:0|t"):format(MODULE_ICON);

local name = "PlayedTime";
local settings = {
	type = "data source",
	label = "PlayedTime",
	text = "",
	icon = MODULE_ICON,
	OnClick = function(frame, button)
		addon:BrokerOnClick(frame, button);
	end,
	OnEnter = function(frame)
		if(addon.tooltipAnchor) then return end
		addon.tooltipAnchor = frame;
		
		addon.tooltip = LibQTip:Acquire("PlayedTimeBrokerTooltip", 2, "LEFT", "RIGHT");
		addon.tooltip:SetFrameStrata("TOOLTIP");
		addon.tooltip:EnableMouse(true);
		
		addon.tooltip.OnRelease = function()
			addon.tooltipAnchor = nil;
		end
		
		addon:BrokerOnEnter(frame, addon.tooltip);
	end,
	OnLeave = function(frame)
		addon:BrokerOnLeave(frame, addon.tooltip);
		-- addon.tooltipAnchor = nil;
	end,
};

function addon:InitDataBroker()
	addon.broker = LibDataBroker:NewDataObject(name, settings);
	addon.UpdateText();
end

function addon:BrokerOnClick(frame, button)
	if(button == "RightButton") then
		addon.tooltip:Release();
		addon:OpenContextMenu(frame, addon:GetMenuData());
	end
end

function addon:UpdateOpenTooltip()
	if(not addon.tooltipAnchor) then return end
	addon:BrokerOnEnter(addon.tooltipAnchor, addon.tooltip);
end

function addon:PrepareTooltipData()
	local tooltipdata = {};
	
	local _, playerRealm, playerFaction, playerName = addon:GetPlayerInformation();
	
	tooltipdata.totalTimePlayed = 0;
	tooltipdata.currentRealm = {
		timePlayed = 0,
		characters = {},
	};
	
	tooltipdata.realms = {};
	tooltipdata.hiddenCharacters = {
		timePlayed = 0,
		characters = {},
	};
	
	-----------------------------------------
	-- Current Character
	do
		local data = addon:GetPlayerData();
		
		tooltipdata.currentCharacter = {
			name = playerName,
			realm = playerRealm,
			faction = playerFaction,
			data = data,
		};
		
		tooltipdata.totalTimePlayed = tooltipdata.totalTimePlayed + data.totalTime;
		tooltipdata.currentRealm.timePlayed = tooltipdata.currentRealm.timePlayed + data.totalTime; 
	end
	
	-----------------------------------------
	-- Current Connected Realm
	local connectedRealms = addon:GetConnectedRealms();
	
	do
		for _, realm in pairs(connectedRealms) do
			local realmData = self.db.global.realms[realm];
			
			for faction, characters in pairs(realmData) do
				for name, data in pairs(characters) do
					if(realm ~= playerRealm or name ~= playerName) then
						local charInfo = {
							name = name,
							faction = faction,
							realm = realm,
							data = data,
						};
						
						if(not data.hidden) then
							tinsert(tooltipdata.currentRealm.characters, charInfo);
							tooltipdata.currentRealm.timePlayed = tooltipdata.currentRealm.timePlayed + data.totalTime;
						else
							tinsert(tooltipdata.hiddenCharacters.characters, charInfo);
							tooltipdata.hiddenCharacters.timePlayed = tooltipdata.hiddenCharacters.timePlayed + data.totalTime;
						end
				
						tooltipdata.totalTimePlayed = tooltipdata.totalTimePlayed + data.totalTime;
					end
				end
			end
		end
		
		table.sort(tooltipdata.currentRealm.characters, function(a, b)
			if(a == nil and b == nil) then return false end
			if(a == nil) then return true end
			if(b == nil) then return false end
			
			return a.data.totalTime > b.data.totalTime;
		end);
	end
	
	-----------------------------------------
	-- Other realms
	for realm, realmData in pairs(self.db.global.realms) do
		local realmIsConnected = false;
		for _, connectedRealm in pairs(connectedRealms) do
			if(realm == connectedRealm) then
				realmIsConnected = true;
				break;
			end
		end
		
		if(not realmIsConnected) then
			local realmInfo = {
				realm = realm,
				timePlayed = 0,
				characters = {},
			}
			
			for faction, characters in pairs(realmData) do
				for name, data in pairs(characters) do
					local charInfo = {
						name = name,
						faction = faction,
						realm = realm,
						data = data,
					};
					
					if(not data.hidden) then
						tinsert(realmInfo.characters, charInfo);
						realmInfo.timePlayed = realmInfo.timePlayed + data.totalTime;
					else
						tinsert(tooltipdata.hiddenCharacters.characters, charInfo);
						tooltipdata.hiddenCharacters.timePlayed = tooltipdata.hiddenCharacters.timePlayed + data.totalTime;
					end
			
					tooltipdata.totalTimePlayed = tooltipdata.totalTimePlayed + data.totalTime;
				end
			end
			
			if(#realmInfo.characters > 0) then
				tinsert(tooltipdata.realms, realmInfo);
				
				table.sort(realmInfo.characters, function(a, b)
					if(a == nil and b == nil) then return false end
					if(a == nil) then return true end
					if(b == nil) then return false end
					
					return a.data.totalTime > b.data.totalTime;
				end);
			end
		end
	end
	
	table.sort(tooltipdata.hiddenCharacters.characters, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.data.totalTime > b.data.totalTime;
	end);
	
	table.sort(tooltipdata.realms, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.timePlayed > b.timePlayed;
	end);
	
	return tooltipdata;
end

function addon:UnpackCharacterInfo(charInfo)
	return charInfo.name, charInfo.realm, charInfo.faction, charInfo.data;
end

function addon:BrokerOnEnter(frame, tooltip)
	tooltip:Clear();
	tooltip:SetClampedToScreen(true);
	
	tooltip:AddHeader(TEX_MODULE_ICON .. " |cffffdd00Played|cffffffffTime|r");
	tooltip:AddLine(" ");
	
	local tooltipdata = addon:PrepareTooltipData();
	
	do
		local name, realm, faction, data = addon:UnpackCharacterInfo(tooltipdata.currentCharacter);
		local color = addon:GetCharacterColor(name);
		
		local classIcon = addon:GetClassIconString(data.class);
		local factionIcon = addon.db.global.ShowFactions and addon:GetFactionIconString(faction) or "";
		
		tooltip:AddLine(
			("%s%s |c%s%s|r |cffffffff(%d)|r"):format(factionIcon, classIcon, color, name, data.level),
			addon:FormatTime(data.totalTime, addon.db.global.UseShort)
		);
		
		tooltip:AddLine(
			"|cffffd200Time on this level|r",
			addon:FormatTime(data.levelTime, addon.db.global.UseShort)
		);
	end
	
	do
		for _, charInfo in ipairs(tooltipdata.currentRealm.characters) do
			local name, realm, faction, data = addon:UnpackCharacterInfo(charInfo);
			
			local fullname = addon:FormatName(name .. "-" .. realm);
			local color = addon:GetCharacterColor(name, realm, faction);
			
			local classIcon = addon:GetClassIconString(data.class);
			local factionIcon = addon.db.global.ShowFactions and addon:GetFactionIconString(faction) or "";
			
			local lineIndex = tooltip:AddLine(
				("%s%s |c%s%s|r |cffffffff(%d)|r"):format(factionIcon, classIcon, color, fullname, data.level),
				addon:FormatTime(data.totalTime, addon.db.global.UseShort)
			);
				
			addon:AddTooltipCharacterScripts(tooltip, lineIndex, name, realm, faction);
		end
	end
	
	if(#tooltipdata.currentRealm.characters > 1) then
		tooltip:AddLine(
			"|cffacee44Realm total|r",
			addon:FormatTime(tooltipdata.currentRealm.timePlayed, addon.db.global.UseShort)
		);
	end
	
	for _, realmInfo in ipairs(tooltipdata.realms) do
		local realm = realmInfo.realm;
		
		local isExpanded = self.db.global.expandedRealms[realm];
		
		local lineIndex = tooltip:AddLine(
			("|cffffd200%s|r (%d)"):format(realm, #realmInfo.characters),
			addon:FormatTime(realmInfo.timePlayed, addon.db.global.UseShort)
		);
		
		if(isExpanded) then
			tooltip:AddSeparator();
		end
		
		tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
			if(button == "LeftButton") then
				addon.db.global.expandedRealms[realm] = not addon.db.global.expandedRealms[realm];
				addon:UpdateOpenTooltip();
			end
		end);
		
		for _, charInfo in ipairs(realmInfo.characters) do
			local name, realm, faction, data = addon:UnpackCharacterInfo(charInfo);
			
			local color = addon:GetCharacterColor(name, realm, faction);
			local classIcon = addon:GetClassIconString(data.class);
			local factionIcon = addon.db.global.ShowFactions and FACTION_ICONS[faction] or "";
			
			local lineIndex = tooltip:AddLine(
				("%s%s |c%s%s|r |cffffffff(%d)|r"):format(factionIcon, classIcon, color, name, data.level),
				addon:FormatTime(data.totalTime, addon.db.global.UseShort)
			);
			
			addon:AddTooltipCharacterScripts(tooltip, lineIndex, name, realm, faction);
		end
	end
	
	tooltip:AddLine(" ");
	tooltip:AddSeparator();
	tooltip:AddLine("|cffacee44Total time played|r", addon:FormatTime(totalTimePlayed, addon.db.global.UseShort));
	
	tooltip:SetAutoHideDelay(0.02, frame);
	
	local point, relative = addon:GetAnchors(frame);
	tooltip:ClearAllPoints();
	tooltip:SetPoint(point, frame, relative, 0, 0);
	
	tooltip:Show();
end

function addon:AddTooltipCharacterScripts(tooltip, lineIndex, name, realm, faction)
	if(not tooltip or not lineIndex or not name or not realm or not faction) then return end
	
	local data = self.db.global.realms[realm][faction][name];
	local classIcon = addon:GetClassIconString(data.class);
	
	tooltip:SetLineScript(lineIndex, "OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_NONE");
		
		local point, relativePoint, offset = addon:GetHorizontalAnchors(self);
		GameTooltip:SetPoint(point, self, relativePoint, 7 * offset, 0);
		
		local color = addon:GetClassColor(data.class);
		
		GameTooltip:AddLine(("%s |c%s%s|r |cffffffff(%s)|r"):format(classIcon, color.colorStr, name, realm));
		GameTooltip:AddLine(("Level |cffffffff%d|r |c%s%s|r"):format(data.level, color.colorStr, addon:GetLocalizedClassName(data.class)));
		GameTooltip:AddLine(" ");
		
		GameTooltip:AddDoubleLine("Total time played", addon:FormatTime(data.totalTime, addon.db.global.UseShort));
		if(data.levelTime > 0) then
			GameTooltip:AddDoubleLine("Time on current level", addon:FormatTime(data.levelTime, addon.db.global.UseShort));
		end
		
		GameTooltip:AddLine(" ");
		if(not data.hidden) then
			GameTooltip:AddDoubleLine("|cff00ff00Ctrl Left-Click", "|cffffffffHide character");
		else
			GameTooltip:AddDoubleLine("|cff00ff00Ctrl Left-Click", "|cffffffffUnhide character");
		end
		GameTooltip:AddDoubleLine("|cff00ff00Ctrl Right-Click", "|cffffffffDelete character");
		
		GameTooltip:Show();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnLeave", function(self)
		GameTooltip:Hide();
	end);
	
	tooltip:SetLineScript(lineIndex, "OnMouseUp", function(self, _, button)
		if(button == "LeftButton" and IsControlKeyDown()) then
			addon:ToggleHideForCharacter(name, realm, faction);
			addon:UpdateOpenTooltip();
		end
		
		if(button == "RightButton" and IsControlKeyDown()) then
			addon:DeleteCharacter(name, realm, faction);
			addon:UpdateOpenTooltip();
		end
	end);
end

function addon:BrokerOnLeave(frame, tooltip)
	
end

function addon:UpdateText()
	local playerData = addon:GetPlayerData();
	if(playerData.totalTime and playerData.totalTime > 0) then
		addon.broker.text = addon:FormatTime(playerData.totalTime, addon.db.global.ShortBroker);
	else
		addon.broker.text = "Played|cffffdd00Time|r";
	end
end

function addon:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if(y < _G.GetScreenHeight() / 2) then
		return B, T;
	else
		return T, B;
	end
end

function addon:GetHorizontalAnchors(frame)
	local R, L = "RIGHT", "LEFT";
	local x, y = frame:GetCenter();
	
	if(x < _G.GetScreenWidth() / 2) then
		return L, R, 1;
	else
		return R, L, -1;
	end
end

local DAY_ABBR  = string.gsub(DAY_ONELETTER_ABBR, "%%d%s*", "");
local HOUR_ABBR = string.gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
local MIN_ABBR  = string.gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", "");
local SEC_ABBR  = string.gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local DHMS = string.format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local  HMS = string.format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local   MS = string.format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
local    S = string.format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

local DH   = string.format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR)
local  HM  = string.format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR)

function addon:FormatTime(time, short)
	if(not time) then return end
	time = math.floor(time);
	
	local d, h, m, s;
	
	if(not addon.db.global.ShowHours) then
		d = math.floor(time / 86400);
		h = math.floor((time % 86400) / 3600);
	else
		d = 0;
		h = math.floor(time / 3600);
	end
	
	m = math.floor((time % 3600) / 60);
	s = math.floor(time % 60);
	
	if(d > 0) then
		return short and string.format(DH, d, h) or string.format(DHMS, d, h, m, s)
	elseif(h > 0) then
		return short and string.format(HM, h, m) or string.format(HMS, h, m ,s)
	elseif(m > 0) then
		return string.format(MS, m, s)
	else
		return string.format(S, s)
	end
end

local contextmenu;
function addon:OpenContextMenu(frame, menudata)
	if(not menudata) then return end
	
	if(not contextmenu) then
		contextmenu = CreateFrame("Frame", ADDON_NAME .. "ContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local point, relative = addon:GetAnchors(frame);
	
	contextmenu:ClearAllPoints();
	contextmenu:SetPoint(point, frame, relative, 0, 0);
	EasyMenu(menudata, contextmenu, frame or "CURSOR", 0, 0, "MENU", 5);
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, frame, relative, 0, 0);
	DropDownList1:SetClampedToScreen(true);
end

function addon:GetMenuData()
	local data = {
		{
			text = "Played|cffffffffTime|r", isTitle = true, notCheckable = true,
		},
		{
			text = "Show hours instead of days",
			func = function()
				addon.db.global.ShowHours = not addon.db.global.ShowHours;
				addon:UpdateText();
				CloseMenus();
			end,
			checked = function()
				return addon.db.global.ShowHours;
			end,
			isNotRadio = true,
		},
		{
			text = "Use short time stamps",
			func = function()
				addon.db.global.UseShort = not addon.db.global.UseShort;
				addon:UpdateText();
				CloseMenus();
			end,
			checked = function()
				return addon.db.global.UseShort;
			end,
			isNotRadio = true,
		},
		{
			text = "Show long time stamp on Broker",
			func = function()
				addon.db.global.ShortBroker = not addon.db.global.ShortBroker;
				addon:UpdateText();
				CloseMenus();
			end,
			checked = function()
				return addon.db.global.ShortBroker;
			end,
			isNotRadio = true,
		},
		{
			text = "Show faction icons",
			func = function()
				addon.db.global.ShowFactions = not addon.db.global.ShowFactions;
				addon:UpdateText();
				CloseMenus();
			end,
			checked = function()
				return addon.db.global.ShowFactions;
			end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Close",
			func = function()
				CloseMenus();
			end,
			notCheckable = true,
		},
	};
	
	return data;
end
