-- Adds the text helpers of Style.lua to a test stub of ns.Style, so the tests see the same label and value text.
return function(Style)
    Style.gold, Style.white = Style.gold or 'gold', Style.white or 'white'
    Style.Text = Style.Text or function(color, text) return '|c' .. color .. tostring(text) .. '|r' end
    Style.Label = function(text) return Style.Text(Style.gold, text) end
    Style.Value = function(text) return Style.Text(Style.white, text) end
    Style.Range = function(first, last, total, what)
        return Style.Label('Showing ') .. Style.Value(first .. '-' .. last) .. Style.Label(' of ') .. Style.Value(total)
            .. (what and Style.Label(' ' .. what) or '')
    end
end
