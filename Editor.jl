#todo : filename should save the full path

include("CompletionWindow.jl")
include("SearchWindow.jl")

extension(f::AbstractString) = splitext(f)[2]

global sourcemap = @GtkSourceMap()
global ntbook = @GtkNotebook()
    setproperty!(ntbook,:scrollable, true)
    setproperty!(ntbook,:enable_popup, true)

global search_settings = @GtkSourceSearchSettings()
setproperty!(search_settings,:wrap_around,true)

type EditorTab <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    filename::AbstractString
    modified::Bool
    search_context::GtkSourceSearchContext
    search_mark

    function EditorTab(filename::AbstractString)

        lang = haskey(languageDefinitions,extension(filename)) ? languageDefinitions[extension(filename)] : languageDefinitions[".jl"]

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

        t = new(sc.handle,v,b,filename,false,search_con,nothing)
        Gtk.gobject_move_ref(t, sc)
    end
    EditorTab() = EditorTab("")
end

function set_text!(t::EditorTab,text::AbstractString)
    setproperty!(t.buffer,:text,text)
end
get_text(t::EditorTab) = getproperty(t.buffer,:text,AbstractString)
getbuffer(textview::GtkTextView) = getproperty(textview,:buffer,GtkSourceBuffer)
get_current_tab() = get_tab(ntbook,get_current_page_idx(ntbook))

import Base.open
function open(t::EditorTab, filename::AbstractString)
    try
        if isfile(filename)
            f = Base.open(filename)
            set_text!(t,readall(f))
            t.modified = false
        else
            f = Base.open(filename,"w")
            t.modified = true
        end
        t.filename = filename
        set_tab_label_text(ntbook,t,basename(filename))
        reset_undomanager(t.buffer)#otherwise we can undo loading the file...
        close(f)
    catch err
        @show err
    end
    update!(project)
end

function save(t::EditorTab)
    try
        f = Base.open(t.filename,"w")
        write(f,get_text(t))
        write(console,"saved $(t.filename)")
        close(f)
    catch err
        @show err
    end
end

save_current_tab() = save(get_current_tab())

function open_in_new_tab(filename::AbstractString)
    filename = ispath(filename) ? filename : joinpath(pwd(),filename)
    t = add_tab(filename)
    open(t,filename)
    return t
end

function set_font(t::EditorTab)
    sc = Gtk.G_.style_context(t.view)
    push!(sc, provider, 600)
end

function get_cell(buffer::GtkTextBuffer)
    (foundb,itb_start,itb_end) = text_iter_backward_search(buffer,"##")
    (foundf,itf_start,itf_end) = text_iter_forward_search(buffer,"##")
     return((foundf == 1 && foundb == 1), itb_start, itf_end)
end

function highlight_cells()

    Gtk.apply_tag(srcbuffer, "background", Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)+1) )
    (found,it_start,it_end) = get_cell(srcbuffer)

    if found
        Gtk.apply_tag(srcbuffer, "cell", it_start , it_end )
    end
end

function get_selected_text()
    t = get_current_tab()
    (found,it_start,it_end) = selection_bounds(t.buffer)
    return found ? text_iter_get_text(it_start,it_end) : ""
end

function ntbook_switch_page_cb(widgetptr::Ptr, pageptr::Ptr, pagenum::Int32, user_data)

    page = convert(Gtk.GtkWidget, pageptr)
    if typeof(page) == EditorTab
        set_view(sourcemap, page.view)
    end
    nothing
end
signal_connect(ntbook_switch_page_cb,ntbook, "switch-page", Void, (Ptr{Gtk.GtkWidget},Int32), false)

global mousepos = zeros(Int,2)
global mousepos_root = zeros(Int,2)
signal_connect(ntbook, "motion-notify-event") do widget, event, args...
    mousepos[1] = round(Int,event.x)
    mousepos[2] = round(Int,event.y)
    mousepos_root[1] = round(Int,event.x_root)
    mousepos_root[2] = round(Int,event.y_root)
end

function close_tab()
    idx = get_current_page_idx(ntbook)
    splice!(ntbook,idx)
    set_current_page_idx(ntbook,max(idx-1,0))
end

import GtkSourceWidget.set_search_text
set_search_text(s::AbstractString) = set_search_text(search_settings,s)


#FIXME need to take into account module
#set the cursos position ?
function open_method(textview::GtkTextView)

    word = get_word_under_cursor(textview)

    try
        ex = parse(word)
        value = eval(Main,ex)
        value = typeof(value) == Function ? methods(value) : value

        tv, decls, file, line = Base.arg_decl_parts(value.defs)
        file = string(file)
        file = ispath(file) ? file : joinpath( joinpath(splitdir(JULIA_HOME)[1],"share\\julia\\base"), file)
        if ispath(file)
            t = open_in_new_tab(file)

            iter = mutable(Gtk.GtkTextIter(t.buffer))
            setproperty!(iter,:line,line)

            @schedule begin
                sleep(0.5) #FIXME
                scroll_to_iter(t.view,iter)
            end
        end
    end

end

function tab_button_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    
    if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        @show "wesh"
        return convert(Cint,true)
    end

    if Int(event.button) == 1 && Int(event.state) == GdkModifierType.CONTROL #ctrl+right click
        open_method(textview)
    end

    return convert(Cint,false)#false : propagate
end

function get_autocomplete_cmd(buffer::GtkTextBuffer)

    itstart = mutable( get_text_iter_at_cursor(buffer) )
    itend = mutable( get_text_iter_at_cursor(buffer) ) +1

    c = text_iter_get_text(itstart,itend)
    if c == " " || c == "\n" || c == "\t" || c == ""
        return ("",itstart,itend)
    end

    cmd = ""
    if getproperty(itstart,:starts_word,Bool)#FIXME I need my own word start definition to avoid this mess
        cmd = text_iter_get_text(itstart-1,itend)
        if can_extend_backward(itstart)
            itstart = extend_word_backward(itstart)
            cmd = text_iter_get_text(itstart,itend)
        end
    else
        text_iter_backward_word_start(itstart)
        itstart = extend_word_backward(itstart)

        cmd = text_iter_get_text(itstart,itend)
    end
    return (cmd,itstart,itend)
end

function editor_autocomplete(view::GtkTextView,replace=true)

    buffer = getproperty(view,:buffer,GtkTextBuffer)

    (cmd,itstart,itend) = get_autocomplete_cmd(buffer)

    if cmd == ""
        visible(completion_window,false)
        return convert(Cint, false)  #we go back to normal behavior if there's nothing on the left of the cursor
    end

    (comp,dotpos) = completions(cmd, endof(cmd))
    if isempty(comp)
        visible(completion_window,false)
        return convert(Cint, false)
    end

    dotpos_ = dotpos
    dotpos = dotpos.start
    prefix = dotpos > 1 ? cmd[1:dotpos-1] : "" #FIXME: redundant with the console code
    out = ""
    if(length(comp)>1)
        #show_completions(comp,dotpos_,nothing,cmd) ##FIXME need a window here
        out = prefix * Base.LineEdit.common_prefix(comp)
    else
        out = prefix * comp[1]        
    end
    build_completion_window(comp,view,prefix)
    replace && replace_text(buffer,itstart,itend,out)

    return convert(Cint, true)
end

function replace_text(buffer::GtkTextBuffer,itstart::GtkTextIters,itend::GtkTextIters,str::AbstractString)
    text_buffer_delete(buffer,itstart,itend)
    insert!(buffer,itstart,str)
end

# returns the position of the cursor inside a buffer such that we can position
# a window there
function get_cursor_absolute_position(view)

    (it,r1,r2) = cursor_locations(view)
    (x,y) = text_view_buffer_to_window_coords(view,1,r1.x,r1.y)

    w = Gtk.G_.window(view)
    (ox,oy) = gdk_window_get_origin(w)

    return (x+ox, y+oy+r1.height,r1.height)

end

function tab_key_release_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = getbuffer(textview)

    !update_completion_window_release(event,buffer) && return convert(Cint,true)

    return convert(Cint,false)#false : propagate
end

function tab_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    #note use write(console,...) here and not print or @show

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = getbuffer(textview)

    if event.keyval == keyval("s") && Int(event.state) == GdkModifierType.CONTROL
        save_current_tab()
    end
    if event.keyval == keyval("w") && Int(event.state) == GdkModifierType.CONTROL
        close_tab()
        save(project)
    end
    if event.keyval == keyval("n") && Int(event.state) == GdkModifierType.CONTROL
        add_tab()
        save(project)
    end
    if event.keyval == keyval("d") && Int(event.state) == GdkModifierType.CONTROL
        show_data_hint(textview)
    end
    if event.keyval == keyval("f") && Int(event.state) == GdkModifierType.CONTROL
        open_search_window("")
    end
    if event.keyval == Gtk.GdkKeySyms.Tab
        if !visible(completion_window)
            return editor_autocomplete(textview)
        end
    end

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == (GdkModifierType.CONTROL + GdkModifierType.SHIFT)

        txt = strip(get_current_line_text(buffer))
        on_return_terminal(entry,txt,false)

        return convert(Cint,true)
    end

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == GdkModifierType.CONTROL

        cmd = get_selected_text()
        if cmd == ""
            (found,it_start,it_end) = get_cell(buffer)
            if found
                cmd = text_iter_get_text(it_start,it_end)
            else
                cmd = getproperty(buffer,:text,AbstractString)
            end
        end
        on_return_terminal(entry,cmd,false)
        return convert(Cint,true)
    end

    !update_completion_window(event,buffer) && return convert(Cint,true)

    return convert(Cint,false)#false : propagate
end

can_extend_backward(iter) = text_iter_get_text(iter, iter-1) == "_"
can_extend_forward(iter) = text_iter_get_text(iter+1, iter) == "_"

#this is a bit brittle
function extend_word_backward(iter_start)

    while can_extend_backward(iter_start)
        iter_start = iter_start - 2
        text_iter_backward_word_start(iter_start)
    end
    return iter_start
end

function extend_word_forward(iter_end)

    while can_extend_forward(iter_end)
        iter_end = iter_end + 2
        text_iter_forward_word_end(iter_end)
    end

    if text_iter_get_text(iter_end+1, iter_end) == "!"
        iter_end = iter_end + 1
    end
    return iter_end
end

function get_word_under_cursor(textview::GtkTextView)

    (x,y) = text_view_window_to_buffer_coords(textview,mousepos[1],mousepos[2])
    iter_end = get_iter_at_position(textview,x,y)
    iter_start = copy(iter_end)

    getproperty(iter_start,:ends_word,Bool) ? nothing : text_iter_forward_word_end(iter_end)
    getproperty(iter_start,:starts_word,Bool) ? nothing : text_iter_backward_word_start(iter_start)

    iter_start = extend_word_backward(iter_start)
    iter_end = extend_word_forward(iter_end)

    word = text_iter_get_text(iter_end, iter_start)
    return word
end

function show_data_hint(textview::GtkTextView)

    word = get_word_under_cursor(textview)

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



get_text_iter_at_cursor(buffer::GtkTextBuffer) = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))

function get_current_line_text(buffer::GtkTextBuffer)

    itstart = get_text_iter_at_cursor(buffer)
    itend = get_text_iter_at_cursor(buffer)

    itstart = Gtk.GLib.MutableTypes.mutable(itstart)
    itend = Gtk.GLib.MutableTypes.mutable(itend)

    text_iter_backward_line(itstart)
    skip(itstart,1,:line)
    text_iter_forward_to_line_end(itend)

    return text_iter_get_text(itstart, itend)
end

function add_tab(filename::AbstractString)
    t = EditorTab(filename);

    idx = get_current_page_idx(ntbook)+1
    insert!(ntbook, idx, t, "Page $idx")
    showall(ntbook)
    set_current_page_idx(ntbook,idx)

    Gtk.create_tag(t.buffer, "debug1", font="Normal $fontsize",background="green")
    Gtk.create_tag(t.buffer, "debug2", font="Normal $fontsize",background="blue")
    set_font(t)

    signal_connect(tab_key_press_cb,t.view , "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false) #we need to use the view here to capture all the keystrokes
    signal_connect(tab_key_release_cb,t.view , "key-release-event", Cint, (Ptr{Gtk.GdkEvent},), false)
    signal_connect(tab_button_press_cb,t.view , "button-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
    return t
end
add_tab() = add_tab("untitled")

for f in project.files
    open_in_new_tab(f)
end

if length(ntbook)==0
    add_tab()
end

t = get_current_tab()
set_view(sourcemap,t.view)

# for i = 1:2
#     add_tab()
# end

##open(get_tab(ntbook,1),"d:\\Julia\\JuliaIDE\\repl.jl")

# set_text!(get_tab(ntbook,2),
# "
# function f(x)
#     x
# end
#
# ## ploting sin
#
# 	x = 0:0.01:5
# 	plot(x,exp(-x))
#
# ## ploting a spiral
#
# 	x = 0:0.01:4*pi
# 	plot(x.*cos(x),x.*sin(x))
#
# ##
#     x = 0:0.01:3*pi
#     for i=1:100
#         plot(x.*cos(i/15*x),x.*sin(i/10*x),
#             xrange=(-8,8),
#             yrange=(-8,8)
#         )
#         drawnow()
#     end
# ##
# ")
# end
# ##
# ")
