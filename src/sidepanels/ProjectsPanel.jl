type ProjectsPanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    tree_view::GtkTreeView
    add_button::GtkButton
    main_window::MainWindow
    

    function ProjectsPanel(main_window::MainWindow)

        (tv,list,cols) = give_me_a_treeview(1,["Name"])

        vbox = GtkBox(:v)
        add_button = GtkButton("A")
        bbox = GtkButtonBox(false)
        push!(bbox,add_button)

        sc = GtkScrolledWindow()
        setproperty!(sc,:vexpand,true)
        push!(sc,tv)

        push!(vbox,bbox,sc)
        setproperty!(bbox,:layout_style, Gtk.GConstants.GtkButtonBoxStyle.GTK_BUTTONBOX_START)
        
        t = new(vbox.handle,list,tv,add_button,main_window)

        signal_connect(projectspanel_treeview_clicked_cb,tv, "button-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        signal_connect(projectspanel_treeview_keypress_cb,tv, "key-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        
        signal_connect(projectspanel_add_button_clicked_cb, add_button, "clicked", Void, (), false, t)

        Gtk.gobject_move_ref(t,vbox)
    end
end

function update!(w::ProjectsPanel)

    n = readdir(joinpath(HOMEDIR,"config","projects"))
    n = filter(x -> extension(x) == ".json", n)
    n = map(x->splitext(x)[1], n)

    empty!(w.list)
    for i = 1:length(n)
        push!(w.list,(n[i],))
    end

end

function add_project(w::ProjectsPanel)
    ok, name = input_dialog("Project name","project",(("Cancel",0),("Ok",1)),w.main_window)
    ok == 0 && return

    w.main_window.project.name = name
    save(w.main_window.project)
    save(w.main_window)

end

function projectspanel_add_button_clicked_cb(widgetptr::Ptr, user_data)
    w = user_data
    add_project(w)
    update!(w)
    return nothing
end

function on_path_change(w::ProjectsPanel)

end

function load(w::ProjectsPanel,treeview::GtkTreeView,list::GtkTreeStore)

    v = selected(treeview, list)
    v == nothing && return

    main_window = w.main_window
    editor = main_window.editor

    project.name = v[1]
    load(project)
    cd(project.path)
    empty!(editor)
    load_tabs(editor,project)
    save(main_window)
    on_path_change(main_window)
end

@guarded (PROPAGATE) function projectspanel_treeview_clicked_cb(widgetptr::Ptr, eventptr::Ptr, projectspanel)

    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = projectspanel.list
    
    if event.button == 3

    else
        if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
            load(projectspanel,treeview,list)
        end
    end
    return PROPAGATE
end

@guarded (PROPAGATE) function projectspanel_treeview_keypress_cb(widgetptr::Ptr, eventptr::Ptr, projectspanel)
    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = projectspanel.list
    if event.keyval == Gtk.GdkKeySyms.Return
        load(projectspanel,treeview,list)
    end
    return PROPAGATE
end

