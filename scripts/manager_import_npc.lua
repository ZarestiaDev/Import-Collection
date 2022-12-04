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
	ImportNPCManager.importHelperSpecialAttacks();
	-- Assume Spells next (optional)
	ImportNPCManager.importHelperSpells();

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

	local sLine = _tImportState.sActiveLine:lower();
	if sLine:match("^" .. sCategory) then
		local sCategoryLine = sLine:gsub("^" .. sCategory .. "%s", "");
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
	if sLine:match("OFFENSE") then
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
	sMeleeAtk = sMeleeAtk:gsub("/.-%(", " (");
	sMeleeAtk = sMeleeAtk:gsub("^%d+%s(%a+)s", "%1");
	sRangedAtk = sRangedAtk:gsub("/.-%(", " (");
	sRangedAtk = sRangedAtk:gsub("(%d+%s)%(", "%1ranged (");
	sRangedFullAtk = sRangedFullAtk:gsub("(%d+%s)%(", "%1ranged (");

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
	local sAtk = "";
	local sFullAtk = "";

	if sAttackLine:match(",") then
		local tAttacks = StringManager.splitByPattern(sAttackLine, ",");
		sAtk = tAttacks[1];
		sFullAtk = sAttackLine:gsub(",", " and");
	elseif sAttackLine:match("%sor%s") then
		local tAttacks = StringManager.splitByPattern(sAttackLine, "%sor%s");
		for _,vAttack in ipairs(tAttacks) do
			if vAttack:match("/%+") then
				sFullAtk = vAttack;
			else
				sAtk = sAttackLine;
				break;
			end
		end
	else
		if sAttackLine:match("/%+") or sAttackLine:match("^%d+") then
			sFullAtk = sAttackLine;
			sAtk = sAttackLine;
		else
			sAtk = sAttackLine;
		end
	end

	return sAtk, sFullAtk;
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

function importHelperSpecialAttacks()
	ImportNPCManager.nextImportLine();
	
	local sLine = _tImportState.sActiveLine;
	if sLine:match("Special Attacks") then
		sLine = sLine:gsub("Special Attacks%s?", "");
		DB.setValue(_tImportState.node, "specialattacks", "string", StringManager.capitalize(sLine));
	else
		ImportNPCManager.previousImportLine();
	end
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
	local nodeNPC = _tImportState.node;
	local nodeNewSpellClass = nodeNPC.createChild("spellset").createChild();
	
	local nCL = tonumber(_tImportState.sActiveLine:match("CL%s(%d+)"));
	
	DB.setValue(nodeNewSpellClass, "label", "string", "Spells");
	DB.setValue(nodeNewSpellClass, "cl", "number", nCL);

	local tModules = getLoadedModules();
	
	while not _tImportState.sActiveLine:lower():match("statistics") do
		ImportNPCManager.nextImportLine();
		local sLine = _tImportState.sActiveLine:lower();
		if not sLine or sLine == "" or sLine:match("statistics") then
			ImportNPCManager.previousImportLine();
			break;
		end

		local nSpellLevel = sLine:match("%d+");
		local sSpells = sLine:match("-(%w+.*)");
		local tSegments = StringManager.splitByPattern(sSpells, ",");
		for _,sSpellName in ipairs(tSegments) do
			ImportNPCManager.importHelperSearchSpell(nodeNewSpellClass, tModules, nSpellLevel, sSpellName);
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

	local nodeTargetLevelSpells = nodeSpellClass.createChild("levels.level" .. nSpellLevel .. ".spells");
	local nodeNewSpell = nodeTargetLevelSpells.createChild();

	DB.copyNode(nodeSpell, nodeNewSpell);
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

		if sLine:match("%(Ex%)") or sLine:match("%(Su%)") or sLine:lower():match("special%sabilities") then
			sLine = sLine:gsub("Copy link to clipboard%s?", "")
			sLine = StringManager.capitalizeAll(sLine:lower());
			if sLine:match("Special%ssAbilities") then
				ImportNPCManager.addStatOutput(string.format("<h>%s</h>" ,sLine));
			else
				ImportNPCManager.addStatOutput(string.format("<p><b>%s</b></p>", sLine));
			end
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
