
mutable struct SidePanelManager <: GtkNotebook

    handle::Ptr{Gtk.GObject}
    main_window
    panels
    
    function SidePanelManager(main_window)

        ntb = GtkNotebook()
        set_gtk_property!(ntb, :vexpand, true)

        # for some strange reason panel aren't type correctly, so I also have them in 
        # that variable as well
        panels = Any[]
        n = new(ntb.handle, main_window, panels)
        Gtk.gobject_move_ref(n, ntb)
    end
end

function init!(sp::SidePanelManager, panels, titles)
    for (p,t) in zip(panels, titles)
        push!(sp, p)
        push!(sp.panels, p)
        Gtk.GAccessor.tab_label_text(sp, p, t)
    end
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
