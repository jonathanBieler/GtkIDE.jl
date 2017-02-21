type ConsoleManager <: GtkNotebook

    handle::Ptr{Gtk.GObject}
    main_window::MainWindow

    function ConsoleManager(main_window::MainWindow)

        ntb = @GtkNotebook()
        
        n = new(ntb.handle,main_window)
        Gtk.gobject_move_ref(n, ntb)
    end
end

current_console(m::ConsoleManager) = m[index(m)]