lgi = require("lgi")
Gtk = lgi.Gtk

if lgi == nil then
    rdis.console("lgi failed to load")
else
    rdis.console("lgi loaded")
end

require("gdb-gui")

function gui_test ()
    local window = Gtk.Window {
        title = "test window"
    }
    
    local button = Gtk.Button {
        label = "the button",
        on_clicked = function () rdis.console("hello") end
    }
    
    window:add(button)
    
    window:show_all()
end
