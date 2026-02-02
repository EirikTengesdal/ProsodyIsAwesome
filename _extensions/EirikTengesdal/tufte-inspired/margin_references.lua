-- see https://github.com/quarto-dev/quarto-cli/discussions/10440

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [6] MARGIN_REFERENCES.LUA STARTING ==========") end

-- Counter to track sidenotes for TOC collision avoidance
local sidenote_counter = 0

-- Store footnotes from headings to re-insert after heading
local heading_footnotes = {}

-- Store toc-depth for header-level checking
local toc_depth = 1  -- Default depth

-- Track when we're inside a .column-margin div
local in_margin_div = false

-- Code block layout configuration (will be set from metadata in post-quarto.lua)
code_layout_mode = nil  -- Global variable
code_max_line_length = 60  -- Global variable
code_min_lines_for_wide = 15  -- Global variable

-- Helper function to read code layout settings from metadata
local function get_code_layout_settings()
  -- Access the document metadata via PANDOC_DOCUMENT if available
  if PANDOC_DOCUMENT and PANDOC_DOCUMENT.meta then
    local meta = PANDOC_DOCUMENT.meta
    local format_meta = meta['tufte-inspired-typst']

    local mode = 'auto'
    local max_length = 60
    local min_lines = 15

    -- Debug: print metadata structure
    print(string.format("[MARGIN_REF] Checking metadata... format_meta exists: %s", format_meta and "yes" or "no"))

    if format_meta and format_meta['code-block-layout'] then
      mode = pandoc.utils.stringify(format_meta['code-block-layout'])
      print(string.format("[MARGIN_REF] Found mode in format_meta: %s", mode))
    elseif meta['code-block-layout'] then
      mode = pandoc.utils.stringify(meta['code-block-layout'])
      print(string.format("[MARGIN_REF] Found mode in meta: %s", mode))
    end

    if format_meta and format_meta['code-max-line-length'] then
      max_length = tonumber(pandoc.utils.stringify(format_meta['code-max-line-length']))
      print(string.format("[MARGIN_REF] Found max_length in format_meta: %d", max_length))
    elseif meta['code-max-line-length'] then
      max_length = tonumber(pandoc.utils.stringify(meta['code-max-line-length']))
      print(string.format("[MARGIN_REF] Found max_length in meta: %d", max_length))
    end

    if format_meta and format_meta['code-min-lines-for-wide'] then
      min_lines = tonumber(pandoc.utils.stringify(format_meta['code-min-lines-for-wide']))
      print(string.format("[MARGIN_REF] Found min_lines in format_meta: %d", min_lines))
    elseif meta['code-min-lines-for-wide'] then
      min_lines = tonumber(pandoc.utils.stringify(meta['code-min-lines-for-wide']))
      print(string.format("[MARGIN_REF] Found min_lines in meta: %d", min_lines))
    end

    return mode, max_length, min_lines
  else
    print("[MARGIN_REF] PANDOC_DOCUMENT.meta not available!")
  end

  return 'auto', 60, 15  -- defaults
end

function Meta(meta)
  -- Read code-block-layout setting from YAML
  -- Check both top-level and nested under format name
  local format_meta = meta['tufte-inspired-typst']

  if format_meta and format_meta['code-block-layout'] then
    code_layout_mode = pandoc.utils.stringify(format_meta['code-block-layout'])
  elseif meta['code-block-layout'] then
    code_layout_mode = pandoc.utils.stringify(meta['code-block-layout'])
  else
    code_layout_mode = 'auto'  -- Default to auto
  end

  -- Read custom thresholds if provided
  if format_meta and format_meta['code-max-line-length'] then
    code_max_line_length = tonumber(pandoc.utils.stringify(format_meta['code-max-line-length']))
  elseif meta['code-max-line-length'] then
    code_max_line_length = tonumber(pandoc.utils.stringify(meta['code-max-line-length']))
  else
    code_max_line_length = 60
  end

  if format_meta and format_meta['code-min-lines-for-wide'] then
    code_min_lines_for_wide = tonumber(pandoc.utils.stringify(format_meta['code-min-lines-for-wide']))
  elseif meta['code-min-lines-for-wide'] then
    code_min_lines_for_wide = tonumber(pandoc.utils.stringify(meta['code-min-lines-for-wide']))
  else
    code_min_lines_for_wide = 15
  end

  -- Debug output
  print(string.format("[MARGIN_REF] Meta() setting globals: mode=%s, max_length=%d, min_lines=%d",
    code_layout_mode or "nil", code_max_line_length, code_min_lines_for_wide))

  return meta
end

function Block(block)
  -- Debug: log first few block types to see what exists
  if FORMAT ~= "typst" then
    return block
  end

  if not _block_count_margin then
    _block_count_margin = 0
    _codeblock_count = 0
    _rawblock_count = 0
  end

  if block.t == "CodeBlock" then
    _codeblock_count = _codeblock_count + 1
    print(string.format("[MARGIN_REF] Found CodeBlock #%d", _codeblock_count))
  end

  -- Print content of first few RawBlocks (any format)
  if block.t == "RawBlock" then
    _rawblock_count = _rawblock_count + 1
    if _rawblock_count <= 5 then
      local preview = (block.text or ""):gsub("\n", " "):sub(1, 80)
      print(string.format("[MARGIN_REF] RawBlock #%d (format: %s): %s",
        _rawblock_count, block.format or "nil", preview))
    end
  end

  if _block_count_margin < 10 and block.t ~= "Para" and block.t ~= "Plain" then
    print(string.format("[MARGIN_REF] Block type: %s", block.t))
    _block_count_margin = _block_count_margin + 1
  end

  return block
end

function CodeBlock(block)
  print(string.format("[MARGIN_REF] !!!! CodeBlock function called! Classes: %s", table.concat(block.classes, ", ")))

  -- Only process for Typst format
  if FORMAT ~= "typst" then
    print("[MARGIN_REF] Skipping - not typst format")
    return block
  end

  -- Use global variables set by Meta() function
  -- If Meta() hasn't run yet, globals will still be at their initial values
  local mode = code_layout_mode or 'auto'
  local max_length = code_max_line_length or 60
  local min_lines = code_min_lines_for_wide or 15

  print(string.format("[MARGIN_REF] Settings from globals: mode=%s, max_length=%d, min_lines=%d",
    mode, max_length, min_lines))

  -- If manual mode and no wideblock class, return as-is
  if mode == 'manual' then
    if not block.classes:includes('wideblock') then
      return block
    end
  end

  -- Determine if this block should be wide
  local should_be_wide = false

  if mode == 'wide' then
    -- Force all code blocks to be wide
    should_be_wide = true
  elseif mode == 'normal' then
    -- Force all code blocks to normal width
    should_be_wide = false
  elseif mode == 'auto' or block.classes:includes('wideblock') then
    -- Auto-detect or explicitly marked as wideblock
    local lines = {}
    for line in block.text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    -- Check max line length
    local max_len = 0
    for _, line in ipairs(lines) do
      if #line > max_len then
        max_len = #line
      end
    end

    -- Debug output
    print(string.format("[MARGIN_REF] CodeBlock: %d lines, max length %d (threshold: %d, min lines: %d)",
      #lines, max_len, max_length, min_lines))

    -- Check if should be wide based on line length or total lines
    if max_len > max_length or #lines >= min_lines then
      should_be_wide = true
      print("  -> Making WIDE")
    else
      print("  -> Keeping normal")
    end
  end

  -- If should be wide, wrap in a wideblock div
  if should_be_wide then
    local div = pandoc.Div({block})
    div.classes:insert('wideblock')
    return div
  end

  return block
end

function Cite(cite)
  -- Only process citations for Typst format
  if FORMAT ~= "typst" then
    return cite
  end

  local citation = cite.citations[1]
  local key = citation.id

  -- Skip table references, figure references, and other cross-references
  if key:match("^tbl%-") or key:match("^fig%-") or key:match("^eq%-") or key:match("^sec%-") then
    return cite
  end

  -- Deconstruct the citation object
  local mode = citation.mode or "NormalCitation"
  local prefix = citation.prefix and pandoc.utils.stringify(citation.prefix) or "none"
  local suffix = citation.suffix and pandoc.utils.stringify(citation.suffix) or "none"
  local locator = citation.locator or "none"
  local label = citation.label or "none"

  -- Use margincite() if inside a .column-margin div, otherwise sidecite()
  local cite_function = in_margin_div and "margincite" or "sidecite"

  -- Create a Typst function call with deconstructed parts
  local typst_call = string.format(
      '#%s(<%s>, "%s", "%s", "%s", %s, %s)',
      cite_function, key, mode, prefix, suffix, locator, label
  )

  return pandoc.Inlines({
      pandoc.RawInline('typst', typst_call)
  })
end

-- Helper function to normalize quotes (smart quotes → straight quotes)
local function normalize_quotes(str)
  if type(str) ~= "string" then
    print("[DEBUG normalize_quotes] Input is not a string, type: " .. type(str))
    return str
  end

  print("[DEBUG normalize_quotes] BEFORE: " .. str)
  print("[DEBUG normalize_quotes] BEFORE byte codes: " .. string.format("%q", str))

  -- Replace smart/curly quotes with straight quotes for Typst compatibility
  str = str:gsub('"', '"')  -- Left double quotation mark
  str = str:gsub('"', '"')  -- Right double quotation mark
  str = str:gsub("'", "'")  -- Left single quotation mark
  str = str:gsub("'", "'")  -- Right single quotation mark

  print("[DEBUG normalize_quotes] AFTER: " .. str)
  print("[DEBUG normalize_quotes] AFTER byte codes: " .. string.format("%q", str))

  return str
end

-- Convert footnotes to marginalia sidenotes
function Note(note)
  -- Only process for Typst format
  if FORMAT ~= "typst" then
    return note
  end

  -- Extract attributes from footnote content if present
  -- Pattern: {key=value key2="value 2"} at the start of the first paragraph
  local note_attrs = {}
  local content_without_attrs = note.content

  if #note.content > 0 and (note.content[1].t == "Para" or note.content[1].t == "Plain") then
    local first_para = note.content[1]
    if #first_para.content > 0 then
      local first_inline = first_para.content[1]
      print(string.format("[SIDENOTE] First inline type: %s, text: %s", first_inline.t, tostring(first_inline.text)))

      -- Check if first inline is Str starting with "{"
      if first_inline.t == "Str" and first_inline.text:match("^%{") then
        -- Extract the full attribute string by collecting text until we find the closing "}"
        local attr_text = ""
        local found_closing = false
        local inlines_to_remove = 0

        for i, inline in ipairs(first_para.content) do
          local text = ""
          if inline.t == "Str" then
            text = inline.text
          elseif inline.t == "Space" then
            text = " "
          elseif inline.t == "Quoted" then
            -- Handle Pandoc's Quoted inline (converts smart quotes to straight quotes)
            -- QuoteType can be SingleQuote or DoubleQuote
            local quote_char = '"'  -- Default to double quote
            if inline.quotetype == "SingleQuote" then
              quote_char = "'"
            end
            -- Use inline.content (the actual content) not stringify (which includes quotes)
            local quoted_content = pandoc.utils.stringify(pandoc.Span(inline.content))
            text = quote_char .. quoted_content .. quote_char
          else
            -- Stop at any other inline type
            break
          end

          attr_text = attr_text .. text
          inlines_to_remove = i

          if text:match("%}") then
            found_closing = true
            break
          end
        end

        if found_closing then
          -- Parse attributes from the collected text
          -- Remove { } braces
          local attrs_str = attr_text:match("^%{(.-)%}")

          if attrs_str then
            print("[DEBUG] RAW attrs_str BEFORE normalization: " .. attrs_str)
            print("[DEBUG] RAW attrs_str byte codes: " .. string.format("%q", attrs_str))

            -- CRITICAL: Normalize quotes BEFORE parsing
            attrs_str = normalize_quotes(attrs_str)

            print("[DEBUG] NORMALIZED attrs_str AFTER normalization: " .. attrs_str)
            print("[DEBUG] NORMALIZED attrs_str byte codes: " .. string.format("%q", attrs_str))
            print("[SIDENOTE] Found inline attributes: " .. attrs_str)

            -- Parse key=value or key="value with spaces"
            -- More robust pattern that handles quoted and unquoted values
            local remaining = attrs_str
            while remaining and remaining ~= "" do
              -- Skip leading whitespace
              remaining = remaining:match("^%s*(.*)$")

              -- Try to match key="quoted value"
              local key, quoted_value, rest = remaining:match('^([%w%-]+)="([^"]*)"(.*)$')
              if key then
                note_attrs[key] = quoted_value  -- Already normalized above
                print(string.format("[SIDENOTE] Parsed attribute: %s = \"%s\"", key, quoted_value))
                remaining = rest
              else
                -- Try to match key=unquoted_value
                key, unquoted_value, rest = remaining:match('^([%w%-]+)=([^%s}]+)(.*)$')
                if key then
                  note_attrs[key] = unquoted_value  -- Already normalized above
                  print(string.format("[SIDENOTE] Parsed attribute: %s = %s", key, unquoted_value))
                  remaining = rest
                else
                  -- No more matches
                  break
                end
              end
            end

            -- Remove the attribute inlines from the content
            for i = 1, inlines_to_remove do
              table.remove(first_para.content, 1)
            end

            -- Remove leading space if present
            if #first_para.content > 0 and first_para.content[1].t == "Space" then
              table.remove(first_para.content, 1)
            end

            -- Update content without attributes
            content_without_attrs = note.content
          end
        end
      end
    end
  end

  -- DEBUG: Print raw note content
  print("\n=== FOOTNOTE DEBUG START ===")
  print("Number of blocks in footnote:", #content_without_attrs)
  for i, block in ipairs(content_without_attrs) do
    print(string.format("Block %d type: %s", i, block.t))
    if block.t == "Para" or block.t == "Plain" then
      print(string.format("Block %d has %d inlines", i, #block.content))
      for j, inline in ipairs(block.content) do
        print(string.format("  Inline %d type: %s, content: %s", j, inline.t, pandoc.utils.stringify(inline)))
      end
    end
  end

  -- Walk through the footnote content and process any citations
  local processed_content = pandoc.walk_block(pandoc.Div(content_without_attrs), {
    Cite = Cite
  }).content

  -- Convert footnote content to Typst format preserving all formatting
  -- Use pandoc.write to convert blocks to typst, which handles all inline formatting
  local content_str = pandoc.write(pandoc.Pandoc(processed_content), 'typst')

  -- Clean up the output:
  -- 1. Remove leading/trailing whitespace
  content_str = content_str:gsub("^%s+", ""):gsub("%s+$", "")
  -- 2. Normalize quotes for Typst compatibility
  content_str = normalize_quotes(content_str)
  -- 3. Preserve paragraph breaks, list formatting, while removing line-wrapping newlines
  --    a) Replace double newlines (paragraph breaks) with placeholder
  content_str = content_str:gsub("\n\n+", "<<<PARBREAK>>>")
  --    b) Protect newlines before list items (bullet and numbered)
  content_str = content_str:gsub("\n([-+*]%s)", "<<<LISTITEM>>>%1")
  content_str = content_str:gsub("\n(%d+%.%s)", "<<<LISTITEM>>>%1")
  --    c) Replace remaining single newlines (line wrapping) with spaces
  content_str = content_str:gsub("\n", " ")
  --    d) Restore paragraph breaks and list items with Typst newlines
  content_str = content_str:gsub("<<<PARBREAK>>>", "\n\n")
  content_str = content_str:gsub("<<<LISTITEM>>>", "\n")
  --    e) Strip all leading whitespace from each line
  content_str = content_str:gsub("\n%s+", "\n")
  -- 4. Collapse multiple spaces into single space (but preserve newlines)
  content_str = content_str:gsub(" +", " ")

  print("Final combined string:", content_str)
  print("=== FOOTNOTE DEBUG END ===\n")

  -- Increment sidenote counter
  sidenote_counter = sidenote_counter + 1

  -- Build parameter list from note attributes (same as .column-margin)
  local string_params = {
    alignment = true,
    side = true,
  }

  local auto_or_string_params = {
    ["anchor-numbering"] = true,
    ["flush-numbering"] = true,
    shift = true,
  }

  local params = {}

  -- Map of attribute names to marginalia parameter names
  local param_map = {
    dy = "dy",
    alignment = "alignment",
    shift = "shift",
    ["keep-order"] = "keep-order",
    side = "side",
  }

  for attr_name, param_name in pairs(param_map) do
    local value = note_attrs[attr_name]
    if value ~= nil then
      print(string.format("[DEBUG] Building param for %s, value: %s, byte codes: %q", attr_name, value, value))

      -- Format the value appropriately
      if string_params[attr_name] then
        local formatted = string.format('%s: "%s"', param_name, value)
        print(string.format("[DEBUG] String param formatted: %s, byte codes: %q", formatted, formatted))
        table.insert(params, formatted)
      elseif auto_or_string_params[attr_name] then
        if value == "auto" or value == "true" or value == "false" or value == "none" then
          table.insert(params, string.format('%s: %s', param_name, value))
        else
          table.insert(params, string.format('%s: "%s"', param_name, value))
        end
      elseif value == "true" or value == "false" or value == "none" or value == "auto" then
        table.insert(params, string.format('%s: %s', param_name, value))
      else
        -- Numbers, lengths, etc.
        table.insert(params, string.format('%s: %s', param_name, value))
      end
    end
  end

  local params_str = ""
  if #params > 0 then
    params_str = table.concat(params, ", ")
    print("[DEBUG] Final params_str: " .. params_str)
    print("[DEBUG] Final params_str byte codes: " .. string.format("%q", params_str))
  end

  -- Call sidenote with named parameters before content
  local typst_call
  if params_str ~= "" then
    typst_call = string.format('#sidenote(%s)[%s]', params_str, content_str)
  else
    typst_call = string.format('#sidenote()[%s]', content_str)
  end

  print("[DEBUG] Final typst_call: " .. typst_call)
  print("[DEBUG] Final typst_call byte codes: " .. string.format("%q", typst_call))

  return pandoc.RawInline('typst', typst_call)
end

-- Handle .aside spans for unnumbered margin notes
function Span(span)
  -- Only process for Typst format
  if FORMAT ~= "typst" then
    return span
  end

  -- Check if span has .aside class
  if span.classes:includes('aside') then
    -- Convert span content to Typst format preserving formatting
    -- Wrap inlines in a Para for pandoc.write
    local content_str = pandoc.write(pandoc.Pandoc({pandoc.Para(span.content)}), 'typst')

    -- Clean up the output
    content_str = content_str:gsub("^%s+", ""):gsub("%s+$", "")
    content_str = normalize_quotes(content_str)
    -- Clean up: strip leading whitespace first, then preserve paragraph breaks and list formatting
    content_str = content_str:gsub("\n[ \t]+", "\n")
    content_str = content_str:gsub("\n\n+", "<<<PARBREAK>>>")
    content_str = content_str:gsub("\n([-+*]%s)", "<<<LISTITEM>>>%1")
    content_str = content_str:gsub("\n(%d+%.%s)", "<<<LISTITEM>>>%1")
    content_str = content_str:gsub("\n", " ")
    content_str = content_str:gsub("<<<PARBREAK>>>", "\n\n")
    content_str = content_str:gsub("<<<LISTITEM>>>", "\n")
    -- Collapse multiple spaces
    content_str = content_str:gsub(" +", " ")

    -- Create an unnumbered margin note
    local typst_call = string.format(
      '#marginnote[%s]',
      content_str
    )

    return pandoc.RawInline('typst', typst_call)
  end

  return span
end


-- -- inspired by: https://github.com/quarto-ext/typst-templates  ams/_extensions/ams/ams.lua
local function endTypstBlock(blocks)
    print("[MARGIN_REFERENCES.LUA] endTypstBlock called with " .. #blocks .. " blocks")
    local lastBlock = blocks[#blocks]
    print("[MARGIN_REFERENCES.LUA] Last block type: " .. lastBlock.t)
    if lastBlock.t == "Para" or lastBlock.t == "Plain" then
      print("[MARGIN_REFERENCES.LUA] Adding RawInline ']' to last Para/Plain block")
      lastBlock.content:insert(pandoc.RawInline('typst', ']'))
      return blocks
    else
      print("[MARGIN_REFERENCES.LUA] Adding RawBlock ']' as new block")
      blocks:insert(pandoc.RawBlock('typst', ']'))
      print("[MARGIN_REFERENCES.LUA] Returning blocks after insert")
      return blocks
    end
end

  -- Process at Pandoc level to append margin notes to previous blocks
  function Pandoc(doc)
    local blocks = doc.blocks
    local new_blocks = pandoc.List()
    local i = 1

    while i <= #blocks do
      local current = blocks[i]

      -- Check if this is a .column-margin div
      if current.t == "Div" and current.classes:includes('column-margin') then
        -- Check if content contains R output divs - recursively search entire tree
        local has_r_output = false
        local function check_for_r_output(element)
          if element.t == "Div" and (element.classes:includes('cell-output') or
                                     element.classes:includes('cell-output-stdout') or
                                     element.classes:includes('cell-output-stderr') or
                                     element.classes:includes('cell') or
                                     element.classes:includes('hidden')) then
            has_r_output = true
            return  -- Stop walking once found
          end
        end

        pandoc.walk_block(current, {Div = check_for_r_output})

        if has_r_output then
          print("[MARGIN_REFERENCES.LUA] Skipping .column-margin with R output (would cause filter chain error)")
          new_blocks:insert(current)
          i = i + 1
        else
          -- Extract marginalia parameters from div attributes
          -- Define which parameters expect string values (need quotes)
          local string_params = {
            alignment = true,
            side = true,
          }

        -- Define which parameters accept "auto" or string values (conditional quotes)
        local auto_or_string_params = {
          ["anchor-numbering"] = true,
          ["flush-numbering"] = true,
          shift = true,
        }

        -- Build parameter list from attributes
        local params = {}

        -- Map of attribute names to marginalia parameter names
        local param_map = {
          counter = "counter",
          numbering = "numbering",
          ["anchor-numbering"] = "anchor-numbering",
          ["link-anchor"] = "link-anchor",
          ["flush-numbering"] = "flush-numbering",
          side = "side",
          alignment = "alignment",
          dy = "dy",
          ["keep-order"] = "keep-order",
          shift = "shift",
        }

        for attr_name, param_name in pairs(param_map) do
          local value = current.attributes[attr_name]
          if value ~= nil then
            -- Format the value appropriately
            if string_params[attr_name] then
              -- Always quote
              table.insert(params, string.format('%s: "%s"', param_name, value))
            elseif auto_or_string_params[attr_name] then
              -- Quote unless it's auto, true, false, or none
              if value == "auto" or value == "true" or value == "false" or value == "none" then
                table.insert(params, string.format('%s: %s', param_name, value))
              else
                table.insert(params, string.format('%s: "%s"', param_name, value))
              end
            elseif value == "true" or value == "false" or value == "none" or value == "auto" then
              -- Boolean/special keywords
              table.insert(params, string.format('%s: %s', param_name, value))
            else
              -- Numbers, lengths, etc.
              table.insert(params, string.format('%s: %s', param_name, value))
            end
          end
        end

        local params_str = table.concat(params, ", ")

        -- Process citations inside margin div content
        -- Set flag to use margincite() instead of sidecite()
        in_margin_div = true
        local processed_content = pandoc.Pandoc(current.content):walk({
          Cite = Cite
        }).blocks
        in_margin_div = false

        -- Convert blocks to Typst format preserving all formatting
        local content_typst = pandoc.write(pandoc.Pandoc(processed_content), 'typst')

        print("=== MARGIN DIV CLEANUP DEBUG ===")
        print("After pandoc.write:")
        print(content_typst)
        print("Byte repr:", string.format("%q", content_typst))
        print("---")

        -- Clean up the output:
        -- 1. Remove leading/trailing whitespace
        content_typst = content_typst:gsub("^%s+", ""):gsub("%s+$", "")
        print("After trim:")
        print(content_typst)
        print("---")

        -- 2. Normalize quotes for Typst compatibility
        content_typst = normalize_quotes(content_typst)
        print("After normalize_quotes:")
        print(content_typst)
        print("---")

        -- 3. Clean up: preserve paragraph breaks and list formatting WITH indentation
        -- Save paragraph breaks first
        content_typst = content_typst:gsub("\n\n+", "<<<PARBREAK>>>")
        print("After saving paragraph breaks:")
        print(content_typst)
        print("---")

        -- Save list items WITH their indentation (capture spaces before markers)
        content_typst = content_typst:gsub("\n([ \t]*)([-+*]%s)", "<<<LISTITEM>>>%1%2")
        content_typst = content_typst:gsub("\n([ \t]*)(%d+%.%s)", "<<<LISTITEM>>>%1%2")
        print("After saving list items with indentation:")
        print(content_typst)
        print("Byte repr:", string.format("%q", content_typst))
        print("---")

        -- Strip leading whitespace from non-list lines
        content_typst = content_typst:gsub("\n[ \t]+", "\n")
        print("After stripping leading whitespace:")
        print(content_typst)
        print("---")

        -- Remove line wrapping
        content_typst = content_typst:gsub("\n", " ")
        print("After removing line wrapping:")
        print(content_typst)
        print("---")

        -- Restore breaks
        content_typst = content_typst:gsub("<<<PARBREAK>>>", "\n\n")
        content_typst = content_typst:gsub("<<<LISTITEM>>>", "\n")
        print("After restoring breaks:")
        print(content_typst)
        print("---")

        -- No space collapsing - preserves list indentation
        print("Final result:")
        print(content_typst)
        print("Byte repr:", string.format("%q", content_typst))
        print("=== MARGIN DIV CLEANUP DEBUG END ===")

        -- Build margin note with dynamic parameters using sidenote with numbering: none
        -- This ensures same counter handling as numbered sidenotes
        -- Must also set anchor-numbering: none to prevent superscript numbers in text
        local full_params = params_str ~= ""
          and string.format("numbering: none, anchor-numbering: none, %s", params_str)
          or "numbering: none, anchor-numbering: none"

        -- Check if content has nested lists (indented list markers = 2+ spaces before -, +, *, or digit.)
        local has_nested_lists = content_typst:match("\n  +[-+*]") or content_typst:match("\n  +%d+%.")
        
        -- Apply first-line-indent: 0em to all margin notes
        -- Only apply list marker workaround if nested lists are present
        -- Typst's default markers: [•], [‣], [–] cycling by depth
        -- NOTE: Depth doesn't reset to 0 when sidenote anchor is inside a list item
        -- Workaround: duplicate first marker ([•], [•], [‣], [–]) so depth 1→•, 2→‣, 3→–
        local margin_note_code
        if has_nested_lists then
          margin_note_code = string.format('#sidenote(%s)[#set par(first-line-indent: 0em); #set list(marker: depth => ([•], [•], [‣], [–]).at(calc.rem(depth, 4)), indent: 0.5em, body-indent: 0.5em); %s]',
            full_params, content_typst)
        else
          margin_note_code = string.format('#sidenote(%s)[#set par(first-line-indent: 0em); %s]', full_params, content_typst)
        end

        print("=== FINAL MARGIN NOTE CODE ===")
        print(margin_note_code)
        print("Byte repr:", string.format("%q", margin_note_code))
        print("=== END FINAL ===")


        local margin_note_inline = pandoc.RawInline('typst', margin_note_code)

        -- Strategy: append to previous block if suitable
        if #new_blocks > 0 then
          local prev = new_blocks[#new_blocks]

          if prev.t == "Para" or prev.t == "Plain" then
            prev.content:insert(margin_note_inline)
          elseif prev.t == "BulletList" or prev.t == "OrderedList" then
            local last_item = prev.content[#prev.content]
            local last_block = last_item[#last_item]
            if last_block and (last_block.t == "Para" or last_block.t == "Plain") then
              last_block.content:insert(margin_note_inline)
            end
          elseif prev.t == "Header" then
            -- For headers, create proper outline structure that hides margin notes from TOC
            local header_text = pandoc.utils.stringify(prev.content)
            local label_code = prev.identifier ~= "" and string.format(" <%s>", prev.identifier) or ""

            -- Generate structure with invisible heading for TOC and visible heading with sidenote
            local header_with_note = string.format([=[#{
  show heading: none
  heading(level: %d, outlined: true)[%s]
  counter(heading).update((..nums) => {
    let arr = nums.pos()
    arr.slice(0, -1) + (arr.last() - 1,)
  })
}#heading(level: %d, outlined: false)[%s%s]%s]=],
              prev.level, header_text,
              prev.level, header_text, margin_note_code, label_code)

            -- Replace the header with a RawBlock
            new_blocks[#new_blocks] = pandoc.RawBlock('typst', header_with_note)
          elseif prev.t == "Div" and prev.classes:includes("wideblock") then
            -- Margin note follows a wideblock - add vertical spacing for Tufte style
            -- Inject dy and shift parameters if not already present
            local modified_note = margin_note_code
            if not margin_note_code:match("dy%s*:") then
              -- Add dy: 1em and shift: "ignore" for spacing after wideblock
              -- Both parameters needed: shift: "ignore" prevents marginalia from overriding dy
              -- 1em matches marginalia's default collision avoidance offset
              modified_note = margin_note_code:gsub("^(#sidenote%()(.-)(%))(%[)", function(start, params, close, bracket)
                local new_params = params ~= "" and params .. ', dy: 1em, shift: "ignore"' or 'dy: 1em, shift: "ignore"'
                return string.format("%s%s%s%s", start, new_params, close, bracket)
              end)
            end
            
            -- Create standalone Plain block with offset margin note
            local plain_block = pandoc.Plain({pandoc.RawInline('typst', modified_note)})
            table.insert(new_blocks, plain_block)
          else
            -- For other blocks, create standalone Plain block
            local plain_block = pandoc.Plain({margin_note_inline})
            table.insert(new_blocks, plain_block)
          end
        else
          local plain_block = pandoc.Plain({margin_note_inline})
          new_blocks:insert(plain_block)
        end
        end  -- end of else (no R output)
      else
        -- Not a .column-margin div, keep as-is
        new_blocks:insert(current)
      end

      i = i + 1
    end

    return pandoc.Pandoc(new_blocks, doc.meta)
  end

  function Div(el)
    print("\n[MARGIN_REFERENCES.LUA] Div function called")
    print("[MARGIN_REFERENCES.LUA] Div classes: " .. table.concat(el.classes, ", "))
    print("[MARGIN_REFERENCES.LUA] FORMAT: " .. tostring(FORMAT))

    -- Skip R code output divs to avoid filter chain issues
    if el.classes:includes('cell-output') or el.classes:includes('cell-output-stdout') or el.classes:includes('cell-output-stderr') then
      print("[MARGIN_REFERENCES.LUA] Skipping R output div (cell-output)")
      return el  -- Pass through unchanged
    end

    -- Skip .column-margin divs - they're handled at Pandoc document level
    if el.classes:includes('column-margin') then
      print("[MARGIN_REFERENCES.LUA] Skipping .column-margin div (handled at Pandoc level)")
      return nil  -- Return nil to pass through (already processed at Pandoc level)
    end

    -- ::{.aside} - unnumbered margin notes (multiline support)
    if el.classes:includes('aside') then
      print("[MARGIN_REFERENCES.LUA] Processing .aside div")
      -- Only process for Typst format
      if FORMAT == "typst" then
        local dy = el.attributes.dy or "0pt"
        print("[MARGIN_REFERENCES.LUA] .aside dy: " .. dy)
        local blocks = pandoc.List({
          pandoc.RawBlock('typst', string.format('#marginnote(dy: %s)[#set par(first-line-indent: 0em)', dy))
        })
        blocks:extend(el.content)
        print("[MARGIN_REFERENCES.LUA] .aside returning endTypstBlock")
        return endTypstBlock(blocks)
      else
        -- For HTML, let Quarto handle .aside natively
        return el
      end
    end

    -- ::{.fullwidth}
    if el.classes:includes('fullwidth') then
      local dx = el.attributes.dx or "0pt"
      local dy = el.attributes.dy or "0pt"
      local width = "100%+75.2mm"
      --local width = "100%+3.5in-0.75in"
      local blocks = pandoc.List({
        pandoc.RawBlock('typst', string.format('#block(width: %s)[', width))
        -- pandoc.RawBlock('typst', string.format('#set text(font: serif-fonts, size: marginfontsize); #block(width: %s)[', width))
      })
      blocks:extend(el.content)
      return endTypstBlock(blocks)
    end

    -- NOTE: wideblock wrapping is now handled by wrap-wideblock.lua (filter #5)
    -- which runs before this filter and modifies Table colspecs directly.
    -- Do not duplicate wideblock handling here.

    -- ::{.column-page-right}
    if el.classes:includes('column-page-right') then
      local dx = el.attributes.dx or "0pt"
      local dy = el.attributes.dy or "2em"
      local width = "100%+75.2mm"
      local blocks = pandoc.List({
        pandoc.RawBlock('typst', string.format('#block(width: %s)[', width))
      })
      blocks:extend(el.content)
      return endTypstBlock(blocks)
    end
  end

-- Extract sidenotes from headings to prevent TOC duplication
-- Uses hidden heading (for outline) + visible heading with outlined:false (for body)
-- Applies to both numbered sidenotes and unnumbered sidenotes (marginnotes)
function Header(header)
  if FORMAT ~= "typst" then
    return header
  end

  -- Handle unnumbered headings by generating proper Typst scope syntax
  if header.classes and header.classes:includes('unnumbered') then
    local heading_text = pandoc.utils.stringify(header.content)
    local label_code = ""
    if header.identifier and header.identifier ~= "" then
      label_code = string.format(" <%s>", header.identifier)
    end
    
    -- Generate heading using Typst's set rule in local scope to avoid block wrapper
    local typst_code = string.format([=[#[
  #set heading(numbering: none)
  %s %s
]%s]=],
      string.rep("=", header.level), heading_text, label_code)
    
    return pandoc.RawBlock('typst', typst_code)
  end

  -- Check if header contains sidenotes (both numbered and unnumbered)
  local has_sidenote = false

  for _, inline in ipairs(header.content) do
    if inline.t == "RawInline" and inline.format == "typst" then
      if inline.text:match("^#sidenote") then
        has_sidenote = true
        break
      end
    end
  end

  -- If no sidenote, return as-is
  if not has_sidenote then
    return header
  end

  -- Extract clean content (without sidenotes/marginnotes) for the outline
  local clean_content = pandoc.List()
  for _, inline in ipairs(header.content) do
    if not (inline.t == "RawInline" and inline.format == "typst" and
            (inline.text:match("^#sidenote") or inline.text:match("^#marginnote"))) then
      table.insert(clean_content, inline)
    end
  end

  local clean_text = pandoc.utils.stringify(clean_content)

  -- Get the heading identifier (label) if it exists
  local label_code = ""
  if header.identifier and header.identifier ~= "" then
    label_code = string.format(" <%s>", header.identifier)
  end

  -- Build clean heading text (without sidenotes) and extract sidenotes separately
  local heading_text_parts = {}
  local sidenote_parts = {}
  for _, inline in ipairs(header.content) do
    if inline.t == "RawInline" and inline.format == "typst" and 
       (inline.text:match("^#sidenote") or inline.text:match("^#marginnote")) then
      -- Extract sidenote/marginnote and inject alignment + dy parameters for vertical alignment
      -- alignment: "baseline" + dy: 0pt provides perfect visual alignment
      local modified_sidenote = inline.text

      -- Detect function name (sidenote or marginnote)
      local func_name = inline.text:match("^#(%w+)")
      
      -- Inject alignment and dy parameters into sidenote/marginnote call
      if inline.text:match("^#" .. func_name .. "%(%)%[") then
        -- No existing parameters: #sidenote()[...] or #marginnote()[...]
        modified_sidenote = inline.text:gsub("^#" .. func_name .. "%(%)%[", 
          "#" .. func_name .. "(alignment: \"baseline\", dy: 0pt)[")
      elseif inline.text:match("^#" .. func_name .. "%(.+%)%[") then
        -- Has parameters: #sidenote(...)[...] or #marginnote(...)[...]
        modified_sidenote = inline.text:gsub("^(#" .. func_name .. "%()(.-)(%))(%[)", function(start, params, close, bracket)
          return string.format("%s%s, alignment: \"baseline\", dy: 0pt%s%s", start, params, close, bracket)
        end)
      end

      table.insert(sidenote_parts, modified_sidenote)
    else
      -- Build heading text
      if inline.t == "Str" then
        table.insert(heading_text_parts, inline.text)
      elseif inline.t == "Space" then
        table.insert(heading_text_parts, " ")
      else
        table.insert(heading_text_parts, pandoc.utils.stringify(inline))
      end
    end
  end
  local heading_text = table.concat(heading_text_parts, "")
  local sidenote_code = table.concat(sidenote_parts, "")

  -- NOTE: Sidenote must be INSIDE heading content to keep anchor inline with heading text.
  -- dy: -6pt offset aligns the margin note vertically with the heading anchor.

  -- Structure: invisible heading for TOC, visible heading with sidenote, then label
  local typst_code = string.format([=[#{
  show heading: none
  heading(level: %d, outlined: true)[%s]
  counter(heading).update((..nums) => {
    let arr = nums.pos()
    arr.slice(0, -1) + (arr.last() - 1,)
  })
}#heading(level: %d, outlined: false)[%s%s]%s]=],
    header.level, clean_text,
    header.level, heading_text, sidenote_code, label_code)

  return pandoc.RawBlock('typst', typst_code)
end