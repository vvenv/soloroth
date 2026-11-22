local AL = AceLibrary("AceLocale-2.2"):new("AtlasLoot");

local ORANGE = "|cffFF8400";

function AtlasLootWorldEventMenu()
	for i = 1, 30, 1 do
		getglobal("AtlasLootItem_"..i):Hide();
	end
	for i = 1, 30, 1 do
		getglobal("AtlasLootMenuItem_"..i):Hide();
		getglobal("AtlasLootMenuItem_"..i).isheader = false;
	end
	getglobal("AtlasLootItemsFrame_NEXT"):Hide();
	getglobal("AtlasLootItemsFrame_PREV"):Hide();
	getglobal("AtlasLootItemsFrame_BACK"):Hide();
	getglobal("AtlasLootServerQueryButton"):Hide();
	--Elemental Invasion
	AtlasLootMenuItem_2_Name:SetText(AL["Elemental Invasion"]);
	AtlasLootMenuItem_2_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_2_Icon:SetTexture("Interface\\Icons\\INV_Ammo_FireTar");
	AtlasLootMenuItem_2.lootpage="ElementalInvasion";
	AtlasLootMenuItem_2:Show();
	--Children's Week
	AtlasLootMenuItem_17_Name:SetText(AL["Children's Week"]);
	AtlasLootMenuItem_17_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_17_Icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall");
	AtlasLootMenuItem_17.lootpage="ChildrensWeek";
	AtlasLootMenuItem_17:Show();
	--Feast of Winter Veil
	AtlasLootMenuItem_18_Name:SetText(AL["Feast of Winter Veil"]);
	AtlasLootMenuItem_18_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_18_Icon:SetTexture("Interface\\Icons\\INV_Holiday_Christmas_Present_01");
	AtlasLootMenuItem_18.lootpage="Winterviel1";
	AtlasLootMenuItem_18:Show();
	--Hallow's End
	AtlasLootMenuItem_19_Name:SetText(AL["Hallow's End"]);
	AtlasLootMenuItem_19_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_19_Icon:SetTexture("Interface\\Icons\\INV_Misc_Food_59");
	AtlasLootMenuItem_19.lootpage="Halloween1";
	AtlasLootMenuItem_19:Show();
	--Harvest Festival
	AtlasLootMenuItem_3_Name:SetText(AL["Harvest Festival"]);
	AtlasLootMenuItem_3_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_3_Icon:SetTexture("Interface\\Icons\\INV_Misc_Food_Wheat_01");
	AtlasLootMenuItem_3.lootpage="HarvestFestival";
	AtlasLootMenuItem_3:Show();
	--Love is in the Air
	AtlasLootMenuItem_20_Name:SetText(AL["Love is in the Air"]);
	AtlasLootMenuItem_20_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_20_Icon:SetTexture("Interface\\Icons\\INV_ValentinesBoxOfChocolates02");
	AtlasLootMenuItem_20.lootpage="Valentineday";
	AtlasLootMenuItem_20:Show();
	--Lunar Festival
	AtlasLootMenuItem_4_Name:SetText(AL["Lunar Festival"]);
	AtlasLootMenuItem_4_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_4_Icon:SetTexture("Interface\\Icons\\INV_Misc_ElvenCoins");
	AtlasLootMenuItem_4.lootpage="LunarFestival1";
	AtlasLootMenuItem_4:Show();
	--Midsummer Fire Festival
	AtlasLootMenuItem_21_Name:SetText(AL["Midsummer Fire Festival"]);
	AtlasLootMenuItem_21_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_21_Icon:SetTexture("Interface\\Icons\\INV_SummerFest_FireFlower");
	AtlasLootMenuItem_21.lootpage="MidsummerFestival";
	AtlasLootMenuItem_21:Show();
	--Noblegarden
	AtlasLootMenuItem_5_Name:SetText(AL["Noblegarden"]);
	AtlasLootMenuItem_5_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_5_Icon:SetTexture("Interface\\Icons\\INV_Egg_03");
	AtlasLootMenuItem_5.lootpage="Noblegarden";
	AtlasLootMenuItem_5:Show();
	--Scourge Invasion
	AtlasLootMenuItem_22_Name:SetText(AL["Scourge Invasion"]);
	AtlasLootMenuItem_22_Extra:SetText(ORANGE..AL["Various Locations"]);
	AtlasLootMenuItem_22_Icon:SetTexture("Interface\\Icons\\INV_Jewelry_Talisman_13");
	AtlasLootMenuItem_22.lootpage="ScourgeInvasionEvent1";
	AtlasLootMenuItem_22:Show();
	--Stranglethorn Fishing Extravaganza
	AtlasLootMenuItem_6_Name:SetText(AL["Stranglethorn Fishing Extravaganza"]);
	AtlasLootMenuItem_6_Extra:SetText(ORANGE..AL["Stranglethorn Vale"]);
	AtlasLootMenuItem_6_Icon:SetTexture("Interface\\Icons\\INV_Fishingpole_01");
	AtlasLootMenuItem_6.lootpage="FishingExtravaganza";
	AtlasLootMenuItem_6:Show();
	for i = 1, 30, 1 do
		getglobal("AtlasLootMenuItem_"..i.."_Extra"):Show();
	end
	AtlasLoot_BossName:SetText("|cffFFFFFF"..AL["World Events"]);
	AtlasLoot_SetItemInfoFrame(AtlasLoot_AnchorFrame);
end
