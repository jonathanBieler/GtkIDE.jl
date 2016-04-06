
#include(joinpath(Pkg.dir(),"GtkIDE","src","GtkIDE.jl"))

###############
## NON-GUI

d =  ["g","ge","get","get(","α","","","α","αw","αw_","αw_1",""]
txt_ = "get(α +αw_1)"
for k = 1:length(d)
    txt = SolidString(txt_,k)
    i,j = select_word_backward(k,txt,false)
    @assert txt[i:j] == d[k]
end

###############
## EDITOR

cd(joinpath(Pkg.dir(),"GtkIDE"))
update_pathEntry()

sleep_time = 0.2
sleep(0.5)#time for loading
open_in_new_tab(joinpath("test","testfile.jl"))
sleep(0.5)#time for loading

t = get_current_tab()
b = t.buffer
#some helper functions
function goto_line(buffer::GtkTextBuffer,line::Integer)
    it = mutable( GtkTextIter(buffer,1) )
    setproperty!(it,:line,line-1)
    text_buffer_place_cursor(buffer,it)
end
function to_line_end(buffer::GtkTextBuffer)
    it = mutable( get_text_iter_at_cursor(buffer) )
    text_iter_forward_to_line_end(it)
    text_buffer_place_cursor(buffer,it)
end
function _test_completion_232_(x::Int64, y::Float64)
end

goto_line(b,1)
    sleep(sleep_time)
run_line(console, b)
    sleep(sleep_time)

@assert x == 2

goto_line(b,2)
to_line_end(b)
editor_autocomplete(t.view,t)
sleep(0.1)

(txt,its,ite) = get_line_text(b, get_text_iter_at_cursor(b) )

@assert txt == "_test_completion_232_"

sleep(sleep_time)
t = get_current_tab()
t.modified = false
close_tab()

###############
## CONSOLE

#stress test printing

function printtest(k)
    for i=1:5
        @show k
        println(rand(3))
        sleep(rand()/10001)
    end
end

for i=1:3
    t = @async printtest(i)
end

wait(t)
sleep(sleep_time)

##

#don't know how to get the hardware_keycode
function emit_keypress(w)

    keyevent = Gtk.GdkEventKey(Gtk.GdkEventType.KEY_PRESS, Gtk.gdk_window(w),
               Int8(0), UInt32(0), UInt32(0), Gtk.GdkKeySyms.Return, UInt32(0),
               convert(Ptr{UInt8},C_NULL), UInt16(13), UInt8(0), UInt32(0) )
   
    signal_emit(w, "key-press-event", Bool, keyevent)
end

prompt(console,"x = 3")
    sleep(sleep_time)
emit_keypress(console.view)
    sleep(sleep_time)
@assert x == 3

prompt(console,"_test_completion_")
cmd = prompt(console)
    sleep(sleep_time)
autocomplete(console,cmd, length(cmd))
    sleep(sleep_time)

@assert prompt(console) == "_test_completion_232_"

cmd = prompt(console)
prompt(console, cmd * "(")
cmd = prompt(console)
    sleep(sleep_time)
autocomplete(console,cmd, length(cmd))
    sleep(sleep_time)

@assert prompt(console) == "_test_completion_232_(x::Int64, y::Float64)"

prompt(console,"clc")
    sleep(sleep_time)
emit_keypress(console.view)
    sleep(sleep_time)
    
##
