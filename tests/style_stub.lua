-- Adds the text helpers of Style.lua to a test stub of ns.Style, so the tests see the same label and value text.
return function(Style)
    Style.gold, Style.white = Style.gold or 'gold', Style.white or 'white'
    Style.Text = Style.Text or function(color, text) return '|c' .. color .. tostring(text) .. '|r' end
    Style.green = Style.green or 'green'
    Style.Date = function(text) return Style.Text(Style.green, text) end
    Style.Label = function(text) return Style.Text(Style.gold, text) end
    Style.Value = function(text) return Style.Text(Style.white, text) end
    -- List icons are left out of the compared text unless a test sets them.
    Style.Icon = Style.Icon or function() return '' end
    Style.ItemIcon = Style.ItemIcon or function() return '' end
    Style.SpellIcon = Style.SpellIcon or function() return '' end
    Style.ItemLabel = Style.ItemLabel or function(id)
        return Style.ItemIcon(id) .. (Style.ItemName and Style.ItemName(id) or Style.Value('Item ' .. id))
    end
    Style.Range = function(first, last, total, what)
        return Style.Label('Showing ') .. Style.Value(first .. '-' .. last) .. Style.Label(' of ') .. Style.Value(total)
            .. (what and Style.Label(' ' .. what) or '')
    end
end
