using Gtk
using GtkSourceWidget

#module J
#export plot, drawnow

using Gtk
using GtkSourceWidget
using Winston
import Base.REPLCompletions.completions

pastcmd = [""];

#globals
sm = @GtkSourceStyleSchemeManager()
style = style_scheme(sm,"zenburn")
languageDef = GtkSourceWidget.language(@GtkSourceLanguageManager(),"julia")
fontsize = 13

#Order might matter
include("GtkExtensions.jl")
include("Console.jl")
include("Editor.jl")

#-
mb = @GtkMenuBar() |>
    (file = @GtkMenuItem("_File"))

filemenu = @GtkMenu(file) |>
    (new_ = @GtkMenuItem("New")) |>
    (open_ = @GtkMenuItem("Open")) |>
    @GtkSeparatorMenuItem() |>
    (quit = @GtkMenuItem("Quit"))

win = @GtkWindow("Julia IDE",1400,900) |>
    ((mainVbox = @GtkBox(:v)) |>
        mb |>
        (mainPan = @GtkPaned(:h))
    )

mainPan |>
    (rightPan = @GtkPaned(:v) |>
        (canvas = Gtk.@Canvas())  |>
        ((rightBox = @GtkBox(:v)) |>
            (consoleFrame = @GtkFrame("") |>
                console_scwindow
            ) |>
            entry
        )
    ) |>
    ntbook

setproperty!(rightPan, :width_request, 600)
setproperty!(canvas,:height_request, 500)
setproperty!(mainPan,:margin,5)
#-

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

drawnow() = sleep(0.001) #probably not the ideal way of doing it

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

  return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win);

function window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == keyval("r") && Int(event.state) == 4 #this often crashes
    end

    return Cint(false)
end
signal_connect(window_key_press_cb,win, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

## reloading functions stuff
function parseall(str)
    pos = start(str)
    exs = []
    while !done(str, pos)
        ex, pos = parse(str, pos)
        push!(exs, ex)
    end
    if length(exs) == 0
        throw(ParseError("end of input"))
    elseif length(exs) == 1
        return exs[1]
    else
        return Expr(:block, exs...)
    end
end

function re()
    files = ["Main.jl","Editor.jl","Console.jl"]
    for f in files re(f) end
    update_cb()
end
function re(filename::String)
    s = open("d:\\Julia\\JuliaIDE\\" * filename) do io
         readall(io)
    end
    ex = parseall(s)
    reloadfunc(ex.args)
end
function reloadfunc(ex::Array{Any,1})
    for e in ex
        reloadfunc(e)
    end
end
function reloadfunc(ex::Expr)
    if ex.head == :function
        eval(Main,ex)
        println(string(ex.args[1].args[1]))
    elseif ex.head == :call && ex.args[1] == :signal_connect
        #eval(Main,ex)
    else
        reloadfunc(ex.args)
    end
end
reloadfunc(s) = nothing
function update_cb()
    #just update the current tab
    t = get_current_tab()
    signal_connect(tab_key_press_cb,t.view , "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
    nothing
end

#end

#importall J
