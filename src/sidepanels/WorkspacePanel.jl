mutable struct WorkspacePanel <: GtkScrolledWindow
    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    tree_view::GtkTreeView
    main_window::MainWindow

    function WorkspacePanel(main_window::MainWindow)

        (tv,list,cols) = give_me_a_treeview(2,["Name","Summary"])

        sc = GtkScrolledWindow()
        push!(sc,tv)
        t = new(sc.handle,list,tv,main_window)

        signal_connect(workspacepanel_treeview_clicked_cb,tv, "button-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        signal_connect(workspacepanel_treeview_keypress_cb,tv, "key-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        
        Gtk.gobject_move_ref(t,sc)
    end
end

function var_info(s::Symbol, mod)
    try
        #return string(typeof(getfield(mod,s))) #FIXME: call on worker
        return summary(Core.eval(mod,s))
    catch err
    end
    ""
end

function on_path_change(w::WorkspacePanel, path)
    
end

function update!(w::WorkspacePanel)

    !visible(w) && return nothing #updating is a bit costly

    mod = current_console(w.main_window).eval_in
    n = sort!(names(mod,all=true))
    t = map(s->var_info(s,mod),n)
    n = map(string,n)

    idx = (t .!= "Module") .& map(s->!startswith(s,"#"),n)
    n,t = n[idx], t[idx]
    
    #M = sortslices([t n n], dims=1)#FIXME use tree view sorting?
    #n = M[:,2]
    #t = M[:,1]

    #sel_val = selected(w.tree_view,w.list)
    empty!(w.list)
    for i = 1:length(t)
        push!(w.list,(n[i],t[i]))
    end

    #sel_val != nothing && select_value(w.tree_view,w.list,sel_val) #this crashes
end

function open_variable(treeview::GtkTreeView,list::GtkTreeStore,main_window::MainWindow)
    v = selected(treeview, list)
    if v != nothing
        GtkREPL.command(current_console(main_window),v[1])
        GtkREPL.on_return(current_console(main_window),v[1])
    end
end

@guarded (PROPAGATE) function workspacepanel_treeview_clicked_cb(widgetptr::Ptr, eventptr::Ptr, workspacepanel)

    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = workspacepanel.list
    
    if event.button == 3

    else
        if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
            open_variable(treeview,list,workspacepanel.main_window)
        end
    end
    return PROPAGATE
end

@guarded (PROPAGATE) function workspacepanel_treeview_keypress_cb(widgetptr::Ptr, eventptr::Ptr, workspacepanel)
    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = workspacepanel.list
    if event.keyval == GdkKeySyms.Return
        open_variable(treeview,list,workspacepanel.main_window)
    end
    return PROPAGATE
end

