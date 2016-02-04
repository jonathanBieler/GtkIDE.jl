# GtkIDE.jl
GtkIDE.jl is a [Gtk-based](https://github.com/JuliaLang/Gtk.jl) IDE for [Julia](https://github.com/JuliaLang/julia) written in Julia. It includes a terminal, a plotting window and an editor.

![screenshot](data/GtkIDE.png)

## Installation


1. Install [GtkSourceWidget.jl](https://github.com/jonathanBieler/GtkSourceWidget.jl)

    `Pkg.clone("https://github.com/jonathanBieler/GtkSourceWidget.jl.git")`
    
2. Install the package

    `Pkg.clone("https://github.com/jonathanBieler/GtkIDE.jl.git")`
    
3. Run it

    `using GtkIDE`
    
## Usage

**Warning:** make sure to backup or commit your work before editing files, as a crash could 
wipe them out.

### Opening files

Use cd, ls, pwd to navigate in the console, and type `edit filename` to open a file. 
If `filename` does not exists it will be created instead. 

See [ConsoleCommands.jl](src/ConsoleCommands.jl) for a list of console commands.

### Running code

- `F5`: Include the current file
- `Ctrl+Return`: Run selected code, or run code between two `## ' (like Matlab's code sections).
- `Ctrl+Shift+Return`: Run selected code, or run current line.

### Shortcuts

In the editor :

- `Ctrl+D` when the cursor is above a word will show you some info on it.
- `Ctrl+Click`on a method will jump to its first definition.

See [Actions.jl](src/Actions.jl)

### Issues

- Prints and error outputs are a bit buggy.
- Random crashes.
- Too many issues to list.
