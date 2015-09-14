## SETUP

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


## Callbacks
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

## scroll textview
function scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)
  setproperty!(adj,:value, getproperty(adj,:upper,FloatingPoint) - getproperty(adj,:page_size,FloatingPoint))
  nothing
end
signal_connect(scroll_cb, textview, "size-allocate", Void, (Ptr{Gtk.GdkRectangle},), false)
