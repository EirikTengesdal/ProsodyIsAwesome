-- breakable-code.lua (v2)
-- Turn Quarto-made code Figures back into breakable code + margin caption in Typst.

-- -------- helpers ------------------------------------------------------------

local function has_class(el, class)
  if not el or not el.classes then return false end
  for _, c in ipairs(el.classes) do if c == class then return true end end
  return false
end

local function fig_caption_text(fig)
  -- Pandoc 3.x uses Caption; prefer .caption.long (blocks)
  if fig.caption then
    local cap = fig.caption
    if type(cap) == "table" and cap.long then
      return pandoc.utils.stringify(cap.long)
    end
    if type(cap) == "table" and cap.content then
      return pandoc.utils.stringify(cap.content)
    end
    return pandoc.utils.stringify(cap)
  end
  return nil
end

local function find_code_in_blocks(blocks)
  if not blocks then return nil end
  for _, b in ipairs(blocks) do
    if b.t == "CodeBlock" then return b end
  end
  return nil
end

local function rawblock_is_fenced_code(rb)
  if rb and rb.t == "RawBlock" and rb.format == "typst" then
    -- Quarto’s Typst writer often injects fenced code for code figures.
    return rb.text:match("```")
  end
  return false
end

local function typst_escape(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\"):gsub("\"", "\\\"")
  return s
end

-- Build a marginalia side caption RawBlock for Typst
local function make_margin_note(caption_text, dy)
  local cap = typst_escape(caption_text or "")
  local dy_str = dy or "1.2em"
  local src = [[
#context {
  // Step your code counter (declare `#let codecounter = counter(...)` in template)
  #codecounter.step()
  let _n = codecounter.get().first()
  marginalia.note(numbering: none, dy: ]] .. dy_str .. [[)[
    #text(size: 8pt)[ #strong[Code #_n.] #text("]] .. cap .. [[") ]
  ]
}
]]
  return pandoc.RawBlock('typst', src)
end

-- -------- transformer --------------------------------------------------------

-- Return replacement blocks for a code Figure, or nil to keep as-is.
local function replace_code_figure(fig, only_if_wideblock)
  -- Optional: respect `.wideblock` scope. Detect by checking an ancestor Div.
  if only_if_wideblock and not fig._inside_wideblock then
    return nil
  end

  -- Case A: the figure body still contains a CodeBlock
  local code = find_code_in_blocks(fig.content)
  if code then
    local cap = fig_caption_text(fig)
    if cap and cap ~= "" then
      return { code, make_margin_note(cap, "1.2em") }
    else
      return { code }
    end
  end

  -- Case B: Quarto has already turned the body into a Typst RawBlock with fences
  if #fig.content == 1 and rawblock_is_fenced_code(fig.content[1]) then
    local rb = fig.content[1]
    local cap = fig_caption_text(fig)
    if cap and cap ~= "" then
      return { rb, make_margin_note(cap, "1.2em") }
    else
      return { rb }
    end
  end

  return nil
end

-- Mark children with `_inside_wideblock` if they are under a `.wideblock` Div
local function Div(div)
  local is_wide = has_class(div, "wideblock")
  if not is_wide then return nil end

  local new = pandoc.List()
  for _, el in ipairs(div.content) do
    if type(el) == "table" then el._inside_wideblock = true end
    new:insert(el)
  end
  div.content = new
  return div
end

local function Figure(fig)

  io.stderr:write("DBG Figure blocks=", tostring(#fig.content), "\n")

  -- Toggle this if you want to limit to `.wideblock` only:
  local ONLY_IN_WIDEBLOCK = false  -- set true if you want strict scoping
  local repl = replace_code_figure(fig, ONLY_IN_WIDEBLOCK)
  if repl then return repl end
  return nil
end

return {
  { Div = Div, Figure = Figure }
}