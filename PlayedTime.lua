------------------------------------------------------------
-- PlayedTime by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0");
_G[ADDON_NAME] = addon;

local LibExtraTip = LibStub("LibExtraTip-1");

local SAVEDVARS = {
	global = {
		ShowHours = false,
		UseShort = false,
		ShortBroker = true,
		ShowFactions = false,
		
		["realms"] = {
			["*"] = { -- Realm
				["*"] = { -- Faction
					["*"] = { -- Character
						["class"]        = nil,
						["level"]        = 0,
						["gender"]       = 2,
						
						["totalTime"]    = 0,
						["levelTime"]    = 0,
						
						["hidden"]       = false,
					},
				},
			},
		},
		["expandedRealms"] = {
			["*"] = false,
		},
	},
};

function addon:CopyOldData()
	if(not PlayedTimeOldData) then
		error("Old data not found");
		return
	end
	
	for realm, realmData in pairs(PlayedTimeOldData) do
		for faction, characters in pairs(realmData) do
			for name, data in pairs(characters) do
				if(not self.db.global.realms[realm][faction][name].class) then
					self.db.global.realms[realm][faction][name].class = data.class;
					self.db.global.realms[realm][faction][name].totalTime = data.timePlayed;
					self.db.global.realms[realm][faction][name].level = data.level;
				end
			end
		end
	end
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PlayedTimeDB", SAVEDVARS);
	
	-- addon:CopyOldData();
end

function addon:OnEnable()
	self:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT");
	self:RegisterEvent("TIME_PLAYED_MSG");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	
	addon:UpdateTimePlayed();
	
	-- Set ticker to update played time every half an hour
	C_Timer.NewTicker(1800, function()
		addon:UpdateTimePlayed();
	end);
	
	CreateFrame("frame"):SetScript("OnUpdate", function(self, elapsed)
		addon:OnUpdate(elapsed);
	end);
	
	local playerData = addon:GetPlayerData();
	
	local _, class = UnitClass("player");
	playerData.class = class;
	playerData.level = UnitLevel("player");
	playerData.gender = UnitSex("player");
	
	addon:InitDataBroker();
end

function addon:GetLocalizedClassName(class, gender)
	if(gender == 3) then
		return LOCALIZED_CLASS_NAMES_FEMALE[class];
	end
	
	return LOCALIZED_CLASS_NAMES_MALE[class];
end

local BlizzardOriginalChatFrame_DisplayTimePlayed = ChatFrame_DisplayTimePlayed;
ChatFrame_DisplayTimePlayed = function(...)
	if(addon.UpdatingPlayedTime) then
		addon.UpdatingPlayedTime = false;
		return;
	end
	
	return BlizzardOriginalChatFrame_DisplayTimePlayed(...);
end

function addon:UpdateTimePlayed()
	addon.UpdatingPlayedTime = true;
	RequestTimePlayed();
end

function addon:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	if(self.elapsed >= 1.0) then
		local playerData = addon:GetPlayerData();
		playerData.totalTime = playerData.totalTime + self.elapsed;
		playerData.levelTime = playerData.levelTime + self.elapsed;
		
		self.elapsed = 0;
		
		-- Update tooltip while open
		addon:UpdateOpenTooltip();
		
		addon:UpdateText();
	end
end

local MESSAGE_PATTERN = "|cff2dbcffPlayedTime|r %s";
function addon:AddMessage(pattern, ...)
	DEFAULT_CHAT_FRAME:AddMessage(MESSAGE_PATTERN:format(string.format(pattern, ...)), 1, 1, 1);
end

function addon:TIME_PLAYED_MSG(event, totalTime, levelTime)
	local playerData = addon:GetPlayerData();
	playerData.totalTime = totalTime;
	playerData.levelTime = levelTime;
end

function addon:PLAYER_LEVEL_UP(event, newLevel)
	local playerData = addon:GetPlayerData();
	playerData.level = newLevel;
end

function addon:NEUTRAL_FACTION_SELECT_RESULT()
	local realm   = addon:GetHomeRealm();
	local faction = UnitFactionGroup("player");
	local name    = addon:GetPlayerName();
	
	self.db.global.realms[realm][faction][name] = self.db.global.realms[realm]["Neutral"][name];
	self.db.global.realms[realm]["Neutral"][name] = nil;
end

function addon:GetClassIconString(class, size)
	if(not class) then return end
	local size = size or 10;
	
	local left, right, top, bottom = unpack(CLASS_ICON_TCOORDS[class]);
	left = left * 256 + 4;
	right = right * 256 - 4;
	top = top * 256 + 4;
	bottom = bottom * 256 - 4;
	
	return string.format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:%d:%d:0:-1:256:256:%d:%d:%d:%d|t", size, size, left, right, top, bottom);
end

local FACTION_ICONS = {
	Alliance  = [[|TInterface\BattlefieldFrame\Battleground-Alliance:%d:%d:0:0:32:32:4:26:4:27|t ]],
	Horde     = [[|TInterface\BattlefieldFrame\Battleground-Horde:%d:%d:0:0:32:32:5:25:5:26|t ]],
	Neutral   = [[|TInterface\Timer\Panda-Logo:%d:%d:0:0|t ]],
};

function addon:GetFactionIconString(faction, size)
	local size = size or 10;
	return FACTION_ICONS[faction]:format(size, size);
end

function addon:ToggleHideForCharacter(name, realm, faction)
	if(not name or not realm or not faction) then return false end
	self.db.global.realms[realm][faction][name].hidden = not self.db.global.realms[realm][faction][name].hidden;
	
	if(self.db.global.realms[realm][faction][name].hidden) then
		addon:AddMessage("%s-%s is now hidden.", name, realm);
	else
		addon:AddMessage("%s-%s is now unhidden.", name, realm);
	end
	
	return true;
end

function addon:DeleteCharacter(name, realm, faction)
	if(not name or not realm or not faction) then return false end
	
	addon:AddMessage("%s-%s was deleted from the database.", name, realm);
	self.db.global.realms[realm][faction][name] = nil;
	
	return true;
end

function addon:GetClassColor(class)
	return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or 'PRIEST'];
end

function addon:GetPlayerName(withRealm)
	local name, realm = UnitFullName("player");
	if(withRealm) then
		return table.concat({n, s}, "-");
	end
	
	return name;
end

function addon:GetHomeRealm()
	local name = string.gsub(GetRealmName(), " ", "");
	return name;
end

function addon:GetConnectedRealms()
	local realms = GetAutoCompleteRealms();
	
	if(realms) then
		return realms;
	else
		return { addon:GetHomeRealm() };
	end
end

function addon:GetConnectedRealmsName()
	return table.concat(addon:GetConnectedRealms(), "-");
end

function addon:GetPlayerInformation()
	local connectedRealm  = addon:GetConnectedRealmsName();
	local homeRealm       = addon:GetHomeRealm();
	local playerFaction   = UnitFactionGroup("player");
	local playerName      = addon:GetPlayerName();
	
	return connectedRealm, homeRealm, playerFaction, playerName;
end

function addon:GetRealmData()
	local realm   = addon:GetHomeRealm();
	local faction = faction or UnitFactionGroup("player");
	local name    = addon:GetPlayerName();
	
	return self.db.global.realms[realm][faction][name];
end

function addon:GetPlayerData(faction)
	local realm   = addon:GetHomeRealm();
	local faction = faction or UnitFactionGroup("player");
	local name    = addon:GetPlayerName();
	
	return self.db.global.realms[realm][faction][name];
end

function addon:ParseName(name)
	if(not name) then return end
	
	local name, realm = string.split("-", name, 2);
	realm = realm or addon:GetHomeRealm();
	return name, realm;
end

function addon:FormatName(name)
	if(not name) then return end
	
	local name, realm = addon:ParseName(name);
	if(realm == addon:GetHomeRealm()) then
		return name;
	end
	
	return string.format("%s|cff999999-%s|r", name, string.sub(realm, 1, 3));
end

function addon:GetCharacterColor(name, realm, faction)
	local faction = faction or UnitFactionGroup("player");
	
	local class = "PRIEST";
	local name, parsedRealm = addon:ParseName(name);
	local realm = realm or parsedRealm;
	if(name) then
		local data = self.db.global.realms[realm][faction][name];
		class = data.class;
	end
	
	return addon:GetClassColor(class).colorStr;
end
