function add_side_panel(w::Gtk.GtkWidget,title::AbstractString)
    push!(sidepanel_ntbook,w)
    set_tab_label_text(sidepanel_ntbook,w,title)
end

type WorkspacePanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    label::GtkLabel

    function WorkspacePanel()
        l = @GtkLabel("")
        sc = @GtkScrolledWindow()
        push!(sc,l)

        t = new(sc.handle,l)
        Gtk.gobject_move_ref(t,sc)
    end
end

function update!(w::WorkspacePanel)

    n = map(string,names(Main))
    str = "\n "
    for el in n
        str = str * el * "\n "
    end
    setproperty!(w.label,:label,str)
end

workspacepanel = WorkspacePanel()
update!(workspacepanel)
add_side_panel(workspacepanel,"W")

#### FILES PANEL

type FilesPanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    label::GtkLabel

    function FilesPanel()
        l = @GtkLabel("")
        sc = @GtkScrolledWindow()
        push!(sc,l)

        t = new(sc.handle,l)
        Gtk.gobject_move_ref(t,sc)
    end
end

function update!(w::FilesPanel)

    n = readdir()
    str = "\n "
    for el in n
        str = str * el * "\n "
    end
    setproperty!(w.label,:label,str)
end

filespanel = FilesPanel()
update!(filespanel)
add_side_panel(filespanel,"F")

@schedule begin
    while(true)
        sleep(0.5)
        update!(filespanel)
    end
end




