-- pre-quarto.lua
-- This filter runs BEFORE Quarto's internal processing
-- Mark column-margin divs for post-processing
-- ONLY FOR TYPST FORMAT

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [2] PRE-QUARTO.LUA STARTING ==========") end

-- Check if we're rendering to Typst format
local function is_typst_format()
  return FORMAT == "typst"
end

function Div(el)
  -- Only process for Typst format
  if not is_typst_format() then
    return el
  end

  -- Mark column-margin divs with a special attribute for post-processing
  if el.classes:includes('column-margin') then
    el.attributes['data-margin-figure'] = 'true'
    return el
  end
  return el
end
