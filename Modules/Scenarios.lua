local SorhaQuestLog = LibStub("AceAddon-3.0"):GetAddon("SorhaQuestLog")
local L = LibStub("AceLocale-3.0"):GetLocale("SorhaQuestLog")
local MODNAME = "ScenarioTracker"
local ScenarioTracker = SorhaQuestLog:NewModule(MODNAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "LibSink-2.0")
SorhaQuestLog.ScenarioTracker = ScenarioTracker;

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local fraMinionAnchor = nil
local blnMinionInitialized = false
local blnMinionUpdating = false

local strButtonPrefix = MODNAME .. "Button"
local strSpellButtonPrefix = MODNAME .. "SpellButton"
local intNumberUsedButtons = 0
local intNumberOfSpellButtons = 0

local tblButtonCache = {}
local tblSpellButtonCache = {}
local tblUsingButtons = {}
local tblUsedSpellButtons = {}

local strMinionTitleColour = "|cffffffff"
local strScenarioHeaderColour = "|cffffffff"
local strScenarioTaskColour = "|cffffffff"
local strScenarioObjectiveColour = "|cffffffff"



local objScenario = nil;

--
local intLastTimerUpdateTime = 0
local intNumTimers = 0
local tblTimers = {}
--

local intTimeLeft = 0
local haveBonusTimer = false; 

-- ProvingGrounds --
local intPGDifficulty = 0;
local intPGCurrentWave = 0;
local intPGMaxWave = 0;
local intPGDuration = 0;
local intPGElapsedTime = 0;
local blnInProvingGround = false;


local dicOutlines = {
	[""] = NONE,
	["OUTLINE"] = L["Outline"],
	["THICKOUTLINE"] = L["Thick Outline"],
	["MONOCHROMEOUTLINE"] = L["Monochrome Outline"],
}

--Defaults
local db
local dbCore
local defaults = {
	profile = {
		MinionParent = "UIParent",
		MinionLocation = {X = 0, Y = 0, Point = "CENTER", RelativePoint = "CENTER"},
		MinionScale = 1,
		MinionLocked = false,
		MinionWidth = 220,
		MinionCollapseToLeft = false,
		MoveTooltipsRight = false,
		ShowTitle = true,
		AutoHideTitle = false,
		SpellButtonScale = 1.0,
		Fonts = {
			-- Scenario minion title font
			MinionTitleFontSize = 11,
			MinionTitleFont = "framd",
			MinionTitleFontOutline = "",
			MinionTitleFontShadowed = true,
			
			-- Scenario header font
			ScenarioHeaderFontSize = 11,
			ScenarioHeaderFont = "framd",
			ScenarioHeaderFontOutline = "",
			ScenarioHeaderFontShadowed = true,
						
			-- Scenario task font
			ScenarioTaskFontSize = 11,
			ScenarioTaskFont = "framd",
			ScenarioTaskFontOutline = "",
			ScenarioTaskFontShadowed = true,
			
			-- Scenario objective font
			ScenarioObjectiveFontSize = 11,
			ScenarioObjectiveFont = "framd",
			ScenarioObjectiveFontOutline = "",
			ScenarioObjectiveFontShadowed = true,
		},
		Colours = {
			MinionTitleColour = {r = 0, g = 1, b = 0, a = 1},
			ScenarioHeaderColour = {r = 1, g = 1, b = 1, a = 1},
			ScenarioTaskColour = {r = 0, g = 0.831, b = 0.380, a = 1},
			ScenarioObjectiveColour = {r = 1, g = 1, b = 1, a = 1},
			StatusBarFillColour = {r = 0, g = 1, b = 0, a = 1},
			StatusBarBackColour = {r = 0, g = 0, b = 0, a = 1},
			MinionBackGroundColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
			MinionBorderColour = {r = 0.5, g = 0.5, b = 0.5, a = 0},
		}
	}
}

--Options
local options
local function getOptions()
	if not options then
		options = {
			name = L["Scenario Settings"],
			type = "group",
			childGroups = "tab",
			order = 1,
			arg = MODNAME,
			args = {
				Main = {
					name = "Main",
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
								ScenarioTracker:MinionAnchorUpdate(false)
							end,
						},
						MinionLockedToggle = {
							name = L["Lock Minion"],
							type = "toggle",
							get = function() return db.MinionLocked end,
							set = function()
								db.MinionLocked = not db.MinionLocked
								ScenarioTracker:MinionAnchorUpdate(false)
							end,
							order = 2,
						},
						ShowTitleToggle = {
							name = L["Show Minion Title"],
							type = "toggle",
							width = "full",
							get = function() return db.ShowTitle end,
							set = function()
								db.ShowTitle = not db.ShowTitle
								ScenarioTracker:UpdateMinion()
							end,
							order = 3,
						},
						MoveTooltipsRightToggle = {
							name = L["Tooltips on right"],
							desc = L["Moves the tooltips to the right"],
							type = "toggle",
							get = function() return db.MoveTooltipsRight end,
							set = function()
								db.MoveTooltipsRight = not db.MoveTooltipsRight
								ScenarioTracker:UpdateMinion()
							end,
							order = 4,
						},
						AutoHideTitleToggle = {
							name = L["Auto Hide Minion Title"],
							desc = L["Hide the title when there is nothing to display"],
							type = "toggle",
							width = "full",
							disabled = function() return not(db.ShowTitle) end,
							get = function() return db.AutoHideTitle end,
							set = function()
								db.AutoHideTitle = not db.AutoHideTitle
								ScenarioTracker:UpdateMinion(false)
							end,
							order = 5,
						},
						MinionSizeSlider = {
							order = 6,
							name = L["Minion Scale"],
							desc = L["Adjust the scale of the minion"],
							type = "range",
							min = 0.5, max = 2, step = 0.05,
							isPercent = false,
							get = function() return db.MinionScale end,
							set = function(info, value)
								db.MinionScale = value
								ScenarioTracker:MinionAnchorUpdate(true)
							end,
						},
						MinionWidth = {
							order = 7,
							name = L["Width"],
							desc = L["Adjust the width of the minion"],
							type = "range",
							min = 150, max = 600, step = 1,
							isPercent = false,
							get = function() return db.MinionWidth end,
							set = function(info, value)
								db.MinionWidth = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						MinionParent = {
							name = L["Minion Anchor Point"],
							desc = L["The minion to anchor this minion to"],
							type = "select",
							order = 8,
							values = function() return SorhaQuestLog:GetPossibleParents(fraMinionAnchor)end,
							get = function() return db.MinionParent  end,
							set = function(info, value)
								db.MinionParent = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						AchivementsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 10,
						},
						AchivementsSpacerHeader = {
							name = "",
							type = "header",
							order = 11,
						},	
						SpellButtonsSizeSlider = {
							order = 20,
							name = L["Spell Button Size"],
							desc = L["Controls the size of the Spell Buttons."],
							type = "range",
							min = 0.5, max = 3, step = 0.05,
							isPercent = false,
							get = function() return db.SpellButtonScale end,
							set = function(info, value)
								db.SpellButtonScale = value
								ScenarioTracker:UpdateMinion()
							end,
						},	
					}
				},
				Fonts = {
					name = "Fonts",
					type = "group",
					order = 5,
					args = {
						HeaderTitleFont = {
							name = L["Minion Title Font Settings"],
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
								ScenarioTracker:UpdateMinion()
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
								ScenarioTracker:UpdateMinion()
							end,
						},
						MinionTitleFontSizeSelect = {
							order = 44,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.MinionTitleFontSize end,
							set = function(info, value)
								db.Fonts.MinionTitleFontSize = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						MinionTitleFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.MinionTitleFontShadowed end,
							set = function()
								db.Fonts.MinionTitleFontShadowed = not db.Fonts.MinionTitleFontShadowed
								ScenarioTracker:UpdateMinion()
							end,
							order = 45,
						},
						HeaderFontsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 50,
						},
						HeaderFonts = {
							name = L["Header Font Settings"],
							type = "header",
							order = 51,
						},
						ScenarioHeaderFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 52,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.ScenarioHeaderFont end,
							set = function(info, value)
								db.Fonts.ScenarioHeaderFont = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioHeaderFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 53,
							values = dicOutlines,
							get = function() return db.Fonts.ScenarioHeaderFontOutline end,
							set = function(info, value)
								db.Fonts.ScenarioHeaderFontOutline = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioHeaderFontSize = {
							order = 54,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.ScenarioHeaderFontSize end,
							set = function(info, value)
								db.Fonts.ScenarioHeaderFontSize = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioHeaderFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.ScenarioHeaderFontShadowed end,
							set = function()
								db.Fonts.ScenarioHeaderFontShadowed = not db.Fonts.ScenarioHeaderFontShadowed
								ScenarioTracker:UpdateMinion()
							end,
							order = 55,
						},
						TaskFontsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 60,
						},
						TaskFonts = {
							name = L["Task Font Settings"],
							type = "header",
							order = 61,
						},
						ScenarioTaskFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 62,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.ScenarioTaskFont end,
							set = function(info, value)
								db.Fonts.ScenarioTaskFont = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioTaskFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 63,
							values = dicOutlines,
							get = function() return db.Fonts.ScenarioTaskFontOutline end,
							set = function(info, value)
								db.Fonts.ScenarioTaskFontOutline = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioTaskFontSize = {
							order = 64,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.ScenarioTaskFontSize end,
							set = function(info, value)
								db.Fonts.ScenarioTaskFontSize = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioTaskFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.ScenarioTaskFontShadowed end,
							set = function()
								db.Fonts.ScenarioTaskFontShadowed = not db.Fonts.ScenarioTaskFontShadowed
								ScenarioTracker:UpdateMinion()
							end,
							order = 65,
						},
						ObjectivesFontsSpacer = {
							name = "",
							width = "full",
							type = "description",
							order = 70,
						},
						ObjectiveFonts = {
							name = L["Objective Font Settings"],
							type = "header",
							order = 71,
						},
						ScenarioObjectiveFontSelect = {
							type = "select", dialogControl = 'LSM30_Font',
							order = 72,
							name = L["Font"],
							desc = L["The font used for this element"],
							values = AceGUIWidgetLSMlists.font,
							get = function() return db.Fonts.ScenarioObjectiveFont end,
							set = function(info, value)
								db.Fonts.ScenarioObjectiveFont = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioObjectiveFontOutlineSelect = {
							name = L["Font Outline"],
							desc = L["The outline that this font will use"],
							type = "select",
							order = 73,
							values = dicOutlines,
							get = function() return db.Fonts.ScenarioObjectiveFontOutline end,
							set = function(info, value)
								db.Fonts.ScenarioObjectiveFontOutline = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioObjectiveFontSize = {
							order = 74,
							name = FONT_SIZE,
							desc = L["Controls the font size this font"],
							type = "range",
							min = 8, max = 20, step = 1,
							isPercent = false,
							get = function() return db.Fonts.ScenarioObjectiveFontSize end,
							set = function(info, value)
								db.Fonts.ScenarioObjectiveFontSize = value
								ScenarioTracker:UpdateMinion()
							end,
						},
						ScenarioObjectiveFontShadowedToggle = {
							name = L["Shadow Text"],
							desc = L["Shows/Hides text shadowing"],
							type = "toggle",
							get = function() return db.Fonts.ScenarioObjectiveFontShadowed end,
							set = function()
								db.Fonts.ScenarioObjectiveFontShadowed = not db.Fonts.ScenarioObjectiveFontShadowed
								ScenarioTracker:UpdateMinion()
							end,
							order = 75,
						},				
					}
				},
				Colours = {
					name = "Colours",
					type = "group",
					order = 6,
					args = {
						HeaderColourSettings = {
							name = L["Colour Settings"],
							type = "header",
							order = 80,
						},
						MinionTitleColour = {
							name = L["Minion Title"],
							desc = L["Sets the color for Minion Title"],
							type = "color",
							width = "full",
							hasAlpha = true,
							get = function() return db.Colours.MinionTitleColour.r, db.Colours.MinionTitleColour.g, db.Colours.MinionTitleColour.b, db.Colours.MinionTitleColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.MinionTitleColour.r = r
									db.Colours.MinionTitleColour.g = g
									db.Colours.MinionTitleColour.b = b
									db.Colours.MinionTitleColour.a = a
									ScenarioTracker:HandleColourChanges()
								end,
							order = 81,
						},
						ScenarioHeaderColour = {
							name = L["Scenario Headers"],
							desc = L["Sets the color for Scenario Headers"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ScenarioHeaderColour.r, db.Colours.ScenarioHeaderColour.g, db.Colours.ScenarioHeaderColour.b, db.Colours.ScenarioHeaderColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ScenarioHeaderColour.r = r
									db.Colours.ScenarioHeaderColour.g = g
									db.Colours.ScenarioHeaderColour.b = b
									db.Colours.ScenarioHeaderColour.a = a
									ScenarioTracker:HandleColourChanges()
								end,
							order = 82,
						},
						ScenarioTaskColour = {
							name = L["Scenario Tasks"],
							desc = L["Sets the color for Scenario Tasks"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ScenarioTaskColour.r, db.Colours.ScenarioTaskColour.g, db.Colours.ScenarioTaskColour.b, db.Colours.ScenarioTaskColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ScenarioTaskColour.r = r
									db.Colours.ScenarioTaskColour.g = g
									db.Colours.ScenarioTaskColour.b = b
									db.Colours.ScenarioTaskColour.a = a
									ScenarioTracker:HandleColourChanges()
								end,
							order = 83,
						},
						ScenarioObjectiveColour = {
							name = L["Scenario Objectives"],
							desc = L["Sets the color for Scenario Objectives"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.ScenarioObjectiveColour.r, db.Colours.ScenarioObjectiveColour.g, db.Colours.ScenarioObjectiveColour.b, db.Colours.ScenarioObjectiveColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.ScenarioObjectiveColour.r = r
									db.Colours.ScenarioObjectiveColour.g = g
									db.Colours.ScenarioObjectiveColour.b = b
									db.Colours.ScenarioObjectiveColour.a = a
									ScenarioTracker:HandleColourChanges()
								end,
							order = 84,
						},
						StatusBarFillColour = {
							name = L["Bar Fill Colour"],
							desc = L["Sets the color for the completed part of the status bar"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarFillColour.r = r
									db.Colours.StatusBarFillColour.g = g
									db.Colours.StatusBarFillColour.b = b
									db.Colours.StatusBarFillColour.a = a
									ScenarioTracker:UpdateMinion()
								end,
							order = 85,
						},
						StatusBarBackColour = {
							name = L["Bar Back Colour"],
							desc = L["Sets the color for the un-completed part of the status bar"],
							type = "color",
							hasAlpha = true,
							get = function() return db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a end,
							set = function(_,r,g,b,a)
									db.Colours.StatusBarBackColour.r = r
									db.Colours.StatusBarBackColour.g = g
									db.Colours.StatusBarBackColour.b = b
									db.Colours.StatusBarBackColour.a = a
									ScenarioTracker:UpdateMinion()
								end,
							order = 86,
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
									ScenarioTracker:HandleColourChanges()
								end,
							order = 87,
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
									ScenarioTracker:HandleColourChanges()
								end,
							order = 88,
						},
					}
				},
			}
		}
	end


	return options
end

--Classes

--Timer
local SQLScenarioTimer = {};
SQLScenarioTimer.__index = SQLScenarioTimer; 

function SQLScenarioTimer:new() 
	local self = {};
	setmetatable(self, SQLScenarioTimer);

	self.Duration = 0;
	self.Elasped = 0;
	self.TimeLeft = 0;
	self.Running = false;
	self.IsValid = false;
	self.TwoChestTime = 0;
	self.ThreeChestTime = 0;
	return self;
end

function SQLScenarioTimer:Start(duration, elasped)
	self.Duration = duration;
	self.Elasped = elasped;
	self.Running = false;
	self.TimeLeft = self.Duration;
	if (self.Duration > self.Elasped) then
		self.Running = true;
		self.IsValid = true;
		self.TwoChestTime = self.Duration * 0.2;
		self.ThreeChestTime = self.Duration * 0.4;
	end
end

function SQLScenarioTimer:Stop()
	self.Duration = 0;
	self.Elasped = 0;
	self.Running = false;
	self.TimeLeft = 0;
end

function SQLScenarioTimer:Update(elasped)
	self.Elasped = self.Elasped + elasped;
	self.TimeLeft = self.Duration - self.Elasped;

	if (self.TimeLeft > 0) then
		self.Running = true;
	else
		if (objScenario.IsChallengeMode == false) then
			self.Elasped = 0;
			self.Running = false;
			self.Duration = 0;		
		end
	end
end


--Bonus Criteria
local SQLScenarioBonusCriteria = {};
SQLScenarioBonusCriteria.__index = SQLScenarioBonusCriteria; 

function SQLScenarioBonusCriteria:new(stepIndex, criteriaIndex) 
	local self = {};
	setmetatable(self, SQLScenarioBonusCriteria);

	self.StepIndex = stepIndex
	self.Index = criteriaIndex;

	if (self.Index == nil or self.StepIndex == nil) then
		return nil;
	end

	local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress = C_Scenario.GetCriteriaInfoByStep(self.StepIndex, self.Index);
	if (not criteriaString) then
		return nil
	end

	self.Name = criteriaString;
	self.Type = criteriaType
	self.IsComplete = criteriaCompleted
	self.IsFailed = criteriaFailed
	self.Duration = duration
	self.Elapsed = elapsed
	self.IsProgressBar = isWeightedProgress;

	if (self.Duration == nil) then
		self.Duration = 0;	
	end
	if (self.Elapsed == nil) then
		self.Elapsed = 0;	
	end


	self.Quantity = quantity
	self.TotalQuantity = totalQuantity
	
	return self;
end

function SQLScenarioBonusCriteria:Render()

end


--Bonus Step
local SQLScenarioBonusStep = {};
SQLScenarioBonusStep.__index = SQLScenarioBonusStep; 
function SQLScenarioBonusStep:new(index) 
	local self = {};
	setmetatable(self, SQLScenarioBonusStep);


	self.Index = index;
	if (self.Index == nil) then
		return nil;
	end

	local stageName, stageDescription, numCriteria, stepFailed, isBonusStep, isForCurrentStepOnly = C_Scenario.GetStepInfo(self.Index);
	if (not stageName) then
		return nil;
	end

	self.Name = stageName;
	self.Description = stageDescription;
	self.IsFailed = stepFailed;

	self.CriteriaCount = 0;
	self.CriteriaList = {};

	self.Name = stageName;
	self.Description = stageDescription;

	self.Stages = numStages;
	self.CurrentStage = currentStage;
	self.IsFailed = stepFailed;

	self.RewardQuestID = nil;
	local questID = C_Scenario.GetBonusStepRewardQuestID(self.Index);
	if (questID) then
		self.RewardQuestID = questID;
	end

	for criteriaIndex=1, numCriteria, 1 do		
		local criteria = SQLScenarioBonusCriteria:new(self.Index, criteriaIndex);
		if (criteria) then
			self.CriteriaCount = self.CriteriaCount + 1;
			tinsert(self.CriteriaList, criteria);
		end
	end

	return self;
end

function SQLScenarioBonusStep:Render()

end


--Criteria
local SQLScenarioCriteria = {};
SQLScenarioCriteria.__index = SQLScenarioCriteria; 

function SQLScenarioCriteria:new(criteriaIndex) 
	local self = {};
	setmetatable(self, SQLScenarioCriteria);

	self.Index = criteriaIndex;

	local criteriaString, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress = C_Scenario.GetCriteriaInfo(criteriaIndex);
	if (not criteriaString) then
		return nil;
	end

	self.Name = criteriaString;
	self.Type = criteriaType
	self.IsComplete = completed
	self.IsFailed = criteriaFailed
	self.Duration = duration
	self.Elapsed = elapsed
	self.IsProgressBar = isWeightedProgress;
	
	if (self.Duration == nil) then
		self.Duration = 0;	
	end
	if (self.Elapsed == nil) then
		self.Elapsed = 0;	
	end

	self.Quantity = quantity
	self.TotalQuantity = totalQuantity

	return self;
end

function SQLScenarioCriteria:Render()

end


--Scenario
local SQLScenario = {};
SQLScenario.__index = SQLScenario; 
function SQLScenario:new() 
	local self = {};
	setmetatable(self, SQLScenario);

	self.Name = nil;
	self.StageName = nil;
	self.StageDescription = nil;

	self.IsChallengeMode = false;
	self.IsProvingGrounds = false;
	self.IsDungeon = false;
	self.IsComplete = false;
	self.IsInScenario = false;
	self.SupressStageText = false;

	self.Stages = 0;
	self.CurrentStage = 0;
	
	self.Waves = 0;
	self.CurrentWave = 0;
	self.Difficulty = 0;
	self.Duration = 0;
	self.DifficultyString = "";

	self.Level = 0;
	self.Affixes = {}
	self.EnergisedKeystone = false;

	self.RewardXP = 0;
	self.RewardMoney = 0;

	self.CriteriaCount = 0;
	self.CriteriaList = {};

	self.BonusCount = 0;
	self.BonusList = {};
	
	self.Spells = {};
	self.Progress = nil;

	self.Timer = SQLScenarioTimer:new();

	self:Update();

	self.Changed = false;
	return self;
end

function SQLScenario:Update()
	self.Changed = false;

	self.IsChallengeMode = false;
	self.IsProvingGrounds = false;
	self.IsDungeon = false;
	self.IsComplete = false;
	self.IsInScenario = false;
	self.SupressStageText = false;


	local scenarioName, currentStage, numStages, flags, _, _, _, xp, money, scenarioType = C_Scenario.GetInfo();
	if (scenarioName == nil or scenarioName == "") then
		return
	end

	local stageName, stageDescription, numCriteria, _, _, _, _, spells, weightedProgress = C_Scenario.GetStepInfo();
	
	
	self.Spells = spells;
	self.Progress = weightedProgress;
	if (weightedProgress and next(weightedProgress) == nil) then
		self.Progress = nil;
	end
	
	
	self.Name = scenarioName;
	self.StageName = stageName;
	self.StageDescription = stageDescription;

	self.Stages = numStages;
	self.CurrentStage = currentStage;
	
	self.IsChallengeMode = (scenarioType == LE_SCENARIO_TYPE_CHALLENGE_MODE);
	self.IsProvingGrounds = (scenarioType == LE_SCENARIO_TYPE_PROVING_GROUNDS);
	self.IsDungeon = (scenarioType == LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY);
	self.IsComplete = currentStage > numStages;
	self.IsInScenario = C_Scenario.IsInScenario();
	self.SupressStageText = bit.band(flags, SCENARIO_FLAG_SUPRESS_STAGE_TEXT) == SCENARIO_FLAG_SUPRESS_STAGE_TEXT

	self.RewardXP = xp;
	self.RewardMoney = money;


	self.Difficulty = 0;
	self.DifficultyString = "";
	self.CurrentWave = 0;
	self.Waves = 0;		
	self.Duration = 0;
	
	self.Affixes = {};
	self.Level = 0;
	self.EnergisedKeystone = false;

	self.IsProvingGrounds = false;
	local difficulty, curWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo();
	local pgSum = difficulty + curWave + maxWave + duration;
	if (pgSum > 0) then
		self.IsProvingGrounds = true;
	end

	--Proving Ground
	if (self.IsProvingGrounds == true) then
		self.Difficulty = difficulty;
		self.CurrentWave = curWave;
		self.Waves = maxWave;		
		self.Duration = duration;

		self.DifficultyString = "Bronze";

		if (self.Difficulty == 2) then
			self.DifficultyString = "Silver";

		elseif (self.Difficulty == 3) then
			self.DifficultyString = "Gold";

		elseif (self.Difficulty == 4) then
			self.DifficultyString = "Endless";
		end
	end
	if (self.IsChallengeMode == true) then
		local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo();
		local dmgPct, healthPct = C_ChallengeMode.GetPowerLevelDamageHealthMod(level);		
		
		tinsert(self.Affixes, {
			Name = ("%s: %d%%"):format(CHALLENGE_MODE_ENEMY_EXTRA_DAMAGE, dmgPct), 
			Description = CHALLENGE_MODE_ENEMY_EXTRA_DAMAGE_DESCRIPTION:format(dmgPct)
		})
		tinsert(self.Affixes, {
			Name = ("%s: %d%%"):format(CHALLENGE_MODE_ENEMY_EXTRA_HEALTH, healthPct), 
			Description = CHALLENGE_MODE_ENEMY_EXTRA_HEALTH_DESCRIPTION:format(healthPct)
		})

		for i = 1, #affixes do
			local affixID = affixes[i];
			local affixName, affixDescription, _ = C_ChallengeMode.GetAffixInfo(affixID);
			tinsert(self.Affixes, {
				Name = affixName,
				Description = affixDescription
			})
		end
		
		if (not wasEnergized) then
			tinsert(self.Affixes, {
				Name = CHALLENGE_MODE_DEPLETED_KEYSTONE, 
				Description = CHALLENGE_MODE_KEYSTONE_DEPLETED_AT_START
			})
		end


		self.Level = level;
		self.EnergisedKeystone = wasEnergized;
	end	

	self:ClearCriteria();
	if (self.IsComplete == false) then
		for criteriaIndex=1, numCriteria, 1 do		
			local criteria = SQLScenarioCriteria:new(criteriaIndex);
			if (criteria) then
				self:AddCriteria(criteria);
			end
		end
	end
	
	--Bonus
	self:ClearBonusSteps();
	local tblBonusSteps = C_Scenario.GetBonusSteps();
	for i=1, #tblBonusSteps, 1 do	
		local bonusStepIndex = tblBonusSteps[i];

		if (bonusStepIndex) then
			local bonusStep = SQLScenarioBonusStep:new(bonusStepIndex);
			if (bonusStep) then
				self:AddBonusStep(bonusStep);
			end
		end
	end


	if (self.IsChallengeMode == false and self.IsProvingGrounds == false and self.IsDungeon == false and self.IsInScenario == false) then
		self.Timer:Stop();
	end
end

function SQLScenario:Render()

end

function SQLScenario:AddCriteria(criteria)
	self.Changed = true;
	self.CriteriaCount = self.CriteriaCount + 1;
	tinsert(self.CriteriaList, criteria);
end

function SQLScenario:ClearCriteria()
	self.Changed = true;
	self.CriteriaCount = 0;
	self.CriteriaList = {};
end

function SQLScenario:AddBonusStep(bonusStep)
	self.Changed = true;
	self.BonusCount = self.BonusCount + 1;
	tinsert(self.BonusList, bonusStep);
end

function SQLScenario:ClearBonusSteps()
	self.Changed = true;
	self.BonusCount = 0;
	self.BonusList = {};
end

function SQLScenario:IsActive()
	if (self.IsChallengeMode == true) then
		return true;
	end
	if (self.IsProvingGrounds == true) then
		return true;
	end
	if (self.IsDungeon == true) then
		return true;
	end
	if (self.IsInScenario == true) then
		return true;
	end
	if (self.SupressStageText == true) then
		return true;
	end


	return false;
end

function SQLScenario:IsValid()
	return self.IsValid;
end

function SQLScenario:Invalidate()
	self.IsValid = false;
end


--Inits
function ScenarioTracker:OnInitialize()
	self.db = SorhaQuestLog.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	self:SetEnabledState(SorhaQuestLog:GetModuleEnabled(MODNAME))
	SorhaQuestLog:RegisterModuleOptions(MODNAME, getOptions, L["Scenario Tracker"])
	
	self:UpdateColourStrings()
	self:MinionAnchorUpdate(true)
end

function ScenarioTracker:OnEnable()
	self:RegisterEvent("QUEST_LOG_UPDATE")	
	self:RegisterEvent("PLAYER_ENTERING_WORLD")	
	
	self:RegisterEvent("SCENARIO_UPDATE")
	self:RegisterEvent("SCENARIO_COMPLETED")
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
	self:RegisterEvent("SCENARIO_SPELL_UPDATE")	
	
	self:RegisterEvent("WORLD_STATE_TIMER_START")
	self:RegisterEvent("WORLD_STATE_TIMER_STOP")
	
	self:MinionAnchorUpdate(false)
	self:UpdateMinion()
end

function ScenarioTracker:OnDisable()
	self:UnregisterEvent("QUEST_LOG_UPDATE")		
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	self:UnregisterEvent("SCENARIO_UPDATE")
	self:UnregisterEvent("SCENARIO_COMPLETED")
	self:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")	
	self:UnregisterEvent("SCENARIO_SPELL_UPDATE")	
	
	
	self:UnregisterEvent("WORLD_STATE_TIMER_START")
	self:UnregisterEvent("WORLD_STATE_TIMER_STOP")

	self:MinionAnchorUpdate(true)
	self:UpdateMinion()
end

function ScenarioTracker:Refresh()
	db = self.db.profile
	dbCore = SorhaQuestLog.db.profile
	
	self:HandleColourChanges()
	self:MinionAnchorUpdate(true)
end

--Events/handlers
function ScenarioTracker:QUEST_LOG_UPDATE(...)
	if (blnMinionUpdating == false) then 
		blnMinionUpdating = true
		self:ScheduleTimer("UpdateMinion", 0.3)
	end
end

function ScenarioTracker:SCENARIO_UPDATE(...)
	if (blnMinionUpdating == false) then 
		self:UpdateMinion();
	end
end

function ScenarioTracker:SCENARIO_CRITERIA_UPDATE(...)
	self:CheckForDurationTimers();
	if (blnMinionUpdating == false) then 
		self:UpdateMinion();
	end
end

function ScenarioTracker:SCENARIO_COMPLETED(...)
	if (blnMinionUpdating == false) then 
		self:UpdateMinion();
	end	
end

function ScenarioTracker:SCENARIO_SPELL_UPDATE(...)
	if (blnMinionUpdating == false) then 
		self:UpdateMinion();
	end	
end

function ScenarioTracker:PLAYER_ENTERING_WORLD()
	ScenarioTracker:CheckTimers(GetWorldElapsedTimers());
end

function ScenarioTracker:PLAYER_REGEN_ENABLED(...)
	self:UpdateMinion();
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function ScenarioTracker:WORLD_STATE_TIMER_START(event, ...)
	local timerID = ...;
	ScenarioTracker:CheckTimers(timerID)
end

function ScenarioTracker:WORLD_STATE_TIMER_STOP(event, ...)
	ScenarioTracker:StopTimer();
end

--Buttons
function ScenarioTracker:GetMinionButton()
	return SorhaQuestLog:GetLogButton();
end

function ScenarioTracker:RecycleMinionButton(objButton)
	objButton.BonusInstance = nil;

	if (objButton.StatusBar ~= nil) then
		self:RecycleStatusBar(objButton.StatusBar)
		objButton.StatusBar = nil
	end
	if (objButton.ProgressBar ~= nil) then
		self:RecycleProgressBar(objButton.ProgressBar)
		objButton.ProgressBar = nil
	end
	SorhaQuestLog:RecycleLogButton(objButton)
end

function ScenarioTracker:GetStatusBar(timerData)
	local objStatusBar = SorhaQuestLog:GetStatusBar();
	objStatusBar.TimerData = timerData

	-- Setup colours and texture
	objStatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
	objStatusBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)
	
	objStatusBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
	objStatusBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)
	
	objStatusBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

	
	objStatusBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.ScenarioTaskFont), db.Fonts.ScenarioTaskFontSize, db.Fonts.ScenarioHeaderFontOutline)
	if (db.Fonts.ScenarioTaskFontShadowed == true) then
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objStatusBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objStatusBar.objFontString:SetText(SorhaQuestLog:SecondsToFormatedTime(objStatusBar.TimerData.TimeLeft))

	objStatusBar:SetValue(objStatusBar.TimerData.TimeLeft);
	objStatusBar:SetMinMaxValues(0, objStatusBar.TimerData.Duration);
	objStatusBar:Show()

	objStatusBar.updateTimer = 0;
	objStatusBar:SetScript('OnUpdate', function(self, elapsed)
		self.updateTimer = self.updateTimer + elapsed

		if(self.updateTimer > 0.05) then
			self.TimerData:Update(self.updateTimer);
			objStatusBar:SetValue(self.TimerData.TimeLeft);
			objStatusBar.objFontString:SetText(SorhaQuestLog:SecondsToFormatedTime(self.TimerData.TimeLeft))
			self.updateTimer = 0;

			if (self.TimerData.TimeLeft <= 0) then
				if (objScenario.IsChallengeMode == true) then
					ScenarioTracker:ScheduleTimer("UpdateMinion", 1.0)
				end
			end
		end
	end)

	return objStatusBar;
end

function ScenarioTracker:GetProgressBar(progress)
	local objProgressBar = SorhaQuestLog:GetStatusBar();
	objProgressBar.TimerData = timerData

	-- Setup colours and texture
	objProgressBar:SetStatusBarTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))
	objProgressBar:SetStatusBarColor(db.Colours.StatusBarFillColour.r, db.Colours.StatusBarFillColour.g, db.Colours.StatusBarFillColour.b, db.Colours.StatusBarFillColour.a)	
	objProgressBar.Background:SetTexture(LSM:Fetch("statusbar", dbCore.StatusBarTexture))			
	objProgressBar.Background:SetVertexColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)	
	objProgressBar:SetBackdropColor(db.Colours.StatusBarBackColour.r, db.Colours.StatusBarBackColour.g, db.Colours.StatusBarBackColour.b, db.Colours.StatusBarBackColour.a)

	
	objProgressBar.objFontString:SetFont(LSM:Fetch("font", db.Fonts.ScenarioTaskFont), db.Fonts.ScenarioTaskFontSize, db.Fonts.ScenarioHeaderFontOutline)
	if (db.Fonts.ScenarioTaskFontShadowed == true) then
		objProgressBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		objProgressBar.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	objProgressBar.objFontString:SetText(progress .. "%")
	objProgressBar:SetMinMaxValues(0, 100);
	objProgressBar:SetValue(progress);
	objProgressBar:Show()

	return objProgressBar;
end

function ScenarioTracker:RecycleStatusBar(objStatusBar)
	objStatusBar.TimerData = nil
	objStatusBar:SetScript("OnUpdate", nil);
	SorhaQuestLog:RecycleStatusBar(objStatusBar)
end

function ScenarioTracker:RecycleProgressBar(objProgressBar)
	SorhaQuestLog:RecycleStatusBar(objProgressBar)
end

function ScenarioTracker:GetSpellButton(objSpell, yOffset)
	local objButton = tremove(tblSpellButtonCache)

	if (objButton == nil) then
		intNumberOfSpellButtons = intNumberOfSpellButtons + 1
		objButton = CreateFrame('Button', strSpellButtonPrefix .. intNumberOfSpellButtons, UIParent, 'SorhaQuestLogSpellButtonTemplate')
		
		objButton:SetAttribute('_onattributechanged', [[
			if(name == 'spell') then
				if(value and not self:IsShown()) then
					self:Show()
				elseif(not value) then
					self:Hide()
				end
			end
		]])

		objButton:SetAttribute('type', 'spell')
		objButton.updateTimer = 0
		objButton.rangeTimer = 0


		objButton:SetScript('OnEvent', function(self, event)
			if (event == "PLAYER_TARGET_CHANGED") then
				self.rangeTimer = TOOLTIP_UPDATE_TIME;

			elseif(event == 'SPELL_UPDATE_COOLDOWN') then
				if(self:IsShown()) then
					local start, duration, enable = GetSpellCooldown(self.spellID)
					if(duration > 0) then
						self.Cooldown:SetCooldown(start, duration)
						self.Cooldown:Show()
					else
						self.Cooldown:Hide()
					end
				end

			elseif(event == 'PLAYER_REGEN_ENABLED') then
				self:SetAttribute('spell', self.attribute)
				if (self.attribute == nil) then
					ScenarioTracker:TearDownSpellButton(objButton);
				else				
					ScenarioTracker:SetupSpellButton(objButton);
				end
				self:UnregisterEvent(event)
			end
		end)
	end

	objButton.yOffset = yOffset;

	if(objSpell.spellID) then
		if(objSpell.spellID == objButton.spellID and objButton:IsShown()) then
			return
		end
		objButton.icon:SetTexture(objSpell.spellIcon)
		objButton.spellID = objSpell.spellID
		objButton.spellName = objSpell.spellName
	end
		
	if(InCombatLockdown()) then
		objButton.attribute = objButton.spellID
		objButton:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		objButton:SetAttribute('spell', objButton.spellID)
		ScenarioTracker:SetupSpellButton(objButton);
	end
	
	return objButton
end

function ScenarioTracker:RecycleSpellButton(objButton)
	if(InCombatLockdown()) then
		objButton.attribute = nil
		objButton:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		objButton:SetAttribute('spell', nil)
		objButton:SetScript('OnUpdate', nil);
		ScenarioTracker:TearDownSpellButton(objButton);
	end
end

function ScenarioTracker:SetupSpellButton(objButton)	
	objButton:SetScale(db.SpellButtonScale);

	objButton:RegisterEvent('SPELL_UPDATE_COOLDOWN')
	objButton:RegisterEvent("PLAYER_TARGET_CHANGED")
	local start, duration, enable = GetSpellCooldown(objButton.spellID)
	if(duration > 0) then
		objButton.Cooldown:SetCooldown(start, duration)
		objButton.Cooldown:Show()
	else
		objButton.Cooldown:Hide()
	end

	objButton:SetParent(fraMinionAnchor);
	objButton:Show();

	objButton:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, (objButton.yOffset * (1 / objButton:GetScale())) - 4)
	tinsert(tblUsedSpellButtons, objButton);
end

function ScenarioTracker:TearDownSpellButton(objButton)
	objButton:SetParent(UIParent)
	objButton:ClearAllPoints()
	objButton:Hide()
	objButton:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
	objButton:UnregisterEvent("PLAYER_TARGET_CHANGED")
	objButton:SetScript("OnUpdate", nil)

	tinsert(tblSpellButtonCache, objButton);
end


--Minion
function ScenarioTracker:CreateMinionLayout()
	fraMinionAnchor = SorhaQuestLog:doCreateFrame("FRAME","SQLScenarioQuestsMinionAnchor",UIParent,200,20,1,"BACKGROUND",1, db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y, 1)
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
		if (dbCore.Main.ShowHelpTooltips == true) then
			if (db.MoveItemsAndTooltipsRight == true) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
			else 
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, 0);
			end
			
			GameTooltip:SetText(L["Scenario Quests Minion Anchor"], 0, 1, 0, 1);
			GameTooltip:AddLine(L["Drag this to move the Scenario Quests minion when it is unlocked."], 1, 1, 1, 1);
			GameTooltip:AddLine(L["You can disable help tooltips in general settings"], 0.5, 0.5, 0.5, 1);
			
			GameTooltip:Show();
		end
	end)
	fraMinionAnchor:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)
	
	fraMinionAnchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 5}})
	fraMinionAnchor:SetBackdropColor(0, 0, 0, 0)
	fraMinionAnchor:SetBackdropBorderColor(0, 0, 0, 0)

	-- scenario Anchor
	fraMinionAnchor.fraScenariosAnchor = SorhaQuestLog:doCreateLooseFrame("FRAME","SQLSenarioQuestsAnchor",fraMinionAnchor, fraMinionAnchor:GetWidth(),1,1,"LOW",1,1)
	fraMinionAnchor.fraScenariosAnchor:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0);
	fraMinionAnchor.fraScenariosAnchor:SetBackdropColor(0, 0, 0, 0)
	fraMinionAnchor.fraScenariosAnchor:SetBackdropBorderColor(0,0,0,0)
	fraMinionAnchor.fraScenariosAnchor:SetAlpha(0)
	
	-- Fontstring for title "Remote Quests"
	fraMinionAnchor.objFontString = fraMinionAnchor:CreateFontString(nil, "OVERLAY");
	fraMinionAnchor.objFontString:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT",0, 0);
	fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize , db.Fonts.MinionTitleFontOutline)
	if (db.Fonts.MinionTitleFontShadowed == true) then
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
	else
		fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
	end
	
	fraMinionAnchor.objFontString:SetJustifyH("LEFT")
	fraMinionAnchor.objFontString:SetJustifyV("TOP")
	fraMinionAnchor.objFontString:SetText("");
	fraMinionAnchor.objFontString:SetShadowOffset(1, -1)
	
	fraMinionAnchor.BorderFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLScenarioQuestsMinionBorder", fraMinionAnchor, 100,20,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", -6, 6, 1)
	fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})
	fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
	fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)
	fraMinionAnchor.BorderFrame:Show()
	
	fraMinionAnchor.BottomFrame = SorhaQuestLog:doCreateFrame("FRAME","SQLScenarioMinionBottom", fraMinionAnchor, db.MinionWidth,40,1,"BACKGROUND",1, "TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, 0, 1)

	blnMinionInitialized = true
	self:MinionAnchorUpdate(false)
end

function ScenarioTracker:UpdateMinion()
	blnMinionUpdating = true
	haveBonusTimer = false;

	
	-- If Scenario Minion is not Initialized then do so
	if (blnMinionInitialized == false) then
		self:CreateMinionLayout()
	end
	
	local parent = fraMinionAnchor:GetParent();
	if (parent) then
		if (parent:GetName() ~= db.MinionParent) then
			if (_G[db.MinionParent]) then
				fraMinionAnchor:SetParent(db.MinionParent);	
			else 
				fraMinionAnchor:SetParent(UIParent);			
			end
			self:MinionAnchorUpdate(true);
		end
	end

	if (self:IsVisible() == false) then
		blnMinionUpdating = false
		return ""
	end
	
	-- Release all used buttons
	for k, objButton in pairs(tblUsingButtons) do
		self:RecycleMinionButton(objButton)
	end
	wipe(tblUsingButtons)
	
	
	local createSpellButtons = true;
	if(InCombatLockdown()) then
		createSpellButtons = false;
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	end

	if (not InCombatLockdown()) then
		-- Release all used Spell buttons
		for k, objSpellButton in pairs(tblUsedSpellButtons) do
			self:RecycleSpellButton(objSpellButton)
		end
		wipe(tblUsedSpellButtons)
	end
	
	
	
	local intYPosition = 4	
	local intLargestWidth = 0
	local blnNothingShown = true
	
	ScenarioTracker:UpdateData();


	-- Show title if enabled
	local showTitle = false;
	if (db.ShowTitle == true and (db.AutoHideTitle == false or (db.AutoHideTitle == true and objScenario:IsActive()))) then
		showTitle = true;
		if (objScenario:IsActive()) then
			if (objScenario.CurrentStage > objScenario.Stages and objScenario.BonusCount < 1) then
				showTitle = false;
			end
		end
	end		

	if (showTitle == true) then
		fraMinionAnchor.objFontString:SetFont(LSM:Fetch("font", db.Fonts.MinionTitleFont), db.Fonts.MinionTitleFontSize, db.Fonts.MinionTitleFontOutline)
		if (db.Fonts.MinionTitleFontShadowed == true) then
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 1.0)
		else
			fraMinionAnchor.objFontString:SetShadowColor(0.0, 0.0, 0.0, 0.0)
		end
		
		fraMinionAnchor.objFontString:SetText(strMinionTitleColour .. L["Scenario Tracker Title"])
		intLargestWidth = fraMinionAnchor.objFontString:GetWidth()
		
		intYPosition = db.Fonts.MinionTitleFontSize
		blnNothingShown = false
	else
		fraMinionAnchor.objFontString:SetText("")
		intLargestWidth = 100
	end


	local minionWidth = db.MinionWidth;
	if (not InCombatLockdown()) then
		fraMinionAnchor:SetWidth(minionWidth)	
	end
	
	
	--Get outlining offsets
	local intTitleOutlineOffset = 0
	local intHeaderOutlineOffset = 0
	local intTaskOutlineOffset = 0
	local intObjectiveOutlineOffset = 0
	if (db.Fonts.MinionTitleFontOutline == "THICKOUTLINE") then
		intTitleOutlineOffset = 2
	elseif (db.Fonts.MinionTitleFontOutline == "OUTLINE") then
		intTitleOutlineOffset = 1
	end
	if (db.Fonts.ScenarioHeaderFontOutline == "THICKOUTLINE") then
		intHeaderOutlineOffset = 1.5
	elseif (db.Fonts.ScenarioHeaderFontOutline == "OUTLINE") then
		intHeaderOutlineOffset = 0.5
	end
	if (db.Fonts.ScenarioTaskFontOutline == "THICKOUTLINE") then
		intTaskOutlineOffset = 1.5
	elseif (db.Fonts.ScenarioTaskFontOutline == "OUTLINE") then
		intTaskOutlineOffset = 0.5
	end
	if (db.Fonts.ScenarioObjectiveFontOutline == "THICKOUTLINE") then
		intObjectiveOutlineOffset = 1.5
	elseif (db.Fonts.ScenarioObjectiveFontOutline == "OUTLINE") then
		intObjectiveOutlineOffset = 0.5
	end
	
	local intInitialYOffset = intYPosition

	if (objScenario:IsActive() and objScenario.IsProvingGrounds == false) then
		blnNothingShown = false;
		
		if (objScenario.CurrentStage > 0 and (objScenario.CurrentStage <= objScenario.Stages or objScenario.BonusCount > 0)) then		
			local intOffset = 0			
			local strTitle = ""
			local strTaskOrTimer = ""


			if (objScenario.IsComplete == true) then
				if( objScenario.IsDungeon ) then
					strTaskOrTimer= strScenarioTaskColour .. DUNGEON_COMPLETED .. "|r"	
				else
					strTaskOrTimer= strScenarioTaskColour .. SCENARIO_COMPLETED_GENERIC.. "|r"	
				end
			else
				--Setup Strings
				if (objScenario.IsChallengeMode == true and objScenario.Timer.Running) then
					strTitle = strScenarioHeaderColour ..  objScenario.StageName .. ": "  .."|r"
					strTaskOrTimer = strScenarioTaskColour .. CHALLENGE_MODE_POWER_LEVEL:format(objScenario.Level) .. "|r"	
				else
					if (objScenario.Stages ~= 1 and objScenario.SupressStageText == false) then
						strTitle = strScenarioHeaderColour .. L["Stage"] .. ": " .. objScenario.CurrentStage .. "/" .. objScenario.Stages  .. "|r"
					end

					strTaskOrTimer = strScenarioTaskColour .. objScenario.StageName .. "|r"		
				end
			end

		
			local objButton = self:GetMinionButton();
			objButton:SetWidth(minionWidth)
			objButton:SetParent(fraMinionAnchor);
			objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
			local objButtonHeight = 0

			objButton:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50)
				if (db.MoveTooltipsRight == true) then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50);
				else 
					GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -50);
				end
				if( objScenario.StageName and objScenario.SupressStageText == true) then
					GameTooltip:SetText(objScenario.StageName, 1, 0.914, 0.682, 1);
					GameTooltip:AddLine(objScenario.StageDescription, 1, 1, 1, true);
					GameTooltip:AddLine(" ");
					if ( objScenario.RewardXP > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
						GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, objScenario.RewardXP), 1, 1, 1);
					end
					if ( objScenario.RewardMoney > 0 ) then
						SetTooltipMoney(GameTooltip, objScenario.RewardMoney, nil);
					end
					GameTooltip:Show();
				elseif( objScenario.CurrentStage <= objScenario.Stages ) then
					GameTooltip:SetText(string.format(SCENARIO_STAGE_STATUS, objScenario.CurrentStage, objScenario.Stages), 1, 0.914, 0.682, 1);
					GameTooltip:AddLine(objScenario.StageName, 1, 0.831, 0.380, true);
					GameTooltip:AddLine(" ");
					GameTooltip:AddLine(objScenario.StageDescription, 1, 1, 1, true);
					GameTooltip:Show();
				end

			end)
			objButton:SetScript("OnLeave", function(self) 
				GameTooltip:Hide()
			end)
			
			
			--Chall/Scen Title Header
			objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
			objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioHeaderFont), db.Fonts.ScenarioHeaderFontSize, db.Fonts.ScenarioHeaderFontOutline)
			if (db.Fonts.ScenarioHeaderFontShadowed == true) then
				objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
			else
				objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
			end		

			objButton.objFontString1:SetText(strTitle);
			objButton.objFontString1:SetWidth(minionWidth)
			
			intOffset = objButton.objFontString1:GetHeight() + intHeaderOutlineOffset
			if (objButton.objFontString1:GetWidth() > intLargestWidth) then
				intLargestWidth = objButton.objFontString1:GetWidth()
			end
					
			if (strTaskOrTimer ~= "") then
				objButton.objFontString2:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -intOffset);
				objButton.objFontString2:SetFont(LSM:Fetch("font", db.Fonts.ScenarioTaskFont), db.Fonts.ScenarioTaskFontSize, db.Fonts.ScenarioTaskFontOutline)
				if (db.Fonts.ScenarioTaskFontShadowed == true) then
					objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 1.0)
				else
					objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 0.0)
				end
				
				objButton.objFontString2:SetText(strTaskOrTimer);					
				objButton.objFontString2:SetWidth(minionWidth)

				intOffset = intOffset + objButton.objFontString2:GetHeight() + intTaskOutlineOffset			
				if (objButton.objFontString2:GetWidth() > intLargestWidth) then
					intLargestWidth = objButton.objFontString2:GetWidth()
				end
			end

			local haveBonusTimer = false;
			for k, BonusInstance in pairs(objScenario.BonusList) do
				for k2, BonusCriteriaInstance in pairs(BonusInstance.CriteriaList) do
					if ( BonusCriteriaInstance.Duration > 0 and BonusCriteriaInstance.IsComplete == false and BonusCriteriaInstance.IsFailed == false ) then
						haveBonusTimer = true;
					end
				end
			end

			if (objScenario.Timer.Running == true and haveBonusTimer == false) then
				--Timer		
				local intStatusBarOffset = 2
				intOffset = intOffset + intStatusBarOffset
				if (objButton.StatusBar == nil) then
					objButton.StatusBar = ScenarioTracker:GetStatusBar(objScenario.Timer)
				end

				objButton.StatusBar:SetParent(objButton)
				objButton.StatusBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -intOffset);				
				
				-- Find out if string is larger then the current largest string
				if (objButton.StatusBar.objFontString:GetWidth() > intLargestWidth) then
					intLargestWidth = objButton.StatusBar.objFontString:GetWidth()
				end
				objButton.StatusBar.objFontString:SetWidth(minionWidth)
				objButton.StatusBar:SetWidth(minionWidth)
				objButton.StatusBar:SetHeight(objButton.StatusBar.objFontString:GetHeight() + 1)	
				
				intOffset = intOffset + objButton.StatusBar:GetHeight() + intStatusBarOffset			
				if (objButton.StatusBar:GetWidth() > intLargestWidth) then
					intLargestWidth = objButton.StatusBar:GetWidth()
				end				
			end

			intYPosition = intYPosition + intOffset	
			objButtonHeight = objButtonHeight + intOffset;	

			objButton:SetHeight(objButtonHeight)				
			tinsert(tblUsingButtons, objButton)	
				
			if (objScenario.IsChallengeMode and objScenario.Timer.Running == false and objScenario.Timer.IsValid) then
				local timeUpButton = self:GetMinionButton();
				timeUpButton:SetWidth(minionWidth)				
				timeUpButton:SetParent(objButton);
				timeUpButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
				local buttonHeight = 0			

			
				timeUpButton.objFontString1:SetPoint("TOPLEFT", timeUpButton, "TOPLEFT", 0, 0);
				timeUpButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioTaskFont), db.Fonts.ScenarioTaskFontSize, db.Fonts.ScenarioTaskFontOutline)
				if (db.Fonts.ScenarioTaskFontShadowed == true) then
					timeUpButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
				else
					timeUpButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
				end
				timeUpButton.objFontString1:SetText(strScenarioTaskColour .. CHALLENGE_MODE_TIMES_UP .. "|r");
				timeUpButton.objFontString1:SetWidth(minionWidth)
				
				timeUpButton:SetScript("OnEnter", function(self) 
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
					GameTooltip:SetText(CHALLENGE_MODE_TIMES_UP, 1, 1, 1);
					local line;
					if (objScenario.EnergisedKeystone == false) then
						if (UnitIsGroupLeader("player")) then
							line = CHALLENGE_MODE_TIMES_UP_NO_LOOT_LEADER;
						else
							line = CHALLENGE_MODE_TIMES_UP_NO_LOOT;
						end
					else
						line = CHALLENGE_MODE_TIMES_UP_LOOT;
					end
					GameTooltip:AddLine(line, nil, nil, nil, true);
					GameTooltip:Show();
				end)
				timeUpButton:SetScript("OnLeave", function(self) 
					GameTooltip:Hide()
				end)
				
				
				
				intOffset = timeUpButton.objFontString1:GetHeight() + intTitleOutlineOffset + intHeaderOutlineOffset + intTaskOutlineOffset + intObjectiveOutlineOffset
				if (timeUpButton.objFontString1:GetWidth() > intLargestWidth) then
					intLargestWidth = timeUpButton.objFontString1:GetWidth()
				end

				intYPosition = intYPosition + intOffset	
				buttonHeight = buttonHeight + intOffset
				
				timeUpButton:SetHeight(buttonHeight)					
				tinsert(tblUsingButtons,timeUpButton)	
				
			end
				
			--Objectives
			
			if (objScenario.Progress) then
				local objCriteriaButton = self:GetMinionButton();
				objCriteriaButton:SetWidth(minionWidth)				
				objCriteriaButton:SetParent(objButton);
				objCriteriaButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
				local buttonHeight = 0			

				local criteriaString = string.format("%s", objScenario.StageDescription);
		
				objCriteriaButton.objFontString1:SetPoint("TOPLEFT", objCriteriaButton, "TOPLEFT", 0, 0);
				objCriteriaButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioObjectiveFont), db.Fonts.ScenarioObjectiveFontSize, db.Fonts.ScenarioObjectiveFontOutline)
				if (db.Fonts.ScenarioObjectiveFontShadowed == true) then
					objCriteriaButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
				else
					objCriteriaButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
				end
				objCriteriaButton.objFontString1:SetText(strScenarioObjectiveColour .. " - " .. criteriaString .. "|r");
				objCriteriaButton.objFontString1:SetWidth(minionWidth)
				
				intOffset = objCriteriaButton.objFontString1:GetHeight() + intTitleOutlineOffset + intHeaderOutlineOffset + intTaskOutlineOffset + intObjectiveOutlineOffset
				if (objCriteriaButton.objFontString1:GetWidth() > intLargestWidth) then
					intLargestWidth = objCriteriaButton.objFontString1:GetWidth()
				end
					
		
				local intStatusBarOffset = 2
				intOffset = intOffset + intStatusBarOffset
				if (objCriteriaButton.ProgressBar == nil) then
					objCriteriaButton.ProgressBar = ScenarioTracker:GetProgressBar(objScenario.Progress)
				end

				objCriteriaButton.ProgressBar:SetParent(objCriteriaButton)
				objCriteriaButton.ProgressBar:SetPoint("TOPLEFT", objCriteriaButton, "TOPLEFT", 0, -intOffset);				
				
				-- Find out if string is larger then the current largest string
				if (objCriteriaButton.ProgressBar.objFontString:GetWidth() > intLargestWidth) then
					intLargestWidth = objCriteriaButton.ProgressBar.objFontString:GetWidth()
				end
				objCriteriaButton.ProgressBar.objFontString:SetWidth(minionWidth)
				objCriteriaButton.ProgressBar:SetWidth(minionWidth)
				objCriteriaButton.ProgressBar:SetHeight(objCriteriaButton.ProgressBar.objFontString:GetHeight() + 1)	
				
				intOffset = intOffset + objCriteriaButton.ProgressBar:GetHeight() + intStatusBarOffset			
				if (objCriteriaButton.ProgressBar:GetWidth() > intLargestWidth) then
					intLargestWidth = objCriteriaButton.ProgressBar:GetWidth()
				end
			


				intYPosition = intYPosition + intOffset	
				buttonHeight = buttonHeight + intOffset
				
				objCriteriaButton:SetHeight(buttonHeight)					
				tinsert(tblUsingButtons,objCriteriaButton)	
			else
				for k, CriteriaInstance in pairs(objScenario.CriteriaList) do
					local objCriteriaButton = self:GetMinionButton();
					objCriteriaButton:SetWidth(minionWidth)				
					objCriteriaButton:SetParent(objButton);
					objCriteriaButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
					local buttonHeight = 0			
					
						
							--Objective
					local criteriaString = string.format("%s: %d/%d", CriteriaInstance.Name, CriteriaInstance.Quantity, CriteriaInstance.TotalQuantity);
					if (CriteriaInstance.IsProgressBar) then
						criteriaString = string.format("%s:", CriteriaInstance.Name);
					end
				
					objCriteriaButton.objFontString1:SetPoint("TOPLEFT", objCriteriaButton, "TOPLEFT", 0, 0);
					objCriteriaButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioObjectiveFont), db.Fonts.ScenarioObjectiveFontSize, db.Fonts.ScenarioObjectiveFontOutline)
					if (db.Fonts.ScenarioObjectiveFontShadowed == true) then
						objCriteriaButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
					else
						objCriteriaButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
					end
					objCriteriaButton.objFontString1:SetText(strScenarioObjectiveColour .. " - " .. criteriaString .. "|r");
					objCriteriaButton.objFontString1:SetWidth(minionWidth)
					
					intOffset = objCriteriaButton.objFontString1:GetHeight() + intTitleOutlineOffset + intHeaderOutlineOffset + intTaskOutlineOffset + intObjectiveOutlineOffset
					if (objCriteriaButton.objFontString1:GetWidth() > intLargestWidth) then
						intLargestWidth = objCriteriaButton.objFontString1:GetWidth()
					end
						
					if (CriteriaInstance.IsProgressBar) then
						local intStatusBarOffset = 2
						intOffset = intOffset + intStatusBarOffset
						if (objCriteriaButton.ProgressBar == nil) then
							objCriteriaButton.ProgressBar = ScenarioTracker:GetProgressBar(CriteriaInstance.Quantity)
						end

						objCriteriaButton.ProgressBar:SetParent(objCriteriaButton)
						objCriteriaButton.ProgressBar:SetPoint("TOPLEFT", objCriteriaButton, "TOPLEFT", 0, -intOffset);				
						
						-- Find out if string is larger then the current largest string
						if (objCriteriaButton.ProgressBar.objFontString:GetWidth() > intLargestWidth) then
							intLargestWidth = objCriteriaButton.ProgressBar.objFontString:GetWidth()
						end
						objCriteriaButton.ProgressBar.objFontString:SetWidth(minionWidth)
						objCriteriaButton.ProgressBar:SetWidth(minionWidth)
						objCriteriaButton.ProgressBar:SetHeight(objCriteriaButton.ProgressBar.objFontString:GetHeight() + 1)	
						
						intOffset = intOffset + objCriteriaButton.ProgressBar:GetHeight() + intStatusBarOffset			
						if (objCriteriaButton.ProgressBar:GetWidth() > intLargestWidth) then
							intLargestWidth = objCriteriaButton.ProgressBar:GetWidth()
						end
					end


					intYPosition = intYPosition + intOffset	
					buttonHeight = buttonHeight + intOffset
					
					objCriteriaButton:SetHeight(buttonHeight)					
					tinsert(tblUsingButtons,objCriteriaButton)	
					
				end
			end
			
			--Affixes
			if (objScenario.Timer.IsValid) then
				if (objScenario.EnergisedKeystone) then
					if (objScenario.Timer.TimeLeft > objScenario.Timer.ThreeChestTime) then
						objScenario.Affixes["+3"] = {Name = ("%s: %s"):format("+3", SorhaQuestLog:SecondsToFormatedTime(objScenario.Timer.ThreeChestTime)), Description="Time for +3 Chest" };				
					else
						objScenario.Affixes["+3"] = {Name = ("%s: %s (Failed)"):format("+3", SorhaQuestLog:SecondsToFormatedTime(objScenario.Timer.ThreeChestTime)), Description="Time for +3 Chest" };				
					end
					if (objScenario.Timer.TimeLeft > objScenario.Timer.ThreeChestTime) then
						objScenario.Affixes["+2"] = {Name = ("%s: %s"):format("+2", SorhaQuestLog:SecondsToFormatedTime(objScenario.Timer.TwoChestTime)), Description="Time for +2 Chest" };				
					else
						objScenario.Affixes["+2"] = {Name = ("%s: %s (Failed)"):format("+2", SorhaQuestLog:SecondsToFormatedTime(objScenario.Timer.TwoChestTime)), Description="Time for +2 Chest" };				
					end
				end
				

				for k, affixInstance in pairs(objScenario.Affixes) do
					local affixButton = self:GetMinionButton();
					affixButton:SetWidth(minionWidth)				
					affixButton:SetParent(objButton);
					affixButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
					local buttonHeight = 0			

				
					affixButton.objFontString1:SetPoint("TOPLEFT", affixButton, "TOPLEFT", 0, 0);
					affixButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioObjectiveFont), db.Fonts.ScenarioObjectiveFontSize, db.Fonts.ScenarioObjectiveFontOutline)
					if (db.Fonts.ScenarioObjectiveFontShadowed == true) then
						affixButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
					else
						affixButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
					end
					affixButton.objFontString1:SetText(strScenarioObjectiveColour .. " - " .. affixInstance.Name .. "|r");
					affixButton.objFontString1:SetWidth(minionWidth)
					
					affixButton:SetScript("OnEnter", function(self) 
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);			
						GameTooltip:SetText(affixInstance.Name, 1, 0.914, 0.682, 1);
						GameTooltip:AddLine(" ");
						GameTooltip:AddLine(affixInstance.Description, 1, 1, 1, true);
						GameTooltip:Show();
					end)
					affixButton:SetScript("OnLeave", function(self) 
						GameTooltip:Hide()
					end)
					
					
					
					intOffset = affixButton.objFontString1:GetHeight() + intTitleOutlineOffset + intHeaderOutlineOffset + intTaskOutlineOffset + intObjectiveOutlineOffset
					if (affixButton.objFontString1:GetWidth() > intLargestWidth) then
						intLargestWidth = affixButton.objFontString1:GetWidth()
					end

					intYPosition = intYPosition + intOffset	
					buttonHeight = buttonHeight + intOffset
					
					affixButton:SetHeight(buttonHeight)					
					tinsert(tblUsingButtons,affixButton)	
				end	
			end
			
			if (#(objScenario.BonusList) > 0) then
				intYPosition = intYPosition + 10;
			end
			for k, BonusInstance in pairs(objScenario.BonusList) do
				local bonusCriteriaString = strScenarioTaskColour .. BonusInstance.Name .. "|r"
				if (BonusInstance.IsFailed == true) then 
					bonusCriteriaString = bonusCriteriaString .. "|cffff2222 (FAILED)|r";
				end
				bonusCriteriaString = bonusCriteriaString .. "\n";
				
				local bonusTimerUp = false;
				for k2, BonusCriteriaInstance in pairs(BonusInstance.CriteriaList) do
					local criteriaString = string.format("%s: %d/%d", BonusCriteriaInstance.Name, BonusCriteriaInstance.Quantity, BonusCriteriaInstance.TotalQuantity);					
					if (BonusCriteriaInstance.IsProgressBar) then
						criteriaString = string.format("%s: %d/%d", BonusCriteriaInstance.Name, BonusCriteriaInstance.Quantity, "100%");					
					end
					if (BonusCriteriaInstance.Quantity == 0 and BonusCriteriaInstance.TotalQuantity == 0) then
						criteriaString = BonusCriteriaInstance.Quantity;
					end

					if (BonusCriteriaInstance.IsFailed) then
						criteriaString = criteriaString .. " (Failed)"
					end
					
					bonusCriteriaString = bonusCriteriaString .. strScenarioObjectiveColour .. " - " .. criteriaString .. "|r\n"
				end		
				
								
				local objBonusButton = self:GetMinionButton();
				objBonusButton.BonusInstance = BonusInstance;
				objBonusButton:SetScale(db.MinionScale)
				objBonusButton:SetWidth(minionWidth)				
				objBonusButton:SetParent(objButton);
				objBonusButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
				local buttonHeight = 0					

				
				-- TOOLTIP
				objBonusButton:SetScript("OnEnter", function(self) 
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50)
					if (db.MoveTooltipsRight == true) then
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -50);
					else 
						GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -50);
					end
					GameTooltip:SetText(REWARDS, 1, 0.831, 0.380);
					GameTooltip:AddLine(BONUS_OBJECTIVE_TOOLTIP_DESCRIPTION, 1, 1, 1, 1);
					GameTooltip:AddLine(" ");
					-- xp
					local xp = GetQuestLogRewardXP(self.BonusInstance.RewardQuestID);
					if ( xp > 0 ) then
						GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1);
					end
					-- currency		
					local numQuestCurrencies = GetNumQuestLogRewardCurrencies(self.BonusInstance.RewardQuestID);
					for i = 1, numQuestCurrencies do
						local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, self.BonusInstance.RewardQuestID);
						local text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name);
						GameTooltip:AddLine(text, 1, 1, 1);			
					end
					-- items
					local numQuestRewards = GetNumQuestLogRewards(self.BonusInstance.RewardQuestID);
					for i = 1, numQuestRewards do
						local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i, self.BonusInstance.RewardQuestID);
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
					local money = GetQuestLogRewardMoney(self.BonusInstance.RewardQuestID);
					if ( money > 0 ) then
						SetTooltipMoney(GameTooltip, money, nil);
					end

					GameTooltip:Show();
				end)
				objBonusButton:SetScript("OnLeave", function(self) 
					GameTooltip:Hide()
				end)
				

				--Bonus Critera
				objBonusButton.objFontString1:SetPoint("TOPLEFT", objBonusButton, "TOPLEFT", 0, 0);
				objBonusButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioObjectiveFont), db.Fonts.ScenarioObjectiveFontSize, db.Fonts.ScenarioObjectiveFontOutline)
				if (db.Fonts.ScenarioObjectiveFontShadowed == true) then
					objBonusButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
				else
					objBonusButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
				end
				
				objBonusButton.objFontString1:SetText(strScenarioObjectiveColour .. bonusCriteriaString .. "|r");
				objBonusButton.objFontString1:SetWidth(minionWidth)
				
				intOffset = objBonusButton.objFontString1:GetHeight() + intTitleOutlineOffset + intHeaderOutlineOffset + intTaskOutlineOffset + intObjectiveOutlineOffset
				if (objBonusButton.objFontString1:GetWidth() > intLargestWidth) then
					intLargestWidth = objBonusButton.objFontString1:GetWidth()
				end


				if (objScenario.Timer.Running == true and haveBonusTimer == true) then
					--Timer		
					local intStatusBarOffset = 2
					intOffset = intOffset + intStatusBarOffset
					if (objBonusButton.StatusBar == nil) then
						objBonusButton.StatusBar = ScenarioTracker:GetStatusBar(objScenario.Timer)
					end

					objBonusButton.StatusBar:SetParent(objBonusButton)
					objBonusButton.StatusBar:SetPoint("TOPLEFT", objBonusButton, "TOPLEFT", 0, -intOffset);				
					
					-- Find out if string is larger then the current largest string
					if (objBonusButton.StatusBar.objFontString:GetWidth() > intLargestWidth) then
						intLargestWidth = objBonusButton.StatusBar.objFontString:GetWidth()
					end
					objBonusButton.StatusBar.objFontString:SetWidth(minionWidth)
					objBonusButton.StatusBar:SetWidth(minionWidth)
					objBonusButton.StatusBar:SetHeight(objBonusButton.StatusBar.objFontString:GetHeight() + 1)	
					
					intOffset = intOffset + objBonusButton.StatusBar:GetHeight() + intStatusBarOffset			
					if (objBonusButton.StatusBar:GetWidth() > intLargestWidth) then
						intLargestWidth = objBonusButton.StatusBar:GetWidth()
					end					
				end


				intYPosition = intYPosition + intOffset	
				buttonHeight = buttonHeight + intOffset
				
				objBonusButton:SetHeight(buttonHeight)					
				tinsert(tblUsingButtons,objBonusButton)				
			end
		
		
			
		
		
			if (createSpellButtons) then
				local numSpells = 0;
				if (objScenario.Spells and objScenario.Spells ~= 0) then
					numSpells = #objScenario.Spells;
					
					for spellIndex = 1, numSpells do
						local objSpellButton = self:GetSpellButton(objScenario.Spells[spellIndex], -intYPosition)
					end
					
				end
			end
		else
			blnNothingShown = true;
		end	
	elseif (objScenario:IsActive() and objScenario.IsProvingGrounds == true) then

		blnNothingShown = false;
		local intOffset = 0
		
		local strTitle = strScenarioHeaderColour .. objScenario.DifficultyString .. "|r"
		local strTask = strScenarioTaskColour  ..  "- Wave: " .. objScenario.CurrentWave .. "/" .. objScenario.Waves  .. "|r"
		local intTimeLeft = intPGDuration - intPGElapsedTime;
		
		local objButton = self:GetMinionButton();
		objButton:SetWidth(minionWidth)
		objButton:SetParent(fraMinionAnchor);
		objButton:SetPoint("TOPLEFT", fraMinionAnchor.fraScenariosAnchor, "TOPLEFT", 0, -intYPosition);
		local objButtonHeight = 0
		
		--Title
		objButton.objFontString1:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, 0);
		objButton.objFontString1:SetFont(LSM:Fetch("font", db.Fonts.ScenarioHeaderFont), db.Fonts.ScenarioHeaderFontSize, db.Fonts.ScenarioHeaderFontOutline)
		if (db.Fonts.ScenarioHeaderFontShadowed == true) then
			objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 1.0)
		else
			objButton.objFontString1:SetShadowColor(0.0, 0.0, 0.0, 0.0)
		end		

		objButton.objFontString1:SetText(strTitle);
		objButton.objFontString1:SetWidth(minionWidth)
		
		intOffset = intOffset + objButton.objFontString1:GetHeight() + intHeaderOutlineOffset
		if (objButton.objFontString1:GetWidth() > intLargestWidth) then
			intLargestWidth = objButton.objFontString1:GetWidth()
		end

		objButton.objFontString2:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -intOffset);
		objButton.objFontString2:SetFont(LSM:Fetch("font", db.Fonts.ScenarioTaskFont), db.Fonts.ScenarioTaskFontSize, db.Fonts.ScenarioTaskFontOutline)
		if (db.Fonts.ScenarioTaskFontShadowed == true) then
			objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 1.0)
		else
			objButton.objFontString2:SetShadowColor(0.0, 0.0, 0.0, 0.0)
		end
		
		objButton.objFontString2:SetText(strTask);					
		objButton.objFontString2:SetWidth(minionWidth)

		intOffset = intOffset + objButton.objFontString2:GetHeight() + intTaskOutlineOffset			
		if (objButton.objFontString2:GetWidth() > intLargestWidth) then
			intLargestWidth = objButton.objFontString2:GetWidth()
		end




		--Timer		
		local intStatusBarOffset = 2
		intOffset = intOffset + intStatusBarOffset
		if (objButton.StatusBar == nil) then
			objButton.StatusBar = ScenarioTracker:GetStatusBar(objScenario.Timer)
		end
	

		objButton.StatusBar:SetParent(objButton)
		objButton.StatusBar:SetPoint("TOPLEFT", objButton, "TOPLEFT", 0, -intOffset);
		

		
		-- Find out if string is larger then the current largest string
		if (objButton.StatusBar.objFontString:GetWidth() > intLargestWidth) then
			intLargestWidth = objButton.StatusBar.objFontString:GetWidth()
		end
		objButton.StatusBar.objFontString:SetWidth(minionWidth)
		objButton.StatusBar:SetWidth(minionWidth)
		objButton.StatusBar:SetHeight(objButton.StatusBar.objFontString:GetHeight() + 1)	
		
		intOffset = intOffset + objButton.StatusBar:GetHeight() + intStatusBarOffset			
		if (objButton.StatusBar:GetWidth() > intLargestWidth) then
			intLargestWidth = objButton.StatusBar:GetWidth()
		end
	
	
		intYPosition = intYPosition + intOffset	
		objButtonHeight = objButtonHeight + intOffset;	

		objButton:SetHeight(objButtonHeight)				
		tinsert(tblUsingButtons,objButton)	
	end
	
	fraMinionAnchor.BottomFrame:SetPoint("TOPLEFT", fraMinionAnchor, "TOPLEFT", 0, -intYPosition);
	fraMinionAnchor.BottomFrame:SetWidth(fraMinionAnchor:GetWidth());
	
	-- Border/Background
	if (blnNothingShown == true) then
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, 0)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, 0)		
	else
		fraMinionAnchor.BorderFrame:SetBackdropColor(db.Colours.MinionBackGroundColour.r, db.Colours.MinionBackGroundColour.g, db.Colours.MinionBackGroundColour.b, db.Colours.MinionBackGroundColour.a)
		fraMinionAnchor.BorderFrame:SetBackdropBorderColor(db.Colours.MinionBorderColour.r, db.Colours.MinionBorderColour.g, db.Colours.MinionBorderColour.b, db.Colours.MinionBorderColour.a)	
		fraMinionAnchor.BorderFrame:SetWidth(intLargestWidth + 16)
		fraMinionAnchor.BorderFrame:SetHeight((intYPosition * db.MinionScale) + 2 + fraMinionAnchor:GetHeight()/2)
	end
	
	blnMinionUpdating = false
end 

--Data
function ScenarioTracker:UpdateData()
	if (objScenario == nil) then
		objScenario = SQLScenario:new();
	else
		objScenario:Update();
	end
end

--Timer Bars
function ScenarioTracker:StartTimer(duration, elapsed)
	if (objScenario == nil ) then
		ScenarioTracker:UpdateData();
	end

	objScenario.Timer:Start(duration, elapsed);
	self:UpdateMinion();
end

function ScenarioTracker:StopTimer()
	if (objScenario == nil ) then
		ScenarioTracker:UpdateData();
	end
	objScenario.Timer:Stop();
	self:UpdateMinion();
end

function ScenarioTracker:CheckForDurationTimers()	
	ScenarioTracker:UpdateData();

	if(objScenario.Duration < 1) then
		local criteriaDuration = 0;
		local criteriaElapsed = 0;

		for k, CriteriaInstance in pairs(objScenario.CriteriaList) do
			if (CriteriaInstance.IsComplete == false and CriteriaInstance.IsFailed == false and CriteriaInstance.Duration > 0 and (CriteriaInstance.Elapsed == nil or CriteriaInstance.Duration > CriteriaInstance.Elapsed)) then
				criteriaDuration = CriteriaInstance.Duration;
				criteriaElapsed = CriteriaInstance.Elapsed;
				break;
			end
		end

		if (criteriaDuration == 0) then
			for k, BonusInstance in pairs(objScenario.BonusList) do						
				for k2, CriteriaInstance in pairs(BonusInstance.CriteriaList) do
					if (CriteriaInstance.IsComplete == false and CriteriaInstance.IsFailed == false and CriteriaInstance.Duration > 0 and (CriteriaInstance.Elapsed == nil or CriteriaInstance.Duration > CriteriaInstance.Elapsed)) then
						criteriaDuration = CriteriaInstance.Duration;
						criteriaElapsed = CriteriaInstance.Elapsed;
						break;
					end
				end
			end
		end

		if (criteriaDuration > 0 and criteriaElapsed == nil) then
			criteriaElapsed = 0;
		end
	
		if (criteriaDuration > 0 and criteriaDuration > criteriaElapsed) then
			ScenarioTracker:StartTimer(criteriaDuration, criteriaElapsed);
		end
	end
end

function ScenarioTracker:CheckTimers(...)
	if (objScenario and objScenario.Timer) then
		objScenario.Timer.IsValid = false;
	end
	
	for i = 1, select("#", ...) do
		local timerID = select(i, ...);		
		local _, elapsedTime, timerType = GetWorldElapsedTime(timerID);	

		if ( timerType == LE_WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND ) then
			local duration = objScenario.Duration;
			ScenarioTracker:StartTimer(duration, elapsedTime)
			return;
		elseif (timerType == LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE ) then
			local mapID = C_ChallengeMode.GetActiveChallengeMapID()
			if ( mapID ) then
				local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID);
				ScenarioTracker:StartTimer(timeLimit, elapsedTime)			
				return;
			end
		end		
	end	
	ScenarioTracker:StopTimer();
end


--Uniform
function ScenarioTracker:MinionAnchorUpdate(blnMoveAnchors)
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
				self:UpdateMinion()
			end
		else
			fraMinionAnchor:Hide()
		end
		
		fraMinionAnchor.BorderFrame:SetBackdrop({bgFile = LSM:Fetch("background", dbCore.BackgroundTexture), tile = false, tileSize = 16,	edgeFile = LSM:Fetch("border", dbCore.BorderTexture), edgeSize = 16,	insets = {left = 5, right = 3, top = 3, bottom = 3}})

		-- Set position to stored position
		if (blnMoveAnchors == true) then
			fraMinionAnchor:ClearAllPoints()

			local isUIParent = false;
			if (db.MinionParent == "UIParent" or fraMinionAnchor:GetParent() == UIParent) then
				isUIParent = true;
			end

			if (isUIParent == true) then
				fraMinionAnchor:SetPoint(db.MinionLocation.Point, UIParent, db.MinionLocation.RelativePoint, db.MinionLocation.X, db.MinionLocation.Y);
			else
				fraMinionAnchor:SetPoint("TOPLEFT", db.MinionParent,"TOPLEFT", 0, 4);
			end

			fraMinionAnchor:SetScale(db.MinionScale);
		end
	end
end

function ScenarioTracker:UpdateColourStrings()
	strMinionTitleColour = format("|c%02X%02X%02X%02X", 255, db.Colours.MinionTitleColour.r * 255, db.Colours.MinionTitleColour.g * 255, db.Colours.MinionTitleColour.b * 255);
	strScenarioHeaderColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ScenarioHeaderColour.r * 255, db.Colours.ScenarioHeaderColour.g * 255, db.Colours.ScenarioHeaderColour.b * 255);
	strScenarioTaskColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ScenarioTaskColour.r * 255, db.Colours.ScenarioTaskColour.g * 255, db.Colours.ScenarioTaskColour.b * 255);
	strScenarioObjectiveColour = format("|c%02X%02X%02X%02X", 255, db.Colours.ScenarioObjectiveColour.r * 255, db.Colours.ScenarioObjectiveColour.g * 255, db.Colours.ScenarioObjectiveColour.b * 255);
end

function ScenarioTracker:HandleColourChanges()
	self:UpdateColourStrings()
	if (self:IsVisible() == true) then
		if (blnMinionUpdating == false) then
			blnMinionUpdating = true
			self:ScheduleTimer("UpdateMinion", 0.1)
		end
	end
end

function ScenarioTracker:ToggleLockState()
	db.MinionLocked = not db.MinionLocked
end

function ScenarioTracker:IsVisible()
	if (self:IsEnabled() == true and dbCore.Main.HideAll == false) then
		return true
	end
	return false	
end
