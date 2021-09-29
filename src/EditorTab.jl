"
    EditorTab <: GtkScrolledWindow

A single text file inside the `Editor`.
The main fields are the GtkSourceView (view) and the GtkSourceBuffer (buffer)."
mutable struct EditorTab <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    filename::String
    texthash::UInt64
    modified::Bool
    search_context::GtkSourceSearchContext
    search_mark_start
    search_mark_end
    scroll_target::Float64
    scroll_target_line::Int
    autocomplete_words::Array{String, 1}
    label::GtkLabel
    eval_in::Module

    function EditorTab(filename::String, main_window::MainWindow)

        languageDefinitions = main_window.style_and_language_manager.languageDefinitions
        lang = haskey(languageDefinitions, extension(filename)) ?
        languageDefinitions[extension(filename)] : languageDefinitions[".jl"]

        filename = isabspath(filename) ? filename : joinpath(pwd(), filename)#FIXME pwd should be called on worker
        filename = normpath(filename)

        b = GtkSourceBuffer(lang)

        set_gtk_property!(b, :style_scheme, main_window.style_and_language_manager.main_style)
        v = GtkSourceView(b)

        highlight_matching_brackets(b, true)

        show_line_numbers!(v, opt("Editor", "show_line_numbers"))
	    auto_indent!(v, true)
        highlight_current_line!(v, true)
        set_gtk_property!(v, :wrap_mode, opt("Editor", "wrap_mode"))
        set_gtk_property!(v, :tab_width, opt("Editor", "tab_width"))
        set_gtk_property!(v, :insert_spaces_instead_of_tabs, true)

        sc = GtkScrolledWindow()
        push!(sc, v)

        search_con = GtkSourceSearchContext(b, _editor(main_window).search_window.search_settings)
        highlight(search_con, true)

        t = new(sc.handle, v, b, filename, 0, false, search_con, nothing, nothing)
        t.eval_in = Main
        Gtk.gobject_move_ref(t, sc)
    end
    EditorTab(main_window::MainWindow) = EditorTab("", main_window)
end

function set_text!(t::EditorTab, text::String)
    set_gtk_property!(t.buffer, :text, text)
end
get_text(t::EditorTab) = get_gtk_property(t.buffer, :text, String)

include("CompletionWindow.jl")
include("SearchWindow.jl")

function check_texthash(t::EditorTab, editor)
    try
        f = Base.open(t.filename, "r")
        text = read(f, String)
        if hash(text) != t.texthash
            ok = ask_dialog("File has been modified by external program, save anyway?", editor.main_window)
            !ok && return false
        end
        close(f)
    catch err
        @warn "Error while saving $(t.filename)"
        @warn err
    end
    true
end

function save(t::EditorTab)

    editor = parent(t)

    if basename(t.filename) == ""
        save_as(t)
        return
    end
    !check_texthash(t, editor) && return
    try
        f = Base.open(t.filename, "w")
        text = get_text(t)
        write(f, text)
        close(f)
        t.texthash = hash(text)
        modified(t, false)
        if extension(t.filename) == ".jl"
            t.autocomplete_words = collect_symbols(t)
        end
    catch err
        @warn "Error while saving $(t.filename)"
        @warn err
    end
end

function save_as(t::EditorTab)
    extensions = (".jl", ".md")
    selection = Gtk.save_dialog("Save as file", Gtk.toplevel(t), map(x->string("*", x), extensions))
    isempty(selection) && return nothing
    #basename, ext = splitext(selection)
    t.filename = selection
    save(t)
end

function open_in_new_tab(filename::String, editor; line=0)#FIXME type this, but Editor not defined at this point
    t = add_tab(filename, editor)
    t.scroll_target_line = max(0, line-1)
    open(t, t.filename)
    return t
end
open_in_new_tab(filename::String; line=0) =
    open_in_new_tab(filename, main_window.editor;line=line)#need this for console command

function set_font(t::EditorTab, provider::GtkStyleProvider)
    sc = Gtk.G_.style_context(t.view)
    push!(sc, provider, 600)
end

function istextfile(t::EditorTab)
    fext = extension(t.filename)
    for ext in [".md", ".txt"]
        fext == ext && return true
    end
    false
end

function get_cell(buffer::GtkTextBuffer)

    (foundb, itb_start, itb_end) = search(buffer, "##", :backward)
    (foundf, itf_start, itf_end) = search(buffer, "##", :forward)

    if foundf && !foundb
        return(true, mutable(GtkTextIter(buffer, 1)), itf_end) #start of file
    end

    return((foundf && foundb), itb_start, itf_end)
end

function highlight_cells()

    Gtk.apply_tag(
        srcbuffer, "background", 
        GtkTextIter(srcbuffer, 1), GtkTextIter(srcbuffer, length(srcbuffer)+1) 
    )
    (found, it_start, it_end) = get_cell(srcbuffer)

    if found
        Gtk.apply_tag(srcbuffer, "cell", it_start , it_end )
    end
end

hasselection(t::EditorTab) = hasselection(t.buffer)

function selected_text(t::EditorTab)
    (found, it_start, it_end) = selection_bounds(t.buffer)
    return found ? (it_start:it_end).text[String] : ""
end


"""
    Opens file at line or switch to it if already opened.
"""
function open_tab(file, editor; line=0)

    file = normpath(file)
    if ispath(file)
        #first look in existing tabs if the file is already open
        for i = 1:length(editor)
            n = editor[i]
            if typeof(n) == EditorTab && n.filename == file

                index(editor, i)
                if line != 0
                    it = GtkTextIter(n.buffer, line, 1)
                    scroll_to(n.view, it, 0, true, 0.0, 0.15)#FIXME use mark instead ? use Gtk's scroll_to
                    place_cursor(n.buffer, it)
                end
                grab_focus(n.view)
                return true
            end
        end
        #otherwise open it
        t = open_in_new_tab(file, editor, line=line)
    else
        #create new file
        t = open_in_new_tab(file, editor, line=line)
    end
    return true
end

function open_method(view::GtkTextView, editor)#FIXME type this, but Editor not defined at this point

    word = get_word_under_mouse_cursor(view)

    try
        ex = Meta.parse(word)

        v = Core.eval(Main, ex)
        v = typeof(v) <: Function ? methods(v) : v

        file, line = method_filename(v)
        file = string(file)
        file = ispath(file) ? file : joinpath( joinpath(splitdir(Sys.BINDIR)[1], "share/julia/base"), file)

        open_tab(file, editor; line=line)
    catch err
        @warn err
    end
    return false
end

function line_to_adj_value(buffer::GtkTextBuffer, adj::GtkAdjustment, l::Integer)
    tot = line_count(buffer)
    scaling = get_gtk_property(adj, :upper, AbstractFloat) #-
              #get_gtk_property(adj, :page_size, AbstractFloat)

    return l/tot * scaling
end

#clicks

function select_word_double_click(textview::GtkTextView, buffer::GtkTextBuffer, x::Integer, y::Integer)

    x, y  = Gtk.window_to_buffer_coords(textview, x, y)
    iter_end = Gtk.text_iter_at_position(textview, x, y)
    #iter_end = mutable( get_text_iter_at_cursor(buffer) ) #not using this because the cursor position is modified somewhere

    w, iter_start, iter_end = select_word(iter_end, buffer)
    select_range(buffer, iter_start, iter_end)
end

@guarded (INTERRUPT) function tab_button_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = get_gtk_property(textview, :buffer, GtkTextBuffer)
    editor = user_data

    if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        select_word_double_click(textview, buffer, round(Integer, event.x), round(Integer, event.y))
        return INTERRUPT
    end

    mod = get_default_mod_mask()

    if Int(event.button) == 1 && event.state & mod == PrimaryModifier
        open_method(textview, editor) && return INTERRUPT
    end

    return PROPAGATE
end

function replace_text(buffer::GtkTextBuffer, itstart::T, itend::T, str::String) where {T <: Gtk.TI}
    pos = offset(itstart)+1
    splice!(buffer, itstart:itend)
    insert!(buffer, GtkTextIter(buffer, pos), str)
end

# returns the position of the cursor inside a buffer such that we can position a window there
function get_cursor_absolute_position(view::GtkTextView)

    it, r1, r2 = Gtk.cursor_locations(view)
    x, y = Gtk.buffer_to_window_coords(view, r1.x, r1.y, 1)

    w = Gtk.GAccessor.window(view)
    ox, oy = Gtk.get_origin(w)

    return (x+ox, y+oy+r1.height, r1.height)
end

function run_line(console::Console, t::EditorTab)

    cmd = selected_text(t)
    if cmd == ""
        (cmd, itstart, itend) = get_current_line_text(t.buffer)
        cmd = strip(cmd)
    end
    run_command(console, cmd)
end

function run_command(c::Console, cmd)
    GtkREPL.command(c, cmd)
    GtkREPL.on_return(c, cmd)
end

@guarded (PROPAGATE) function editor_key_release_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    @warn "loading data"
    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = textview.buffer[GtkTextBuffer]
    editor = user_data
    
    @warn "updating completion window"
    !update_completion_window_release(event, buffer, editor) && return convert(Cint, true)
    @warn "done"

    return PROPAGATE
end
##

@guarded (INTERRUPT) function editor_tab_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = textview.buffer[GtkTextBuffer]
    t = user_data
    editor = parent(t)::Editor
    console = current_console(editor)
    
    doing(Actions["save"], event) && save(t)
    doing(Actions["open"], event) && openfile_dialog()

    if doing(Actions["closetab"], event)
        close_tab(editor)
        save(project)
    end
    if doing(Actions["newtab"], event)
        add_tab(editor)
        save(project)
    end
    if doing(Actions["datahint"], event)
        show_data_hint(textview, t)
    end
    if doing(Actions["search"], event)
        open(editor.search_window, t)
    end
    if event.keyval == GdkKeySyms.Tab
        if !visible(completion_window)
            return init_autocomplete(textview, t; key=:tab)
        end
    end
    if event.keyval == GdkKeySyms.F3
        if !visible(completion_window)
            return init_autocomplete(textview, t; key=:ctrl_tab)
        end
    end
    if doing(Actions["runline"], event) || doing(Actions["runline_kp"], event)
        run_line(console, t)
        return convert(Cint, true)
    end
    if doing(Actions["runcode"], event) || doing(Actions["runcode_kp"], event)
        run_code(console, t)
        return INTERRUPT
    end
    if doing(Actions["runfile"], event)
        cmd = "include(\"$(t.filename)\")"
        cmd = replace(cmd, "\\" => "/")
        run_command(console, cmd)
    end
    if event.keyval == GdkKeySyms.Escape
        set_search_text(editor.search_window.search_settings, "")
        visible(editor.search_window, false)
    end
    if doing(Actions["copy"], event)
        (found, it_start, it_end) = selection_bounds(buffer)
        if !found
            (txt, its, ite) = get_line_text(buffer, get_text_iter_at_cursor(buffer))
            select_range(buffer, its, ite)
        end
        signal_emit(textview, "copy-clipboard", Nothing)
        return INTERRUPT
    end
    if doing(Actions["paste"], event)
        signal_emit(textview, "paste-clipboard", Nothing)
        return INTERRUPT
    end
    if doing(Actions["cut"], event)
        (found, it_start, it_end) = selection_bounds(buffer)
        if !found
            (txt, its, ite) = get_line_text(buffer, get_text_iter_at_cursor(buffer))
            select_range(buffer, its, ite)
        end
        signal_emit(textview, "cut-clipboard", Nothing)

        return INTERRUPT
    end
    if doing(Actions["move_to_line_start"], event) ||
       doing(Action(GdkKeySyms.Left, PrimaryModifier), event)
        move_cursor_to_sentence_start(buffer)
        return INTERRUPT
    end
    if doing(Actions["move_to_line_end"], event) ||
       doing(Action(GdkKeySyms.Right, PrimaryModifier), event)
        move_cursor_to_sentence_end(buffer)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Right, PrimaryModifier+GdkModifierType.SHIFT), event)
        select_on_ctrl_shift(:end, buffer)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Left, PrimaryModifier+GdkModifierType.SHIFT), event)
        select_on_ctrl_shift(:start, buffer)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Down, PrimaryModifier), event)
        move_cursor_to_next_cell(buffer, textview, :down)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Up, PrimaryModifier), event)
        move_cursor_to_next_cell(buffer, textview, :up)
        return INTERRUPT
    end
    if doing(Actions["toggle_comment"], event)
        user_action(toggle_comment, buffer)#make sure undo works
    end
    if doing(Actions["undo"], event)
        canundo(buffer) && undo!(buffer)
        return INTERRUPT
    end
    if doing(Actions["redo"], event)
        canredo(buffer) && redo!(buffer)
        return INTERRUPT
    end
    if doing(Actions["delete_line"], event)
        (found, itstart, itend) = selection_bounds(buffer)
        if found
            itstart = text_iter_line_start(nonmutable(buffer, itstart))#FIXME need a mutable version
            !get_gtk_property(itend, :ends_line, Bool) && skip(itend, :forward_to_line_end)
            splice!(buffer, itstart-1:itend)
        else
            (cmd, itstart, itend) = get_current_line_text(buffer)
            splice!(buffer, itstart-1:itend)
        end
    end
    if doing(Actions["duplicate_line"], event)
        (cmd, itstart, itend) = get_current_line_text(buffer)
        insert!(buffer, itend, "\n" * cmd)
    end
    if doing(Actions["goto_line"], event)
        ok, v = input_dialog("Line number", "1", (("Cancel", 0), ("Ok", 1)), editor.main_window)
        if ok == 1
            v = Meta.parse(v)
            if typeof(v) <: Integer
                scroll_to_line(t, v)
            else
                println("Invalid line number: $v")
            end
        end
    end
    if doing(Actions["extract_method"], event)
        return user_action(editor_extract_method, buffer)
    end
    !update_completion_window(event, buffer, t) && return INTERRUPT

    return PROPAGATE
end

##

function editor_extract_method(buffer::GtkTextBuffer)
    (found, itstart, itend) = selection_bounds(buffer)
    body = found ? (itstart:itend).text[String] : ""
    body == "" && return PROPAGATE
    
    insert_offset = offset(itstart)

    tabw = opt("Editor", "tab_width")
    tab = " "^tabw
    met = Refactoring.extract_method(body, tab)

    replace_text(buffer, itstart, itend, met)
    it = GtkTextIter(buffer, insert_offset + sizeof("function ")+2) #FIXME probable offset issue 
    place_cursor(buffer, it)
    
    return INTERRUPT 
end


function toggle_comment(buffer::GtkTextBuffer)

    (found, it_start, it_end) = selection_bounds(buffer)
    if found
        for i in line(it_start):line(it_end)
            toggle_comment(buffer, GtkTextIter(buffer, i, 1))
        end
    else
        it = get_text_iter_at_cursor(buffer)
        toggle_comment(buffer, it)
    end
end
function toggle_comment(buffer::GtkTextBuffer, it::GtkTextIter)

    it = text_iter_line_start(it)#start of the text
    it_ls = GtkTextIter(buffer, line(it), 1)#start of the line

    if get_text_right_of_iter(it_ls) == "#"
        splice!(buffer, it_ls:it_ls+1)
    else
        if get_text_right_of_iter(it) == "#"
            splice!(buffer, it:it+1)
        else
            insert!(buffer, it_ls, "#")
        end
    end
end

function run_code(console::Console, t::EditorTab)
    cmd = selected_text(t)
    if cmd == ""
        (found, it_start, it_end) = get_cell(t.buffer)
        if found
            cmd = (it_start:it_end).text[String]
        else
            cmd = get_gtk_property(t.buffer, :text, String)
        end
    end
    run_command(console, cmd)
end

function get_word_under_mouse_cursor(textview::GtkTextView)
    x, y = Gtk.window_to_buffer_coords(textview, mousepos[1], mousepos[2])
    iter_end = Gtk.text_iter_at_position(textview, x, y)
    buffer = textview.buffer[GtkTextBuffer]
    word, itstart, itend = select_word(iter_end, buffer, false)
    return word
end

function show_data_hint(textview::GtkTextView, t::EditorTab)

    word = get_word_under_mouse_cursor(textview)

    try
        if extension(t.filename) == ".md"

        else
            ex = Meta.parse(word)
            isnothing(ex) && return

            c = current_console(parent(t))
            
            v = remotecall_fetch(GtkREPL.eval_symbol, worker(c), ex, c.eval_in)
            v = GtkREPL.RemoteGtkREPL.format_output(v)
                        
            doc = remotecall_fetch(GtkREPL.RemoteGtkREPL.get_doc, worker(c), ex, c.eval_in)
             
            v = string(v, "\n\n")
            doc = string("\n", doc)
        end
        
        # sp = parent(t).main_window.style_and_language_manager.main_style
        # style = GtkSourceWidget.style(sp, "text")

        style_mng = parent(t).main_window.style_and_language_manager
        style = get_style(style_mng, "text")
        
        mc = MarkdownColors(
            style_mng.fontsize,
            Gtk.get_gtk_property(style, :foreground, String),
            Gtk.get_gtk_property(style, :background, String),
            Gtk.get_gtk_property(get_style(style_mng, "def:note"), :foreground, String),
            Gtk.get_gtk_property(style, :background, String),
        )

        view = MarkdownTextView(doc, v, mc)
        
        popup = GtkWindow("", 800, 400, true, true) |> GtkScrolledWindow(view)
        set_gtk_property!(view, :margin, 3)
        signal_connect(data_hint_window_key_press_cb, popup, "key-press-event", Cint, (Ptr{Gtk.GdkEvent}, ), false)
        signal_connect(data_hint_window_focus_out_cb, popup, "focus-out-event", Cint, (Ptr{Gtk.GdkEvent}, ), false)

        Gtk.G_.position(popup, mousepos_root[1]+10, mousepos_root[2])
        showall(popup)

    catch err
        @warn err
    end
end

@guarded (INTERRUPT) function data_hint_window_focus_out_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    w = convert(GtkWindow, widgetptr)
    destroy(w)
    return INTERRUPT
end

#    if doing(Actions["copy"], event)
#        signal_emit(textview, "copy-clipboard", Nothing)
#        return INTERRUPT
#    end

@guarded (INTERRUPT) function data_hint_window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    w = convert(GtkWindow, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    
    if doing(Action(GdkKeySyms.Escape, NoModifier), event)
        destroy(w)
    end
    return PROPAGATE
end

value(adj::GtkAdjustment) = get_gtk_property(adj, :value, AbstractFloat)
value(adj::GtkAdjustment, v::AbstractFloat) = set_gtk_property!(adj, :value, v)

# maybe I should replace this by a task that check for the
# end of loading and then call a function
function tab_adj_changed_cb(adjptr::Ptr, user_data)

    #FIXME need to check if the scroll target is valid somehow
    adj = convert(GtkAdjustment, adjptr)
    t = user_data
    if t.scroll_target != 0 && t.scroll_target_line == 0
        if value(adj) != t.scroll_target
            value(adj, t.scroll_target)
        else
            t.scroll_target = 0
        end
    end

    if t.scroll_target_line != 0
        v = line_to_adj_value(get_buffer(t.view), adj, t.scroll_target_line)
        if value(adj) != v
            value(adj, v)
        else
            t.scroll_target_line = 0
        end
    end

    return nothing
end

function scroll_to_line(t::EditorTab, l::Integer)

    adj = get_gtk_property(t, :vadjustment, GtkAdjustment)
    v = line_to_adj_value(get_buffer(t.view), adj, l)
    v = max(0, v - get_gtk_property(adj, :step_increment, AbstractFloat))
    value(adj, v)
end

function modified(t::EditorTab, v::Bool)
    t.modified = v
    f = basename(t.filename)
    f = f == "" ? "Untitled" : f

    s = v ? f * "*" : f

    set_gtk_property!(t.label, :label, s)
end

function tab_buffer_changed_cb(widgetptr::Ptr, user_data)
    t = user_data
    modified(t, true)

    return nothing
end


@guarded (PROPAGATE) function input_dialog_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    dialog = convert(GtkMessageDialog, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if doing(Action(GdkKeySyms.Return, NoModifier), event)
        response(dialog, 1)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Escape, NoModifier), event)
        response(dialog, 0)
        return INTERRUPT
    end

    return PROPAGATE
end

#FIXME put this into Gtk.jl ?
import Gtk.input_dialog
function input_dialog(message::String, entry_default::String, buttons = (("Cancel", 0), ("Accept", 1)), parent = GtkNullContainer())
    widget = GtkMessageDialog(message, buttons, Gtk.GtkDialogFlags.DESTROY_WITH_PARENT, Gtk.GtkMessageType.INFO, parent)
    
    box = Gtk.content_area(widget)
    entry = GtkEntry(; text = entry_default)
    push!(box, entry)
    
    signal_connect(input_dialog_key_press_cb, widget, "key-press-event",
    Cint, (Ptr{Gtk.GdkEvent}, ), false)
    
    showall(widget)
    resp = run(widget)
    entry_text = get_gtk_property(entry, :text, String)
    destroy(widget)
    return resp, entry_text
end

@guarded (nothing) function move_cursor_to_next_cell(buffer, textview, direction = :down)
    
    (found, it_start, it_end) = search(buffer, "##", direction == :down ? :forward : :backward)
    !found && return
    
    # if we are just bellow a cell going up, skip the ##
    it = get_text_iter_at_cursor(buffer)
    if (direction == :up) && (it.line[Int]-1 == it_start.line[Int])
        place_cursor(buffer, it_start)
        (found, it_start, it_end) = search(buffer, "##", :backward)
        !found && return
    end

    skip(it_start, 1, :lines)#make sure the cursor is in the cell
    place_cursor(buffer, it_start)
    mark = create_mark(buffer, it_start)
    scroll_to(textview, mark, 0, true, 0.0, 0.15)
    nothing
end