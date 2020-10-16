local SorhaQuestLog = LibStub("AceAddon-3.0"):GetAddon("SorhaQuestLog")
local L = LibStub("AceLocale-3.0"):GetLocale("SorhaQuestLog")
local MODNAME = "QuestTracker"
local QuestTracker = SorhaQuestLog:NewModule(MODNAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "LibSink-2.0")
SorhaQuestLog.QuestTracker = QuestTracker

local LibToast = LibStub("LibToast-1.0", true)
LibToast:Embed(SorhaQuestLog)


local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local MSQ = LibStub("Masque", true)

local fraMinionAnchor = nil
local blnMinionInitialized = false
local blnMinionUpdating = false

local strButtonPrefix = MODNAME .. "Button"
local strItemButtonPrefix = MODNAME .. "ItemButton"
local intNumberUsedButtons = 0
local intNumberOfItemButtons = 0

local tblButtonCache = {}
local tblItemButtonCache = {}
local tblUsingButtons = {}
local tblUsedItemButtons = {}

local strMinionTitleColour = "|cffffffff"
local strInfoColour = "|cffffffff"
local strHeaderColour = "|cffffffff"
local strQuestTitleColour = "|cffffffff"
local strObjectiveTitleColour = "|cffffffff"
local strObjectiveDescriptionColour = "|cffffffff"
local strQuestStatusFailed = "|cffffffff"
local strQuestStatusDone = "|cffffffff"
local strQuestStatusGoto = "|cffffffff"
local strQuestLevelColour = "|cffffffff"
local strObjectiveStatusColour = "|cffffffff"
local strObjective00Colour = "|cffffffff"
local strObjective01to24Colour = "|cffffffff"
local strObjective25to49Colour = "|cffffffff"
local strObjective50to74Colour = "|cffffffff"
local strObjective75to99Colour = "|cffffffff"
local strObjective100Colour = "|cffffffff"
local strUndoneColour = "|cffffffff"
local strDoneColour = "|cffffffff"
local strObjectiveTooltipTextColour = "|cffffffff"

local intItemButtonSize = 26
local bonusObjectivesZoneTitle = L['Bonus Objectives'];
local bonusObjectivesZoneID = 'Bonus Objectives';
local worldQuestsZoneTitle = TRACKER_HEADER_WORLD_QUESTS;
local worldQuestsZoneID = 'World Quests';
local campaignZoneID = 'Campaign Objectives';

--player info
local playerMoney = 0;
local tblPOIs = {};

-- Tables
local tblBagsToCheck = {}
local tblHaveQuestItems = {}

local blnWasAClick = false -- Was QUEST_LOG_UPDATE called by a click on a header etc
local blnIgnoreUpdateEvents = false -- Ignores QLU events, used when making large scale collapse/expands to log
local blnFirstUpdate = true -- Was first update of quest log, no old data will be on store yet
local blnFirstBagCheck = true

local blnBagCheckUpdating = false
local blnHaveRegisteredBagUpdate = false


-- Strings used to store current location for auto collapse/expand
local strZone = ""
local strSubZone = ""

local curQuestInfo = nil -- Questlog data stores
local intTimeOfLastSound = 0 -- Time last sound played
local timeOfProximityCheck = 0
local timeOfFirstQuestUpdate = 0;

local LEFT_CLICK = "LEFT_CLICK";
local LEFT_ALT_CLICK = "LEFT_ALT_CLICK";
local LEFT_ALT_CTRL_CLICK = "LEFT_ALT_CTRL_CLICK";
local LEFT_ALT_SHIFT_CLICK = "LEFT_ALT_SHIFT_CLICK";
local LEFT_CTRL_CLICK = "LEFT_CTRL_CLICK";
local LEFT_CTRL_SHIFT_CLICK = "LEFT_CTRL_SHIFT_CLICK";
local LEFT_SHIFT_CLICK = "LEFT_SHIFT_CLICK";
local RIGHT_CLICK = "RIGHT_CLICK";
local RIGHT_ALT_CLICK = "RIGHT_ALT_CLICK";
local RIGHT_ALT_CTRL_CLICK = "RIGHT_ALT_CTRL_CLICK";
local RIGHT_ALT_SHIFT_CLICK = "RIGHT_ALT_SHIFT_CLICK";
local RIGHT_CTRL_CLICK = "RIGHT_CTRL_CLICK";
local RIGHT_CTRL_SHIFT_CLICK = "RIGHT_CTRL_SHIFT_CLICK";
local RIGHT_SHIFT_CLICK = "RIGHT_SHIFT_CLICK";
local HEADER_BUTTON = "HEADER_BUTTON";
local QUEST_BUTTON = "QUEST_BUTTON";


local tmpQuest = nil;
local btnSearchQuestsClick = 1;
local btnSearchQuests = nil;

-- Matching quest completion outputs
local function getPattern(strPattern)
	strPattern = string.gsub(strPattern, "%(", "%%%1")
	strPattern = string.gsub(strPattern, "%)", "%%%1")
	strPattern = string.gsub(strPattern, "%%%d?$?.", "(.+)")
	return format("^%s$", strPattern)
end

local tblQuestMatchs = {
	["Found"] = getPattern(ERR_QUEST_ADD_FOUND_SII),
	["Item"] = getPattern(ERR_QUEST_ADD_ITEM_SII),
	["Kill"] = getPattern(ERR_QUEST_ADD_KILL_SII),
	["PKill"] = getPattern(ERR_QUEST_ADD_PLAYER_KILL_SII),
	["ObjectiveComplete"] = getPattern(ERR_QUEST_OBJECTIVE_COMPLETE_S),
	["QuestComplete"] = getPattern(ERR_QUEST_COMPLETE_S),
	["QuestFailed"] = getPattern(ERR_QUEST_FAILED_S),
}

local tblZoneClickBindings = {
	["LEFT_CLICK"] = nil,
	["LEFT_ALT_CLICK"] = nil,
	["LEFT_ALT_CTRL_CLICK"] = nil,
	["LEFT_CTRL_CLICK"] = nil,
	["LEFT_SHIFT_CLICK"] = nil,
	["RIGHT_CLICK"] = nil,	
}

local tblQuestClickBindings = {
	["LEFT_CLICK"] = nil,
	["LEFT_ALT_CLICK"] = nil,
	["LEFT_ALT_CTRL_CLICK"] = nil,
	["LEFT_CTRL_CLICK"] = nil,
	["LEFT_SHIFT_CLICK"] = nil,
	["RIGHT_CLICK"] = nil,	
	["RIGHT_SHIFT_CLICK"] = nil,
}

-- Tables used for quest tags (Group, Elite etc)
local dicQuestTags = {
	[ELITE] = "+",
	[Enum.QuestTag.Group] = "g",
	[Enum.QuestTag.Pvp] = "p",
	[Enum.QuestTag.Raid] = "r",
	[Enum.QuestTag.Raid10] = "r",
	[Enum.QuestTag.Raid25] = "r",
	[Enum.QuestTag.Dungeon] = "d",
	[Enum.QuestTag.Heroic] = "d+",
	[Enum.QuestTag.Scenario] = "s",
	[Enum.QuestTag.Account] = "a",
	["Daily"] = "*",
	["Weekly"] = "**",
}

local dicLongQuestTags = {
	[ELITE] = ELITE,
	[Enum.QuestTag.Group] = GROUP,
	[Enum.QuestTag.Pvp] = PVP,
	[Enum.QuestTag.Raid] = RAID,
	[Enum.QuestTag.Raid10] = RAID,
	[Enum.QuestTag.Raid25] = RAID,
	[Enum.QuestTag.Dungeon] = LFG_TYPE_DUNGEON,
	[Enum.QuestTag.Heroic] = PLAYER_DIFFICULTY2,
	[Enum.QuestTag.Scenario] = TRACKER_HEADER_SCENARIO,
	[Enum.QuestTag.Account] = L["Account"],
	["Daily"] = DAILY,
	["Weekly"] = WEEKLY,
}

local dicRepLevels = {
	["Hated"] = {["MTitle"] = FACTION_STANDING_LABEL1, ["FTitle"] = FACTION_STANDING_LABEL1_FEMALE, ["Value"] = 1.00},
	["Hostile"] = {["MTitle"] = FACTION_STANDING_LABEL2, ["FTitle"] = FACTION_STANDING_LABEL2_FEMALE, ["Value"] = 1.30},
	["Unfriendly"] = {["MTitle"] = FACTION_STANDING_LABEL3, ["FTitle"] = FACTION_STANDING_LABEL3_FEMALE, ["Value"] = 1.70},
	["Neutral"] = {["MTitle"] = FACTION_STANDING_LABEL4, ["FTitle"] = FACTION_STANDING_LABEL4_FEMALE, ["Value"] = 2.20},
	["Friendly"] = {["MTitle"] = FACTION_STANDING_LABEL5, ["FTitle"] = FACTION_STANDING_LABEL5_FEMALE, ["Value"] = 2.85},
	["Honored"] = {["MTitle"] = FACTION_STANDING_LABEL6, ["FTitle"] = FACTION_STANDING_LABEL6_FEMALE, ["Value"] = 3.71},
	["Revered"] = {["MTitle"] = FACTION_STANDING_LABEL7, ["FTitle"] = FACTION_STANDING_LABEL7_FEMALE, ["Value"] = 4.82},
	["Exalted"] = {["MTitle"] = FACTION_STANDING_LABEL8, ["FTitle"] = FACTION_STANDING_LABEL8_FEMALE, ["Value"] = 6.27},
}

--options table helpers
local dicQuestSortOrder = {
	["Default"] = DEFAULT,
	["Title"] = L["Title"],
	["Level"] = LEVEL,
	["POI"] = MINIMAP_TRACKING_POI,
	["Proximity"] = TRACKER_SORT_PROXIMITY,
	["Completion"] = TUTORIAL_TITLE34,
}

local dicOutlines = {
	[""] = NONE,
	["OUTLINE"] = L["Outline"],
	["THICKOUTLINE"] = L["Thick Outline"],
	["MONOCHROMEOUTLINE"] = L["Monochrome Outline"],
}

local dicQuestTitleColourOptions = {
	["Custom"] = CUSTOM,
	["Level"] = LEVEL,
	["Completion"] = TUTORIAL_TITLE34,
	["Done/Undone"] = L["Done/Undone"],
}

local dicObjectiveColourOptions = {
	["Custom"] = CUSTOM,
	["Done/Undone"] = L["Done/Undone"],
	["Completion"] = TUTORIAL_TITLE34,
}

local dicNotificationColourOptions = {
	["Custom"] = CUSTOM,
	["Completion"] = TUTORIAL_TITLE34,
}

local dicKeybinds = {
	["LEFT_CLICK"] = L["Left Click"],
	["LEFT_ALT_CLICK"] = L["Left Alt Click"],
	["LEFT_ALT_CTRL_CLICK"] = L["Left Alt+Ctrl Click"],
	--["LEFT_ALT_SHIFT_CLICK"] = L["Left Alt+Shift Click"],
	["LEFT_CTRL_CLICK"] = L["Left Ctrl Click"],
	--["LEFT_CTRL_SHIFT_CLICK"] = L["Left Ctrl+Shift Click"],
	["LEFT_SHIFT_CLICK"] = L["Left Shift Click"],
	["RIGHT_CLICK"] = L["Right Click"],
	--["RIGHT_ALT_CLICK"] = L["Right Alt Click"],
	--["RIGHT_ALT_CTRL_CLICK"] = L["Right Alt+Ctrl Click"],
	--["RIGHT_ALT_SHIFT_CLICK"] = L["Right Alt+Shift Click"],
	--["RIGHT_CTRL_CLICK"] = L["Right Ctrl Click"],
	--["RIGHT_CTRL_SHIFT_CLICK"] = L["Right Ctrl+Shift Click"],
	["RIGHT_SHIFT_CLICK"] = L["Right Shift Click"],
}

local dicQuestTagsLength = {
	["None"] = NONE,
	["Short"] = SHORT,
	["Full"] = L["Full"],
}

local dicZoneLevels = {
	[650] = 110, -- Highmountain
	[634] = 110, -- Stormheim
	[680] = 110, -- Suramar
	[630] = 110, -- Azsuna
	[641] = 110, -- Val'sharah
	[627] = 110, -- Dalaran
	[790] = 110, -- Eye of Azshara
	[646] = 110, -- Broken Shore
	[882] = 110, -- Mac'Aree
	[830] = 110, -- Krokun
	[885] = 110, -- Antoran Wastes
	[942] = 120, -- Stormsong Valley
	[895] = 120, -- Tiragarde Sound
	[1161] = 120, -- Boralus
	[896] = 120, -- Drustvar
	[864] = 120, -- Vol'dun
	[863] = 120, -- Nazmir
	[862] = 120, -- Zuldazar
	[1165] = 120, -- Dazar'alor
}

--Defaults
local db
local dbCore;
local dbChar;
local defaults = {
	profile = {
		MinionLocation = {X = 0, Y = 0, Point = "CENTER", RelativePoint = "CENTER"},
		MinionScale = 1,
		MinionLocked = false,
		MinionWidth = 220,
		AutoHideTitle = false,
		MinionCollapseToLeft = false,
		MoveTooltipsRight = false,		
		GrowUpwards = false,
		ConfirmQuestAbandons = true,
		ShowNumberOfQuests = true,
		ShowNumberOfDailyQuests = false,		
		ShowItemButtons = true,
		IndentItemButtons = false,
		IndentItemButtonQuestsOnly = false,			
		ItemButtonScale = 0.8,
		HideItemButtonsForCompletedQuests = true,	
		UseStatusBars = true,
		UseQuestCountMaxText = true,
		ShowCurrentSmartQuestItem = false,
		ZonesAndQuests = {
			QuestLevelColouringSetting = "Level",
			QuestTitleColouringSetting = "Level",
			ObjectiveTitleColouringSetting = "Custom",
			ObjectiveStatusColouringSetting = "Completion",
			QuestTagsLength = "Short",
			ShowQuestLevels = true,
			HideCompletedObjectives = true,
			HideCompletedQuests = false,
			ShowDescWhenNoObjectives = false,
			AllowHiddenQuests = true,
			CollapseOnLeave = false,
			ExpandOnEnter = false,
			HideZoneHeaders = false,
			QuestHeadersHideWhenEmpty = true,
			ShowHiddenCountOnZones = false,
			QuestTitleIndent = 5,
			ObjectivesIndent = 0,
			QuestAfterPadding = 0,
			ObjectiveTextLast= false,
			DisplayPOITag = false,
			QuestSortOrder = "Default",
			DisplayQuestIDInTooltip = false,
		},		
		Sounds = {
			UseQuestDoneSound = false,
			UseObjectiveDoneSound = false,
		},
		Fonts = {
			-- Scenario minion title font
			MinionTitleFontSize = 11,
			MinionTitleFont = "framd",
			MinionTitleFontOutline = "",
			MinionTitleFontShadowed = true,
			MinionTitleFontLineSpacing = 0,
			
			-- Zone header font
			HeaderFontSize = 11,
			HeaderFont = "framd",
			HeaderFontOutline = "",
			HeaderFontShadowed = true,
			HeaderFontLineSpacing = 0,
				
			-- Quest title font
			QuestFontSize = 11,
			QuestFont = "framd",
			QuestFontOutline = "",
			QuestFontShadowed = true,
			QuestFontLineSpacing = 0,
			
			-- Objective text font
			ObjectiveFontSize = 11,
			ObjectiveFont = "framd",
			ObjectiveFontOutline = "",
			ObjectiveFontShadowed = true,
			ObjectiveFontLineSpacing = 0,
		},
		Colours = {
			MinionTitleColour = {r = 0, g = 1, b = 0, a = 1},
			HeaderColour = {r = 0, g = 0.6, b = 1, a = 1},
			QuestTitleColour = {r = 1, g = 1, b = 1, a = 1},
			ObjectiveDescColour = {r = 0.5, g = 0.5, b = 0.5, a = 0.5},
			ObjectiveTitleColour = {r = 1, g = 1, b = 1, a = 1},			
			QuestStatusFailedColour = {r = 1, g = 1, b = 1, a = 1},
			QuestStatusDoneColour = {r = 1, g = 1, b = 1, a = 1},
			QuestStatusGotoColour = {r = 1, g = 1, b = 1, a = 1},
			QuestLevelColour = {r = 1, g = 1, b = 1, a = 1},
			ObjectiveStatusColour = {r = 1, g = 1, b = 1, a = 1},
			Objective00Colour = {r = 1, g = 0, b = 0, a = 1},
			Objective00PlusColour = {r = 1, g = 0, b = 0, a = 1},
			Objective25PlusColour = {r = 1, g = 0.3, b = 0, a = 1},
			Objective50PlusColour  = {r = 1, g = 0.6, b = 0, a = 1},
			Objective75PlusColour = {r = 1, g = 0.95, b = 0, a = 1},
			ObjectiveDoneColour = {r = 0, g = 1, b = 0, a = 1},			
			UndoneColour = {r = 1, g = 0, b = 0, a = 1},			
			DoneColour = {r = 0, g = 1, b = 0, a = 1},			
			MinionBackGroundColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
			MinionBorderColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
			InfoColour = {r = 0, g = 1, b = 0.5, a = 1},
			NotificationsColour = {r = 0, g = 1, b = 0, a = 1},
			ObjectiveTooltipTextColour = {r = 0.5, g = 0.5, b = 0.5, a = 1},
			StatusBarFillColour = {r = 0, g = 1, b = 0, a = 1},
			StatusBarBackColour = {r = 0, g = 0, b = 0, a = 1},
			ShowHideButtonColour = {r = 0.3, g = 0.3, b = 0.3, a = 0.65},
			ShowHideButtonActiveColour = {r = 0.2, g = 0.3, b = 1, a = 0.75},
			ShowHideButtonBorderColour = {r = 0, g = 0, b = 0, a = 1},
		},
		Notifications = {
			SuppressBlizzardNotifications = false,
			LibSinkColourSetting = "Custom",
			LibSinkObjectiveNotifications = false,
			DisplayQuestOnObjectiveNotifications = true,
			ShowQuestCompletesAndFails = false,
			QuestDoneSound = "None",
			ObjectiveDoneSound = "None",
			ObjectiveChangedSound = "None",
			QuestItemFoundSound = "None",
			ShowMessageOnPickingUpQuestItem = false,
			DisableToasts = false,
		},
		ClickBinds = {
			OpenLog = "LEFT_CLICK",
			OpenFullLog = "LEFT_ALT_CLICK",
			AbandonQuest = "LEFT_ALT_CTRL_CLICK",
			TrackQuest = "LEFT_CTRL_CLICK",
			LinkQuest = "LEFT_SHIFT_CLICK",
			HideShowQuest = "RIGHT_CLICK",
			FindGroup = "RIGHT_SHIFT_CLICK",
		},
	},
	char = {
		ZoneIsAllHiddenQuests = {},
		ZoneIsCollapsed = {},
		ZonesAndQuests = {
			ShowAllQuests = false,
		}
	},
}

--Options
local options
local function getOptions()
	if not options then
		options = {
			name = L["Quest Tracker Settings"],
			type = "group",
			childGroups = "tab",
			order = 1,
			arg = MODNAME,
			args = {
				Main = {
					name = L["Main"],
					type = "group",
					order = 1,
					args = {
						enabled = {
							order = 1,
							type = "toggle",
							name = L["Enable Minion"],
							get = function() return SorhaQuestLog:GetModuleEnabled(MODNAME) end,
							set = function(info, value) 
								SorhaQuestLog:SetModuleEnabled(MODNAME, value) 
								QuestTracker:MinionAnchorUpdate(false)
							end,
						},				
						MinionLockedToggle = {
							name = L["Lock Minion"],
							type = "toggle",
							get = function() return db.MinionLocked end,
							set = function()
								db.MinionLocked = not db.MinionLocked
								QuestTracker:MinionAnchorUpdate(false)
							end,
							order = 2,
						},
						AutoHideTitleToggle = {
							name = L["Auto Hide Minion Title"],
							desc = L["Hide the title when there is nothing to display"],
							type = "toggle",
							get = function() return db.AutoHideTitle end,
							set = function()
								db.AutoHideTitle = not db.AutoHideTitle
								QuestTracker:UpdateMinion()
							end,
							order = 5,
						},
						GrowUpwardsToggle = {
							name = L["Grow Upwards"],
							desc = L["Minions grows upwards from the anchor"],
							type = "toggle",
							get = function() return db.GrowUpwards end,
							set = function()
								db.GrowUpwards = not db.GrowUpwards
								QuestTracker:UpdateMinion()
							end,
							order = 7,
						},						
						CollapseToLeftToggle = {
							name = L["Autoshrink to left"],
							desc = L["Shrinks the width down when the length of current achievements is less then the max width\nNote: Doesn't work well with achievements that word wrap"],
							type = "toggle",
							get = function() return db.MinionCollapseToLeft end,
							set = function()
								db.MinionCollapseToLeft = not db.MinionCollapseToLeft
								QuestTracker:UpdateMinion()
							end,
							order = 8,
						},
						MoveTooltipsRightToggle = {
							name = L["Tooltips on right"],
							desc = L["Moves the tooltips to the right"],
							type = "toggle",
							get = function() return db.MoveTooltipsRight end,
							set = function()
								db.MoveTooltipsRight = not db.MoveTooltipsRight
								QuestTracker:UpdateMinion()
							end,
							order = 9,
						},
						MinionScaler = {
							order = 10,
							name = L["Minion Scale"],
							desc = L["Adjust the scale of the minion"],
							type = "range",
							min = 0.5, max = 2, step = 0.05,
							isPercent = false,
							get = function() return db.MinionScale end,
							set = function(info, value)
								db.MinionScale = value
								QuestTracker:MinionAnchorUpdate(true)
							end,
						},
						MinionWidth = {
							order = 11,
							name = L["Width"],
							desc = L["Adjust the width of the minion"],
							type = "range",
							min = 150, max = 600, step = 1,
							isPercent = false,
							get = function() return db.MinionWidth end,
							set = function(info, value)
								db.MinionWidth = value
								QuestTracker:UpdateMinion()
							end,
						},
						Reset = {
							order = 12,
							type = "execute",
							name = L["Reset Main Frame"],
							desc = L["Resets Main Frame position"],
							func = function()
								db.MinionLocation.Point = "CENTER"
								db.MinionLocation.RelativePoint =  "CENTER"
								db.MinionLocation.X = 0
								db.MinionLocation.Y = 0
								QuestTracker:MinionAnchorUpdate(true)
							end,
						},
						HeaderMiscSettingsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 30,
						},
						HeaderMiscSettings = {
							name = L["Misc. Settings"],
							type = "header",
							order = 31,
						},
						ShowNumberQuestsToggle = {
							name = L["Show number of quests"],
							desc = L["Shows/Hides the number of quests"],
							type = "toggle",
							get = function() return db.ShowNumberOfQuests end,
							set = function()
								db.ShowNumberOfQuests = not db.ShowNumberOfQuests
								QuestTracker:UpdateMinion()
							end,
							order = 32,
						},
						ShowNumberOfDailyQuestsToggle = {
							name = L["Show # of Dailies"],
							desc = L["Shows/Hides the number of daily quests completed"],
							type = "toggle",
							get = function() return db.ShowNumberOfDailyQuests end,
							set = function()
								db.ShowNumberOfDailyQuests = not db.ShowNumberOfDailyQuests
								QuestTracker:UpdateMinion()
							end,
							order = 33,
						},
						UseQuestCountMaxTextToggle = {
							name = L["Count/Max Header"],
							desc = L["Sets the LDB and minion header counts to questcount/max instead of count/completed"],
							type = "toggle",
							get = function() return db.UseQuestCountMaxText end,
							set = function()
								db.UseQuestCountMaxText = not db.UseQuestCountMaxText
								QuestTracker:UpdateMinion()
							end,
							order = 34,
						},
						ConfirmQuestAbandonsToggle = {
							name = L["Require confirmation when abandoning a Quest"],
							desc = L["Shows the confirm box when you try to abandon a quest"],
							type = "toggle",
							width = "full",
							get = function() return db.ConfirmQuestAbandons end,
							set = function()
								db.ConfirmQuestAbandons = not db.ConfirmQuestAbandons
								QuestTracker:UpdateMinion()
							end,
							order = 36,
						},	
						AutoTrackQuests = {
							name = L["Automatically track quests"],
							desc = L["Same as blizzard setting. Tracked quests are shown quests when the ability to hide quests is on."],
							width = "full",
							type = "toggle",
							get = function()
								if (GetCVar("autoQuestWatch") ==  "1") then
									return true
								else
									return false
								end
							end,
							set = function()
								if (GetCVar("autoQuestWatch") ==  "1") then
									SetCVar("autoQuestWatch", "0", AUTO_QUEST_WATCH_TEXT)
								else
									SetCVar("autoQuestWatch", "1", AUTO_QUEST_WATCH_TEXT)
								end
							end,
							order = 37,
						},
						AutoTrackQuestsWhenObjectiveupdate = {
							name = L["Automatically track quests when objectives update"],
							desc = L["Same as blizzard setting. Tracked quests are shown quests when the ability to hide quests is on."],
							width = "full",
							type = "toggle",
							get = function()
								if (GetCVar("autoQuestProgress") ==  "1") then
									return true
								else
									return false
								end
							end,
							set = function()
								if (GetCVar("autoQuestProgress") ==  "1") then
									SetCVar("autoQuestProgress", "0", AUTO_QUEST_PROGRESS_TEXT)
								else
									SetCVar("autoQuestProgress", "1", AUTO_QUEST_PROGRESS_TEXT)
								end
							end,
							order = 38,
						},
						StatusBarSpacerHeader = {
							name = L["Status Bar Settings"],
							type = "header",
							order = 50,
						},
						UseStatusBarsToggle = {
							name = L["Use Bars"],
							desc = L["Uses status bars for progress bar type objectives"],
							type = "toggle",
							get = function() return db.UseStatusBars end,
							set = function()
								db.UseStatusBars = not db.UseStatusBars
								QuestTracker:UpdateMinion()
							end,
							order = 51,
						},				
						MouseBindsSpacerHeader = {
							name = L["Mouse Click Bindings"],
							type = "header",
							order = 60,
						},
						OpenQuestLogClick = {
							name = L["Open Quest Log:"],
							desc = L["Mouse click to open the quest details pane"],
							type = "select",
							order = 61,
							values = dicKeybinds,
							get = function() return db.ClickBinds.OpenLog end,
							set = function(info, value)
								db.ClickBinds.OpenLog = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},	
						OpenFullQuestLogClick = {
							name = L["Open Full Quest Log:"],
							desc = L["Mouse click to open the full quest log pane"],
							type = "select",
							order = 62,
							values = dicKeybinds,
							get = function() return db.ClickBinds.OpenFullLog end,
							set = function(info, value)
								db.ClickBinds.OpenFullLog = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
						AbandonQuestClick = {
							name = ABANDON_QUEST,
							desc = L["Mouse click to abandon quest"],
							type = "select",
							order = 63,
							values = dicKeybinds,
							get = function() return db.ClickBinds.AbandonQuest end,
							set = function(info, value)
								db.ClickBinds.AbandonQuest = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
						TrackQuestClick = {
							name = TRACK_QUEST,
							desc = L["Mouse click to track quest"],
							type = "select",
							order = 64,
							values = dicKeybinds,
							get = function() return db.ClickBinds.TrackQuest end,
							set = function(info, value)
								db.ClickBinds.TrackQuest = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
						LinkQuestClick = {
							name = L["Link Quest:"],
							desc = L["Mouse click to link quest in chat"],
							type = "select",
							order = 65,
							values = dicKeybinds,
							get = function() return db.ClickBinds.LinkQuest end,
							set = function(info, value)
								db.ClickBinds.LinkQuest = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
						HideShowQuestClick = {
							name = L["Hide/Show Quest:"],
							desc = L["Mouse click to show/hide quest"],
							type = "select",
							order = 66,
							values = dicKeybinds,
							get = function() return db.ClickBinds.HideShowQuest end,
							set = function(info, value)
								db.ClickBinds.HideShowQuest = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
						FindGroupClick = {
							name = L["Find/Start Quest Group:"],
							desc = L["Mouse click to find or start a group for the quest"],
							type = "select",
							order = 67,
							values = dicKeybinds,
							get = function() return db.ClickBinds.FindGroup end,
							set = function(info, value)
								db.ClickBinds.FindGroup = value
								QuestTracker:UpdateClickBindings();
								QuestTracker:UpdateMinion()
							end,
						},
					},						
				},
				Zones = {
					name = L["Zones"],
					type = "group",
					order = 2,
					args = {
						AllowHiddenQuestsToggle = {
							name = L["Allow quests to be hidden"],
							desc = L["Allows quests to be hidden and enables the show/hide button"],
							type = "toggle",
							width = "full",
							get = function() return db.ZonesAndQuests.AllowHiddenQuests end,
							set = function()
								db.ZonesAndQuests.AllowHiddenQuests = not db.ZonesAndQuests.AllowHiddenQuests
								QuestTracker:doHiddenQuestsUpdate()
								QuestTracker:UpdateMinion()
							end,
							order = 3,
						},
						AllowHiddenHeadersToggle = {
							name = L["Zone headers hide when all contained quests are hidden"],
							desc = L["Makes zone headers hide when all contained quests are hidden"],
							type = "toggle",
							disabled = function() return not db.ZonesAndQuests.AllowHiddenQuests end,
							width = "full",
							get = function() return db.ZonesAndQuests.QuestHeadersHideWhenEmpty end,
							set = function()
								db.ZonesAndQuests.QuestHeadersHideWhenEmpty = not db.ZonesAndQuests.QuestHeadersHideWhenEmpty
								QuestTracker:UpdateMinion()
							end,
							order = 4,
						},		
						AllowHiddenCountOnZonesToggle = {
							name = L["Display count of hidden quest in each zone"],
							desc = L["Displays a count of the hidden quests in each zone on the zone header"],
							type = "toggle",
							disabled = function() return not db.ZonesAndQuests.AllowHiddenQuests end,
							width = "full",
							get = function() return db.ZonesAndQuests.ShowHiddenCountOnZones end,
							set = function()
								db.ZonesAndQuests.ShowHiddenCountOnZones = not db.ZonesAndQuests.ShowHiddenCountOnZones
								QuestTracker:UpdateMinion()
							end,
							order = 5,
						},
						ExpandOnEnterToggle = {
							name = L["Auto expand zones on enter"],
							desc = L["Automatically expands zone headers when you enter the zone"],
							type = "toggle",
							get = function() return db.ZonesAndQuests.ExpandOnEnter end,
							set = function()
								db.ZonesAndQuests.ExpandOnEnter = not db.ZonesAndQuests.ExpandOnEnter
								QuestTracker:doHandleZoneChange()
							end,
							order = 22,
						},	
						CollapseOnLeaveToggle = {
							name = L["Auto collapse zones on exit"],
							desc = L["Automatically collapses zone headers when you exit the zone"],
							type = "toggle",
							get = function() return db.ZonesAndQuests.CollapseOnLeave end,
							set = function()
								db.ZonesAndQuests.CollapseOnLeave = not db.ZonesAndQuests.CollapseOnLeave
								QuestTracker:doHandleZoneChange()
							end,
							order = 23,
						},	
						HideZoneHeadersToggle = {
							name = L["Hide Zone Headers"],
							desc = L["Hides all zone headers and just displays quests. Note: Does not expand zone headers for you"],
							type = "toggle",
							get = function() return db.ZonesAndQuests.HideZoneHeaders end,
							set = function()
								db.ZonesAndQuests.HideZoneHeaders = not db.ZonesAndQuests.HideZoneHeaders
								QuestTracker:UpdateMinion()
							end,
							order = 28,
						},
						
					}
				},
				Quests = {
					name = QUESTS_LABEL,
					type = "group",
					order = 3,
					args = {
						ShowQuestLevelsToggle = {
							name = L["Display level in Quest Title"],
							desc = L["Displays the level of the quest in the title"],
							type = "toggle",
							get = function() return db.ZonesAndQuests.ShowQuestLevels end,
							set = function()
								db.ZonesAndQuests.ShowQuestLevels = not db.ZonesAndQuests.ShowQuestLevels
								QuestTracker:UpdateMinion()
							end,
							order = 6,
						},
						ShowQuestPOIsToggle = {
							name = L["Display POI Tag in Quest Title"],
							desc = L["Displays the POI Tag used on the world map for in the title"],
							type = "toggle",
							get = function() return db.ZonesAndQuests.DisplayPOITag end,
							set = function()
								db.ZonesAndQuests.DisplayPOITag = not db.ZonesAndQuests.DisplayPOITag
								QuestTracker:UpdateMinion()
							end,
							order = 7,
						},
						DisplayQuestIDInTooltipToggle = {
							name = L["Show Quest Ids in Tooltip"],
							desc = L["Displays the Id of the quest in the tooltip"],
							type = "toggle",
							width = "full",
							get = function() return db.ZonesAndQuests.DisplayQuestIDInTooltip end,
							set = function()
								db.ZonesAndQuests.DisplayQuestIDInTooltip = not db.ZonesAndQuests.DisplayQuestIDInTooltip
								QuestTracker:UpdateMinion()
							end,
							order = 8,
						},
						QuestTagsLengthSelect = {
							name = L["Quest Tag Length:"],
							desc = L["The length of the quest tags (d, p, g5, ELITE etc)"],
							type = "select",
							order = 9,
							values = dicQuestTagsLength,
							get = function() return db.ZonesAndQuests.QuestTagsLength end,
							set = function(info, value)
								db.ZonesAndQuests.QuestTagsLength = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestSortOrderSelect = {
							name = L["Quest Sort Order:"],
							desc = L["The sort order of quests, within each zone"],
							type = "select",
							order = 10,
							values = dicQuestSortOrder,
							get = function() return db.ZonesAndQuests.QuestSortOrder end,
							set = function(info, value)
								db.ZonesAndQuests.QuestSortOrder = value
								QuestTracker:UpdateMinion()
							end,
						},

						HeaderQuestsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 40,
						},
						HeaderQuests = {
							name = L["Quest Settings"],
							type = "header",
							order = 41,
						},

						HideCompletedQuestsToggle = {
							name = L["Hide Completed quests/goto Quests"],
							desc = L["Automatically hides completed quests on completion. Also hides goto quests"],
							width = "full",
							type = "toggle",
							get = function() return db.ZonesAndQuests.HideCompletedQuests end,
							set = function()
								db.ZonesAndQuests.HideCompletedQuests = not db.ZonesAndQuests.HideCompletedQuests
								QuestTracker:UpdateMinion()
							end,
							order = 43,
						},
						QuestTitleIndent = {
							order = 48,
							name = L["Quest Text Indent"],
							desc = L["Controls the level of indentation for the quest text"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.ZonesAndQuests.QuestTitleIndent end,
							set = function(info, value)
								db.ZonesAndQuests.QuestTitleIndent = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestAfterPadding = {
							order = 49,
							name = L["Padding After Quest"],
							desc = L["The amount of extra padding after a quest before the next text."],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.ZonesAndQuests.QuestAfterPadding end,
							set = function(info, value)
								db.ZonesAndQuests.QuestAfterPadding = value
								QuestTracker:UpdateMinion()
							end,
						},					
						
						HeaderObjectivesSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 80,
						},
						HeaderObjectives = {
							name = L["Objective Settings"],
							type = "header",
							order = 81,
						},
						HideCompletedObjectivesToggle = {
							name = L["Hide completed objectives"],
							desc = L["Shows/Hides completed objectives"],
							type = "toggle",
							width = "full",
							get = function() return db.ZonesAndQuests.HideCompletedObjectives end,
							set = function()
								db.ZonesAndQuests.HideCompletedObjectives = not db.ZonesAndQuests.HideCompletedObjectives
								QuestTracker:UpdateMinion()
							end,
							order = 82,
						},
						ShowDescWhenNoObjectivesToggle = {
							name = L["Display quest description if not objectives"],
							desc = L["Displays a quests description if there are no objectives available"],
							type = "toggle",
							width = "full",
							get = function() return db.ZonesAndQuests.ShowDescWhenNoObjectives end,
							set = function()
								db.ZonesAndQuests.ShowDescWhenNoObjectives = not db.ZonesAndQuests.ShowDescWhenNoObjectives
								QuestTracker:UpdateMinion()
							end,
							order = 83,
						},	
						ObjectivesIndent = {
							order = 88,
							name = L["Objective Text Indent"],
							desc = L["Controls the level of indentation for the Objective text"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.ZonesAndQuests.ObjectivesIndent end,
							set = function(info, value)
								db.ZonesAndQuests.ObjectivesIndent = value
								QuestTracker:UpdateMinion()
							end,
						},	
						ObjectivesTextLast = {
							order = 89,
							name = L["Objective Text Last"],
							desc = L["Display the text of an objective after numbers"],
							type = "toggle",
							width = "full",
							get = function() return db.ZonesAndQuests.ObjectiveTextLast end,
							set = function()
								db.ZonesAndQuests.ObjectiveTextLast = not db.ZonesAndQuests.ObjectiveTextLast
								QuestTracker:UpdateMinion()
							end,
						},		

					}
				},
				QuestItems = {
					name = L["Quest Items"],
					type = "group",
					order = 4,
					args = {
						HeaderItemButtons = {
							name = L["Item Button Settings"],
							type = "header",
							order = 71,
						},
						ShowItemButtonsToggle = {
							name = L["Show quest item buttons"],
							desc = L["Shows/Hides the quest item buttons"],
							type = "toggle",
							get = function() return db.ShowItemButtons end,
							set = function()
								db.ShowItemButtons = not db.ShowItemButtons
								QuestTracker:UpdateMinion()
							end,
							order = 72,
						},
						ItemsAndTooltipsRightToggle = {
							name = L["Display items and tooltips on right"],
							desc = L["Moves items and tooltips to the right"],
							type = "toggle",
							get = function() return db.MoveTooltipsRight end,
							set = function()
								db.MoveTooltipsRight = not db.MoveTooltipsRight
								QuestTracker:UpdateMinion()
							end,
							order = 73,
						},
						IndentItemButtonsToggle = {
							name = L["Indent item buttons inside tracker"],
							desc = L["Indents the item buttons into the quest tracker so they are flush with zone headers"],
							type = "toggle",
							width = "full",
							disabled = function() return (db.MoveTooltipsRight == true or db.ShowItemButtons == false) end,
							get = function() return db.IndentItemButtons end,
							set = function()
								db.IndentItemButtons = not db.IndentItemButtons
								QuestTracker:UpdateMinion()
							end,
							order = 74,
						},
						IndentItemButtonQuestsOnlyToggle = {
							name = L["Indent only quests with item buttons"],
							desc = L["Only indents a quest if the quest has an item button"],
							type = "toggle",
							width = "full",
							disabled = function() return (db.MoveTooltipsRight == true or db.IndentItemButtons == false or db.ShowItemButtons == false) end,
							get = function() return db.IndentItemButtonQuestsOnly end,
							set = function()
								db.IndentItemButtonQuestsOnly = not db.IndentItemButtonQuestsOnly
								QuestTracker:UpdateMinion()
							end,
							order = 75,
						},
						HideItemButtonsForCompletedQuestsToggle = {
							name = L["Hide Item Buttons for completed quests"],
							desc = L["Hides the quests item button once the quest is complete"],
							type = "toggle",
							width = "full",
							disabled = function() return not(db.ShowItemButtons) end,
							get = function() return db.HideItemButtonsForCompletedQuests end,
							set = function()
								db.HideItemButtonsForCompletedQuests = not db.HideItemButtonsForCompletedQuests
								QuestTracker:UpdateMinion()
							end,
							order = 76,
						},		
						ShowCurrentSmartQuestItemToggle = {
							name = L["Show Smart Item Button"],
							desc = L["Shows the Smart Item Button. This isn't needed for the keybind"],
							type = "toggle",
							width = "full",
							disabled = function() return not(db.ShowItemButtons) end,
							get = function() return db.ShowCurrentSmartQuestItem end,
							set = function()
								db.ShowCurrentSmartQuestItem = not db.ShowCurrentSmartQuestItem
								QuestTracker:UpdateMinion()
							end,
							order = 77,
						},	
						ItemButtonsSizeSlider = {
							order = 80,
							name = L["Item Button Size"],
							desc = L["Controls the size of the Item Buttons."],
							type = "range",
							disabled = function() return not(db.ShowItemButtons) end,
							min = 0.5, max = 2, step = 0.05,
							isPercent = false,
							get = function() return db.ItemButtonScale end,
							set = function(info, value)
								db.ItemButtonScale = value
								QuestTracker:UpdateMinion()
							end,
						},											
					}
				},
				Fonts = {
					name = L["Fonts"],
					type = "group",
					order = 5,
					args = {
						HeaderTitleFont = {
							name = L["Info Text Font Settings"],
							type = "header",
							order = 41,
						},
						MinionTitleFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 42,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.MinionTitleFont end,
							set = function(info, value)
								db.Fonts.MinionTitleFont = value
								QuestTracker:UpdateMinion()
							end,
						},
						MinionTitleFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 43,
							values = dicOutlines,
							get = function() return db.Fonts.MinionTitleFontOutline end,
							set = function(info, value)
								db.Fonts.MinionTitleFontOutline = value
								QuestTracker:UpdateMinion()
							end,
						},
						MinionTitleFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.MinionTitleFontShadowed end,
							set = function()
								db.Fonts.MinionTitleFontShadowed = not db.Fonts.MinionTitleFontShadowed
								QuestTracker:UpdateMinion()
							end,
							order = 44,
						},
						MinionTitleFontSizeSelect = {
							order = 45,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.MinionTitleFontSize end,
							set = function(info, value)
								db.Fonts.MinionTitleFontSize = value
								QuestTracker:UpdateMinion()
							end,
						},
						MinionTitleFontLineSpacing = {
							order = 46,
							name = L["Font Line Spacing"],
							desc = L["Controls the spacing below each line of this font"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.MinionTitleFontLineSpacing end,
							set = function(info, value)
								db.Fonts.MinionTitleFontLineSpacing = value
								QuestTracker:UpdateMinion()
							end,
						},

						ZonesFontSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 50,
						},
						ZonesFontHeader = {
							name = L["Zone Font Settings"],
							type = "header",
							order = 51,
						},
						ZonesFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 52,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.HeaderFont end,
							set = function(info, value)
								db.Fonts.HeaderFont = value
								QuestTracker:UpdateMinion()
							end,
						},
						ZonesFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 53,
							values = dicOutlines,
							get = function() return db.Fonts.HeaderFontOutline end,
							set = function(info, value)
								db.Fonts.HeaderFontOutline = value
								QuestTracker:UpdateMinion()
							end,
						},
						ZonesFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.HeaderFontShadowed end,
							set = function()
								db.Fonts.HeaderFontShadowed = not db.Fonts.HeaderFontShadowed
								QuestTracker:UpdateMinion()
							end,
							order = 54,
						},
						ZonesFontSize = {
							order = 55,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.HeaderFontSize end,
							set = function(info, value)
								db.Fonts.HeaderFontSize = value
								QuestTracker:UpdateMinion()
							end,
						},
						ZonesFontLineSpacing = {
							order = 56,
							name = L["Font Line Spacing"],
							desc = L["Controls the spacing below each line of this font"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.HeaderFontLineSpacing end,
							set = function(info, value)
								db.Fonts.HeaderFontLineSpacing = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestFontSpacer = {
							name = "", 
							width = "full",
							type = "description",
							order = 60,
						},
						QuestFontHeader = {
							name = L["Quest Font Settings"],
							type = "header",
							order = 61,
						},
						QuestFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 62,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.QuestFont end,
							set = function(info, value)
								db.Fonts.QuestFont = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 63,
							values = dicOutlines,
							get = function() return db.Fonts.QuestFontOutline end,
							set = function(info, value)
								db.Fonts.QuestFontOutline = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.QuestFontShadowed end,
							set = function()
								db.Fonts.QuestFontShadowed = not db.Fonts.QuestFontShadowed
								QuestTracker:UpdateMinion()
							end,
							order = 64,
						},
						QuestFontSize = {
							order = 65,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.QuestFontSize end,
							set = function(info, value)
								db.Fonts.QuestFontSize = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestFontLineSpacing = {
							order = 66,
							name = L["Font Line Spacing"],
							desc = L["Controls the spacing below each line of this font"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.QuestFontLineSpacing end,
							set = function(info, value)
								db.Fonts.QuestFontLineSpacing = value
								QuestTracker:UpdateMinion()
							end,
						},
						
						ObjectiveFontSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 70,
						},
						ObjectiveFontHeader = {
							name = L["Objective Font Settings"],
							type = "header",
							order = 71,
						},
						ObjectiveFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 72,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.ObjectiveFont end,
							set = function(info, value)
								db.Fonts.ObjectiveFont = value
								QuestTracker:UpdateMinion()
							end,
						},
						ObjectiveFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 73,
							values = dicOutlines,
							get = function() return db.Fonts.ObjectiveFontOutline end,
							set = function(info, value)
								db.Fonts.ObjectiveFontOutline = value
								QuestTracker:UpdateMinion()
							end,
						},
						ObjectiveFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.ObjectiveFontShadowed end,
							set = function()
								db.Fonts.ObjectiveFontShadowed = not db.Fonts.ObjectiveFontShadowed
								QuestTracker:UpdateMinion()
							end,
							order = 74,
						},	
						ObjectiveFontSize = {
							order = 75,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.ObjectiveFontSize end,
							set = function(info, value)
								db.Fonts.ObjectiveFontSize = value
								QuestTracker:UpdateMinion()
							end,
						},
						ObjectiveFontLineSpacing = {
							order = 76,
							name = L["Font Line Spacing"],
							desc = L["Controls the spacing below each line of this font"],
							type = "range",
							min = 0, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.ObjectiveFontLineSpacing end,
							set = function(info, value)
								db.Fonts.ObjectiveFontLineSpacing = value
								QuestTracker:UpdateMinion()
							end,
						},
					}
				},
				Colours = {
					name = L["Colours"],
					type = "group",
					order = 6,
					args = {
						InfoTextColour = {
							name = L["Info Text"],
							desc = L["Sets the color of the info text (Title bar, # of quests hidden etc)"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.InfoColour.r, db.Colours.InfoColour.g, db.Colours.InfoColour.b, db.Colours.InfoColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.InfoColour.r = r
									db.Colours.InfoColour.g = g
									db.Colours.InfoColour.b = b
									db.Colours.InfoColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 2,
						},
						MinionBackGroundColour = {
							name = L["Background Colour"],
							desc = L["Sets the color of the minions background"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionBackGroundColour.r = r
									db.Colours.MinionBackGroundColour.g = g
									db.Colours.MinionBackGroundColour.b = b
									db.Colours.MinionBackGroundColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 4,
						},
						MinionBorderColour = {
							name = L["Border Colour"],
							desc = L["Sets the color of the minions border"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionBorderColour.r = r
									db.Colours.MinionBorderColour.g = g
									db.Colours.MinionBorderColour.b = b
									db.Colours.MinionBorderColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 5,
						},
						ShowHideButtonColourSelect = {
							name = L["Toggle Hidden Colour"],
							desc = L["Sets the color of the 'Toggle Hidden Quests' buttons inactive state"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ShowHideButtonColour.r, db.Colours.ShowHideButtonColour.g, db.Colours.ShowHideButtonColour.b, db.Colours.ShowHideButtonColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ShowHideButtonColour.r = r
									db.Colours.ShowHideButtonColour.g = g
									db.Colours.ShowHideButtonColour.b = b
									db.Colours.ShowHideButtonColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 6,
						},
						ShowHideButtonBorderColourSelect = {
							name = L["Toggle Hidden Border Colour"],
							desc = L["Sets the color of the 'Toggle Hidden Quests' buttons border"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ShowHideButtonBorderColour.r, db.Colours.ShowHideButtonBorderColour.g, db.Colours.ShowHideButtonBorderColour.b, db.Colours.ShowHideButtonBorderColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ShowHideButtonBorderColour.r = r
									db.Colours.ShowHideButtonBorderColour.g = g
									db.Colours.ShowHideButtonBorderColour.b = b
									db.Colours.ShowHideButtonBorderColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 7,
						},			
						ShowHideButtonActiveColourSelect = {
							name = L["Toggle Hidden Colour (Active)"],
							desc = L["Sets the color of the 'Toggle Hidden Quests' buttons active state"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ShowHideButtonActiveColour.r, db.Colours.ShowHideButtonActiveColour.g, db.Colours.ShowHideButtonActiveColour.b, db.Colours.ShowHideButtonActiveColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ShowHideButtonActiveColour.r = r
									db.Colours.ShowHideButtonActiveColour.g = g
									db.Colours.ShowHideButtonActiveColour.b = b
									db.Colours.ShowHideButtonActiveColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 8,
						},			
						HeaderColourSettings = {
							name = L["Colour Settings"],
							type = "header",
							order = 10,
						},
						QuestLevelColouringSelect = {
							name = L["Colour quest levels by:"],
							desc = L["The setting by which the colour of quest levels are determined"],
							type = "select",
							order = 11,
							values = dicQuestTitleColourOptions,
							get = function() return db.ZonesAndQuests.QuestLevelColouringSetting end,
							set = function(info, value)
								db.ZonesAndQuests.QuestLevelColouringSetting = value
								QuestTracker:UpdateMinion()
							end,
						},
						QuestTitleColouringSelect = {
							name = L["Colour quest titles by:"],
							desc = L["The setting by which the colour of quest titles is determined"],
							type = "select",
							order = 12,
							values = dicQuestTitleColourOptions,
							get = function() return db.ZonesAndQuests.QuestTitleColouringSetting end,
							set = function(info, value)
								db.ZonesAndQuests.QuestTitleColouringSetting = value
								QuestTracker:UpdateMinion()
							end,
						},
						ObjectiveTitleColouringSelect = {
							name = L["Colour objective title text by:"],
							desc = L["The setting by which the colour of objective title is determined"],
							type = "select",
							order = 13,
							values = dicObjectiveColourOptions,
							get = function() return db.ZonesAndQuests.ObjectiveTitleColouringSetting end,
							set = function(info, value)
								db.ZonesAndQuests.ObjectiveTitleColouringSetting = value
								QuestTracker:UpdateMinion()
							end,
						},
						ObjectiveStatusColouringSelect = {
							name = L["Colour objective status text by:"],
							desc = L["The setting by which the colour of objective statuses is determined"],
							type = "select",
							order = 14,
							values = dicObjectiveColourOptions,
							get = function() return db.ZonesAndQuests.ObjectiveStatusColouringSetting end,
							set = function(info, value)
								db.ZonesAndQuests.ObjectiveStatusColouringSetting = value
								QuestTracker:UpdateMinion()
							end,
						},
						HeaderMainColoursSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 20,
						},
						HeaderMainColours = {
							name = L["Main Colours"],
							type = "header",
							order = 21,
						},
						HeaderColour = {
							name = L["Zone Header Colour"],
							desc = L["Sets the color for the header of each zone"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.HeaderColour.r, db.Colours.HeaderColour.g, db.Colours.HeaderColour.b, db.Colours.HeaderColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.HeaderColour.r = r
									db.Colours.HeaderColour.g = g
									db.Colours.HeaderColour.b = b
									db.Colours.HeaderColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 24,
						},
						QuestLevelColour = {
							name = L["Quest levels"],
							desc = L["Sets the color for the quest levels if custom colouring is on"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.QuestLevelColouringSetting == "Custom") end,
							hasAlpha = true,
							get = function() return db.Colours.QuestLevelColour.r, db.Colours.QuestLevelColour.g, db.Colours.QuestLevelColour.b, db.Colours.QuestLevelColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.QuestLevelColour.r = r
									db.Colours.QuestLevelColour.g = g
									db.Colours.QuestLevelColour.b = b
									db.Colours.QuestLevelColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 25,
						},
						QuestTitleColour = {
							name = L["Quest titles"],
							desc = L["Sets the color for the quest titles if colouring by level is off"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.QuestTitleColouringSetting == "Custom") end,
							hasAlpha = true,
							get = function() return db.Colours.QuestTitleColour.r, db.Colours.QuestTitleColour.g, db.Colours.QuestTitleColour.b, db.Colours.QuestTitleColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.QuestTitleColour.r = r
									db.Colours.QuestTitleColour.g = g
									db.Colours.QuestTitleColour.b = b
									db.Colours.QuestTitleColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 26,
						},
						NoObjectivesColour = {
							name = L["No objectives description colour"],
							desc = L["Sets the color for the description displayed when there is no quest objectives"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ObjectiveDescColour.r, db.Colours.ObjectiveDescColour.g, db.Colours.ObjectiveDescColour.b, db.Colours.ObjectiveDescColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ObjectiveDescColour.r = r
									db.Colours.ObjectiveDescColour.g = g
									db.Colours.ObjectiveDescColour.b = b
									db.Colours.ObjectiveDescColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 27,
						},
						ObjectiveTitleColourPicker = {
							name = L["Objective title colour"],
							desc = L["Sets the custom color for objectives titles"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Custom") end,
							hasAlpha = true,
							get = function() return db.Colours.ObjectiveTitleColour.r, db.Colours.ObjectiveTitleColour.g, db.Colours.ObjectiveTitleColour.b, db.Colours.ObjectiveTitleColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ObjectiveTitleColour.r = r
									db.Colours.ObjectiveTitleColour.g = g
									db.Colours.ObjectiveTitleColour.b = b
									db.Colours.ObjectiveTitleColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 28,
						},
						ObjectiveStatusColourPicker = {
							name = L["Objective status colour"],
							desc = L["Sets the custom color for objectives statuses"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Custom") end,
							hasAlpha = true,
							get = function() return db.Colours.ObjectiveStatusColour.r, db.Colours.ObjectiveStatusColour.g, db.Colours.ObjectiveStatusColour.b, db.Colours.ObjectiveStatusColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ObjectiveStatusColour.r = r
									db.Colours.ObjectiveStatusColour.g = g
									db.Colours.ObjectiveStatusColour.b = b
									db.Colours.ObjectiveStatusColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 29,
						},
						QuestStatusFailedColourPicker = {
							name = L["Quest failed tag"],
							desc = L["Sets the color for the quest failed tag"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.QuestStatusFailedColour.r, db.Colours.QuestStatusFailedColour.g, db.Colours.QuestStatusFailedColour.b, db.Colours.QuestStatusFailedColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.QuestStatusFailedColour.r = r
									db.Colours.QuestStatusFailedColour.g = g
									db.Colours.QuestStatusFailedColour.b = b
									db.Colours.QuestStatusFailedColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 30,
						},								
						QuestStatusDoneColourPicker = {
							name = L["Quest done tag"],
							desc = L["Sets the color for the quest done tag"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.QuestStatusDoneColour.r, db.Colours.QuestStatusDoneColour.g, db.Colours.QuestStatusDoneColour.b, db.Colours.QuestStatusDoneColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.QuestStatusDoneColour.r = r
									db.Colours.QuestStatusDoneColour.g = g
									db.Colours.QuestStatusDoneColour.b = b
									db.Colours.QuestStatusDoneColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 31,
						},									
						QuestStatusGotoColourPicker = {
							name = L["Quest goto Tag"],
							desc = L["Sets the color for the quest goto tag"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.QuestStatusGotoColour.r, db.Colours.QuestStatusGotoColour.g, db.Colours.QuestStatusGotoColour.b, db.Colours.QuestStatusGotoColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.QuestStatusGotoColour.r = r
									db.Colours.QuestStatusGotoColour.g = g
									db.Colours.QuestStatusGotoColour.b = b
									db.Colours.QuestStatusGotoColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 32,
						},		
						ObjectiveTooltipTextColourColourPicker = {
							name = L["Objective Tooltip Text"],
							desc = L["Sets the color for the objective text in the quests tooltip"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ObjectiveTooltipTextColour.r, db.Colours.ObjectiveTooltipTextColour.g, db.Colours.ObjectiveTooltipTextColour.b, db.Colours.ObjectiveTooltipTextColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ObjectiveTooltipTextColour.r = r
									db.Colours.ObjectiveTooltipTextColour.g = g
									db.Colours.ObjectiveTooltipTextColour.b = b
									db.Colours.ObjectiveTooltipTextColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 33,
						},		
						HeaderGradualColoursSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 50,
						},
						HeaderGradualColours = {
							name = L["Gradual objective Colours"],
							type = "header",
							order = 51,
						},
						Objective00Colour = {
							name = L["Unstarted(0%) objective colour"],
							desc = L["Sets the color for objectives that are 0% complete"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.Objective00Colour.r, db.Colours.Objective00Colour.g, db.Colours.Objective00Colour.b, db.Colours.Objective00Colour.a end,
							set = function(_,r,g,b,a)
									db.Colours.Objective00Colour.r = r
									db.Colours.Objective00Colour.g = g
									db.Colours.Objective00Colour.b = b
									db.Colours.Objective00Colour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 52,
						},
						Objective00PlusColour = {
							name = L["1-25% Complete objective colour"],
							desc = L["Sets the color for objectives that are above 0% complete"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.Objective00PlusColour.r, db.Colours.Objective00PlusColour.g, db.Colours.Objective00PlusColour.b, db.Colours.Objective00PlusColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.Objective00PlusColour.r = r
									db.Colours.Objective00PlusColour.g = g
									db.Colours.Objective00PlusColour.b = b
									db.Colours.Objective00PlusColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 53,
						},
						Objective25PlusColour = {
							name = L["25% Complete objective colour"],
							desc = L["Sets the color for objectives that are above 25% complete"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Completion" or db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Completion" or db.ZonesAndQuests.QuestLevelColouringSetting == "Completion" or db.ZonesAndQuests.QuestTitleColouringSetting == "Completion") end,
							hasAlpha = true,
							get = function() return db.Colours.Objective25PlusColour.r, db.Colours.Objective25PlusColour.g, db.Colours.Objective25PlusColour.b, db.Colours.Objective25PlusColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.Objective25PlusColour.r = r
									db.Colours.Objective25PlusColour.g = g
									db.Colours.Objective25PlusColour.b = b
									db.Colours.Objective25PlusColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 54,
						},
						Objective50PlusColour = {
							name = L["50% Complete objective colour"],
							desc = L["Sets the color for objectives that are above 50% complete"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Completion" or db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Completion" or db.ZonesAndQuests.QuestLevelColouringSetting == "Completion" or db.ZonesAndQuests.QuestTitleColouringSetting == "Completion") end,
							hasAlpha = false,
							get = function() return db.Colours.Objective50PlusColour.r, db.Colours.Objective50PlusColour.g, db.Colours.Objective50PlusColour.b, db.Colours.Objective50PlusColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.Objective50PlusColour.r = r
									db.Colours.Objective50PlusColour.g = g
									db.Colours.Objective50PlusColour.b = b
									db.Colours.Objective50PlusColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 55,
						},
						Objective75PlusColour = {
							name = L["75% Complete objective colour"],
							desc = L["Sets the color for objectives that are above 75% complete"],
							type = "color",
							disabled = function() return not(db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Completion" or db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Completion" or db.ZonesAndQuests.QuestLevelColouringSetting == "Completion" or db.ZonesAndQuests.QuestTitleColouringSetting == "Completion") end,
							hasAlpha = true,
							get = function() return db.Colours.Objective75PlusColour.r, db.Colours.Objective75PlusColour.g, db.Colours.Objective75PlusColour.b, db.Colours.Objective75PlusColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.Objective75PlusColour.r = r
									db.Colours.Objective75PlusColour.g = g
									db.Colours.Objective75PlusColour.b = b
									db.Colours.Objective75PlusColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 56,
						},
						DoneObjectiveColour = {
							name = L["Complete objective colour"],
							desc = L["Sets the color for the complete objectives"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ObjectiveDoneColour.r, db.Colours.ObjectiveDoneColour.g, db.Colours.ObjectiveDoneColour.b, db.Colours.ObjectiveDoneColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ObjectiveDoneColour.r = r
									db.Colours.ObjectiveDoneColour.g = g
									db.Colours.ObjectiveDoneColour.b = b
									db.Colours.ObjectiveDoneColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 57,
						},
						spacerdoneundone1 = {
							name = "",
							type = "description",
							order = 58,
						},
						UndoneColour = {
							name = L["Undone colour"],
							desc = L["Sets the colour for undone items"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.UndoneColour.r, db.Colours.UndoneColour.g, db.Colours.UndoneColour.b, db.Colours.UndoneColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.UndoneColour.r = r
									db.Colours.UndoneColour.g = g
									db.Colours.UndoneColour.b = b
									db.Colours.UndoneColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 59,
						},
						DoneColour = {
							name = L["Done colour"],
							desc = L["Sets the colour for done items"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.DoneColour.r, db.Colours.DoneColour.g, db.Colours.DoneColour.b, db.Colours.DoneColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.DoneColour.r = r
									db.Colours.DoneColour.g = g
									db.Colours.DoneColour.b = b
									db.Colours.DoneColour.a = a
									QuestTracker:HandleColourChanges()
								end,
							order = 60,
						},

						StatusBarSpacerHeader = {
							name = L["Status Bar Settings"],
							type = "header",
							order = 70,
						},						
						StatusBarFillColour = {
							name = L["Bar Fill Colour"],
							desc = L["Sets the color for the completed part status bars"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarFillColour.r = r
									db.Colours.StatusBarFillColour.g = g
									db.Colours.StatusBarFillColour.b = b
									db.Colours.StatusBarFillColour.a = a
									QuestTracker:UpdateMinion()
								end,
							order = 71,
						},
						StatusBarBackColour = {
							name = L["Bar Back Colour"],
							desc = L["Sets the color for the un-completed part of status bars"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarBackColour.r = r
									db.Colours.StatusBarBackColour.g = g
									db.Colours.StatusBarBackColour.b = b
									db.Colours.StatusBarBackColour.a = a
									QuestTracker:UpdateMinion()
								end,
							order = 72,
						},
					}
				},
				Notifications = {
					name = L["Notifications"],
					type = "group",
					childGroups = "tab",
					order = 7,
					args = {
						Notifications2 = {
							name = L["Notifications"],
							type = "group",
							order = 7,
							args = {
								NotificationSettingsHeader = {
									name = L["Text Notification Settings"],
									type = "header",
									order = 1,
								},
								SuppressBlizzardNotificationsToggle = {
									name = L["Suppress blizzard notification messages"],
									desc = L["Suppresses the notification messages sent by blizzard to the UIErrors Frame for progress updates"],
									type = "toggle",
									width = "full",
									get = function() return db.Notifications.SuppressBlizzardNotifications end,
									set = function()
										db.Notifications.SuppressBlizzardNotifications = not db.Notifications.SuppressBlizzardNotifications
									end,
									order = 2,
								},
								LibSinkHeaderSpacer = {
									name = "",
									width = "full",
									type = "description",
									order = 20,
								},
								LibSinkHeader = {
									name = L["LibSink Options"],
									type = "header",
									order = 21,
								},
								LibSinkObjectivesSmallHeader = {
									name = "|cff00ff00" .. L["Objective Notifications"] .. "|r",
									width = "full",
									type = "description",
									order = 22,
								},
								LibSinkObjectiveNotificationsToggle = {
									name = L["Use for Objective notification messages"],
									desc = L["Displays objective notification messages using LibSink"],
									type = "toggle",
									get = function() return db.Notifications.LibSinkObjectiveNotifications end,
									set = function()
										db.Notifications.LibSinkObjectiveNotifications = not db.Notifications.LibSinkObjectiveNotifications
									end,
									order = 23,
								},
								DisplayQuestOnObjectiveNotificationsToggle = {
									name = L["Display Quest Name"],
									desc = L["Adds the quest name to objective notification messages"],
									type = "toggle",
									disabled = function() return not(db.Notifications.LibSinkObjectiveNotifications) end,
									get = function() return db.Notifications.DisplayQuestOnObjectiveNotifications end,
									set = function()
										db.Notifications.DisplayQuestOnObjectiveNotifications = not db.Notifications.DisplayQuestOnObjectiveNotifications
									end,
									order = 24,
								},
								LibSinkQuestsSmallHeader = {
									name = "|cff00ff00" .. L["Quest Notifications"] .. "|r",
									width = "full",
									type = "description",
									order = 26,
								},
								ShowQuestCompletesAndFailsToggle = {
									name = L["Output Complete and Failed messages for quests"],
									desc = L["Displays '<Quest Title> (Complete)' etc messages once you finish all objectives"],
									type = "toggle",
									width = "full",
									get = function() return db.Notifications.ShowQuestCompletesAndFails end,
									set = function()
										db.Notifications.ShowQuestCompletesAndFails = not db.Notifications.ShowQuestCompletesAndFails
									end,
									order = 27,
								},
								ShowMessageOnPickingUpQuestItemToggle = {
									name = L["Show message when picking up an item that starts a quest"],
									desc = L["Displays a message through LibSink when you pick up an item that starts a quest"],
									type = "toggle",
									width = "full",
									get = function() return db.Notifications.ShowMessageOnPickingUpQuestItem end,
									set = function()
										db.Notifications.ShowMessageOnPickingUpQuestItem = not db.Notifications.ShowMessageOnPickingUpQuestItem
									end,
									order = 28,
								},
								DisableToastsToggle = {
									name = L["Disable Toast popups on completing bonus objectives"],
									desc = L["Disables the Toasts which appear upon completing a bonus objective"],
									type = "toggle",
									width = "full",
									get = function() return db.Notifications.DisableToasts end,
									set = function()
										db.Notifications.DisableToasts = not db.Notifications.DisableToasts
									end,
									order = 29,
								},

								LibSinkColourSmallHeaderSpacer = {
									name = "",
									width = "full",
									type = "description",
									order = 50,
								},
								LibSinkColourSmallHeader = {
									name = "|cff00ff00" .. L["Colour Settings"] .. "|r",
									width = "full",
									type = "description",
									order = 51,
								},
								NotificationsColourSelect = {
									name = L["Lib Sink Colour by:"],
									desc = L["The setting by which the colour of notification messages are determined"],
									type = "select",
									order = 52,
									values = dicNotificationColourOptions,
									get = function() return db.Notifications.LibSinkColourSetting end,
									set = function(info, value)
										db.Notifications.LibSinkColourSetting = value
									end,
								},
								NotificationsColour = {
									name = L["Notifications"],
									desc = L["Sets the color for notifications"],
									type = "color",
									hasAlpha = true,
									get = function() return db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b, db.Colours.NotificationsColour.a end,
									set = function(_,r,g,b,a)
											db.Colours.NotificationsColour.r = r
											db.Colours.NotificationsColour.g = g
											db.Colours.NotificationsColour.b = b
											db.Colours.NotificationsColour.a = a
										end,
									order = 53,
								},
								SoundSettingsHeaderSpacer = {
									name = "",
									width = "full",
									type = "description",
									order = 80,
								},
								SoundSettingsHeader = {
									name = SOUND_OPTIONS,
									type = "header",
									order = 81,
								},
								ObjectiveDoneSoundSelect = {
									name = L["Objective Completion Sound"], 
									desc = L["The sound played when you complete a quests objective"],
									type = "select", 
									dialogControl = "LSM30_Sound", 
									values = AceGUIWidgetLSMlists.sound, 
									get = function() return db.Notifications.ObjectiveDoneSound end,
									set = function(info, value)
										db.Notifications.ObjectiveDoneSound = value
									end,
									order = 82
								},
								ObjectiveChangedSoundSelect = {
									name = L["Objective Changed Sound"], 
									desc = L["The sound played when a quests objective changes"],
									type = "select", 
									dialogControl = "LSM30_Sound", 
									values = AceGUIWidgetLSMlists.sound, 
									get = function() return db.Notifications.ObjectiveChangedSound end,
									set = function(info, value)
										db.Notifications.ObjectiveChangedSound = value
									end,
									order = 83
								},
								QuestDoneSoundSelect = {
									name = L["Quest Completion Sound"], 
									desc = L["The sound played when you complete a quest (Finish all objectives)"],
									type = "select", 
									dialogControl = "LSM30_Sound", 
									values = AceGUIWidgetLSMlists.sound, 
									get = function() return db.Notifications.QuestDoneSound end,
									set = function(info, value)
										db.Notifications.QuestDoneSound = value
									end,
									order = 84
								},
								QuestItemFoundSoundSelect = {
									name = L["Quest Starting Item Picked Up"], 
									desc = L["The sound played when you pickup an item that starts a quest"],
									type = "select", 
									dialogControl = "LSM30_Sound", 
									values = AceGUIWidgetLSMlists.sound, 
									get = function() return db.Notifications.QuestItemFoundSound end,
									set = function(info, value)
										db.Notifications.QuestItemFoundSound = value
									end,
									order = 85
								},
							}
						},
						NotificationsOptions = QuestTracker:GetSinkAce3OptionsDataTable(),
					}
				},
			}
		}
	end

	return options
end



--Sorting
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function zoneSortChooser(t)
	return spairs(t, function(t,a,b) 
		if (a and b) then
			if (t[a].ID and t[a].ID == campaignZoneID) then
				return true
			end
			if (t[b].ID and t[b].ID == campaignZoneID) then
				return false
			end
			if (t[a].IsFakeZone == true or t[b].IsFakeZone == true) then
				return tostring(t[b].IsFakeZone) > tostring(t[a].IsFakeZone)			
			else
				return b > a
			end
		end
	end);
end

local function questSortChooser(t)
	if (db.ZonesAndQuests.QuestSortOrder == "Default") then
		return pairs(t);
	end
	if (db.ZonesAndQuests.QuestSortOrder == "Title") then
		return spairs(t, function(t,a,b) 
			return t[b].Title > t[a].Title 
		end);
	end
	if (db.ZonesAndQuests.QuestSortOrder == "Level") then
		return spairs(t, function(t,a,b) 
			return t[b].Level > t[a].Level 
		end);
	end
	if (db.ZonesAndQuests.QuestSortOrder == "POI") then
		return spairs(t, function(t,a,b) 
			return t[b].POIText > t[a].POIText 
		end);
	end
	if (db.ZonesAndQuests.QuestSortOrder == "Proximity") then
		if (InCombatLockdown()) then
			return spairs(t, function(t,a,b) 
				return t[b].LastSortIndex > t[a].LastSortIndex 
			end);
		end
		return spairs(t, function(t,a,b) 
			return t[b].Distance > t[a].Distance 
		end);
	end
	if (db.ZonesAndQuests.QuestSortOrder == "Completion") then
		return spairs(t, function(t,a,b) 
			if (t[b].IsComplete == false and t[a].IsComplete == false) then
				return t[b].ObjectiveCount < t[a].ObjectiveCount;
			end
			return tostring(t[b].IsComplete) > tostring(t[a].IsComplete);
			--return tostring(t[b].IsComplete) > tostring(t[a].IsComplete) 
		end);
	end
	return pairs(t);
end


--Classes
local SQLQuestTimer = {};
SQLQuestTimer.__index = SQLQuestTimer; 

function SQLQuestTimer:new(duration, elasped) 
	local self = {};
	setmetatable(self, SQLQuestTimer);

	self.Duration = duration;
	self.Elasped = elasped;
	self.TimeLeft = 0;
	self.Running = false;

	self:Start();
	return self;
end

function SQLQuestTimer:Start()
	self.Running = false;
	self.TimeLeft = self.Duration;
	if (self.Duration > self.Elasped) then
		self.Running = true;
	end
end

function SQLQuestTimer:Stop()
	self.Duration = 0;
	self.Elasped = 0;
	self.Running = false;
	self.TimeLeft = 0;
end

function SQLQuestTimer:Refresh(elasped)
	self.Elasped = elasped;
	self.TimeLeft = self.Duration - self.Elasped;

	if (self.TimeLeft > 0) then
		self.Running = true;
	else
		self.Duration = 0;
		self.Elasped = 0;
		self.Running = false;
		self.TimeLeft = 0;
	end
end

function SQLQuestTimer:Update(elasped)
	self.Elasped = self.Elasped + elasped;
	self.TimeLeft = self.Duration - self.Elasped;

	if (self.TimeLeft > 0) then
		self.Running = true;
	else
		self.Duration = 0;
		self.Elasped = 0;
		self.Running = false;
		self.TimeLeft = 0;
	end
end



local SQLObjective = {};
SQLObjective.__index = SQLObjective; 

function SQLObjective:new(objectiveIndex, questIndex, questID) 
	local self = {};
	setmetatable(self, SQLObjective);

	self.Index = objectiveIndex;
	self.QuestIndex = questIndex
	self.QuestID = questID;
	self.Text = nil;
	self.Have = nil;
	self.Need = nil;
	self.CompletionLevel = 0;
	self.Type = nil;
	self.IsComplete = false;

	self.Changed = false;
	self._Valid = false;

	if (self.Index ~= nil and self.QuestIndex ~= nil) then
		self:Update();
	end

	if (self._Valid == true) then
		self.Changed = false;
		return self;
	else
		return nil;
	end
end

function SQLObjective:Update()
	self.Changed = false;
	local text, objectiveType, finished, have, need = GetQuestObjectiveInfo(self.QuestID, self.Index, false);
	

	
	self.Type = objectiveType;	

	if (finished == true) then
		if (self.IsComplete == false) then
			self.Changed = true;	
		end
		self.IsComplete = true;
	else 
		if (self.IsComplete == true) then
			self.Changed = true;	
		end
		self.IsComplete = false;
	end

	if (text ~= nil) then
		self.Text = text;
		local completionLevel = 0;
		local intGot = 0;
		local intNeed = 1;
		
		if (self.Type == "reputation") then
			local y, z, repuationHave, reputationNeed,objectiveDescription  = string.find(self.Text, "(.*)%s*/%s*(%S*)%s*(.*)");

			if (objectiveDescription == "") then
				y, z, objectiveDescription, repuationHave, reputationNeed = string.find(self.Text, "(.*):%s*([-%d]+)/([-%d]+)$");
			end

			if (objectiveDescription ~= nil) then 
				self.Text = objectiveDescription 
			end

			if (repuationHave == nil) then 
				have = ""
			else 
				have = strtrim(repuationHave) 
			end

			if (reputationNeed == nil) then 
				need = "" 
			else 
				need = strtrim(reputationNeed) 
			end

			for k, RepInstance in pairs(dicRepLevels) do
				if (have == RepInstance["MTitle"] or have == RepInstance["FTitle"]) then
					intGot = RepInstance["Value"]
				end
				if (need == RepInstance["MTitle"] or need == RepInstance["FTitle"]) then
					intNeed = RepInstance["Value"]
				end
			end
			intGot = tonumber(intGot);
			intNeed = tonumber(intNeed);
			if not(intGot) then
				intGot = 0;
			end
			if not(intNeed) then
				intNeed = 1;
			end
			completionLevel = intGot / intNeed;
		else
			local y, z, intGot, intNeeded, objectiveDescription = string.find(self.Text, "([-%d]+)/([-%d]+)%s*(.*)$");
			if (objectiveDescription == "") then
				y, z, objectiveDescription, intGot, intNeeded = string.find(self.Text, "(.*):%s*([-%d]+)/([-%d]+)$");
			end

			if (objectiveDescription ~= nil) then 
				self.Text = objectiveDescription 
			end

			completionLevel = have / need;
		end

		if (self.IsComplete == true) then
			completionLevel = 1;
		end

		if (self.Have ~= have) then
			local canChange = true;
			if (self.Have and need) then
				if ((tonumber(self.Have) and tonumber(need)) and (tonumber(self.Have) >= tonumber(need))) then
					canChange = false;	
				end	
			end		
			if (canChange) then
				self.Changed = true;
			end
			self.Have = have;
		end

		if (self.Need ~= need) then
			self.Need = need;
			self.Changed = true;
		end

		if (self.CompletionLevel ~= completionLevel) then
			self.CompletionLevel = completionLevel;
			self.Changed = true;
		end

		self._Valid = true;
	end
end

function SQLObjective:Render()
	local strObjectiveGradualColour = "|cffffffff"
	local strObjectiveTitleColourOutput = strObjectiveTitleColour
	local strObjectiveStatusColourOutput = strObjectiveStatusColour
	local strOutput ="";

	-- If somethings uses gradual colours get colour
	if (db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Completion" or db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Completion") then
		strObjectiveGradualColour = QuestTracker:GetCompletionColourString(self.CompletionLevel)
	end
	
	-- Decide on quest title colour
	if (db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Completion") then
		strObjectiveTitleColourOutput = strObjectiveGradualColour
	elseif (db.ZonesAndQuests.ObjectiveTitleColouringSetting == "Done/Undone") then
		if (self.IsComplete == false) then
			strObjectiveTitleColourOutput = strUndoneColour
		else
			strObjectiveTitleColourOutput = strDoneColour
		end
	end	

	-- Decide on quest status (0/1 etc) colour
	if (db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Completion") then
		strObjectiveStatusColourOutput = strObjectiveGradualColour
	elseif (db.ZonesAndQuests.ObjectiveStatusColouringSetting == "Done/Undone") then
		if (self.IsComplete == false) then
			strObjectiveStatusColourOutput = strUndoneColour
		else
			strObjectiveStatusColourOutput = strDoneColour
		end
	end				
	
	
	-- Depending on quest type display it in a certain way
	if (self.Type == nil) then
		strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r"		
		
	elseif (self.Type == "event") then
		if (self.IsComplete == false) then
			strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r"
		else
			strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r" .. strObjective100Colour .. " (Done)|r"
		end
		
	elseif (self.Type == "log" or self.Type == "progressbar") then
		strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r"
		
	elseif (self.Type == "reputation") then
		if ((self.Have == 0 and self.Need == 0) or (self.Have == '' and self.Need == '') or (self.Have == nil and self.Need == nil)) then
			if (self.IsComplete == false) then
				strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r"
			else
				strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r" .. strObjective100Colour .. " (Done)|r"
			end
		else
			if (db.ZonesAndQuests.ObjectiveTextLast == true) then
				strOutput = strObjectiveStatusColourOutput .. " - "..  self.Have .. " / " .. self.Need .. "|r" .. " " .. strObjectiveTitleColourOutput  .. self.Text .. "|r"
			else
				strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. ": |r" .. strObjectiveStatusColourOutput .. self.Have .. " / " .. self.Need .. "|r"
			end
		end					
	elseif (self.IsComplete == false and self.Have == self.Need) then
		strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. "|r" 
	
	else
		if (db.ZonesAndQuests.ObjectiveTextLast == true) then
			strOutput = strObjectiveStatusColourOutput .. " - " .. self.Have .. "/" .. self.Need .. "|r" .. strObjectiveTitleColourOutput .. " " .. self.Text .. "|r";
		else
			strOutput = strObjectiveTitleColourOutput .. " - " .. self.Text .. ": |r" .. strObjectiveStatusColourOutput .. self.Have .. "/" .. self.Need .. "|r"
		end
	end
	
	return strOutput;
end


local SQLItem = {};
SQLItem.__index = SQLItem; 

function SQLItem:new(questIndex) 
	local self = {};
	setmetatable(self, SQLItem);

	self.QuestIndex = questIndex;

	self.Link = nil;
	self.Item = nil;
	self.Charges = 0;
	self.ItemID = nil;
	self.ShowWhenComplete = false;
	self.Changed = false;
	self.Valid = false;
	self.StillValid = true;

	self:Update();

	if (self.Valid == true) then
		self.Changed = true;
		return self;
	else
		return nil;
	end
end

function SQLItem:Update(newIndex)
	self.Changed = false;

	if (newIndex) then
		self.QuestIndex = newIndex;
	end

	local link, icon, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(self.QuestIndex)
	
	if (icon ~= nil) then
		local itemID = link:match("Hitem:(%d+):");
		if (self.ItemID ~= itemID) then
			self.ItemID = itemID;
			self.Changed = true;
		end

		if (self.Charges ~= charges) then
			self.Charges = charges;
			self.Changed = true;
		end

		self.ShowWhenComplete = showItemWhenComplete;
		self.Link = link;
		self.Item = icon
		self.Valid = true;
	else
		self.Valid = false;
	end
end


local SQLQuest = {};
SQLQuest.__index = SQLQuest; 

function SQLQuest:new(questIndex, questID, isWorldQuest) 
	local self = {};
	setmetatable(self, SQLQuest);

	self.Index = questIndex;
	self.ID = questID;
	self.Title = nil;
	self.Level = nil;
	self.SuggestedGroup = nil;
	self.Frequency = nil;
	
	self.HaveLocalPOI = false;
	self.DisplayQuestID = false;
	self.IsComplete = false;
	self.IsFailed = false;
	self.IsOnMap = false;
	self.IsTask = false;
	self.IsWorldQuest = isWorldQuest;
	self.IsStory = false;
	self.StartsEvent = false;
	self.IsHidden = false;
	self.IsBreadcrumb = false;
	self.RequiredMoney = 0;
	self.LastSortIndex = 0;

	self.Timer = nil;

	self.TagID = nil;
	self.TagName = nil;
	self.QuestItem = nil;
	self.ObjectiveCount = 0;
	self.ObjectiveList = {};
	self.ObjectiveDescription = "";
	self.CompletionText = "";
	self.POIText = "";
	self.Distance = 0;
	self.ProgressBarPercent = 0;
	self.HasProgressBar = false;
	self.DataChanged = true;
	self.Changed = true;
	self.Keep = true;
	self._Valid = false;
	
	self._ChangedValid = false;
	self._CompletionLevel = 0;
	self._CompletionLevelValid = false;
	self._FirstUpdate = true;


	if (self.Index ~= nil) then
		self:Update();
	end	

	if (self._Valid == true) then
		self.Changed = false;
		self.DataChanged = false;		
		return self;
	else
		return nil;
	end
end

function SQLQuest:Update(newIndex)
	self.Changed = false;
	self.DataChanged = false;
	self.Keep = true;
	self._CompletionLevelValid = false;

	if (newIndex) then
		self.Index = newIndex;
		for i, objective in ipairs(self.ObjectiveList) do
	    	objective.QuestIndex = self.Index;
		end
	end

	if (self.IsWorldQuest) then
		
		local isInArea, isOnMap, numObjectives, taskName, displayAsObjective = GetTaskInfo(self.ID);
		local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(self.ID);
		self.TagID = tagID;
		if (isElite) then
			self.TagID = ELITE
		end
		self.TagName = tagName;		
		self.Index = GetQuestLogIndexByID(self.ID);
		
		self.Title = taskName;
		if (self.Title == nil) then
			self.Title = UNKNOWN
		end

		if (self._FirstUpdate) then
			self.RequiredMoney = 0;
			self.ObjectiveDescription = "";
			
			self.Level = dicZoneLevels[zoneID] or 120;
			self.SuggestedGroup = 0;
			self.Frequency = frequency;

			if (isOnMap) then
				self.IsOnMap = true;
			end
			
			self.IsTask = true;
		end

		if not(self.QuestItem) then
			self.QuestItem = SQLItem:new(self.Index);
			if (self.QuestItem) then
				self.Changed = true;
				self.DataChanged = true;
			end
		else 
			self.QuestItem:Update(self.Index);
			if (self.QuestItem.Valid == false) then
				self.QuestItem = nil;
				self.Changed = true;
				self.DataChanged = true;
			else
				if (self.QuestItem.Changed == true) then
					self.Changed = true;
					self.DataChanged = true;
				end
			end
		end
		
		if (isComplete == nil) then
			if (self.IsComplete == true or self.IsFailed == true) then
				self.Changed = true;
				self.DataChanged = true;
			end
			self.IsComplete = false;
			self.IsFailed = false;
		
		elseif (isComplete == 1) then
			if (self.IsComplete == false or self.IsFailed == true) then
				self.Changed = true;
				self.DataChanged = true;

				if (db.ZonesAndQuests.HideCompletedQuests == true and self._FirstUpdate == false) then
					self:Hide();
				end
			end
			self.IsComplete = true;
			self.IsFailed = false;
		else 
			if (self.IsComplete == true or self.IsFailed == false) then
				self.Changed = true;
				self.DataChanged = true;
			end
			self.IsComplete = false;
			self.IsFailed = true;
		end

		self.HasProgressBar = false;
		local tmpObjectives = {}
		if (numObjectives and (self.ObjectiveCount == 0 or numObjectives ~= self.ObjectiveCount)) then
			for objectiveIndex = 1, numObjectives, 1 do
				local objective = SQLObjective:new(objectiveIndex, self.Index, self.ID);
				if (objective) then
					tinsert(tmpObjectives, objective);
				end
			end
		end
		if (self.ObjectiveCount ~= #tmpObjectives and #tmpObjectives > 0) then
			self:ClearObjectives();
			for objectiveIndex = 1, #tmpObjectives, 1 do
				local objective = tmpObjectives[objectiveIndex]
				self:AddObjective(objective);
				if (objective.Type == "progressbar") then
					self.HasProgressBar = true;
				end
				self.Changed = true;
				self.DataChanged = true;
			end
		else		
			for i, objective in ipairs(self.ObjectiveList) do
				objective:Update();
				if (objective.Type == "progressbar") then
					self.HasProgressBar = true;
				end
				if (objective.Changed == true) then
					self.Changed = true;
					self.DataChanged = true;
				end
			end
		end
		
		
		if (self.HasProgressBar == true) then
			self.ProgressBarPercent = GetQuestProgressBarPercent(self.ID);
		end


		if (self.ObjectiveCount == 0) then
			if (db.ZonesAndQuests.HideCompletedQuests == true and self._FirstUpdate == true) then
				self:Hide();
			end
		end

		self.POIText = "";
		for i=0, #tblPOIs, 1 do
			if (tblPOIs[i] == self.ID) then
				if ( self.IsComplete == true or self.ObjectiveCount == 0) then
					self.POIText = "?";
				else
					self.POIText = tostring(i);
				end
			end
		end

		self.Distance = 0;
		self._FirstUpdate = false;
		self._Valid = true;	

	
	else	
		local title, level, suggestedGroup, isHeader, _, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(self.Index);	
		local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questID);
		self.TagID = tagID;
		self.TagName = tagName;		
		
		self.Title = title;
		if (self.Title == nil) then
			self.Title = UNKNOWN
		end

		if (self._FirstUpdate) then
			SelectQuestLogEntry(self.Index);			
			local _, questObjectives = GetQuestLogQuestText();
			self.RequiredMoney = GetQuestLogRequiredMoney(self.Index);

			self.ObjectiveDescription = questObjectives;
			


			self.Level = level;
			self.SuggestedGroup = suggestedGroup;
			self.Frequency = frequency;


			if (startEvent) then
				self.StartsEvent = true;
			end

			if (displayQuestID) then
				self.DisplayQuestID = true;
			end

			if (isOnMap) then
				self.IsOnMap = true;
			end

			if (hasLocalPOI) then
				self.HaveLocalPOI = true;
			end

			if (isTask) then
				self.IsTask = true;
			end

			if (isStory) then
				self.IsStory = true;
			end
		end
		local numObjectives = GetNumQuestLeaderBoards(self.Index);


		if not(self.QuestItem) then
			self.QuestItem = SQLItem:new(self.Index);
			if (self.QuestItem) then
				self.Changed = true;
				self.DataChanged = true;
			end
		else 
			self.QuestItem:Update(self.Index);
			if (self.QuestItem.Valid == false) then
				self.QuestItem = nil;
				self.Changed = true;
				self.DataChanged = true;
			else
				if (self.QuestItem.Changed == true) then
					self.Changed = true;
					self.DataChanged = true;
				end
			end
		end
		
		if (self.IsTask ~= true) then
			local isWatched = IsQuestWatched(self.Index);		
			if (isWatched == nil) then
				if (self.IsHidden == false) then
					self:Hide();
				end
			else
				if (self.IsHidden == true) then
					self:Show();
				end
			end
		end


		self.IsBreadcrumb = false;
		if (not( isComplete and isComplete < 0 )) then
			if ( numObjectives == 0 and playerMoney >= self.RequiredMoney and not self.StartsEvent) then
				if ( self.RequiredMoney == 0 ) then
					self.IsBreadcrumb = true;
					self.CompletionText = GetQuestLogCompletionText(self.Index);
				end
			end
		end

		if (isComplete == nil) then
			if (self.IsComplete == true or self.IsFailed == true) then
				self.Changed = true;
				self.DataChanged = true;
			end
			self.IsComplete = false;
			self.IsFailed = false;
		
		elseif (isComplete == 1) then
			if (self.IsComplete == false or self.IsFailed == true) then
				self.Changed = true;
				self.DataChanged = true;

				if (db.ZonesAndQuests.HideCompletedQuests == true and self._FirstUpdate == false) then
					self:Hide();
				end
			end
			self.IsComplete = true;
			self.IsFailed = false;
		else 
			if (self.IsComplete == true or self.IsFailed == false) then
				self.Changed = true;
				self.DataChanged = true;
			end
			self.IsComplete = false;
			self.IsFailed = true;
		end


		self.HasProgressBar = false;
		local tmpObjectives = {}
		if (self.ObjectiveCount == 0 or numObjectives ~= self.ObjectiveCount) then
			for objectiveIndex = 1, numObjectives, 1 do
				local objective = SQLObjective:new(objectiveIndex, self.Index, self.ID);
				if (objective) then
					tinsert(tmpObjectives, objective);
				end
			end
		end
		if (self.ObjectiveCount ~= #tmpObjectives and #tmpObjectives > 0) then
			self:ClearObjectives();
			for objectiveIndex = 1, #tmpObjectives, 1 do
				local objective = tmpObjectives[objectiveIndex]
				self:AddObjective(objective);
				if (objective.Type == "progressbar") then
					self.HasProgressBar = true;
				end
			end
		else		
			for i, objective in ipairs(self.ObjectiveList) do
				objective:Update();
				if (objective.Type == "progressbar") then
					self.HasProgressBar = true;
				end
				if (objective.Changed == true) then
					self.Changed = true;
					self.DataChanged = true;
				end
			end
		end
		
										
		if (self.HasProgressBar == true) then
			self.ProgressBarPercent = GetQuestProgressBarPercent(self.ID);
		end


		if (self.ObjectiveCount == 0) then
			if (db.ZonesAndQuests.HideCompletedQuests == true and self._FirstUpdate == true) then
				self:Hide();
			end
		end

		self.POIText = "";
		for i=0, #tblPOIs, 1 do
			if (tblPOIs[i] == self.ID) then
				if ( self.IsComplete == true or self.ObjectiveCount == 0) then
					self.POIText = "?";
				else
					self.POIText = tostring(i);
				end
			end
		end

		self.Distance = 0;
		if (db.ZonesAndQuests.QuestSortOrder == "Proximity") then
			local distanceSq, onContinent = GetDistanceSqToQuest(self.Index)
			if(onContinent) then
				self.Distance =  distanceSq;
			end
		end

		self._FirstUpdate = false;
		self._Valid = true;
		
	end



	return self;
end

function SQLQuest:Render()
	local strLevelColor = ""
	local strTitleColor = ""
	

	-- Get quest level colour
	if (db.ZonesAndQuests.QuestLevelColouringSetting == "Level") then
		local objColour = GetQuestDifficultyColor(self.Level);	
		strLevelColor = format("|c%02X%02X%02X%02X", 255, objColour.r * 255, objColour.g * 255, objColour.b * 255);
	
	elseif (db.ZonesAndQuests.QuestLevelColouringSetting == "Completion") then
		strLevelColor = QuestTracker:GetCompletionColourString(self:CompletionLevel())
	
	elseif (db.ZonesAndQuests.QuestLevelColouringSetting == "Done/Undone") then
		if (self.IsComplete == true) then
			strLevelColor = strDoneColour
		else

			strLevelColor = strUndoneColour
		end
	
	else
		strLevelColor = strQuestLevelColour
	end
	
	-- Get quest title colour
	if (db.ZonesAndQuests.QuestTitleColouringSetting == "Level") then
		local objColour = GetQuestDifficultyColor(self.Level);	
		strTitleColor = format("|c%02X%02X%02X%02X", 255, objColour.r * 255, objColour.g * 255, objColour.b * 255);
	
	elseif (db.ZonesAndQuests.QuestTitleColouringSetting == "Completion") then
		strTitleColor = QuestTracker:GetCompletionColourString(self:CompletionLevel())
	
	elseif (db.ZonesAndQuests.QuestTitleColouringSetting == "Done/Undone") then
		if (self.IsComplete == true) then
			strTitleColor = strDoneColour
		else
			strTitleColor = strUndoneColour
		end
	
	else
		strTitleColor = strQuestTitleColour
	end
		
	local strQuestReturnText = ""
	local blnShowBrackets = false
	local blnFirstThing = true



	if (db.ZonesAndQuests.DisplayPOITag == true) then
		if (self.POIText ~= nil and self.POIText ~= "") then
			strQuestReturnText = strQuestReturnText .. self.POIText .. " "
		end
	end

	-- Quest level
	if (db.ZonesAndQuests.ShowQuestLevels == true) then
		strQuestReturnText = strQuestReturnText .. self.Level
		blnShowBrackets = true
		blnFirstThing = false
	end




	

	--PVP, RAID, Group, etc tags
	if (self.TagID) then
		if (db.ZonesAndQuests.QuestTagsLength == "Full" and dicLongQuestTags[self.TagID] ~= nil) then
			if (blnFirstThing == true) then
				strQuestReturnText = strQuestReturnText .. dicLongQuestTags[self.TagID]
			else
				strQuestReturnText = strQuestReturnText .. " " .. dicLongQuestTags[self.TagID]
			end
			
			blnShowBrackets = true
			blnFirstThing = false
		elseif (db.ZonesAndQuests.QuestTagsLength == "Short" and dicQuestTags[self.TagID] ~= nil) then
			strQuestReturnText = strQuestReturnText .. dicQuestTags[self.TagID]
			blnShowBrackets = true
			blnFirstThing = false
		end		
	end
	
	if (self.SuggestedGroup > 0 and db.ZonesAndQuests.QuestTagsLength ~= "None") then
		strQuestReturnText = strQuestReturnText .. self.SuggestedGroup
		blnShowBrackets = true
		blnFirstThing = false
	end

	if (self:IsDaily() == true) then
		if (db.ZonesAndQuests.QuestTagsLength == "Full") then
			if (blnFirstThing == true) then
				strQuestReturnText = strQuestReturnText .. dicLongQuestTags["Daily"]
			else
				strQuestReturnText = strQuestReturnText .. " " .. dicLongQuestTags["Daily"]
			end
			blnShowBrackets = true
		elseif (db.ZonesAndQuests.QuestTagsLength == "Short") then
			strQuestReturnText = strQuestReturnText .. dicQuestTags["Daily"]
			blnShowBrackets = true
		end
	end
	
	if (self:IsWeekly() == true) then
		if (db.ZonesAndQuests.QuestTagsLength == "Full") then
			if (blnFirstThing == true) then
				strQuestReturnText = strQuestReturnText .. dicLongQuestTags["Weekly"]
			else
				strQuestReturnText = strQuestReturnText .. " " .. dicLongQuestTags["Weekly"]
			end
			blnShowBrackets = true
		elseif (db.ZonesAndQuests.QuestTagsLength == "Short") then
			strQuestReturnText = strQuestReturnText .. dicQuestTags["Weekly"]
			blnShowBrackets = true
		end
	end

	if (db.ZonesAndQuests.ShowQuestLevels == true or db.ZonesAndQuests.QuestTagsLength ~= "None" and blnShowBrackets == true) then
		strQuestReturnText = strLevelColor .. "[" .. strQuestReturnText
		
		strQuestReturnText = strQuestReturnText .. "]|r "
	end
	
	strQuestReturnText = strQuestReturnText .. strTitleColor .. self.Title .. "|r"

	-- Completion/failed etc tag
	if (self.IsFailed == true) then 
		strQuestReturnText = strQuestReturnText .. strQuestStatusFailed .. L[" (Failed)"] .. "|r"
	elseif (self.IsComplete == true) then
		strQuestReturnText = strQuestReturnText .. strQuestStatusDone .. L[" (Done)"] .. "|r"
	elseif (self.ObjectiveCount == 0) then
		strQuestReturnText = strQuestReturnText .. strQuestStatusGoto .. L[" (goto)"] .. "|r"
	end
	
	-- Hidden tag
	if (self.IsHidden == true and db.ZonesAndQuests.AllowHiddenQuests == true) then
		strQuestReturnText = strQuestReturnText .. strHeaderColour .. L[" (Hidden)"] .. "|r"
	end 
	
	local strObjectivesReturnText = ""
	
	-- Objectives
	if (self.ObjectiveCount == 0) then
		-- If no objective and show descriptions on display quest description
		local renderText = self.ObjectiveDescription;
		if (self.IsBreadcrumb == true) then
			renderText = self.CompletionText;
		end
		if (renderText == nill) then
			renderText = "";
		end
		if (db.ZonesAndQuests.ShowDescWhenNoObjectives == true) then
			if (not(self.IsComplete == true)) then
				strObjectivesReturnText = strObjectivesReturnText .. strObjectiveDescriptionColour .. " - " .. renderText .. "|r\n"
			else
				if (db.ZonesAndQuests.HideCompletedObjectives == false) then
					strObjectivesReturnText = strObjectivesReturnText .. strObjectiveDescriptionColour .. " - " .. renderText .. "|r\n"
				end
			end	
		end
	else
		if (self.IsComplete == false) then
			-- For each objective in quest
			for k, ObjectiveInstance in pairs(self.ObjectiveList) do
				if not(db.ZonesAndQuests.HideCompletedObjectives == true and ObjectiveInstance.IsComplete == true) then
					strObjectivesReturnText = strObjectivesReturnText .. ObjectiveInstance:Render() .. "\n";	
				end
			end
		end
	end

	
	strQuestReturnText = strtrim(strQuestReturnText)
	strObjectivesReturnText = strtrim(strObjectivesReturnText)
	return strQuestReturnText, strObjectivesReturnText
end

function SQLQuest:Hide()
	self.IsHidden = true;
	self.Changed = true;
	RemoveQuestWatch(self.Index)
end

function SQLQuest:Show()
	self.IsHidden = false;
	self.Changed = true;
	AddQuestWatch(self.Index)
end

function SQLQuest:IsDaily()
	if (self.Frequency == 2) then
		return true;
	end
	return false;
end

function SQLQuest:IsWeekly()
	if (self.Frequency == 3) then
		return true;
	end
	return false;
end

function SQLQuest:AddObjective(objective)
	self.Changed = true;
	self.DataChanged = true;
	self.ObjectiveCount = self.ObjectiveCount + 1;
	tinsert(self.ObjectiveList, objective);
	self._CompletionLevelValid = false;
end

function SQLQuest:ClearObjectives()
	self.Changed = true;
	self.DataChanged = true;
	self.ObjectiveCount = 0;
	self.ObjectiveList = {};
	self._CompletionLevelValid = false;
end

function SQLQuest:CompletionLevel()
	if (self._CompletionLevelValid == false) then
		if (self.ObjectiveCount == 0) then
			self._CompletionLevel = 1;
		else 
			local totalCompletion = 0;
			local usedObjectives = 0;
			for i, objective in ipairs(self.ObjectiveList) do
		    	totalCompletion = totalCompletion + objective.CompletionLevel;
		    	usedObjectives = usedObjectives + 1;
			end
			self._CompletionLevel = totalCompletion / usedObjectives;
		end
		self._CompletionLevelValid = true;
	end
	return self._CompletionLevel;
end


local SQLZone = {};
SQLZone.__index = SQLZone; 


function SQLZone:new(zoneIndex, fakeZone, id, title) 
	local self = {};
	setmetatable(self, SQLZone);

	self.Index = zoneIndex;
	self.IsFakeZone = false;
	self.ID = nil;
	self.Title = nil;
	self.IsCollapsed = false;

	self.QuestCount = 0;
	self._CompletedQuestCount = 0;
	self.QuestList = {};

	self._HiddenQuestCount = 0;
	self._Changed = true;
	self._Valid = false;


	if (fakeZone) then
		self.IsFakeZone = true;
		self.ID = id;
		self.Title = title;
	end

	if (self.Index ~= nil) then
		self:Update();
	end

	if (self._Valid == true) then
		self._Changed = true;
		return self;
	else
		return nil;
	end
end

function SQLZone:Update(newIndex)
	self._Changed = false;

	if (self.IsFakeZone == true) then
		self._Valid = true;
		return;
	end

	if (newIndex ~= nil) then
		self.Index = newIndex;
	end

	local title, _, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(self.Index);
	
	if (isHeader) then
		self.Title = title;
		self.ID = title;
		if (self.Title == nil) then
			self.Title = UNKNOWN;
		end		

		self._Valid = true;
	end
end

function SQLZone:AddQuest(quest)
	if (self.QuestList[quest.ID] == nil) then
		self.QuestCount = self.QuestCount + 1;
		self.QuestList[quest.ID] = quest
		self._HiddenQuestCountValid = false;
		self._ChangedValid = false;
	end

end

function SQLZone:RemoveQuest(quest)
	if (self.QuestList[quest.ID] ~= nil) then
		self.QuestCount = self.QuestCount - 1;
		self.QuestList[quest.ID] = nil;
		self._HiddenQuestCountValid = false;
		self._ChangedValid = false;
	end 
end

function SQLZone:ClearQuests()
	self.QuestCount = 0;
	self.HiddenQuestCount = 0;
	self.QuestList = {};	
	self._HiddenQuestCountValid = false;
	self._ChangedValid = false;
end

function SQLZone:Changed()
	for i, quest in pairs(self.QuestList) do
    	if (quest.Changed == true) then
    		self._Changed = true;
    	end
	end
	return self._Changed;
end

function SQLZone:Collapse()
	dbChar.ZoneIsCollapsed[self.ID] = true;
	self._Changed = true;
end

function SQLZone:Expand()
	dbChar.ZoneIsCollapsed[self.ID] = false;
	self._Changed = true;
end

function SQLZone:CompletedQuestCount()
	self._CompletedQuestCount = 0;
	for i, quest in pairs(self.QuestList) do
    	if (quest.IsComplete == true) then
    		self._CompletedQuestCount = self._CompletedQuestCount + 1;
    	end
	end

	return self._CompletedQuestCount;
end

function SQLZone:HiddenQuestCount()
	self._HiddenQuestCount = 0;
	for i, quest in pairs(self.QuestList) do
    	if (quest.IsHidden == true or (quest.IsTask == true and self.IsFakeZone == false)) then
    		self._HiddenQuestCount = self._HiddenQuestCount + 1;
    	end
	end

	return self._HiddenQuestCount;
end

function SQLZone:HaveVisibleQuests()
	if (self:HiddenQuestCount() >= self.QuestCount) then
		return false;
	end
	return true;
end

local SQLQuestLogData = {};
SQLQuestLogData.__index = SQLQuestLogData; 


function SQLQuestLogData:new() 
	local self = {};
	setmetatable(self, SQLQuestLogData);

	self.FirstUpdate = true;
	self.EntryCount = 0;
	self.HaveTrackedQuests = false;

	self.ZoneCount = 0;
	self.ZoneList = {};
	
	self.QuestCount = 0;
	self.QuestList = {};
	self.CompletedQuestCount = 0;

	self.CollapsedZoneCount = 0;
	self.HiddenQuestCount = 0;

	self.ZoneList[campaignZoneID] = SQLZone:new(1, true, campaignZoneID, "");
	self.ZoneList[bonusObjectivesZoneID] = SQLZone:new(0, true, bonusObjectivesZoneID, bonusObjectivesZoneTitle);
	self.ZoneList[worldQuestsZoneID] = SQLZone:new(100, true, worldQuestsZoneID, worldQuestsZoneTitle);

	self.Changed = false;
	self:Update();

	return self;
end

function SQLQuestLogData:Update()
	self.Changed = false;
	
	if (timeOfFirstQuestUpdate == 0) then
		timeOfFirstQuestUpdate = GetTime();
	end

	playerMoney = GetMoney();
	local POIs = GetQuestPOIs();
	tblPOIs = {};
	for i=0, #POIs, 1 do
		if (POIs[i]) then
			tblPOIs[i] = POIs[i];
		end
	end



	for i, quest in pairs(self.QuestList) do
    	quest.Keep = false;
	end

	local timers = {GetQuestTimers()};
	local tblTimers = {};
	local trackedTimerCount = 0;

	if (#timers > 0) then
		for i = 1, GetNumQuestWatches() do
			local timerQuestID, _, _, _, _, _, _, _, failureTime, timeElapsed = GetQuestWatchInfo(i);
			if ( not timerQuestID ) then
				break;
			end
			if (failureTime ~= nil and failureTime > 0) then
				if (timeElapsed == nil) then
					timeElapsed = 0;
				end
				tblTimers[timerQuestID] = {['Elapsed'] = timeElapsed, ['Duration'] = failureTime, ['Tracked'] = true}
				trackedTimerCount = trackedTimerCount + 1;
			end
		end
		if (trackedTimerCount < #timers) then
			for i=1,#timers, 1 do
				local index = GetQuestIndexForTimer(i);
				local _, _, _, _, _, _, _, timerQuestID = GetQuestLogTitle(index);	
				tblTimers[timerQuestID] = {['Elapsed'] = 0, ['Duration'] = timers[i], ['Tracked'] = false}
			end
		end
	end

		
		
	local campaignId = C_CampaignInfo.GetCurrentCampaignID();
	if (campaignId) then
		local campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignId);
		self.ZoneList[campaignZoneID].Title = campaignInfo.name or "";
	end
	
	
	
	local numEntries, numQuests = GetNumQuestLogEntries();
	local zoneID = nil;
	for i = 1, numEntries, 1 do
		local title, _, _, isHeader, _, _, _, questID, _, _, isOnMap, _, _, isBounty, _, isHidden = GetQuestLogTitle(i);		

		if (isHeader) then
			zoneID = title;
			if (self.ZoneList[zoneID] == nil) then
				self.ZoneList[zoneID] = SQLZone:new(i);
				self.ZoneCount = self.ZoneCount + 1;
			else
				self.ZoneList[zoneID]:Update(i);
			end
			if (dbChar.ZoneIsCollapsed[zoneID] == true) then
				self.ZoneList[zoneID].IsCollapsed = true;
			else 
				self.ZoneList[zoneID].IsCollapsed = false;
			end
		else
			if (not QuestUtils_IsQuestWorldQuest(questID) and (not isHidden and not isBounty)) then
				if (self.QuestList[questID] == nil) then
					self.QuestList[questID] = SQLQuest:new(i, questID, false);
					self.QuestCount = self.QuestCount + 1;
				else
					self.QuestList[questID]:Update(i);
				end

				if (tblTimers[questID] == nil) then
					self.QuestList[questID].Timer = nil;
				else
					if (self.QuestList[questID].Timer == nil) then
						self.QuestList[questID].Timer = SQLQuestTimer:new(tblTimers[questID].Duration, tblTimers[questID].Elapsed)
					else
						if (tblTimers[questID].Duration > self.QuestList[questID].Timer.Duration) then
							self.QuestList[questID].Timer.Duration = tblTimers[questID].Duration;
						end

						if (tblTimers[questID].Tracked == false) then
							local elapsed = self.QuestList[questID].Timer.Duration - tblTimers[questID].Duration;
							self.QuestList[questID].Timer:Refresh(elapsed);
						else
							self.QuestList[questID].Timer:Refresh(tblTimers[questID].Elapsed);
						end
					end
				end

				if (self.QuestList[questID].IsTask == true) then
					self.ZoneList[bonusObjectivesZoneID]:AddQuest(self.QuestList[questID]);
				else 
					if (self.ZoneList[zoneID] ~= nil) then
						self.ZoneList[zoneID]:AddQuest(self.QuestList[questID]);
					end
				end
				
				if (C_CampaignInfo.IsCampaignQuest(questID)) then
					self.ZoneList[campaignZoneID]:AddQuest(self.QuestList[questID]);
				end 
			
			end
		end
	end


	
	
	local worldQuestIDs = {}
	local tasksTable = GetTasksTable();
	for i = 1, #tasksTable do
		local questID = tasksTable[i];
		if (QuestUtils_IsQuestWorldQuest(questID) and not IsWorldQuestWatched(questID) ) then
			local isInArea = GetTaskInfo(questID);
			if (isInArea) then
				table.insert(worldQuestIDs, questID);
			end
		end
	end
	
	for i = 1, GetNumWorldQuestWatches() do
		local watchedWorldQuestID = GetWorldQuestWatchInfo(i);
		if ( watchedWorldQuestID ) then
			table.insert(worldQuestIDs, watchedWorldQuestID)
		end
	end
	
	for i = 1, #worldQuestIDs do
		local questID = worldQuestIDs[i];
		if (self.QuestList[questID] == nil) then
			self.QuestList[questID] = SQLQuest:new(i, questID, true);
			self.QuestCount = self.QuestCount + 1;
		else
			self.QuestList[questID]:Update(i);
		end
		self.ZoneList[worldQuestsZoneID]:AddQuest(self.QuestList[questID]);
	end

	
	
	if (dbChar.ZoneIsCollapsed[bonusObjectivesZoneID] == true) then
		self.ZoneList[bonusObjectivesZoneID].IsCollapsed = true;
	else 
		self.ZoneList[bonusObjectivesZoneID].IsCollapsed = false;
	end
	if (dbChar.ZoneIsCollapsed[worldQuestsZoneID] == true) then
		self.ZoneList[worldQuestsZoneID].IsCollapsed = true;
	else 
		self.ZoneList[worldQuestsZoneID].IsCollapsed = false;
	end
	if (dbChar.ZoneIsCollapsed[campaignZoneID] == true) then
		self.ZoneList[campaignZoneID].IsCollapsed = true;
	else 
		self.ZoneList[campaignZoneID].IsCollapsed = false;
	end

	self.HiddenQuestCount = 0;
	self.CompletedQuestCount = 0;
	for questKey, quest in pairs(self.QuestList) do
    	if (quest.Keep == false) then
			for zoneKey, zone in pairs(self.ZoneList) do
		    	zone:RemoveQuest(quest);
			end
    		self.QuestList[quest.ID] = nil;
    		self.QuestCount = self.QuestCount - 1;
    		self.Changed = true;
    	else
    		if (quest.IsComplete == true) then
    			self.CompletedQuestCount = self.CompletedQuestCount + 1;
    		end
    		if(quest.IsHidden == true) then
				self.HiddenQuestCount = self.HiddenQuestCount + 1;
    		end
    	end
	end


	if (self.QuestCount > 0 and GetTime() - timeOfFirstQuestUpdate > 20) then
		dbChar.ZoneIsCollapsed = {};
	end
	self.CollapsedZoneCount = 0;
	for zoneKey, zone in pairs(self.ZoneList) do
		if (zone.QuestCount > 0 or zone.IsFakeZone == true) then
	    	if (zone.IsCollapsed == true) then
				self.CollapsedZoneCount = self.CollapsedZoneCount + 1;
				dbChar.ZoneIsCollapsed[zoneKey] = true;
	    	else
				dbChar.ZoneIsCollapsed[zoneKey] = false;
	    	end

	    	if (zone:Changed() == true) then
	    		self.Changed = true;
	    	end
	    
	    else
    		self.ZoneList[zone.ID] = nil;
    		self.ZoneCount = self.ZoneCount - 1;
    		self.Changed = true;
    	end
	end

	self.HaveTrackedQuests = true;
	if (self.HiddenQuestCount >= self.QuestCount) then
		self.HaveTrackedQuests = false;
	end


	self.FirstUpdate = false;
end

function SQLQuestLogData:CompleteCheck()
	local questComplete = false;
	local questFailed = false;
	local objectiveChanged = false;
	local objectiveComplete = false;
	local messages = {};

	for questKey, quest in pairs(self.QuestList) do
		if (quest.DataChanged == true) then			
			for objectiveKey, objective in pairs(quest.ObjectiveList) do
				if (objective.Changed == true) then
					objectiveChanged = true;

					local strMessage = "";
					if (objective.IsComplete == true) then
						objectiveComplete = true;

						if (db.Notifications.LibSinkObjectiveNotifications == true) then
							if (db.Notifications.DisplayQuestOnObjectiveNotifications == true) then
								strMessage = format("(%s) %s ", quest.Title, objective.Text) .. L["(Complete)"];
							else
								strMessage = format("%s ", objective.Text) .. L["(Complete)"];
							end

							if (db.Notifications.LibSinkColourSetting == "Custom") then
								QuestTracker:Pour(strMessage, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b);
							else
								QuestTracker:Pour(strMessage, db.Colours.ObjectiveDoneColour.r, db.Colours.ObjectiveDoneColour.g, db.Colours.ObjectiveDoneColour.b);
							end
						end
					else
						if (db.Notifications.LibSinkObjectiveNotifications == true) then
							if (db.Notifications.DisplayQuestOnObjectiveNotifications == true) then
								if (quest.Title == nil or objective.Text == nil or objective.Have == nil or objective.Need == nil) then
									print(quest.Title);print(objective.Text);print(objective.Have);print(objective.Need);
								end
								strMessage = format("(%s) %s : %s / %s", quest.Title, objective.Text, objective.Have, objective.Need);
							else
								strMessage = format("%s : %s / %s", objective.Text, objective.Have, objective.Need);
							end
								
							if (db.Notifications.LibSinkColourSetting == "Custom") then
								QuestTracker:Pour(strMessage, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b);
							else
								r, g, b = QuestTracker:GetCompletionColourRGB(objective.CompletionLevel / 1.0);
								QuestTracker:Pour(strMessage, r, g, b);
							end
						end
					end
				end
			end
			

			if (quest.IsComplete == true) then
				questComplete = true;
				if (db.Notifications.ShowQuestCompletesAndFails) then
					QuestTracker:Pour(QUEST_COMPLETE .. ": " .. quest.Title, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b);
				end
			elseif (quest.IsFailed == true) then
				questFailed = true;
				if (db.Notifications.ShowQuestCompletesAndFails) then
					QuestTracker:Pour(L["Quest failed: "] .. quest.Title, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b);
				end
			end
		end
	end
	

	if (questComplete == true) then
		if ((GetTime() - intTimeOfLastSound) > 1 and db.Notifications.QuestDoneSound ~= "None") then
			PlaySoundFile(LSM:Fetch("sound", db.Notifications.QuestDoneSound))
			intTimeOfLastSound = GetTime()
		end
	elseif (objectiveComplete == true) then
		if ((GetTime() - intTimeOfLastSound) > 1 and db.Notifications.ObjectiveDoneSound ~= "None") then
			PlaySoundFile(LSM:Fetch("sound", db.Notifications.ObjectiveDoneSound))
			intTimeOfLastSound = GetTime()
		end
	elseif (objectiveChanged == true) then
		if ((GetTime() - intTimeOfLastSound) > 1 and db.Notifications.ObjectiveChangedSound ~= "None") then
			PlaySoundFile(LSM:Fetch("sound", db.Notifications.ObjectiveChangedSound))
			intTimeOfLastSound = GetTime()
		end
	end
end

--Inits
function QuestTracker:OnInitialize()
	self.db = SorhaQuestLog.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	dbChar = self.db.char	
	dbCore = SorhaQuestLog.db.profile
	self:SetSinkStorage(db)
	
	self:SetEnabledState(SorhaQuestLog:GetModuleEnabled(MODNAME))
	SorhaQuestLog:RegisterModuleOptions(MODNAME, getOptions, L["Quest Tracker"])
	
	self:UpdateColourStrings();
	self:UpdateClickBindings();
	self:MinionAnchorUpdate(true)

	SorhaQuestLog:RegisterToast("TaskCompleteToast", function(toast, rewards)
	    toast:SetTitle(rewards.title)

		local text = "";
		local firstIcon = true;
		if (rewards["currencies"]) then
			if (firstIcon == true) then
				toast:SetIconTexture(rewards["currencies"].texture);
			end
			text = text .. rewards["currencies"].text .. "\n";
			firstIcon = false;
		end
		if (rewards["items"]) then
			if (firstIcon == true) then
				toast:SetIconTexture(rewards["items"].texture);
			end
			text = text .. rewards["items"].text .. "\n";
			firstIcon = false;
		end
		if (rewards["xp"]) then
			if (firstIcon == true) then
				toast:SetIconTexture(rewards["xp"].texture);

			end
			text = text .. rewards["xp"].text .. " Experience\n";
			firstIcon = false;
		end
		if (rewards["money"]) then
			if (firstIcon == true) then
				toast:SetIconTexture(rewards["money"].texture);
			end
			text = text .. rewards["money"].text .. "\n";
			firstIcon = false;
		end

	    toast:SetText(text)
	end)
end

function QuestTracker:OnEnable()
	
	strZone = GetRealZoneText()
	strSubZone = GetSubZoneText()
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("QUEST_TURNED_IN");
	self:RegisterEvent('PLAYER_LEVEL_UP');
	self:RegisterEvent("ZONE_CHANGED")
	self:RegisterEvent("ZONE_CHANGED_INDOORS")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_STOPPED_MOVING")
	
	
	-- Hook for moving quest progress messages
	self:RawHookScript(UIErrorsFrame, "OnEvent", function(self, event, msgType, msg, ...) 
		QuestTracker:HandleUIErrorsFrame(self, event, msgType, msg, ...) 
	end)
	


	intTimeOfLastSound = GetTime()
	self:MinionAnchorUpdate(false);

	self:UpdateMinionHandler()
end

function QuestTracker:OnDisable()
	self:UnregisterEvent("QUEST_LOG_UPDATE")	
	self:UnregisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:UnregisterEvent("QUEST_TURNED_IN");
	self:UnregisterEvent('PLAYER_LEVEL_UP');
	self:UnregisterEvent("ZONE_CHANGED")
	self:UnregisterEvent("ZONE_CHANGED_INDOORS")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	self:UnregisterEvent("PLAYER_STOPPED_MOVING")

	self:MinionAnchorUpdate(true);
	self:UpdateMinionHandler()
end

function QuestTracker:Refresh()
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	self:SetSinkStorage(db)
	
	self:HandleColourChanges()
	self:doHiddenQuestsUpdate()
	self:MinionAnchorUpdate(true)	
end


--Events/handlers
function QuestTracker:QUEST_LOG_UPDATE(...)
	if (blnHaveRegisteredBagUpdate == false) then
		blnHaveRegisteredBagUpdate = true
		self:RegisterEvent("BAG_UPDATE")
	end

	self:UpdateMinionHandler();
end

function QuestTracker:QUEST_WATCH_LIST_CHANGED(...)
	self:UpdateMinionHandler();
end

function QuestTracker:QUEST_TURNED_IN(...)
	local event, questID, xp, money = ...;
	if ( IsQuestTask(questID)) then
		rewards = { };
		local title = C_TaskQuest.GetQuestInfoByQuestID(questID);
		if (title == nil) then
			return
		end
		rewards.title = C_TaskQuest.GetQuestInfoByQuestID(questID) .. " Complete";

		-- xp
		if ( not xp ) then
			xp = GetQuestLogRewardXP(questID);
		end
		if ( xp > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
			local t = { };
			t.text = xp;
			t.texture = "Interface\\Icons\\XP_Icon";
			rewards["xp"] = t;
		end

		-- currencies
		local numCurrencies = GetNumQuestLogRewardCurrencies(questID);
		for i = 1, numCurrencies do
			local name, texture, count = GetQuestLogRewardCurrencyInfo(i, questID);
			local t = { };
			t.text = tostring(count) .. " " .. name;
			t.texture = texture;
			rewards["currencies"] = t;
			break;
		end

		-- items -- only the first
		local numItems = GetNumQuestLogRewards(questID);
		for i = 1, numItems do
			local name, texture, count, quality, isUsable = GetQuestLogRewardInfo(i, questID);
			local t = { };
			t.text = name;
			t.texture = texture;
			rewards["items"] = t;
			break;
		end	

		-- money
		if ( not money ) then
			money = GetQuestLogRewardMoney(questID);
		end
		if ( money > 0 ) then
			local t = { };
			t.text = GetCoinText(money, ", ");
			t.texture = "Interface\\Icons\\inv_misc_coin_01";
			rewards["money"] = t;
		end

		if (db.Notifications.DisableToasts == false) then
			SorhaQuestLog:SpawnToast("TaskCompleteToast", rewards);
		end
	end
end

function QuestTracker:PLAYER_LEVEL_UP(...)
	self:UpdateMinionHandler();
end

function QuestTracker:PLAYER_REGEN_ENABLED(...)
	blnWasAClick = true;
	self:UpdateMinionHandler();
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function QuestTracker:ZONE_CHANGED(...)
	self:doHandleZoneChange()
end

function QuestTracker:ZONE_CHANGED_INDOORS(...)
	self:doHandleZoneChange()
end

function QuestTracker:ZONE_CHANGED_NEW_AREA(...)
	if (strZone == nil) then 
		strZone = GetRealZoneText()
		strSubZone = GetSubZoneText()
	end
	self:doHandleZoneChange()
end


function QuestTracker:PLAYER_STOPPED_MOVING(...)
	if (InCombatLockdown()) then
		return;
	end

	local currentTime = GetTime();
	if (timeOfProximityCheck + 5 < currentTime) then
		timeOfProximityCheck = currentTime;
		
		if (db.ZonesAndQuests.QuestSortOrder ~= "Proximity") then
			QuestTracker:UpdateMinionHandler();
		else 
			QuestTracker:UpdateSmartItemButton();
		end		
	end
end

function QuestTracker:BAG_UPDATE(...)
	local intBag = select(2,...)
	
	if (db.Notifications.ShowMessageOnPickingUpQuestItem == true) then
		if (intBag < 5) then
			if (tContains(tblBagsToCheck, intBag) == nil) then
				tinsert(tblBagsToCheck, intBag)
			end
			if (blnBagCheckUpdating == false) then
				blnBagCheckUpdating = true
				self:ScheduleTimer("CheckBags", 1)
			end
		end
	end
end

function QuestTracker:HandleUIErrorsFrame(frame, event, msgType, msg, ...)
	if (event == "UI_INFO_MESSAGE") then
		for k, strPattern in pairs(tblQuestMatchs) do
			if (msg:match(strPattern)) then
				if (db.Notifications.SuppressBlizzardNotifications == true) then
					return
				end
				break
			end
		end
	end
	QuestTracker.hooks[frame].OnEvent(frame, event, msgType, msg, ...)
end

--Buttons
function QuestTracker:GetMinionButton()
	local objButton = SorhaQuestLog:GetLogButton()
	objButton:SetParent(fraMinionAnchor)
	objButton.intOffset = 0;

	-- Create scripts
	objButton:RegisterForClicks("AnyUp")
	objButton:SetScript("OnLeave", function(self) 
		GameTooltip:Hide() 
	end)
	return objButton
end

function QuestTracker:GetMinionHeaderButton(zoneInstance)
	local objButton = QuestTracker:GetMinionButton()	
	objButton.ZoneInstance = zoneInstance;

	local strPrefix = strHeaderColour .. "- "
	if (objButton.ZoneInstance.IsCollapsed == true) then
		strPrefix = strHeaderColour .. "+ "
	end

	objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.HeaderFont), db.Fonts.HeaderFontSize, db.Fonts.HeaderFontOutline)
	objButton.objFontString1:SetSpacing(db.Fonts.HeaderFontLineSpacing)
	if (db.Fonts.HeaderFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	if (db.ZonesAndQuests.ShowHiddenCountOnZones == true and db.ZonesAndQuests.AllowHiddenQuests == true) then
		if (objButton.ZoneInstance:HiddenQuestCount() > 0) then
			objButton.objFontString1:SetText(strPrefix .. objButton.ZoneInstance.Title .. "|r " .. strInfoColour .. "(" .. objButton.ZoneInstance:HiddenQuestCount() .. "/" .. objButton.ZoneInstance.QuestCount .." Hidden)|r");	
		else
			objButton.objFontString1:SetText(strPrefix .. objButton.ZoneInstance.Title .. "|r");
		end
	else
		objButton.objFontString1:SetText(strPrefix .. objButton.ZoneInstance.Title .. "|r");
	end


	-- Create scripts
	objButton:SetScript("OnClick", function(self, button)
		blnWasAClick = true
		if (button == "LeftButton") then
			if (self.ZoneInstance.IsCollapsed == true) then
				dbChar.ZoneIsCollapsed[self.ZoneInstance.ID] = false;
			else
				dbChar.ZoneIsCollapsed[self.ZoneInstance.ID] = true;
			end
			QuestTracker:UpdateMinionHandler();			
		else
			if (IsAltKeyDown()) then
				QuestTracker:DisplayAltRightClickMenu(self)		
			else
				if (db.ZonesAndQuests.AllowHiddenQuests == true) then
					QuestTracker:DisplayRightClickMenu(self)
				end
			end
		end
	end)
	objButton:SetScript("OnEnter", function(self)		
		if (db.ShowHelpTooltips == true) then
			if (db.MoveTooltipsRight == true) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
			else 
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 0);
			end
			
			GameTooltip:SetText(L["Zone Header"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Click to collapse/expand zone"], 1, 1, 1, 1);
			if (db.ZonesAndQuests.AllowHiddenQuests == true) then
				GameTooltip:AddLine(L["Right-click to show hidden quests toggle dropdown menu"], 1, 1, 1, 1);
			end
			GameTooltip:AddLine(L["Alt Right-click to show zone collapse/expand dropdown menu"], 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)

	
	return objButton
end

function QuestTracker:GetCampaignButton(zoneInstance)


	-- Create scripts
	local campaignId = C_CampaignInfo.GetCurrentCampaignID();
	local campaignInfo, campaignChapterInfo;
	if (campaignId) then
		campaignInfo = C_CampaignInfo.GetCampaignInfo(campaignId);
	end
	
	local campaignChapterId = C_CampaignInfo.GetCurrentCampaignChapterID();	
	if (campaignChapterId) then
		campaignChapterInfo = C_CampaignInfo.GetCampaignChapterInfo(campaignChapterId)
	end
	

	local objButton = fraMinionAnchor.CampaignButton;
	objButton.ZoneInstance = zoneInstance
	objButton.CampaignTooltip.warCampaignID = campaignId;

	objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.HeaderFont), db.Fonts.HeaderFontSize, db.Fonts.HeaderFontOutline)
	objButton.objFontString1:SetSpacing(db.Fonts.HeaderFontLineSpacing)
	if (db.Fonts.HeaderFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end	
	
	if (objButton.ZoneInstance.IsCollapsed == true) then
		objButton.objFontString1:SetText(strHeaderColour .. "+ " .. zoneInstance.Title .. "|r");	
	else
		objButton.objFontString1:SetText(strHeaderColour .. "- " ..zoneInstance.Title .. "|r");	
	end


	objButton.objFontString2:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
	objButton.objFontString2:SetFont(LSM:Fetch("font", db.Fonts.QuestFont), db.Fonts.QuestFontSize, db.Fonts.QuestFontOutline)
	objButton.objFontString2:SetSpacing(db.Fonts.QuestFontLineSpacing)
	if (db.Fonts.HeaderFontShadowed == true) then
		objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end	
	if (campaignChapterInfo) then
		objButton.objFontString2:SetText(strQuestTitleColour .. campaignChapterInfo.name .. "|r");
	end

	
	
	
	objButton:SetScript("OnClick", function(self, button)
		blnWasAClick = true

		if (button == "LeftButton") then
			if (self.ZoneInstance.IsCollapsed == true) then
				dbChar.ZoneIsCollapsed[self.ZoneInstance.ID] = false;
				self.ZoneInstance:Expand();
			else
				dbChar.ZoneIsCollapsed[self.ZoneInstance.ID] = true;
				self.ZoneInstance:Collapse();
			end
			QuestTracker:UpdateMinionHandler();			
		else
			if (IsAltKeyDown()) then
				QuestTracker:DisplayAltRightClickMenu(self)		
			else
				if (db.ZonesAndQuests.AllowHiddenQuests == true) then
					QuestTracker:DisplayRightClickMenu(self)
				end
			end
		end
	end)

	objButton:SetScript("OnEnter", function(self)		
		if (db.MoveTooltipsRight == true) then
			self.CampaignTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 27, 0);
		else
			self.CampaignTooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", -5, 0);
		end		

		if (campaignInfo) then
			self.CampaignTooltip.Title:SetText(campaignInfo.name);
		end

		if (campaignChapterId) then
			local campaignChapterInfo = C_CampaignInfo.GetCampaignChapterInfo(campaignChapterId);
			if (campaignChapterInfo) then
				self.CampaignTooltip.ChapterTitle:SetText(campaignChapterInfo.name);
				self.CampaignTooltip.Description:SetText(campaignChapterInfo.description);
				self.CampaignTooltip.Description:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB());
				if ( GetNumQuestLogRewards(campaignChapterInfo.rewardQuestID) > 0 ) then
					-- if (not EmbeddedItemTooltip_SetItemByQuestReward(self.ItemTooltip, 1, campaignChapterInfo.rewardQuestID)) then
						-- self.CampaignTooltip.ItemTooltip:Hide();
					-- end
				elseif ( GetNumQuestLogRewardSpells(campaignChapterInfo.rewardQuestID) > 0 ) then
					-- if (not EmbeddedItemTooltip_SetSpellByQuestReward(self.ItemTooltip, 1, campaignChapterInfo.rewardQuestID)) then
						-- self.CampaignTooltip.ItemTooltip:Hide();
					-- end
				else
					-- if (QuestUtils_AddQuestCurrencyRewardsToTooltip(campaignChapterInfo.rewardQuestID, nil, self.ItemTooltip) == 0 ) then
						-- self.CampaignTooltip.ItemTooltip:Hide();
					-- end
					EmbeddedItemTooltip_UpdateSize(self.CampaignTooltip.ItemTooltip);
				end
			else
				self.CampaignTooltip.ChapterTitle:SetText(campaignInfo.name);
				self.CampaignTooltip.Description:SetText(campaignInfo.playerConditionFailedReason);
				self.CampaignTooltip.ItemTooltip:Hide();
				self.CampaignTooltip.Description:SetTextColor(NORMAL_FONT_COLOR:GetRGB());
			end	
		else
			if ( campaignInfo.complete ) then
				self.CampaignTooltip.Description:SetText(WAR_CAMPAIGN_DONE_DESCRIPTION);
			else
				self.CampaignTooltip.Description:SetText(campaignInfo.playerConditionFailedReason);
			end
			self.CampaignTooltip.ChapterTitle:SetText(nil);
			self.CampaignTooltip.ItemTooltip:Hide();
			self.CampaignTooltip.Description:SetTextColor(NORMAL_FONT_COLOR:GetRGB());
		end

		if (self.CampaignTooltip.ItemTooltip:IsShown()) then
			self.CampaignTooltip.CompleteRewardText:Show();
		else
			self.CampaignTooltip.CompleteRewardText:Hide();
		end

		self.CampaignTooltip:Layout();
		self.CampaignTooltip:Show();
	
	end)
	
	objButton:SetScript("OnLeave", function(self)		
		self.CampaignTooltip:Hide()
	end)

	objButton:Show();
	return objButton
end

function QuestTracker:GetMinionQuestButton(questInstance)
	local objButton = QuestTracker:GetMinionButton()
	objButton.QuestInstance = questInstance;

	-- Get quest text
	local strQuestTitle, strObjectiveText = objButton.QuestInstance:Render();
	
	-- Setup quest title string
	objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
	objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.QuestFont), db.Fonts.QuestFontSize, db.Fonts.QuestFontOutline)
	objButton.objFontString1:SetSpacing(db.Fonts.QuestFontLineSpacing)
	if (db.Fonts.QuestFontShadowed == true) then
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objButton.objFontString1:SetText(strQuestTitle);

	-- Setup quest objectives string
	objButton.objFontString2:SetFont(LSM:Fetch("font", db.Fonts.ObjectiveFont), db.Fonts.ObjectiveFontSize, db.Fonts.ObjectiveFontOutline)
	objButton.objFontString2:SetSpacing(db.Fonts.ObjectiveFontLineSpacing)
	if (db.Fonts.ObjectiveFontShadowed == true) then
		objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	if (questInstance.IsWorldQuest) then
		local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInstance.ID);
		if (timeLeftMinutes and timeLeftMinutes > 0 and timeLeftMinutes < WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			strObjectiveText = strObjectiveText .. "\n" .. strQuestStatusFailed .. BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(timeLeftMinutes * 60)) .. "|r";
		end
	end
	
	objButton.objFontString2:SetText(strObjectiveText);		

	-- Create scripts
	objButton:SetScript("OnClick", function(self, button)
		blnWasAClick = true

		if (button == "LeftButton") then
			if (IsShiftKeyDown()) then 
				QuestTracker:HandleQuestClick(LEFT_SHIFT_CLICK, self.QuestInstance);

			elseif (IsControlKeyDown() and IsAltKeyDown()) then 
				QuestTracker:HandleQuestClick(LEFT_ALT_CTRL_CLICK, self.QuestInstance);
				
			elseif (IsAltKeyDown()) then
				QuestTracker:HandleQuestClick(LEFT_ALT_CLICK, self.QuestInstance);

			elseif (IsControlKeyDown()) then
				QuestTracker:HandleQuestClick(LEFT_CTRL_CLICK, self.QuestInstance);

			else 
				QuestTracker:HandleQuestClick(LEFT_CLICK, self.QuestInstance);
			end
		else
			if (IsShiftKeyDown()) then 
				QuestTracker:HandleQuestClick(RIGHT_SHIFT_CLICK, self.QuestInstance);
			else
				QuestTracker:HandleQuestClick(RIGHT_CLICK, self.QuestInstance);
			end
		end
	end)
	objButton:SetScript("OnEnter", function(self)
		if (db.MoveTooltipsRight == true) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50);
		else 
			GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -50);
		end

		if (self.QuestInstance.IsTask == false) then
			GameTooltip:SetText(self.QuestInstance.Title, 0, 1, 0, 1);
			GameTooltip:AddLine(self.QuestInstance.ObjectiveDescription, db.Colours.ObjectiveTooltipTextColour.r, db.Colours.ObjectiveTooltipTextColour.g, db.Colours.ObjectiveTooltipTextColour.b, db.Colours.ObjectiveTooltipTextColour.a);
		else
			if (self.QuestInstance.IsWorldQuest) then		
				local questID = self.QuestInstance.ID
				local headerLine = 1;
				local needsSpacer = false;
				
				local mapID, zoneMapID = C_TaskQuest.GetQuestZoneID(questID)
				
				if (mapID and zoneMapID) then
					local name = C_MapCanvas.GetZoneInfoByID(mapID, zoneMapID); 
								
					if (name) then
						GameTooltip:SetText(name, 0.4, 0.733, 1.0);
						needsSpacer = true;
						headerLine = headerLine + 1;
					end
				end
				
				local _, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questID);				
				if (factionID) then
					local factionName = GetFactionInfoByID(factionID);
					if ( factionName ) then	
						if (capped) then
							GameTooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
						else
							GameTooltip:AddLine(factionName, 0.4, 0.733, 1.0);
						end
						headerLine = headerLine + 1;
						
					end
				end
				
				local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInstance.ID);
				if (timeLeftMinutes and timeLeftMinutes > 0) then
					GameTooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(timeLeftMinutes * 60)), 1, 1, 1, 1);
				end
					
				if (needsSpacer) then
					GameTooltip:AddLine(" ");
					headerLine = headerLine + 1;
				end
					
				GameTooltip:AddLine(REWARDS, 1, 0.824, 0);
				GameTooltip:AddLine(WORLD_QUEST_TOOLTIP_DESCRIPTION, 1, 1, 1, 1);
				GameTooltip:AddLine(" ");
				-- xp
				local xp = GetQuestLogRewardXP(questID);
				if ( xp > 0 ) then
					GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1);
				end
				local artifactXP = GetQuestLogRewardArtifactXP(questID);
				if ( artifactXP > 0 ) then
					GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_ARTIFACT_XP_FORMAT, artifactXP), 1, 1, 1);
				end
				-- currency		
				local numQuestCurrencies = GetNumQuestLogRewardCurrencies(questID);
				for i = 1, numQuestCurrencies do
					local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, questID);
					local text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
					GameTooltip:AddLine(text, 1, 1, 1);			
				end
				-- items
				local numQuestRewards = GetNumQuestLogRewards(questID);
				for i = 1, numQuestRewards do
					local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i, questID);
					local text;
					if ( numItems > 1 ) then
						text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
					elseif( texture and name ) then
						text = string.format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name);			
					end
					if( text ) then
						local color = ITEM_QUALITY_COLORS[quality];
						GameTooltip:AddLine(text, color.r, color.g, color.b);
					end
				end
				-- money
				local money = GetQuestLogRewardMoney(questID);
				if ( money > 0 ) then
					SetTooltipMoney(GameTooltip, money, nil);
				end
			else
				GameTooltip:AddLine(BONUS_OBJECTIVE_TOOLTIP_DESCRIPTION, 1, 1, 1, 1);
				GameTooltip:AddLine(" ");
				-- xp
				local xp = GetQuestLogRewardXP(self.QuestInstance.ID);
				if ( xp > 0 ) then
					GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1);
				end
				-- currency		
				local numQuestCurrencies = GetNumQuestLogRewardCurrencies(self.QuestInstance.ID);
				for i = 1, numQuestCurrencies do
					local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, self.QuestInstance.ID);
					local text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
					GameTooltip:AddLine(text, 1, 1, 1);			
				end
				-- items
				local numQuestRewards = GetNumQuestLogRewards(self.QuestInstance.ID);
				for i = 1, numQuestRewards do
					local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i, self.QuestInstance.ID);
					local text;
					if ( numItems > 1 ) then
						text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
					elseif( texture and name ) then
						text = string.format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name);			
					end
					if( text ) then
						local color = ITEM_QUALITY_COLORS[quality];
						GameTooltip:AddLine(text, color.r, color.g, color.b);
					end
				end
				-- money
				local money = GetQuestLogRewardMoney(self.QuestInstance.ID);
				if ( money > 0 ) then
					SetTooltipMoney(GameTooltip, money, nil);
				end

			end
		end
		
		local strQuestTag = ""
		if (self.QuestInstance.Frequency == 2) then
			strQuestTag = strQuestTag .. DAILY .. " "			
		elseif (self.QuestInstance.Frequency == 3) then
			strQuestTag = strQuestTag .. CALENDAR_REPEAT_WEEKLY .. " "
		end				

		if (self.QuestInstance.SuggestedGroup > 0) then
			strQuestTag = strQuestTag .. " (" .. self.QuestInstance.SuggestedGroup .. ")"
		end
		GameTooltip:AddLine(strQuestTag, 1, 0, 0, 1);

		if (db.ZonesAndQuests.DisplayQuestIDInTooltip) then
			GameTooltip:AddLine(self.QuestInstance.ID, 1, 1, 1, 1);
		end
		
		local intPartyMembers = GetNumGroupMembers();
		if (intPartyMembers > 0) then
			GameTooltip:AddLine(PARTY_QUEST_STATUS_ON, 0, 1, 0, 1);
			for k = 1, intPartyMembers do
				if (IsUnitOnQuest(self.QuestInstance.Index, "party" .. k)) then
					GameTooltip:AddLine(UnitName("party" .. k), 1, 1, 1, 1);
				end
			end				
		end

		GameTooltip:Show();
	end)
	
	return objButton
end

function QuestTracker:GetStatusBar()
	return SorhaQuestLog:GetStatusBar()
end

function QuestTracker:GetTimerStatusBar(timerInstance)
	local objStatusBar = SorhaQuestLog:GetStatusBar();
	objStatusBar.TimerInstance = timerInstance

	-- Setup colours and texture
	objStatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
	objStatusBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)
	
	objStatusBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
	objStatusBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)
	
	objStatusBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

	
	objStatusBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.ObjectiveFont), db.Fonts.ObjectiveFontSize, db.Fonts.ObjectiveFontOutline)
	if (db.Fonts.ObjectiveFontShadowed == true) then
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end

	local r,g,b = SorhaQuestLog:GetTimerTextColor(objStatusBar.TimerInstance.Duration, objStatusBar.TimerInstance.Elasped);
	local colour = format("|c%02X%02X%02X%02X", 255, r * 255, g * 255, b * 255);

	objStatusBar.objFontString:SetText( colour .. SorhaQuestLog:SecondsToFormatedTime(objStatusBar.TimerInstance.TimeLeft) .. "|r")

	objStatusBar.Width = objStatusBar.objFontString:GetWidth();
	
	objStatusBar.objFontString:SetHeight(math.floor(objStatusBar.objFontString:GetHeight() + 3));
	objStatusBar:SetHeight(math.floor(objStatusBar.objFontString:GetHeight()))	

	objStatusBar:SetMinMaxValues(0, objStatusBar.TimerInstance.Duration);
	objStatusBar:SetValue(objStatusBar.TimerInstance.TimeLeft);

	objStatusBar:Show()

	objStatusBar.updateTimer = 0;

	objStatusBar:SetScript('OnUpdate', function(self, elapsed)
		self.updateTimer = self.updateTimer + elapsed

		if(self.updateTimer > 0.05) then
			self.TimerInstance:Update(self.updateTimer);
			objStatusBar:SetValue(self.TimerInstance.TimeLeft);

			local r,g,b = SorhaQuestLog:GetTimerTextColor(self.TimerInstance.Duration, self.TimerInstance.Elasped);
			local colour = format("|c%02X%02X%02X%02X", 255, r * 255, g * 255, b * 255);

			objStatusBar.objFontString:SetText( colour .. SorhaQuestLog:SecondsToFormatedTime(self.TimerInstance.TimeLeft) .. "|r")
			self.updateTimer = 0;
		end
	end)

	objStatusBar:SetWidth(math.floor(db.MinionWidth - db.ZonesAndQuests.QuestTitleIndent));
	objStatusBar.objFontString:SetWidth(math.floor(db.MinionWidth - db.ZonesAndQuests.QuestTitleIndent))
	return objStatusBar;
end

function QuestTracker:RecycleStatusBar(objStatusBar)
	objStatusBar:SetScript("OnUpdate", nil);
	SorhaQuestLog:RecycleStatusBar(objStatusBar)
end

function QuestTracker:RecycleMinionButton(objButton)
	if (objButton.StatusBar ~= nil) then
		self:RecycleStatusBar(objButton.StatusBar)
		objButton.StatusBar = nil
	end
	if (objButton.TimerBar ~= nil) then
		self:RecycleStatusBar(objButton.TimerBar)
		objButton.TimerBar = nil
	end
	SorhaQuestLog:RecycleLogButton(objButton)
end

function QuestTracker:GetItemButton(objItem, yOffset)
	local objButton = tremove(tblItemButtonCache)
	if (objButton == nil) then
		intNumberOfItemButtons = intNumberOfItemButtons + 1
		objButton = CreateFrame('Button', strItemButtonPrefix .. intNumberOfItemButtons, UIParent, 'SorhaQuestLogItemButtonTemplate')
		objButton.rangeTimer = -1

		if (MSQ) then
			local group = MSQ:Group("SorhaQuestLog", "Item Buttons")
			group:AddButton(objButton,{ Icon = objButton.icon })
		end
		
		
		objButton:SetScript('OnEvent', function(self, event)
			if (event == "PLAYER_TARGET_CHANGED") then
				self.rangeTimer = TOOLTIP_UPDATE_TIME;

			elseif(event == 'BAG_UPDATE_COOLDOWN') then
				QuestObjectiveItem_UpdateCooldown(self)

			elseif(event == 'PLAYER_REGEN_ENABLED') then
				self:SetAttribute('item', self.setItem)
				if (self.setItem == nil) then
					QuestTracker:TearDownItemButton(objButton);
				else				
					QuestTracker:SetupItemButton(objButton);
				end
				self:UnregisterEvent(event)
			end
		end)
	end

	objButton:SetID(objItem.QuestIndex)
	objButton.questLogIndex = objItem.QuestIndex;			
	objButton.yOffset = yOffset;
	if(objItem.Link) then
		if(objItem.Link == objButton.itemLink and objButton:IsShown()) then
			return
		end
		objButton.charges = objItem.Charges;
		objButton.link = objItem.Link
		objButton.item = objItem.Item		
		SetItemButtonTexture(objButton, objItem.Item)
		SetItemButtonCount(objButton, objItem.Charges)
		objButton.HotKey:Hide()
	end
		
	if(InCombatLockdown()) then
		objButton.setItem = objButton.link
		objButton:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		objButton:SetAttribute('item', objButton.link)
		QuestTracker:SetupItemButton(objButton);
	end	
	
	return objButton
end

function QuestTracker:RecycleItemButton(objButton)
	if(InCombatLockdown()) then
		objButton.setItem = nil
		objButton:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		objButton:SetAttribute('item', nil)
		objButton:SetScript('OnUpdate', nil);
		QuestTracker:TearDownItemButton(objButton);
	end
end

function QuestTracker:SetupItemButton(objButton)	
	objButton:SetScale(db.ItemButtonScale);

	objButton:RegisterEvent('BAG_UPDATE_COOLDOWN')
	objButton:RegisterEvent("PLAYER_TARGET_CHANGED")
	
	objButton:SetScript('OnUpdate', function(self, elapsed)
		self.rangeTimer = self.rangeTimer + elapsed;

		if(self.rangeTimer >= TOOLTIP_UPDATE_TIME) then
			if (IsQuestLogSpecialItemInRange(self.questLogIndex) == 0) then
				SetItemButtonTextureVertexColor(self, 0.8, 0.1, 0.1)
			else
				SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
			end
			self.rangeTimer = 0
		end
	end)

	objButton:SetParent(fraMinionAnchor);
	objButton:Show();
	QuestObjectiveItem_UpdateCooldown(objButton)
	objButton.Cooldown:SetFrameStrata("DIALOG")
	if (db.MoveTooltipsRight == true) then
		objButton:SetPoint("TOPLEFT", fraMinionAnchor, "TOPRIGHT", (8 * (1 / objButton:GetScale())), objButton.yOffset * (1 / objButton:GetScale()))
	else
		if (db.IndentItemButtons == true) then
			objButton:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", (1 * (1 / objButton:GetScale())), objButton.yOffset * (1 / objButton:GetScale()))
		else
			objButton:SetPoint("TOPRIGHT", fraMinionAnchor, "TOPLEFT", -(1 * (1 / objButton:GetScale())), objButton.yOffset * (1 / objButton:GetScale()))
		end
	end
	tinsert(tblUsedItemButtons, objButton);	
end

function QuestTracker:TearDownItemButton(objButton)
	objButton:SetParent(UIParent)
	objButton:ClearAllPoints()
	objButton:Hide()
	objButton:UnregisterEvent("BAG_UPDATE_COOLDOWN")
	objButton:UnregisterEvent("PLAYER_TARGET_CHANGED")
	objButton:SetScript("OnUpdate", nil)

	tinsert(tblItemButtonCache, objButton);
end

--Minion
function QuestTracker:CreateMinionLayout()
	fraMinionAnchor = SorhaQuestLog:doCreateFrame("FRAME","SQLQuestMinionAnchor",UIParent,db.MinionWidth,20,1,"BACKGROUND",1, db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y, 1)
	
	fraMinionAnchor:SetMovable(true)
	fraMinionAnchor:SetClampedToScreen(true)
	fraMinionAnchor:RegisterForDrag("LeftButton")
	fraMinionAnchor:SetScript("OnDragStart", fraMinionAnchor.StartMoving)
	fraMinionAnchor:SetScript("OnDragStop",  function(self)
		fraMinionAnchor:StopMovingOrSizing()
		local strPoint, tempB, strRelativePoint, intPosX, intPosY = fraMinionAnchor:GetPoint()
		db.MinionLocation.Point = strPoint
		db.MinionLocation.RelativePoint = strRelativePoint
		db.MinionLocation.X = intPosX
		db.MinionLocation.Y = intPosY
	end)
	fraMinionAnchor:SetScript("OnEnter", function(self) 
		if (db.ShowHelpTooltips == true) then
			if (db.MoveTooltipsRight == true) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
			else 
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 0);
			end
			
			GameTooltip:SetText(L["Quest Minion Anchor"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Drag this to move the Quest minion when it is unlocked."], 1, 1, 1, 1);
			local strOutput = ""
			if (db.ShowNumberOfQuests == true) then
				strOutput = strOutput .. L["Displays # of quests you have in your log and the max limit"]
			end
			if (db.ShowNumberOfDailyQuests == true) then
				strOutput = strOutput .. L["Displays # of daily quests you have done today of the max limit"]
			end			
			GameTooltip:AddLine(strOutput, 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)
	fraMinionAnchor:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)
	
	fraMinionAnchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = false, tileSize = 16,	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 5}})
	fraMinionAnchor:SetBackdropColor(0, 1, 0, 0)
	fraMinionAnchor:SetBackdropBorderColor(0.5, 0.5, 0, 0)
	
	-- Quests Anchor
	fraMinionAnchor.fraQuestsAnchor = SorhaQuestLog:doCreateLooseFrame("FRAME","SQLQuestsAnchor",fraMinionAnchor, fraMinionAnchor:GetWidth(),1,1,"LOW",1,1)
	fraMinionAnchor.fraQuestsAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
	fraMinionAnchor.fraQuestsAnchor:SetBackdropColor(0, 0, 0, 0)
	fraMinionAnchor.fraQuestsAnchor:SetBackdropBorderColor(0,0,0,0)
	fraMinionAnchor.fraQuestsAnchor:SetAlpha(0)
	
	-- Number of quests fontstring/title fontstring
	fraMinionAnchor.objFontString = fraMinionAnchor:CreateFontString(nil, "OVERLAY");
	fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
	fraMinionAnchor.objFontString:SetJustifyH("LEFT")
	fraMinionAnchor.objFontString:SetJustifyV("TOP")
	fraMinionAnchor.objFontString:SetText("");
	if (db.Fonts.MinionTitleFontShadowed == true) then
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	fraMinionAnchor.objFontString:SetShadowOffset(1, -1)

	fraMinionAnchor.buttonShowHidden = SorhaQuestLog:doCreateLooseFrame("BUTTON","SQLShowHiddenButton",fraMinionAnchor,10,10,1,"LOW",1,1)
	fraMinionAnchor.buttonShowHidden:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 3, -1);
	fraMinionAnchor.buttonShowHidden:SetBackdrop({bgFile="Interface\\BUTTONS\\WHITE8X8", edgeFile="Interface\\BUTTONS\\WHITE8X8", tile=false, tileSize=0, edgeSize=1, insets={left=0, right=0, top=0, bottom=0}})
	fraMinionAnchor.buttonShowHidden:SetBackdropColor(db.Colours.ShowHideButtonColour.r, db.Colours.ShowHideButtonColour.g, db.Colours.ShowHideButtonColour.b, db.Colours.ShowHideButtonColour.a)
	fraMinionAnchor.buttonShowHidden:SetBackdropBorderColor(db.Colours.ShowHideButtonBorderColour.r, db.Colours.ShowHideButtonBorderColour.g, db.Colours.ShowHideButtonBorderColour.b, db.Colours.ShowHideButtonBorderColour.a)


	fraMinionAnchor.buttonShowHidden.Update = function(self) 
		if (dbChar.ZonesAndQuests.ShowAllQuests == true) then
			fraMinionAnchor.buttonShowHidden:SetBackdropColor(db.Colours.ShowHideButtonActiveColour.r, db.Colours.ShowHideButtonActiveColour.g, db.Colours.ShowHideButtonActiveColour.b, db.Colours.ShowHideButtonActiveColour.a)
		else
			fraMinionAnchor.buttonShowHidden:SetBackdropColor(db.Colours.ShowHideButtonColour.r, db.Colours.ShowHideButtonColour.g, db.Colours.ShowHideButtonColour.b, db.Colours.ShowHideButtonColour.a)
		end
		fraMinionAnchor.buttonShowHidden:SetBackdropBorderColor(db.Colours.ShowHideButtonBorderColour.r, db.Colours.ShowHideButtonBorderColour.g, db.Colours.ShowHideButtonBorderColour.b, db.Colours.ShowHideButtonBorderColour.a)
	end
	
	-- Show/Hide hidden quest button events
	fraMinionAnchor.buttonShowHidden:RegisterForClicks("AnyUp")
	fraMinionAnchor.buttonShowHidden:SetScript("OnEnter", function(self) 
		fraMinionAnchor.buttonShowHidden:SetBackdropBorderColor(0, 0, 1, 1)
		if (db.ShowHelpTooltips == true) then
			if (db.MoveTooltipsRight == true) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
			else 
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 0);
			end
			
			GameTooltip:SetText(L["Show all quests button"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Enable to show all hidden quests"], 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)
	fraMinionAnchor.buttonShowHidden:SetScript("OnLeave", function(self) 
		fraMinionAnchor.buttonShowHidden:SetBackdropBorderColor(0, 0, 0, 1)
		GameTooltip:Hide()
	end)	
	fraMinionAnchor.buttonShowHidden:SetScript("OnClick", function() 
		if (IsControlKeyDown()) then
		 	local hidingZones = false;
			for k, ZoneInstance in pairs(curQuestInfo.ZoneList) do
				if (ZoneInstance.IsCollapsed == false) then
					hidingZones = true;
					break;
				end
			end

			for k, ZoneInstance in pairs(curQuestInfo.ZoneList) do
				dbChar.ZoneIsCollapsed[ZoneInstance.ID] =hidingZones;
			end
		else				
			dbChar.ZonesAndQuests.ShowAllQuests = not dbChar.ZonesAndQuests.ShowAllQuests
			fraMinionAnchor.buttonShowHidden.Update();
		end
		self:UpdateMinionHandler()
	end)
	

	
	fraMinionAnchor.BorderFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLQuestMinionBorder", fraMinionAnchor, db.MinionWidth,40,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0, 1)
	fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})
	fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
	fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)
	fraMinionAnchor.BorderFrame:Show()
	
	fraMinionAnchor.BottomFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLQuestMinionBottom", fraMinionAnchor, db.MinionWidth,40,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0, 1)

	
		
	btnSearchQuests = CreateFrame('Button', "SQLSearchQuestsButton", UIParent, 'SecureActionButtonTemplate')
	btnSearchQuests:SetPoint("TOPRIGHT", fraMinionAnchor, "TOPRIGHT", 0, 2);
	btnSearchQuests:SetHeight(24)
	btnSearchQuests:SetWidth(100)
	btnSearchQuests:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = false, tileSize = 16,edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 5}})
	btnSearchQuests:SetBackdropColor(0, 0, 0, 0.9)
	btnSearchQuests:SetBackdropBorderColor(1, 1, 1, 0)
	btnSearchQuests:SetFrameStrata("DIALOG")
	btnSearchQuests:SetFrameLevel(2)
	btnSearchQuests:Hide()
	btnSearchQuests:SetAttribute("type", "myFunction")
	btnSearchQuests.myFunction = function(self)
		local activityID, categoryID, filters, questName = LFGListUtil_GetQuestCategoryData(tmpQuest.ID);
		if not activityID then
			self:Hide();			
			return;
		end		

		if (LFGListFrame.CategorySelection.selectedCategory == categoryID and LFGListFrame.activePanel == LFGListFrame.SearchPanel and LFGListFrame:IsVisible()) then
			self:Hide();			

			LFGListFrame.SearchPanel.SearchBox:SetText(questName or "");
			local languages = C_LFGList.GetLanguageSearchFilter();
			C_LFGList.Search(categoryID, LFGListSearchPanel_ParseSearchTerms(questName), filters, 4, languages)
		else			
			if C_LFGList.GetActiveEntryInfo() then
				if LFGListUtil_CanListGroup() then
					C_LFGList.RemoveListing();
					LFGListFrame_SetPendingQuestIDSearch(LFGListFrame, questID);
				end
				return;
			end
			
			PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub); 
			
			local panel = LFGListFrame.CategorySelection;
			LFGListCategorySelection_SelectCategory(panel, categoryID, filters);
			LFGListEntryCreation_SetAutoCreateMode(panel:GetParent().EntryCreation, "quest", activityID, questID);
			 
			local searchPanel = panel:GetParent().SearchPanel;
			LFGListSearchPanel_Clear(searchPanel);
			searchPanel.SearchBox:SetText(questName or "");
			LFGListSearchPanel_SetCategory(searchPanel, panel.selectedCategory, panel.selectedFilters, baseFilters);
			LFGListFrame_SetActivePanel(panel:GetParent(), searchPanel);
			
		end
	end
	btnSearchQuests.TextFrame = SorhaQuestLog:doCreateLooseFrame("FRAME","SQLSearchQuestsButtonText",SQLSearchQuestsButton, SQLSearchQuestsButton:GetWidth(),1,1,"DIALOG",3,1)
	btnSearchQuests.TextFrame:SetPoint("TOPRIGHT", SQLSearchQuestsButton, "TOPRIGHT", -5, -4);
	btnSearchQuests.TextFrame.objFontString1 = btnSearchQuests.TextFrame:CreateFontString(nil, "OVERLAY");
	btnSearchQuests.TextFrame.objFontString1:SetPoint("TOPRIGHT", btnSearchQuests.TextFrame, "TOPRIGHT", 0, 0);
	btnSearchQuests.TextFrame.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.HeaderFont), db.Fonts.HeaderFontSize, db.Fonts.HeaderFontOutline)
	btnSearchQuests.TextFrame.objFontString1:SetSpacing(db.Fonts.HeaderFontLineSpacing)
	btnSearchQuests.TextFrame.objFontString1:SetJustifyH("RIGHT")
	btnSearchQuests.TextFrame.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	btnSearchQuests.TextFrame.objFontString1:SetText(strHeaderColour .. L["Click Until Gone"] .. "|r")
	
	fraMinionAnchor.CampaignButton = QuestTracker:GetMinionButton();
	fraMinionAnchor.CampaignButton.CampaignTooltip = CreateFrame("FRAME","CampaignItemTooltip",UIParent,"WarCampaignTooltipTemplate")

	self:CreateSmartItemButton()
	
	blnMinionInitialized = true
	self:MinionAnchorUpdate(false)
	self:doHiddenQuestsUpdate()	-- Update show/hide hidden quests button position/visibility etc
end

function QuestTracker:CreateSmartItemButton() 

	fraMinionAnchor.SmartItemButton = CreateFrame('Button', 'SQLSmartItemButton', UIParent, 'SorhaQuestLogItemButtonTemplate')
	local objButton = fraMinionAnchor.SmartItemButton;
	
	objButton.rangeTimer = -1

	if (MSQ) then
		local group = MSQ:Group("SorhaQuestLog", "Item Buttons")
		group:AddButton(objButton,{ Icon = objButton.icon })
	end	
	
	objButton:SetScript('OnEvent', function(self, event)
		if (event == "PLAYER_TARGET_CHANGED") then
			self.rangeTimer = TOOLTIP_UPDATE_TIME;

		elseif(event == 'BAG_UPDATE_COOLDOWN') then
			if (self.questLogIndex) then
				QuestObjectiveItem_UpdateCooldown(self)
			end

		elseif(event == 'PLAYER_REGEN_ENABLED') then
			self:SetParent(fraMinionAnchor);
			self:SetPoint("TOPRIGHT", fraMinionAnchor, "TOPRIGHT", -2, -2);
			self:UnregisterEvent(event)
		end
	end)

	if(InCombatLockdown()) then
		objButton:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		objButton:SetParent(fraMinionAnchor);
		objButton:SetPoint("TOPRIGHT", fraMinionAnchor, "TOPRIGHT", -2, -2);
	end	

	objButton:SetID(0)
	objButton.questLogIndex = nil;
	objButton:RegisterEvent('BAG_UPDATE_COOLDOWN')
	objButton:RegisterEvent("PLAYER_TARGET_CHANGED")
	objButton:SetScale(0.9);
	objButton:SetScript('OnUpdate', function(self, elapsed)
		self.rangeTimer = self.rangeTimer + elapsed;
		
		if(self.rangeTimer >= TOOLTIP_UPDATE_TIME) then
			if (not self.questLogIndex or IsQuestLogSpecialItemInRange(self.questLogIndex) == 0) then
				SetItemButtonTextureVertexColor(self, 0.8, 0.1, 0.1)
			else
				SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
			end
			self.rangeTimer = 0
		end
	end)

	objButton:Hide();


		
end

function QuestTracker:UpdateMinionHandler()	
	if (blnWasAClick == true) then -- Was the event called from a click (Skips the delay on header collapses etc)
		blnMinionUpdating = true
		self:UpdateMinion()
	elseif (blnMinionUpdating == false) then --If not updating then update, forces a 0.5 second delay between system called updates
		if (blnIgnoreUpdateEvents == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.3)
		end
	end
end

function QuestTracker:UpdateMinion()
	blnMinionUpdating = true
	blnWasAClick = false

	--Build minion
	if (blnMinionInitialized == false) then
		self:CreateMinionLayout()
	end	

	--Get Quest Info, Compare quest data
	self:GetQuestLogInformation();
	curQuestInfo:CompleteCheck();
	
	-- Update LDB 
	if (LDB) then
		if (SorhaQuestLog.SQLBroker ~= nil) then
			if (db.UseQuestCountMaxText == true) then
				SorhaQuestLog.SQLBroker.text = strInfoColour .. curQuestInfo.QuestCount .. "/25|r"
			else
				SorhaQuestLog.SQLBroker.text = strInfoColour .. curQuestInfo.QuestCount .. "/"..  curQuestInfo.CompletedQuestCount  .. "|r"
			end
		end
	end

	--Do nothing if hidden
	if (self:IsVisible() == false) then
		blnMinionUpdating = false
		return ""
	end

	-- Release all used buttons
	fraMinionAnchor.CampaignButton:Hide();
	for k, objButton in pairs(tblUsingButtons) do
		self:RecycleMinionButton(objButton)
	end
	wipe(tblUsingButtons)

	local createItemButtons = true;
	if(InCombatLockdown()) then
		createItemButtons = false;
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	end

	if (not InCombatLockdown()) then
		self:UpdateSmartItemButton();
		-- Release all used Item buttons
		for k, objItemButton in pairs(tblUsedItemButtons) do
			self:RecycleItemButton(objItemButton)
		end
		wipe(tblUsedItemButtons)
	end
	
	-- Setup variables
	local isVisible = false;
	local intSpacingIncrease = 0
	local intLargestWidth = 20
	local blnLargestWidthIsHeader = false
	local intHeaderOutlineOffset = 0
	local intQuestOutlineOffset = 0
	local intObjectiveOutlineOffset = 0
	local intYPosition = 0
	local intInitialYOffset = 0
	local intButtonSize = intItemButtonSize * db.ItemButtonScale
	local intQuestOffset =  db.ZonesAndQuests.QuestTitleIndent
	local intObjectiveOffset =  db.ZonesAndQuests.ObjectivesIndent
	local intQuestWithItemButtonOffset = intQuestOffset + intButtonSize
	


	
	--Add in slight offsets for outlined text to try stop overlap
	if (db.Fonts.HeaderFontOutline == "THICKOUTLINE") then
		intHeaderOutlineOffset = 2
	elseif (db.Fonts.HeaderFontOutline == "OUTLINE" or db.Fonts.HeaderFontOutline == "MONOCHROMEOUTLINE") then
		intHeaderOutlineOffset = 1
	end
	if (db.Fonts.QuestFontOutline == "THICKOUTLINE") then
		intQuestOutlineOffset = 1.5
	elseif (db.Fonts.QuestFontOutline == "OUTLINE" or db.Fonts.QuestFontOutline == "MONOCHROMEOUTLINE") then
		intQuestOutlineOffset = 0.5
	end
	if (db.Fonts.ObjectiveFontOutline == "THICKOUTLINE") then
		intObjectiveOutlineOffset = 1.5
	elseif (db.Fonts.ObjectiveFontOutline == "OUTLINE" or db.Fonts.ObjectiveFontOutline == "MONOCHROMEOUTLINE") then
		intObjectiveOutlineOffset = 0.5
	end	
		
	-- Number of quests title display
	if (curQuestInfo.HaveTrackedQuests == false and db.AutoHideTitle == true) then
		fraMinionAnchor.objFontString:SetText("");
		fraMinionAnchor.buttonShowHidden:Hide()	
	else
		isVisible = true;
		
		if (db.ZonesAndQuests.AllowHiddenQuests == true) then
			fraMinionAnchor.buttonShowHidden:Show()
		else
			fraMinionAnchor.buttonShowHidden:Hide()	
		end
		
		if (db.ShowNumberOfQuests == true or db.ShowNumberOfDailyQuests == true or db.ZonesAndQuests.AllowHiddenQuests == true) then
			intYPosition = -db.Fonts.MinionTitleFontSize - db.Fonts.MinionTitleFontLineSpacing;
		else
			intYPosition = -2 - db.Fonts.MinionTitleFontLineSpacing;
		end
		
		if (db.ShowNumberOfQuests == true or db.ShowNumberOfDailyQuests == true) then
			fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
			fraMinionAnchor.objFontString:SetSpacing(db.Fonts.MinionTitleFontLineSpacing)
			if (db.Fonts.MinionTitleFontShadowed == true) then
				fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
			else
				fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
			end
			
			local strText = ""
			if (db.ShowNumberOfQuests == true) then
				if (db.UseQuestCountMaxText == true) then
					strText = strText .. strInfoColour .. curQuestInfo.QuestCount .. "/25 |r"
				else
					strText = strText .. strInfoColour .. curQuestInfo.QuestCount .. "/"..  curQuestInfo.CompletedQuestCount  .. " |r"
				end

			end
			if (db.ShowNumberOfDailyQuests == true) then
				strText = strText ..  strInfoColour .. "(" .. GetDailyQuestsCompleted() .. ")|r"
			end
			
			
			fraMinionAnchor.objFontString:SetText(strText);
			if (fraMinionAnchor.objFontString:GetWidth() > intLargestWidth) then
				if (db.ZonesAndQuests.AllowHiddenQuests == true) then
					intLargestWidth = fraMinionAnchor.objFontString:GetWidth() + 20 -- Offset for the show/hide button pushing the fontstring accross
				else
					intLargestWidth = fraMinionAnchor.objFontString:GetWidth()
				end
			end
		else
			fraMinionAnchor.objFontString:SetText("");
		end
	end

	
	intInitialYOffset = intYPosition;
	--local tblTasks = {};
	local tblItemButtons = {};

	-- Zone/Quest buttons
	local campaignId = C_CampaignInfo.GetCurrentCampaignID();
	local objButton = nil
	for k, ZoneInstance in zoneSortChooser(curQuestInfo.ZoneList) do
		if (curQuestInfo.HaveTrackedQuests == false and db.AutoHideTitle == true and ZoneInstance.ID ~= campaignZoneID) then
			break
		end
		
		if (dbChar.ZonesAndQuests.ShowAllQuests == true or not(db.ZonesAndQuests.AllowHiddenQuests == true and db.ZonesAndQuests.QuestHeadersHideWhenEmpty == true and ZoneInstance:HaveVisibleQuests() == false) or ZoneInstance.ID == campaignZoneID) then
			if (db.ZonesAndQuests.HideZoneHeaders == false and not (ZoneInstance.IsFakeZone == true and ZoneInstance:HaveVisibleQuests() == false) or (ZoneInstance.ID == campaignZoneID and campaignId ~= nil)) then
				
				if (ZoneInstance.ID and ZoneInstance.ID == campaignZoneID) then
					objButton = self:GetCampaignButton(ZoneInstance)
				
					objButton:SetWidth(db.MinionWidth)
					--
					if (objButton.objFontString1:GetWidth() > intLargestWidth) then
						intLargestWidth = objButton.objFontString1:GetWidth()
						blnLargestWidthIsHeader = true
					end
					--
					objButton.objFontString1:SetWidth(db.MinionWidth)
					intSpacingIncrease = objButton.objFontString1:GetHeight() + intHeaderOutlineOffset + db.Fonts.HeaderFontLineSpacing
					
					local nextOffset = objButton.objFontString1:GetHeight() + intHeaderOutlineOffset + db.Fonts.HeaderFontLineSpacing;
					objButton.objFontString2:SetPoint("TOPLEFT", objButton, "TOPLEFT", intObjectiveOffset, -nextOffset);
					objButton.objFontString2:SetWidth(db.MinionWidth)
					
					
					nextOffset = objButton.objFontString2:GetHeight() + intQuestOutlineOffset + db.Fonts.QuestFontLineSpacing;
					intSpacingIncrease = intSpacingIncrease + nextOffset
					
					
					objButton:SetHeight(intSpacingIncrease)

					objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", 0, intYPosition - intHeaderOutlineOffset)
					intYPosition = intYPosition - intSpacingIncrease
				else
					objButton = self:GetMinionHeaderButton(ZoneInstance)
										
					objButton:SetWidth(db.MinionWidth)
					--
					if (objButton.objFontString1:GetWidth() > intLargestWidth) then
						intLargestWidth = objButton.objFontString1:GetWidth()
						blnLargestWidthIsHeader = true
					end
					--
					objButton.objFontString1:SetWidth(db.MinionWidth)
					
					intSpacingIncrease = objButton.objFontString1:GetHeight() + intHeaderOutlineOffset + db.Fonts.HeaderFontLineSpacing
					objButton:SetHeight(intSpacingIncrease)
					tinsert(tblUsingButtons, objButton)

					objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", 0, intYPosition - intHeaderOutlineOffset)
					intYPosition = intYPosition - intSpacingIncrease
				end
			end
			
			if (ZoneInstance.IsCollapsed == false) then
				-- Create each quest in zone

				local questSortIndex = 0;
				for k2, QuestInstance in questSortChooser(ZoneInstance.QuestList) do
					questSortIndex = questSortIndex + 1;
					QuestInstance.LastSortIndex = questSortIndex;

					if ((QuestInstance.IsHidden == false or QuestInstance.IsTask == true) or db.ZonesAndQuests.AllowHiddenQuests == false or dbChar.ZonesAndQuests.ShowAllQuests == true) then
						if (not (QuestInstance.IsTask == true and ZoneInstance.IsFakeZone == false)) then
							
							local blnHasShownButton = false
							local intThisQuestsOffset = intQuestOffset
							if (db.ShowItemButtons == true and QuestInstance.QuestItem) then -- Item Buttons on and has a button
								if (db.HideItemButtonsForCompletedQuests == false or (db.HideItemButtonsForCompletedQuests and QuestInstance.IsComplete == false and QuestInstance.IsFailed == false) or (QuestInstance.QuestItem.ShowWhenComplete and QuestInstance.IsComplete)) then -- Button not hidden because of completion
									blnHasShownButton = true
		
									if (db.IndentItemButtons == true and db.MoveTooltipsRight == false) then
										intThisQuestsOffset = intQuestWithItemButtonOffset
									end
								end
							end
							if (db.IndentItemButtonQuestsOnly == false and db.IndentItemButtons == true and db.MoveTooltipsRight == false) then
								intThisQuestsOffset = intQuestWithItemButtonOffset				
							end

							objButton = self:GetMinionQuestButton(QuestInstance)
							objButton.intOffset = intThisQuestsOffset
							objButton:SetWidth(db.MinionWidth - intThisQuestsOffset)

							-- Find out if either string is larger then the current largest string
							if (objButton.objFontString1:GetWidth() + intThisQuestsOffset > intLargestWidth) then
								intLargestWidth = objButton.objFontString1:GetWidth() + intThisQuestsOffset*2
								blnLargestWidthIsHeader = false
							end
							if (objButton.objFontString2:GetWidth() + (intThisQuestsOffset + intObjectiveOffset) > intLargestWidth) then
								intLargestWidth = objButton.objFontString2:GetWidth() + intThisQuestsOffset + intObjectiveOffset
								blnLargestWidthIsHeader = false
							end

							objButton.objFontString1:SetWidth(db.MinionWidth - intThisQuestsOffset)

							-- Set second fontstring of the buttons position
							local nextOffset = objButton.objFontString1:GetHeight() + intQuestOutlineOffset + db.Fonts.QuestFontLineSpacing;

							if (QuestInstance.Timer ~= nil and not QuestInstance.IsComplete) then
								objButton.TimerBar = QuestTracker:GetTimerStatusBar(QuestInstance.Timer);
								objButton.TimerBar:SetParent(objButton)
								objButton.TimerBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -nextOffset-3);
								nextOffset = nextOffset + objButton.TimerBar:GetHeight() + 5;
								
								objButton.TimerBar.Offsets = intThisQuestsOffset;

								if (intLargestWidth < objButton.TimerBar.Width) then
									intLargestWidth = objButton.TimerBar.Width
								end
							end

							objButton.objFontString2:SetPoint("TOPLEFT", objButton, "TOPLEFT", intObjectiveOffset, -nextOffset);
							objButton.objFontString2:SetWidth(db.MinionWidth - intThisQuestsOffset - intObjectiveOffset)
							
							
							--Progress bars
							if (QuestInstance.HasProgressBar == false or (QuestInstance.HasProgressBar == true and QuestInstance.IsComplete == true)) then
								-- Find spacing needed for next button
								nextOffset = objButton.objFontString2:GetHeight() + intObjectiveOutlineOffset + nextOffset								
								intSpacingIncrease = nextOffset
							else
								local percentText = format("%d", QuestInstance.ProgressBarPercent);
								local tmpText = objButton.objFontString2:GetText();
								if (tmpText == nil) then
									tmpText = " - " .. QUEST_COMPLETE .. ": ";
								end

								objButton.objFontString2:SetText(tmpText);
								nextOffset = objButton.objFontString2:GetHeight() + intObjectiveOutlineOffset + nextOffset								


								if (db.UseStatusBars == false) then 
									objButton.objFontString2:SetText(objButton.objFontString2:GetText() .. percentText .. "%");
									intSpacingIncrease = nextOffset	

								else
									nextOffset = nextOffset + 4
									intSpacingIncrease = nextOffset

									if (objButton.StatusBar == nil) then
										objButton.StatusBar = self:GetStatusBar()
									end
								
									objButton.StatusBar:Show()
									objButton.StatusBar:SetParent(objButton)
									objButton.StatusBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", intObjectiveOffset, -nextOffset);
									
									-- Setup colours and texture
									objButton.StatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
									objButton.StatusBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)									
									objButton.StatusBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
									objButton.StatusBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)									
									objButton.StatusBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

								
									objButton.StatusBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.ObjectiveFont), db.Fonts.ObjectiveFontSize, db.Fonts.ObjectiveFontOutline)
									if (db.Fonts.ObjectiveFontShadowed == true) then
										objButton.StatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
									else
										objButton.StatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
									end
									
									objButton.StatusBar.objFontString:SetText(percentText .. "%")
									
									-- Find out if string is larger then the current largest string
									if (objButton.StatusBar.objFontString:GetWidth() > intLargestWidth) then
										intLargestWidth = objButton.StatusBar.objFontString:GetWidth()
									end
									objButton.StatusBar.objFontString:SetWidth(db.MinionWidth)
									objButton.StatusBar:SetWidth(db.MinionWidth - intThisQuestsOffset - intObjectiveOffset)
									objButton.StatusBar.Offsets = intThisQuestsOffset + intObjectiveOffset;
									
									objButton.StatusBar.objFontString:SetHeight(objButton.StatusBar.objFontString:GetHeight() + 1.5);
									objButton.StatusBar:SetHeight(objButton.StatusBar.objFontString:GetHeight())	

									
									objButton.StatusBar:SetMinMaxValues(0, 100);
									objButton.StatusBar:SetValue(tonumber(QuestInstance.ProgressBarPercent));
								
									nextOffset = objButton.StatusBar:GetHeight() + 2							
									intSpacingIncrease = intSpacingIncrease + nextOffset
								end
							end

						
							-- If theres an item button to be shown add it
							if (blnHasShownButton == true) then
								
								if (createItemButtons == true) then
									local tmp = {['Item'] = QuestInstance.QuestItem, ['Offset'] = intYPosition};
									tinsert(tblItemButtons, tmp)
									--local objItemButton = self:GetItemButton(QuestInstance.QuestItem, intYPosition)
								end
								
								-- If a button is heigher then its quest then expand the quest frame to stop overlapping buttons
								if (intButtonSize > intSpacingIncrease) then
									intSpacingIncrease = intButtonSize
									objButton.objFontString1:SetHeight(intButtonSize)
								end
							end



							objButton:SetHeight(intSpacingIncrease)
							tinsert(tblUsingButtons, objButton)

							objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", intThisQuestsOffset, intYPosition)
							intYPosition = intYPosition - intSpacingIncrease - db.Fonts.ObjectiveFontLineSpacing - db.ZonesAndQuests.QuestAfterPadding;
						end
					end
				end
			end
		end
	end


	--Create Item buttons last for position data
	for key, ItemButtonInfo in pairs(tblItemButtons) do
		if (db.GrowUpwards == false) then
			local objItemButton = self:GetItemButton(ItemButtonInfo.Item, ItemButtonInfo.Offset)
		else
			local offset = ItemButtonInfo.Offset - intYPosition + 5;
			local objItemButton = self:GetItemButton(ItemButtonInfo.Item, offset)
		end		
	end

	
	-- Auto collapse
	if(InCombatLockdown()  == false) then		
		fraMinionAnchor:SetWidth(db.MinionWidth)	
	end

	local intBorderWidth = db.MinionWidth
	if (db.MinionCollapseToLeft == true) then
		if (intLargestWidth < db.MinionWidth) then
			
			if(InCombatLockdown() == false) then		
				fraMinionAnchor:SetWidth(intLargestWidth)
			end

			intBorderWidth = intLargestWidth
			
			for k, objButton in pairs(tblUsingButtons) do
				objButton.objFontString1:SetWidth(intLargestWidth - objButton.intOffset)
				objButton:SetWidth(intLargestWidth - objButton.intOffset)

				if (objButton.StatusBar ~= nil) then
					objButton.StatusBar.objFontString:SetWidth(intLargestWidth - objButton.StatusBar.Offsets)
					objButton.StatusBar:SetWidth(intLargestWidth - objButton.StatusBar.Offsets)
				end
				if (objButton.TimerBar ~= nil) then
					local width = math.floor(intLargestWidth - objButton.TimerBar.Offsets);
					objButton.TimerBar.objFontString:SetWidth(width)
					objButton.TimerBar:SetWidth(width)
				end	
			end
		end
	end
	
	fraMinionAnchor.BottomFrame:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", 0, intYPosition);
	fraMinionAnchor.BottomFrame:SetWidth(fraMinionAnchor:GetWidth());
	fraMinionAnchor.BottomFrame:SetHeight(5);
	
	
	-- Show border if at least the title is shown
	if (isVisible == false) then
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, 0)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, 0)		
	else
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)	
		fraMinionAnchor.BorderFrame:SetWidth(intBorderWidth + 16)
	end
	
	-- Reposition/Resize the border and the Achievements Anchor based on grow upwards option
	fraMinionAnchor.BorderFrame:ClearAllPoints()
	if (db.GrowUpwards == false) then
		fraMinionAnchor.BorderFrame:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", -6, 6);
		fraMinionAnchor.BorderFrame:SetHeight((-intYPosition) + 6 + fraMinionAnchor:GetHeight()/2)
		fraMinionAnchor.fraQuestsAnchor:ClearAllPoints()
		fraMinionAnchor.fraQuestsAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
	else
		fraMinionAnchor.BorderFrame:SetPoint("TOPLEFT", fraMinionAnchor.fraQuestsAnchor, "TOPLEFT", -6,  6 + intInitialYOffset);
		fraMinionAnchor.BorderFrame:SetHeight((-intYPosition) + fraMinionAnchor:GetHeight() - 2)
		fraMinionAnchor.fraQuestsAnchor:ClearAllPoints()
		fraMinionAnchor.fraQuestsAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, -intYPosition+5);
	end

	blnMinionUpdating = false
end 

function QuestTracker:UpdateSmartItemButton()
	local objButton = fraMinionAnchor.SmartItemButton;
	local questInstance = self:GetClosestItemQuest()
	if (questInstance)	then
		objButton:SetID(questInstance.Index)
		objButton.questLogIndex = questInstance.Index;			

		local objItem = questInstance.QuestItem;
		if(objItem.Link) then
			if(objItem.Link == objButton.itemLink and objButton:IsShown()) then
				return
			end
			objButton.charges = objItem.Charges;
			objButton.link = objItem.Link
			objButton.item = objItem.Item		
			SetItemButtonTexture(objButton, objItem.Item)
			SetItemButtonCount(objButton, objItem.Charges)
			objButton.HotKey:Hide()
		end
		
		--update function
		QuestObjectiveItem_UpdateCooldown(objButton)
		objButton.Cooldown:SetFrameStrata("DIALOG")	
		objButton:SetAttribute('item', objButton.link)
		if (db.ShowCurrentSmartQuestItem) then
			objButton:Show();
		end
	else
		objButton:SetID(0)
		objButton.questLogIndex = nil;
		objButton.itemLink = nil;
		objButton:Hide();
	end
end


--Quest minion
function QuestTracker:GetQuestLogInformation()
	if (curQuestInfo == nil) then
		curQuestInfo = SQLQuestLogData:new();
	else
		curQuestInfo:Update();
	end
end

function QuestTracker:GetCompletionColourString(dblPercent)
	if (dblPercent == 0.00) then
		return strObjective00Colour
	elseif (dblPercent < 0.25) then
		return strObjective01to24Colour
	elseif (dblPercent >= 0.25 and dblPercent < 0.50) then
		return strObjective25to49Colour
	elseif (dblPercent >= 0.50 and dblPercent < 0.75) then
		return strObjective50to74Colour
	elseif (dblPercent >= 0.75 and dblPercent < 1) then
		return strObjective75to99Colour
	else
		return strObjective100Colour
	end
end

function QuestTracker:GetCompletionColourRGB(dblPercent)
	if (dblPercent < 0.25) then
		return db.Colours.Objective00PlusColour.r, db.Colours.Objective00PlusColour.g, db.Colours.Objective00PlusColour.b
	elseif (dblPercent >= 0.25 and dblPercent < 0.50) then
		return db.Colours.Objective25PlusColour.r, db.Colours.Objective25PlusColour.g, db.Colours.Objective25PlusColour.b
	elseif (dblPercent >= 0.50 and dblPercent < 0.75) then
		return db.Colours.Objective50PlusColour.r, db.Colours.Objective50PlusColour.g, db.Colours.Objective50PlusColour.b
	elseif (dblPercent >= 0.75 and dblPercent < 1) then
		return db.Colours.Objective75PlusColour.r, db.Colours.Objective75PlusColour.g, db.Colours.Objective75PlusColour.b
	else
		return db.Colours.ObjectiveDoneColour.r, db.Colours.ObjectiveDoneColour.g, db.Colours.ObjectiveDoneColour.b
	end
end

function QuestTracker:doHiddenQuestsUpdate()
	-- Show/Hide hidden quests button and move quest count text accordingly
	if (blnMinionInitialized == true) then
		if (db.ZonesAndQuests.AllowHiddenQuests == true) then
			fraMinionAnchor.objFontString:ClearAllPoints()
			fraMinionAnchor.objFontString:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 16, 0);
		else
			fraMinionAnchor.objFontString:ClearAllPoints()
			fraMinionAnchor.objFontString:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
		end		
		fraMinionAnchor.buttonShowHidden.Update();
	end
end

function QuestTracker:DisplayRightClickMenu(objButton)
	local objMenu = CreateFrame("Frame", "SorhaQuestLogMenuThing")
	local intLevel = 1
	local info = {}
	
	objMenu.displayMode = "MENU"
	objMenu.initialize = function(self, intLevel)
		if not intLevel then return end
		wipe(info)
		if intLevel == 1 then
			-- Create the title of the menu
			info.isTitle = 1
			info.text = L["Show/Hide Quests"]
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, intLevel)
			
			local intCurrentButton = 0
			local curZone = curQuestInfo.ZoneList[objButton.ZoneInstance.ID];
				
			-- Show/Hide buttons for each quest
			for k2, QuestInstance in pairs(curZone.QuestList) do
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = nil
				info.text = QuestInstance.Title;
				info.func = function()
					if (QuestInstance.IsHidden == true) then
						if (GetNumQuestWatches() >= 25) then
							UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, 25), 1.0, 0.1, 0.1, 1.0);
						else
							AddQuestWatch(QuestInstance.Index)
						end
					else
						RemoveQuestWatch(QuestInstance.Index)
					end
					QuestTracker:UpdateMinionHandler()
				end
				info.checked = not(QuestInstance.IsHidden);
				UIDropDownMenu_AddButton(info, intLevel)
			end
	
			-- Hide all button if not all hidden
			if (curZone.HaveVisibleQuests == true)then
				info.text = L["Hide All"]
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = 1
				info.func = function()
					for k2, QuestInstance in pairs(curZone.QuestList) do
						RemoveQuestWatch(QuestInstance.Index);
					end
					QuestTracker:UpdateMinionHandler()
				end
				UIDropDownMenu_AddButton(info, intLevel)
			end
			
			-- Show all button if not all hidden
			if (curZone.HaveVisibleQuests == true and curZone.HiddenQuestCount > 0)then
				info.text = L["Show All"]
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = 1
				info.func = function()
					for k2, QuestInstance in pairs(curZone.QuestList) do
						if (GetNumQuestWatches() >= 25) then
							UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, 25), 1.0, 0.1, 0.1, 1.0);
							break
						else
							AddQuestWatch(QuestInstance.Index)
						end
					end
					QuestTracker:UpdateMinionHandler()
				end
				UIDropDownMenu_AddButton(info, intLevel)
			end

			-- Close menu item
			info.text = CLOSE
			info.disabled = nil
			info.isTitle = nil
			info.notCheckable = 1
			info.func = function() CloseDropDownMenus() end
			UIDropDownMenu_AddButton(info, intLevel)
		end
	end

	ToggleDropDownMenu(1, nil, objMenu, objButton, 0, 0)
end

function QuestTracker:DisplayAltRightClickMenu(objButton)
	local objMenu = CreateFrame("Frame", "SorhaQuestLogMenuThing")
	local intLevel = 1
	local info = {}
	
	objMenu.displayMode = "MENU"
	objMenu.initialize = function(self, intLevel)
		if not intLevel then return end
		wipe(info)
		if intLevel == 1 then
			-- Create the title of the menu
			info.isTitle = 1
			info.text = L["Expand/Collapse Zones"]
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, intLevel)
			
			-- Collapse/Expand button for each zone
			for k, ZoneInstance in pairs(curQuestInfo.ZoneList) do
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = nil
				info.text = ZoneInstance.Title;
				info.func = function()
					if (ZoneInstance.IsCollapsed == true) then
						dbChar.ZoneIsCollapsed[ZoneInstance.ID] = false;
					else
						dbChar.ZoneIsCollapsed[ZoneInstance.ID] = true;
					end
					QuestTracker:UpdateMinionHandler();
				end
				info.checked = not(ZoneInstance.IsCollapsed)
				UIDropDownMenu_AddButton(info, intLevel)
			end

			-- Collapse all button if not all hidden
			if (curQuestInfo.CollapsedZoneCount < curQuestInfo.ZoneCount)then
				info.text = L["Collapse All"]
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = 1
				info.func = function()
					for k, ZoneInstance in pairs(curQuestInfo.ZoneList) do
						dbChar.ZoneIsCollapsed[ZoneInstance.ID] = true;
					end
					QuestTracker:UpdateMinionHandler();
				end
				UIDropDownMenu_AddButton(info, intLevel)
			end
			
			-- Expand all button if not all hidden
			if (curQuestInfo.CollapsedZoneCount > 0)then
				info.text = L["Expand All"]
				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = 1
				info.func = function()
					for k, ZoneInstance in pairs(curQuestInfo.ZoneList) do
						dbChar.ZoneIsCollapsed[ZoneInstance.ID] = false;
					end
					QuestTracker:UpdateMinionHandler();
				end
				UIDropDownMenu_AddButton(info, intLevel)
			end

			-- Close menu item
			info.text = CLOSE
			info.disabled = nil
			info.isTitle = nil
			info.notCheckable = 1
			info.func = function() CloseDropDownMenus() end
			UIDropDownMenu_AddButton(info, intLevel)
		end
	end

	ToggleDropDownMenu(1, nil, objMenu, objButton, 0, 0)
end

function QuestTracker:CheckBags()
	for k, intBag in pairs(tblBagsToCheck) do
		for intSlot = 1, GetContainerNumSlots(intBag), 1 do 
			local isQuestItem, questId, isActive = GetContainerItemQuestInfo(intBag, intSlot);
			if (questId ~= nil and isActive == false) then
				local intID = GetContainerItemID(intBag, intSlot)
				if (blnFirstBagCheck == true) then
					tinsert(tblHaveQuestItems, intID)
				else
					if not(tContains(tblHaveQuestItems, intID)) then
						tinsert(tblHaveQuestItems, intID)
						local itemName, itemLink, itemRarity , _, _, _, _, _,_, itemTexture, _ = GetItemInfo(intID)
						local _, _, _, hex = GetItemQualityColor(itemRarity)
						
						hex = "|c" .. hex
						
						local strOutput = nil
						if (db.sink20OutputSink == "Channel") then
							strOutput = UnitName("player") .. " " .. L["picked up a quest starting item: "] .. hex .. itemName .. "|r"
							self:Pour(strOutput, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b,_,_,_,_,_,itemTexture)
						else
							local strItem = ""
							if (db.sink20OutputSink == "ChatFrame") then
								strItem = "|T" .. itemTexture .. ":15|t"
							else
								strItem = "|T" .. itemTexture .. ":20:20:-5|t"
							end
							
							strOutput = L["You picked up a quest starting item: "] .. " " .. strItem .. hex .. itemLink .. "|r"
							self:Pour(strOutput, db.Colours.NotificationsColour.r, db.Colours.NotificationsColour.g, db.Colours.NotificationsColour.b)
						end
						
						-- Play sound if enabled
						if ((GetTime() - intTimeOfLastSound) > 1 and db.Notifications.QuestItemFoundSound ~= "None") then
							PlaySoundFile(LSM:Fetch("sound", db.Notifications.QuestItemFoundSound))
							intTimeOfLastSound = GetTime()
						end
					end
				end
			end
		end
	end
	wipe(tblBagsToCheck)

	if (blnFirstBagCheck == true) then
		blnFirstBagCheck = false
	end
	blnBagCheckUpdating = false
end

function QuestTracker:doHandleZoneChange()
	blnIgnoreUpdateEvents = true
	
	local blnNewZone = not(strZone == GetRealZoneText())
	strZone = GetRealZoneText()
	strSubZone = GetSubZoneText()
	local blnChanged = false
	
	if (db.ZonesAndQuests.CollapseOnLeave == true or db.ZonesAndQuests.ExpandOnEnter == true) then
		if (curQuestInfo == nil) then
			self:GetQuestLogInformation()
		end

		local numEntries, numQuests = GetNumQuestLogEntries();	
		for i = numEntries, 1, -1 do
			local zoneKey = GetQuestLogTitle(i);
			local zone = curQuestInfo.ZoneList[zoneKey];

			if (zone) then
				if (zone.Title == strZone or zone.Title == strSubZone) then
					if (db.ZonesAndQuests.ExpandOnEnter == true and zone.IsCollapsed == true) then
						zone:Expand();
						blnChanged = true
					end
				else		
					if (db.ZonesAndQuests.CollapseOnLeave == true and zone.IsCollapsed == false and blnNewZone) then				
						zone:Collapse();
						blnChanged = true
					end				
				end
			end
		end
	end
	
	blnIgnoreUpdateEvents = false
	if (blnMinionInitialized == true and blnChanged == true) then
		self:UpdateMinionHandler()
	end
end

function QuestTracker:GetClosestItemQuest()
	local itemQuests = {}
	for k, QuestInstance in pairs(curQuestInfo.QuestList) do
		if (db.ShowItemButtons == true and QuestInstance.QuestItem) then
			if (db.HideItemButtonsForCompletedQuests == false or (db.HideItemButtonsForCompletedQuests and QuestInstance.IsComplete == false and QuestInstance.IsFailed == false) or (QuestInstance.QuestItem.ShowWhenComplete and QuestInstance.IsComplete)) then
		
				QuestInstance.Distance = 0;
				local distanceSq, onContinent = GetDistanceSqToQuest(QuestInstance.Index)
				if(onContinent) then
					QuestInstance.Distance =  distanceSq;
				end	
				tinsert(itemQuests, QuestInstance)
			end
		end
	end
	if (#itemQuests < 1) then
		return nil	
	end
	for k, QuestInstance in spairs(itemQuests, function(itemQuests,a,b) return itemQuests[b].Distance > itemQuests[a].Distance end) do
		return QuestInstance;
	end
end



--Click Bindings
function QuestTracker:UpdateClickBindings()
	tblQuestClickBindings = {};
	tblQuestClickBindings[db.ClickBinds.OpenLog] = function(questInstance) QuestTracker:OpenQuestLog(questInstance); end;
	tblQuestClickBindings[db.ClickBinds.OpenFullLog] = function(questInstance) QuestTracker:OpenFullQuestLog(questInstance); end;
	tblQuestClickBindings[db.ClickBinds.AbandonQuest] = function(questInstance) QuestTracker:AbandonQuest(questInstance); end;
	tblQuestClickBindings[db.ClickBinds.TrackQuest] = function(questInstance) QuestTracker:TrackQuest(questInstance); end;
	tblQuestClickBindings[db.ClickBinds.LinkQuest] = function(questInstance) QuestTracker:LinkQuest(questInstance); end;	
	tblQuestClickBindings[db.ClickBinds.HideShowQuest] = function(questInstance) QuestTracker:HideShowQuest(questInstance); end;
	tblQuestClickBindings[db.ClickBinds.FindGroup] = function(questInstance) QuestTracker:FindQuestGroup(questInstance); end;
	
end

function QuestTracker:HandleQuestClick(binding, questInstance)
	if (tblQuestClickBindings[binding]) then
		tblQuestClickBindings[binding](questInstance);
	end
end

function QuestTracker:OpenQuestLog(questInstance)
	if (questInstance.IsWorldQuest) then
		if(WorldMapFrame:IsShown() ~= true) then
			ToggleWorldMap()
		end
		local mapID, zoneMapID = C_TaskQuest.GetQuestZoneID(questInstance.ID)
		if mapID then
			OpenQuestLog(mapID);
			WorldMapPing_StartPingQuest(questInstance.ID);
		end
		
		
		SetSuperTrackedQuestID(questInstance.ID)
		
		return
	end
	if ( IsQuestComplete(questInstance.ID) and GetQuestLogIsAutoComplete(questInstance.Index) ) then
		AutoQuestPopupTracker_RemovePopUp(questInstance.ID);
		ShowQuestComplete(questInstance.Index);
	else
		QuestLogPopupDetailFrame_Show(questInstance.Index);
	end
end

function QuestTracker:OpenFullQuestLog(questInstance)
	if (questInstance.IsWorldQuest) then
		if IsAddOnLoaded("WorldQuestGroupFinder") then 
			WorldQuestGroupFinder.HandleBlockClick(questInstance.ID) 
		else
			LFGListUtil_FindQuestGroup(questInstance.ID);
		end;
		return
	end
	if (QuestLogFrame and QuestLog_SetSelection) then --Legacy quest support
		QuestLog_SetSelection(questInstance.Index);
		if (QuestLogFrame:IsVisible() == false) then
			if (ToggleQuestLog) then
				ToggleQuestLog();
			end
		end
	else
		QuestMapFrame_OpenToQuestDetails(questInstance.ID);
	end
end

function QuestTracker:FindQuestGroup(questInstance)
	if (questInstance.IsWorldQuest and IsAddOnLoaded("WorldQuestGroupFinder")) then 
		WorldQuestGroupFinder.HandleBlockClick(questInstance.ID) 
	else		
		if (C_LFGList.CanCreateQuestGroup(questInstance.ID)) then
			LFGListUtil_FindQuestGroup(questInstance.ID)
		else
			print(L["The LFG tool does not work with Quest: "] .. questInstance.Title);
		end
	end
end

function QuestTracker:TrackQuest(questInstance)
	SetSuperTrackedQuestID(questInstance.ID)
	
	if (DugisGuideViewer and DugisGuideViewer.DugisArrow) then
		DugisGuideViewer.DugisArrow:QuestPOIWaypoint({questID=questInstance.ID,worldQuest=questInstance.IsWorldQuest},true)
	end
end

function QuestTracker:LinkQuest(questInstance)
	if (questInstance.IsWorldQuest) then		
		local zone = "";

		local mapID, zoneMapID = C_TaskQuest.GetQuestZoneID(questInstance.ID)
		if (mapID and zoneMapID) then
			zone = C_MapCanvas.GetZoneInfoByID(mapID, zoneMapID); 
		end				
				
		local rewards = {};		
		local xp = GetQuestLogRewardXP(questInstance.ID);
		if ( xp > 0 ) then
			tinsert(rewards,string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp))
		end
		local artifactXP = GetQuestLogRewardArtifactXP(questInstance.ID);
		if ( artifactXP > 0 ) then
			tinsert(rewards,string.format(BONUS_OBJECTIVE_ARTIFACT_XP_FORMAT, artifactXP))
		end
		
		-- currency		
		for i = 1, GetNumQuestLogRewardCurrencies(questInstance.ID) do
			local name, _, numItems = GetQuestLogRewardCurrencyInfo(i, questInstance.ID);
			tinsert(rewards, numItems .. " " .. name);
		end
		
		-- items
		for i = 1, GetNumQuestLogRewards(questInstance.ID) do
			local name, texture, numItems, quality, isUsable, itemID = GetQuestLogRewardInfo(i, questInstance.ID);
			local _, link = GetItemInfo(itemID);
			tinsert(rewards, link);
			
			local text;
			if ( numItems > 1 ) then
				text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
			elseif( texture and name ) then
				text = string.format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name);			
			end
			if( text ) then
				local color = ITEM_QUALITY_COLORS[quality];
			end
			

		end
		-- money
		local money = GetQuestLogRewardMoney(questInstance.ID);
		if (money > 0) then
			tinsert(rewards, floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD)) .. "g");
		end
		
		local rewardText = "";
		for i=1, #rewards do
			if (rewardText ~= "") then
				rewardText = rewardText .. ", ";
			end
			rewardText = rewardText .. rewards[i];
		end
		
		local link = GetQuestLink(questInstance.ID);
		if (zone and zone ~= "") then
			link = link .. " - " .. zone;
		end
		link = link .. " - " .. REWARDS .. ": " .. rewardText
		
	
		
		ChatEdit_InsertLink(link)
		return
	end
	if ChatEdit_GetActiveWindow() then -- Link in chat
		ChatEdit_InsertLink(GetQuestLink(questInstance.ID))
	else -- Track/untrack quest
		if (db.ZonesAndQuests.AllowHiddenQuests == true) then
			if (IsQuestWatched(questInstance.Index) == nil) then
				if (GetNumQuestWatches() >= 25) then
					UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, 25), 1.0, 0.1, 0.1, 1.0);
				else
					AddQuestWatch(questInstance.Index)
				end
			else
				RemoveQuestWatch(questInstance.Index)
			end
			QuestTracker:UpdateMinionHandler()
		end
	end
end

function QuestTracker:AbandonQuest(questInstance)
	local intCurrentSelectedIndex = GetQuestLogSelection()
	SelectQuestLogEntry(questInstance.Index)
	SetAbandonQuest()
	
	if (db.ConfirmQuestAbandons == true) then
		local items = GetAbandonQuestItems();
		if ( items ) then
			StaticPopup_Hide("ABANDON_QUEST");
			StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), items);
		else
			StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS");
			StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName());
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFFDF4444" .. L["Quest abandoned: "] .. questInstance.Title .. "|r")
		PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
		AbandonQuest()
	end

	SelectQuestLogEntry(intCurrentSelectedIndex);
end

function QuestTracker:HideShowQuest(questInstance)
	if (questInstance.IsWorldQuest) then
		RemoveWorldQuestWatch(questInstance.ID)
	else
		if (db.ZonesAndQuests.AllowHiddenQuests == true) then
			if (IsQuestWatched(questInstance.Index) == nil) then
				if (GetNumQuestWatches() >= 25) then
					UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, 25), 1.0, 0.1, 0.1, 1.0);
				else
					AddQuestWatch(questInstance.Index)
				end
			else
				RemoveQuestWatch(questInstance.Index)
			end
			QuestTracker:UpdateMinionHandler()
		end
	end
end



--Uniform
function QuestTracker:MinionAnchorUpdate(blnMoveAnchors)
	if (blnMinionInitialized == false) then
		if (self:IsVisible() == true) then
			self:CreateMinionLayout()
		end
	end	
	
	if (blnMinionInitialized == true) then
		-- Enable/Disable movement	
		if (db.MinionLocked == false) then
			fraMinionAnchor:EnableMouse(true)
		else
			fraMinionAnchor:EnableMouse(false)
		end
		
		-- Show/Hide Minion
		if (self:IsVisible() == true) then
			fraMinionAnchor:Show()
			if (dbCore.Main.ShowAnchors == true and db.MinionLocked == false) then
				fraMinionAnchor:SetBackdropColor(0, 1, 0, 1)
			else
				fraMinionAnchor:SetBackdropColor(0, 1, 0, 0)
			end
			
			if (blnMinionUpdating == false) then
				self:UpdateMinionHandler()
			end
		else
			fraMinionAnchor:Hide()
		end
		
		fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})

		-- Set position to stored position
		if (blnMoveAnchors == true) then
			fraMinionAnchor:ClearAllPoints()
			fraMinionAnchor:SetPoint(db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y);
			fraMinionAnchor:SetScale(db.MinionScale);
		end
	end
end

function QuestTracker:UpdateColourStrings()
	strMinionTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.MinionTitleColour.r * 255, db.Colours.MinionTitleColour.g * 255, db.Colours.MinionTitleColour.b * 255);
	strInfoColour = format("|c%02X%02X%02X%02X", 255, db.Colours.InfoColour.r * 255, db.Colours.InfoColour.g * 255, db.Colours.InfoColour.b * 255);
	strHeaderColour = format("|c%02X%02X%02X%02X", 255, db.Colours.HeaderColour.r * 255, db.Colours.HeaderColour.g * 255, db.Colours.HeaderColour.b * 255);	
	strQuestStatusFailed = format("|c%02X%02X%02X%02X", 255, db.Colours.QuestStatusFailedColour.r * 255, db.Colours.QuestStatusFailedColour.g * 255, db.Colours.QuestStatusFailedColour.b * 255);
	strQuestStatusDone = format("|c%02X%02X%02X%02X", 255, db.Colours.QuestStatusDoneColour.r * 255, db.Colours.QuestStatusDoneColour.g * 255, db.Colours.QuestStatusDoneColour.b * 255);
	strQuestStatusGoto = format("|c%02X%02X%02X%02X", 255, db.Colours.QuestStatusGotoColour.r * 255, db.Colours.QuestStatusGotoColour.g * 255, db.Colours.QuestStatusGotoColour.b * 255);
	strQuestLevelColour = format("|c%02X%02X%02X%02X", 255, db.Colours.QuestLevelColour.r * 255, db.Colours.QuestLevelColour.g * 255, db.Colours.QuestLevelColour.b * 255);
	strQuestTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.QuestTitleColour.r * 255, db.Colours.QuestTitleColour.g * 255, db.Colours.QuestTitleColour.b * 255);
	strObjectiveTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ObjectiveTitleColour.r * 255, db.Colours.ObjectiveTitleColour.g * 255, db.Colours.ObjectiveTitleColour.b * 255);
	strObjectiveStatusColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ObjectiveStatusColour.r * 255, db.Colours.ObjectiveStatusColour.g * 255, db.Colours.ObjectiveStatusColour.b * 255);
	strObjective00Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.Objective00Colour.r * 255, db.Colours.Objective00Colour.g * 255, db.Colours.Objective00Colour.b * 255);
	strObjective01to24Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.Objective00PlusColour.r * 255, db.Colours.Objective00PlusColour.g * 255, db.Colours.Objective00PlusColour.b * 255);
	strObjective25to49Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.Objective25PlusColour.r * 255, db.Colours.Objective25PlusColour.g * 255, db.Colours.Objective25PlusColour.b * 255);
	strObjective50to74Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.Objective50PlusColour.r * 255, db.Colours.Objective50PlusColour.g * 255, db.Colours.Objective50PlusColour.b * 255);
	strObjective75to99Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.Objective75PlusColour.r * 255, db.Colours.Objective75PlusColour.g * 255, db.Colours.Objective75PlusColour.b * 255);
	strObjective100Colour = format("|c%02X%02X%02X%02X", 255, db.Colours.ObjectiveDoneColour.r * 255, db.Colours.ObjectiveDoneColour.g * 255, db.Colours.ObjectiveDoneColour.b * 255);
	strUndoneColour = format("|c%02X%02X%02X%02X", 255, db.Colours.UndoneColour.r * 255, db.Colours.UndoneColour.g * 255, db.Colours.UndoneColour.b * 255);
	strDoneColour = format("|c%02X%02X%02X%02X", 255, db.Colours.DoneColour.r * 255, db.Colours.DoneColour.g * 255, db.Colours.DoneColour.b * 255);
	strObjectiveDescriptionColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ObjectiveDescColour.r * 255, db.Colours.ObjectiveDescColour.g * 255, db.Colours.ObjectiveDescColour.b * 255);	
	strObjectiveTooltipTextColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ObjectiveTooltipTextColour.r * 255, db.Colours.ObjectiveTooltipTextColour.g * 255, db.Colours.ObjectiveTooltipTextColour.b * 255);	
end

function QuestTracker:HandleColourChanges()
	self:UpdateColourStrings()

	if (blnMinionInitialized) then
		fraMinionAnchor.buttonShowHidden.Update();
	end
	if (self:IsVisible() == true) then
	
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

function QuestTracker:ToggleLockState()
	db.MinionLocked = not db.MinionLocked
end

function QuestTracker:IsVisible()
	if (self:IsEnabled() == true and dbCore.Main.HideAll == false) then
		return true
	end
	return false	
end
