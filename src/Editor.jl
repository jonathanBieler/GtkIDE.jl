include("EditorUtils.jl")
include("Actions.jl")
include("EditorTab.jl")

"     Editor <: GtkNotebook
"
type Editor <: GtkNotebook

    handle::Ptr{Gtk.GObject}
    sourcemap::Gtk.GtkWidget

    function Editor()
        ntbook = @GtkNotebook()
        setproperty!(ntbook,:scrollable, true)
        setproperty!(ntbook,:enable_popup, false)

        if GtkSourceWidget.SOURCE_MAP #old linux libraries don't have GtkSourceMap
            sourcemap = @GtkSourceMap()
            t = new(ntbook.handle,sourcemap)
        else
            sourcemap = @GtkBox(:v)#put a dummy box instead
            t = new(ntbook.handle,sourcemap)
        end
        Gtk.gobject_move_ref(t, ntbook)
    end
end

if !GtkSourceWidget.SOURCE_MAP
    set_view() = nothing
end

get_current_tab() = get_tab(editor,index(editor))# remove this ?

function ntbook_switch_page_cb(widgetptr::Ptr, pageptr::Ptr, pagenum::Int32, user_data)

    page = convert(Gtk.GtkWidget, pageptr)
    if typeof(page) == EditorTab && GtkSourceWidget.SOURCE_MAP
        set_view(editor.sourcemap, page.view)
        visible(editor.sourcemap,opt("Editor","show_source_map"))
    end
    nothing
end

global mousepos = zeros(Int,2)
global mousepos_root = zeros(Int,2)

#I need this to get the mouse position when we use the keyboard
function ntbook_motion_notify_event_cb(widget::Ptr,  eventptr::Ptr, user_data)
    event = convert(Gtk.GdkEvent, eventptr)

    mousepos[1] = round(Int,event.x)
    mousepos[2] = round(Int,event.y)
    mousepos_root[1] = round(Int,event.x_root)
    mousepos_root[2] = round(Int,event.y_root)
    return PROPAGATE
end

#this could be in the constructor but it doesn't work for some reason
function init(editor::Editor)
    signal_connect(ntbook_switch_page_cb,editor,"switch-page", Void, (Ptr{Gtk.GtkWidget},Int32), false)
    signal_connect(ntbook_motion_notify_event_cb,editor,"motion-notify-event",Cint, (Ptr{Gtk.GdkEvent},), false)
end

function set_dir_to_file_path_cb(btn::Ptr,tab)
    cd(dirname(tab.filename))
    on_path_change()
    return nothing
end

function close_tab(idx::Int)
    if editor[idx].modified
        ok = ask_dialog("Unsaved changed, close anyway?",win)
        !ok && return
    end
    splice!(editor,idx)
    index(editor,max(idx-1,0))
end
close_tab() = close_tab(index(editor))

function close_tab_cb(btn::Ptr, tab)
    close_tab(Gtk.pagenumber(editor,tab)+1)
    return nothing
end

function close_other_tabs_cb(btn::Ptr,tab)
    while Gtk.GAccessor.n_pages(editor) > 1
        if get_tab(editor,1) == tab
            splice!(editor,2)
        else
            splice!(editor,1)
        end
    end
    return nothing
end
function close_tabs_right_cb(btn::Ptr,tab)
    idx = Gtk.pagenumber(editor,tab) +1
    while (Gtk.GAccessor.n_pages(editor) > idx)
        close_tab(idx+1)
    end
    return nothing
end
function close_all_tabs_cb(btn::Ptr,tab)
    while (Gtk.GAccessor.n_pages(editor) > 0)
        close_tab(1)
    end
    return nothing
end

function find_filename(model_ptr, path_ptr, iter_ptr, data_ptr)
    model = convert(Gtk.GtkTreeStoreLeaf,model_ptr)
    iter  = unsafe_load(iter_ptr)
    path  = Gtk.GtkTreePath(path_ptr)
    data  = unsafe_pointer_to_objref(data_ptr)
    if model[iter,3] == data[1]
        data[2][1] = true
        data[2][2] = path
        return Cint(1)
    else
        return Cint(0)
    end
end

@guarded nothing function reveal_in_tree_view(btn::Ptr, tab)
    data = [false,nothing]
    foreach(GtkTreeModel(filespanel.list),find_filename,(tab.filename,data))
    if data[1]
        set_cursor_on_cell(filespanel.tree_view, data[2])
    end
    return nothing
end
function switch_tab_cb(btn::Ptr, idx)
    index(editor,idx)
    return nothing
end
function create_tab_menu(container, tab)

#    menu =  @GtkMenu() |>
#    (closeTabItem = @GtkMenuItem("Close Tab")) |>
#    (closeOthersTabsItem = @GtkMenuItem("Close Others Tabs")) |>
#    (closeTabsRight = @GtkMenuItem("Close Tabs to the Right ")) |>
#    (closeAllTabs = @GtkMenuItem("Close All Tabs")) |>
#    @GtkSeparatorMenuItem() |>
#    (revealInTreeItem = @GtkMenuItem("Reveal in Tree View")) |>
#    (@GtkSeparatorMenuItem())


#
#    signal_connect(close_tab_cb, closeTabItem, "activate", Void,(),false,tab)
#    signal_connect(close_other_tabs_cb, closeOthersTabsItem, "activate", Void,(),false,tab)
#    signal_connect(close_tabs_right_cb, closeTabsRight, "activate", Void,(),false,tab)
#    signal_connect(close_all_tabs_cb, closeAllTabs, "activate", Void,(),false,tab)
#    signal_connect(reveal_in_tree_view, revealInTreeItem, "activate", Void,(),false,tab)

    menu = buildmenu([
            MenuItem("Close Tab",close_tab_cb),
            MenuItem("Close Others Tabs",close_other_tabs_cb),
            MenuItem("Close Tabs to the Right",close_tabs_right_cb),
            MenuItem("Close All Tabs",close_all_tabs_cb),
            GtkSeparatorMenuItem,
            MenuItem("Reveal in Tree View",reveal_in_tree_view),
            MenuItem("Set Directory to File Path",set_dir_to_file_path_cb),
            GtkSeparatorMenuItem
            ],
            tab
        )

    #show all open tabs
    for i=1:length(editor)
        if typeof(editor[i]) == EditorTab
            s = @GtkMenuItem(basename(editor[i].filename))
            push!(menu,s)
            signal_connect(switch_tab_cb, s, "activate", Void,(),false,i)
        end
    end

    showall(menu)
    return menu
end

@guarded (PROPAGATE) function tab_button_press_event_cb(event_box_ptr::Ptr,eventptr::Ptr, tab)
    event_box = convert(GtkEventBox, event_box_ptr)
    event     = convert(Gtk.GdkEvent,eventptr)

    if rightclick(event)
        popup(create_tab_menu(event_box, tab),event)
        return INTERRUPT
    else
        return PROPAGATE
    end
    return PROPAGATE
end

function get_tab_widget(tab, filename)

    layout = @GtkBox(:h)
    event_box = @GtkEventBox()
    push!(event_box,layout)
    signal_connect(tab_button_press_event_cb, event_box, "button-press-event",Cint, (Ptr{Gtk.GdkEvent},), false,tab)
    lbl = @GtkLabel(basename(filename))
    setproperty!(lbl,:name, "filename_label")
    btn = @GtkButton("X")
    signal_connect(close_tab_cb, btn, "clicked", Void,(),false,tab)

    push!(layout,lbl)
    push!(layout,btn)
    showall(event_box)
    return (event_box, lbl)
end

import Base.open
function open(t::EditorTab, filename::AbstractString)
    try
        if isfile(filename)
            f = Base.open(filename)
            set_text!(t,readall(f))
            t.modified = false
            modified(t,t.modified)
        else
            f = Base.open(filename,"w")
            t.modified = true
        end
        t.filename = filename
        reset_undomanager(t.buffer)#otherwise we can undo loading the file...
        close(f)
    catch err
        @show err
    end
    update!(project)
end

function add_tab(filename::AbstractString)

    t = EditorTab(filename);
    t.scroll_target = 0.
    t.scroll_target_line = 0

    idx = index(editor)+1
    (event_box,t.label) = get_tab_widget(t, filename)
    insert!(editor, idx, t, event_box)
    showall(editor)
    index(editor,idx)

    Gtk.create_tag(t.buffer, "debug1", font="Normal $fontsize",background="green")
    Gtk.create_tag(t.buffer, "debug2", font="Normal $fontsize",background="blue")
    set_font(t)

    #we need to use the view here to capture all the keystrokes
    signal_connect(tab_key_press_cb,t.view, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false,t)
    signal_connect(tab_key_release_cb,t.view, "key-release-event", Cint, (Ptr{Gtk.GdkEvent},), false)
    signal_connect(tab_button_press_cb,t.view, "button-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
    signal_connect(tab_buffer_changed_cb,t.buffer,"changed", Void, (), false,t)

#    signal_connect(tab_extend_selection_cb,t.view, "extend-selection", Cint,
#    (Ptr{Void},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}), false)

    signal_connect(tab_adj_changed_cb, getproperty(t.view,:vadjustment,GtkAdjustment) , "changed", Void, (), false,t)

    return t
end
add_tab() = add_tab("Untitled.jl")

function openfile_dialog()
    f = open_dialog("Pick a file", win, ("*.jl","*.md"))
    if isfile(f)
        open_in_new_tab(f)
    end
end

function load_tabs(project::Project)

    #project get modified later
    files = project.files
    scroll_position = project.scroll_position
    ntbook_idx = project.ntbook_idx

    for i = 1:length(files)
        t = open_in_new_tab(files[i])
        t.scroll_target = scroll_position[i]
    end

    if length(editor)==0
        open_in_new_tab(joinpath(Pkg.dir(),"GtkIDE","README.md"))
    elseif ntbook_idx <= length(editor)
        index(editor,ntbook_idx)
    end
    t = get_current_tab()
    GtkSourceWidget.SOURCE_MAP && set_view(editor.sourcemap,t.view)
end
