function add_side_panel(w::Gtk.GtkWidget,title::AbstractString)
    push!(sidepanel_ntbook,w)
    set_tab_label_text(sidepanel_ntbook,w,title)
end

function give_me_a_treeview(n)

    t = ntuple(i->AbstractString,n)
    list = @GtkListStore(t...)

    tv = @GtkTreeView(GtkTreeModel(list))

    for i=1:n
        r1 = @GtkCellRendererText()
        c1 = @GtkTreeViewColumn("", r1, Dict([("text",i-1)]))
        Gtk.G_.max_width(c1,Int(200/n))
        push!(tv,c1)
    end

    return (tv,list)
end

#### FILES PANEL

type FilesPanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkListStore
    tree_view::GtkTreeView

    function FilesPanel()

        (tv,list) = give_me_a_treeview(1)

        sc = @GtkScrolledWindow()
        push!(sc,tv)

        t = new(sc.handle,list,tv)
        Gtk.gobject_move_ref(t,sc)
    end
end

import Gtk.selected
function selected(tree_view::GtkTreeView,list::GtkListStore)
    selmodel = Gtk.G_.selection(tree_view)
    if hasselection(selmodel)
        iter = selected(selmodel)
        return list[iter]
    end
    return nothing
end
#select the first entry that is equal to v
function select_value(tree_view::GtkTreeView,list::GtkListStore,v)
    selmodel = Gtk.G_.selection(tree_view)
    for i = 1:length(list)
        if list[i] == v
            select!(selmodel, Gtk.iter_from_index(list, i))
            return
        end
    end
end

function update!(w::FilesPanel)

    n = readdir()

    sel_val = selected(w.tree_view,w.list)

    empty!(w.list)
    for el in n
        push!(w.list,(el,))
    end

    sel_val != nothing && select_value(w.tree_view,w.list,sel_val)
end

filespanel = FilesPanel()
update!(filespanel)
add_side_panel(filespanel,"F")

#FIXME I should stop all tasks when exiting
@schedule begin
    while(true)
        sleep(1.0)
        update!(filespanel)
    end
end

#### WORKSPACE PANEL

type WorkspacePanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkListStore
    tree_view::GtkTreeView

    function WorkspacePanel()

        (tv,list) = give_me_a_treeview(2)

        sc = @GtkScrolledWindow()
        push!(sc,tv)

        t = new(sc.handle,list,tv)
        Gtk.gobject_move_ref(t,sc)
    end
end

function update!(w::WorkspacePanel)

    ##
    function gettype(s::Symbol)
        try
            return string(typeof(getfield(Main,s)))
        end
        ""
    end

    n = sort!(names(Main))
    t = map(gettype,n)
    n = map(string,n)

    sel_val = selected(w.tree_view,w.list)

    empty!(w.list)
    for i = 1:length(t)
        push!(w.list,(n[i],t[i]))
    end

    sel_val != nothing && select_value(w.tree_view,w.list,sel_val)
end

workspacepanel = WorkspacePanel()
update!(workspacepanel)
add_side_panel(workspacepanel,"W")
