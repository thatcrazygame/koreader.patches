local Dispatcher = require("dispatcher")
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local logger = require("logger")
local Presets = require("ui/presets")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")
local Screensaver = require("ui/screensaver")
local _ = require("gettext")

    
local function find_item_from_path(menu, ...)
    local function find_sub_item(sub_items, text)
        -- logger.info("search item", text)
        for _, item in ipairs(sub_items) do
            local item_text = item.text or (item.text_func and item.text_func())
            if item_text and item_text == text then
                -- logger.info("Found item", item_text)
                return item
            end
        end
    end

    local sub_items, item
    for _, text in ipairs { ... } do
        sub_items = item and item.sub_item_table or menu
        if not sub_items then return end
        item = find_sub_item(sub_items, text)
        if not item then return end
    end
    return item
end

local function add_options_in(self, menu)
    local items = menu.sub_item_table
    items[#items].separator = true
	table.insert(items, {
        text = _("Sleep screen presets"),
        separator = true,
        sub_item_table_func = function()
            return Presets.genPresetMenuItemTable(self.preset_obj, nil, nil)
        end,
    })
end

local function add_options_in_screensaver(order, menu, menu_name)
    local buttons = order["KOMenu:menu_buttons"]
    for i, button in ipairs(buttons) do
        if button == "setting" then
            local setting_menu = menu.tab_item_table[i]
            -- logger.info(i, setting_menu)
            if setting_menu then
                local sub_menu = find_item_from_path(setting_menu, _("Screen"), _("Sleep screen"))
                if sub_menu then
                    add_options_in(menu, sub_menu)
                    logger.info("Add screensaver options in", menu_name, "menu")
                end
            end
        end
    end
end


local function buildPreset()
	local screensaver_message = Screensaver.default_screensaver_message
	local prefix = Screensaver.prefix or ""
	if G_reader_settings:has(prefix .. "screensaver_message") then
		screensaver_message = G_reader_settings:readSetting(prefix .. "screensaver_message")
	elseif G_reader_settings:has("screensaver_message") then
		screensaver_message = G_reader_settings:readSetting("screensaver_message")
	end
	
	local screensaver_dir = G_reader_settings:readSetting(prefix .. "screensaver_dir")
                             or G_reader_settings:readSetting("screensaver_dir")

	return {
	    show_message = G_reader_settings:readSetting("screensaver_show_message"),
		message = screensaver_message,
		screensaver_type = G_reader_settings:readSetting("screensaver_type"),
		img_background = G_reader_settings:readSetting("screensaver_img_background"),
		rand_img_dir = screensaver_dir,
		cycle_images = G_reader_settings:readSetting("screensaver_cycle_images_alphabetically"),
		msg_background = G_reader_settings:readSetting("screensaver_msg_background"),
		message_container = G_reader_settings:readSetting("screensaver_message_container"),
		message_vertical_position = G_reader_settings:readSetting("screensaver_message_vertical_position"),
		message_alpha = G_reader_settings:readSetting("screensaver_message_alpha"),
		stretch_images = G_reader_settings:readSetting("screensaver_stretch_images"),
		rotate_auto_for_best_fit = G_reader_settings:readSetting("screensaver_rotate_auto_for_best_fit"),
		delay = G_reader_settings:readSetting("screensaver_delay"),
		hide_fallback_msg = G_reader_settings:readSetting("screensaver_hide_fallback_msg"),
		close_widgets = G_reader_settings:readSetting("screensaver_close_widgets_when_no_fill"),
		center_image = G_reader_settings:readSetting("screensaver_center_image"),
		overlap_message = G_reader_settings:readSetting("screensaver_overlap_message"),
		invert_message_color = G_reader_settings:readSetting("screensaver_invert_message_color")
	}
end

local function loadPreset(preset)
	 if preset.show_message ~= nil then G_reader_settings:saveSetting("screensaver_show_message", preset.show_message) end
	 if preset.message ~= nil then G_reader_settings:saveSetting("screensaver_message", preset.message) end
	 if preset.screensaver_type ~= nil then G_reader_settings:saveSetting("screensaver_type", preset.screensaver_type) end
	 if preset.img_background ~= nil then G_reader_settings:saveSetting("screensaver_img_background", preset.img_background) end
	 if preset.rand_img_dir ~= nil then G_reader_settings:saveSetting("screensaver_dir", preset.rand_img_dir) end
	 if preset.cycle_images ~= nil then G_reader_settings:saveSetting("screensaver_cycle_images_alphabetically", preset.cycle_images) end
	 if preset.msg_background ~= nil then G_reader_settings:saveSetting("screensaver_msg_background", preset.msg_background) end
	 if preset.message_container ~= nil then G_reader_settings:saveSetting("screensaver_message_container", preset.message_container) end
	 if preset.message_vertical_position ~= nil then G_reader_settings:saveSetting("screensaver_message_vertical_position", preset.message_vertical_position) end
	 if preset.message_alpha ~= nil then G_reader_settings:saveSetting("screensaver_message_alpha", preset.message_alpha) end
	 if preset.stretch_images ~= nil then G_reader_settings:saveSetting("screensaver_stretch_images", preset.stretch_images) end
	 if preset.rotate_auto_for_best_fit ~= nil then G_reader_settings:saveSetting("screensaver_rotate_auto_for_best_fit", preset.rotate_auto_for_best_fit) end
	 if preset.delay ~= nil then G_reader_settings:saveSetting("screensaver_delay", preset.delay) end
	 if preset.hide_fallback_msg ~= nil then G_reader_settings:saveSetting("screensaver_hide_fallback_msg", preset.hide_fallback_msg) end
	 if preset.close_widgets ~= nil then G_reader_settings:saveSetting("screensaver_close_widgets_when_no_fill", preset.close_widgets) end
	 if preset.center_image ~= nil then G_reader_settings:saveSetting("screensaver_center_image", preset.center_image) end
	 if preset.overlap_message ~= nil then G_reader_settings:saveSetting("screensaver_overlap_message", preset.overlap_message) end
	 if preset.invert_message_color ~= nil then G_reader_settings:saveSetting("screensaver_invert_message_color", preset.invert_message_color) end
end

local function getPresets()
	local screensaver_config = {
		presets = G_reader_settings:readSetting("screensaver_presets", {})
	}
	
	return Presets.getPresets(screensaver_config)
end

local function register_action()
	Dispatcher:registerAction("load_screensaver_preset", {category="string", event="LoadScreensaverPreset", title=_("Load screensaver preset"), args_func=getPresets, screen=true})
end


local screensaver_preset_obj = {
	presets = G_reader_settings:readSetting("screensaver_presets", {}),
	-- cycle_index = G_reader_settings:readSetting("my_module_presets_cycle_index"),
	dispatcher_name = "load_screensaver_preset",
	-- saveCycleIndex = function(this)
		-- G_reader_settings:saveSetting("my_module_presets_cycle_index", this.cycle_index)
	-- end,
	buildPreset = function() return buildPreset() end,
	loadPreset = function(preset) loadPreset(preset) end,
}


local function initPresets(Menu, MenuOrder) 
	local orig_Menu_init = Menu.init
	function Menu:init()
		orig_Menu_init(self)
		
		self.preset_obj = screensaver_preset_obj
		self:onDispatcherRegisterActions()
	end

	function Menu:onDispatcherRegisterActions()
		register_action()
	end

	function Menu:onLoadScreensaverPreset(preset_name)
		return Presets.onLoadPreset(self.preset_obj, preset_name, true)
	end

	local orig_Menu_setUpdateItemTable = Menu.setUpdateItemTable

	Menu.setUpdateItemTable = function(self)
		orig_Menu_setUpdateItemTable(self)
		add_options_in_screensaver(MenuOrder, self, "reader")
	end
end

initPresets(ReaderMenu, ReaderMenuOrder)
initPresets(FileManagerMenu, FileManagerMenuOrder)