using Gtk

include(Pkg.dir() *  "Gtk/src/GLib/GLib.jl")
using .GLib
using .GLib.MutableTypes

pastcmd = [""];

win = @GtkWindow("")
setproperty!(win, :width_request, 1200)
setproperty!(win, :height_request, 800)
fontsize = 11

entry = @GtkEntry()
setproperty!(entry, :text, "x = rand(100,1)");

buffer = @GtkTextBuffer()
setproperty!(buffer,:text,"""
                       _
           _       _ _(_)_     |  A fresh approach to technical computing
          (_)     | (_) (_)    |  Documentation: http://docs.julialang.org
           _ _   _| |_  __ _   |  Type \"?help\" for help.
          | | | | | | |/ _` |  |
          | | |_| | | | (_| |  |  Version $(VERSION)
         _/ |\\__'_|_|_|\\__'_|  |
        |__/                   |  $(Sys.MACHINE)
        """)

tag = Gtk.create_tag(buffer, "error", font="Normal 16")
setproperty!(tag,:foreground,"gray")
Gtk.apply_tag(buffer, "error", Gtk.GtkTextIter(buffer,1) , Gtk.GtkTextIter(buffer,23) )

Gtk.create_tag(buffer, "cursor", font="Normal $fontsize",foreground="green")
Gtk.create_tag(buffer, "plaintext", font="Normal $fontsize",foreground="black")

textview = @GtkTextView()
textview[:buffer] = buffer
textview[:editable] = false
textview[:can_focus] = false
textview[:vexpand] = true

scwindow = @GtkScrolledWindow()
setproperty!(scwindow,:height_request, 600)
push!(scwindow,textview)
adj = getproperty(scwindow,:vadjustment, GtkAdjustment)

## EDITOR
ntbook = @GtkNotebook()

scbook = @GtkScrolledWindow()
setproperty!(scbook,:height_request, 600)
push!(ntbook,scbook)

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
Gtk.create_tag(srcbuffer, "function", font="Bold $fontsize",foreground="black")
Gtk.create_tag(srcbuffer, "blocks",   font="Normal $fontsize",foreground="blue")
Gtk.create_tag(srcbuffer, "strings",  font="Normal $fontsize",foreground="#2a6")
Gtk.create_tag(srcbuffer, "functionnames",  font="Normal $fontsize",foreground="#a26")

Gtk.apply_tag(srcbuffer, "plaintext", Gtk.GtkTextIter(srcbuffer,1) , Gtk.GtkTextIter(srcbuffer,length(srcbuffer)) )

for t in tags
  for m in eachmatch( Regex("\\s" * t * "\\s"),getproperty(srcbuffer,:text,String) )
    Gtk.apply_tag(srcbuffer, "blocks", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(t)+1) )
  end
end
for m in eachmatch( Regex("\\sfunction\\s"),getproperty(srcbuffer,:text,String) )
  Gtk.apply_tag(srcbuffer, "function", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+9) )
end
for m in eachmatch( Regex("\"[^\"(\\\")]*\""),getproperty(srcbuffer,:text,String) )
  Gtk.apply_tag(srcbuffer, "strings", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)) )
end
for m in eachmatch( r"[\w_]+\(",getproperty(srcbuffer,:text,String) )
  Gtk.apply_tag(srcbuffer, "functionnames", Gtk.GtkTextIter(srcbuffer,m.offset) , Gtk.GtkTextIter(srcbuffer,m.offset+length(m.match)-1) )
end


g = @GtkGrid()

g[1,1] = scwindow    # Cartesian coordinates, g[x,y]
g[1,2] = entry
g[2,1:2] = ntbook
setproperty!(g, :column_homogeneous, true) # setproperty!(g,:homogeoneous,true) for gtk2
setproperty!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, g)

function on_return_terminal(widget::GtkEntry)

  cmd = getproperty(widget,:text,String)

  if cmd == ""
    insert!(buffer,"\n")
    return
  end

  if cmd == "clc"
    setproperty!(buffer,:text,"")
    setproperty!(widget,:text,"")
    return
  end

  pastcmd[1] = cmd
  ex = Base.parse_input_line(cmd)
  ex = expand(ex)

  setproperty!(widget,:text,"")

  evalout = ""
  value = :()
  @async begin

    #(outRead, outWrite) = redirect_stdout()#capture console prints
    #(errorRead, errorWrite) = redirect_stderr()

    try
      value = eval(Main,ex)
      eval(Main, :(ans = $(Expr(:quote, value))))
      evalout = sprint(Base.showlimited,value)
    catch err
      io = IOBuffer()
      showerror(io,err)
      evalout = takebuf_string(io)
      close(io)
    end

    std_data = ""
    #close(outWrite)
    #std_data = readavailable(outRead)
    #close(outRead)
    #std_data = convert(UTF8String,std_data)

    #close(errorWrite)
    #errors = readavailable(errorRead)
    #close(errorRead)
    #evalout = errors == "" ? evalout : errors

    finalOutput = "
>julia $cmd
$evalout
$std_data";
    insert!(buffer,finalOutput)

    pos = length(buffer)-length(finalOutput)
    Gtk.apply_tag(buffer, "cursor", Gtk.GtkTextIter(buffer,pos+3) , Gtk.GtkTextIter(buffer,pos+10) )
    Gtk.apply_tag(buffer, "plaintext", Gtk.GtkTextIter(buffer,pos+10),Gtk.GtkTextIter(buffer,length(buffer)) )

  end
end

function entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkEntry, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  if event.keyval == Gtk.GdkKeySyms.Return
    on_return_terminal(widget)
  end

  if event.keyval == Gtk.GdkKeySyms.Up
    setproperty!(widget,:text,pastcmd[1])
    return convert(Cint,true)
  end

  return convert(Cint,false)
end
signal_connect(entry_key_press_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

text_iter_forward_line(it::Mutable{Gtk.GtkTextIter})  = ccall((:gtk_text_iter_forward_line,  Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_backward_line(it::Mutable{Gtk.GtkTextIter}) = ccall((:gtk_text_iter_backward_line, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)

function editor_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkTextView, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  if event.keyval == Gtk.GdkKeySyms.Return && Int(event.state) == 5 #ctrl+shift

    itstart = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)-2) #select current line
    itend = Gtk.GtkTextIter(srcbuffer,getproperty(srcbuffer,:cursor_position,Int)+2) #select current line
    text_iter_backward_line(itstart)
    #text_iter_forward_line(itend)
    Gtk.apply_tag(srcbuffer, "function", itstart , itend )

    show(itstart)

    return convert(Cint,true)
  end

  return convert(Cint,false)#false : propagate
end
signal_connect(editor_key_press_cb, textviewsrc, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

## scroll textview
function scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)
  setproperty!(adj,:value, getproperty(adj,:upper,FloatingPoint) - getproperty(adj,:page_size,FloatingPoint))
  nothing
end
signal_connect(scroll_cb, textview, "size-allocate", Void, (Ptr{Gtk.GdkRectangle},), false)


## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

  return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win);
