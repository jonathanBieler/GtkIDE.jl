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
menubar = @GtkMenuBar() |>
    (file = @GtkMenuItem("_File"))

filemenu = @GtkMenu(file) |>
    (newMenuItem = @GtkMenuItem("New")) |>
    (openMenuItem = @GtkMenuItem("Open")) |>
    @GtkSeparatorMenuItem() |>
    (quitMenuItem = @GtkMenuItem("Quit"))

win = @GtkWindow("Julia IDE",1800,1200) |>
    ((mainVbox = @GtkBox(:v)) |>
        menubar |>
        (topBarBox = @GtkBox(:h) |>
            (sidePanelButton = @GtkButton("F1")) |>
            (pathEntry = @GtkEntry()) |>
            (editorButton = @GtkButton("F2"))
        ) |>
        (sidePan = @GtkPaned(:h))
    )

(mainPan = @GtkPaned(:h)) |>
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

sidePan |>
    (sidepanel_ntbook = @GtkNotebook()) |>
    mainPan

#FIXME is right left?
##setproperty!(ntbook, :width_request, 800)

include("SidePanels.jl")
Gtk.G_.position(sidePan,160)

setproperty!(ntbook,:vexpand,true)
setproperty!(editorBox,:expand,ntbook,true)
setproperty!(mainPan,:margin,0)
Gtk.G_.position(mainPan,600)
Gtk.G_.position(rightPan,450)
#-

setproperty!(topBarBox,:hexpand,true)
setproperty!(pathEntry,:hexpand,true)

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
        pth = getproperty(widget,:text,AbstractString)
        try 
            cd(pth)
            
        catch err
            write(console,string(err) * "\n")
        end
        on_path_change()
    end

    return convert(Cint,false)
end
signal_connect(pathEntry_key_press_cb, pathEntry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

################
## MENU THINGS

function quitMenuItem_activate_cb(widgetptr::Ptr, user_data)
    #widget = convert(GtkMenuItem, widgetptr)
    destroy(win)
    return nothing
end
signal_connect(quitMenuItem_activate_cb, quitMenuItem, "activate", Void, (), false)

function newMenuItem_activate_cb(widgetptr::Ptr, user_data)
    add_tab()
    save(project)##FIXME this souldn't be here
    return nothing
end
signal_connect(newMenuItem_activate_cb, newMenuItem, "activate", Void, (), false)

function openMenuItem_activate_cb(widgetptr::Ptr, user_data)
    f = open_dialog("Pick a file", win, ("*.jl","*.md"))
    if isfile(f)
        open_in_new_tab(f)
    end
    return nothing
end
signal_connect(openMenuItem_activate_cb, openMenuItem, "activate", Void, (), false)


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
    REDIRECT_STDOUT && stop_console_redirect(console_redirect,stdout,stderr)
    return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win)
visible(search_window,false)
visible(sidepanel_ntbook,false)

function toggle_sidepanel()
    visible(sidepanel_ntbook,!visible(sidepanel_ntbook))
end

function toggle_editor()#use visible ?
    if Gtk.G_.position(mainPan) > 0
        mainPanPos = Gtk.G_.position(mainPan)
        Gtk.G_.position(mainPan,0)
    else
        Gtk.G_.position(mainPan,650) #FIXME need a layout type to save all these things
    end
end

function window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == keyval("r") && Int(event.state) == PrimaryModifier
        @schedule begin
            #crashes if we are still in the callback
            sleep(0.2)
            eval(Main,:(restart()))
        end
    end
    if event.keyval == Gtk.GdkKeySyms.F1
      toggle_sidepanel()
    end
    if event.keyval == Gtk.GdkKeySyms.F2
        toggle_editor()
    end

    return Cint(false)
end
signal_connect(window_key_press_cb,win, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

function sidePanelButton_clicked_cb(widgetptr::Ptr, user_data)
    toggle_sidepanel()
    return nothing
end
signal_connect(sidePanelButton_clicked_cb, sidePanelButton, "clicked", Void, (), false)

function editorButtonclicked_cb(widgetptr::Ptr, user_data)
    toggle_editor()
    return nothing
end
signal_connect(editorButtonclicked_cb, editorButton, "clicked", Void, (), false)

function on_path_change()

    update_pathEntry()
    update!(filespanel)
end

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

# @schedule begin
#     th = linspace(0,8*π,500)
#     for i = 1:500
#
#         #p = text(-1,0.6, "GtkIDE.jl")
#
#         plot( sin(1*th*1/10+i/200).*cos((1+i/1000)*th),exp(-th/12).*sin(th),
#             xrange=(-1.1,1.1),
#             yrange=(-0.75,0.95)
#         )
#         drawnow()
#     end
# end

##

#end#module

#importall G
