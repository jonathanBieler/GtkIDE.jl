if(myid()!=1)
    error("GtkIDE need to run on the first worker")
end

#module GtkIDE

const HOMEDIR = joinpath(Pkg.dir(),"GtkIDE","src")
const REDIRECT_STDOUT = true

using Immerse
using Gtk
using GtkSourceWidget
using GtkUtilities
using JSON
using Compat
include("GtkExtensions.jl"); #using GtkExtenstions

# Compatitbily with 0.5
if !isdefined(Base,:(showlimited))
    showlimited(x) = show(x)
    showlimited(io::IO,x) = show(io,x)
else
    import Base.showlimited
end
if !GtkSourceWidget.SOURCE_MAP
    macro GtkSourceMap() end
    type GtkSourceMap end
end

import Base.REPLCompletions.completions

## globals
const is_running = true #should probably use g_main_loop_is_running or something of the sort

sourceStyleManager = @GtkSourceStyleSchemeManager()
GtkSourceWidget.set_search_path(sourceStyleManager,
  Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/styles/",C_NULL])


const languageDefinitions = Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}()
sourceLanguageManager = @GtkSourceLanguageManager()
GtkSourceWidget.set_search_path(sourceLanguageManager,
  Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/language-specs/",C_NULL])
languageDefinitions[".jl"] = GtkSourceWidget.language(sourceLanguageManager,"julia")
languageDefinitions[".md"] = GtkSourceWidget.language(sourceLanguageManager,"markdown")

@windows_only begin
    const style = style_scheme(sourceStyleManager,"autumn")
    global fontsize = 13
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Consolas, Courier, monospace;
        font-size: $(fontsize)
    }"""
end
@osx_only begin
    const style = style_scheme(sourceStyleManager,"autumn")
    global fontsize = 13
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Monaco, Consolas, Courier, monospace;
        font-size: $(fontsize);
    }"""
end
@linux_only begin
    const style = style_scheme(sourceStyleManager,"tango")
    global fontsize = 12
    fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
        font-family: Consolas, Courier, monospace;
        font-size: $(fontsize)
    }"""
end

const provider = GtkStyleProvider( GtkCssProviderFromData(data=fontCss) )

#Order matters
include("NtbookUtils.jl")
include("MenuUtils.jl")
include("PlotWindow.jl")
include("Project.jl")
include("Console.jl")
include("Editor.jl")
include("PathDisplay.jl")

GtkIconThemeAddResourcePath(GtkIconThemeGetDefault(), joinpath(HOMEDIR,"../icons/"))

##
menubar = @GtkMenuBar() |>
    (file = @GtkMenuItem("_File"))

filemenu = @GtkMenu(file) |>
    (newMenuItem = @GtkMenuItem("New")) |>
    (openMenuItem = @GtkMenuItem("Open")) |>
    @GtkSeparatorMenuItem() |>
    (quitMenuItem = @GtkMenuItem("Quit"))

win = @GtkWindow("GtkIDE.jl",1800,1200) |>
    ((mainVbox = @GtkBox(:v)) |>
        menubar |>
        (topBarBox = @GtkBox(:h) |>
            (sidePanelButton = @GtkButton("F1")) |>
             pathCBox   |>
            (editorButton = @GtkButton("F2"))
        ) |>
        (sidePan = @GtkPaned(:h)) |>
        (statusBar = @GtkStatusbar())
    )

(mainPan = @GtkPaned(:h)) |>
    (rightPan = @GtkPaned(:v) |>
        #(canvas = @GtkCanvas())  |>
        (fig_ntbook)  |>
        console_ntkbook
    ) |>
    ((editorVBox = @GtkBox(:v)) |>
        ((editorBox = @GtkBox(:h)) |>
            editor |>
            editor.sourcemap
        ) |>
        search_window
    )

sidePan |>
    (sidepanel_ntbook = @GtkNotebook()) |>
    mainPan

include("SidePanels.jl")

setproperty!(statusBar,:margin,2)

sbidx = Gtk.context_id(statusBar, "context")
push!(statusBar,sbidx,"Julia $VERSION")

Gtk.G_.position(sidePan,160)

setproperty!(editor,:vexpand,true)
setproperty!(editorBox,:expand,editor,true)
setproperty!(mainPan,:margin,0)
Gtk.G_.position(mainPan,600)
Gtk.G_.position(rightPan,450)
#-

setproperty!(topBarBox,:hexpand,true)

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
    openfile_dialog()
    return nothing
end
signal_connect(openMenuItem_activate_cb, openMenuItem, "activate", Void, (), false)


################
## Plots

figure()
drawnow() = sleep(0.001)

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    if typeof(project) == Project
        save(project)
    end
    #REDIRECT_STDOUT && stop_console_redirect(watch_stdio_tastk,stdout,stderr)
    global is_running = false

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

    mod = get_default_mod_mask()

    if doing(Action("r",PrimaryModifier),event)
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
    c_path = bytestring(Gtk.G_.active_text(pathCBox))
    update_pathEntry()
    if pwd() != c_path
        push!(pathCBox,pwd())
        update!(filespanel)
    end
end

init(pathCBox)#need on_path_change to be defined

##
function restart(new_workspace=false)

    #@schedule begin
        println("restarting...")
        sleep(0.1)
        is_running = false

        REDIRECT_STDOUT && stop_console_redirect(watch_stdout_tastk,stdout,stderr)

        update!(project)
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

#end#module
