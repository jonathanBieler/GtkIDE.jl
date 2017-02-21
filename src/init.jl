## globals
global const is_running = true #should probably use g_main_loop_is_running or something of the sort

sourceStyleManager = @GtkSourceStyleSchemeManager()
GtkSourceWidget.set_search_path(sourceStyleManager,
 Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/styles/",C_NULL])

global const languageDefinitions = Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}()
sourceLanguageManager = @GtkSourceLanguageManager()
GtkSourceWidget.set_search_path(sourceLanguageManager,
 Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/language-specs/",C_NULL])
languageDefinitions[".jl"] = GtkSourceWidget.language(sourceLanguageManager,"julia")
languageDefinitions[".md"] = GtkSourceWidget.language(sourceLanguageManager,"markdown")

@static if is_windows()
   global const main_style = style_scheme(sourceStyleManager,"autumn")
   global const fontsize = opt("fontsize")
   fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
       font-family: Consolas, Courier, monospace;
       font-size: $(fontsize)pt;
   }"""
end
@static if is_apple()
   global const main_style = style_scheme(sourceStyleManager,"autumn")
   global const fontsize = opt("fontsize")
   fontCss =  "button, entry, window, sourceview, textview {
       font-family: Monaco, Consolas, Courier, monospace;
       font-size: $(fontsize)pt;
   }"
end

@static if is_linux()
   global const main_style = style_scheme(sourceStyleManager,"tango")
   global const fontsize = opt("fontsize")-1
   fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
       font-family: Consolas, Courier, monospace;
       font-size: $(fontsize)pt;
   }"""
end

global const provider = GtkStyleProvider( GtkCssProviderFromData(data=fontCss) )
GtkIconThemeAddResourcePath(GtkIconThemeGetDefault(), joinpath(HOMEDIR,"../icons/"))


global const main_window = MainWindow()

## Console

global const console_ntkbook = ConsoleManager(main_window)


## Editor

global const editor = Editor(main_window)
init(editor)
load_tabs(editor,project)

init!(main_window,editor,console_ntkbook)

menubar = MainMenu(main_window)

## Main layout

main_window |>
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

# Console

global const console = first_console(main_window)
#add_console()
for i=1:length(free_workers())
    #add_console(main_window)
end

signal_connect(console_ntkbook_button_press_cb,console_ntkbook, "button-press-event",
Cint, (Ptr{Gtk.GdkEvent},),false,main_window)
signal_connect(console_ntkbook_switch_page_cb,console_ntkbook,"switch-page", Void, (Ptr{Gtk.GtkWidget},Int32), false)

setproperty!(statusBar,:margin,2)
text(statusBar,"Julia $VERSION")
Gtk.G_.position(sidePan,160)

setproperty!(editor,:vexpand,true)
setproperty!(editorBox,:expand,editor,true)
setproperty!(mainPan,:margin,0)
Gtk.G_.position(mainPan,600)
Gtk.G_.position(rightPan,450)
#-

setproperty!(topBarBox,:hexpand,true)

################
# Side Panels

form_builder = Gtk.GtkBuilderLeaf(filename=joinpath(HOMEDIR,"forms/forms.glade"))
filespanel = FilesPanel()
update!(filespanel)
add_side_panel(filespanel,"Files")

#=#FIXME I should stop all tasks when exiting
#this can make it crash if it runs while sorting
@schedule begin
    while(false)
        sleep(1.0)
        update!(filespanel)
    end
end=#

workspacepanel = WorkspacePanel()
update!(workspacepanel)
add_side_panel(workspacepanel,"W")

################
## Plots

sleep(0.5)
#figure()
drawnow() = sleep(0.001)

init(pathCBox)#need on_path_change to be defined

signal_connect(sidePanelButton_clicked_cb, sidePanelButton, "clicked", Void, (), false)
signal_connect(editorButtonclicked_cb, editorButton, "clicked", Void, (), false)

showall(main_window)
visible(search_window,false)
visible(sidepanel_ntbook,false)
GtkSourceWidget.SOURCE_MAP && visible(editor.sourcemap,opt("Editor","show_source_map"))

#

sleep(0.5)

if REDIRECT_STDOUT

    stdout = STDOUT
    stderr = STDERR

    read_stdout, wr = redirect_stdout()
    read_stderr, wre = redirect_stderr()

    function watch_stdout()
        @schedule watch_stream(read_stdout,console)
    end
    function watch_stderr()
        @schedule watch_stream(read_stderr,console)
    end

    watch_stdout_tastk = watch_stdout()
    watch_stderr_tastk = watch_stderr()

    g_timeout_add(100,print_to_console,console)
end
