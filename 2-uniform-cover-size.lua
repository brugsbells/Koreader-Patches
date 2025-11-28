-- File: force_cover_stretch.lua
-- Description: Patches ImageWidget to look for 'max_img_w' and 'max_img_h' 
--              in the calling function (Mosaic/List Menu) and enforces 
--              20% stretch using those dimensions.

local ImageWidget = require("ui/widget/imagewidget")
local original_new = ImageWidget.new

function ImageWidget:new(t, ...)
    if type(t) == "table" and t.image then
        
        -- We need to find the dimensions (max_img_w/h) from the calling function.
        -- We scan the call stack (levels 2-5) for these local variables.
        
        local found_width, found_height = nil, nil
        local is_target_context = false

        for level = 2, 5 do
            local info = debug.getinfo(level, "f")
            if not info then break end

            local i = 1
            while true do
                local name, value = debug.getlocal(level, i)
                if not name then break end
                
                -- We look for 'cover_specs' to confirm we are in the right plugin
                if name == "cover_specs" then
                    is_target_context = true
                end
                
                -- We grab the dimensions calculated by the menu
                if name == "max_img_w" then
                    found_width = value
                elseif name == "max_img_h" then
                    found_height = value
                end
                
                i = i + 1
            end
            
            -- If we found everything we need in this level, stop looking
            if is_target_context and found_width and found_height then
                break
            end
            
            -- Reset for next level if we didn't find the full set
            found_width, found_height, is_target_context = nil, nil, false
        end

        -- If we found the context and the dimensions:
        if is_target_context and found_width and found_height then
            
            -- 1. INJECT the missing dimensions (Critical!)
            t.width = found_width
            t.height = found_height
            
            -- 2. Remove the aspect-ratio lock
            t.scale_factor = nil
            
            -- 3. Force the stretch limit
            t.stretch_limit_percentage = 20
            
        end
    end

    return original_new(self, t, ...)
end

return true