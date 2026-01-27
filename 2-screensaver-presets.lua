local Blitbuffer = require("ffi/blitbuffer")
local BookStatusWidget = require("ui/widget/bookstatuswidget")
local CustomPositionContainer = require("ui/widget/container/custompositioncontainer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local ffiUtil = require("ffi/util")
local Font = require("ui/font")
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local ImageWidget = require("ui/widget/imagewidget")
local InfoMessage = require("ui/widget/infomessage")
local OverlapGroup = require("ui/widget/overlapgroup")
local Presets = require("ui/presets")
local RenderImage = require("ui/renderimage")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")
local ReaderUI = require("apps/reader/readerui")
local Screen = Device.screen
local Screensaver = require("ui/screensaver")
local ScreenSaverLockWidget = require("ui/widget/screensaverlockwidget")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")

local logger = require("logger")

-- default values
if G_reader_settings:hasNot("screensaver_close_widgets_when_no_fill") then
    G_reader_settings:saveSetting("screensaver_close_widgets_when_no_fill", false)
end
if G_reader_settings:hasNot("screensaver_center_image") then
    G_reader_settings:saveSetting("screensaver_center_image", false)
end
if G_reader_settings:hasNot("screensaver_overlap_message") then
    G_reader_settings:saveSetting("screensaver_overlap_message", true)
end
if G_reader_settings:hasNot("screensaver_invert_message_color") then
    G_reader_settings:saveSetting("screensaver_invert_message_color", false)
end
if G_reader_settings:hasNot("screensaver_box_message_show_icon") then
    G_reader_settings:saveSetting("screensaver_box_message_show_icon", true)
end

local function find_item_from_path(menu, ...)
    local function find_sub_item(sub_items, text)
        -- logger.dbg("search item", text)
        for _, item in ipairs(sub_items) do
            local item_text = item.text or (item.text_func and item.text_func())
            if item_text and item_text == text then
                -- logger.dbg("Found item", item_text)
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

local function add_options_in(menu, sub_menu)
    local items = sub_menu.sub_item_table
	items[#items].separator = true
    table.insert(items, {
        text = _("Close widgets before showing the screensaver"),
        help_text = _("This option will only become available, if you have selected 'No fill'."),
        enabled_func = function() return G_reader_settings:readSetting("screensaver_img_background") == "none" end,
        checked_func = function() return G_reader_settings:isTrue("screensaver_close_widgets_when_no_fill") end,
        callback = function(touchmenu_instance)
            G_reader_settings:flipNilOrFalse("screensaver_close_widgets_when_no_fill")
            touchmenu_instance:updateItems()
        end,
    })
    -- table.insert(items, {
        -- text = _("Refresh before showing the screensaver"),
        -- help_text = _("This option will only become available, if you have selected a cover or a random image."),
        -- enabled_func = function()
            -- local screensaver_type = G_reader_settings:readSetting("screensaver_type")
            -- return Device:hasEinkScreen() and (screensaver_type == "cover" or screensaver_type == "random_image")
        -- end,
        -- checked_func = function() return G_reader_settings:isTrue("screensaver_refresh") end,
        -- callback = function(touchmenu_instance)
            -- G_reader_settings:toggle("screensaver_refresh")
            -- touchmenu_instance:updateItems()
        -- end,
    -- })
    table.insert(items, {
        text = _("Message do not overlap image"),
        help_text = _(
            "This option will only become available, if you have selected a cover or a random image and you have a message and the message position is 'top' or 'bottom'."
        ),
        enabled_func = function()
            local screensaver_type = G_reader_settings:readSetting("screensaver_type")
            local message_pos = G_reader_settings:readSetting("screensaver_message_vertical_position")
            return G_reader_settings:readSetting("screensaver_show_message")
                and (screensaver_type == "cover" or screensaver_type == "random_image")
                and (message_pos == 100 or message_pos == 0)
        end,
        checked_func = function() return G_reader_settings:nilOrFalse("screensaver_overlap_message") end,
        callback = function(touchmenu_instance)
            G_reader_settings:toggle("screensaver_overlap_message")
            touchmenu_instance:updateItems()
        end,
    })
    table.insert(items, {
        text = _("Center image"),
        help_text = _("This option will only become available, if you have selected 'Message do not overlap image'."),
        enabled_func = function()
            local screensaver_type = G_reader_settings:readSetting("screensaver_type")
            local message_pos = G_reader_settings:readSetting("screensaver_message_vertical_position")
            return G_reader_settings:nilOrFalse("screensaver_overlap_message")
                and (screensaver_type == "cover" or screensaver_type == "random_image")
                and (message_pos == 100 or message_pos == 0)
        end,
        checked_func = function() return G_reader_settings:isTrue("screensaver_center_image") end,
        callback = function(touchmenu_instance)
            G_reader_settings:flipNilOrFalse("screensaver_center_image")
            touchmenu_instance:updateItems()
        end,
    })
    table.insert(items, {
        text = _("Invert message color when no fill"),
        -- help_text = _("When the This option will only become available, if you have selected 'Message do not overlap image'."),
        checked_func = function() return G_reader_settings:isTrue("screensaver_invert_message_color") end,
        callback = function(touchmenu_instance)
            G_reader_settings:flipNilOrFalse("screensaver_invert_message_color")
            touchmenu_instance:updateItems()
        end,
    })
    items[#items].separator = true
	table.insert(items, {
        text = _("Sleep screen presets"),
        separator = true,
        sub_item_table_func = function()
            return Presets.genPresetMenuItemTable(menu.preset_obj, nil, nil)
        end,
    })
	
	local message_container_menu = find_item_from_path(items, _("Sleep screen message"), _("Container and position"))
	local container_items = message_container_menu.sub_item_table
	local prefix = Screensaver.prefix or ""
	table.insert(container_items, {
        text = _("Show icon"),
        help_text = _("This option will only become available, if you have selected Box as the container."),
        enabled_func = function()
            local message_container = G_reader_settings:readSetting(prefix .. "screensaver_message_container")
		        or G_reader_settings:readSetting("screensaver_message_container")
            return message_container == "box" 
        end,
        checked_func = function() return G_reader_settings:isTrue("screensaver_box_message_show_icon") end,
        callback = function(touchmenu_instance)
            G_reader_settings:flipNilOrFalse("screensaver_box_message_show_icon")
            touchmenu_instance:updateItems()
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
		invert_message_color = G_reader_settings:readSetting("screensaver_invert_message_color"),
		show_icon = G_reader_settings:readSetting("screensaver_box_message_show_icon"),
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
	 if preset.show_icon ~= nil then G_reader_settings:saveSetting("screensaver_box_message_show_icon", preset.show_icon) end
end

local function getPresets()
	local screensaver_config = {
		presets = G_reader_settings:readSetting("screensaver_presets", {})
	}
	
	return Presets.getPresets(screensaver_config)
end

local function initPresetsAndMenus(Menu, MenuOrder) 
	local orig_Menu_init = Menu.init
	function Menu:init()
		orig_Menu_init(self)
		
		self.preset_obj = {
			presets = G_reader_settings:readSetting("screensaver_presets", {}),
			-- cycle_index = G_reader_settings:readSetting("my_module_presets_cycle_index"),
			dispatcher_name = "load_screensaver_preset",
			-- saveCycleIndex = function(this)
				-- G_reader_settings:saveSetting("my_module_presets_cycle_index", this.cycle_index)
			-- end,
			buildPreset = function() return buildPreset() end,
			loadPreset = function(preset) loadPreset(preset) end,
		}

		self:onDispatcherRegisterActions()
	end

	function Menu:onDispatcherRegisterActions()
		Dispatcher:registerAction("load_screensaver_preset", {category="string", event="LoadScreensaverPreset", title=_("Load screensaver preset"), args_func=getPresets, screen=true})
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

local userpatch = require("userpatch")
local addOverlayMessage = userpatch.getUpValue(Screensaver.show, "addOverlayMessage")

Screensaver.show = function(self)
    -- self.ui is set in Screensaver:setup()
    if not self.ui then return end

    -- Notify Device methods that we're in screen saver mode, so they know whether to suspend or resume on Power events.
    Device.screen_saver_mode = true

    -- Check if we requested a lock gesture
    local with_gesture_lock = Device:isTouchDevice() and G_reader_settings:readSetting("screensaver_delay") == "gesture"

    -- In as-is mode with no message, no overlay and no lock, we've got nothing to show :)
    if self.screensaver_type == "disable" and not self.show_message and not self.overlay_message and not with_gesture_lock then
        return
    end

    local orig_dimen
    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local rotation_mode = Screen:getRotationMode()

    -- We mostly always suspend in Portrait/Inverted Portrait mode...
    -- ... except when we just show an InfoMessage or when the screensaver
    -- is disabled, as it plays badly with Landscape mode (c.f., #4098 and #5920).
    -- We also exclude full-screen widgets that work fine in Landscape mode,
    -- like ReadingProgress and BookStatus (c.f., #5724)
    if self:modeExpectsPortrait() then
        Device.orig_rotation_mode = rotation_mode
        -- Leave Portrait & Inverted Portrait alone, that works just fine.
        if bit.band(Device.orig_rotation_mode, 1) == 1 then
            -- i.e., only switch to Portrait if we're currently in *any* Landscape orientation (odd number)
            Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
            orig_dimen = with_gesture_lock and { w = screen_w, h = screen_h }
            screen_w, screen_h = screen_h, screen_w
        else
            Device.orig_rotation_mode = nil
        end

        -- On eInk, if we're using a screensaver mode that shows an image,
        -- flash the screen to white first, to eliminate ghosting.
        if Device:hasEinkScreen() and self:modeIsImage() then
            if self:withBackground() then
                Screen:clear()
            end
            Screen:refreshFull(0, 0, screen_w, screen_h)

            -- On Kobo, on sunxi SoCs with a recent kernel, wait a tiny bit more to avoid weird refresh glitches...
            if Device:isKobo() and Device:isSunxi() then
                ffiUtil.usleep(150 * 1000)
            end
        end
    else
        -- nil it, in case user switched ScreenSaver modes during our lifetime.
        Device.orig_rotation_mode = nil
    end

    -- Build the main widget for the effective mode, all the sanity checks were handled in setup
    local widget = nil
    if self.screensaver_type == "cover" or self.screensaver_type == "random_image" then
        local widget_settings = {
            width = screen_w,
            height = screen_h,
            scale_factor = G_reader_settings:isFalse("screensaver_stretch_images") and 0 or nil,
            stretch_limit_percentage = G_reader_settings:readSetting("screensaver_stretch_limit_percentage"),
        }
        if self.image then
            widget_settings.image = self.image
            widget_settings.image_disposable = true
        elseif self.image_file then
            if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
                -- We need to load the image here to determine whether to rotate
                if util.getFileNameSuffix(self.image_file) == "svg" then
                    widget_settings.image = RenderImage:renderSVGImageFile(self.image_file, nil, nil, 1)
                else
                    widget_settings.image = RenderImage:renderImageFile(self.image_file, false, nil, nil)
                end
                if not widget_settings.image then
                    widget_settings.image = RenderImage:renderCheckerboard(screen_w, screen_h, Screen.bb:getType())
                end
                widget_settings.image_disposable = true
            else
                widget_settings.file = self.image_file
                widget_settings.file_do_cache = false
            end
            widget_settings.alpha = true
        end -- set cover or file
        if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
            local angle = rotation_mode == 3 and 180 or 0 -- match mode if possible
            if (widget_settings.image:getWidth() < widget_settings.image:getHeight()) ~= (widget_settings.width < widget_settings.height) then
                angle = angle + (G_reader_settings:isTrue("imageviewer_rotation_landscape_invert") and -90 or 90)
            end
            widget_settings.rotation_angle = angle
        end
        widget = ImageWidget:new(widget_settings)
    elseif self.screensaver_type == "bookstatus" then
        widget = BookStatusWidget:new{
            ui = self.ui,
            readonly = true,
        }
    elseif self.screensaver_type == "readingprogress" then
        widget = self.ui.statistics:onShowReaderProgress(true) -- get widget
    end

    -- Assume that we'll be covering the full-screen by default (either because of a widget, or a background fill).
    local covers_fullscreen = true
    -- Speaking of, set that background fill up...
    local background
    local fgcolor, bgcolor = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE
    if self.screensaver_background == "black" then
        background = Blitbuffer.COLOR_BLACK
        bgcolor = background -- text follow the same color scheme
        fgcolor = Blitbuffer.COLOR_WHITE
    elseif self.screensaver_background == "white" then
        background = Blitbuffer.COLOR_WHITE
    elseif self.screensaver_background == "none" then
        background = nil
        if G_reader_settings:isTrue("screensaver_invert_message_color") then
            fgcolor, bgcolor = bgcolor, fgcolor
        end
    end

    if G_reader_settings:isTrue("night_mode") then
        fgcolor, bgcolor = bgcolor, fgcolor
    end

    local message_height
    if self.show_message then
        -- Handle user settings & fallbacks, with that prefix mess on top...
        local screensaver_message = self.default_screensaver_message
        if G_reader_settings:has(self.prefix .. "screensaver_message") then
            screensaver_message = G_reader_settings:readSetting(self.prefix .. "screensaver_message")
        elseif G_reader_settings:has("screensaver_message") then
            screensaver_message = G_reader_settings:readSetting("screensaver_message")
        end
        -- If the message is set to the defaults (which is also the case when it's unset), prefer the event message if there is one.
        if screensaver_message == self.default_screensaver_message then
            if self.event_message then
                screensaver_message = self.event_message
                -- The overlay is only ever populated with the event message, and we only want to show it once ;).
                self.overlay_message = nil
            end
        end

        screensaver_message = self.ui.bookinfo:expandString(screensaver_message)
            or self.event_message or self.default_screensaver_message

        local message_container = G_reader_settings:readSetting(self.prefix .. "screensaver_message_container")
            or G_reader_settings:readSetting("screensaver_message_container")
        local vertical_percentage = G_reader_settings:readSetting(self.prefix .. "screensaver_message_vertical_position")
            or G_reader_settings:readSetting("screensaver_message_vertical_position", 50)
        local alpha_value = G_reader_settings:readSetting(self.prefix .. "screensaver_message_alpha")
            or G_reader_settings:readSetting("screensaver_message_alpha", 100)

        -- The only case where we *won't* cover the full-screen is when we only display a message and no background.
        if widget == nil and self.screensaver_background == "none" then
            covers_fullscreen = false
        end

        local message_widget, content_widget
        if message_container == "box" then
			local show_icon = G_reader_settings:isTrue("screensaver_box_message_show_icon")
            content_widget = InfoMessage:new{
                text = screensaver_message,
                readonly = true,
                dismissable = false,
                force_one_line = true,
                alpha = false,
                show_icon = show_icon,
                alignment = show_icon and "left" or "center"
            }
            content_widget = content_widget.movable
            
            local frame = content_widget[1]
            frame.color = fgcolor
            frame.background = bgcolor
            
            local hgroup = frame[1]
            
            local icon = hgroup[1]
            if bgcolor == Blitbuffer.COLOR_BLACK then
                icon.invert = true
            end
            
            local textbox = hgroup[3]
            textbox.fgcolor = fgcolor
            textbox.bgcolor = bgcolor
            textbox:update(true)
            
        elseif message_container == "banner" then
            local face = Font:getFace("infofont")
            content_widget = TextBoxWidget:new{
                text = screensaver_message,
                face = face,
                width = screen_w,
                alignment = "center",
                fgcolor = fgcolor,
                bgcolor = bgcolor,
            }
        end
        -- Create a custom container that places the Message at the requested vertical coordinate.
        message_widget = CustomPositionContainer:new{
            widget = content_widget,
            -- although the computer expects 0 to be the top, users expect 0 to be the bottom
            vertical_position = 1 - (vertical_percentage / 100),
            alpha = alpha_value / 100,
        }
        -- Forward the height of the top message to the overlay widget
        if vertical_percentage > 80 then -- top of the screen
            message_height = message_widget.widget:getSize().h
        end

        -- Check if message_widget should be overlaid on another widget
        if message_widget then
            if widget then  -- We have a Screensaver widget
                -- Show message_widget depending on overlap_message and center_image
				local overlap_message = not self:modeIsImage() or G_reader_settings:readSetting("screensaver_overlap_message") or not (vertical_percentage == 100 or vertical_percentage == 0)
                local group_settings
                local group_type

                if overlap_message then
                    group_type = OverlapGroup
                    group_settings = {
						widget,
						message_widget
					}
                else
					local center_image = G_reader_settings:readSetting("screensaver_center_image")
					local is_message_top = vertical_percentage >= 50
					message_widget = message_widget.widget -- pull out of CustomPositionContainer
					widget.height = screen_h - message_widget:getSize().h * (center_image and 2 or 1)
				
                    group_type = VerticalGroup
                    if center_image then
                        local verticalspan = VerticalSpan:new { width = message_widget:getSize().h }
                        if is_message_top then
                            group_settings = { message_widget, widget, verticalspan }
                        else
                            group_settings = { verticalspan, widget, message_widget }
                        end
                    else
                        if is_message_top then
                            group_settings = { message_widget, widget }
                        else
                            group_settings = { widget, message_widget }
                        end
                    end
                end
                group_settings.dimen = {
                    w = screen_w,
                    h = screen_h,
                }
                widget = group_type:new(group_settings)
            else
                -- No previously created widget, so just show message widget
                widget = message_widget
            end
        end
    end

    if self.screensaver_background == "none" and self:modeIsImage() then -- is the background kept ?
        if G_reader_settings:readSetting("screensaver_close_widgets_when_no_fill") then -- !!!!!!!!!
            -- clear highlight
            local readerui = ReaderUI.instance
            if readerui and readerui.highlight then readerui.highlight:clear(readerui.highlight:getClearId()) end

            local added = {}
            local widgets = {}
            for widget in UIManager:topdown_widgets_iter() do -- populate bottom up with unique widgets (eg. keyboard appears several times)
                if not added[widget] then -- already added ?
                    table.insert(widgets, widget)
                    added[widget] = true
                end
            end
            table.remove(widgets) -- remove the main widget @ the end of the stack, we don't want to close it
            if #widgets >= 1 then -- close all the remaining ones and repaint
                for _, widget in ipairs(widgets) do
                    UIManager:close(widget, "fast")
                end
                UIManager:forceRePaint()
            end
        end
    end    
	
    if self.overlay_message then
        widget = addOverlayMessage(widget, message_height, self.overlay_message)
    end

    -- NOTE: Make sure InputContainer gestures are not disabled, to prevent stupid interactions with UIManager on close.
    UIManager:setIgnoreTouchInput(false)

    if widget then
        self.screensaver_widget = ScreenSaverWidget:new{
            widget = widget,
            background = background,
            covers_fullscreen = covers_fullscreen,
        }
        self.screensaver_widget.modal = true
        self.screensaver_widget.dithered = true

        UIManager:show(self.screensaver_widget, "full")
    end

    -- Setup the gesture lock through an additional invisible widget, so that it works regardless of the configuration.
    if with_gesture_lock then
        self.screensaver_lock_widget = ScreenSaverLockWidget:new{
            ui = self.ui,
            orig_dimen = orig_dimen,
        }

        -- It's flagged as modal, so it'll stay on top
        UIManager:show(self.screensaver_lock_widget)
    end
end

initPresetsAndMenus(ReaderMenu, ReaderMenuOrder)
initPresetsAndMenus(FileManagerMenu, FileManagerMenuOrder)
