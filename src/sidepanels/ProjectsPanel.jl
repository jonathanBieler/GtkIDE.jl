mutable struct ProjectsPanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    treeview::GtkTreeView
    add_button::GtkToolButton
    main_window::MainWindow
    

    function ProjectsPanel(main_window::MainWindow)

        tv,list,cols = projectspanel_treeview()

        vbox = GtkBox(:v)
        add_button = GtkToolButton("gtk-add")
        rm_button = GtkToolButton("gtk-remove")
        bbox = GtkButtonBox(false)
        push!(bbox,add_button,rm_button)

        sc = GtkScrolledWindow()
        set_gtk_property!(sc,:vexpand,true)
        set_gtk_property!(sc,:hscrollbar_policy,1)
        push!(sc,tv)

        push!(vbox,bbox,sc)
        set_gtk_property!(bbox,:layout_style, Gtk.GConstants.GtkButtonBoxStyle.GTK_BUTTONBOX_START)
        
        t = new(vbox.handle,list,tv,add_button,main_window)

        signal_connect(projectspanel_treeview_clicked_cb,tv, "button-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        signal_connect(projectspanel_treeview_keypress_cb,tv, "key-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        
        signal_connect(projectspanel_add_button_clicked_cb, add_button, "clicked", Nothing, (), false, t)
        signal_connect(projectspanel_rm_button_clicked_cb, rm_button, "clicked", Nothing, (), false, t)

        Gtk.gobject_move_ref(t,vbox)
    end
end

function projectspanel_treeview()

    list = GtkTreeStore(String, Int)
    tv = GtkTreeView(GtkTreeModel(list))

    cell = GtkCellRendererText()
    cols = GtkTreeViewColumn("Name", cell, Dict([("text",0),("weight",1)]))#the second collumn controls the font weight
    push!(tv,cols)

    return tv,list,cols
end

function update!(w::ProjectsPanel)

    n = readdir(joinpath(HOMEDIR,"config","projects"))
    n = filter(x -> extension(x) == ".json", n)
    n = map(x->splitext(x)[1], n)

    empty!(w.list)
    for i = 1:length(n)
        weight = n[i] == w.main_window.project.name ? 800 : 400 #bold the select project
        push!(w.list,(n[i],weight))
    end

end

function add_project(w::ProjectsPanel)
    ok, name = input_dialog("Project name","project",(("Cancel",0),("Ok",1)),w.main_window)
    ok == 0 && return

    w.main_window.project.name = name
    save(w.main_window.project)
    save(w.main_window)
end

function remove_project(w::ProjectsPanel)
    
    v = selected(w.treeview, w.list)
    v == nothing && return
    
    name = v[1]
    name == "default" && return #can't delete default
    
    rm(joinpath(HOMEDIR,"config","projects","$(name).json"))
    
    if name == project.name #when current, load default
        load(project,"default", w.main_window.editor, w.main_window; dosave=false)#we shouldn't resave the project we just deleted
    end
end

@guarded nothing function projectspanel_add_button_clicked_cb(widgetptr::Ptr, user_data)
    w = user_data
    add_project(w)
    update!(w)
    return nothing
end

@guarded nothing function projectspanel_rm_button_clicked_cb(widgetptr::Ptr, user_data)
    w = user_data
    remove_project(w)
    update!(w)
    return nothing
end

function on_path_change(w::ProjectsPanel, path)
end

function load(w::ProjectsPanel,treeview::GtkTreeView,list::GtkTreeStore)

    v = selected(treeview, list)
    v == nothing && return

    main_window = w.main_window
    editor = main_window.editor

    load(project,v[1], editor, main_window)
    update!(w)
end

function load(project::Project,name::String, editor::Editor, main_window::MainWindow; dosave=true)

    dosave && save(main_window.project)

    project.name = name
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
    if event.keyval == GdkKeySyms.Return
        load(projectspanel,treeview,list)
    end
    return PROPAGATE
end

