#__precompile__()
module GtkIDE

global const HOMEDIR = joinpath(Pkg.dir(),"GtkIDE","src")
global const REDIRECT_STDOUT = true
using Reexport
using Immerse
using Gtk
using GtkSourceWidget
using GtkExtensions
using GtkUtilities
using JSON
using Compat
using ConfParser
using WordsUtils
#using RemoteEval
using RemoteGtkIDE

include("Options.jl")
include("MarkdownTextView.jl")

import Gtk.GtkTextIter
import Gadfly.Colors
import Immerse.Cairo

export image, plot, figure, rprint

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

#dirty hack ?
if !isdefined(Base,:MethodList)#0.4
    function method_filename(m)
        tv, decls, file, line = Base.arg_decl_parts(m.defs)
        return file,line
    end
else
    function method_filename(m)
        tv, decls, file, line = Base.arg_decl_parts(m.ms[1])
        return file,line
    end
end

import Base: REPLCompletions.completions, push!, search
import Cairo.text

#export add_console, figure

#Order matters
include("MenuUtils.jl")
include("PlotWindow.jl")
include("StyleAndLanguageManager.jl")
include("MainWindow.jl")
include("Project.jl")
include("ConsoleManager.jl")
include("CommandHistory.jl")
include("Console.jl")
include("Refactoring.jl")
include("Editor.jl")
include("NtbookUtils.jl")
include("PathDisplay.jl")
include("MainMenu.jl")
include("SidePanels.jl")
include("Logo.jl")

include("init.jl")


#__init__()
end#module
#