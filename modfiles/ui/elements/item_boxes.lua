item_boxes = {}

--- ** LOCAL UTIL **
local function build_item_box(player, name, column_count)
    local item_boxes_elements = data_util.get("main_elements", player).item_boxes

    local window_frame = item_boxes_elements.horizontal_flow.add{type="frame", direction="vertical",
      style="window_content_frame"}
    window_frame.style.padding = ITEM_BOX_PADDING
    window_frame.style.top_padding = 6

    window_frame.add{type="label", caption={"fp.pu_" .. name, 2}, style="caption_label"}

    local item_frame = window_frame.add{type="frame", style="slot_button_deep_frame"}
    item_frame.style.top_margin = 4
    local scroll_pane = item_frame.add{type="scroll-pane", style="fp_scroll_pane_inside_content_frame_bare"}
    scroll_pane.style.width = column_count * ITEM_BOX_BUTTON_SIZE

    local table_items = scroll_pane.add{type="table", column_count=column_count, style="filter_slot_table"}
    item_boxes_elements[name .. "_item_table"] = table_items
end

local function refresh_item_box(player, name, subfactory, allow_addition)
    local ui_state = data_util.get("ui_state", player)
    local item_boxes_elements = ui_state.main_elements.item_boxes
    local class_name = (name:gsub("^%l", string.upper))

    local table_items = item_boxes_elements[name .. "_item_table"]
    table_items.clear()
    if not subfactory or not subfactory.valid then return 0 end

    local table_item_count = 0
    local default_style = (name == "ingredient") and "flib_slot_button_default" or "flib_slot_button_red"
    local tut_mode_tooltip = (name == "product") and ui_util.generate_tutorial_tooltip(player, "tl_product", true) or ""
    local metadata = view_state.generate_metadata(player, subfactory, 4, true)

    for _, item in ipairs(Subfactory.get_in_order(subfactory, class_name)) do
        local required_amount = (name == "product") and Item.required_amount(item) or nil
        local amount, number_tooltip = view_state.process_item(metadata, item, required_amount, nil)
        if amount == -1 then goto skip_item end  -- an amount of -1 means it was below the margin of error

        local style, satisfaction_line = default_style, ""
        if name == "product" and amount ~= nil and amount ~= "0" then
            local satisfied_percentage = (item.amount / required_amount) * 100
            local percentage_string = ui_util.format_number(satisfied_percentage, 3)
            satisfaction_line = {"fp.newline", {"fp.two_word_title", (percentage_string .. "%"), {"fp.satisfied"}}}

            if satisfied_percentage <= 0 then style = "flib_slot_button_red"
            elseif satisfied_percentage < 100 then style = "flib_slot_button_yellow"
            else style = "flib_slot_button_green" end
        end

        local indication = (item.proto.type == "entity") and {"fp.indication", {"fp.indication_raw_ore"}} or ""
        local name_line = {"fp.two_word_title", item.proto.localised_name, indication}
        local number_line = (number_tooltip) and {"fp.newline", number_tooltip} or ""
        local tooltip = {"", name_line, number_line, satisfaction_line, tut_mode_tooltip}

        table_items.add{type="sprite-button", name="fp_sprite-button_top_level_" .. name .. "_" .. item.id,
          sprite=item.proto.sprite, tooltip=tooltip, number=amount, style=style, mouse_button_filter={"left-and-right"}}
        table_item_count = table_item_count + 1

        ::skip_item::  -- goto for fun, wooohoo
    end

    if allow_addition then  -- meaning allow the user to add items of this type
        local button_add = table_items.add{type="sprite-button", name="fp_sprite-button_add_top_level_" .. name,
          sprite="fp_sprite_plus", tooltip={"fp.two_word_title", {"fp.add"}, {"fp.pl_" .. name, 1}},
          enabled=(not ui_state.flags.archive_open), style="fp_sprite-button_inset_tiny", mouse_button_filter={"left"}}
        button_add.style.padding = 2
        button_add.style.margin = 4
        table_item_count = table_item_count + 1
    end

    local table_rows_required = math.ceil(table_item_count / table_items.column_count)
    return table_rows_required
end


local function handle_item_button_click(player, button, metadata)
    local sstring = split_string(button.name, "_")
    local item_class = sstring[5]:gsub("^%l", string.upper)
    local item_id = sstring[6]

    local context = data_util.get("context", player)
    local subfactory = context.subfactory
    local item = Subfactory.get(subfactory, item_class, item_id)

    if metadata.alt then
        data_util.execute_alt_action(player, "show_item", {item=item.proto, click=metadata.click})

    elseif not ui_util.check_archive_status(player) then
        return

    else  -- individual handlers
        if item_class == "Product" then
            if metadata.direction ~= nil then  -- Shift product in the given direction
                if Subfactory.shift(subfactory, item, metadata.direction) then
                    -- Row count doesn't change, so we can refresh directly
                    refresh_item_box(player, "product", subfactory, true)
                else
                    local direction_string = (metadata.direction == "negative") and {"fp.left"} or {"fp.right"}
                    local message = {"fp.error_list_item_cant_be_shifted", {"fp.pl_product", 1}, direction_string}
                    titlebar.enqueue_message(player, message, "error", 1, true)
                end

            elseif metadata.click == "left" then
                if context.floor.level == 1 then
                    modal_dialog.enter(player, {type="recipe", modal_data={product=item, production_type="produce"}})
                else
                    titlebar.enqueue_message(player, {"fp.error_product_wrong_floor"}, "error", 1, true)
                end

            elseif metadata.click == "right" then
                if metadata.action == "edit" then
                    modal_dialog.enter(player, {type="picker", submit=true, delete=true,
                      modal_data={object=item, item_category="product"}})

                elseif metadata.action == "delete" then
                    Subfactory.remove(subfactory, item)
                    data_util.cleanup_subfactory(player, subfactory, true)
                end
            end
        end
    end
end


-- ** TOP LEVEL **
item_boxes.gui_events = {
    on_gui_click = {
        {
            pattern = "^fp_sprite%-button_add_top_level_[a-z]+$",
            timeout = 20,
            handler = (function(player, element, _)
                local item_category = string.gsub(element.name, "fp_sprite%-button_add_top_level_", "")
                modal_dialog.enter(player, {type="picker", submit=true, modal_data={item_category=item_category}})
            end)
        },
        {
            pattern = "^fp_sprite%-button_top_level_[a-z]+_%d+$",
            timeout = 20,
            handler = (function(player, element, metadata)
                handle_item_button_click(player, element, metadata)
            end)
        }
    }
}

function item_boxes.build(player)
    local main_elements = data_util.get("main_elements", player)
    main_elements.item_boxes = {}

    local parent_flow = main_elements.flows.right_vertical
    local flow_horizontal = parent_flow.add{type="flow", direction="horizontal"}
    flow_horizontal.style.horizontal_spacing = HORIZONTAL_FRAME_SPACING
    main_elements.item_boxes["horizontal_flow"] = flow_horizontal

    local products_per_row = data_util.get("settings", player).products_per_row
    build_item_box(player, "product", products_per_row)
    build_item_box(player, "byproduct", products_per_row)
    build_item_box(player, "ingredient", products_per_row*2)

    item_boxes.refresh(player)
end

function item_boxes.refresh(player)
    local ui_state = data_util.get("ui_state", player)
    local subfactory = ui_state.context.subfactory

    prow_count = refresh_item_box(player, "product", subfactory, true)
    brow_count = refresh_item_box(player, "byproduct", subfactory, false)
    irow_count = refresh_item_box(player, "ingredient", subfactory, false)

    local item_boxes_elements = ui_state.main_elements.item_boxes
    local maxrow_count = math.max(prow_count, math.max(brow_count, irow_count))
    local item_table_height = math.max(maxrow_count, 1) * ITEM_BOX_BUTTON_SIZE

    item_boxes_elements.product_item_table.style.height = item_table_height
    item_boxes_elements.byproduct_item_table.style.height = item_table_height
    item_boxes_elements.ingredient_item_table.style.height = item_table_height
end