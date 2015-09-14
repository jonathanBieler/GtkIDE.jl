## SETUP
ntbook = @GtkNotebook()

scbook = @GtkScrolledWindow()
setproperty!(scbook,:height_request, 600)
push!(ntbook,scbook)

scbook2 = @GtkScrolledWindow()
setproperty!(scbook2,:height_request, 600)
push!(ntbook,scbook2)

srcbuffer = @GtkTextBuffer()

f = open("d:\\Julia\\JuliaIDE\\Main.jl")
setproperty!(srcbuffer,:text,readall(f))
close(f)

textviewsrc = @GtkTextView()
setproperty!(textviewsrc,:buffer,srcbuffer)
push!(scbook,textviewsrc)

#ref : https://github.com/quinnj/Sublime-Julia/blob/master/Syntax/Julia.tmLanguage
tags = ["end","if","for","try","else","catch"]

Gtk.create_tag(srcbuffer, "plaintext", font="Normal $fontsize",foreground="black")
Gtk.create_tag(srcbuffer, "function",  font="Bold $fontsize",foreground="black")
Gtk.create_tag(srcbuffer, "blocks",    font="Normal $fontsize",foreground="#42f")
Gtk.create_tag(srcbuffer, "brackets",  font="Normal $fontsize",foreground="#624")
Gtk.create_tag(srcbuffer, "strings",   font="Normal $fontsize",foreground="#a02")
Gtk.create_tag(srcbuffer, "functionnames",  font="Normal $fontsize",foreground="#a26")
Gtk.create_tag(srcbuffer, "comments",       font="Normal $fontsize",foreground="#1a1")

## Callbacks

doing_highlight_syntax = false
function highlight_syntax()
  doing_highlight_syntax = true
  Gtk.remove_all_tags(srcbuffer,Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)))
  Gtk.apply_tag(srcbuffer, "plaintext", Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)) )

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
  doing_highlight_syntax = false
end

highlight_syntax()
@time highlight_syntax()


function editor_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkTextView, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 5 #ctrl+shift

    itstart = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)) #select current line
    itend = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)) #select current line

    itstart = Gtk.GLib.MutableTypes.mutable(itstart)
    itend = Gtk.GLib.MutableTypes.mutable(itend)

    text_iter_backward_line(itstart)
    skip(itstart,1,:line)
    text_iter_forward_to_line_end(itend)

    #Gtk.apply_tag(srcbuffer, "function", itstart , itend )

    txt = getproperty(srcbuffer,:text,String)
    txt = txt[getproperty(itstart,:offset,Int):getproperty(itend,:offset,Int)]

    on_return_terminal(entry,txt,false)

    #setproperty!(entry,:text,txt)
    #keyevent = Gtk.GdkEventKey(Gtk.GdkEventType.KEY_PRESS, Gtk.gdk_window(entry), Int8(0), UInt32(0), UInt32(0), Gtk.GdkKeySyms.Return, UInt32(0), convert(Ptr{Uint8},C_NULL), UInt16(13), UInt8(0), uint32(0) )
    #signal_emit(entry, "key-press-event", Bool, keyevent)

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
