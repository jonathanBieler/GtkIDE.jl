using Gtk
using Winston
import Base.REPLCompletions.completions

pastcmd = [""];

win = @GtkWindow("")
setproperty!(win, :width_request, 1200)
setproperty!(win, :height_request, 800)
fontsize = 11

canvas = Gtk.@Canvas()
setproperty!(canvas,:height_request, 500)

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
setproperty!(scwindow,:height_request, 100)
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

rightPan = @GtkPaned(:v)
mainPan = @GtkPaned(:h)
rightBox = @GtkBox(:v)

setproperty!(rightPan, :width_request, 600)

push!(rightBox,scwindow)
push!(rightBox,entry)

rightPan[1] = canvas
rightPan[2] = rightBox

mainPan[1] = rightPan
mainPan[2] = ntbook

#g[1] = mainPan

#g[1,1] = rightPan
#g[2,1] = ntbook
setproperty!(g, :column_homogeneous, true) # setproperty!(g,:homogeoneous,true) for gtk2
setproperty!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, mainPan)

## Winston things

if !Winston.hasfig(Winston._display,1)
  Winston.ghf()
  Winston.addfig(Winston._display, 1, Winston.Figure(canvas,Winston._pwinston))
else
  Winston._display.figs[1] = Winston.Figure(canvas,Winston._pwinston)
end


## TERMINAL

function my_println(xs)
  insert!(buffer,string(xs))
  nothing
end

import Base.println
#println(xs...) = my_println(xs...)

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

  if event.keyval == Gtk.GdkKeySyms.Tab
    cmd = getproperty(widget,:text,String)

    (comp,dotpos) = completions(cmd, endof(cmd))
    dotpos = dotpos.start
    prefix = dotpos > 1 ? cmd[1:dotpos-1] : ""

    if(length(comp)>1)
      out = "\n"
      for i=1:length(comp)
        out = "$out $(comp[i]) \t\t"
        if mod(i,6) == 0
          out = out * "\n"
        end
      end
      out = out * "\n"
      insert!(buffer,out)
      out = prefix * Base.LineEdit.common_prefix(comp)
      setproperty!(widget,:text,out)
      set_position(widget,endof(out))

    elseif !isempty(comp)
      out = prefix * comp[1]
      setproperty!(widget,:text,out)
      set_position(widget,endof(out))
    end

    return convert(Cint,true)
  end

  return convert(Cint,false)
end
signal_connect(entry_key_press_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

text_iter_forward_line(it::Gtk.GLib.MutableTypes.Mutable{Gtk.GtkTextIter})  = ccall((:gtk_text_iter_forward_line,  Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_backward_line(it::Gtk.GLib.MutableTypes.Mutable{Gtk.GtkTextIter}) = ccall((:gtk_text_iter_backward_line, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_forward_to_line_end(it::Gtk.GLib.MutableTypes.Mutable{Gtk.GtkTextIter}) = ccall((:gtk_text_iter_forward_to_line_end, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)

function set_position(editable::Gtk.Entry,position_)
    ccall((:gtk_editable_set_position,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),editable,position_)
    return editable
end

function editor_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkTextView, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  @show event

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
    setproperty!(entry,:text,txt)

    keyevent = Gtk.GdkEventKey(Gtk.GdkEventType.KEY_PRESS, Gtk.gdk_window(entry), Int8(0), UInt32(0), UInt32(0), Gtk.GdkKeySyms.Return, UInt32(0), convert(Ptr{Uint8},C_NULL), UInt16(13), UInt8(0), uint32(0) )
    signal_emit(entry, "key-press-event", Bool, keyevent)

    #creating an event ain't easy
    #event = Gtk.GdkEventKey(8,Ptr{Void} @0x0000000013dde300,0,0x02a26074,0x00000000,0x0000ff0d,1,Ptr{UInt8} @0x000000001262a8c0,0x000d,0x00,0x00000000)
    #immutable GdkEventKey <: GdkEvent
    #    event_type::GEnum
    #    gdk_window::Ptr{Void}
    #    send_event::Int8
    #    time::Uint32
    #    state::Uint32
    #    keyval::Uint32
    #    length::Int32
    #    string::Ptr{Uint8}
    #    hardware_keycode::Uint16
    #    group::Uint8
    #    flags::Uint32
    #end

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
