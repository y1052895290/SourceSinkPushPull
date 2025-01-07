-- SSPP by jagoly

local styles = data.raw["gui-style"].default

--------------------------------------------------------------------------------

styles.sspp_stretchable_subheader_frame = { ---@type data.FrameStyleSpecification
    type = "frame_style",
    parent = "subheader_frame",
    horizontally_stretchable = "on",
}

--------------------------------------------------------------------------------

styles.sspp_network_left_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
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
    height = 32 + 36 * 12 + 36,
}

styles.sspp_station_left_scroll_pane = { ---@type data.ScrollPaneStyleSpecification
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
    height = 32 + 102 * 4 + 36,
}

--------------------------------------------------------------------------------

styles.sspp_network_class_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 4,
    right_padding = 4,
    cell_padding = 4,
    column_widths = {
        { column = 1, width = 32 },
        { column = 2, width = 100 },
        { column = 3, width = 100 },
        { column = 4, width = 100 },
        { column = 5, width = 100 },
        { column = 6, width = 100 },
        { column = 7, width = 48 },
    },
    odd_row_graphical_set = {
        filename = "__core__/graphics/gui-new.png",
        position = { 472, 25 },
        size = 1,
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_network_item_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 4,
    right_padding = 4,
    cell_padding = 4,
    column_widths = {
        { column = 1, width = 32 },
        { column = 2, width = 100 },
        { column = 3, width = 100 },
        { column = 4, width = 100 },
        { column = 5, width = 264 },
    },
    odd_row_graphical_set = {
        filename = "__core__/graphics/gui-new.png",
        position = { 472, 25 },
        size = 1,
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
}

styles.sspp_station_item_table = { ---@type data.TableStyleSpecification
    type = "table_style",
    parent = "table",
    left_padding = 6,
    right_padding = 6,
    left_cell_padding = 8,
    right_cell_padding = 8,
    top_cell_padding = 6,
    bottom_cell_padding = 6,
    column_widths = {
        { column = 1, width = 80 },
        { column = 2, width = 200 },
        { column = 3, width = 200 },
        { column = 4, width = 200 },
    },
    odd_row_graphical_set = {
        filename = "__core__/graphics/gui-new.png",
        position = { 472, 25 },
        size = 1,
    },
    horizontal_spacing = 0,
    vertical_spacing = 0,
    horizontal_align = "right",
}

--------------------------------------------------------------------------------

styles.sspp_compact_slot_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "slot_button",
    size = 32,
    top_margin = -2,
    bottom_margin = -2,
}

styles.sspp_station_item_property_flow = { ---@type data.HorizontalFlowStyleSpecification
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    width = 200,
    height = 30,
    horizontal_spacing = 0,
    vertical_align = "center",
}

styles.sspp_station_item_key = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "bold_label",
    width = 100,
    horizontal_align = "left",
}

styles.sspp_station_item_value = { ---@type data.LabelStyleSpecification
    type = "label_style",
    parent = "label",
    width = 100,
    horizontal_align = "right",
}

styles.sspp_station_item_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 100,
    horizontal_align = "right",
}

styles.sspp_aligned_switch = { ---@type data.SwitchStyleSpecification
    type = "switch_style",
    parent = "switch",
    horizontal_align = "center",
    vertical_align = "center",
}

styles.sspp_frame_tool_button = { ---@type data.ButtonStyleSpecification
    type = "button_style",
    parent = "frame_button",
    font = "heading-2",
    default_font_color = { 0.9, 0.9, 0.9 },
    minimal_width = 0,
    height = 24,
    right_padding = 8,
    left_padding = 8,
}

styles.sspp_hauler_frame = { ---@type data.FrameStyleSpecification
    type = "frame_style",
    parent = "frame",
    width = 200,
    height = 76,
    padding = 4,
}

styles.sspp_hauler_textbox = { ---@type data.TextBoxStyleSpecification
    type = "textbox_style",
    parent = "textbox",
    width = 184,
}
