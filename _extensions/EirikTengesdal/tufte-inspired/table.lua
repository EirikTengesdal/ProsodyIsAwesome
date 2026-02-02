-- _extensions/typst-lastrow/table-rows.lua
-- One-pass Pandoc Lua filter for Quarto → Typst:
--   1) Map tbl-colwidths-typst -> AST colspecs (fractions that sum to 1.0), strip the attribute.
--   2) Wrap each Table exactly once in: #with-table-rows(n: N)[ ...table... ]
--
-- Works across Pandoc versions (no hard dependency on pandoc.ColSpec).
-- Scope-safe: no double wrapping, no duplicate `columns:` in Typst output.

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [1] TABLE.LUA STARTING ==========") end

local is_typst = (FORMAT == "typst")

-- --------------------------------------------------------------------
-- Utilities
-- --------------------------------------------------------------------

-- Parse numeric list like "[12,8,10,30,40]" -> {12,8,10,30,40}
local function parse_widths_list(s)
  if not s or s == "" then return nil end
  s = pandoc.utils.stringify(s):gsub("^%[", ""):gsub("%]$", "")
  local nums = {}
  for w in s:gmatch("[^,%s]+") do
    local v = tonumber(w)
    if v then nums[#nums+1] = v end
  end
  if #nums == 0 then return nil end
  return nums
end

-- Convert numeric list to fractions that sum to 1.0.
-- If the sum is ~100, treat as percentages; otherwise treat as weights.
-- The last column is set to (1 - sum(previous)) to avoid rounding drift.
local function normalize_widths_to_fractions(nums)
  -- Sanitize & sum
  local clean, raw_sum = {}, 0.0
  for i, v in ipairs(nums) do
    local x = tonumber(v) or 0
    if x < 0 then x = 0 end
    clean[i] = x
    raw_sum = raw_sum + x
  end

  local eps = 1e-6
  local fracs = {}
  local is_percentish = math.abs(raw_sum - 100.0) <= 1e-3 and raw_sum > eps

  if is_percentish then
    local running = 0.0
    for i = 1, #clean - 1 do
      fracs[i] = clean[i] / 100.0
      running = running + fracs[i]
    end
    fracs[#clean] = math.max(0.0, 1.0 - running)
  else
    if raw_sum <= eps then
      local eq = 1.0 / math.max(1, #clean)
      for i = 1, #clean do fracs[i] = eq end
    else
      local running = 0.0
      for i = 1, #clean - 1 do
        fracs[i] = clean[i] / raw_sum
        running = running + fracs[i]
      end
      fracs[#clean] = math.max(0.0, 1.0 - running)
    end
  end

  return fracs
end

-- From table / caption / parent Div, fetch the first tbl-colwidths-typst value found.
local function get_tblcol_attr(tbl, parent_val)
  -- 1) table attribute
  if tbl.attr and tbl.attr.attributes and tbl.attr.attributes["tbl-colwidths-typst"] then
    return "table", tbl.attr.attributes["tbl-colwidths-typst"]
  end
  -- 2) caption attribute
  if tbl.caption and tbl.caption.long and tbl.caption.long.attr then
    local capattr = tbl.caption.long.attr
    if capattr.attributes and capattr.attributes["tbl-colwidths-typst"] then
      return "caption", capattr.attributes["tbl-colwidths-typst"]
    end
  end
  -- 3) parent Div attribute (promote to table)
  if parent_val then
    return "parent", parent_val
  end
  return nil, nil
end

-- Apply widths (fractions) into tbl.colspecs, preserving existing alignments.
-- Strip `tbl-colwidths-typst` from where it came from.
local function apply_widths_to_colspecs(tbl, where, raw_val)
  local nums = parse_widths_list(raw_val)
  if nums and #nums > 0 then
    local fracs = normalize_widths_to_fractions(nums)

    local existing = tbl.colspecs or {}
    local ncols = #existing
    if ncols == 0 then
      -- Heuristic: infer columns from header cells if colspecs missing.
      -- (Pandoc usually sets colspecs; this is a fallback.)
      if tbl.head and tbl.head.rows and tbl.head.rows[1] then
        ncols = #tbl.head.rows[1].cells
      else
        ncols = #fracs
      end
    end
    if ncols == 0 then ncols = #fracs end

    -- If we have fewer fracs than columns, fill remainder equally from leftover.
    if #fracs < ncols then
      local remain = 1.0
      for _, f in ipairs(fracs) do remain = remain - f end
      local missing = ncols - #fracs
      local add = (missing > 0) and (remain / missing) or 0
      for _ = 1, missing do fracs[#fracs + 1] = math.max(0.0, add) end
    end

    -- If more fracs than columns, renormalize first ncols to sum 1.0
    if #fracs > ncols then
      local s = 0.0
      for i = 1, ncols do s = s + fracs[i] end
      if s > 1e-9 then
        local running = 0.0
        for i = 1, ncols - 1 do
          fracs[i] = fracs[i] / s
          running = running + fracs[i]
        end
        fracs[ncols] = math.max(0.0, 1.0 - running)
      else
        local eq = 1.0 / ncols
        fracs = {}
        for i = 1, ncols do fracs[i] = eq end
      end
    end

    -- Build new colspecs
    local new = {}
    for i = 1, ncols do
      local align = pandoc.AlignDefault
      if existing[i] then
        -- existing[i] = { align, width } in Lua API
        align = existing[i][1] or pandoc.AlignDefault
      end
      local width = fracs[i] or (1.0 / ncols)

      -- Prefer constructor when available; otherwise fallback to 2‑tuple.
      if pandoc and pandoc.ColSpec then
        new[i] = pandoc.ColSpec(align, width)
      else
        new[i] = { align, width }
      end
    end
    tbl.colspecs = new
  end

  -- Strip the typst-only attribute at its origin so it never leaks
  if where == "table" and tbl.attr and tbl.attr.attributes then
    tbl.attr.attributes["tbl-colwidths-typst"] = nil
  elseif where == "caption"
     and tbl.caption and tbl.caption.long and tbl.caption.long.attr
     and tbl.caption.long.attr.attributes then
    tbl.caption.long.attr.attributes["tbl-colwidths-typst"] = nil
  end
  return tbl
end

-- Count rows for the Typst stroke logic (head.rows + sum(bodies.head/body) + foot.rows)
local function count_rows(tbl)
  local n = 0
  if tbl.head and tbl.head.rows then n = n + #tbl.head.rows end
  if tbl.bodies then
    for _, b in ipairs(tbl.bodies) do
      if b.head then n = n + #b.head end
      if b.body then n = n + #b.body end
    end
  end
  if tbl.foot and tbl.foot.rows then n = n + #tbl.foot.rows end
  return n
end

-- One recursive pass (no double wrapping)
-- --------------------------------------------------------------------

-- We carry the parent Div's width string AND a flag for wideblock with custom columns
local function transform_blocks(blocks, parent_colwidths_val, skip_colwidths)
  local out = pandoc.List{}

  for _, b in ipairs(blocks) do
    if b.t == "Div" then
      if DEBUG then
        print(string.format("[TABLE.LUA] Processing Div, classes: %s",
          (b.attr and b.attr.classes) and table.concat(b.attr.classes, ", ") or "none"))
      end

      -- Skip R output divs to avoid filter chain errors
      if b.attr and b.attr.classes then
        local is_r_output = false
        for _, cls in ipairs(b.attr.classes) do
          if cls == "cell-output" or cls == "cell-output-stdout" or 
             cls == "cell-output-stderr" or cls == "cell" or cls == "hidden" then
            is_r_output = true
            break
          end
        end
        
        if is_r_output then
          if DEBUG then print("[TABLE.LUA] Skipping R output div") end
          out:insert(b)
          goto continue
        end
      end

      local next_parent_val = parent_colwidths_val
      local next_skip = skip_colwidths

      -- If this Div has tbl-colwidths-typst, strip it here and pass the value down.
      if b.attr and b.attr.attributes and b.attr.attributes["tbl-colwidths-typst"] then
        next_parent_val = b.attr.attributes["tbl-colwidths-typst"]
        b.attr.attributes["tbl-colwidths-typst"] = nil
        if DEBUG then print("[TABLE.LUA] Found tbl-colwidths-typst attribute") end
      end

      -- Check for wideblock with columns attribute
      if b.attr and b.attr.classes then
        for _, cls in ipairs(b.attr.classes) do
          if cls == "wideblock" then
            if DEBUG then print("[TABLE.LUA] Found wideblock Div!") end
            if b.attr.attributes["columns"] then
              if DEBUG then
                print(string.format("[TABLE.LUA] Wideblock has custom columns: %s",
                  b.attr.attributes["columns"]))
              end
              next_skip = true
            end
            break
          end
        end
      end

      out:insert(pandoc.Div(transform_blocks(b.content, next_parent_val, next_skip), b.attr))
      
      ::continue::  -- Label for goto to skip processing

    elseif b.t == "Table" then
      if DEBUG then
        print("\n[TABLE.LUA] ========== Processing Table Element ==========")
        print("[TABLE.LUA] Table fields available:")
        for k, v in pairs(b) do
          if type(v) ~= "function" then
            print(string.format("  [TABLE.LUA] %s = %s (type: %s)", k, tostring(v), type(v)))
          end
        end

        if b.colspecs then
          print("[TABLE.LUA] Table.colspecs:")
          for i, spec in ipairs(b.colspecs) do
            print(string.format("  [TABLE.LUA] Column %d: align=%s, width=%s",
                                i, tostring(spec[1]), tostring(spec[2])))
          end
        else
          print("[TABLE.LUA] Table has NO colspecs")
        end

        if b.head and b.head.rows then
          print("[TABLE.LUA] Header rows: " .. #b.head.rows)
        end
        if b.bodies then
          print("[TABLE.LUA] Bodies count: " .. #b.bodies)
        end
        print("[TABLE.LUA] Skip colwidths flag: " .. tostring(skip_colwidths))
      end

      if skip_colwidths then
        if DEBUG then
          print("[TABLE.LUA] *** WIDEBLOCK MODE - Will skip colspec modification ***")
        end
        -- For wideblock with custom columns: just wrap, don't modify colspecs
        if is_typst then
          local n = count_rows(b)
          local open  = pandoc.RawBlock('typst', '#with-table-rows(n: ' .. tostring(n) .. ')[')
          local close = pandoc.RawBlock('typst', ']')
          out:extend(pandoc.List{ open, b, close })
        else
          out:insert(b)
        end
      else
        -- Apply widths into colspecs (if any were provided), then strip the source attr.
        local where, raw_val = get_tblcol_attr(b, parent_colwidths_val)
        local t = (raw_val and apply_widths_to_colspecs(b, where, raw_val)) or b

        -- Wrap once for Typst so your helper can style header & last row.
        if is_typst then
          local n = count_rows(t)
          local open  = pandoc.RawBlock('typst', '#with-table-rows(n: ' .. tostring(n) .. ')[')
          local close = pandoc.RawBlock('typst', ']')
          out:extend(pandoc.List{ open, t, close })
        else
          out:insert(t)
        end
      end

    else
      out:insert(b)
    end
  end

  return out
end

function Pandoc(doc)
  if DEBUG then print("[TABLE.LUA] Pandoc() function called, processing document blocks") end
  doc.blocks = transform_blocks(doc.blocks, nil, false)
  return doc
end
