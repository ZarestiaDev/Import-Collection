-- 
-- Please see the LICENSE.md file included with this distribution for 
-- attribution and copyright information.
--

local _tImportState = {};

function onInit()
	Interface.onDesktopInit = onDesktopInit;
end
function onDesktopInit()
	local sLabel = Interface.getString("import_mode_2022");
	ImportUtilityManager.registerImportMode("npc", "2022", sLabel, ImportNPCManager.import2022);
end

function performImport(w)
	local sMode = w.mode.getSelectedValue();
	local tImportMode = ImportUtilityManager.getImportMode("npc", sMode);
	if tImportMode then
		local sStats = w.statblock.getValue();
		local sDesc = w.description.getValue();
		tImportMode.fn(sStats, sDesc);
	end
end

--
--	Built-in supported import modes
--

function import2022(sStats, sDesc)
	-- Track state information
	ImportNPCManager.initImportState(sStats, sDesc);

	-- GENERAL
	-- Assume Name/CR next
	ImportNPCManager.importHelperNameCr();
	-- Skip possible source and xp
	ImportNPCManager.importHelperSkip("source");
	ImportNPCManager.importHelperSkip("xp");
	-- Assume Alignment/Size/Type next
	ImportNPCManager.importHelperAlignmentSizeType();
	-- Assume Initiative/Senses next
	ImportNPCManager.importHelperInitiativeSenses();
	-- Assume Aura next (optional)
	ImportNPCManager.importHelperSimpleLine("aura");

	-- DEFENSE
	-- Assume Defense next
	ImportNPCManager.importHelperSkip("defense");
	ImportNPCManager.importHelperACHP();
	ImportNPCManager.importHelperSaves();
	ImportNPCManager.importHelperDefOptional();

	-- OFFENSE
	ImportNPCManager.importHelperSkip("offense");
	-- Assume Speed next
	ImportNPCManager.importHelperSimpleLine("speed");
	-- Assume Attacks next
	ImportNPCManager.importHelperAttack();
	-- Assume Space/Reach next
	ImportNPCManager.importHelperSpaceReach();
	ImportNPCManager.importHelperSimpleLine("special attacks");
	-- Assume Spells next (optional)
	ImportNPCManager.importHelperSpells();
	-- Assume Tactics next (optional)
	ImportNPCManager.importHelperTactics();

	-- STATISTICS
	ImportNPCManager.importHelperSkip("statistics");
	-- Assume Ability Scores next
	ImportNPCManager.importHelperAbilityScores();
	-- Assume BAB/CMB/CMD next
	ImportNPCManager.importHelperBabCmbCmd();
	-- Assume Feats next (optional)
	ImportNPCManager.importHelperSimpleLine("feats");
	-- Assume Skills next (optional)
	ImportNPCManager.importHelperSimpleLine("skills");
	-- Assume Languages next (optional)
	ImportNPCManager.importHelperSimpleLine("languages");

	-- MISC
	-- Assume SQ next (optional)
	ImportNPCManager.importHelperSQ();
	-- Assume Gear next (optional)
	ImportNPCManager.importHelperGear();

	-- ECOLOGY
	ImportNPCManager.importHelperSkip("ecology");
	-- Assume Environment next (optional)
	ImportNPCManager.importHelperSimpleLine("environment");
	-- Assume Organization next (optional)
	ImportNPCManager.importHelperSimpleLine("organization");
	-- Assume Treasure next (optional)
	ImportNPCManager.importHelperSimpleLine("treasure");

	-- FINALIZING
	-- Assume Special Abilities next
	ImportNPCManager.importHelperSpecialAbilities();
	-- Update Spellclass information
	ImportNPCManager.finalizeSpellclass();
	-- Update uppercase for some fields
	ImportNPCManager.finalizeUppercase();
	-- Update Description by adding the statblock text as well
	ImportNPCManager.finalizeDescription();
	-- Open new record window and matching campaign list
	ImportUtilityManager.showRecord("npc", _tImportState.node);
end

--
--	Import section helper functions
--

function importHelperSkip(sKeyword)
	ImportNPCManager.nextImportLine();

	if not _tImportState.sActiveLine:lower():match("^" .. sKeyword) then
		ImportNPCManager.previousImportLine();
	end
end

function importHelperSimpleLine(sCategory)
	ImportNPCManager.nextImportLine();

	if not _tImportState.sActiveLine then
		return;
	end

	local sLine = _tImportState.sActiveLine:lower();
	if sLine:match("^" .. sCategory) then
		local sCategoryLine = sLine:gsub("^" .. sCategory .. "%s", "");
		sCategory = sCategory:gsub("%s", "");
		DB.setValue(_tImportState.node, sCategory, "string", StringManager.capitalize(sCategoryLine));
	else
		ImportNPCManager.previousImportLine();
	end
end

function importHelperSQjoin(sNew)
	local sSQ = DB.getValue(_tImportState.node, "specialqualities", "");
	sNew = sNew:gsub("^%s", "");

	if sSQ ~= "" then
		sSQ = sSQ .. ", " .. sNew;
	else
		sSQ = sNew;
	end

	DB.setValue(_tImportState.node, "specialqualities", "string", sSQ);
end

function importHelperNameCr()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	local sName = sLine:gsub("%sCR.+", "");
	local nCR = tonumber(sLine:match("CR%s(%d+)"));
	if sLine:match("1/8") then
		nCR = 0.125;
	elseif sLine:match("1/6") then
		nCR = 0.166;
	elseif sLine:match("1/4") then
		nCR = 0.25;
	elseif sLine:match("1/3") then
		nCR = 0.333;
	elseif sLine:match("1/2") then
		nCR = 0.5;
	end

	DB.setValue(_tImportState.node, "name", "string", sName);
	DB.setValue(_tImportState.node, "cr", "number", nCR);
end

function importHelperAlignmentSizeType()
	ImportNPCManager.nextImportLine();

	-- Handle optional race/class
	if _tImportState.sActiveLine:match("%d+") then
		local sRaceClass = _tImportState.sActiveLine;

		ImportNPCManager.nextImportLine();

		local sAlignmentSizeType = _tImportState.sActiveLine;
		DB.setValue(_tImportState.node, "type", "string", sAlignmentSizeType .. " [" .. sRaceClass .. "]");
	else
		DB.setValue(_tImportState.node, "type", "string", _tImportState.sActiveLine);
	end
end

function importHelperInitiativeSenses()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	local nInit = tonumber(sLine:match("Init%s(.?%d+)"));
	local sSenses = sLine:match("Senses%s(.*)");

	DB.setValue(_tImportState.node, "init", "number", nInit);
	DB.setValue(_tImportState.node, "senses", "string", StringManager.capitalize(sSenses));
end

function importHelperACHP()
	ImportNPCManager.nextImportLine();

	-- Extract AC
	local sLine = _tImportState.sActiveLine:lower();
	local sACLine, sRemainder = StringManager.extractPattern(sLine, "^ac.-%)");
	local sAC = StringManager.trim(sACLine:gsub("ac", "")) or "";
	-- Extract HP
	sRemainder = sRemainder:gsub("%s?hp%s?", "");
	local nHP = sRemainder:match("%d+") or 0;
	local sHD = sRemainder:match("%((.-)%)") or "";

	-- Handle optional Regeneration
	if sRemainder:match("regeneration") then
		local sRegeneration = sRemainder:match("(regeneration%s%d+)");
		ImportNPCManager.importHelperSQjoin(sRegeneration);
	end

	DB.setValue(_tImportState.node, "ac", "string", sAC);
	DB.setValue(_tImportState.node, "hp", "number", nHP);
	DB.setValue(_tImportState.node, "hd", "string", sHD);
end

function importHelperSaves()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;

	local nFort = tonumber(sLine:match("Fort%s(%-?%+?%d+)")) or 0;
	local nRef = tonumber(sLine:match("Ref%s(%-?%+?%d+)")) or 0;
	local nWill = tonumber(sLine:match("Will%s(%-?%+?%d+)")) or 0;

	if sLine:match(";") then
		local aLines = StringManager.splitByPattern(sLine, ";");
		ImportNPCManager.importHelperSQjoin(aLines[2]);
	end

	DB.setValue(_tImportState.node, "fortitudesave", "number", nFort);
	DB.setValue(_tImportState.node, "reflexsave", "number", nRef);
	DB.setValue(_tImportState.node, "willsave", "number", nWill);
end

function importHelperDefOptional()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	if sLine:lower():match("offense") or sLine:lower():match("speed") then
		ImportNPCManager.previousImportLine();
		return;
	end

	-- check optional Weaknesses
	ImportNPCManager.nextImportLine();

	local sNextLine = _tImportState.sActiveLine;
	if sNextLine:match("Weaknesses") then
		sLine = sLine .. ", " .. sNextLine;
	else
		ImportNPCManager.previousImportLine();
	end

	sLine = sLine:gsub("Defensive%sAbilities%s", "");
	sLine = sLine:gsub("Weaknesses%s", "");

	ImportNPCManager.importHelperSQjoin(sLine);
end

function importHelperTactics()
	ImportNPCManager.nextImportLine();

	if _tImportState.sActiveLine:lower():match("^tactics") then
		ImportNPCManager.addStatOutput("<h>Tactics</h>")

		while not _tImportState.sActiveLine:lower():match("^statistics") do
			ImportNPCManager.nextImportLine();

			local sLine = _tImportState.sActiveLine;
			if not sLine or sLine == "" or sLine:lower():match("^statistics") or sLine:lower():match("^str%s") then
				ImportNPCManager.previousImportLine();
				break;
			end

			ImportNPCManager.addStatOutput(string.format("<p>%s</p>", sLine));
		end
	else
		ImportNPCManager.previousImportLine();
	end
end

function importHelperAttack()
	-- Handle melee attacks
	ImportNPCManager.nextImportLine();

	local sMelee = _tImportState.sActiveLine:gsub("^Melee%s?", "");
	sMelee = sMelee:gsub("&#215;", "x");
	local sMeleeAtk, sMeleeFullAtk = importHelperAttackFormat(sMelee);
	local sRangedAtk = "";
	local sRangedFullAtk = "";

	-- Check for optional ranged attacks
	ImportNPCManager.nextImportLine();

	local sRanged = _tImportState.sActiveLine;
	if sRanged:match("Ranged") then
	 	sRanged = sRanged:gsub("^Ranged%s?", "");
		sRanged = sRanged:gsub("&#215;", "x");
		sRangedAtk, sRangedFullAtk = importHelperAttackFormat(sRanged);
	else
		ImportNPCManager.previousImportLine();
	end

	-- Clenaup Attacks
	sMeleeAtk = sMeleeAtk:gsub("/%+.-%(", " (");
	sMeleeAtk = sMeleeAtk:gsub("^%d+%s(%a+)s", "%1");
	sRangedAtk = sRangedAtk:gsub("/%+.-%(", " (");
	sRangedAtk = sRangedAtk:gsub("^%d+%s(%a+)s", "%1");
	sRangedAtk = sRangedAtk:gsub("(%d+%s)%(", "%1ranged (");
	sMeleeFullAtk = sMeleeFullAtk:gsub(",", " and");
	sRangedFullAtk = sRangedFullAtk:gsub(",", " and");
	sRangedFullAtk = sRangedFullAtk:gsub("(%d+%s)%(", "%1ranged (");

	sMeleeAtk = StringManager.capitalize(sMeleeAtk);
	sMeleeFullAtk = StringManager.capitalize(sMeleeFullAtk);
	sRangedAtk = StringManager.capitalize(sRangedAtk);
	sRangedFullAtk = StringManager.capitalize(sRangedFullAtk);

	-- Merge Attacks
	if sMeleeAtk ~= "" and sRangedAtk ~= "" then
		DB.setValue(_tImportState.node, "atk", "string", sMeleeAtk .. " or " .. sRangedAtk);
	else
		DB.setValue(_tImportState.node, "atk", "string", sMeleeAtk .. sRangedAtk);
	end

	-- Merge Full Attacks
	if sMeleeFullAtk ~= "" and sRangedFullAtk ~= "" then
		DB.setValue(_tImportState.node, "fullatk", "string", sMeleeFullAtk .. " or " .. sRangedFullAtk);
	else
		DB.setValue(_tImportState.node, "fullatk", "string", sMeleeFullAtk .. sRangedFullAtk);
	end
end

function importHelperAttackFormat(sAttackLine)
	local sAtk, sFullAtk = "", "";
	local bAnd, bOr, bFull, bMult = false, false, false, false;

	if sAttackLine:match(",") then
		bAnd = true;
		sAtk, sFullAtk = ImportNPCManager.importHelperAttackFormatAnd(sAttackLine, sAtk, sFullAtk);
	end
	if sAttackLine:match("%sor%s") then
		bOr = true;
		sAtk, sFullAtk = ImportNPCManager.importHelperAttackFormatOr(sAttackLine, sAtk, sFullAtk);
	end
	if sAttackLine:match("/%+") then
		bFull = true;
	end
	if sAttackLine:match("^%d+") then
		bMult = true;
	end
	
	if (bFull or bMult) and not (bAnd or bOr) then
		sAtk = sAttackLine;
		sFullAtk = sAttackLine;
	elseif not (bAnd or bOr or bFull or bMult) then
		sAtk = sAttackLine;
	end

	return sAtk, sFullAtk;
end

function importHelperAttackFormatAnd(sAttackLine, sAtk, sFullAtk)
	sAtk = StringManager.splitByPattern(sAttackLine, ",")[1];
	sFullAtk = sAttackLine;

	return sAtk, sFullAtk;
end

function importHelperAttackFormatOr(sAttackLine, sAtk, sFullAtk)
	for _,vAttack in ipairs(StringManager.splitByPattern(sAttackLine, "%sor%s")) do
		-- iterative full-attack "+12/+7/+2"
		if vAttack:match("/%+") then
			sFullAtk = ImportNPCManager.importHelperAttackOrCheck(sFullAtk, vAttack);
			sAtk = ImportNPCManager.importHelperAttackOrCheck(sAtk, vAttack:gsub("/.-%(", " ("));
		-- multiple single attacks "8 tentacles"
		elseif vAttack:match("^%d+") then
			sFullAtk = ImportNPCManager.importHelperAttackOrCheck(sFullAtk, vAttack);
			-- Convert "2 Slams" into Slam for single attacks
			sAtk = ImportNPCManager.importHelperAttackOrCheck(sAtk, vAttack:gsub("^%d+%s(%a+)s", "%1"));
		-- single attack
		else
			sAtk = ImportNPCManager.importHelperAttackOrCheck(sAtk, vAttack);
		end
		if vAttack:match(",") then
			sAtk = sAtk:gsub(",.-%)", "");
		end
	end

	return sAtk, sFullAtk;
end

function importHelperAttackOrCheck(sSource, sNew)
	if sSource == sNew then
		return sSource;
	end

	if sSource ~= "" then
		sSource = sSource .. " or " .. sNew;
	else
		sSource = sNew;
	end

	return sSource;
end

function importHelperSpaceReach()
	ImportNPCManager.nextImportLine();

	local sSpaceReach = "5 ft./5 ft.";
	local sLine = _tImportState.sActiveLine;
	sLine = sLine:gsub(",", ";");
	if sLine:match("Space") and sLine:match(";") then
		local tSegments = StringManager.splitByPattern(sLine, ";");

		local sSpace = tSegments[1]:match("%d+.*");
		local sReach = tSegments[2]:match("%d+.*");
		sSpaceReach = sSpace .. "/" .. sReach;
	elseif not sLine:match("Space") then
		ImportNPCManager.previousImportLine();
	end

	DB.setValue(_tImportState.node, "spacereach", "string", sSpaceReach);
end

function importHelperSpells()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	if sLine:match("Spell") then
		ImportNPCManager.importHelperSpellcasting();
	else
		ImportNPCManager.previousImportLine();
	end
end

function getLoadedModules()
	local tLoadedModules = {};
	local tAllModules = Module.getModules();

	for _,sModuleName in ipairs(tAllModules) do
		local tModuleData = Module.getModuleInfo(sModuleName);
		if tModuleData.loaded then
			tLoadedModules[#tLoadedModules+1] = tModuleData.name;
		end
	end

	return tLoadedModules;
end

function importHelperSpellcasting()
	local nodeSpellClass = _tImportState.node.createChild("spellset").createChild();
	local bSpellLike = false;
	
	DB.setValue(nodeSpellClass, "label", "string", _tImportState.sActiveLine:gsub("%s?%b()", ""));
	DB.setValue(nodeSpellClass, "cl", "number", tonumber(_tImportState.sActiveLine:match("CL%s(%d+)")) or 0);
	if _tImportState.sActiveLine:lower():match("known") then
		DB.setValue(nodeSpellClass, "castertype", "string", "spontaneous");
	end
	if _tImportState.sActiveLine:lower():match("spell%-like") then
		bSpellLike = true;
	end

	local tModules = getLoadedModules();
	
	while not _tImportState.sActiveLine:lower():match("^statistics") do
		ImportNPCManager.nextImportLine();
		local sLine = _tImportState.sActiveLine;
		-- get rid of D in domain spells
		sLine = sLine:gsub("(%w)D", "%1");
		sLine = sLine:lower();

		if not sLine or sLine == "" or sLine:match("^statistics") or sLine:match("^tactics") or sLine:match("^str%s") then
			ImportNPCManager.previousImportLine();
			break;
		elseif sLine:match("^spell") then
			ImportNPCManager.previousImportLine();
			ImportNPCManager.importHelperSpells();
			break;
		end

		local nSpellLevel = tonumber(sLine:match("^(%d+)")) or 0;
		local nKnown = tonumber(sLine:match("%((%d)")) or 0;
		local sSpells = sLine:match("-%s?(%w+.*)") or "";
		sSpells = sSpells:gsub("%(dc.-%)", "");
		sSpells = sSpells:gsub("'", "");

		if sSpells:match(",") then
			for _,sSpellName in ipairs(StringManager.splitByPattern(sSpells, ",")) do
				ImportNPCManager.importHelperSearchSpell(nodeSpellClass, tModules, nSpellLevel, sSpellName, nKnown, bSpellLike);
			end
		else
			ImportNPCManager.importHelperSearchSpell(nodeSpellClass, tModules, nSpellLevel, sSpells, nKnown, bSpellLike);
		end
	end
end

function importHelperSearchSpell(nodeSpellClass, tModules, nSpellLevel, sSpellName, nKnown, bSpellLike)
	if sSpellName == "" then
		return;
	end

	local nQuantity = tonumber(sSpellName:match("(%d+)")) or 1;
	
	if bSpellLike then
		nQuantity = nSpellLevel;
		if nQuantity < 1 then
			nQuantity = 1;
		end
	end
	
	sSpellName = sSpellName:gsub("%b()", "");
	if sSpellName:match("^%s?mass") then
		sSpellName = sSpellName:gsub("mass", "");
		sSpellName = sSpellName .. "mass";
	end
	
	local nodeSpellBook = DB.findNode("spelldesc." .. sSpellName:gsub("%s", "") .. '@*');
	if not nodeSpellBook then
		-- Check for the spell without the first word for metamagic
		local sSpellNameMM = sSpellName:gsub("^%s?.-%s", "");
		nodeSpellBook = DB.findNode("spelldesc." .. sSpellNameMM:gsub("%s", "") .. '@*');
	end

	if nodeSpellBook then
		ImportNPCManager.importHelperAddSpell(nodeSpellBook, nodeSpellClass, nSpellLevel, nQuantity, nKnown, bSpellLike);
		return;
	end
	
	for _,sModule in pairs(tModules) do
		local nodeSpellModule = DB.findNode("reference.spells" .. "@" .. sModule);
		if not nodeSpellModule then
			return;
		end
		
		for _,nodeSpell in ipairs(DB.getChildList(nodeSpellModule)) do
			local sModuleSpellName = DB.getValue(nodeSpell, "name", "");
			if sModuleSpellName == "" then
				return;
			end
			if sModuleSpellName == sSpellName then
				ImportNPCManager.importHelperAddSpell(nodeSpell, nodeSpellClass, nSpellLevel, nQuantity, nKnown, bSpellLike);
				break;
			elseif sModuleSpellName == sSpellName:gsub("^%s?.-%s", "") then
				ImportNPCManager.importHelperAddSpell(nodeSpell, nodeSpellClass, nSpellLevel, nQuantity, nKnown, bSpellLike);
				break;
			end
		end
	end
end

function importHelperAddSpell(nodeSpell, nodeSpellClass, nSpellLevel, nQuantity, nKnown, bSpellLike)
	if nKnown > 0 then
		DB.setValue(nodeSpellClass, "availablelevel" .. tostring(nSpellLevel), "number", nKnown);
	else
		local nCurrentQuantity = DB.getValue(nodeSpellClass, "availablelevel" .. tostring(nSpellLevel), 0);
		DB.setValue(nodeSpellClass, "availablelevel" .. tostring(nSpellLevel), "number", nCurrentQuantity + nQuantity);
	end
	
	-- Create data beforehand, otherwise the addSpell() won't work
	nodeSpellClass.createChild("levels.level" .. tostring(nSpellLevel) .. ".spells");

	local nodeNewSpell = SpellManager.addSpell(nodeSpell, nodeSpellClass, nSpellLevel);
	DB.setValue(nodeNewSpell, "prepared", "number", nQuantity);
end

function importHelperAbilityScores()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine:gsub("-", "0");
	sLine = sLine:gsub("—", "0");
	local nStr, nDex, nCon, nInt, nWis, nCha = sLine:match("(%d+).-(%d+).-(%d+).-(%d+).-(%d+).-(%d+)");

	DB.setValue(_tImportState.node, "strength", "number", nStr);
	DB.setValue(_tImportState.node, "dexterity", "number", nDex);
	DB.setValue(_tImportState.node, "constitution", "number", nCon);
	DB.setValue(_tImportState.node, "intelligence", "number", nInt);
	DB.setValue(_tImportState.node, "wisdom", "number", nWis);
	DB.setValue(_tImportState.node, "charisma", "number", nCha);
end

function importHelperBabCmbCmd()
	ImportNPCManager.nextImportLine();

	DB.setValue(_tImportState.node, "babgrp", "string", _tImportState.sActiveLine);
end

function importHelperSQ()
	ImportNPCManager.nextImportLine();
	if _tImportState.sActiveLine:match("^SQ") then
		local sSQ = _tImportState.sActiveLine:gsub("^SQ%s", "");
		ImportNPCManager.importHelperSQjoin(sSQ);
	else
		ImportNPCManager.previousImportLine();
	end
end

function importHelperGear()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	if sLine:match("Gear") then
		local sGear = sLine:gsub("Combat%sGear%s", "");
		sGear = sGear:gsub("Other%sGear%s", "");
		sGear = sGear:gsub("Gear%s", "");
		ImportNPCManager.addStatOutput("<h>Gear</h>");
		ImportNPCManager.addStatOutput(string.format("<p>%s</p>", StringManager.capitalize(sGear)));
	else
		ImportNPCManager.previousImportLine();
	end
end

function importHelperSpecialAbilities()
	ImportNPCManager.nextImportLine();

	if not _tImportState.sActiveLine or _tImportState.sActiveLine == "" then
		return;
	end

	ImportNPCManager.addStatOutput("<h>Special Abilities</h>");

	while _tImportState.sActiveLine:match("%w") do
		ImportNPCManager.nextImportLine();

		local sLine = _tImportState.sActiveLine;

		if not sLine or sLine == "" then
			break;
		end

		if sLine:match("%(Ex%)") or sLine:match("%(Su%)") then
			sLine = sLine:gsub("(.-%(Ex%))", "<b>%1</b>");
			sLine = sLine:gsub("(.-%(Su%))", "<b>%1</b>");
			ImportNPCManager.addStatOutput(string.format("<p>%s</p>", sLine));
		else
			ImportNPCManager.addStatOutput(string.format("<p>%s</p>" ,sLine));
		end
	end
end

--
--	Import state identification and tracking
--

function initImportState(sStatBlock, sDesc)
	_tImportState = {};

	local sCleanStats = ImportUtilityManager.cleanUpText(sStatBlock);
	_tImportState.nLine = 0;
	_tImportState.tLines = ImportUtilityManager.parseFormattedTextToLines(sCleanStats);
	_tImportState.sActiveLine = "";

	_tImportState.sDescription = ImportUtilityManager.cleanUpText(sDesc);
	_tImportState.tStatOutput = {};

	local sRootMapping = LibraryData.getRootMapping("npc");
	_tImportState.node = DB.createChild(sRootMapping);
end

function nextImportLine(nAdvance)
	_tImportState.nLine = _tImportState.nLine + (nAdvance or 1);
	_tImportState.sActiveLine = _tImportState.tLines[_tImportState.nLine];
end

function previousImportLine()
	_tImportState.nLine = _tImportState.nLine - 1;
	_tImportState.sActiveLine = _tImportState.tLines[_tImportState.nLine];
end

function addStatOutput(s)
	table.insert(_tImportState.tStatOutput, s);
end

function finalizeSpellclass()
	local nodeSpellset = DB.getChild(_tImportState.node, "spellset");
	
	if not nodeSpellset then
		return;
	end

	local nInt = DB.getValue(_tImportState.node, "intelligence", 0);
	local nWis = DB.getValue(_tImportState.node, "wisdom", 0);
	local nCha = DB.getValue(_tImportState.node, "charisma", 0);

	local nHighest = math.max(nInt, nWis, nCha);

	local nodeSpellClass = DB.getChild(nodeSpellset, "id-00001");

	if nHighest == nWis then
		DB.setValue(nodeSpellClass, "dc.ability", "string", "wisdom");
	end
	if nHighest == nCha then
		DB.setValue(nodeSpellClass, "dc.ability", "string", "charisma");
	end
	if nHighest == nInt then
		DB.setValue(nodeSpellClass, "dc.ability", "string", "intelligence");
	end
end

function finalizeUppercase()
	DB.setValue(_tImportState.node, "feats", "string", StringManager.capitalizeAll(DB.getValue(_tImportState.node, "feats", "")));
	DB.setValue(_tImportState.node, "skills", "string", StringManager.capitalizeAll(DB.getValue(_tImportState.node, "skills", "")));
	DB.setValue(_tImportState.node, "languages", "string", StringManager.capitalizeAll(DB.getValue(_tImportState.node, "languages", "")));
	DB.setValue(_tImportState.node, "specialqualities", "string", StringManager.capitalize(DB.getValue(_tImportState.node, "specialqualities", "")));
end

function finalizeDescription()
	DB.setValue(_tImportState.node, "text", "formattedtext", _tImportState.sDescription .. table.concat(_tImportState.tStatOutput));
end
