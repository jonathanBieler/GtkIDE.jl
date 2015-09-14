using Gtk
using Winston
import Base.REPLCompletions.completions

pastcmd = [""];

file = @GtkMenuItem("_File")

filemenu = @GtkMenu(file)
new_ = @GtkMenuItem("New")
push!(filemenu, new_)
open_ = @GtkMenuItem("Open")
push!(filemenu, open_)
push!(filemenu, @GtkSeparatorMenuItem())
quit = @GtkMenuItem("Quit")
push!(filemenu, quit)

mb = @GtkMenuBar()
push!(mb, file)  # notice this is the "File" item, not filemenu

win = @GtkWindow("Julia IDE")
#setproperty!(win, :width_request, 1400)
#setproperty!(win, :height_request, 900)
resize!(win,1400,900)
fontsize = 11

canvas = Gtk.@Canvas()
setproperty!(canvas,:height_request, 500)

entry = @GtkEntry()
setproperty!(entry, :text, "x = rand(100,1)");

buffer = @GtkTextBuffer()
setproperty!(buffer,:text,"")

tag = Gtk.create_tag(buffer, "error", font="Normal 16")
setproperty!(tag,:foreground,"gray")
Gtk.apply_tag(buffer, "error", Gtk.GtkTextIter(buffer,1) , Gtk.GtkTextIter(buffer,23) )

Gtk.create_tag(buffer, "cursor", font="Normal $fontsize",foreground="green")
Gtk.create_tag(buffer, "plaintext", font="Normal $fontsize",foreground="black")

textview = @GtkTextView()
setproperty!(textview,:buffer, buffer)
setproperty!(textview,:editable, false)
setproperty!(textview,:can_focus, false)
setproperty!(textview,:vexpand, true)

scwindow = @GtkScrolledWindow()
setproperty!(scwindow,:height_request, 100)
push!(scwindow,textview)
adj = getproperty(scwindow,:vadjustment, GtkAdjustment)




################
## EDITOR
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


g = @GtkGrid()

rightPan = @GtkPaned(:v)
mainPan = @GtkPaned(:h)
rightBox = @GtkBox(:v)
mainVbox = @GtkBox(:v)
consoleFrame = @GtkFrame("")
push!(consoleFrame,scwindow)

setproperty!(rightPan, :width_request, 600)

push!(rightBox,consoleFrame)
push!(rightBox,entry)

rightPan[1] = canvas
rightPan[2] = rightBox

mainPan[1] = rightPan
mainPan[2] = ntbook


push!(mainVbox,mb)
push!(mainVbox,mainPan)

#g[1] = mainPan

#g[1,1] = rightPan
#g[2,1] = ntbook
setproperty!(g, :column_homogeneous, true) # setproperty!(g,:homogeoneous,true) for gtk2
setproperty!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, mainVbox)

################
## WINSTON

if !Winston.hasfig(Winston._display,1)
  Winston.ghf()
  Winston.addfig(Winston._display, 1, Winston.Figure(canvas,Winston._pwinston))
else
  Winston._display.figs[1] = Winston.Figure(canvas,Winston._pwinston)
end

#replace plot with a version that display the plot
import Winston.plot
plot(args::Winston.PlotArg...; kvs...) = display(Winston.plot(Winston.ghf(), args...; kvs...))

################
## TERMINAL

function my_println(xs)
  insert!(buffer,string(xs))
  nothing
end

import Base.println
#println(xs...) = my_println(xs...)

#void
#gtk_clipboard_set_text (GtkClipboard *clipboard,
#                        const gchar *text,
#                        gint len);

function on_return_terminal(widget::GtkEntry,cmd::String,doClear)

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

  doClear ? setproperty!(widget,:text,"") : nothing

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

#export GtkClipboard
#@Gtk.gtktype GtkClipboard
#GtkClipboard() =  ccall((:gtk_clipboard_get,Gtk.libgtk),Ptr{GObject},(Ptr{Uint8},), "CLIPBOARD")
#clipboard_set_text(clip::Ptr{Gtk.GLib.GObject},text::String) = ccall((:gtk_clipboard_set_text,Gtk.libgtk),Void,(Ptr{Gtk.GLib.GObject},Ptr{Uint8},Cint), clip, text, length(text))

function entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
  widget = convert(GtkEntry, widgetptr)
  event = convert(Gtk.GdkEvent, eventptr)

  if Int(event.keyval) == 99 && Int(event.state) == 4 #ctrl+c

    #clipboard_set_text(GtkClipboard(),"wesh wesh yo")
    #@show "trying to copy text"
  end

  if event.keyval == Gtk.GdkKeySyms.Return
    cmd = getproperty(widget,:text,String)
    on_return_terminal(widget,cmd,true)
  end

  if event.keyval == Gtk.GdkKeySyms.Up
    setproperty!(widget,:text,pastcmd[1])
    return convert(Cint,true)
  end

  if event.keyval == Gtk.GdkKeySyms.Tab
    cmd = getproperty(widget,:text,String)

    (comp,dotpos) = completions(cmd, endof(cmd))
    show_completions(comp,dotpos,widget)

    return convert(Cint,true)
  end

  return convert(Cint,false)
end
signal_connect(entry_key_press_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

#print completions in console (maye use the one in Base?)
function show_completions(comp,dotpos,widget)
  dotpos = dotpos.start
  prefix = dotpos > 1 ? cmd[1:dotpos-1] : ""

  if(length(comp)>1)
    out = "\n"
    for i=1:length(comp)
      tabs = repeat("\t",ceil(Int,9/length(comp[i]))+1)
      out = "$out $(comp[i]) $tabs"
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
end

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
