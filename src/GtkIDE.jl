using Winston
#this need to run before gtk
if Winston.output_surface != :gtk
    #could do that automatically?
    pth = joinpath(Pkg.dir(),"Winston","src")

    warn("Patching Winston.ini")
    sleep(0.5)
    pth = joinpath(Pkg.dir(),"Winston","src","Winston.ini")
    try
        f = open(pth,"r")
        s = readall(f)
        s = replace(s, r"output_surface          = tk",
                        "output_surface          = gtk")
        close(f)

        f = open(pth,"w")
        write(f,s)
        close(f)
    catch err
        warning("failed to patch Winston")
        close(f)
        rethrow(err)
    end
    error("Winston has been patched. Type workspace() and restart GtkIDE.")
end

using Gtk
using GtkSourceWidget
using JSON

#module G
#export plot, drawnow

import Base.REPLCompletions.completions
include("GtkExtensions.jl"); #using GtkExtenstions

const HOMEDIR = joinpath(Pkg.dir(),"GtkIDE","src")
const REDIRECT_STDOUT = true

## globals
sourceStyleManager = @GtkSourceStyleSchemeManager()
GtkSourceWidget.set_search_path(sourceStyleManager,
  Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/styles/",C_NULL])

global style = style_scheme(sourceStyleManager,"autumn")

@linux_only begin
    global style = style_scheme(sourceStyleManager,"tango")
end

global languageDefinitions = Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}()
sourceLanguageManager = @GtkSourceLanguageManager()
GtkSourceWidget.set_search_path(sourceLanguageManager,
  Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/language-specs/",C_NULL])
languageDefinitions[".jl"] = GtkSourceWidget.language(sourceLanguageManager,"julia")
languageDefinitions[".md"] = GtkSourceWidget.language(sourceLanguageManager,"markdown")

@windows_only begin
    global fontsize = 13
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Consolas, Courier, monospace;
        font-size: $(fontsize)
    }"""
end
@osx_only begin
    global fontsize = 13
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Monaco, Consolas, Courier, monospace;
        font-size: $(fontsize)
    }"""
end
@linux_only begin
    global fontsize = 12
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Consolas, Courier, monospace;
        font-size: $(fontsize)
    }"""
end

global provider = GtkStyleProvider( GtkCssProviderFromData(data=fontCss) )

#Order matters
include("Project.jl")
include("Console.jl")
include("Editor.jl")

if sourcemap == nothing
    sourcemap = @GtkBox(:v)
end

##
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
            console.entry
        )
    ) |>
    ((editorVBox = @GtkBox(:v)) |>
        ((editorBox = @GtkBox(:h)) |>
            ntbook |>
            sourcemap
        ) |>
        search_window
    )

#FIXME is right left?
##setproperty!(ntbook, :width_request, 800)

setproperty!(ntbook,:vexpand,true)
setproperty!(editorBox,:expand,ntbook,true)
setproperty!(mainPan,:margin,0)
Gtk.G_.position(mainPan,600)
Gtk.G_.position(rightPan,450)
#-

sc = Gtk.G_.style_context(console.entry)
push!(sc, provider, 600)
sc = Gtk.G_.style_context(pathEntry)
push!(sc, provider, 600)
sc = Gtk.G_.style_context(console.view)
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
if true
if !Winston.hasfig(Winston._display,1)
    Winston.ghf()
    Winston.addfig(Winston._display, 1, Winston.Figure(canvas,Winston._pwinston))
else
    Winston._display.figs[1] = Winston.Figure(canvas,Winston._pwinston)
end

#replace plot with a version that display the plot
import Winston.plot
plot(args::Winston.PlotArg...; kvs...) = Winston.display(Winston.plot(Winston.ghf(), args...; kvs...))
end
drawnow() = sleep(0.001)

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

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

    if event.keyval == keyval("r") && Int(event.state) == GdkModifierType.CONTROL
        @schedule begin
            #crashes if we are still in the callback
            sleep(0.2)
            eval(Main,:(restart()))
        end
    end

    return Cint(false)
end
signal_connect(window_key_press_cb,win, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
##
function restart(new_workspace=false)

    #@schedule begin
        println("restarting...")
        sleep(0.1)
        wait(console)
        lock(console)
        REDIRECT_STDOUT && stop_console_redirect(console_redirect,stdout,stderr)
        unlock(console)
        println("stdout freed")

        save(project)
        win_ = win

        new_workspace && workspace()
        include( joinpath(HOMEDIR,"GtkIDE.jl") )
        destroy(win_)
    #end

end

function run_tests()
    include( joinpath(Pkg.dir(),"GtkIDE","test","runtests.jl") )
end

@schedule begin
    th = linspace(0,8*π,500)
    for i = 1:500

        #p = text(-1,0.6, "GtkIDE.jl")

        plot( sin(1*th*1/10+i/200).*cos((1+i/1000)*th),exp(-th/12).*sin(th),
            xrange=(-1.1,1.1),
            yrange=(-0.75,0.95)
        )
        drawnow()
    end
end

##

#end#module

#importall G