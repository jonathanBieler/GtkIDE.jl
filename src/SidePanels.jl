
function add_side_panel(w::Gtk.GtkWidget,title::AbstractString)
    push!(sidepanel_ntbook,w)
    set_tab_label_text(sidepanel_ntbook,w,title)
end
function files_tree_view(rownames)
    n  = length(rownames)
    t = (Gtk.GdkPixbuf,AbstractString, AbstractString)
    list = @GtkTreeStore(t...)

    tv = @GtkTreeView(GtkTreeModel(list))



    cols = Array(GtkTreeViewColumn,0)

    r1 = @GtkCellRendererPixbuf()
    c1 = @GtkTreeViewColumn(rownames[1], r1, Dict([("pixbuf",0)]))
    Gtk.G_.sort_column_id(c1,0)
    push!(cols,c1)
    Gtk.G_.max_width(c1,Int(200/n))
    push!(tv,c1)

    r2 = @GtkCellRendererText()
    c2 = @GtkTreeViewColumn(rownames[2], r2, Dict([("text",1)]))
    Gtk.G_.sort_column_id(c2,1)
    push!(cols,c2)
    Gtk.G_.max_width(c2,Int(200/n))
    push!(tv,c2)



    return (tv,list,cols)
end
function give_me_a_treeview(n,rownames)

    t = ntuple(i->AbstractString,n)
    list = @GtkTreeStore(t...)

    tv = @GtkTreeView(GtkTreeModel(list))

    cols = Array(GtkTreeViewColumn,0)

    for i=1:n
        r1 = @GtkCellRendererText()
        c1 = @GtkTreeViewColumn(rownames[i], r1, Dict([("text",i-1)]))
        Gtk.G_.sort_column_id(c1,i-1)
        push!(cols,c1)
        Gtk.G_.max_width(c1,Int(200/n))
        push!(tv,c1)
    end

    return (tv,list,cols)
end

import Gtk.selected
function selected(tree_view::GtkTreeView,list::GtkTreeStore)
    selmodel = Gtk.G_.selection(tree_view)
    if hasselection(selmodel)
        iter = selected(selmodel)
        return list[iter]
    end
    return nothing
end
#select the first entry that is equal to v
function select_value(tree_view::GtkTreeView,list::GtkTreeStore,v)
    selmodel = Gtk.G_.selection(tree_view)
    for i = 1:length(list)
        if list[i] == v
            select!(selmodel, Gtk.iter_from_index(list, i))
            return
        end
    end
end

#### FILES PANEL
function get_selected_path(treeview::GtkTreeView,list::GtkTreeStore)
    v = selected(treeview, list)
    if v != nothing && length(v) == 3
        return v[3]
    else
        return nothing
    end
end
function get_selected_file(treeview::GtkTreeView,list::GtkTreeStore)
    path = get_selected_path(treeview,list)
    if (isfile(path))
        return path
    else
        return nothing
    end
end
function open_file(treeview::GtkTreeView,list::GtkTreeStore)
    file = get_selected_file(treeview,list)
    if file != nothing
        open_in_new_tab(file)
    end
end
#=File path menu =#
function path_dialog_create_file_cb(ptr::Ptr, data)
    (path,filename) = data
    println(getproperty(filename, :text, AbstractString))
    return nothing
end
function path_dialog_filename_inserted_text(text_entry_buffer_ptr::Ptr, cursor_pos,new_text::Cstring,n_chars,data)
    path = data[1]
    delete_signal_id = data[2]
    text_entry_buffer = convert(GtkEntryBuffer, text_entry_buffer_ptr)
    if (cursor_pos < length(path))
        Gtk.signal_handler_block(text_entry_buffer, delete_signal_id[])
        delete_text(text_entry_buffer,cursor_pos,n_chars)
        Gtk.signal_handler_unblock(text_entry_buffer, delete_signal_id[])
    end
    return nothing
end
function path_dialog_filename_deleted_text(text_entry_buffer_ptr::Ptr, cursor_pos,n_chars,data)
    path = data[1]
    insert_signal_id = data[2]
    text_entry_buffer = convert(GtkEntryBuffer, text_entry_buffer_ptr)
    if (cursor_pos < length(path))
        println(cursor_pos)
        Gtk.signal_handler_block(text_entry_buffer, insert_signal_id[])
        insert_text(text_entry_buffer,cursor_pos, path[cursor_pos+1:min(end,cursor_pos+n_chars+1)],n_chars)
        Gtk.signal_handler_unblock(text_entry_buffer, insert_signal_id[])
    end
    return nothing
end
function show_file_path_dialog(path)
    path = string(path,"/")
    b = Gtk.GtkBuilderLeaf(filename=joinpath(dirname(@__FILE__),"forms/forms.glade"))
    w = GAccessor.object(b,"DialogCreateFile")
    btn_create_file = GAccessor.object(b,"btnCreateFile")
    te_filename = GAccessor.object(b,"filename")
    setproperty!(te_filename, :text,path);
    te_filename_buffer = buffer(te_filename)
    const id_signal_insert = [Culong(0)]
    const id_signal_delete = [Culong(0)]
    id_signal_insert[1] = signal_connect(path_dialog_filename_inserted_text,
                  te_filename_buffer,
                  "inserted-text",
                  Void,
                  (Cuint,Cstring,Cuint),false,(path,id_signal_delete))
    id_signal_delete[1] = signal_connect(path_dialog_filename_deleted_text,
                   te_filename_buffer,
                   "deleted-text",
                    Void,
                    (Cuint,Cuint),false,(path,id_signal_insert))
    signal_connect(path_dialog_create_file_cb,btn_create_file, "clicked",Void,(),false,(path,te_filename))
    showall(w)
end
#==========#

function filespanel_treeview_clicked_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    (list,menu) = user_data
    if event.button == 3
        showall(menu)
        popup(menu,event)
    else
        if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
            open_file(treeview,list)
        end
    end

    return PROPAGATE
end

function filespanel_treeview_keypress_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = user_data

    if event.keyval == Gtk.GdkKeySyms.Return
        open_file(treeview,list)
    end

    return PROPAGATE
end

function filespanel_newFileItem_activate_cb(widgetptr::Ptr,user_data)
    (list,treeview)     = user_data
    path = get_selected_path(treeview,list)
    if (path!=nothing)
        path = dirname(path)
        show_file_path_dialog(path)
    end
    return nothing
end

type FilesPanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    tree_view::GtkTreeView
    menu::GtkMenu
    function FilesPanel()

        (tv,list,cols) = files_tree_view(["Icon","Name"])

        menu = @GtkMenu(file) |>
            (newFileItem = @GtkMenuItem("New File")) |>
            (newFolderItem = @GtkMenuItem("New Folder")) |>
            @GtkSeparatorMenuItem() |>
            (quitMenuItem = @GtkMenuItem("Quit"))


        signal_connect(filespanel_treeview_clicked_cb,tv, "button-press-event",
        Cint, (Ptr{Gtk.GdkEvent},), false,(list,menu))
        signal_connect(filespanel_treeview_keypress_cb,tv, "key-press-event",
        Cint, (Ptr{Gtk.GdkEvent},), false,list)

        sc = @GtkScrolledWindow()
        push!(sc,tv)




        signal_connect(filespanel_newFileItem_activate_cb, newFileItem,
                        "activate", Void, (), false, (list,tv))


        t = new(sc.handle,list,tv,menu)
        Gtk.gobject_move_ref(t,sc)
    end
end

function update!(w::FilesPanel, path::AbstractString, parent=nothing)
    pixbuf = GtkIconThemeLoadIconForScale(GtkIconThemeGetDefault(),"folder",24,1,0)
    folder = push!(w.list,(pixbuf,basename(path),path),parent)
    n = readdir(path)
    for el in n
        full_path = joinpath(path,string(el))
        if isdir(full_path)
            update!(w,full_path, folder )
        else
           file_parts = splitext(el)
           if  (file_parts[2]==".jl")
             pixbuf = GtkIconThemeLoadIconForScale(GtkIconThemeGetDefault(),"code",24,1,0)
             push!(w.list,(pixbuf,el, joinpath(path,el)),folder)
           end
         end
    end
end

function update!(w::FilesPanel)


    sel_val = selected(w.tree_view,w.list)
    empty!(w.list)
    update!(w,pwd())

    sel_val != nothing && select_value(w.tree_view,w.list,sel_val)
end

filespanel = FilesPanel()
update!(filespanel)
add_side_panel(filespanel,"Files")

#FIXME I should stop all tasks when exiting
#this can make it crash if it runs while sorting
@schedule begin
    while(false)
        sleep(1.0)
        update!(filespanel)
    end
end

#### WORKSPACE PANEL

type WorkspacePanel <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    tree_view::GtkTreeView

    function WorkspacePanel()

        (tv,list,cols) = give_me_a_treeview(2,["Name","Type"])

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
    M = sortrows([t n])#FIXME use tree view sorting?
    n = M[:,2]
    t = M[:,1]

    ##

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
