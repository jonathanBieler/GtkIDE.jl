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
get_current_tab() = tabs[current_tab]
getbuffer(textview::GtkTextView) = getproperty(textview,:buffer,GtkSourceBuffer)

#hack while waiting for proper fonts
function set_font(t::EditorTab)
    Gtk.create_tag(t.buffer, "plaintext", font="Normal $fontsize")
    Gtk.apply_tag(t.buffer, "plaintext", Gtk.GtkTextIter(t.buffer,1) , Gtk.GtkTextIter(t.buffer,length(t.buffer)+1) )
end

ntbook = @GtkNotebook()
    setproperty!(ntbook,:scrollable, true)
    setproperty!(J.ntbook,:enable_popup, true)



#text_buffer_place_cursor(buffer,its)

#see : https://github.com/quinnj/Sublime-Julia/blob/master/Syntax/Julia.tmLanguage
tags = ["end","if","for","try","else","catch"]

Gtk.create_tag(srcbuffer, "plaintext", font="Normal $fontsize",foreground="black")
Gtk.create_tag(srcbuffer, "function",  font="Bold $fontsize",foreground="black")
Gtk.create_tag(srcbuffer, "blocks",    font="Normal $fontsize",foreground="#42f")
Gtk.create_tag(srcbuffer, "brackets",  font="Normal $fontsize",foreground="#624")
Gtk.create_tag(srcbuffer, "strings",   font="Normal $fontsize",foreground="#a02")
Gtk.create_tag(srcbuffer, "functionnames",  font="Normal $fontsize",foreground="#a26")
Gtk.create_tag(srcbuffer, "comments",       font="Normal $fontsize",foreground="#1a1")
Gtk.create_tag(srcbuffer, "cell",       font="Normal $fontsize",background="#FAF2DC")
Gtk.create_tag(srcbuffer, "background",       font="Normal $fontsize",background="white")
## Callbacks

#Gtk.create_tag(srcbuffer2, "plaintext", font="Normal $fontsize")
#Gtk.apply_tag(srcbuffer2, "plaintext", Gtk.GtkTextIter(srcbuffer2,1) , Gtk.GtkTextIter(srcbuffer2,length(srcbuffer)+1) )

doing_highlight_syntax = false
function highlight_syntax()
  doing_highlight_syntax = true
  Gtk.remove_all_tags(srcbuffer,Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)+1))
  Gtk.apply_tag(srcbuffer, "plaintext", Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)+1) )

  for t in tags
    for m in eachmatch( Regex("\\s" * t * "\\s?"),getproperty(srcbuffer,:text,String) )
      Gtk.apply_tag(srcbuffer, "blocks", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(t)+1) )
    end
  end
  for m in eachmatch( Regex("\\sfunction\\s"),getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "function", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+9) )
  end
  for m in eachmatch( r"[a-zA-Z_!]+\(",getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "functionnames", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)-1) )
  end
  for m in eachmatch(r"\[[^]]+\]",getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "brackets", Gtk.GtkTextIter(srcbuffer,m.offset+1) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)-1) )
  end
  for m in eachmatch(r"#.*\s",getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "comments", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)) )
  end
  for m in eachmatch( Regex("\"[^\"(\\\")]*\""),getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "strings", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)) )
  end
  highlight_cells()
  doing_highlight_syntax = false

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

highlight_syntax()
@time highlight_syntax()

function editor_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkTextView, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  if event.keyval == Gtk.GdkKeySyms.Left
      #cursors = cursors-1
  end

  if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 5 #ctrl+shift

    itstart = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)) #select current line
    itend = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)) #select current line

    itstart = Gtk.GLib.MutableTypes.mutable(itstart)
    itend = Gtk.GLib.MutableTypes.mutable(itend)

    text_iter_backward_line(itstart)
    skip(itstart,1,:line)
    text_iter_forward_to_line_end(itend)

    txt = getproperty(srcbuffer,:text,String)
    txt = txt[getproperty(itstart,:offset,Int):getproperty(itend,:offset,Int)]

    on_return_terminal(entry,txt,false)

    #setproperty!(entry,:text,txt)
    #keyevent = Gtk.GdkEventKey(Gtk.GdkEventType.KEY_PRESS, Gtk.gdk_window(entry), Int8(0), UInt32(0), UInt32(0), Gtk.GdkKeySyms.Return, UInt32(0), convert(Ptr{Uint8},C_NULL), UInt16(13), UInt8(0), uint32(0) )
    #signal_emit(entry, "key-press-event", Bool, keyevent)

    return convert(Cint,true)
  end

  if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 4 #ctrl
      highlight_cells()
      (found,it_start,it_end) = get_cell(srcbuffer)
      if found
          cmd = text_iter_get_text(it_start,it_end)
      else
          cmd = getproperty(srcbuffer,:text,String)
          @show cmd
      end
      on_return_terminal(entry,cmd,false)
      return convert(Cint,true)
  end

  return convert(Cint,false)#false : propagate
end
signal_connect(editor_key_press_cb, textviewsrc, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

signal_connect(srcbuffer, "changed") do widget
  if !doing_highlight_syntax
    highlight_syntax()
  end
end

signal_connect(ntbook, "switch-page") do widget, page, page_num, args...
    current_tab = Int(page_num)+1
end

function tab_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == keyval("w") && Int(event.state) == 4 #ctrl
        pos = get_current_page(ntbook)
        splice!(ntbook,pos)
        set_current_page(ntbook,max(pos-1,0))
    end
    if event.keyval == keyval("n") && Int(event.state) == 4
        add_tab()
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
    push!(tabs,t)

    pos = get_current_page(ntbook)+1
    insert!(ntbook, pos, t, "Page $pos")
    showall(ntbook)
    set_current_page(ntbook,pos)

    signal_connect(tab_key_press_cb,t.view , "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false) #we need to use the view here to capture all the keystrokes
end

for i = 1:2
    add_tab()
end

f = open("d:\\Julia\\JuliaIDE\\Editor.jl")
set_text!(tabs[1],readall(f))
close(f)

set_text!(tabs[2],
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
