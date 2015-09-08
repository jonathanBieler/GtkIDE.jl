using Gtk

pastcmd = [""];

win = @GtkWindow("")
setproperty!(win, :width_request, 800)
setproperty!(win, :height_request, 600)

entry = @GtkEntry()
setproperty!(entry, :text, "x = rand(100,1)");

buffer = @GtkTextBuffer()
setproperty!(buffer,:text,"wesh")

textview = @GtkTextView()
setproperty!(textview,:buffer,buffer)
setproperty!(textview,:editable,false)
setproperty!(textview,:can_focus,false)

scwindow = @GtkScrolledWindow()
setproperty!(scwindow,:height_request, 400)
push!(scwindow,textview)
adj = getproperty(scwindow,:vadjustment, GtkAdjustment)

g = @GtkGrid()

g[1,1] = scwindow    # Cartesian coordinates, g[x,y]
g[1,2] = entry
setproperty!(g, :column_homogeneous, true) # setproperty!(g,:homogeoneous,true) for gtk2
setproperty!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, g)

function on_return_terminal(widget::GtkEntry)

  cmd = getproperty(widget,:text,String)
  pastcmd[1] = cmd
  ex = Base.parse_input_line(cmd)
  ex = expand(ex)

  setproperty!(widget,:text,"")

  evalout = ""
  value = :()
  @async begin

    (outRead, outWrite) = redirect_stdout()#capture console prints

    try
      value = eval(Main,ex)
      eval(Main, :(ans = $(Expr(:quote, value))))
      evalout = sprint(Base.showlimited,value)
    catch err
      evalout = "$err"
    end

    txt  = getproperty(buffer,:text,String)

    close(outWrite)
    std_data = readavailable(outRead)
    close(outRead)

    #setproperty!(buffer,:text,string(txt,"\n>",cmd,"\n",s,"\n",std_data))
    setproperty!(buffer,:text,
"$txt
>$cmd
$evalout
$std_data
")



  end

end

function text_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
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
signal_connect(text_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false, ())

## scroll textview
function scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)
  setproperty!(adj,:value, getproperty(adj,:upper,FloatingPoint) - getproperty(adj,:page_size,FloatingPoint))
  nothing
end
signal_connect(scroll_cb, textview, "size-allocate", Void, (Ptr{Gtk.GdkRectangle},), false, ())

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

  return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false, ())


showall(win)
