## SETUP

type EditorTab <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer

    function EditorTab()

        b = @GtkSourceBuffer(languageDef)
        sc = @GtkScrolledWindow() |>
            (v = @GtkSourceView(b))

        setproperty!(b,:style_scheme,style)
        show_line_numbers!(v,true)
        auto_indent!(v,true)
        highlight_matching_brackets(b,true)
        highlight_current_line!(v, true)

        t = new(sc.handle,v,b)
        Gtk.gobject_move_ref(t, sc)
    end
end

function set_text!(t::EditorTab,text::String)
    setproperty!(t.buffer,:text,text)
    set_font(t)
end

getbuffer(textview::GtkTextView) = getproperty(textview,:buffer,GtkSourceBuffer)

#hack while waiting for proper fonts
function set_font(t::EditorTab)
    Gtk.create_tag(t.buffer, "plaintext", font="Normal $fontsize")
    Gtk.apply_tag(t.buffer, "plaintext", Gtk.GtkTextIter(t.buffer,1) , Gtk.GtkTextIter(t.buffer,length(t.buffer)+1) )
end

ntbook = @GtkNotebook()
    setproperty!(ntbook,:scrollable, true)
    setproperty!(ntbook,:enable_popup, true)

#text_buffer_place_cursor(buffer,its)

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



# signal_connect(srcbuffer, "changed") do widget
#   if !doing_highlight_syntax
#     highlight_syntax()
#   end
# end

signal_connect(ntbook, "switch-page") do widget, page, page_num, args...

end

mousepos = zeros(Int,2)
mousepos_root = zeros(Int,2)
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
    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    @show event
    #
    if event.keyval == keyval("w") && Int(event.state) == 4 #ctrl
        close_tab()
    end
    if event.keyval == keyval("n") && Int(event.state) == 4
        add_tab()
    end

    if event.keyval == keyval("d") && Int(event.state) == 4

        (x,y) = text_view_window_to_buffer_coords(textview,mousepos[1],mousepos[2])
        iter_end = get_iter_at_position(textview,x,y)
        iter_start = copy(iter_end)

        text_iter_forward_word_end(iter_end)
        text_iter_backward_word_start(iter_start)

        word = text_iter_get_text(iter_end, iter_start)

        try
          ex = parse(word)
          value = eval(Main,ex)
          value = typeof(value) == Function ? methods(value) : value
          value = sprint(Base.showlimited,value)

          label = @GtkLabel(value)
          popup = @GtkWindow("", 120, 80, false, false) |> label
          Gtk.G_.position(popup,mousepos_root[1],mousepos_root[2])
          showall(popup)

          @schedule begin
              sleep(1)
              destroy(popup)
          end

        end

    end

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 5 #ctrl+shift

        buffer = getbuffer(textview)

        #this is a bit buggy
        itstart = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int)) #select current line
        itend = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int)) #select current line

        itstart = Gtk.GLib.MutableTypes.mutable(itstart)
        itend = Gtk.GLib.MutableTypes.mutable(itend)

        text_iter_backward_line(itstart)
        skip(itstart,1,:line)
        text_iter_forward_to_line_end(itend)

        txt = getproperty(buffer,:text,String)
        txt = txt[getproperty(itstart,:offset,Int):getproperty(itend,:offset,Int)]

        on_return_terminal(entry,txt,false)

        return convert(Cint,true)
    end

    if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 4 #ctrl

        buffer = getbuffer(textview)

        (found,it_start,it_end) = get_cell(buffer)
        if found
            cmd = text_iter_get_text(it_start,it_end)
        else
            cmd = getproperty(buffer,:text,String)
            @show cmd
        end
        on_return_terminal(entry,cmd,false)
        return convert(Cint,true)
    end


    return convert(Cint,false)#false : propagate
end



function add_tab()
    t = EditorTab();

    idx = get_current_page_idx(ntbook)+1
    insert!(ntbook, idx, t, "Page $idx")
    showall(ntbook)
    set_current_page_idx(ntbook,idx)

    signal_connect(tab_key_press_cb,t.view , "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false) #we need to use the view here to capture all the keystrokes
end

for i = 1:2
    add_tab()
end

f = open("d:\\Julia\\JuliaIDE\\Editor.jl")
set_text!(get_tab(ntbook,1),readall(f))
close(f)

set_text!(get_tab(ntbook,2),
"
function f(x)
    x
end

## ploting sin

	x = 0:0.01:5
	plot(x,exp(-x))

## ploting a spiral

	x = 0:0.01:4*pi
	plot(x.*cos(x),x.*sin(x))

##
    x = 0:0.01:3*pi
    for i=1:100
        plot(x.*cos(i/15*x),x.*sin(i/10*x),
            xrange=(-8,8),
            yrange=(-8,8)
        )
        drawnow()
    end
##
")
