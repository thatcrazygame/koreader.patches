local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local gettext = require("gettext")
local ImageWidget = require("ui/widget/imagewidget")
local mupdf = require("ffi/mupdf")
local OverlapGroup = require("ui/widget/overlapgroup")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local Screen = Device.screen
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")

local logger = require("logger")

-- ================================================================
-- SETTINGS
-- ================================================================

local MIN_STRENGTH = 0.1
local MAX_STRENGTH = 10
local MIN_QUALITY = 1
local MAX_QUALITY = 10
local STEP = 1
local HOLD_STEP = 0.1

local SETTINGS = {
    BLUR_SCREEN = "screensaver_blur_screen",
    BLUR_SCREEN_STRENGTH = "screensaver_blur_screen_strength",
    BLUR_SCREEN_QUALITY = "screensaver_blur_screen_quality",
    BLUR_COVER = "screensaver_blur_cover",
    BLUR_COVER_STRENGTH = "screensaver_blur_cover_strength",
    BLUR_COVER_QUALITY = "screensaver_blur_cover_quality",
    FORCE_BLUR = "screensaver_force_blur",
}

local DEFAULTS = {
    BLUR_SCREEN = true,
    BLUR_SCREEN_STRENGTH = 1.0,
    BLUR_SCREEN_QUALITY = 7.0,
    BLUR_COVER = false,
    BLUR_COVER_STRENGTH = 2.0,
    BLUR_COVER_QUALITY = 6.0,
    FORCE_BLUR = false,
}

local function initDefaults()
    for key, setting in pairs(SETTINGS) do
        if G_reader_settings:hasNot(setting) then
            G_reader_settings:saveSetting(setting, DEFAULTS[key])
        end
    end
end

initDefaults()

-- ================================================================
-- LOCALIZATION
-- ================================================================

local PATCH_L10N = {
    en = {
        ["Blur screen"] = "Blur screen",
        ["Blur cover"] = "Blur cover",
        ["Blur the screen before showing any sleep screen covers or widgets"] = "Blur the screen before showing any sleep screen covers or widgets",
        ["Enable blur"] = "Enable blur",
        ["Force blur"] = "Force blur",
        ["Enable blur even if sleep screen may be covering entire screen"] = "Enable blur even if sleep screen may be covering entire screen",
        ["Strength"] = "Strength",
        ["Adjust the strength of the blur effect. A higher strength will take longer to apply and then sleep."] = "Adjust the strength of the blur effect. A higher strength will take longer to apply and then sleep.",
        ["Quality"] = "Quality",
        ["Adjust the visual quality of the blur effect. A higher quality will take longer to apply and then sleep."] = "Adjust the visual quality of the blur effect. A higher quality will take longer to apply and then sleep.",
    }
}


local function l10nLookup(msg)
    local lang = "en"
    if G_reader_settings and G_reader_settings.readSetting then
        lang = G_reader_settings:readSetting("language") or "en"
    end
    local lang_base = lang:match("^([a-z]+)") or lang
    local map = PATCH_L10N[lang] or PATCH_L10N[lang_base] or PATCH_L10N.en or {}
    return map[msg]
end


local function _(msg)
    return l10nLookup(msg) or gettext(msg)
end


-- ================================================================
-- MENUS
-- ================================================================

local function enableCoverBlur()
    return G_reader_settings:readSetting("screensaver_type") == "cover"
end


local function createSpinnerMenuItem(text, info_text, setting_key, default_val, min_val, max_val, step, hold_step, separator, enabled_func)
    local spin_menu = {
        text_func = function() 
            return _(text) .. ": " .. G_reader_settings:readSetting(setting_key)
        end,
        callback = function(touchmenu_instance)
            local current = G_reader_settings:readSetting(setting_key, default_val)
            local spinner = SpinWidget:new {
                value = current,
                value_min = min_val,
                value_max = max_val,
                value_step = step,
                value_hold_step = hold_step,
                precision = "%.1f",
                ok_text = _("Save"),
                title_text = _(text),
                info_text = _(info_text),
                callback = function(spin)
                    G_reader_settings:saveSetting(setting_key, spin.value)
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            }
            UIManager:show(spinner)
            if touchmenu_instance then touchmenu_instance:updateItems() end
        end,
        keep_menu_open = true,
        separator = separator,
    }
    
    if type(enabled_func) == "function" then
        spin_menu.enabled_func = enabled_func
    end
    
    return spin_menu
end


local function findItemFromPath(menu, ...)
    local function findSubItem(sub_items, text)
        for i, item in ipairs(sub_items) do
            local item_text = item.text or (item.text_func and item.text_func())
            if item_text and item_text == text then
                return item, i
            end
        end
    end

    local sub_items, item, menu_pos
    for i, text in ipairs { ... } do
        sub_items = item and item.sub_item_table or menu
        if not sub_items then return end
        item, menu_pos = findSubItem(sub_items, text)
        if not item then return end
    end
    return item, menu_pos
end


local function addOptionsIn(menu, sub_menu)
    local items = sub_menu.sub_item_table
    local no_show, menu_pos = findItemFromPath(items, _("Do not show this book cover on sleep screen"))

    logger.dbg("Sleep screen sub items", no_show, menu_pos)
    
    items[#items].separator = true
    table.insert(items, (menu_pos or 0) + 1, {
        text = _("Blur"),
        help_text = _("Blur the screen before showing any sleep screen covers or widgets"),
        sub_item_table = {
            {
                text = _("Blur screen"),
                checked_func = function() return G_reader_settings:isTrue(SETTINGS.BLUR_SCREEN) end,
                callback = function(touchmenu_instance)
                    G_reader_settings:toggle(SETTINGS.BLUR_SCREEN)
                    touchmenu_instance:updateItems()
                end,
            },
            --[[
            -- Intended for use with other screensaver patches. May enable if there is demand for it
            -- Or those other patches could set screensaver_force_blur = true themselves
            {
                text = _("Force blur"),
                help_text = _("Enable blur even if sleep screen may be covering entire screen"),
                checked_func = function() return G_reader_settings:isTrue(SETTINGS.FORCE_BLUR) end,
                callback = function(touchmenu_instance)
                    G_reader_settings:toggle(SETTINGS.FORCE_BLUR)
                    touchmenu_instance:updateItems()
                end,
            },            
            ]]--
            createSpinnerMenuItem(
                "Strength",
                "Adjust the strength of the blur effect. A higher strength will take longer to apply and then sleep.",
                SETTINGS.BLUR_SCREEN_STRENGTH, DEFAULTS.BLUR_SCREEN_STRENGTH,
                MIN_STRENGTH, MAX_STRENGTH,
                STEP, HOLD_STEP,
                false, nil
            ),
            createSpinnerMenuItem(
                "Quality",
                "Adjust the visual quality of the blur effect. A higher quality will take longer to apply and then sleep.",
                SETTINGS.BLUR_SCREEN_QUALITY, DEFAULTS.BLUR_SCREEN_QUALITY,
                MIN_QUALITY, MAX_QUALITY,
                STEP, HOLD_STEP,
                true, nil
            ),
            {
                text = _("Blur cover"),
                checked_func = function() return G_reader_settings:isTrue(SETTINGS.BLUR_COVER) end,
                enabled_func = enableCoverBlur,
                callback = function(touchmenu_instance)
                    G_reader_settings:toggle(SETTINGS.BLUR_COVER)
                    touchmenu_instance:updateItems()
                end,
            },
            createSpinnerMenuItem(
                "Strength",
                "Adjust the strength of the blur effect. A higher strength will take longer to apply and then sleep.",
                SETTINGS.BLUR_COVER_STRENGTH, DEFAULTS.BLUR_COVER_STRENGTH,
                MIN_STRENGTH, MAX_STRENGTH,
                STEP, HOLD_STEP,
                false, enableCoverBlur
            ),
            createSpinnerMenuItem(
                "Quality",
                "Adjust the visual quality of the blur effect. A higher quality will take longer to apply and then sleep.",
                SETTINGS.BLUR_COVER_QUALITY, DEFAULTS.BLUR_COVER_QUALITY,
                MIN_QUALITY, MAX_QUALITY,
                STEP, HOLD_STEP,
                false, enableCoverBlur
            ),
        }
    })
end


local function addOptionsInScreensaver(order, menu, menu_name)
    local buttons = order["KOMenu:menu_buttons"]
    for i, button in ipairs(buttons) do
        if button == "setting" then
            local setting_menu = menu.tab_item_table[i]
            if setting_menu then
                local sub_menu = findItemFromPath(setting_menu, _("Screen"), _("Sleep screen"))
                if sub_menu then
                    addOptionsIn(menu, sub_menu)
                    logger.info("Add screensaver options in", menu_name, "menu")
                end
            end
        end
    end
end


local function initMenus(Menu, MenuOrder)
    local orig_Menu_setUpdateItemTable = Menu.setUpdateItemTable

    Menu.setUpdateItemTable = function(self)
        orig_Menu_setUpdateItemTable(self)
        addOptionsInScreensaver(MenuOrder, self, "reader")
    end
end


initMenus(ReaderMenu, ReaderMenuOrder)
initMenus(FileManagerMenu, FileManagerMenuOrder)


-- ================================================================
-- UTILS
-- ================================================================

local function round(num) 
    -- assumes positive numbers
    return math.floor(num + 0.5)
end


local function getBlurProperties(strength_setting, quality_setting)
    local strength = G_reader_settings:readSetting(strength_setting)
    local quality = MAX_QUALITY - G_reader_settings:readSetting(quality_setting) + 1
    local kernel_size = (4 * strength) + 1

    return strength, quality, kernel_size
end


-- ================================================================
-- BLUR FUNCTIONS
-- ================================================================

local function createGaussianKernel(sigma, size)
    -- https://en.wikipedia.org/wiki/Gaussian_blur
    -- Don't need the part of the equation before e because we're normalizing

    local kernel = {}
    local sum = 0
    local mean = (size - 1) / 2
    
    for i = 0, size - 1 do
        local x = i - mean
        kernel[i + 1] = math.exp(-(x ^ 2) / (2 * (sigma ^ 2)))
        sum = sum + kernel[i + 1]
    end
    
    -- Normalize
    for i = 1, size do
        kernel[i] = kernel[i] / sum
    end

    return kernel
end


local function blur1D(in_bb, kernel)
    local height = in_bb:getHeight()
    local width = in_bb:getWidth()
    local out_bb = in_bb:copy()
    local is_rgb = out_bb:isRGB()
    local has_alpha = out_bb:getType() == Blitbuffer.TYPE_BB8A or out_bb:getType() == Blitbuffer.TYPE_BBRGB32
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local val = {
                a = 0, -- greyscale value, not alpha
                r = 0,
                g = 0,
                b = 0,
                alpha = 0,
            }
            for i, weight in ipairs(kernel) do
                local offset = i - 1 - math.floor(#kernel / 2)
                if x + offset < 0 or x + offset > width - 1 then offset = -1 * offset end
                
                local pix = in_bb:getPixel(x + offset, y)
                if is_rgb then
                    val.r = val.r + (pix:getR() * weight)
                    val.g = val.g + (pix:getG() * weight)
                    val.b = val.b + (pix:getB() * weight)
                else
                    val.a = val.a + (pix.a * weight)
                end
                if has_alpha then
                    val.alpha = val.alpha + (pix:getAlpha() * weight)
                end
            end

            for key, v in pairs(val) do
                -- by the math, it shouldn't be possible to greater than 255, but just in case
                val[key] = math.min(round(v), 255)
            end

            local color
            if is_rgb then
                if has_alpha then
                    color = Blitbuffer.ColorRGB32(val.r, val.g, val.b, val.alpha)
                else
                    color = Blitbuffer.ColorRGB24(val.r, val.g, val.b)    
                end
            else
                if has_alpha then
                    color = Blitbuffer.Color8A(val.a, val.alpha)
                else
                    color = Blitbuffer.Color8(val.a)    
                end
            end
            out_bb:setPixel(x, y, color)
        end
    end
    return out_bb
end


local function gaussianBlur(in_bb, sigma, blur_size)
    local kernel = createGaussianKernel(sigma, blur_size)
    local x_pass_bb = blur1D(in_bb, kernel):rotate(90) -- rotate 90 so we can use the same x/y loops
    local final_bb = blur1D(x_pass_bb, kernel):rotate(-90) -- then rotate back
    return final_bb
end


local function do_blur_screen(screensaver)
    return G_reader_settings:isTrue(SETTINGS.BLUR_SCREEN)
            and (
                (screensaver.screensaver_background == "none" and screensaver:modeIsImage())
                or screensaver.screensaver_type == "disable"
            )
            or G_reader_settings:isTrue("screensaver_force_blur")
end


local function do_blur_cover(screensaver)
    return G_reader_settings:isTrue(SETTINGS.BLUR_COVER) and screensaver.screensaver_type == "cover"
end


local function createBlurWidget()
    local strength, quality, kernel_size = getBlurProperties(SETTINGS.BLUR_SCREEN_STRENGTH, SETTINGS.BLUR_SCREEN_QUALITY)
    local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
    local screenshot = Screen.bb:copy()
    local screenshot_rotation = screenshot:getRotation()
    -- scaling back up handled by ImageWidget
    screenshot = mupdf.scaleBlitBuffer(screenshot, round(screen_w / quality), round(screen_h / quality))
    screenshot = gaussianBlur(screenshot, strength, kernel_size)
    
    local blur_widget = ImageWidget:new{
        name = "BlurWidget",
        image = screenshot,
        image_disposable = true,
        width = screen_w,
        height = screen_h,
        rotation_angle = screenshot_rotation * 90,
        scale_factor = 0,
    }

    return blur_widget
end


-- ================================================================
-- SCREENSAVER OVERRIDES
-- ================================================================

function ScreenSaverWidget:update()
    self.height = Screen:getHeight()
    self.width = Screen:getWidth()

    self.region = Geom:new{
        x = 0, y = 0,
        w = self.width,
        h = self.height,
    }
    
    local widget = self.widget
    if do_blur_screen(Screensaver) then
        local blur_widget = createBlurWidget()
        local overlap_widget = OverlapGroup:new{
            dimen = {
                h = self.width,
                w = self.height,
            },
            blur_widget,
            self.widget
        }
        widget = overlap_widget
    end
    
    self.main_frame = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = self.background,
        width = self.width,
        height = self.height,
        widget,
    }
    self.dithered = true
    self[1] = self.main_frame
end


local orig_screesaver_setup = Screensaver.setup

function Screensaver:setup(event, event_message)
    orig_screesaver_setup(self, event, event_message)
    if self.image and do_blur_cover(self) then
        local strength, quality, kernel_size = getBlurProperties(SETTINGS.BLUR_COVER_STRENGTH, SETTINGS.BLUR_COVER_QUALITY)
        local blur_cover = self.image:copy()
        blur_cover = mupdf.scaleBlitBuffer(blur_cover, round(self.image:getWidth() / quality), round(self.image:getHeight() / quality))
        blur_cover = gaussianBlur(blur_cover, strength, kernel_size)
        self.image = blur_cover
    end
end