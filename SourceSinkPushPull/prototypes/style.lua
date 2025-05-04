-- SSPP by jagoly

local styles = data.raw["gui-style"].default

--------------------------------------------------------------------------------

styles.sspp_stretchable_subheader_frame = { ---@type data.FrameStyleSpecification
    type = "frame_style",
    parent = "subheader_frame",
    horizontally_stretchable = "on",
}

styles.sspp_subheader_caption_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 276,
    minimal_height = 30,
    left_padding = 4,
    font = "heading-2",
}

styles.sspp_tab_content_flow = { ---@type data.VerticalFlowStyleSpecification
    type = "vertical_flow_style",
    parent = "vertical_flow",
    top_margin = -8,
}

--------------------------------------------------------------------------------

styles.sspp_network_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
    type = "scroll_pane_style",
    parent = "deep_scroll_pane",
    left_margin = 8,
    right_margin = 8,
    bottom_margin = 4,
    padding = 0,
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0,
    },
    height = 36 * 15 + 36,
}

styles.sspp_station_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
    type = "scroll_pane_style",
    parent = "deep_scroll_pane",
    left_margin = 8,
    right_margin = 8,
    bottom_margin = 4,
    padding = 0,
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0,
    },
    height = 132 * 4 + 36,
}

styles.sspp_right_flat_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
    type = "scroll_pane_style",
    parent = "deep_scroll_pane",
    margin = 4,
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0,
    },
    vertically_stretchable = "on",
    scrollbars_go_outside = true,
}

styles.sspp_right_grid_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
    type = "scroll_pane_style",
    parent = "sspp_right_flat_scroll_pane",
    background_graphical_set = deep_slot_background_tiling(144, 144),
}

styles.sspp_thin_shallow_frame = { ---@type data.FrameStyleSpecification
    type = "frame_style",
    parent = "shallow_frame",
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 8,
    },
    horizontal_flow_style = {
        type = "horizontal_flow_style",
        horizontal_spacing = 8,
    },
}

--------------------------------------------------------------------------------

styles.sspp_network_class_header = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 12,
    right_padding = 12,
    cell_padding = 4,
    column_widths = {
        { column = 1, width = 128 },
        { column = 2, width = 120 },
        { column = 3, width = 120 },
        { column = 4, width = 120 },
        { column = 5, width = 100 },
        { column = 6, width = 32 },
        { column = 7, width = 80 },
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_network_class_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "sspp_network_class_header",
    width = 764,
    left_padding = 4,
    right_padding = 4,
    odd_row_graphical_set = { position = { 472, 25 }, size = 1 },
}

styles.sspp_network_item_header = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 12,
    right_padding = 12,
    cell_padding = 4,
    column_widths = {
        { column = 1, width = 128 },
        { column = 2, width = 120 },
        { column = 3, width = 120 },
        { column = 4, width = 120 },
        { column = 5, width = 32 },
        { column = 6, width = 60 },
        { column = 7, width = 32 },
        { column = 8, width = 80 },
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_network_item_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "sspp_network_item_header",
    width = 764,
    left_padding = 4,
    right_padding = 4,
    odd_row_graphical_set = { position = { 472, 25 }, size = 1 },
}

styles.sspp_network_job_header = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 12,
    right_padding = 12,
    cell_padding = 4,
    column_widths = {
        { column = 1, width = 128 },
        { column = 2, width = 272 },
        { column = 3, width = 100 },
        { column = 4, width = 224 },
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_network_job_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "sspp_network_job_header",
    width = 764,
    left_padding = 4,
    right_padding = 4,
    top_cell_padding = 5,
    bottom_cell_padding = 5,
    odd_row_graphical_set = { position = { 472, 25 }, size = 1 },
}

styles.sspp_network_job_inverted_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "sspp_network_job_header",
    width = 764,
    left_padding = 4,
    right_padding = 4,
    top_cell_padding = 5,
    bottom_cell_padding = 5,
    even_row_graphical_set = { position = { 472, 25 }, size = 1 },
}

styles.sspp_station_item_header = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 14,
    right_padding = 14,
    left_cell_padding = 8,
    right_cell_padding = 8,
    top_cell_padding = 4,
    bottom_cell_padding = 4,
    column_widths = {
        { column = 1, width = 32 - 4 },
        { column = 2, width = 80 },
        { column = 3, width = 220 },
        { column = 4, width = 220 },
        { column = 5, width = 220 },
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_station_item_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "sspp_station_item_header",
    width = 860,
    left_padding = 6,
    right_padding = 6,
    top_cell_padding = 6,
    bottom_cell_padding = 6,
    odd_row_graphical_set = { position = { 472, 25 }, size = 1 },
}

styles.sspp_grid_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    width = 144 * 3,
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

--------------------------------------------------------------------------------

styles.sspp_vertical_warning_image = { ---@type data.ImageStyleSpecification
    type = "image_style",
    parent = "image",
    size = 24,
    left_margin = 4,
    right_margin = 4,
    stretch_image_to_widget_size = true,
}

styles.sspp_move_sprite_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "list_box_item",
    width = 32,
    height = 14,
    padding = 0,
    invert_colors_of_picture_when_hovered_or_toggled = true,
}

styles.sspp_item_mode_sprite_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "control_settings_section_button",
    width = 18,
    padding = 0,
    left_margin = -4,
}

styles.sspp_compact_slot_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "slot_button",
    size = 32,
    top_margin = -2,
    bottom_margin = -2,
}

styles.sspp_compact_sprite_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "sspp_compact_slot_button",
    padding = 4,
    invert_colors_of_picture_when_hovered_or_toggled = true,
}

styles.sspp_compact_warning_image = { ---@type data.ImageStyleSpecification
    type = "image_style",
    parent = "image",
    size = 24,
    right_margin = -4,
    top_margin = 2,
    bottom_margin = 2,
    stretch_image_to_widget_size = true,
}

styles.sspp_job_buttons_flow = { ---@type data.HorizontalFlowStyleSpecification
    type = "horizontal_flow_style",
    left_padding = 6,
    horizontal_spacing = 10,
    vertical_align = "center",
}

styles.sspp_job_slot_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "slot_button",
    size = 48,
}

styles.sspp_job_sprite_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "slot_button",
    size = 32,
    padding = 4,
    invert_colors_of_picture_when_hovered_or_toggled = true,
}

styles.sspp_job_cell_flow = { ---@type data.VerticalFlowStyleSpecification
    type = "vertical_flow_style",
    vertical_spacing = 2,
    height = 20 * 4 + 2 * 3,
    vertical_align = "center",
}

styles.sspp_job_action_label = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "label",
    maximal_width = 274 - 8,
}

styles.sspp_job_action_flow = { ---@type data.HorizontalFlowStyleSpecification
    type = "horizontal_flow_style",
    parent = "packed_horizontal_flow",
    width = 432,
    height = 28,
    vertical_align = "center",
    left_padding = 8,
    right_padding = 8,
}

styles.sspp_station_cell_flow = { ---@type data.VerticalFlowStyleSpecification
    type = "vertical_flow_style",
    parent = "packed_vertical_flow",
    width = 220,
    height = 30 * 4,
    vertical_align = "center",
}

styles.sspp_station_property_flow = { ---@type data.HorizontalFlowStyleSpecification
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    height = 30,
    vertical_align = "center",
}

styles.sspp_station_limit_value = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "label",
    width = 16,
    right_margin = 4,
    horizontal_align = "right",
}

styles.sspp_header_filter_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 104,
    top_margin = -4,
    bottom_margin = -4,
}

styles.sspp_name_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 100,
    horizontal_align = "left",
}

styles.sspp_number_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 100,
    horizontal_align = "right",
}

styles.sspp_wide_name_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 120,
    horizontal_align = "left",
}

styles.sspp_wide_number_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 120,
    horizontal_align = "right",
}

styles.sspp_json_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 200,
    margin = 8,
    rich_text_setting = "disabled",
}

styles.sspp_aligned_switch = { ---@type data.SwitchStyleSpecification
    type = "switch_style",
    parent = "switch",
    horizontal_align = "center",
    vertical_align = "center",
}

styles.sspp_minimap = { ---@type data.MinimapStyleSpecification
    type = "minimap_style",
    size = 128,
}

styles.sspp_camera = { ---@type data.CameraStyleSpecification
    type = "camera_style",
    size = 128,
}

styles.sspp_dead_entity_image = { ---@type data.ImageStyleSpecification
    type = "image_style",
    size = 128,
    padding = 48,
    stretch_image_to_widget_size = true,
}

styles.sspp_minimap_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "locomotive_minimap_button",
    size = 128,
    -- doesn't match vanilla style, but makes text more readable
    hovered_graphical_set = { position = { 8, 8 }, size = 1, opacity = 0.7 },
    clicked_graphical_set = { position = { 42, 8 }, size = 1, opacity = 0.7 },
    default_graphical_set = {},
}

styles.sspp_minimap_top_label = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "semibold_label",
    size = 128,
    padding = 4,
    horizontal_align = "left",
    vertical_align = "top",
}

styles.sspp_minimap_bottom_label = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "semibold_label",
    size = 128,
    padding = 4,
    horizontal_align = "right",
    vertical_align = "bottom",
}

styles.sspp_minimap_subtitle_label = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "bold_label",
    width = 128,
    padding = 4,
    horizontal_align = "center",
}

styles.sspp_frame_tool_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "frame_button",
    font = "heading-2",
    default_font_color = { 0.9, 0.9, 0.9 },
    minimal_width = 80,
    height = 24,
    right_padding = 6,
    left_padding = 6,
}

styles.sspp_hauler_frame = { ---@type data.FrameStyleSpecification
    type = "frame_style",
    parent = "frame",
    width = 244,
    height = 108,
    padding = 4,
}
