local Dispatcher = require("dispatcher")
local FileManagerMenu = require("apps/filemanager/filemanagermenu")
-- local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")
local gettext = require("gettext")
local ReaderMenu = require("apps/reader/modules/readermenu")
-- local ReaderMenuOrder = require("ui/elements/reader_menu_order")
local userpatch = require("userpatch")
local logger = require("logger")

local PATCH_L10N = {
    en = {
        ["Set starts with location"] = "Set starts with location",
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

local function hasFunction(object, funcName)
    local func = object[funcName]
    return func ~= nil and type(func) == "function"
end

local function getStartsWithOptions()
    -- Copied from FileManagerMenu:getStartWithMenuTable()
    local start_withs = {
        { _("file browser"), "filemanager" },
        { _("history"), "history" },
        { _("favorites"), "favorites" },
        { _("folder shortcuts"), "folder_shortcuts" },
        { _("last file"), "last" },
    }
    
    -- could just hard code these tables, but want to be able to copy/paste the options for start_withs 
    -- or access them if they ever get moved to a non-local variable
    local start_names, start_texts = {}, {}
    for _, v in ipairs(start_withs) do
        local start_text, start_name = table.unpack(v)
        table.insert(start_names, start_name)
        table.insert(start_texts, start_text)
    end

    return start_names, start_texts
end

local function registerActions()
    Dispatcher:registerAction("set_starts_with", {
        category = "string",
        event = "SetStartsWith",
        title = _("Set starts with location"),
        args_func = getStartsWithOptions,
        general = true,
    })
end

local function initActions(Menu)
    if hasFunction(Menu, "onDispatcherRegisterActions") then
        local orig_onDispatcherRegisterActions = Menu.onDispatcherRegisterActions
        Menu.onDispatcherRegisterActions = function(self)
            orig_onDispatcherRegisterActions(self)
            registerActions()
        end
    else
        Menu.onDispatcherRegisterActions = function(self)
            registerActions()
        end
    end
    
    local orig_Menu_init = Menu.init
    function Menu:init()
        orig_Menu_init(self)
        self:onDispatcherRegisterActions()
    end

    function Menu:onSetStartsWith(start_with)
        G_reader_settings:saveSetting("start_with", start_with)
    end
end

initActions(FileManagerMenu)
initActions(ReaderMenu)