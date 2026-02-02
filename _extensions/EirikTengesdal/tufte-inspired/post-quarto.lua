-- post-quarto.lua
-- This filter runs AFTER Quarto's internal processing to convert
-- column-margin figures to marginalia notes
-- ONLY FOR TYPST FORMAT

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [8] POST-QUARTO.LUA STARTING ==========") end

-- Check if we're rendering to Typst format
local function is_typst_format()
  return FORMAT == "typst"
end

-- Global storage for margin figures to process
local margin_figures_to_process = {}

-- First pass: collect margin figure information and mark for removal
function Div(el)
  -- Only process for Typst format
  if not is_typst_format() then
    return el
  end

  -- Check if this div has the margin figure marker we added in pre-quarto
  if el.classes:includes("column-margin") and el.attributes and el.attributes['data-margin-figure'] == 'true' then
    -- Look for quarto-scaffold divs within this column-margin div
    for i, content_elem in ipairs(el.content) do
      if content_elem.t == "Div" and content_elem.classes:includes("quarto-scaffold") then
        -- Collect information from all scaffold elements
        local image_src = ""
        local label = ""
        local caption_parts = {}

        -- Walk through the scaffold content to collect all information
        for j, scaffold_elem in ipairs(content_elem.content) do
          if scaffold_elem.t == "Plain" then
            for k, inline in ipairs(scaffold_elem.content) do
              if inline.t == "Image" then
                image_src = inline.src
              elseif inline.t == "RawInline" and inline.format == "typst" then
                local raw_content = inline.text
                -- Look for label in RawInline content
                local label_match = raw_content:match("<(fig%-[^>]+)>")
                if label_match then
                  label = label_match
                end
              elseif inline.t == "Str" then
                local text = inline.text or ""
                if text ~= "" and not text:match("^%s*$") and text ~= "position:" and text ~= "bottom," then
                  table.insert(caption_parts, text)
                end
              end
            end
          end
        end

        -- Store margin figure info for processing
        if image_src ~= "" then
          local caption_text = table.concat(caption_parts, " ")
          if caption_text == "" then
            caption_text = "Margin figure"
          end

          local label_part = label ~= "" and ("<" .. label .. ">") or ""

          -- Determine supplement text based on document language
          local supplement = "Figure" -- Default to English
          if PANDOC_STATE and PANDOC_STATE.meta and PANDOC_STATE.meta.lang then
            local lang = pandoc.utils.stringify(PANDOC_STATE.meta.lang)
            if lang == "nb" or lang == "no" or lang == "nn" then
              supplement = "Figur"
            end
          end

          -- Generate the marginalia note call
          local figure_call = "#note(numbering: none, shift: \"avoid\", dy: -0.5em)[" ..
                              "#figure(" ..
                              "image(\"" .. image_src .. "\"), " ..
                              "caption: [" .. caption_text .. "], " ..
                              "kind: \"quarto-float-fig\", " ..
                              "supplement: \"" .. supplement .. "\"" ..
                              ")" .. label_part ..
                              "]"

          -- Store for later processing
          table.insert(margin_figures_to_process, {
            note_call = figure_call,
            processed = false
          })
        end
      end
    end

    -- Remove the margin figure div
    return {}
  end

  return el
end

-- Second pass: modify the next paragraph to include the note call
function Para(el)
  -- Only process for Typst format
  if not is_typst_format() then
    return el
  end

  -- If we have unprocessed margin figures, prepend the note call to this paragraph
  for i, fig_info in ipairs(margin_figures_to_process) do
    if not fig_info.processed then
      -- Create a RawInline with the note call and prepend it to the paragraph
      local note_inline = pandoc.RawInline("typst", fig_info.note_call)
      table.insert(el.content, 1, note_inline)

      -- Mark as processed
      fig_info.processed = true
      break -- Only process one margin figure per paragraph
    end
  end

  return el
end

-- Helper to inspect elements
local function inspect_element(el, context)
  if not DEBUG then return end

  print(string.format("\n[POST-QUARTO:%s] Element tag: %s", context, tostring(el.t or "unknown")))

  -- Show available fields
  local fields = {}
  for k, v in pairs(el) do
    if type(k) == "string" and k ~= "t" and type(v) ~= "function" then
      table.insert(fields, k)
    end
  end
  if #fields > 0 then
    print(string.format("  [POST-QUARTO:%s] Available fields: %s", context, table.concat(fields, ", ")))
  end
end

-- Note: Table column customization now handled in wrap-wideblock.lua (before Quarto conversion)
-- No need for wideblock detection or Table modification here

-- Track wideblock nesting depth
local wideblock_depth = 0

-- Process RawBlocks
function RawBlock(el)
  if not is_typst_format() then
    return el
  end

  if el.format == "typst" then
    -- Check if this starts a wideblock
    if el.text:match("^#wideblock") then
      wideblock_depth = wideblock_depth + 1
      if DEBUG then
        print(string.format("[POST-QUARTO:RAWBLOCK] Entering wideblock (depth: %d)", wideblock_depth))
      end
    end

    -- Track bracket nesting within wideblock
    if wideblock_depth > 0 then
      -- Count opening brackets
      local open_count = 0
      for _ in el.text:gmatch("%[") do
        open_count = open_count + 1
      end

      -- Count closing brackets
      local close_count = 0
      for _ in el.text:gmatch("%]") do
        close_count = close_count + 1
      end

      -- Update depth
      wideblock_depth = wideblock_depth + open_count - close_count

      if DEBUG and (open_count > 0 or close_count > 0) then
        print(string.format("[POST-QUARTO:RAWBLOCK] Brackets: +%d -%d, new depth: %d", open_count, close_count, wideblock_depth))
      end
    end

    -- If we're in a wideblock, check for table with columns
    if wideblock_depth > 0 and el.text:match("#table%(") then
      local table_text = el.text

      -- Look for columns specification like: columns: (25%, auto, auto)
      local columns_match = table_text:match("columns:%s*%(([^)]+)%),")

      if columns_match then
        if DEBUG then
          print(string.format("[POST-QUARTO:RAWBLOCK] Found table with columns: %s", columns_match))
        end

        -- Parse column specifications
        local column_specs = {}
        for spec in columns_match:gmatch("([^,]+)") do
          spec = spec:match("^%s*(.-)%s*$") -- trim
          table.insert(column_specs, spec)
        end

        -- Calculate total percentage and count auto columns
        local total_percent = 0
        local auto_count = 0
        for _, spec in ipairs(column_specs) do
          if spec:match("%%$") then
            local num = tonumber(spec:match("^(.-)%%$"))
            if num then
              total_percent = total_percent + num
            end
          elseif spec == "auto" then
            auto_count = auto_count + 1
          end
        end

        -- Calculate fraction for auto columns
        local auto_fraction = auto_count > 0 and ((100 - total_percent) / auto_count) or 0

        -- Convert to fractional units
        local converted_specs = {}
        for _, spec in ipairs(column_specs) do
          local converted
          if spec:match("%%$") then
            local num = spec:match("^(.-)%%$")
            converted = num .. "fr"
          elseif spec == "auto" then
            converted = string.format("%.1ffr", auto_fraction)
          else
            converted = spec
          end
          table.insert(converted_specs, converted)
        end

        local new_columns = table.concat(converted_specs, ", ")

        if DEBUG then
          print(string.format("[POST-QUARTO:RAWBLOCK] Converting columns from (%s) to (%s)", columns_match, new_columns))
        end

        -- Replace the columns specification
        local new_text = table_text:gsub(
          "columns:%s*%(" .. columns_match:gsub("([%%%(%)%.])", "%%%1") .. "%)",
          "columns: (" .. new_columns .. ")"
        )

        el.text = new_text

        if DEBUG then
          print(string.format("[POST-QUARTO:RAWBLOCK] Updated table columns to fractional units"))
        end
      end
    end

    if DEBUG then
      inspect_element(el, "RAWBLOCK")
      print(string.format("[POST-QUARTO:RAWBLOCK] Text length: %d", string.len(el.text)))
      print(string.format("[POST-QUARTO:RAWBLOCK] First 100 chars: %s", string.sub(el.text, 1, 100)))
    end
  end

  return el
end

-- Generic Block handler to see what block types exist
function Block(block)
  if not is_typst_format() then
    return block
  end

  -- Only log first few blocks to avoid spam
  if not _block_count then
    _block_count = 0
  end

  if _block_count < 5 and block.t ~= "Para" and block.t ~= "Plain" then
    print(string.format("[POST-QUARTO] Block type: %s", block.t))
    _block_count = _block_count + 1
  end

  return block
end

-- Note: CodeBlock handling (automatic wide layout detection) now in margin_references.lua
-- which runs BEFORE Quarto's internal processing, where it can actually modify CodeBlocks
