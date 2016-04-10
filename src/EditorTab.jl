"
    EditorTab <: GtkScrolledWindow

A single text file inside the `Editor`.
The main fields are the GtkSourceView (view) and the GtkSourceBuffer (buffer)."
type EditorTab <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    filename::AbstractString
    modified::Bool
    search_context::GtkSourceSearchContext
    search_mark_start
    search_mark_end
    scroll_target::AbstractFloat
    scroll_target_line::Integer
    autocomplete_words::Array{AbstractString,1}
    label::GtkLabel

    function EditorTab(filename::AbstractString)

        lang = haskey(languageDefinitions,extension(filename)) ?
        languageDefinitions[extension(filename)] : languageDefinitions[".jl"]

        filename = isabspath(filename) ? filename : joinpath(pwd(),filename)
        filename = normpath(filename)

        b = @GtkSourceBuffer(lang)
        setproperty!(b,:style_scheme,style)
        v = @GtkSourceView(b)

        highlight_matching_brackets(b,true)

        show_line_numbers!(v,true)
	    auto_indent!(v,true)
        highlight_current_line!(v, true)
        setproperty!(v,:wrap_mode,0)

        setproperty!(v,:tab_width,4)
        setproperty!(v,:insert_spaces_instead_of_tabs,true)

        sc = @GtkScrolledWindow()
        push!(sc,v)

        search_con = @GtkSourceSearchContext(b,search_settings)
        highlight(search_con,true)

        t = new(sc.handle,v,b,filename,false,search_con,nothing,nothing)
        Gtk.gobject_move_ref(t, sc)
    end
    EditorTab() = EditorTab("")
end

function set_text!(t::EditorTab,text::AbstractString)
    setproperty!(t.buffer,:text,text)
end
get_text(t::EditorTab) = getproperty(t.buffer,:text,AbstractString)
getbuffer(textview::GtkTextView) = getproperty(textview,:buffer,GtkSourceBuffer)

include("CompletionWindow.jl")
include("SearchWindow.jl")

function save(t::EditorTab)

    if basename(t.filename) == ""
        save_as(t)
        return
    end
    try
        f = Base.open(t.filename,"w")
        write(f,get_text(t))
        #println("saved $(t.filename)")
        close(f)
        modified(t,false)
        if extension(t.filename) == ".jl"
            t.autocomplete_words = collect_symbols(t)
        end
    catch err
        warn("Error while saving $(t.filename)")
        warn(err)
    end
end

function save_as(t::EditorTab)
    extensions = (".jl", ".md")
    selection = Gtk.save_dialog("Save as file", Gtk.toplevel(t), map(x->string("*",x), extensions))
    isempty(selection) && return nothing
    #basename, ext = splitext(selection)
    t.filename = selection
    save(t)
end

save_current_tab() = save(get_current_tab())

function open_in_new_tab(filename::AbstractString)
    t = add_tab(filename)
    open(t,t.filename)
    return t
end

function set_font(t::EditorTab)
    sc = Gtk.G_.style_context(t.view)
    push!(sc, provider, 600)
end

function get_cell(buffer::GtkTextBuffer)

    (foundb,itb_start,itb_end) = text_iter_backward_search(buffer, "##")
    (foundf,itf_start,itf_end) = text_iter_forward_search(buffer, "##")

    if foundf && !foundb
        return(true, mutable(GtkTextIter(buffer,1)), itf_end) #start of file
    end

    return((foundf && foundb), itb_start, itf_end)
end

function highlight_cells()

    Gtk.apply_tag(srcbuffer, "background", GtkTextIter(srcbuffer,1) , GtkTextIter(srcbuffer,length(srcbuffer)+1) )
    (found,it_start,it_end) = get_cell(srcbuffer)

    if found
        Gtk.apply_tag(srcbuffer, "cell", it_start , it_end )
    end
end

import Gtk.hasselection
function hasselection(b::GtkTextBuffer)
    (found,it_start,it_end) = selection_bounds(b)
    found
end
hasselection(t::EditorTab) = hasselection(t.buffer)

function selected_text(t::EditorTab)
    (found,it_start,it_end) = selection_bounds(t.buffer)
    return found ? text_iter_get_text(it_start,it_end) : ""
end
selected_text() = selected_text(get_current_tab())

function open_method(view::GtkTextView)

    word = get_word_under_mouse_cursor(view)

    try
        ex = parse(word)

        v = eval(Main,ex)
        v = typeof(v) == Function ? methods(v) : v

        tv, decls, file, line = Base.arg_decl_parts(v.defs)
        file = string(file)
        file = ispath(file) ? file : joinpath( joinpath(splitdir(JULIA_HOME)[1],"share/julia/base"), file)
        file = normpath(file)
        if ispath(file)
            #first look in existing tabs if the file is already open
            for i = 1:length(editor)
                n = editor[i]
                if typeof(n) == EditorTab && n.filename == file

                    set_current_page_idx(editor,i)
                    it = GtkTextIter(n.buffer,line,1)
                    scroll_to_iter(n.view, it)
                    text_buffer_place_cursor(n.buffer,it)
                    grab_focus(n.view)

                    return true
                end
            end
#            otherwise open it
            t = open_in_new_tab(file)
            t.scroll_target_line = line

            return true
        end
    catch

    end
    return false
end

function line_to_adj_value(buffer::GtkTextBuffer,adj::GtkAdjustment,l::Integer)
    tot = line_count(buffer)
    scaling = getproperty(adj,:upper,AbstractFloat) -
              getproperty(adj,:page_size,AbstractFloat)

    return l/tot * scaling
end

#clicks

function select_word_double_click(textview::GtkTextView,buffer::GtkTextBuffer,x::Integer,y::Integer)

    (x,y) = text_view_window_to_buffer_coords(textview,x,y)
    iter_end = get_iter_at_position(textview,x,y)
    #iter_end = mutable( get_text_iter_at_cursor(buffer) ) #not using this because the cursor position is modified somewhere

    (w, iter_start, iter_end) = select_word(iter_end,buffer)
    selection_bounds(buffer,iter_start,iter_end)
end

@guarded (INTERRUPT) function tab_button_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = getproperty(textview,:buffer,GtkTextBuffer)

    if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        select_word_double_click(textview,buffer,round(Integer,event.x),round(Integer,event.y))
        return INTERRUPT
    end

    mod = get_default_mod_mask()

    if Int(event.button) == 1 && event.state & mod == PrimaryModifier
        open_method(textview) && return INTERRUPT
    end

    return PROPAGATE
end

#FIXME: this should be reworked a bit with CompletionWindow code
function editor_autocomplete(view::GtkTextView,t::EditorTab,replace=true)

    buffer = getbuffer(view)
    it = get_text_iter_at_cursor(buffer)

    (cmd,itstart,itend) = select_word_backward(it,buffer,false)
    cmd = strip(cmd)

    if cmd == ""
        if get_text_left_of_cursor(buffer) == ")"
            return tuple_autocomplete(it,buffer,completion_window,view)
        else
            visible(completion_window,false)
            return PROPAGATE #we go back to normal behavior if there's nothing to do
        end
    end

    if !isdefined(t,:autocomplete_words)
        t.autocomplete_words = [""]
    end

    (comp,dotpos) = extcompletions(cmd,t.autocomplete_words)

    if isempty(comp)
        visible(completion_window,false)
        return PROPAGATE
    end

    dotpos_ = dotpos
    dotpos = dotpos.start
    prefix = dotpos > 1 ? cmd[1:dotpos-1] : "" #FIXME: redundant with the console code
    out = ""
    if(length(comp)>1)
        out = prefix * Base.LineEdit.common_prefix(comp)
        build_completion_window(comp,view,prefix)
    else
        out = prefix * comp[1]
        visible(completion_window) && build_completion_window(comp,view,prefix)
    end

    #don't insert prefix when completing a method
    replace = (cmd[end] == '(' && length(comp)>1) ? false : replace
    replace && insert_autocomplete(out,itstart,itend,buffer)

    return convert(Cint, true)
end

function tuple_autocomplete(it::GtkTextIter, buffer::GtkTextBuffer, completion_window::CompletionWindow, view::GtkTextView)

    (found,tu,itstart) = select_tuple(it, buffer)
    !found && return PROPAGATE

    args = tuple_to_types(tu)
    isempty(args) && return PROPAGATE

    m = methods_with_tuple(args)
    comp = map(string,m)
    func_names = [string(x.func.code.name) for x in m]

    if isempty(comp)
        visible(completion_window,false)
        return PROPAGATE
    end

    build_completion_window(comp,view,"",func_names)
    return INTERRUPT
end

function replace_text{T<:GtkTextIters}(buffer::GtkTextBuffer,itstart::T,itend::T,str::AbstractString)
    pos = offset(itstart)+1
    splice!(buffer,itstart:itend)
    insert!(buffer,GtkTextIter(buffer,pos),str)
end

# returns the position of the cursor inside a buffer such that we can position a window there
function get_cursor_absolute_position(view::GtkTextView)

    (it,r1,r2) = cursor_locations(view)
    (x,y) = text_view_buffer_to_window_coords(view,1,r1.x,r1.y)

    w = Gtk.G_.window(view)
    (ox,oy) = gdk_window_get_origin(w)

    return (x+ox, y+oy+r1.height,r1.height)
end

function run_line(console::Console,buffer::GtkTextBuffer)

    cmd = selected_text()
    if cmd == ""
        (cmd, itstart, itend) = get_current_line_text(buffer)
        cmd = strip(cmd)
    end
    run_command(console,cmd)
end

function run_command(c::Console,cmd::AbstractString)
    prompt(c,cmd)
    on_return(c,cmd)
end

function tab_key_release_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = getbuffer(textview)

    !update_completion_window_release(event,buffer) && return convert(Cint,true)

    return PROPAGATE
end

@guarded (INTERRUPT) function tab_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent,eventptr)
    buffer = getbuffer(textview)
    t = user_data
    console = get_current_console()

#    println(event.state)

    doing(Actions.save, event) && save(t)
    doing(Actions.open, event) && openfile_dialog()
        
    if doing(Actions.closetab, event)
        close_tab()
        save(project)
    end
    if doing(Actions.newtab, event)
        add_tab()
        save(project)
    end
    if doing(Actions.datahint, event)
        show_data_hint(textview)
    end
    if doing(Actions.search, event)
        open(search_window)
    end
    if event.keyval == Gtk.GdkKeySyms.Tab
        if !visible(completion_window) && !hasselection(t)
            return editor_autocomplete(textview,t)
        end
    end
    if doing(Actions.runline, event)
        run_line(console,buffer)
        return convert(Cint,true)
    end
    if doing(Actions.runcode, event)
        run_code(console,buffer)
        return INTERRUPT
    end
    if doing(Actions.runfile, event)
        cmd = "include(\"$(t.filename)\")"
        cmd = replace(cmd,"\\", "/")
        run_command(console,cmd)
    end
    if event.keyval == Gtk.GdkKeySyms.Escape
        set_search_text("")
        visible(search_window,false)
    end
    if doing(Actions.copy,event)
        (found,it_start,it_end) = selection_bounds(buffer)
        if !found
            (txt, its,ite) = get_line_text(buffer, get_text_iter_at_cursor(buffer))
            selection_bounds(buffer,its,ite)
        end
        signal_emit(textview, "copy-clipboard", Void)
        return INTERRUPT
    end
    if doing(Actions.paste,event)
        signal_emit(textview, "paste-clipboard", Void)
        return INTERRUPT
    end
    if doing(Actions.cut,event)
        (found,it_start,it_end) = selection_bounds(buffer)
        if !found
            (txt, its,ite) = get_line_text(buffer, get_text_iter_at_cursor(buffer))
            selection_bounds(buffer,its,ite)
        end
        signal_emit(textview, "cut-clipboard", Void)

        return INTERRUPT
    end
    if doing(Actions.move_to_line_start,event) ||
       doing(Action(GdkKeySyms.Left, PrimaryModifier),event)
        move_cursor_to_sentence_start(buffer)
        return INTERRUPT
    end
    if doing(Actions.move_to_line_end,event) ||
       doing(Action(GdkKeySyms.Right, PrimaryModifier),event)
        move_cursor_to_sentence_end(buffer)
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Right, PrimaryModifier+GdkModifierType.SHIFT),event)

        #FIXME put this and bellow in a function
        (found,its,ite) = selection_bounds(buffer)
        if !found
            its = get_text_iter_at_cursor(buffer)
            move_cursor_to_sentence_end(buffer)
            ite = get_text_iter_at_cursor(buffer)
            selection_bounds(buffer,ite,its)#invert here so the cursor end up on the far right
        else
            its = nonmutable(buffer,its)#FIXME this shouldn't require the buffer
            move_cursor_to_sentence_end(buffer)
            ite = get_text_iter_at_cursor(buffer)
            selection_bounds(buffer,ite,its)
        end
        return INTERRUPT
    end
    if doing(Action(GdkKeySyms.Left, PrimaryModifier+GdkModifierType.SHIFT),event)

        (found,its,ite) = selection_bounds(buffer)
        if !found
            ite = get_text_iter_at_cursor(buffer)
            move_cursor_to_sentence_start(buffer)
            its = get_text_iter_at_cursor(buffer)
            selection_bounds(buffer,its,ite)
        else
            ite = nonmutable(buffer,ite)
            move_cursor_to_sentence_start(buffer)
            its = get_text_iter_at_cursor(buffer)
            selection_bounds(buffer,its,ite)
        end
        return INTERRUPT
    end

    if doing(Actions.toggle_comment,event)
        user_action(toggle_comment, buffer)#make sure undo works
    end
    if doing(Actions.undo,event)
        canundo(buffer) && undo!(buffer)
        return INTERRUPT
    end
    if doing(Actions.redo,event)
        canredo(buffer) && redo!(buffer)
        return INTERRUPT
    end
    if doing(Actions.delete_line,event)
        (found,itstart,itend) = selection_bounds(buffer)
        if found
            itstart = text_iter_line_start(nonmutable(buffer,itstart))#FIXME need a mutable version
            !getproperty(itend,:ends_line,Bool) && text_iter_forward_to_line_end(itend)
            splice!(buffer,itstart-1:itend)
        else
            (cmd, itstart, itend) = get_current_line_text(buffer)
            splice!(buffer,itstart-1:itend)
        end
    end
    if doing(Actions.duplicate_line,event)
        (cmd, itstart, itend) = get_current_line_text(buffer)
        insert!(buffer,itend,"\n" * cmd)
    end

    !update_completion_window(event,buffer) && return INTERRUPT

    return PROPAGATE
end

function toggle_comment(buffer::GtkTextBuffer)

    (found,it_start,it_end) = selection_bounds(buffer)
    if found
        for i in line(it_start):line(it_end)
            toggle_comment(buffer,GtkTextIter(buffer,i,1))
        end
    else
        it = get_text_iter_at_cursor(buffer)
        toggle_comment(buffer,it)
    end
end
function toggle_comment(buffer::GtkTextBuffer,it::GtkTextIter)

    it = text_iter_line_start(it)#start of the text
    it_ls = GtkTextIter(buffer,line(it),1)#start of the line

    if get_text_right_of_iter(it_ls) == "#"
        splice!(buffer,it_ls:it_ls+1)
    else
        if get_text_right_of_iter(it) == "#"
            splice!(buffer,it:it+1)
        else
            insert!(buffer,it_ls,"#")
        end
    end
end

function run_code(console::Console, buffer::GtkTextBuffer)
    cmd = selected_text()
    if cmd == ""
        (found,it_start,it_end) = get_cell(buffer)
        if found
            cmd = text_iter_get_text(it_start,it_end)
        else
            cmd = getproperty(buffer,:text,AbstractString)
        end
    end
    run_command(console,cmd)
end

function get_word_under_mouse_cursor(textview::GtkTextView)
    (x,y) = text_view_window_to_buffer_coords(textview,mousepos[1],mousepos[2])
    iter_end = get_iter_at_position(textview,x,y)
    buffer = getproperty(textview,:buffer,GtkTextBuffer)
    (word,itstart,itend) = select_word(iter_end,buffer,false)

    return word
end

function show_data_hint(textview::GtkTextView)

    word = get_word_under_mouse_cursor(textview)

    try
      ex = parse(word)
      value = eval(Main,ex)
      value = typeof(value) == Function ? methods(value) : value
      value = sprint(Base.showlimited,value)

      label = @GtkLabel(value)
      popup = @GtkWindow("", 2, 2, true, false) |> label
      setproperty!(label,:margin,5)

      Gtk.G_.position(popup,mousepos_root[1]+10,mousepos_root[2])
      showall(popup)

      @schedule begin
          sleep(2)
          destroy(popup)
      end

    end
end

value(adj::GtkAdjustment) = getproperty(adj,:value,AbstractFloat)
value(adj::GtkAdjustment,v::AbstractFloat) = setproperty!(adj,:value,v)

# maybe I should replace this by a task that check for the
# end of loading and then call a function
function tab_adj_changed_cb(adjptr::Ptr, user_data)

    #FIXME need to check if the scroll target is valid somehow
    adj = convert(GtkAdjustment, adjptr)
    t = user_data
    if t.scroll_target != 0 && t.scroll_target_line == 0
        if value(adj) != t.scroll_target
            value(adj,t.scroll_target)
        else
            t.scroll_target = 0
        end
    end

    if t.scroll_target_line != 0
        v = line_to_adj_value(get_buffer(t.view),adj,t.scroll_target_line)
        if value(adj) != v
            value(adj,v)
        else
            t.scroll_target_line = 0
        end
    end

    return nothing
end

function tab_extend_selection_cb(widgetptr::Ptr,granularityptr::Ptr,locationptr::Ptr,it_startptr::Ptr,it_endptr::Ptr,user_data)

    view = convert(GtkTextView,widgetptr)
    location = convert(GtkTextView,locationptr)

    return convert(Cint,false)
end

function modified(t::EditorTab,v::Bool)
    t.modified = v
    f = basename(t.filename)
    f = f == "" ? "Untitled" : f

    s = v ? f * "*" : f

    setproperty!(t.label,:label,s)
end

function tab_buffer_changed_cb(widgetptr::Ptr,user_data)
    t = user_data
    modified(t,true)

    return nothing
end
