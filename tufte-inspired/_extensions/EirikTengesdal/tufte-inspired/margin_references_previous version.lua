-- see https://github.com/quarto-dev/quarto-cli/discussions/10440

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [6] MARGIN_REFERENCES.LUA STARTING ==========") end

-- Counter to track sidenotes for TOC collision avoidance
local sidenote_counter = 0

-- Store footnotes from headings to re-insert after heading
local heading_footnotes = {}

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

  -- Create a Typst function call with deconstructed parts
  local typst_call = string.format(
      '#sidecite(<%s>, "%s", "%s", "%s", %s, %s)',
      key, mode, prefix, suffix, locator, label
  )

  return pandoc.Inlines({
      pandoc.RawInline('typst', typst_call)
  })
end

-- Convert footnotes to marginalia sidenotes
function Note(note)
  -- Only process for Typst format
  if FORMAT ~= "typst" then
    return note
  end

  -- DEBUG: Print raw note content
  print("\n=== FOOTNOTE DEBUG START ===")
  print("Number of blocks in footnote:", #note.content)
  for i, block in ipairs(note.content) do
    print(string.format("Block %d type: %s", i, block.t))
    if block.t == "Para" or block.t == "Plain" then
      print(string.format("Block %d has %d inlines", i, #block.content))
      for j, inline in ipairs(block.content) do
        print(string.format("  Inline %d type: %s, content: %s", j, inline.t, pandoc.utils.stringify(inline)))
      end
    end
  end

  -- Walk through the footnote content and process any citations
  local processed_content = pandoc.walk_block(pandoc.Div(note.content), {
    Cite = Cite
  }).content

  -- Convert footnote content preserving Typst formatting
  local content_parts = {}
  for _, block in ipairs(processed_content) do
    if block.t == "Para" or block.t == "Plain" then
      -- Process inlines to preserve formatting
      local inline_parts = {}
      local prev_was_linebreak = false
      local is_first_parbreak = true
      for _, inline in ipairs(block.content) do
        if inline.t == "Strong" then
          table.insert(inline_parts, string.format("*%s*", pandoc.utils.stringify(inline)))
          prev_was_linebreak = false
        elseif inline.t == "Emph" then
          table.insert(inline_parts, string.format("_%s_", pandoc.utils.stringify(inline)))
          prev_was_linebreak = false
        elseif inline.t == "Code" then
          table.insert(inline_parts, string.format("`%s`", inline.text))
          prev_was_linebreak = false
        elseif inline.t == "LineBreak" then
          if prev_was_linebreak then
            -- Two consecutive line breaks = paragraph break
            if is_first_parbreak then
              -- First paragraph after heading should have no indent
              table.insert(inline_parts, "#parbreak()#set par(first-line-indent: 0em); ")
              is_first_parbreak = false
            else
              table.insert(inline_parts, "#parbreak()")
            end
            prev_was_linebreak = false  -- Reset after parbreak
          else
            prev_was_linebreak = true
          end
        elseif inline.t == "Space" then
          if not prev_was_linebreak then
            table.insert(inline_parts, " ")
          end
          -- Don't reset prev_was_linebreak for spaces
        else
          table.insert(inline_parts, pandoc.utils.stringify(inline))
          prev_was_linebreak = false
        end
      end
      table.insert(content_parts, table.concat(inline_parts, ""))
    else
      table.insert(content_parts, pandoc.utils.stringify(block))
    end
  end
  local content_str = table.concat(content_parts, "#parbreak()")  -- Paragraph breaks between blocks

  print("Final combined string:", content_str)
  print("=== FOOTNOTE DEBUG END ===\n")

  -- Increment sidenote counter
  sidenote_counter = sidenote_counter + 1

  -- Add vertical offset for first sidenote to avoid TOC collision
  local dy_offset = "0pt"
  if sidenote_counter == 1 then
    dy_offset = "1em"  -- Minimal offset to clear TOC
  end

  local typst_call = string.format('#sidenote(dy: %s)[%s]', dy_offset, content_str)

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
    -- Convert span content to string
    local content_str = pandoc.utils.stringify(span.content)

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
        
        -- Set defaults if not specified
        if not current.attributes.numbering then
          table.insert(params, 'numbering: none')
        end
        
        local params_str = table.concat(params, ", ")
        
        -- Convert content blocks to Typst format (preserves paragraphs, formatting, etc.)
        local content_typst = pandoc.write(pandoc.Pandoc(current.content), 'typst')
        -- Remove trailing newlines to avoid extra spacing
        content_typst = content_typst:gsub("\n+$", "")
        
        -- Debug: show first 50 chars of margin note content
        local preview = content_typst:sub(1, 50):gsub("\n", " ")
        print(string.format("[MARGIN] Processing margin note: '%s...', params: %s", preview, params_str))
        
        -- Build margin note with dynamic parameters
        local margin_note_code = string.format('#marginalia.note(%s)[#set par(first-line-indent: 0em)\n%s]', 
          params_str, content_typst)
        
        local margin_note_inline = pandoc.RawInline('typst', margin_note_code)
        
        -- Strategy: Look at both previous and next blocks
        if #new_blocks > 0 then
          local prev = new_blocks[#new_blocks]
          
          print(string.format("[MARGIN] Previous block type: %s", prev.t))
          
          -- Always append margin notes to headers - Typst show rule handles TOC filtering
          if prev.t == "Header" then
            print("[MARGIN] Appending to Header (Typst will filter from TOC)")
            prev.content:insert(margin_note_inline)
          elseif prev.t == "Para" or prev.t == "Plain" then
            print("[MARGIN] Appending to previous Para/Plain")
            prev.content:insert(margin_note_inline)
          else
            local plain_block = pandoc.Plain({margin_note_inline})
            new_blocks:insert(plain_block)
          end
        else
          local plain_block = pandoc.Plain({margin_note_inline})
          new_blocks:insert(plain_block)
        end
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
function Header(header)
  if FORMAT ~= "typst" then
    return header
  end

  -- Check if this heading contains a sidenote
  local has_sidenote = false
  for _, inline in ipairs(header.content) do
    if inline.t == "RawInline" and inline.format == "typst" and inline.text:match("^#sidenote") then
      has_sidenote = true
      break
    end
  end

  -- If no sidenote, return as-is
  if not has_sidenote then
    return header
  end

  -- Extract clean content (without sidenotes) for the outline
  local clean_content = pandoc.List()
  for _, inline in ipairs(header.content) do
    if not (inline.t == "RawInline" and inline.format == "typst" and inline.text:match("^#sidenote")) then
      table.insert(clean_content, inline)
    end
  end

  local clean_text = pandoc.utils.stringify(clean_content)
  local blocks = pandoc.List()

  -- Hidden heading for outline (will appear in TOC with number)
  local hidden_code = string.format([[#{
  show heading: none
  heading(level: %d)[%s]
}]], header.level, clean_text)
  table.insert(blocks, pandoc.RawBlock('typst', hidden_code))

  -- Step back the counter so visible heading gets the same number
  table.insert(blocks, pandoc.RawBlock('typst', '#counter(heading).update(n => n - 1)'))

  -- Visible heading with sidenote (outlined: false to exclude from TOC)
  table.insert(blocks, pandoc.RawBlock('typst', string.format('#heading(level: %d, outlined: false)[', header.level)))
  table.insert(blocks, pandoc.Plain(header.content))
  table.insert(blocks, pandoc.RawBlock('typst', ']'))

  return blocks
end
-- Return filter with Meta first, then Pandoc document-level, then element-level handlers
return {
  {Meta = Meta},  -- First pass: set global variables
  {Pandoc = Pandoc},  -- Second pass: process .column-margin divs at document level
  {CodeBlock = CodeBlock, Cite = Cite, Note = Note, Span = Span, Div = Div, Header = Header, Block = Block}  -- Third pass: process elements
}