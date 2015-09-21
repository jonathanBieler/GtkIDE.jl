## SETUP

entry = @GtkEntry()
setproperty!(entry, :text, "x = rand(100,1)");

buffer = @GtkSourceBuffer()
setproperty!(buffer,:text,"")

tag = Gtk.create_tag(buffer, "error", font="Normal 16")
setproperty!(tag,:foreground,"gray")
Gtk.apply_tag(buffer, "error", Gtk.GtkTextIter(buffer,1) , Gtk.GtkTextIter(buffer,23) )

Gtk.create_tag(buffer, "cursor", font="Normal $fontsize",foreground="green")
Gtk.create_tag(buffer, "plaintext", font="Normal $fontsize")

textview = @GtkSourceView()
setproperty!(textview,:buffer, buffer)
setproperty!(textview,:editable, false)
setproperty!(textview,:can_focus, false)
setproperty!(textview,:vexpand, true)

console_scwindow = @GtkScrolledWindow()
setproperty!(console_scwindow,:height_request, 100)
push!(console_scwindow,textview)
adj = getproperty(console_scwindow,:vadjustment, GtkAdjustment)


## Callbacks
# function my_println(xs)
#   insert!(buffer,string(xs))
#   nothing
# end
# my_println() = nothing
#
# import Base.println
# println(xs...) = my_println(xs...)
# import Base.print
# print(xs...) = my_println(xs...)

function print_std_out(rd::Base.PipeEndpoint,buffer::GtkTextBuffer)
    response = readavailable(rd)
    if !isempty(response)
        insert!(buffer,bytestring(response))
    end
end
function watch_redirect(buffer::GtkTextBuffer)
    rd, wr = redirect_stdout()
    while(true)
        print_std_out(rd,buffer)
    end
end
#remotecall(1,watch_redirect,buffer)#too slow

type HistoryProvider
    history::Array{String,1}
    history_file
    cur_idx::Int
    last_idx::Int
    HistoryProvider() = new(String[""],nothing,0,0)
    HistoryProvider(h::Array{AbstractString,1},hf,cidx::Int,lidx::Int) = new(h,hf,cidx,lidx)
end

function setup_history()
    #load history, etc
    h = HistoryProvider(String["x = pi"],nothing,1,1)
end
function history_add(h::HistoryProvider, str::String)
    isempty(strip(str)) && return
    push!(h.history, str)
    h.history_file === nothing && return
end
function history_move(h::HistoryProvider,m::Int)
    h.cur_idx = clamp(h.cur_idx+m,1,length(h.history)+1) #+1 is the empty state when we are at the end of history and press down
end
history_get_current(h::HistoryProvider) = h.cur_idx == length(h.history)+1 ? "" : h.history[h.cur_idx]
function history_seek_end(h::HistoryProvider)
    h.cur_idx = length(h.history)+1
end

history = setup_history()

function clear_entry()
    setproperty!(entry,:text,"")
end

function check_special_commands(cmd::String)

    #case :(
    if cmd == ""
      insert!(buffer,"\n")
      return true
    end
    if cmd == "clc"
      setproperty!(buffer,:text,"")
      clear_entry()
      return true
    end
    if cmd == "reload"
        re()
        clear_entry()
      return true
    end

    return false
end

function on_return_terminal(widget::GtkEntry,cmd::String,doClear)

    history_add(history,cmd)
    history_seek_end(history)

    cmd = strip(cmd)
    check_special_commands(cmd) && return

    pos_start = length(buffer)+1
    insert!(buffer,">julia $cmd")

    Gtk.apply_tag(buffer, "cursor", Gtk.GtkTextIter(buffer,pos_start) , Gtk.GtkTextIter(buffer,pos_start+7) )
    Gtk.apply_tag(buffer, "plaintext", Gtk.GtkTextIter(buffer,1),Gtk.GtkTextIter(buffer,length(buffer)+1) )

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
$evalout
$std_data";
    insert!(buffer,finalOutput)

    Gtk.apply_tag(buffer, "plaintext", Gtk.GtkTextIter(buffer,1),Gtk.GtkTextIter(buffer,length(buffer)+1) )

    end
end

clip = @GtkClipboard()

text_buffer_copy_clipboard(buffer::GtkTextBuffer,clip::GtkClipboard)  = ccall((:gtk_text_buffer_copy_clipboard,  Gtk.libgtk),Void,
    (Ptr{GObject},Ptr{GObject}),buffer,clip)

function entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if Int(event.keyval) == 99 && Int(event.state) == 4 #ctrl+c
        text_buffer_copy_clipboard(buffer,clip)
    end

    if event.keyval == Gtk.GdkKeySyms.Return
        cmd = getproperty(widget,:text,String)
        on_return_terminal(widget,cmd,true)
    end

    if event.keyval == Gtk.GdkKeySyms.Up

        history_move(history,-1)
        setproperty!(widget,:text,history_get_current(history))

        return convert(Cint,true)
    end
    if event.keyval == Gtk.GdkKeySyms.Down

        history_move(history,+1)
        setproperty!(widget,:text,history_get_current(history))
        return convert(Cint,true)
    end

  if event.keyval == Gtk.GdkKeySyms.Tab
    cmd = getproperty(widget,:text,String)

    (comp,dotpos) = completions(cmd, endof(cmd))
    show_completions(comp,dotpos,widget,cmd)

    return convert(Cint,true)
  end

  return convert(Cint,false)
end
signal_connect(entry_key_press_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

#print completions in console (maye use the one in Base?)
function show_completions(comp,dotpos,widget,cmd)
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
    set_position!(widget,endof(out))

  elseif !isempty(comp)
    out = prefix * comp[1]
    setproperty!(widget,:text,out)
    set_position!(widget,endof(out))
  end
end

function set_position!(editable::Gtk.Entry,position_)
    ccall((:gtk_editable_set_position,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),editable,position_)
end

## scroll textview
function scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)
  setproperty!(adj,:value, getproperty(adj,:upper,FloatingPoint) - getproperty(adj,:page_size,FloatingPoint))
  nothing
end
signal_connect(scroll_cb, textview, "size-allocate", Void, (Ptr{Gtk.GdkRectangle},), false)
