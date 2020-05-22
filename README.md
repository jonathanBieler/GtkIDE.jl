# GtkIDE.jl

[![Build Status](https://travis-ci.org/jonathanBieler/GtkIDE.jl.svg?branch=master)](https://travis-ci.org/jonathanBieler/GtkIDE.jl)

[![Coverage Status](https://coveralls.io/repos/jonathanBieler/GtkIDE.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/jonathanBieler/GtkIDE.jl?branch=master)


GtkIDE.jl is a [Gtk-based](https://github.com/JuliaLang/Gtk.jl) IDE for [Julia](https://github.com/JuliaLang/julia) 1.0 written in Julia. It includes a terminal, a plotting window and an editor.

![screenshot](data/GtkIDE.png)

Demo [video](https://www.youtube.com/watch?v=AbzNUNfwSGc).

## Installation

1. Install the dependencies :

    ```julia
     add Cairo
     add Gadfly
     add https://github.com/jonathanBieler/GtkExtensions.jl.git
     add https://github.com/jonathanBieler/JuliaWordsUtils.jl.git
     add https://github.com/jonathanBieler/GtkTextUtils.jl.git
     add https://github.com/jonathanBieler/RemoteGtkREPL.jl.git
     add https://github.com/jonathanBieler/GtkREPL.jl.git
     add https://github.com/jonathanBieler/GtkIDE.jl.git
     ```

3. Use the package and run the application

    ```
    using GtkIDE
    GtkIDE.run()
    ```

## Usage

**Warning:** make sure to backup or commit your work before editing files, as this editor is
still somewhat experimental.

### Opening files

Use cd, ls, pwd to navigate in the console, and type `edit filename` to open a file.
If `filename` does not exists it will be created instead. You can also use the files panel on the left.

See [ConsoleCommands.jl](src/ConsoleCommands.jl) for a list of console commands.

### Running code

Each console is associated with a Julia worker. The first worker runs GtkIDE, so running
computations that use all the CPU on it will freeze the application. Additional workers/consoles can be via the right-click activated menu.

- `F5`: Include the current file
- `Ctrl+Return`: Run selected code, or run code between two `## ' (like Matlab's code sections).
- `Ctrl+Shift+Return`: Run selected code, or run current line.

The evaluation context of each console can be changed with the `ConsoleCommand` `evalin Module`.
The current context is printed via `evalin ?`.

### Making plots

Currently interactive plots are available via [Immerse.jl](https://github.com/JuliaGraphics/Immerse.jl).
You can create new figures by typing `figure()` into the console (see Immerse documentation).
Immerse uses [Gadfly.jl](https://github.com/dcjones/Gadfly.jl) to create plots.

Since displaying images is slow in Gadly there is also an `Image` widget available.
Use `image(randexp(500,500))` to display a matrix. Zooming on images is handled by Immerse.
Press `r` to reset the zoom.

### Shortcuts

- `Ctrl+§` Switch focus between editor and console.    

In the editor:

- `Ctrl+Shift+D` when the cursor is above a word will show you some info on it.
- `Ctrl+Click`on a method will jump to its first definition.

- `Ctrl+s` Save file.
- `Ctrl+n` New tab.
- `Ctrl+w` Close current tab.

- `Ctrl+c` Copy.
- `Ctrl+v` Paste.
- `Ctrl+x` Cut.

- `Ctrl+k` Delete line.
- `Ctrl+d` Duplicate line.
- `Ctrl+/` Toggle comment.
- `Ctrl+g` Go to line.

- `Alt+e` Move cursor to line end.
- `Alt+a` Move cursor to line start.

- `Ctrl+z` Undo.
- `Ctrl+Shift+z` Redo.

- `Ctrl+f` Search.
- `Ctrl+a` Select all.

- `F3` Autocompletion using the console history as a provider. 

In the console:

- `Alt+x` Interrupt current task.
- `Ctrl+k` Clear console.

See [Actions.jl](src/Actions.jl) for all actions.

### Refactoring

You can create a function for a selected piece of code by pressing `Ctrl+e` and typing the name of the function. GtkIDE will try to guess
the parameters but will fail to do so in some situations.

### Projects

A project is a path and a set of files. You can open and create projects in the project panel
on the left.    

### Misc.

To gain space you can hide elements of the UI, e.g.:

    GtkIDE.visible(GtkIDE.main_window.menubar,false)

### Issues

- Prints and error outputs are a bit buggy.
- No stdin.
- Evaluating in sub-modules doesn't work.
- Random crashes.
- Too many issues to list.
