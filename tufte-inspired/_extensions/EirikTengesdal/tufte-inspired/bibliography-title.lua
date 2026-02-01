-- bibliography-title.lua

local DEBUG = true  -- Set to false to disable debug output

if DEBUG then print("\n========== [9] BIBLIOGRAPHY-TITLE.LUA STARTING ==========") end

function Pandoc(doc)
  for i, el in ipairs(doc.blocks) do
    if el.t == "Div" and el.identifier == "refs" then
      for j, innerEl in ipairs(el.content) do
        if innerEl.t == "Header" and innerEl.level == 1 then
          innerEl.content = {pandoc.Str("Referanser")}
        end
      end
    end
  end
  return doc
end