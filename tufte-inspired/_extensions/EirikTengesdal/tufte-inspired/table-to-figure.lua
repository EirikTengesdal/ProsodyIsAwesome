-- table-to-figure.lua
-- Converts tables and code blocks with captions to proper figures for Typst margin caption handling
-- This works BEFORE table.lua processes tables

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [3] TABLE-TO-FIGURE.LUA STARTING ==========") end

function Table(table)
  if FORMAT:match 'typst' then
    if table.caption and table.caption.long and #table.caption.long > 0 then
      -- Extract caption content
      local caption_text = pandoc.write(pandoc.Pandoc(table.caption.long), 'typst')

      -- Remove the caption from the table
      table.caption = nil

      -- Create figure wrapper as raw blocks
      local figure_start = pandoc.RawBlock('typst',
        '#figure(\n  kind: table,\n  caption: [' .. caption_text .. '],\n  ['
      )
      local figure_end = pandoc.RawBlock('typst', '])')

      -- Return the figure wrapper with the table inside
      return {figure_start, table, figure_end}
    end
  end
  return table
end

function Pandoc(doc)
  if not FORMAT:match 'typst' then
    return doc
  end

  -- Function to process a list of blocks
  local function process_blocks(blocks)
    local new_blocks = {}
    local i = 1

    while i <= #blocks do
      local block = blocks[i]

      -- Check if this is a div (like wideblock) and process its content recursively
      if block.t == "Div" then
        block.content = process_blocks(block.content)
        table.insert(new_blocks, block)
        i = i + 1

    --   -- Check if this is a code block followed by a caption paragraph
    --   elseif block.t == "CodeBlock" and i < #blocks then
    --     local next_block = blocks[i + 1]

    --     -- Check if the next block is a paragraph that starts with ": " (indicating a caption)
    --     if next_block and next_block.t == "Para" and #next_block.content > 0 then
    --       local first_element = next_block.content[1]
    --       if first_element and first_element.t == "Str" and first_element.text:match("^:") then
    --         -- Found a code block with a caption
    --         -- Extract caption content (remove the ": " prefix)
    --         local caption_content = pandoc.List(next_block.content)
    --         -- Remove the ":" from the first element
    --         if caption_content[1] and caption_content[1].t == "Str" then
    --           caption_content[1].text = caption_content[1].text:gsub("^:%s*", "")
    --         end

    --         local caption_text = pandoc.write(pandoc.Pandoc({pandoc.Para(caption_content)}), 'typst')

    --         -- Create figure wrapper for code block
    --         local figure_start = pandoc.RawBlock('typst',
    --           '#figure(\n  kind: raw,\n  caption: [' .. caption_text .. '],\n  ['
    --         )
    --         local figure_end = pandoc.RawBlock('typst', '])')

    --         -- Add the figure wrapper with code block inside
    --         table.insert(new_blocks, figure_start)
    --         table.insert(new_blocks, block)
    --         table.insert(new_blocks, figure_end)

    --         -- Skip the next block (caption) since we've consumed it
    --         i = i + 2
    --       else
    --         -- Regular code block without caption
    --         table.insert(new_blocks, block)
    --         i = i + 1
    --       end
    --     else
    --       -- Regular code block without caption
    --       table.insert(new_blocks, block)
    --       i = i + 1
    --     end

      -- Check if this is a quote block followed by a caption paragraph
      elseif block.t == "BlockQuote" and i < #blocks then
        local next_block = blocks[i + 1]

        -- Check if the next block is a paragraph that starts with ": " (indicating a caption)
        if next_block and next_block.t == "Para" and #next_block.content > 0 then
          local first_element = next_block.content[1]
          if first_element and first_element.t == "Str" and first_element.text:match("^:") then
            -- Found a quote block with a caption
            -- Extract caption content (remove the ": " prefix)
            local caption_content = pandoc.List(next_block.content)
            -- Remove the ":" from the first element
            if caption_content[1] and caption_content[1].t == "Str" then
              caption_content[1].text = caption_content[1].text:gsub("^:%s*", "")
            end

            local caption_text = pandoc.write(pandoc.Pandoc({pandoc.Para(caption_content)}), 'typst')

            -- Create figure wrapper for quote block
            local figure_start = pandoc.RawBlock('typst',
              '#figure(\n  kind: quote,\n  caption: [' .. caption_text .. '],\n  ['
            )
            local figure_end = pandoc.RawBlock('typst', '])')

            -- Add the figure wrapper with quote inside
            table.insert(new_blocks, figure_start)
            table.insert(new_blocks, block)
            table.insert(new_blocks, figure_end)

            -- Skip the next block (caption) since we've consumed it
            i = i + 2
          else
            -- Regular quote block without caption
            table.insert(new_blocks, block)
            i = i + 1
          end
        else
          -- Regular quote block without caption
          table.insert(new_blocks, block)
          i = i + 1
        end
      else
        -- Not a code or quote block, add as-is
        table.insert(new_blocks, block)
        i = i + 1
      end
    end

    return new_blocks
  end

  doc.blocks = process_blocks(doc.blocks)
  return doc
end