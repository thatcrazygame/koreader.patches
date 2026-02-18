local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Device = require("device")
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local gettext = require("gettext")
local ImageWidget = require("ui/widget/imagewidget")
local lfs = require("libs/libkoreader-lfs")
local md5 = require("ffi/MD5")
local mupdf = require("ffi/mupdf")
local ffiUtil = require("ffi/util")
local OverlapGroup = require("ui/widget/overlapgroup")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderMenuOrder = require("ui/elements/reader_menu_order")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local Screen = Device.screen
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local util = require("util")

local T = ffiUtil.template

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
    --[[
        Put localizations inside this table
        i.e. 
        es = {
            ["Strength"] = "Fortaleza",
        }
    ]]--
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
-- UTILS
-- ================================================================

local function round(num) 
    -- assumes positive numbers
    return math.floor(num + 0.5)
end


function getFolderSize(dir)
    local size = 0
    for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local path = dir .. "/" .. file
            local attr = lfs.attributes(path)
            if attr.mode == "directory" then
                size = size + getFolderSize(path) -- Recursive call for subfolders
            else
                size = size + attr.size
            end
        end
    end
    return size
end


local function getBlurProperties(strength_setting, quality_setting)
    local strength = G_reader_settings:readSetting(strength_setting)
    local quality = MAX_QUALITY - G_reader_settings:readSetting(quality_setting) + 1
    local kernel_size = (4 * strength) + 1

    return strength, quality, kernel_size
end


local function getBlurCacheDir()
    local blur_cache_dir = DataStorage:getDataDir() .. "/patches/blurcache"
    if not util.directoryExists(blur_cache_dir) then
        util.makePath(blur_cache_dir)
    end
    return blur_cache_dir
end


local function getBlurFilePath(basename, strength, quality)
    local blur_cache = getBlurCacheDir()
    return T("%1/%2_blur_S-%3_Q-%4.png", blur_cache, basename, strength, quality)
end


local function cleanUpCache(starts_with, cache_file)
    local blur_cache = getBlurCacheDir()
    util.findFiles(blur_cache, function(file)
        if util.stringStartsWith(ffiUtil.basename(file), starts_with) and file ~= cache_file then
            util.removeFile(file)
        end
    end, false, nil)
end


local function deleteCache()
    util.findFiles(getBlurCacheDir(), function(file)
        util.removeFile(file)
    end, false, nil)
    util.removePath(getBlurCacheDir())
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
    local m, no_menu_pos = findItemFromPath(items, _("Do not show this book cover on sleep screen"))
    local m, msg_menu_pos = findItemFromPath(items, _("Sleep screen message"))
    local menu_idx = (no_menu_pos or msg_menu_pos or #items) + 1

    items[#items].separator = true
    table.insert(items, menu_idx, {
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
                true, enableCoverBlur
            ),
            {
                text_func = function()
                    local cache_size = getFolderSize(getBlurCacheDir())  / (1024 * 1024)
                    return string.format(_("Cache size: %.2f MB"), cache_size)
                end
            },
            {
                text = _("Empty cache"),
                keep_menu_open = false,
                callback = function(touchmenu_instance)
                    local ConfirmBox = require("ui/widget/confirmbox")
                    UIManager:show(ConfirmBox:new {
                        text = _("Are you sure that you want to delete the blur cache?"),
                        ok_text = _("Empty cache"),
                        ok_callback = function()
                            deleteCache()
                            local InfoMessage = require("ui/widget/infomessage")
                            UIManager:show(InfoMessage:new { text = _("Cache emptied.") })
                            touchmenu_instance:updateItems()
                        end
                    })
                    touchmenu_instance:updateItems()
                end,
            },
            {
                text = _("Delete cache: ") .. _("screen blur only"),
                callback = function(touchmenu_instance)
                    cleanUpCache("screen_", nil)
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new { text = _("Screen blur cache deleted") })
                    touchmenu_instance:updateItems()
                end,
            }
        }
    })

    if menu.name == "readermenu" then
        table.insert(items[menu_idx].sub_item_table, {
            text = _("Delete cache: ") .. _("this book only"),
            callback = function()
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new {
                    text = _("Are you sure that you want to delete this book's blur cover?"),
                    ok_text = _("Delete blur cover"),
                    ok_callback = function()
                        local lastfile = G_reader_settings:readSetting("lastfile")
                        local basename = util.splitFileNameSuffix(ffiUtil.basename(lastfile))
                        cleanUpCache(basename, nil)
                        local InfoMessage = require("ui/widget/infomessage")
                        UIManager:show(InfoMessage:new { text = _("Blur cover deleted.") })
                    end
                })
            end,
        })
    end
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
    local is_rgb = in_bb:isRGB() and Device:hasColorScreen()
    local out_type = Blitbuffer.TYPE_BB8
    local stride = width
    local pixel_stride = width
    if is_rgb then
        out_type = Blitbuffer.TYPE_BBRGB24
        stride = width * 3
    end
    local out_bb = Blitbuffer.new(width, height, out_type, nil, stride, pixel_stride)
    local kernel_size_offset = 1 + math.floor(#kernel / 2)
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Use this instead of a bb color because we don't want to overflow int8s
            local val = {
                a = 0,
                r = 0,
                g = 0,
                b = 0,
            }
            for i, weight in ipairs(kernel) do
                local offset = i - kernel_size_offset
                if x + offset < 0 or x + offset > width - 1 then offset = -1 * offset end
                local pix = in_bb:getPixel(x + offset, y)
                if is_rgb then
                    val.r = val.r + (pix:getR() * weight)
                    val.g = val.g + (pix:getG() * weight)
                    val.b = val.b + (pix:getB() * weight)
                else
                    val.a = val.a + (pix:getColor8().a * weight)
                end
            end
            for key, v in pairs(val) do
                val[key] = math.min(round(v), 255)
            end
            local color = Blitbuffer.Color8(val.a)
            if is_rgb then
                color = Blitbuffer.ColorRGB24(val.r, val.g, val.b)
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
    
    local blur_cache = getBlurCacheDir()
    local pre_blur_cache_file = getBlurFilePath("screen_pre", strength, quality)
    local blur_cache_file = blur_cache .. "/screen_blur.png"
    
    cleanUpCache("screen_pre_blur", pre_blur_cache_file)
    
    local cache_md5sum
    if util.pathExists(pre_blur_cache_file) then
        cache_md5sum = md5.sumFile(pre_blur_cache_file)
    end

    screenshot:writePNG(pre_blur_cache_file)

    if cache_md5sum == md5.sumFile(pre_blur_cache_file) and util.pathExists(blur_cache_file) then
        screenshot = mupdf.renderImageFile(blur_cache_file, nil, nil)
    else
        screenshot = mupdf.scaleBlitBuffer(screenshot, round(screen_w / quality), round(screen_h / quality))
        -- scaling back up handled by ImageWidget
        screenshot = gaussianBlur(screenshot, strength, kernel_size)
        screenshot:writePNG(blur_cache_file)
        screenshot = mupdf.renderImageFile(blur_cache_file, nil, nil)
    end
    
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

local orig_screensaverwidget_init = ScreenSaverWidget.init

function ScreenSaverWidget:init()
    local orig_widget = self.widget
    if do_blur_screen(Screensaver) then
        local blur_widget = createBlurWidget()
        local overlap_widget = OverlapGroup:new{
            dimen = {
                h = self.width,
                w = self.height,
            },
            blur_widget,
            orig_widget
        }
        self.widget = overlap_widget
    end
    orig_screensaverwidget_init(self)
end


local orig_screesaver_setup = Screensaver.setup

function Screensaver:setup(event, event_message)
    orig_screesaver_setup(self, event, event_message)
    if self.image and do_blur_cover(self) then
        local strength, quality, kernel_size = getBlurProperties(SETTINGS.BLUR_COVER_STRENGTH, SETTINGS.BLUR_COVER_QUALITY)
        
        local lastfile = G_reader_settings:readSetting("lastfile")
        local basename = util.splitFileNameSuffix(ffiUtil.basename(lastfile))
        local blur_cache_file = getBlurFilePath(basename, strength, quality)

        cleanUpCache(basename, blur_cache_file)
        
        local blur_cover
        if util.pathExists(blur_cache_file) then
            blur_cover = mupdf.renderImageFile(blur_cache_file, nil, nil)
        else
            blur_cover = self.image:copy()
            blur_cover = mupdf.scaleBlitBuffer(blur_cover, round(self.image:getWidth() / quality), round(self.image:getHeight() / quality))
            blur_cover = gaussianBlur(blur_cover, strength, kernel_size)
            blur_cover:writePNG(blur_cache_file)
            -- just reopening the file seems to be the easiest way to handle rotation
            blur_cover = mupdf.renderImageFile(blur_cache_file, nil, nil)
        end
        
        self.image = blur_cover
    end
end