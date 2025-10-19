-- Script: Split /move into /pos (custom segment length)
-- Usage: Select lines with /move tags and run
script_name = "Split '\\move' into '\\pos' (custom steps)"
script_description = "Splits a /move line into multiple /pos lines, one per N-frame segment."
script_author = "Le Chat"
script_version = "1.1"

-- Required for dialog
local haveDepCtrl, DependencyControl, depctrl = pcall(require, "l0.DependencyControl")
if haveDepCtrl then
    depctrl = DependencyControl{
        feed = "https://raw.githubusercontent.com/petzku/Aegisub-Scripts/stable/DependencyControl.json",
        {'karaskel'}
    }
    depctrl:requireModules()
else
    require 'karaskel'
end

local function replace_move_with_pos(text, x, y)
    -- Replace \move with \pos in the same position
    return text:gsub("\\move%b()", string.format("\\pos(%g,%g)", x, y))
end

function split_move_into_pos(subs, sel)
    -- Show dialog for user input
    local dialog_config = {
        {x = 0, y = 0, class = "label", label = "Enter the number of frames per segment:"},
        {x = 0, y = 1, class = "intedit", name = "frames_per_segment", value = 3, min = 1},
        {x = 0, y = 2, class = "checkbox", name = "delete_original", label = "Delete original line", value = false},
    }

    local pressed, results = aegisub.dialog.display(dialog_config, {"OK", "Cancel"})
    if pressed ~= "OK" then return end

    local frames_per_segment = results.frames_per_segment
    local delete_original = results.delete_original

    for _, line_number in ipairs(sel) do
        local line = subs[line_number]
        if not line.class == "dialogue" then
            aegisub.debug.out("Skipping non-dialogue line %d\n", line_number)
            goto continue
        end

        aegisub.debug.out("Processing line %d: %s\n", line_number, line.text)

        -- Extract \move parameters: {\move(x1,y1,x2,y2,t1,t2)}
        -- { .... \move(826.929,613.5,933,334.5,2,526) .... }
        local text = line.text
        local move_params = text:match("\\move%(([^)]+)%)")
        if not move_params then
            aegisub.debug.out("No \\move tag found, skipping line %d\n", line_number)
            goto continue
        end

        aegisub.debug.out("Found \\move parameters: %s\n", move_params)

        -- \move(826.929,613.5,933,334.5,2,526)
        local x1, y1, x2, y2, t1, t2 = move_params:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^)]+)")
        x1 = tonumber(x1)
        y1 = tonumber(y1)
        x2 = tonumber(x2)
        y2 = tonumber(y2)
        t1 = tonumber(t1) or 0
        t2 = tonumber(t2) or line.duration

        -- Calculate total movement
        local dx = x2 - x1
        local dy = y2 - y1
        local movement_start_frame = aegisub.frame_from_ms(line.start_time + t1)
        local movement_end_frame = aegisub.frame_from_ms(line.start_time + t2)
        aegisub.debug.out("line_start_frame: %d, line_end_frame: %d\n", movement_start_frame, movement_end_frame)

        local total_frames = movement_end_frame - movement_start_frame + 1
        aegisub.debug.out("total_frames: %d\n", total_frames)

        local num_segments = math.floor(total_frames / frames_per_segment)
        aegisub.debug.out("num_segments: %d\n", num_segments)
        if num_segments <= 1 then
            aegisub.debug.out("Not enough frames for splitting, skipping line %d\n", line_number)
            goto continue
        end

        local leading_static_frames = movement_start_frame - aegisub.frame_from_ms(line.start_time)
        local trailing_static_frames = aegisub.frame_from_ms(line.end_time) - movement_end_frame
        aegisub.debug.out("leading_static_frames: %d, trailing_static_frames: %d\n", leading_static_frames, trailing_static_frames)

        -- TODO: Adjust \t tags within the line to fit the new timing if necessary.
        -- \t(<style modifiers>)
        -- \t(<accel>,<style modifiers>)
        -- \t(<t1>,<t2>,<style modifiers>)
        -- \t(<t1>,<t2>,<accel>,<style modifiers>)
        if leading_static_frames > 0 then
            -- Create leading static segment
            local lead_end_time = aegisub.ms_from_frame(movement_start_frame)

            local lead_line = table.copy(line)
            lead_line.end_time = lead_end_time
            lead_line.text = replace_move_with_pos(text, x1, y1)

            subs.insert(line_number, lead_line)
            line_number = line_number + 1
        end

        -- Split into segments
        for seg = 0, num_segments - 1 do
            local seg_start_time = aegisub.ms_from_frame(movement_start_frame + seg * frames_per_segment)
            local seg_end_time = aegisub.ms_from_frame(movement_start_frame + (seg + 1) * frames_per_segment)
            local ratio = seg / num_segments
            local seg_x = x1 + ratio * dx
            local seg_y = y1 + ratio * dy

            -- TODO: Adjust \t tags within the line to fit the new timing if necessary.
            local new_line = table.copy(line)
            new_line.start_time = seg_start_time
            new_line.end_time = seg_end_time
            new_line.text = replace_move_with_pos(text, seg_x, seg_y)

            subs.insert(line_number + seg + 1, new_line)
        end

        -- TODO: Adjust \t tags within the line to fit the new timing if necessary.
        if trailing_static_frames > 0 then
            -- Create trailing static segment
            local trail_start_time = aegisub.ms_from_frame(movement_end_frame + 1)

            local trail_line = table.copy(line)
            trail_line.start_time = trail_start_time
            trail_line.text = replace_move_with_pos(text, x2, y2)

            subs.insert(line_number + num_segments + 1, trail_line)
        end

        -- Delete the original line if requested
        if delete_original then
            subs:delete(line_number)
        end

        ::continue::
    end
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, split_move_into_pos)