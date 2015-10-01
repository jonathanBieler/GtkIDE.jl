using Gtk
using GtkSourceWidget
using JSON

#module J
#export plot, drawnow

using Winston
import Base.REPLCompletions.completions
include("GtkExtensions.jl"); #using GtkExtenstions

const HOMEDIR = "d:\\Julia\\JuliaIDE\\"
const REDIRECT_STDOUT = false

## more sure antialiasing is working on windows
if OS_NAME == :Windows
    s = Pkg.dir() * "\\WinRPM\\deps\\usr\\x86_64-w64-mingw32\\sys-root\\mingw\\etc\\gtk-3.0\\"
    if isdir(s) && !isfile(s * "settings.ini")
        f = open(s * "settings.ini","w")
        write(f,
"[Settings]
gtk-xft-antialias = 1
gtk-xft-rgba = rgb)")
        close(f)
    end
end

## globals
global style = style_scheme(@GtkSourceStyleSchemeManager(),"zenburn")
global languageDef = GtkSourceWidget.language(@GtkSourceLanguageManager(),"julia")
global fontsize = 13

fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
    font-family: Consolas, Courier, monospace;
    font-size: $(fontsize)
}"""
global provider = GtkStyleProvider( GtkCssProviderFromData(data=fontCss) )


#Order matters
include("Workspace.jl")
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

win = @GtkWindow("Julia IDE",1600,1000) |>
    ((mainVbox = @GtkBox(:v)) |>
        mb |>
        (pathEntry = @GtkEntry()) |>
        (mainPan = @GtkPaned(:h))
    )

mainPan |>
    (rightPan = @GtkPaned(:v) |>
        (canvas = Gtk.@Canvas())  |>
        ((rightBox = @GtkBox(:v)) |>
            console |>
            entry
        )
    ) |>
    ((editorBox = @GtkBox(:h)) |>
        ntbook |>
        sourcemap
    )

##setproperty!(ntbook, :width_request, 800)

setproperty!(editorBox,:expand,ntbook,true)
setproperty!(mainPan,:margin,0)
Gtk.G_.position(mainPan,600)
Gtk.G_.position(rightPan,400)
#-

sc = Gtk.G_.style_context(entry)
push!(sc, provider, 600)
sc = Gtk.G_.style_context(pathEntry)
push!(sc, provider, 600)
sc = Gtk.G_.style_context(textview)
push!(sc, provider, 600)

## the current path is shown in an entry on top
setproperty!(pathEntry, :widht_request, 600)
update_pathEntry() = setproperty!(pathEntry, :text, pwd())
update_pathEntry()

function pathEntry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == Gtk.GdkKeySyms.Return
        cd(getproperty(widget,:text,AbstractString))
        write(console,getproperty(widget,:text,AbstractString) * "\n")
    end

    return convert(Cint,false)
end
signal_connect(pathEntry_key_press_cb, pathEntry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)


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


function restart()
    win_ = win
    include("d:\\Julia\\JuliaIDE\\Main.jl")
    destroy(win_)
end

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
        #println(string(ex.args[1].args[1]))
    elseif ex.head == :call && ex.args[1] == :signal_connect
        eval(Main,ex)
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

#end#module

#importall J
