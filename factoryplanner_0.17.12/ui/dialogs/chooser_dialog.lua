-- Handles populating the chooser dialog
function open_chooser_dialog(flow_modal_dialog)
    local modal_data = get_ui_state(game.get_player(flow_modal_dialog.player_index)).modal_data
    flow_modal_dialog.parent.caption = {"", {"label.choose"}, " ", modal_data.title}

    local label_text = flow_modal_dialog.add{type="label", name="label_chooser_text", caption=modal_data.text}

    local table_chooser = flow_modal_dialog.add{type="table", name="table_chooser_elements", column_count=10}
    table_chooser.style.top_padding = 6
    table_chooser.style.bottom_padding = 10
    table_chooser.style.left_padding = 6
    for _, choice in ipairs(modal_data.choices) do
        table_chooser.add{type="sprite-button", name="fp_sprite-button_chooser_element_" .. choice.name,
          sprite=choice.sprite, tooltip=choice.tooltip, number=choice.number, 
          style="fp_button_icon_large_recipe", mouse_button_filter={"left"}}
    end
end

-- Handles click on an element presented by the chooser
function handle_chooser_element_click(player, element_id)
    _G["apply_chooser_" .. get_ui_state(player).modal_data.reciever_name .. "_choice"](player, element_id)
    exit_modal_dialog(player, "cancel", {})
end