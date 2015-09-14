using Gtk
using Winston
import Base.REPLCompletions.completions

pastcmd = [""];

file = @GtkMenuItem("_File")

filemenu = @GtkMenu(file)
new_ = @GtkMenuItem("New")
push!(filemenu, new_)
open_ = @GtkMenuItem("Open")
push!(filemenu, open_)
push!(filemenu, @GtkSeparatorMenuItem())
quit = @GtkMenuItem("Quit")
push!(filemenu, quit)

mb = @GtkMenuBar()
push!(mb, file)  # notice this is the "File" item, not filemenu

win = @GtkWindow("Julia IDE")
#setproperty!(win, :width_request, 1400)
#setproperty!(win, :height_request, 900)
resize!(win,1400,900)
fontsize = 11

canvas = Gtk.@Canvas()
setproperty!(canvas,:height_request, 500)

#Order might matter
include("Console.jl")
include("Editor.jl")

##SETUP ALL WIDGETS
g = @GtkGrid()

rightPan = @GtkPaned(:v)
mainPan = @GtkPaned(:h)
rightBox = @GtkBox(:v)
mainVbox = @GtkBox(:v)
consoleFrame = @GtkFrame("")
push!(consoleFrame,scwindow)

setproperty!(rightPan, :width_request, 600)

push!(rightBox,consoleFrame)
push!(rightBox,entry)

rightPan[1] = canvas
rightPan[2] = rightBox

mainPan[1] = rightPan
mainPan[2] = ntbook

push!(mainVbox,mb)
push!(mainVbox,mainPan)

#g[1] = mainPan

#g[1,1] = rightPan
#g[2,1] = ntbook
setproperty!(g, :column_homogeneous, true) # setproperty!(g,:homogeoneous,true) for gtk2
setproperty!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
push!(win, mainVbox)

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

## exiting
function quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

  return convert(Cint,false)
end
signal_connect(quit_cb, win, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

showall(win);
