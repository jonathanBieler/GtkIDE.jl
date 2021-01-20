function selected(tree_view::GtkTreeView, list::GtkTreeStore)
    selmodel = Gtk.GAccessor.selection(tree_view)
    if hasselection(selmodel)
        iter = selected(selmodel)
        return list[iter]
    end
    return nothing
end

#select the first entry that is equal to v
function select_value(tree_view::GtkTreeView,list::GtkTreeStore,v)
    selmodel = Gtk.GAccessor.selection(tree_view)
    for i = 1:length(list)
        if list[i] == v
            partialsort!(selmodel, Gtk.iter_from_index(list, i))
            return
        end
    end
end

expand_root(tree_view::GtkTreeView) = Gtk.expand_to_path(tree_view, Gtk.treepath("0"))

gdk_keyval_name(val) = unsafe_string(
    ccall((:gdk_keyval_name,libgtk),Ptr{UInt8},(Cuint,),val),
true)