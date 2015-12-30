
include(joinpath(Pkg.dir(),"GtkIDE","src","GtkIDE.jl"))

##

sleep_time = 0.5
sleep(0.5)#time for loading
open_in_new_tab("test/testfile.jl")
sleep(0.5)#time for loading

t = get_current_tab()
buffer = t.buffer
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
function _test_completion_232_(x::Int,y::Float64)
end

goto_line(buffer,1)
    sleep(sleep_time)
run_line(buffer)
    sleep(sleep_time)

@assert x == 2

goto_line(buffer,2)
to_line_end(buffer)
editor_autocomplete(t.view)
sleep(0.1)

(txt,its,ite) = get_line_text(buffer, get_text_iter_at_cursor(buffer) )

@assert txt == "_test_completion_232_"

sleep(sleep_time)
close_tab()



##
