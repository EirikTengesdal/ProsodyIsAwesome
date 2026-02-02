local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [5] WRAP-WIDEBLOCK.LUA STARTING ==========") end

function Div(el)
  if el.classes:includes('wideblock') then
    -- Only apply wideblock wrapper for Typst output
    if FORMAT:match 'typst' then
      -- Check if custom columns are specified
      local custom_columns = el.attributes["columns"]

      if DEBUG then
        print("\n[WRAP-WIDEBLOCK] ========== Found wideblock Div ==========")
        print(string.format("[WRAP-WIDEBLOCK] Custom columns: %s", tostring(custom_columns)))
        print(string.format("[WRAP-WIDEBLOCK] Content blocks: %d", #el.content))
      end

      -- Separate Typst metadata (e.g., #let total-rows) from other content
      local result = {}
      local typst_metadata = {}

      for i, block in ipairs(el.content) do
        if DEBUG then
          print(string.format("\n[WRAP-WIDEBLOCK] --- Content Block %d ---", i))
          print(string.format("[WRAP-WIDEBLOCK] Block type (tag): %s", block.t))

          -- Show all fields
          for k, v in pairs(block) do
            if type(v) ~= "function" and k ~= "t" then
              print(string.format("  [WRAP-WIDEBLOCK] %s = %s", k, tostring(v)))
            end
          end
        end

        -- Special handling for Table elements
        if block.t == "Table" then
          if DEBUG then
            print("[WRAP-WIDEBLOCK] *** TABLE ELEMENT DETECTED ***")
            if block.colspecs then
              print(string.format("[WRAP-WIDEBLOCK] Table has %d columns with colspecs:", #block.colspecs))
              for j, spec in ipairs(block.colspecs) do
                print(string.format("    [WRAP-WIDEBLOCK] Col %d: align=%s, width=%s",
                                    j, tostring(spec[1]), tostring(spec[2])))
              end
            end
          end

          -- Modify colspecs if custom columns specified
          if custom_columns then
            -- Parse the custom column specifications
            local custom_cols = {}
            for col_spec in string.gmatch(custom_columns, "([^,]+)") do
              col_spec = col_spec:match("^%s*(.-)%s*$")  -- trim whitespace
              table.insert(custom_cols, col_spec)
            end

            if DEBUG then
              print(string.format("[WRAP-WIDEBLOCK] Applying custom columns: %d columns", #custom_cols))
            end

            -- Modify the table's colspecs
            if #custom_cols == #block.colspecs then
              for i, col_spec in ipairs(custom_cols) do
                local align = block.colspecs[i][1]  -- Keep original alignment
                local new_width

                if col_spec == "auto" then
                  new_width = nil  -- nil means auto in Pandoc
                elseif col_spec:match("%%$") then
                  -- Convert percentage to fraction (e.g., "20%" -> 0.20)
                  new_width = tonumber(col_spec:match("([%d.]+)%%")) / 100
                else
                  -- Try to parse as direct number
                  new_width = tonumber(col_spec)
                end

                block.colspecs[i] = {align, new_width}

                if DEBUG then
                  print(string.format("    [WRAP-WIDEBLOCK] Modified col %d: align=%s, width=%s",
                                      i, tostring(align), tostring(new_width)))
                end
              end

              if DEBUG then
                print("[WRAP-WIDEBLOCK] ✓ Successfully modified all colspecs")
              end
            else
              if DEBUG then
                print(string.format("[WRAP-WIDEBLOCK] WARNING: Column count mismatch (custom=%d, table=%d)",
                                    #custom_cols, #block.colspecs))
              end
            end
          end
        end

        if block.t == "RawBlock" then
          if DEBUG then
            print(string.format("[WRAP-WIDEBLOCK] RawBlock format: %s", block.format))
            if block.format == "typst" then
              print("[WRAP-WIDEBLOCK] RawBlock text (first 150 chars):")
              print(string.sub(block.text, 1, 150))
              print(string.format("[WRAP-WIDEBLOCK] Contains '#table('? %s",
                                  block.text:match("#table%s*%(") and "YES" or "NO"))
            end
          end
        end

        if block.t == "RawBlock" and block.format == "typst" and block.text:match("^#let%s+") then
          -- Extract Typst metadata (e.g., #let total-rows) and place it outside the wideblock
          table.insert(typst_metadata, block)
        else
          -- If this is a table block and we have custom columns, remove Pandoc's columns parameter
          if custom_columns and block.t == "RawBlock" and block.format == "typst" then
            -- Remove the columns: line from #table( blocks
            if block.text:match("#table%(") or block.text:match("^#with%-table%-rows") then
              if DEBUG then
                print("[WRAP-WIDEBLOCK] Found table RawBlock, attempting to strip columns:")
                print(string.sub(block.text, 1, 200))
              end
              -- Remove the line with "columns: (...)" or "columns: 0,"
              local original = block.text
              block.text = block.text:gsub("%s*columns:%s*[^,\n]+,?\n?", "")
              if DEBUG and original ~= block.text then
                print("[WRAP-WIDEBLOCK] Successfully stripped columns parameter")
                print("[WRAP-WIDEBLOCK] New text:")
                print(string.sub(block.text, 1, 200))
              elseif DEBUG then
                print("[WRAP-WIDEBLOCK] No columns parameter found to strip")
              end
            end
          end
          -- Add regular content inside the wideblock
          table.insert(result, block)
        end
      end

      -- Build wideblock parameters
      -- NOTE: Custom columns will be applied directly to #table() in post-quarto.lua
      local params = {}
      if custom_columns then
        print(string.format("\n[WRAP-WIDEBLOCK] *** CUSTOM COLUMNS DETECTED ***"))
        print(string.format("[WRAP-WIDEBLOCK] Columns attribute: %s", custom_columns))
        print(string.format("[WRAP-WIDEBLOCK] Will be converted to fractional units in post-processing"))
        -- Don't add columns parameter to wideblock - let post-quarto.lua modify #table() directly
      end

      if el.attributes["table-size"] then
        table.insert(params, string.format('table-size: %s', el.attributes["table-size"]))
      end
      local params_str = #params > 0 and string.format("(%s)", table.concat(params, ", ")) or ""

      if DEBUG then
        print(string.format("[WRAP-WIDEBLOCK] Final wideblock call parameters: #wideblock%s[", params_str))
      end

      -- Build the new block list
      local new_blocks = {}
      for _, metadata in ipairs(typst_metadata) do
        table.insert(new_blocks, metadata) -- Add metadata before the wideblock
      end
      table.insert(new_blocks, pandoc.RawBlock('typst', '#wideblock' .. params_str .. '['))
      for _, block in ipairs(result) do
        table.insert(new_blocks, block)
      end
      table.insert(new_blocks, pandoc.RawBlock('typst', ']'))
      return new_blocks
    else
      -- For other formats (e.g., HTML), just return the content without the wrapper
      return el.content
    end
  end
end