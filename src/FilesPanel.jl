(type_folder, type_file, type_placeholder) = (1,2,3)
function files_tree_view(rownames)
    n  = length(rownames)
    t = (Gtk.GdkPixbuf,AbstractString, AbstractString, Bool, Int)
    list = @GtkTreeStore(t...)
    tv = @GtkTreeView(GtkTreeModel(list))
    setproperty!(tv,"level-indentation",4)
    cols = Array(GtkTreeViewColumn,0)

    r1 = @GtkCellRendererPixbuf()
    c1 = @GtkTreeViewColumn(rownames[1], r1, Dict([("pixbuf",0)]))
    Gtk.G_.sort_column_id(c1,0)
    push!(cols,c1)
    #Gtk.G_.max_width(c1,Int(200/n))
    push!(tv,c1)

    r2 = @GtkCellRendererText()
    c2 = @GtkTreeViewColumn(rownames[2], r2, Dict([("text",1)]))
    Gtk.G_.sort_column_id(c2,1)
    push!(cols,c2)
    #Gtk.G_.max_width(c2,Int(200/n))
    push!(tv,c2)
    return (tv,list,cols)
end
type FilePathDialog
  dialog::GtkDialog
  signal_insert_id::Culong
  signal_delete_id::Culong
end

function FilePathDialog()
    w = GAccessor.object(form_builder,"DialogCreateFile")
    Gtk.GAccessor.transient_for(w,win)
    Gtk.GAccessor.modal(w,true)
    btn_create_file = GAccessor.object(form_builder,"btnCreateFile")
    signal_connect(close_file_path_dialog,btn_create_file, "clicked", Void, (), false,w)
    return FilePathDialog(w,0,0)

end
 function close_file_path_dialog(btn::Ptr,dialog)
    response(dialog,Gtk.GConstants.GtkResponseType.ACCEPT)
    return nothing
end
type FilesPanel <: GtkScrolledWindow
    handle::Ptr{Gtk.GObject}
    list::GtkTreeStore
    tree_view::GtkTreeView
    paste_action
    menu
    current_iterator
    path_dialog::FilePathDialog

    function FilesPanel()
        sc = @GtkScrolledWindow()
        (tv,list,cols) = files_tree_view(["Icon","Name"])
        push!(sc,tv)

        t = new(sc.handle,list,tv,nothing,nothing,nothing,FilePathDialog());
        t.menu = filespanel_context_menu_create(t)

        signal_connect(filespanel_treeview_clicked_cb,tv, "button-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        signal_connect(filespanel_treeview_keypress_cb,tv, "key-press-event",
                       Cint, (Ptr{Gtk.GdkEvent},), false,t)
        signal_connect(filespanel_treeview_row_expanded_cb,tv, "test-expand-row",
                       Cint, (Ptr{Gtk.TreeIter},Ptr{Gtk.TreePath}))
        Gtk.gobject_move_ref(t,sc)
    end
end
function copy_up(model::GtkTreeModel,iter::Gtk.GtkTreeIter)
  parent_iterator = Gtk.mutable(Gtk.GtkTreeIter)
  ret = Gtk.iter_parent(model,parent_iterator, iter)
  if (!ret)
    return nothing
  else
    return parent_iterator[]
  end
end
function filespanel_context_menu_create(t::FilesPanel)
    menu = @GtkMenu() |>
    (changeDirectoryItem = @GtkMenuItem("Change Directory")) |>
    (addToPathItem = @GtkMenuItem("Add to Path")) |>
    @GtkSeparatorMenuItem() |>
    (newFileItem = @GtkMenuItem("New File")) |>
    (newFolderItem = @GtkMenuItem("New Folder")) |>
    @GtkSeparatorMenuItem() |>
    (deleteItem = @GtkMenuItem("Delete")) |>
    (renameItem = @GtkMenuItem("Rename")) |>
    (copyItem = @GtkMenuItem("Copy")) |>
    (cutItem = @GtkMenuItem("Cut")) |>
    (pasteItem = @GtkMenuItem("Paste")) |>
    @GtkSeparatorMenuItem() |>
    (copyFullPathItem = @GtkMenuItem("Copy Full Path"))
    
    #FIXME disable until the dialog bugs are fixed
    setproperty!(newFileItem,:sensitive,false)
    setproperty!(newFolderItem,:sensitive,false)
    setproperty!(deleteItem,:sensitive,false)
    setproperty!(renameItem,:sensitive,false)
    setproperty!(copyItem,:sensitive,false)
    setproperty!(pasteItem,:sensitive,false)
    setproperty!(cutItem,:sensitive,false)

    signal_connect(filespanel_changeDirectoryItem_activate_cb,
    changeDirectoryItem, "activate",Void, (),false,t)
    signal_connect(filespanel_addToPathItem_activate_cb, addToPathItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_newFileItem_activate_cb, newFileItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_newFolderItem_activate_cb, newFolderItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_deleteItem_activate_cb, deleteItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_renameItem_activate_cb, renameItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_copyItem_activate_cb, copyItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_cutItem_activate_cb, cutItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_pasteItem_activate_cb, pasteItem,
    "activate",Void, (),false,t)
    signal_connect(filespanel_copyFullPathItem_activate_cb, copyFullPathItem,
    "activate",Void, (),false,t)
    return menu
end

function get_sorted_files(path)
    sort_paths = (x,y)->
    begin
        try
            if isdir(x) && isdir(y)
                return x < y
            elseif isdir(x)
                return true
            elseif isdir(y)
                return false
            else
                return x < y
            end
        catch err
            return true
        end
    end
    sort(readdir(path),lt=sort_paths, by=(x)->return joinpath(path,x))
end

function create_treestore_file_item(path::AbstractString, filename::AbstractString)
    pixbuf = GtkIconThemeLoadIconForScale(GtkIconThemeGetDefault(),"code",16,1,0)
    return (pixbuf,filename, joinpath(path,filename), true, type_file)
end
function create_treestore_placeholder_item()
    pixbuf = GtkIconThemeLoadIconForScale(GtkIconThemeGetDefault(),"code",24,1,0)
    return (pixbuf,"", "", true, type_placeholder)
end
function add_placeholder(list::GtkTreeStore, parent=nothing)
    return push!(list,create_treestore_placeholder_item(),parent)
end
function add_file(list::GtkTreeStore,path::AbstractString,filename::AbstractString, parent=nothing)
    return push!(list,create_treestore_file_item(path,filename),parent)
end
function insert_file(list::GtkTreeStore,path::AbstractString,filename::AbstractString, iter)
  return insert!(list,iter,create_treestore_file_item(path,filename), how=:sibling, where=:before)
end
function create_treestore_folder_item(path::AbstractString)
  pixbuf = GtkIconThemeLoadIconForScale(GtkIconThemeGetDefault(),"folder",24,1,0)
  return (pixbuf,basename(path),path,false,type_folder )
end
function add_folder(list::GtkTreeStore,path::AbstractString, parent=nothing)
    return push!(list,create_treestore_folder_item(path),parent)
end
function insert_folder(list::GtkTreeStore,path::AbstractString, iter)
    return insert!(list,iter,create_treestore_folder_item(path), how=:sibling, where=:before)
end
function populate_folder(w::GtkTreeStore,folder::GtkTreeIter)
    w[folder,4] = true #mark folderr as loaded
    path        = w[folder,3]
    n           = get_sorted_files(path)
    for el in n
        try #some operations are not allowed 
            full_path = joinpath(path,string(el))
            if isdir(full_path)
                child = add_folder(w,full_path,folder)
                add_placeholder(w,child)
            else
                file_parts = splitext(el)
                if  (file_parts[2]==".jl" || file_parts[2]==".md")#FIXME need something more general
                    add_file(w,path,el,folder)
                end
            end
        end
    end
end
function where_insert_folder(w::GtkTreeStore,path::AbstractString, parent)
    iter = Gtk.mutable(Gtk.GtkTreeIter)
    iter_valid = iter_nth_child(Gtk.GtkTreeModel(w),iter,parent,1)
    while iter_valid && (w[iter,5] == type_folder && w[iter,2] < basename(path))
        iter_valid = Gtk.get_iter_next(Gtk.GtkTreeModel(w), iter)
    end
    if iter_valid
        return iter
    else
        return nothing
    end
end
function where_insert_file(w::GtkTreeStore,p::AbstractString, parent)
  iter = Gtk.mutable(Gtk.GtkTreeIter)

  iter_valid = iter_nth_child(Gtk.GtkTreeModel(w),iter,parent,1)
  #Skip folders
  while iter_valid && w[iter,5] == type_folder
    iter_valid = Gtk.get_iter_next(Gtk.GtkTreeModel(w), iter)
  end
  while iter_valid &&  w[iter,2] < basename(p)
      iter_valid = Gtk.get_iter_next(Gtk.GtkTreeModel(w), iter)
  end
  if iter_valid
      return iter
  else
      return nothing
  end
end
function update!(w::GtkTreeStore, p::AbstractString, parent=nothing)
    if isdir(p)
        iter = where_insert_folder(w,p,parent)
        if iter!=nothing
            folder = insert_folder(w,p,iter)
        else
            folder = add_folder(w,p,parent)
        end
        populate_folder(w,folder)
    else
      iter = where_insert_file(w,p,parent)
      if iter!=nothing
          insert_file(w,dirname(p),basename(p),iter)
      else
          add_file(w,dirname(p),basename(p),parent)
      end
    end
end
function update!(w::FilesPanel)
    empty!(w.list)
    update!(w.list,pwd())
    expand_root(w.tree_view)
end
#### FILES PANEL
function get_selected_path(treeview::GtkTreeView,list::GtkTreeStore)
    v = selected(treeview, list)
    if v != nothing
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

function file_tab_index(filename)
    for i=1:length(editor)
        t = get_tab(editor,i)
        if typeof(t) == EditorTab && t.filename == filename #in case we want to have something else in the editor
            return i
        end
    end
    return -1
end
function open_file(treeview::GtkTreeView,list::GtkTreeStore)
    file = get_selected_file(treeview,list)
    file_idx = file_tab_index(file)
    if file != nothing && file_idx==-1
        open_in_new_tab(file)
    else
        set_current_page_idx(editor,file_idx)
    end
end
function nearest_folder_from_current_iterator(filespanel)
    if filespanel.list[filespanel.current_iterator,5] == type_file
        #Get parent folder
        iterator = copy_up(GtkTreeModel(filespanel.list),filespanel.current_iterator)
    else
        iterator = filespanel.current_iterator
    end
    return iterator
end
#=File path menu =#
 function path_dialog_create_file(filespanel)
    te_filename = GAccessor.object(form_builder,"filename")
    #TODO check overwrite
    iterator = nearest_folder_from_current_iterator(filespanel)
    filename = getproperty(te_filename, :text, AbstractString)
    touch(filename)
    update!(filespanel.list, filename, iterator)
    open_in_new_tab(filename)

    return nothing
end
function path_dialog_create_directory(filespanel)
    te_filename = GAccessor.object(form_builder,"filename")
    iterator = nearest_folder_from_current_iterator(filespanel)
    #TODO check overwrite
    filename = getproperty(te_filename, :text, AbstractString)
    mkdir(filename)

    update!(filespanel.list,filename,iterator)

    return nothing
end

function path_dialog_rename_file(filespanel)
    te_filename = GAccessor.object(form_builder,"filename")
    #TODO check overwrite

    current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
    filename = getproperty(te_filename, :text, AbstractString)
    mv(current_path,filename)

    update!(filespanel.list, filename,copy_up(GtkTreeModel(filespanel.list),filespanel.current_iterator))
    delete!(filespanel.list, filespanel.current_iterator)




    return nothing
end
function path_dialog_filename_inserted_text(text_entry_buffer_ptr::Ptr,
                                            cursor_pos,
                                            new_text::Cstring,
                                            n_chars,
                                            data)
    path              = data[1]
    delete_signal_id  = data[2]
    text_entry_buffer = convert(GtkEntryBuffer, text_entry_buffer_ptr)
    if (cursor_pos < length(path))
        Gtk.signal_handler_block(text_entry_buffer, delete_signal_id)
        delete_text(text_entry_buffer,cursor_pos,n_chars)
        Gtk.signal_handler_unblock(text_entry_buffer, delete_signal_id)
    end
    return nothing
end
function path_dialog_filename_deleted_text(text_entry_buffer_ptr::Ptr, cursor_pos,n_chars,data)
    path = data[1]
    insert_signal_id = data[2]
    text_entry_buffer = convert(GtkEntryBuffer, text_entry_buffer_ptr)
    if (cursor_pos < length(path))
        Gtk.signal_handler_block(text_entry_buffer, insert_signal_id)
        insert_text(text_entry_buffer,
                    cursor_pos,
                    path[cursor_pos+1:min(end,cursor_pos+n_chars+1)],
                    n_chars)
        Gtk.signal_handler_unblock(text_entry_buffer, insert_signal_id)
    end
    return nothing
end

function configure_text_entry_fixed_content(te, fixed, nonfixed="")
    setproperty!(te, :text,"");
    setproperty!(te, :text,string(fixed,nonfixed));
    te = buffer(te)
    id_signal_insert = Culong(0)
    id_signal_delete = Culong(0)
    id_signal_insert = signal_connect(path_dialog_filename_inserted_text,
        te,
        "inserted-text",
        Void,
        (Cuint,Cstring,Cuint),false,(fixed,id_signal_delete))
    id_signal_delete = signal_connect(path_dialog_filename_deleted_text,
        te,
        "deleted-text",
        Void,
        (Cuint,Cuint),false,(fixed,id_signal_insert))
    return (id_signal_insert, id_signal_delete)
end
function configure(dialog::FilePathDialog,
                   files_panel::FilesPanel,
                   path::AbstractString,
                   filename::AbstractString="")
    #Disconnect the Text Entry
    te_filename = GAccessor.object(form_builder,"filename")

    te = buffer(te_filename)
    if (dialog.signal_insert_id > 0)
        signal_handler_disconnect(te,dialog.signal_insert_id)
    end
    if (dialog.signal_delete_id > 0)
        signal_handler_disconnect(te,dialog.signal_delete_id)
    end

    if (!isdirpath(path))
	    path = joinpath(path,"")        
    end
    (dialog.signal_insert_id, dialog.signal_delete_id) = configure_text_entry_fixed_content(te_filename,path,filename)



end

function file_path_dialog_set_button_caption(w, caption::AbstractString)
    btn_create_file = GAccessor.object(form_builder,"btnCreateFile")
    setproperty!(btn_create_file,:label,caption)
end

function filespanel_treeview_row_expanded_cb(treeviewptr::Ptr,
                                             iterptr::Ptr{Gtk.TreeIter},
                                             path::Ptr{Gtk.TreePath},
                                             data)
    treeview        = convert(GtkTreeView,treeviewptr)
    iter            = unsafe_load(iterptr)
    tree_view_model = model(treeview)
    if (tree_view_model[iter,5]==type_folder) && (!tree_view_model[iter,4])
        child_iter =Gtk.mutable(GtkTreeIter)
        if Gtk.iter_nth_child(GtkTreeModel(tree_view_model),child_iter,iter,1)
            delete!(tree_view_model, child_iter[])
        end
        populate_folder(tree_view_model,iter)
    end
    return Cint(0)
end

function filespanel_treeview_clicked_cb(widgetptr::Ptr, eventptr::Ptr, filespanel)

    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = filespanel.list
    menu = filespanel.menu

    if event.button == 3
        (ret,current_path) = Gtk.path_at_pos(treeview,round(Int,event.x),round(Int,event.y));
        if ret
            (ret,filespanel.current_iterator) = Gtk.iter(
                                                      Gtk.GtkTreeModel(filespanel.list),
                                                      current_path)
            showall(menu)
            popup(menu,event)
        end
    else
        if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
            open_file(treeview,list)
        end
    end
    return PROPAGATE
end

function filespanel_treeview_keypress_cb(widgetptr::Ptr, eventptr::Ptr, filespanel)
    treeview = convert(GtkTreeView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    list = filespanel.list
    if event.keyval == Gtk.GdkKeySyms.Return
        open_file(treeview,list)
    end
    return PROPAGATE
end

function filespanel_newFileItem_activate_cb(widgetptr::Ptr,filespanel)

    if (filespanel.current_iterator != nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        if isfile(current_path)
            current_path = dirname(current_path)
        end
        configure(filespanel.path_dialog ,
                  filespanel,
                  current_path )


        file_path_dialog_set_button_caption(filespanel.path_dialog,"+")

        ret = run(filespanel.path_dialog.dialog)
        visible(filespanel.path_dialog.dialog,false)
        if ret == Gtk.GConstants.GtkResponseType.ACCEPT
            path_dialog_create_file(filespanel)
        end

    end
    return nothing
end

function filespanel_deleteItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        delete!(filespanel.list,filespanel.current_iterator)
        rm(current_path,recursive=true)
    end
    return nothing
end
 function filespanel_renameItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        base_path = dirname(current_path)
        resource  = basename(current_path)
        #TODO check overwrite
        configure(filespanel.path_dialog ,
                  filespanel,
                  base_path,
                  resource )

        file_path_dialog_set_button_caption(filespanel.path_dialog,"Rename it")
        ret = run(filespanel.path_dialog.dialog)
        visible(filespanel.path_dialog.dialog,false)
        if ret == Gtk.GConstants.GtkResponseType.ACCEPT
            path_dialog_rename_file(filespanel)
        end
    end
    return nothing
end
function filespanel_changeDirectoryItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        if isfile(current_path)
            current_path = dirname(current_path)
        end
        try
            cd(current_path)
            on_path_change()
        catch err
        end
    end
    return nothing
end
function filespanel_addToPathItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        if isfile(current_path)
            current_path = dirname(current_path)
        end
        push!(LOAD_PATH,current_path)
        try
            cd(current_path)
            on_path_change()
        catch err
        end
    end
    return nothing
end
function filespanel_newFolderItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        if isfile(current_path)
            current_path = dirname(current_path)
        end
        configure(filespanel.path_dialog ,
                  filespanel,
                  current_path )

        file_path_dialog_set_button_caption(filespanel.path_dialog,"+")
        ret = run(filespanel.path_dialog.dialog)
        visible(filespanel.path_dialog.dialog,false)
        if ret ==Gtk.GConstants.GtkResponseType.ACCEPT
            path_dialog_create_directory(filespanel)
        end

    end
    return nothing
end
function filespanel_copyItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        filespanel.paste_action = ("copy", filespanel.current_iterator)
    end
    return nothing
end
function filespanel_cutItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        filespanel.paste_action = ("cut", filespanel.current_iterator)
    end
    return nothing
end
@guarded nothing function filespanel_pasteItem_activate_cb(widgetptr::Ptr,filespanel)
    #TODO check overwrite
    if (filespanel.paste_action != nothing) && (filespanel.current_iterator!=nothing)
        orig_path    = filespanel.list[filespanel.paste_action[2],3]
        iterator     = nearest_folder_from_current_iterator(filespanel)
        current_path = filespanel.list[iterator,3]
        destination  = joinpath(current_path,basename(orig_path))

        if (filespanel.paste_action[1]=="copy")
            cp(orig_path,destination)
        else
            mv(orig_path,destination)
            delete!(filespanel.list, filespanel.paste_action[2])
        end
        update!(filespanel.list, destination,iterator)

    end
    return nothing
end
function filespanel_copyFullPathItem_activate_cb(widgetptr::Ptr,filespanel)
    if (filespanel.current_iterator!=nothing)
        current_path =  Gtk.getindex(filespanel.list,filespanel.current_iterator,3)
        try
            clipboard(current_path)
        catch e
            println(e)
        end
    end
    return nothing
end
