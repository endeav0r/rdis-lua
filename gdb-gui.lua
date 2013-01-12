require('gdb-util')

GDB_GUI = nil

function gdb_gui_reset ()
    GDB_GUI = nil
end


function gdb_gui_step ()
    GDB_GUI.gdb:step()
    gdb_gui_set_registers()
end


function gdb_gui_update_memory ()
    gdb_remote_update_mem(GDB_GUI.gdb)
    rdis.console("memory update done")
end


function gdb_gui_continue ()
    GDB_GUI.gdb:continue()
    gdb_gui_set_registers()
end


function gdb_gui_kill ()
    GDB_GUI.gdb:kill()
end


function gdb_gui_add_breakpoint ()
    local button = Gtk.Button { label = "Add Breakpoint" }
    local entry  = Gtk.Entry {}
    local window = Gtk.Window {
        title = "Add Breakpoint",
        default_width = 200,
        default_height = 80,
        Gtk.Box {
            orientation = 'VERTICAL',
            spacing = 4,
            Gtk.Label { label = "Enter Breakpoint Address" },
            entry,
            button
        }
    }

    window:show_all()

    function button:on_clicked()
        local address = uint64(entry:get_text())
        window:destroy()
        rdis.console('adding breakpoint ' .. tostring(address))
        GDB_GUI.gdb:add_breakpoint(address)
        gdb_gui_set_breakpoints()
    end
end


function gdb_gui_set_registers ()
    GDB_GUI.registerStore:clear()
    local registers = GDB_GUI.gdb:registers()

    -- we will write the registers in the order intended
    for k,register in pairs(GDB_GUI.gdb.architecture.registers) do
        GDB_GUI.registerStore:append({register[1], registers[register[1]]})
    end
end


function gdb_gui_set_breakpoints ()
    GDB_GUI.breakpointStore:clear()

    for k,breakpoint in pairs(GDB_GUI.gdb.breakpoints) do
        GDB_GUI.breakpointStore:append({tostring(breakpoint)})
    end
end


function gdb_gui(host, port, arch)
    if GDB_GUI ~= nil then
        rdis.console("gdb gui instance already running")
        return
    end

    local gdb = gdb_remote(host, port, arch)
    if gdb == nil then
        return nil
    end

    local gui = {
        gdb = gdb
    }

    gui.window = Gtk.Window {
        title = "Gdb Remote " .. host .. ":" .. tostring(port),
        default_width = 600,
        default_height = 400,
        on_destroy = gdb_gui_reset
    }

    gui.stepButton = Gtk.Button {
        label = "Step",
        on_clicked = gdb_gui_step
    }

    gui.updateMemoryButton = Gtk.Button {
        label = "Update Memory",
        on_clicked = gdb_gui_update_memory
    }

    gui.addBreakpointButton = Gtk.Button {
        label = "Add Breakpoint",
        on_clicked = gdb_gui_add_breakpoint
    }

    gui.continueButton = Gtk.Button {
        label = "Continue",
        on_clicked = gdb_gui_continue
    }

    gui.killButton = Gtk.Button {
        label = "Kill",
        on_clicked = gdb_gui_kill
    }

    gui.registerColumn = {
        NAME  = 1,
        VALUE = 2
    }

    gui.registerStore = Gtk.ListStore.new {
        [gui.registerColumn.NAME] = lgi.GObject.Type.STRING,
        [gui.registerColumn.VALUE] = lgi.GObject.Type.STRING
    }

    gui.registerWindow = Gtk.ScrolledWindow {
        expand = true,
        Gtk.TreeView {
            model = gui.registerStore,
            Gtk.TreeViewColumn {
                title = "Register",
                {
                    Gtk.CellRendererText {},
                    { text = gui.registerColumn.NAME }
                }
            },
            Gtk.TreeViewColumn {
                title = "Value",
                {
                    Gtk.CellRendererText { font = "monospace" },
                    { text = gui.registerColumn.VALUE }
                }
            }
        }
    }

    gui.breakpointColumn = {
        ADDRESS = 1
    }

    gui.breakpointStore = Gtk.ListStore.new {
        [gui.breakpointColumn.ADDRESS] = lgi.GObject.Type.STRING
    }

    gui.breakpointWindow = Gtk.ScrolledWindow {
        expand = true,
        Gtk.TreeView {
            model = gui.breakpointStore,
            Gtk.TreeViewColumn {
                title = "Breakpoint Address",
                {
                    Gtk.CellRendererText {font = "monospace" },
                    { text = gui.breakpointColumn.ADDRESS }
                }
            }
        }
    }

    gui.buttonBox = Gtk.Box {
        orientation = 'VERTICAL',
        spacing = 4
    }

    gui.hbox = Gtk.Box {
        orientation = "HORIZONTAL",
        spacing = 4
    }

    gui.buttonBox:add(gui.stepButton)
    gui.buttonBox:add(gui.updateMemoryButton)
    gui.buttonBox:add(gui.addBreakpointButton)
    gui.buttonBox:add(gui.continueButton)
    gui.buttonBox:add(gui.killButton)

    gui.hbox:add(gui.buttonBox)
    gui.hbox:add(gui.registerWindow)
    gui.hbox:add(gui.breakpointWindow)

    gui.window:add(gui.hbox)
    gui.window:show_all()

    GDB_GUI = gui

    gdb_gui_set_registers()

end