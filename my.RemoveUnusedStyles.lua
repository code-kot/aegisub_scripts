-- Script: Cleanup styles table
script_name = "Remove Unused Styles"
script_description = "Removes unused styles from the styles table"
script_version = "1.0.0"
script_author = "my"
script_namespace = "my.RemoveUnusedStyles"

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

function remove_unused_styles(subs, sel)
    local _, styles = karaskel.collect_head(subs, false)

    -- Collect used styles
    local used_styles = {}
    for i = 1, #subs do
        local line = subs[i]
        if line.class == "dialogue" then
            used_styles[line.style] = true
        end
    end

    -- Remove unused styles
    local new_styles = {}
    for i = 1, #styles do
        local style = styles[i]
        if used_styles[style.name] then
            table.insert(new_styles, style)
        else
            aegisub.debug.out("Removing unused style: %s\n", style.name)
        end
    end

    -- Rebuild styles table in subs
    local style_start_index = nil
    for i = 1, #subs do
        if subs[i].class == "style" then
            if not style_start_index then
                style_start_index = i
            end
        elseif style_start_index then
            break
        end
    end

    if style_start_index then
        -- Find the end index of the style block
        local style_end_index = style_start_index
        for i = style_start_index, #subs do
            if subs[i].class ~= "style" then
                style_end_index = i - 1
                break
            end
            style_end_index = i
        end

        -- Remove all old styles
        for i = style_end_index, style_start_index, -1 do
            subs:delete(i)
        end

        -- Insert all new styles at the correct position
        for i = #new_styles, 1, -1 do
            subs.insert(style_start_index - 1, new_styles[i])
        end
    end
end

if haveDepCtrl then
    depctrl:registerMacro(remove_unused_styles)
else
    aegisub.register_macro(script_name, script_description, remove_unused_styles)
end