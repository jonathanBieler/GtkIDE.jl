#FIXME globals
function add_side_panel(w::Gtk.GtkWidget, title::AbstractString)
    push!(sidepanel_ntbook, w)
    Gtk.GAccessor.tab_label_text(sidepanel_ntbook, w, title)
end
function give_me_a_treeview(n, rownames)

    t = ntuple(i->AbstractString, n)
    list = GtkTreeStore(t...)

    tv = GtkTreeView(GtkTreeModel(list))

    cols = GtkTreeViewColumn[]

    for i=1:n
        r1 = GtkCellRendererText()
        c1 = GtkTreeViewColumn(rownames[i], r1, Dict([("text", i-1)]))
        Gtk.G_.sort_column_id(c1, i-1)
        push!(cols, c1)
        Gtk.G_.max_width(c1, Int(200/n))
        push!(tv, c1)
    end

    return (tv, list, cols)
end

include(joinpath("sidepanels", "FilesPanel.jl"))
include(joinpath("sidepanels", "WorkspacePanel.jl"))
include(joinpath("sidepanels", "ProjectsPanel.jl"))

