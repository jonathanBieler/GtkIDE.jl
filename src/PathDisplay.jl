type PathComboBox <: GtkComboBoxText
    handle::Ptr{Gtk.GObject}
    entry::GtkEntry
    time_last_keypress::AbstractFloat

    function PathComboBox()

        cbox = @GtkComboBoxText(true)
        entry = cbox[1]

        p = new(cbox.handle, entry, time())
        Gtk.gobject_move_ref(p, cbox)
    end
end

pathCBox = PathComboBox()

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
        on_path_change()
    end

    return convert(Cint,false)
end
signal_connect(pathEntry_key_press_cb, pathCBox.entry, "key-press-event",
Cint, (Ptr{Gtk.GdkEvent},), false, pathCBox)

@guarded (nothing) function pathDbox_changed_cb(ptr::Ptr, user_data)

    pathCBox = convert(GtkComboBoxText, ptr)

    #@show time() - pathCBox.time_last_keypress

    if time() - pathCBox.time_last_keypress < 0.1
        return nothing
    end

    pth = bytestring(Gtk.G_.active_text(pathCBox))
    try
        cd(pth)
    catch err
        println(string(err))
    end

    on_path_change()
    nothing
end
signal_connect(pathDbox_changed_cb,pathCBox,"changed", Void, (), false)

update_pathEntry() = setproperty!(pathCBox.entry, :text, pwd())

function init(pathCBox::PathComboBox)

    setproperty!(pathCBox.entry, :widht_request, 400)
    
    update_pathEntry()

    setproperty!(pathCBox.entry,:hexpand,true)

    sc = Gtk.G_.style_context(pathCBox.entry)
    push!(sc, provider, 600)
end
