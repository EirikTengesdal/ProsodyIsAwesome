-- Add booktabs styling to all tables by modifying the table structure
-- This filter adds booktabs class and modifies the table to include row count information

local is_typst = FORMAT == "typst"

return {
  -- Process Pandoc Table elements to add booktabs styling
  Table = function(el)
    if not is_typst then return nil end

    -- Add booktabs class to all tables if not already present
    local has_booktabs = false
    for _, class in ipairs(el.classes) do
      if class == "booktabs" then
        has_booktabs = true
        break
      end
    end

    if not has_booktabs then
      table.insert(el.classes, "booktabs")
    end

    -- Count total rows to help with dynamic bottom rule placement
    local total_rows = 0

    -- Count header rows
    if el.head and el.head.rows then
      total_rows = total_rows + #el.head.rows
    end

    -- Count body rows
    if el.bodies then
      for _, body in ipairs(el.bodies) do
        if body.body then
          total_rows = total_rows + #body.body
        end
      end
    end

    -- Count foot rows
    if el.foot and el.foot.rows then
      total_rows = total_rows + #el.foot.rows
    end

    -- Store the total row count as an attribute
    el.attributes = el.attributes or {}
    el.attributes["total-rows"] = tostring(total_rows)

    return el
  end
}