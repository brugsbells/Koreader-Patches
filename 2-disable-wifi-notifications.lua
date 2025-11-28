local UIManager = require("ui/uimanager")
local logger = require("logger")

-- Save the original show function
local old_show = UIManager.show

-- Log to confirm the patch is active
print("[WifiPatch] V6 Nuclear Hook Loaded")

-- List of text patterns to block (lowercase)
local suppressed_patterns = {
    "connecting to",
    "scanning for",
    "connected to",
    "obtaining ip",
    "turning on",
	"turning off",
    "associating",
    "wi-fi",
    "network connection"
}

-- Helper to check text against our list
local function should_block(text)
    if not text or type(text) ~= "string" then return false end
    local s = text:lower()
    for _, pattern in ipairs(suppressed_patterns) do
        if s:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Hook the main UIManager:show function
-- This catches EVERYTHING that tries to appear on screen
UIManager.show = function(self, widget, ...)
    if widget then
        -- Check standard text properties used by various widgets
        local text_to_check = widget.text or widget.title
        
        -- Sometimes text is hidden inside a body table (complex widgets)
        if not text_to_check and type(widget.body) == "table" then
            text_to_check = widget.body.text
        end

        -- If we find a match, BLOCK IT
        if should_block(text_to_check) then
            print("[WifiPatch] BLOCKED POPUP: " .. tostring(text_to_check))
            return -- Return early without showing the widget
        end
    end

    -- If it's safe, let KOReader show it normally
    return old_show(self, widget, ...)
end