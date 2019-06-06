ui_util = {
    view_state = {}
}

-- Readjusts the size of the main dialog according to the user setting of number of items per row
function ui_util.recalculate_main_dialog_dimensions(player)
    local player_table = global.players[player.index]
    local width = 880 + ((player_table.settings.items_per_row - 4) * 175)
    player_table.main_dialog_dimensions.width = width
end


-- Sets the font color of the given label / button-label
function ui_util.set_label_color(ui_element, color)
    if color == "red" then
        ui_element.style.font_color = {r = 1, g = 0.2, b = 0.2}
    elseif color == "dark_red" then
        ui_element.style.font_color = {r = 0.8, g = 0, b = 0}
    elseif color == "yellow" then
        ui_element.style.font_color = {r = 0.8, g = 0.8, b = 0}
    elseif color == "white" or color == "default_label" then
        ui_element.style.font_color = {r = 1, g = 1, b = 1}
    elseif color == "black" or color == "default_button" then
        ui_element.style.font_color = {r = 0, g = 0, b = 0}
    end
end


-- Returns the type of the given prototype (item/fluid)
function ui_util.get_prototype_type(proto)
    local index = global.all_items.index
    if index[proto.name] ~= "dupe" then
        return index[proto.name]
    else
        -- Fall-back to the slow (and awful) method if the name describes both an item and fluid
        if pcall(function () local a = proto.type end) then return "item"
        else return "fluid" end
    end
end

-- Returns the sprite string of the given item
function ui_util.get_item_sprite(player, item)
    return (ui_util.get_prototype_type(item) .. "/" .. item.name)
end

-- Returns the sprite string of the given recipe
function ui_util.get_recipe_sprite(player, recipe)
    local sprite = "recipe/" .. recipe.name
    if recipe.name == "fp-space-science-pack" then
        sprite = "item/space-science-pack"
    elseif string.find(recipe.name, "^impostor%-[a-z0-9-_]+$") then
        sprite = recipe.type .. "/" .. recipe.name:gsub("impostor%-", "")

        -- If the mining recipe has no sprite, the sprite of the first product is used instead
        if not player.gui.is_valid_sprite_path(sprite) then
            local product = recipe.products[1]
            sprite = product.type .. "/" .. product.name
        end
    end
    return sprite
end


-- Formats given number to given number of significant digits
function ui_util.format_number(number, precision)
    return ("%." .. precision .. "g"):format(number)
end

-- Returns string representing the given timescale (Currently only needs to handle 1 second/minute/hour)
function ui_util.format_timescale(timescale)
    if timescale == 1 then
        return "1s"
    elseif timescale == 60 then
        return "1m"
    elseif timescale == 3600 then
        return "1h"
    end
end

-- Returns string representing the given power 
function ui_util.format_energy_consumption(energy_consumption, precision)
    local scale = {"W", "kW", "MW", "GW", "TW", "PW", "EW", "ZW", "YW"}
    local scale_counter = 1

    while scale_counter < #scale and energy_consumption >= 1000 do
        energy_consumption = energy_consumption / 1000
        scale_counter = scale_counter + 1
    end

    return (ui_util.format_number(energy_consumption, precision) .. " " .. scale[scale_counter])
end


-- Sorts a table by string-key using an iterator
function ui_util.pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

-- Splits given string
function ui_util.split(s, separator)
    local r = {}
    for token in string.gmatch(s, "[^" .. separator .. "]+") do
        if tonumber(token) ~= nil then
            token = tonumber(token)
        end
        table.insert(r, token) 
    end
    return r
end


-- Refreshes the current view state
function ui_util.view_state.refresh(player_table, keep_selection)
    local subfactory = player_table.context.subfactory
    if subfactory ~= nil then
        local timescale = ui_util.format_timescale(subfactory.timescale):gsub("1", "")
        local view_state = {
            [1] = {
                name = "items_per_timescale",
                caption = {"", {"button-text.items"}, "/", timescale},
                enabled = true,
                selected = true
            },
            [2] = {
                name = "belts_or_lanes",
                caption = (player_table.settings.belts_or_lanes == "Belts") 
                  and {"button-text.belts"} or {"button-text.lanes"},
                enabled = true,
                selected = false
            },
            [3] = {
                name = "items_per_second",
                caption = {"", {"button-text.items"}, "/s"},
                enabled = (timescale ~= "s"),
                selected = false
            }
        }

        if keep_selection then  -- conserves the selection state from the previous view_state
            local id_to_select = nil

            for i, view in ipairs(player_table.view_state) do
                if view.selected then
                    id_to_select = i
                else
                    view_state[i].selected = false            
                end
            end

            ui_util.view_state.correct(view_state, id_to_select)
        end

        player_table.view_state = view_state
    end
end

-- Sets the current view to the given view (If no view if provided, it sets it to the next enabled one)
function ui_util.view_state.change(player_table, view_name)
    -- Create view state if non exists yet
    if player_table.view_state == nil then ui_util.view_state.refresh(player_table) end

    if player_table.view_state ~= nil then
        local id_to_select = nil
        for i, view in ipairs(player_table.view_state) do
            -- Move selection on by one if no view_name is provided
            if view_name == nil and view.selected then
                view.selected = false
                id_to_select = (i % #player_table.view_state) + 1
                break

            -- Otherwise, select the given view
            else
                if view.name == view_name then
                    id_to_select = i
                else
                    view.selected = false            
                end
            end
        end

        ui_util.view_state.correct(player_table.view_state, id_to_select)
    end
end

-- Moves on the selection until it is on an enabled state (at least 1 view needs to be enabled)
function ui_util.view_state.correct(view_state, id_to_select)
    while true do
        view = view_state[id_to_select]
        if view.enabled then
            view.selected = true
            break
        else
            id_to_select = (id_to_select % #view_state) + 1
        end
    end
end

-- Returns the name of the currently selected view
function ui_util.view_state.selected_state(player_table)
    for i, view in ipairs(player_table.view_state) do
        if view.selected then return view end
    end
end