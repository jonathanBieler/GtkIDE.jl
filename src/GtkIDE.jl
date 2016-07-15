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
using ConfParser
include("GtkExtensions.jl"); #using GtkExtenstions
include("Options.jl")

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
import Cairo.text

#export add_console, figure

#Order matters
include("NtbookUtils.jl")
include("MenuUtils.jl")
include("WordUtils.jl")
include("PlotWindow.jl")
include("Project.jl")
include("CommandHistory.jl")
include("Console.jl")
include("Editor.jl")
include("PathDisplay.jl")
include("MainMenu.jl")
include("SidePanels.jl")
include("MainWindow.jl")

include("init.jl")

#end#module
