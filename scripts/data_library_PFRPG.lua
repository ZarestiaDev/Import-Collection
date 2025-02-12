function onInit()
    aRecordOverrides = {
        ["npc"] = { 
            aDataMap = { "npc", "reference.npcdata" }, 
            aGMListButtons = { "button_npc_byletter", "button_npc_bycr", "button_npc_bytype" },
            aGMEditButtons = { "button_add_npc_import_text", "button_add_npc_import" },
            aCustomFilters = {
                ["CR"] = { sField = "cr", sType = "number", fGetValue = LibraryData35E.getNPCCRValue },
                ["Type"] = { sField = "type", fGetValue = LibraryData35E.getNPCTypeValue },
            },
        };
    };

    LibraryData.overrideRecordTypes(aRecordOverrides);
end
