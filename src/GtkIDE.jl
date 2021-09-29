#__precompile__()
module GtkIDE

global const HOMEDIR = @__DIR__()
global const REDIRECT_STDOUT = true
pkgdir(pkg::Module) = abspath(joinpath(dirname(Base.pathof(pkg)), ".."))

using Gtk, GtkSourceWidget, GtkUtilities, GtkMarkdownTextView
using Immerse
using GtkREPL
using JSON, ConfParser, Refactoring
using Distributed, REPL, InteractiveUtils, Sockets, Markdown, Pkg
using GtkREPL.GtkTextUtils

import GtkREPL: ConsoleManager, Console, current_console, print_to_console, new_prompt,
worker, add_remote_console_cb, ConsoleCommand, on_command_done, index, style_css, get_tab,
PROPAGATE, INTERRUPT, nonmutable, offset

include("Options.jl")

import Gtk: GtkTextIter, get_default_mod_mask, GdkKeySyms, selected, hasselection, mutable
import Gadfly.Colors
import Immerse: Cairo, Compose

import REPL: REPLCompletions.completions
import Base: push!, search
import Cairo.text

export image, plot, figure, rprint
export GtkREPL, Pkg #This gets called by remote consoles

function method_filename(m)
    tv, decls, file, line = Base.arg_decl_parts(m.ms[1])
    return file, line
end

#export add_console, figure

#Order matters
include("gtk_utils.jl")
include("PlotWindow.jl")
include("StyleAndLanguageManager.jl")
include("MainWindow.jl")
include("Project.jl")
include("Console.jl")
include("ConsoleCommands.jl")
include("Editor.jl")
include("NtbookUtils.jl")
include("PathDisplay.jl")
include("MainMenu.jl")
include("SidePanels.jl")
include(joinpath("sidepanels", "FilesPanel.jl"))
include(joinpath("sidepanels", "WorkspacePanel.jl"))
include(joinpath("sidepanels", "ProjectsPanel.jl"))
include("Logo.jl")

include("init.jl")

#__init__()
end#module
#
