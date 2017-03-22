type PathComboBox <: GtkComboBoxText
    handle::Ptr{Gtk.GObject}
    entry::GtkEntry
    time_last_keypress::AbstractFloat
    main_window::MainWindow

    function PathComboBox(main_window::MainWindow)
        cbox = GtkComboBoxText(true)
        entry = cbox[1]

        p = new(cbox.handle, entry, time(), main_window)
        Gtk.gobject_move_ref(p, cbox)
    end
end

update_pathEntry(pathCBox::PathComboBox) = setproperty!(pathCBox.entry, :text, pwd())
update_pathEntry(main_window::MainWindow) = update_pathEntry(main_window.pathCBox)

function pathEntry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    pathCBox = user_data
    pathCBox.time_last_keypress = time()

    if event.keyval == Gtk.GdkKeySyms.Return
        pth = getproperty(widget,:text,AbstractString)
        try
            cd(pth)
        catch err
            println(string(err))
        end
        on_path_change(pathCBox.main_window,true)
    end

    return convert(Cint,false)
end

@guarded (nothing) function pathDbox_changed_cb(ptr::Ptr, user_data)

    pathCBox = convert(GtkComboBoxText, ptr)

    #@show time() - pathCBox.time_last_keypress

    if time() - pathCBox.time_last_keypress < 0.1
        return nothing
    end

    pth = unsafe_string(Gtk.G_.active_text(pathCBox))
    try
        cd(pth)
    catch err
        println(string(err))
    end

    on_path_change(pathCBox.main_window)
    nothing
end

function init!(pathCBox::PathComboBox)

    signal_connect(pathEntry_key_press_cb, pathCBox.entry, "key-press-event",
    Cint, (Ptr{Gtk.GdkEvent},), false, pathCBox)

    signal_connect(pathDbox_changed_cb,pathCBox,"changed", Void, (), false)

    setproperty!(pathCBox.entry, :width_request, 400)
    update_pathEntry(pathCBox)
    setproperty!(pathCBox.entry,:hexpand,true)

    sc = Gtk.G_.style_context(pathCBox.entry)
    push!(sc, style_provider(pathCBox.main_window), 600)
end
