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
global style = style_scheme(@GtkSourceStyleSchemeManager(),"autumn")
global languageDefinitions = Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}()
languageDefinitions[".jl"] = GtkSourceWidget.language(@GtkSourceLanguageManager(),"julia")
languageDefinitions[".md"] = GtkSourceWidget.language(@GtkSourceLanguageManager(),"markdown")
global fontsize = 13

fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
    font-family: Consolas, Courier, monospace;
    font-size: $(fontsize)
}"""
global provider = GtkStyleProvider( GtkCssProviderFromData(data=fontCss) )


#Order matters
include("Project.jl")
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

win = @GtkWindow("Julia IDE",1800,1200) |>
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
    ((editorVBox = @GtkBox(:v)) |>
        ((editorBox = @GtkBox(:h)) |>
            ntbook |>
            sourcemap
        ) |>
        search_window
    )

##setproperty!(ntbook, :width_request, 800)

setproperty!(ntbook,:vexpand,true)
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

    @show project
    if typeof(project) == Project
        save(project)
    end
    return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win)
visible(search_window,false)

function window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == keyval("r") && Int(event.state) == 4 #this often crashes
    end

    return Cint(false)
end
signal_connect(window_key_press_cb,win, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

function restart(new_workspace=false)
    save(project)
    win_ = win
    new_workspace && workspace()
    include("d:\\Julia\\JuliaIDE\\Main.jl")
    destroy(win_)
end

#end#module

#importall J
