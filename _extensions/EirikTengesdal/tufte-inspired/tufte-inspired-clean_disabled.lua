-- see https://github.com/quarto-dev/quarto-cli/discussions/10440
function Cite(cite)
  -- Only process citations for Typst format
  if FORMAT ~= "typst" then
    return cite
  end

  local citation = cite.citations[1]

  -- Deconstruct the citation object
  local key = citation.id
  local mode = citation.mode or "NormalCitation"
  local prefix = citation.prefix and pandoc.utils.stringify(citation.prefix) or "none"
  local suffix = citation.suffix and pandoc.utils.stringify(citation.suffix) or "none"
  local locator = citation.locator or "none"
  local label = citation.label or "none"

  -- Check whether the label contains the prefix `fig-`
  if string.sub(key, 1, 4) == "fig-" then
    print(cite)
    return cite
  end

  -- Create a Typst function call with deconstructed parts
  local typst_call = string.format(
    '#sidecite(<%s>, "%s", "%s", "%s", %s, %s)',
    key, mode, prefix, suffix, locator, label
  )

  return pandoc.Inlines({
    pandoc.RawInline('typst', typst_call)
  })
end

-- inspired by: https://github.com/quarto-ext/typst-templates  ams/_extensions/ams/ams.lua
local function endTypstBlock(blocks)
    local lastBlock = blocks[#blocks]
    if lastBlock.t == "Para" or lastBlock.t == "Plain" then
      lastBlock.content:insert(pandoc.RawInline('typst', ']'))
      -- Add some vertical spacing after the block
      blocks:insert(pandoc.RawBlock('typst', '#v(0.65em)'))
      -- Reset font settings without wrapping in a block
      blocks:insert(pandoc.RawBlock('typst', '#set text(font: serif-fonts, size: 12pt)'))
      return blocks
    else
      blocks:insert(pandoc.RawBlock('typst', ']'))
      -- Add spacing and font reset as separate blocks
      blocks:insert(pandoc.RawBlock('typst', '#v(0.65em)'))
      blocks:insert(pandoc.RawBlock('typst', '#set text(font: serif-fonts, size: 12pt)'))
      return blocks
    end
  end

-- Helper function to convert a figure to a sidenote
local function process_figure_to_sidenote(figure_block, dy)
  -- Extract image and caption information
  local image_src = ""
  local image_width = "75%"
  local caption = ""

  -- Get image info
  pandoc.walk_block(figure_block, {
    Image = function(img)
      image_src = img.src
      image_width = img.attributes.width or "75%"
      return img
    end
  })

  -- Get caption
  if figure_block.caption and figure_block.caption.long then
    caption = pandoc.utils.stringify(figure_block.caption.long)
  elseif figure_block.caption then
    caption = pandoc.utils.stringify(figure_block.caption)
  end

  if image_src ~= "" then
    -- Create sidenote with image and caption
    local typst_call
    if caption ~= "" then
      typst_call = string.format(
        '#sidenote(dy: %s, padding: (left: 1.5em, right: 4.5em))[#box[#image("%s", width: %s)] \\ #text(size: 7pt, style: "italic")[%s]]',
        dy, image_src, image_width, caption
      )
    else
      typst_call = string.format(
        '#sidenote(dy: %s, padding: (left: 1.5em, right: 4.5em))[#box[#image("%s", width: %s)]]',
        dy, image_src, image_width
      )
    end

    return pandoc.RawBlock('typst', typst_call)
  else
    return figure_block
  end
end

-- Helper function to recursively find and replace figures with sidenotes
local function process_content_for_figures(content, dy)
  local new_content = {}

  for i, block in ipairs(content) do
    if block.t == "Figure" then
      print("Found Figure - converting to sidenote!")
      table.insert(new_content, process_figure_to_sidenote(block, dy))
    elseif block.t == "Div" then
      -- Recursively process nested divs
      local processed_div_content = process_content_for_figures(block.content, dy)
      local new_div = pandoc.Div(processed_div_content)
      new_div.attr = block.attr  -- preserve attributes
      table.insert(new_content, new_div)
    else
      table.insert(new_content, block)
    end
  end

  return new_content
end

function Div(el)
    -- ::{.column-margin} - mark context for figure processing
    if el.classes:includes('column-margin') then
      local dy = el.attributes.dy or "0pt"
      print("Processing column-margin div with dy:", dy)

      -- Use recursive processing to find figures at any nesting level
      local new_content = process_content_for_figures(el.content, dy)

      print("Returning", #new_content, "blocks for column-margin")
      -- Return just the content, not wrapped in a div
      return new_content
    end

    -- ::{.fullwidth}
    if el.classes:includes('fullwidth') then
      local dx = el.attributes.dx or "0pt"
      local dy = el.attributes.dy or "0pt"
      local width = "100%+75.2mm"
      local blocks = pandoc.List({
        pandoc.RawBlock('typst', string.format('#set text(font: serif-fonts, size: marginfontsize); #block(width: %s)[', width))
      })
      blocks:extend(el.content)
      return endTypstBlock(blocks)
    end

    -- ::{.column-page-right} - handle images normally (no sidenote wrapper)
    if el.classes:includes('column-page-right') then
      local dx = el.attributes.dx or "0pt"
      local dy = el.attributes.dy or "2em"
      local width = "100%+75.2mm"

      -- Just wrap content in block without any special image processing
      local blocks = pandoc.List({
        pandoc.RawBlock('typst', string.format('#block(width: %s)[', width))
      })
      blocks:extend(el.content)
      return endTypstBlock(blocks)
    end
  end

function Figure(el)
  -- For figures outside column-margin, process normally
  return el
end

-- Removed the global Image function that was automatically converting all images to sidenotes
-- Images are now only processed within their specific div contexts (.column-margin, .column-page-right, etc.)
