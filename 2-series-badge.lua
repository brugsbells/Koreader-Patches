--[[ User patch for KOReader to add series number badges and reorganize corner widgets ]]--
local Blitbuffer = require("ffi/blitbuffer")

--========================== [[Edit your preferences here]] ================================
local series_font_size = 0.4						-- Adjust from 0 to 1
local series_text_color = Blitbuffer.COLOR_WHITE 	-- Choose your desired color
local border_thickness = 2 							-- Adjust from 0 to 5
local border_corner_radius = 7					-- Adjust from 0 to 20
local border_color = Blitbuffer.COLOR_DARK_GRAY	-- Choose your desired color
local background_color = Blitbuffer.COLOR_GRAY_3 	-- Choose your desired color
local move_from_border = 5 							-- Choose how far in the badge should sit

--==========================================================================================

--========================== [[Do not modify this section]] ================================
local userpatch = require("userpatch")
local logger = require("logger")
local TextWidget = require("ui/widget/textwidget")
local FrameContainer = require("ui/widget/container/framecontainer")
local Font = require("ui/font")
local Screen = require("device").screen
local Size = require("ui/size")
local BD = require("ui/bidi")
local ReadCollection = require("readcollection")

local function patchCoverBrowserCornerWidgets(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    -- Store original MosaicMenuItem paintTo method
    local origMosaicMenuItemPaintTo = MosaicMenuItem.paintTo
    
    -- Override paintTo method to rearrange corner widgets and add series badges
    function MosaicMenuItem:paintTo(bb, x, y)
        -- We need to call the base InputContainer paintTo instead of the full original
        -- to avoid the original collection mark painting, then handle all overlays ourselves
        local InputContainer = require("ui/widget/container/inputcontainer")
        InputContainer.paintTo(self, bb, x, y)

        -- Get corner mark size (replicating the original logic)
        local corner_mark_size = math.floor(math.min(self.width, self.height) / 8)
        
        -- Paint shortcut icon (top-left, from original)
        if self.shortcut_icon then
            local ix
            if BD.mirroredUILayout() then
                ix = self.dimen.w - self.shortcut_icon.dimen.w
            else
                ix = 0
            end
            local iy = 0
            self.shortcut_icon:paintTo(bb, x+ix, y+iy)
        end

        -- Get the cover image widget (target) and dimensions
        local target = self[1] and self[1][1] and self[1][1][1]
        if not target or not target.dimen then
            return
        end

        -- Paint COLLECTION MARK in TOP-LEFT corner (moved from top-right)
        if self.menu.name ~= "collections" and ReadCollection:isFileInCollections(self.filepath) then
            -- Get collection_mark from the MosaicMenu module
            local collection_mark = userpatch.getUpValue(MosaicMenu._recalculateDimen, "collection_mark")
            if collection_mark then
                local ix, rect_ix
                if BD.mirroredUILayout() then
                    ix = self.width - math.ceil((self.width - target.dimen.w)/2) - corner_mark_size
                    rect_ix = 0
                else
                    ix = math.floor((self.width - target.dimen.w)/2)
                    rect_ix = target.bordersize
                end
                local iy = 0
                local rect_size = corner_mark_size - target.bordersize
                bb:paintRect(x+ix+rect_ix, target.dimen.y+target.bordersize, rect_size, rect_size, Blitbuffer.COLOR_GRAY)
                collection_mark:paintTo(bb, x+ix, target.dimen.y+iy)
            end
        end

        -- Paint SERIES NUMBER BADGE in TOP-RIGHT corner (new)
        if not self.is_directory and not self.file_deleted then
            local series_number = nil
            if self.filepath then
                local filename = self.filepath:match("([^/]+)$") or self.filepath
                -- Updated pattern to match both integers [03] and decimals [1.5]
                series_number = filename:match("%[([%d%.]+)%]")
            end
            
            if series_number then
                local num = tonumber(series_number)
                if num then
                    -- Keep decimal format if it's a decimal, otherwise show as integer
                    local series_text
                    if num == math.floor(num) then
                        series_text = "#" .. tostring(math.floor(num)) -- Remove .0 for whole numbers
                    else
                        series_text = "#" .. tostring(num) -- Keep decimals for non-whole numbers
                    end
                    
                    local font_size = math.floor(corner_mark_size * series_font_size)
            
                    local series_text_widget = TextWidget:new{
                        text = series_text,
                        face = Font:getFace("cfont", font_size),
                        alignment = "left",
                        fgcolor = series_text_color,
                        bold = true,
                        padding = 2,
                    }
                    
                    local series_badge = FrameContainer:new{
                        linesize = Screen:scaleBySize(2),
                        radius = Screen:scaleBySize(border_corner_radius),
                        color = border_color,
                        bordersize = border_thickness,
                        background = background_color,
                        padding_top = Screen:scaleBySize(2),
                        padding_bottom = Screen:scaleBySize(2),
                        padding_left = Screen:scaleBySize(4),  -- Extra horizontal padding
                        padding_right = Screen:scaleBySize(4), -- Extra horizontal padding
                        margin = 0,
                        series_text_widget,
                    }
                    
                    local cover_left = x + math.floor((self.width - target.dimen.w) / 2)
                    local cover_top = y + math.floor((self.height - target.dimen.h) / 2)
                    local badge_w, badge_h = series_badge:getSize().w, series_badge:getSize().h
                    
                    -- Position in top-right corner
                    local pad = Screen:scaleBySize(move_from_border)
                    local pos_x_badge = cover_left + target.dimen.w - badge_w - pad
                    local pos_y_badge = cover_top + pad
                    
                    series_badge:paintTo(bb, pos_x_badge, pos_y_badge)
                end
            end
        end

        -- Paint dogear (bottom-right, from original)
        if self.do_hint_opened and self.been_opened then
            -- Get the dogear marks from the MosaicMenu module
            local reading_mark = userpatch.getUpValue(MosaicMenu._recalculateDimen, "reading_mark")
            local abandoned_mark = userpatch.getUpValue(MosaicMenu._recalculateDimen, "abandoned_mark")
            local complete_mark = userpatch.getUpValue(MosaicMenu._recalculateDimen, "complete_mark")
            
            if reading_mark and abandoned_mark and complete_mark then
                local corner_mark
                if self.status == "abandoned" then
                    corner_mark = abandoned_mark
                elseif self.status == "complete" then
                    corner_mark = complete_mark
                else
                    corner_mark = reading_mark
                end
                
                local ix
                if BD.mirroredUILayout() then
                    ix = math.floor((self.width - target.dimen.w)/2)
                else
                    ix = self.width - math.ceil((self.width - target.dimen.w)/2) - corner_mark_size
                end
                local iy = self.height - math.ceil((self.height - target.dimen.h)/2) - corner_mark_size
                corner_mark:paintTo(bb, x+ix, y+iy)
            end
        end

        -- Paint progress bar (bottom, from original)
        if self.show_progress_bar then
            local progress_widget = userpatch.getUpValue(MosaicMenu._recalculateDimen, "progress_widget")
            if progress_widget then
                local progress_widget_margin = math.floor((corner_mark_size - progress_widget.height) / 2)
                progress_widget.width = target.width - 2*progress_widget_margin
                local pos_x = x + math.ceil((self.width - progress_widget.width) / 2)
                if self.do_hint_opened then
                    progress_widget.width = progress_widget.width - corner_mark_size
                    if BD.mirroredUILayout() then
                        pos_x = pos_x + corner_mark_size
                    end
                end
                local pos_y = y + self.height - math.ceil((self.height - target.height) / 2) - corner_mark_size + progress_widget_margin
                if self.status == "abandoned" then
                    progress_widget.fillcolor = Blitbuffer.COLOR_GRAY_6
                else
                    progress_widget.fillcolor = Blitbuffer.COLOR_BLACK
                end
                progress_widget:setPercentage(self.percent_finished)
                progress_widget:paintTo(bb, pos_x, pos_y)
            end
        end

        -- Paint description indicator (right edge, from original)
        if self.has_description and not require("bookinfomanager"):getSetting("no_hint_description") then
            local d_w = Screen:scaleBySize(3)
            local d_h = math.ceil(target.dimen.h / 8)
            local ix
            if BD.mirroredUILayout() then
                ix = - d_w + 1
                local x_overflow_left = x - target.dimen.x+ix
                if x_overflow_left > 0 then
                    self.refresh_dimen = self[1].dimen:copy()
                    self.refresh_dimen.x = self.refresh_dimen.x - x_overflow_left
                    self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_left
                end
            else
                ix = target.dimen.w - 1
                local x_overflow_right = target.dimen.x+ix+d_w - x - self.dimen.w
                if x_overflow_right > 0 then
                    self.refresh_dimen = self[1].dimen:copy()
                    self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_right
                end
            end
            local iy = 0
            bb:paintBorder(target.dimen.x+ix, target.dimen.y+iy, d_w, d_h, 1)
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserCornerWidgets)