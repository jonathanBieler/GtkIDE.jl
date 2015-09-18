using Gtk
using GtkSourceWidget

module J

export plot, drawnow

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

drawnow() = sleep(1e-16) #probably not the ideal way of doing it

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

  return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win);

end

importall J
