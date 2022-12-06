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
	-- Assume Alignment/Size/Type next
	ImportNPCManager.importHelperAlignmentSizeType();
	-- Assume Initiative/Senses next
	ImportNPCManager.importHelperInitiativeSenses();
	-- Assume Aura next (optional)
	ImportNPCManager.importHelperSimpleLine("aura");

	-- DEFENSE
	-- Assume Defense next
	ImportNPCManager.importHelperACHP();
	ImportNPCManager.importHelperSaves();
	ImportNPCManager.importHelperDefOptional();

	-- OFFENSE
	ImportNPCManager.nextImportLine();
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
	ImportNPCManager.nextImportLine();
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
	-- Update Description by adding the statblock text as well
	ImportNPCManager.finalizeDescription();
	-- Open new record window and matching campaign list
	ImportUtilityManager.showRecord("npc", _tImportState.node);
end

--
--	Import section helper functions
--

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
	-- skip possible XP and Source lines
	if _tImportState.sActiveLine:match("^Source") then
		ImportNPCManager.nextImportLine();
	end
	if _tImportState.sActiveLine:match("^XP") then
		ImportNPCManager.nextImportLine();
	end

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
	ImportNPCManager.nextImportLine(2);

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
		DB.setValue(_tImportState.node, "specialqualities", "string", sRegeneration);
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

	DB.setValue(_tImportState.node, "fortitudesave", "number", nFort);
	DB.setValue(_tImportState.node, "reflexsave", "number", nRef);
	DB.setValue(_tImportState.node, "willsave", "number", nWill);
end

function importHelperDefOptional()
	ImportNPCManager.nextImportLine();

	local sLine = _tImportState.sActiveLine;
	if sLine:lower():match("offense") then
		ImportNPCManager.previousImportLine();
		return;
	end

	local sExistingSQ = DB.getValue(_tImportState.node, "specialqualities", "");
	if sExistingSQ ~= "" then
		sExistingSQ = sExistingSQ .. ", ";
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

	DB.setValue(_tImportState.node, "specialqualities", "string", StringManager.capitalize(sExistingSQ .. sLine));
end

function importHelperTactics()
	ImportNPCManager.nextImportLine();

	if _tImportState.sActiveLine:lower():match("tactics") then
		ImportNPCManager.addStatOutput("<h>Tactics</h>")

		while not _tImportState.sActiveLine:lower():match("statistics") do
			ImportNPCManager.nextImportLine();

			local sLine = _tImportState.sActiveLine;
			if not sLine or sLine == "" or sLine:lower():match("statistics") then
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
	local sMeleeAtk, sMeleeFullAtk = importHelperAttackFormat(sMelee);
	local sRangedAtk = "";
	local sRangedFullAtk = "";

	-- Check for optional ranged attacks
	ImportNPCManager.nextImportLine();

	local sRanged = _tImportState.sActiveLine;
	if sRanged:match("Ranged") then
	 	sRanged = sRanged:gsub("^Ranged%s?", "");
		sRangedAtk, sRangedFullAtk = importHelperAttackFormat(sRanged);
	else
		ImportNPCManager.previousImportLine();
	end

	-- Clenaup Attacks
	sMeleeAtk = sMeleeAtk:gsub("/%+.-%(", " (");
	sMeleeAtk = sMeleeAtk:gsub("^%d+%s(%a+)s", "%1");
	sRangedAtk = sRangedAtk:gsub("/%+.-%(", " (");
	sRangedAtk = sRangedAtk:gsub("(%d+%s)%(", "%1ranged (");
	sMeleeFullAtk = sMeleeFullAtk:gsub(",", " and");
	sRangedFullAtk = sRangedFullAtk:gsub(",", " and");
	sRangedFullAtk = sRangedFullAtk:gsub("(%d+%s)%(", "%1ranged (");

	sMeleeAtk = StringManager.capitalize(sMeleeAtk);
	sMeleeFullAtk = StringManager.capitalize(sMeleeFullAtk);
	sRangedAtk = StringManager.capitalize(sRangedAtk);
	sRangedFullAtk = StringManager.capitalize(sRangedFullAtk);

	-- Merge Attacks
	if sMeleeAtk and sRangedAtk ~= "" then
		DB.setValue(_tImportState.node, "atk", "string", sMeleeAtk .. " or " .. sRangedAtk);
	else
		DB.setValue(_tImportState.node, "atk", "string", sMeleeAtk .. sRangedAtk);
	end

	-- Merge Full Attacks
	if sMeleeFullAtk and sRangedFullAtk ~= "" then
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
		if vAttack:match("/%+") then
			sFullAtk = vAttack;
			sAtk = vAttack:gsub("/.-%(", " (");
		elseif vAttack:match("^%d+") then
			sFullAtk = ImportNPCManager.importHelperAttackOrCheck(sFullAtk, vAttack);
			-- Convert "2 Slams" into Slam for single attacks
			local sAtkSingle = vAttack:gsub("^%d+%s(%a+)s", "%1");
			sAtk = ImportNPCManager.importHelperAttackOrCheck(sAtk, sAtkSingle);
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
	if sLine:match("Spell") or sLine:match("At Will") or sLine:match("Constant") then
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
	local nodeNewSpellClass = _tImportState.node.createChild("spellset").createChild();
	local nCL = tonumber(_tImportState.sActiveLine:match("CL%s(%d+)")) or 0;
	
	DB.setValue(nodeNewSpellClass, "label", "string", _tImportState.sActiveLine:gsub("%s?%b()", ""));
	DB.setValue(nodeNewSpellClass, "cl", "number", nCL);

	local tModules = getLoadedModules();
	
	while not _tImportState.sActiveLine:lower():match("statistics") do
		ImportNPCManager.nextImportLine();
		local sLine = _tImportState.sActiveLine:lower();
		if not sLine or sLine == "" or sLine:match("statistics") then
			ImportNPCManager.previousImportLine();
			break;
		elseif sLine:match("^spell") then
			ImportNPCManager.previousImportLine();
			ImportNPCManager.importHelperSpells();
			break;
		end

		local nSpellLevel = sLine:match("%d+") or 0;
		local sSpells = sLine:match("-(%w+.*)");
		if sSpells:match(",") then
			for _,sSpellName in ipairs(StringManager.splitByPattern(sSpells, ",")) do
				ImportNPCManager.importHelperSearchSpell(nodeNewSpellClass, tModules, nSpellLevel, sSpellName);
			end
		else
			ImportNPCManager.importHelperSearchSpell(nodeNewSpellClass, tModules, nSpellLevel, sSpells);
		end
	end
end

function importHelperSearchSpell(nodeSpellClass, tModules, nSpellLevel, sSpellName)
	local nDC = tonumber(sSpellName:match("dc%s(%d+)"));
	sSpellName = sSpellName:gsub("%(dc.*%)", "");
	local nQuantity = tonumber(sSpellName:match("(%d+)")) or 1;
	sSpellName = sSpellName:gsub("%b()", "");
	
	local nodeSpellBook = DB.findNode("spelldesc." .. sSpellName:gsub("%s", "") .. '@*');
	if nodeSpellBook then
		ImportNPCManager.importHelperAddSpell(nodeSpellBook, nodeSpellClass, nSpellLevel, nQuantity);
		return;
	end

	for _,sModule in pairs(tModules) do
		local nodeSpellModule = DB.findNode("reference.spells" .. "@" .. sModule);
		if nodeSpellModule then
			for _,nodeSpell in pairs(nodeSpellModule.getChildren()) do
				local sModuleSpellName = DB.getValue(nodeSpell, "name", "");
				if sModuleSpellName ~= '' then
					if sModuleSpellName == sSpellName then
						ImportNPCManager.importHelperAddSpell(nodeSpell, nodeSpellClass, nSpellLevel, nQuantity);
						break;
					end
				end
			end
		end
	end
end

function importHelperAddSpell(nodeSpell, nodeSpellClass, nSpellLevel, nQuantity)
	local nCurrentQuantity = DB.getValue(nodeSpellClass, "availablelevel" .. nSpellLevel, 0);
	DB.setValue(nodeSpellClass, "availablelevel" .. nSpellLevel, "number", nCurrentQuantity + nQuantity);

	SpellManager.addSpell(nodeSpell, nodeSpellClass, nSpellLevel);
end

function importHelperAbilityScores()
	-- skip STATISTICS
	ImportNPCManager.nextImportLine(2);

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
		local sExistingSQ = DB.getValue(_tImportState.node, "specialqualities", "");
		if sExistingSQ ~= "" then
			sSQ = sExistingSQ .. ", " .. sSQ;
		end

		DB.setValue(_tImportState.node, "specialqualities", "string", StringManager.capitalizeAll(sSQ));
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
	local nodeSpellset = _tImportState.node.getChild("spellset");
	
	if not nodeSpellset then
		return;
	end

	local nInt = DB.getValue(_tImportState.node, "intelligence", 0);
	local nWis = DB.getValue(_tImportState.node, "wisdom", 0);
	local nCha = DB.getValue(_tImportState.node, "charisma", 0);

	local nHighest = math.max(nInt, nWis, nCha);

	local nodeSpellClass = nodeSpellset.getChild("id-00001");

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

function finalizeDescription()
	DB.setValue(_tImportState.node, "text", "formattedtext", _tImportState.sDescription .. table.concat(_tImportState.tStatOutput));
end
