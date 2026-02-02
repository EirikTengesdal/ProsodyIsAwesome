-- code-caption-to-marginnote.lua (v4)
-- Main-width code: caption as marginal note ABOVE code (align with first line)
-- Full-width (inside .wideblock): caption as marginal note BELOW code
-- Consumes markdown ": caption" paras and handles Figure(CodeBlock, Caption) defensively.

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [7] CODE-CAPTION-TO-MARGINNOTE.LUA STARTING ==========") end

-- ───────── helpers ─────────

local function typst_escape(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\"):gsub("\"", "\\\"")
  return s
end

local function get_meta(meta, key, default)
  if meta and meta[key] then
    local v = pandoc.utils.stringify(meta[key])
    if v and v ~= "" then return v end
  end
  return default
end

-- Document-level knobs (optional in YAML):
--   typst-code-caption-dy:       default "0em"   (main width, aligns to first line)
--   typst-code-caption-dy-wide:  default "0.2em" (full width, looks like "below")
local function note_block(caption, dy)
  local cap = typst_escape(caption or "")
  local src = [[
#context {
  codecounter.step()
  let _n = codecounter.get().first()
  marginalia.note(numbering: none, dy: ]] .. dy .. [[)[
    #text(size: 8pt)[ #strong[Code #_n.] #text("]] .. cap .. [[") ]
  ]
}
]]
  return pandoc.RawBlock('typst', src)
end

local SEP = pandoc.RawBlock('typst', "\n")    -- hard block boundary

local function para_is_caption(para)
  if para.t ~= "Para" then return nil end
  local s = pandoc.utils.stringify(para or {})
  local body = s:match("^%s*:%s*(.*)$")  -- tolerate leading spaces
  if body and body ~= "" then return body end
  return nil
end

local function fig_caption_string(fig)
  if not fig.caption then return nil end
  local cap = fig.caption
  if type(cap) == "table" and cap.long then
    return pandoc.utils.stringify(cap.long)
  end
  if type(cap) == "table" and cap.content then
    return pandoc.utils.stringify(cap.content)
  end
  return pandoc.utils.stringify(cap)
end

local function is_fenced_typst(rb)
  return rb and rb.t == "RawBlock" and rb.format == "typst" and rb.text:match("```")
end

-- mark a CodeBlock we already processed so we don't do it twice
local function mark_done(code)
  code.attr = code.attr or pandoc.Attr()
  code.attr.attributes = code.attr.attributes or {}
  code.attr.attributes["data-ccmn-done"] = "1"
end

local function is_done(code)
  return code.attr and code.attr.attributes and code.attr.attributes["data-ccmn-done"] == "1"
end

-- ───────── transformers ─────────

-- Main-width pass over a list of blocks: place note BEFORE code
local function process_main(blocks, meta)
  local out = pandoc.List()
  local i, dy = 1, get_meta(meta, "typst-code-caption-dy", "0em")

  while i <= #blocks do
    local b = blocks[i]

    if b.t == "CodeBlock" and not is_done(b) and i < #blocks then
      local cap = para_is_caption(blocks[i + 1])
      if cap then
        out:insert(note_block(cap, dy))  -- ABOVE
        out:insert(SEP)
        mark_done(b); out:insert(b)
        i = i + 2
      else
        out:insert(b); i = i + 1
      end

    elseif b.t == "Div" then
      -- Don't touch here; a separate pass (process_wide) handles .wideblock
      b.content = process_main(b.content, meta)  -- leaves code alone inside .wideblock
      out:insert(b); i = i + 1

    else
      out:insert(b); i = i + 1
    end
  end
  return out
end

-- Full-width pass inside a `.wideblock` div: place note AFTER code
local function process_wide(blocks, meta)
  local out = pandoc.List()
  local i, dy = 1, get_meta(meta, "typst-code-caption-dy-wide", "0.2em")

  while i <= #blocks do
    local b = blocks[i]

    if b.t == "CodeBlock" and not is_done(b) and i < #blocks then
      local cap = para_is_caption(blocks[i + 1])
      if cap then
        mark_done(b); out:insert(b)
        out:insert(SEP)
        out:insert(note_block(cap, dy))  -- BELOW
        i = i + 2
      else
        out:insert(b); i = i + 1
      end

    elseif b.t == "Div" then
      -- recurse for nested blocks within wide area
      b.content = process_wide(b.content, meta)
      out:insert(b); i = i + 1

    else
      out:insert(b); i = i + 1
    end
  end
  return out
end

-- Defensive: Figure(CodeBlock, Caption) at main width → ABOVE
function Figure(fig)
  if FORMAT ~= "typst" then return nil end
  if #fig.content == 1 and fig.content[1].t == "CodeBlock" then
    local cap = fig_caption_string(fig)
    if cap and cap ~= "" then
      local dy = get_meta(PANDOC_STATE and PANDOC_STATE.meta, "typst-code-caption-dy", "0em")
      local code = fig.content[1]
      mark_done(code)
      return { note_block(cap, dy), SEP, code }
    end
  end
  if #fig.content == 1 and is_fenced_typst(fig.content[1]) then
    local cap = fig_caption_string(fig)
    if cap and cap ~= "" then
      local dy = get_meta(PANDOC_STATE and PANDOC_STATE.meta, "typst-code-caption-dy", "0em")
      return { note_block(cap, dy), SEP, fig.content[1] }
    end
  end
  return nil
end

-- Top-level dispatcher:
--  1) Walk blocks; for each .wideblock Div, run process_wide on its content (note BELOW).
--  2) Run process_main on everything else (note ABOVE).
function Pandoc(doc)
  if FORMAT ~= "typst" then return nil end

  local meta = doc.meta
  local out = pandoc.List()

  for _, b in ipairs(doc.blocks) do
    if b.t == "Div" and b.classes and b.classes:includes("wideblock") then
      local nb = pandoc.Div(process_wide(b.content, meta), b.attr)
      out:insert(nb)
    else
      out:insert(b)
    end
  end

  doc.blocks = process_main(out, meta)
  return doc
end
