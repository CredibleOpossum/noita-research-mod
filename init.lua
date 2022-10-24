local EZWand = dofile_once("mods/noita-research-mod/lib/EZWand.lua")
local json = dofile_once("mods/noita-research-mod/lib/json.lua")

local function get_player() return EntityGetWithTag("player_unit")[1] end

function IsWand(id) return EntityHasTag(id, "wand") end

function GetPlayerEntity()
    local players = EntityGetWithTag("player_unit")
    if #players == 0 then return end

    return players[1]
end

function GetHeldItemId()
    local inventory_conponent = EntityGetFirstComponentIncludingDisabled(
                                    GetPlayerEntity(), "Inventory2Component")
    local item_id = ComponentGetValue2(inventory_conponent, "mActiveItem")
    return item_id
end
function PriorityInit()
    SaveSlotID = 1
    DeleteStage = 0
    local possible_save = ModSettingGet("research_mod.save")
    if possible_save ~= nil then
        Saves = json.parse(ModSettingGet("research_mod.save"))
    else
        Saves = {}
    end
end

PriorityInit()
function OnWorldInitialized()
    print(ModSettingGet("research_mod.save"))
    title = GuiCreate()
    loadout_arrows = GuiCreate()
    image = GuiCreate()
    gui = GuiCreate()
    gui2 = GuiCreate()
end

function ChangeSaveSlotId(num)
    SaveSlotID = math.max(1, math.min(SaveSlotID + num, 20))
end

function OnWorldPostUpdate()
    local x, y = EntityGetTransform(get_player())
    local biome = BiomeMapGetName(x, y)
    local draw_ui = GameGetGameEffect(get_player(), "EDIT_WANDS_EVERYWHERE") ~=
                        0 or biome == "$biome_holymountain"
    local draw_ui = draw_ui and not GameIsInventoryOpen()
    if draw_ui then
        local id = 1
        local function new_id()
            id = id + 1
            return id
        end
        ------------------------------------------------------------------------------------------------------------------
        GuiLayoutBeginHorizontal(title, 2.5, 20)
        GuiStartFrame(title)
        GuiText(title, 0, 0, tostring(SaveSlotID))
        GuiLayoutEnd(title)
        ------------------------------------------------------------------------------------------------------------------
        GuiLayoutBeginHorizontal(loadout_arrows, 2.5, 22)
        GuiStartFrame(loadout_arrows)
        if GuiButton(loadout_arrows, new_id(), 0, 0, "<-") then
            ChangeSaveSlotId(-1)
        end
        if GuiButton(loadout_arrows, new_id(), 0, 0, "->") then
            ChangeSaveSlotId(1)
        end
        GuiLayoutEnd(loadout_arrows)
        ------------------------------------------------------------------------------------------------------------------
        GuiLayoutBeginHorizontal(gui, 2.5, 25)
        GuiStartFrame(gui)
        if Saves[tostring(SaveSlotID)] ~= nil then

            GuiLayoutBeginHorizontal(image, 2.5, 22)
            GuiStartFrame(image)
            wand_image =
                EZWand.Deserialize(Saves[tostring(SaveSlotID)])["sprite_image_file"]
            GuiImage(image, new_id(), 10, 20, wand_image, 1, 3.5, 3.5)
            GuiLayoutEnd(image)

            if GuiButton(gui, new_id(), 0, 0, "Spawn") then
                button_pressed("spawn")
            end
            if GuiButton(gui, new_id(), 5, 0, "Delete") then
                button_pressed("delete")
            end

        else
            if GuiButton(gui, new_id(), 0, 0, "Research") then
                button_pressed("research")
            end
        end
        GuiLayoutEnd(gui)
        ------------------------------------------------------------------------------------------------------------------
        local item_held = GetHeldItemId()
        if IsWand(item_held) then -- Only wands supported so far, planned to include items
            if PreviousHeldItem ~= item_held then
                wand_price = evaluate_wand_price(
                                 EZWand.Deserialize(EZWand(item_held):Serialize()))
                -- Only recalculate the price every time a different wand is held to better performance
            else
                wand_price = PreviousWandPrice
            end

            GuiLayoutBeginHorizontal(gui2, 5, 10)
            GuiStartFrame(gui2)
            GuiText(gui2, 0, 0, "held wand price is: " .. wand_price .. "$")
            GuiLayoutEnd(gui2)

            PreviousHeldItem = item_held
            PreviousWandPrice = wand_price
        end
        ------------------------------------------------------------------------------------------------------------------
    end
end

function button_pressed(action)

    if action == "research" then
        if not IsWand(GetHeldItemId()) then return end
        local x, y = EntityGetTransform(get_player())
        local wand_to_research = EZWand.GetHeldWand():Serialize()
        local price = evaluate_wand_price(EZWand.Deserialize(wand_to_research))

        local player = get_player()
        local wallet = EntityGetFirstComponent(player, "WalletComponent")
        local money = ComponentGetValueInt(wallet, "money")

        if money >= price then
            money = money - price
            ComponentSetValue2(wallet, "money", money)

            Saves[tostring(SaveSlotID)] = wand_to_research
            ModSettingSet("research_mod.save", json.stringify(Saves))
        else
            GamePrint("You don't have enough money to research this wand!")
        end

    elseif action == "spawn" then
        if Saves[tostring(SaveSlotID)] ~= nil then
            local wand_props = EZWand.Deserialize(Saves[tostring(SaveSlotID)])
            local x, y = EntityGetTransform(get_player())
            EZWand(Saves[tostring(SaveSlotID)], x, y)
        end

    elseif action == "delete" then
        Saves[tostring(SaveSlotID)] = nil
        ModSettingSet("research_mod.save", json.stringify(Saves))
    end

end

function OnPlayerSpawned(player_entity) -- This runs when player entity has been created
    print("Research mod loaded!")
end

function evaluate_wand_price(wand_data)
    local price = 0
    price = price + #wand_data["spells"] * 500
    price = price + math.max(wand_data["props"]["spellsPerCast"] - 1, 0) * 500;
    price =
        price + (0.01 ^ (wand_data["props"]["castDelay"] / 60 - 1.8) + 200) *
            0.1;
    price = price +
                (0.01 ^ (wand_data["props"]["rechargeTime"] / 60 - 1.8) + 200) *
                0.1;
    price = price + wand_data["props"]["manaMax"];
    price = price + wand_data["props"]["manaChargeSpeed"] * 2;
    price = price + math.max(wand_data["props"]["capacity"] - 1, 0) * 50;

    price = price * ModSettingGet("research_mod.cost_multiplier")

    return math.ceil(price / 10) * 10
end
