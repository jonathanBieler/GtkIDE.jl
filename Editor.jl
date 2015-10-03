#todo : filename should save the full path


global sourcemap = @GtkSourceMap()
global ntbook = @GtkNotebook()
    setproperty!(ntbook,:scrollable, true)
    setproperty!(ntbook,:enable_popup, true)

type EditorTab <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    filename::AbstractString
    modified::Bool

    function EditorTab()

        b = @GtkSourceBuffer(languageDef)
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

        t = new(sc.handle,v,b,"",false)
        Gtk.gobject_move_ref(t, sc)
    end
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
        f = Base.open(filename)
        set_text!(t,readall(f))
        t.filename = filename
        t.modified = false
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
    catch err
        @show err
    end
end
in
save_current_tab() = save(get_current_tab())

function open_in_new_tab(filename::AbstractString)
    add_tab()
    filename = ispath(filename) ? filename : joinpath(pwd(),filename)
    open(get_current_tab(),filename)
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

function tab_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    #note use write(console,...) here and not print or @show

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

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

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == (GdkModifierType.CONTROL + GdkModifierType.SHIFT)

        buffer = getbuffer(textview)
        txt = strip(get_current_line_text(buffer))
        on_return_terminal(entry,txt,false)

        return convert(Cint,true)
    end

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 4 #ctrl

        buffer = getbuffer(textview)

        (found,it_start,it_end) = get_cell(buffer)
        if found
            cmd = text_iter_get_text(it_start,it_end)
        else
            cmd = getproperty(buffer,:text,AbstractString)
        end
        on_return_terminal(entry,cmd,false)
        return convert(Cint,true)
    end

    return convert(Cint,false)#false : propagate
end

function show_data_hint(textview::GtkTextView)

    (x,y) = text_view_window_to_buffer_coords(textview,mousepos[1],mousepos[2])
    iter_end = get_iter_at_position(textview,x,y)
    iter_start = copy(iter_end)

    getproperty(iter_start,:ends_word,Bool) ? nothing : text_iter_forward_word_end(iter_end)
    getproperty(iter_start,:starts_word,Bool) ? nothing : text_iter_backward_word_start(iter_start)

    word = text_iter_get_text(iter_end, iter_start)

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

function get_current_line_text(buffer::GtkTextBuffer)

    itstart = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int)) #select current line
    itend = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int)) #select current line

    itstart = Gtk.GLib.MutableTypes.mutable(itstart)
    itend = Gtk.GLib.MutableTypes.mutable(itend)

    text_iter_backward_line(itstart)
    skip(itstart,1,:line)
    text_iter_forward_to_line_end(itend)

    txt = getproperty(buffer,:text,AbstractString)
    return txt[getproperty(itstart,:offset,Int):getproperty(itend,:offset,Int)]
end


function add_tab()
    t = EditorTab();

    idx = get_current_page_idx(ntbook)+1
    insert!(ntbook, idx, t, "Page $idx")
    showall(ntbook)
    set_current_page_idx(ntbook,idx)

    Gtk.create_tag(t.buffer, "debug1", font="Normal $fontsize",background="green")
    Gtk.create_tag(t.buffer, "debug2", font="Normal $fontsize",background="blue")
    set_font(t)

    signal_connect(tab_key_press_cb,t.view , "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false) #we need to use the view here to capture all the keystrokes
end

#open_in_new_tab("d:\\Julia\\JuliaIDE\\repl.jl")
#open_in_new_tab("d:\\Julia\\JuliaIDE\\Editor.jl")

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
