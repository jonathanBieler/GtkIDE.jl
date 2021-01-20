using GtkIDE
using Test, Gtk

###############
## EDITOR

sleep_time = 0.5

function _test_completion_232_(x::Int64, y::Float64)
end

@testset "Editor" begin

main_window = GtkIDE.main_window
editor = main_window.editor
console = GtkIDE.current_console(main_window)

cd(joinpath(GtkIDE.HOMEDIR,".."))
GtkIDE.update_pathEntry(main_window.pathCBox,pwd())

sleep(sleep_time)#time for loading
GtkIDE.open_in_new_tab(joinpath("test","testfile.jl"),main_window.editor)
sleep(sleep_time)#time for loading

t = GtkIDE.current_tab(editor)
b = t.buffer
#some helper functions
function goto_line(buffer::GtkIDE.GtkTextBuffer,line::Integer)
    it = GtkIDE.mutable( GtkIDE.GtkTextIter(buffer,1) )
    GtkIDE.set_gtk_property!(it,:line,line-1)
    GtkIDE.place_cursor(buffer,it)
end
function to_line_end(buffer::GtkIDE.GtkTextBuffer)
    it = GtkIDE.mutable( GtkIDE.get_text_iter_at_cursor(buffer) )
    skip(it,:forward_to_line_end)
    GtkIDE.place_cursor(buffer,it)
end

goto_line(b,1)
    sleep(sleep_time)
GtkIDE.run_line(console, t)
    sleep(sleep_time)

@test x == 2

goto_line(b,2)
to_line_end(b)
GtkIDE.init_autocomplete(t.view,t)
sleep(0.5)

(txt,its,ite) = GtkIDE.get_line_text(b, GtkIDE.get_text_iter_at_cursor(b) )

@test txt == "_test_completion_232_"

sleep(sleep_time)
t = GtkIDE.current_tab(editor)
t.modified = false
GtkIDE.close_tab(editor)

end

###############
## CONSOLE

@testset "Console" begin

import GtkIDE.GtkREPL.command

main_window = GtkIDE.main_window
console = GtkIDE.current_console(main_window)

#stress test printing
function printtest(k)
    for i=1:5
        @show k
        println(rand(3))
        sleep(rand()/10001)
    end
end

for i=1:3
    global t = @async printtest(i)
end

wait(t)
sleep(sleep_time)

##

#don't know how to get the hardware_keycode
function emit_keypress(w)

    keyevent = Gtk.GdkEventKey(Gtk.GdkEventType.KEY_PRESS, Gtk.gdk_window(w),
               Int8(0), UInt32(0), UInt32(0), GdkKeySyms.Return, UInt32(0),
               convert(Ptr{UInt8},C_NULL), UInt16(13), UInt8(0), UInt32(0) )

    signal_emit(w, "key-press-event", Bool, keyevent)
end

command(console,"x = 3")
    sleep(sleep_time)
emit_keypress(console.view)
    sleep(sleep_time)
@test x == 3

command(console,"_test_completion_")
    sleep(sleep_time)   
cmd = command(console)
    sleep(sleep_time)
GtkIDE.GtkREPL.autocomplete(console,cmd, length(cmd))
    sleep(sleep_time)

@test command(console) == "_test_completion_232_"

cmd = command(console)
command(console, cmd * "(")
cmd = command(console)
    sleep(sleep_time)
GtkIDE.GtkREPL.autocomplete(console,cmd, length(cmd))
    sleep(sleep_time)

@test startswith(command(console), "_test_completion_232_(x::Int64, y::Float64)")

command(console,"clc")
    sleep(sleep_time)
emit_keypress(console.view)
    sleep(sleep_time)

end

##
