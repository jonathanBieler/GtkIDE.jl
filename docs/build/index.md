
<a id='documentation'></a>
# Documentation

- [Documentation](index.md#documentation)
    - [Functions](index.md#functions)
    - [Index](index.md#index)

<a id='functions'></a>
## Functions


<a id='Main.clear-Tuple{Any}' href='#Main.clear-Tuple{Any}'>#</a>
**Method**

```
clear(c::Console)

Clear the console.
```

---

<a id='Main.Console' href='#Main.Console'>#</a>
**Type**

```
Console <: GtkScrolledWindow
```

Each `Console` has an associated worker, the first `Console` runs on worker 1 alongside Gtk and printing is handled a bit differently than for other workers.

---

<a id='Main.ConsoleCommand' href='#Main.ConsoleCommand'>#</a>
**Type**

```
ConsoleCommand
```

Commands that are first executed in the console before Julia code.

  * `edit filename` : open filename in the Editor. If filename does not exists it will be created instead. 
  * `clc` : clear the console.
  * `pwd` : get the current working directory.
  * `cd dirname` : set the current working directory.
  * `open name` : open name with default application (e.g. `open .` opens the current directory).
  * `mkdir dirname` : make a new directory.

---

<a id='Main.SearchWindow' href='#Main.SearchWindow'>#</a>
**Type**

```
SearchWindow <: GtkFrame
```

Search/replace panel that pops-up at the bottom of the editor. It uses a global `GtkSourceSearchSettings` (search_settings) alongside each `EditorTab` `GtkSourceSearchContext` (search_context). Each tab also store the position of the current match using `GtkTextMark`'s.

---

<a id='Main.Editor' href='#Main.Editor'>#</a>
**Type**

```
 Editor <: GtkNotebook
```

---

<a id='Main.EditorTab' href='#Main.EditorTab'>#</a>
**Type**

```
EditorTab <: GtkScrolledWindow
```

A single text file inside the `Editor`. The main fields are the GtkSourceView (view) and the GtkSourceBuffer (buffer).

---

<a id='index'></a>
## Index

- [`Console`](index.md#Main.Console)
- [`ConsoleCommand`](index.md#Main.ConsoleCommand)
- [`Editor`](index.md#Main.Editor)
- [`EditorTab`](index.md#Main.EditorTab)
- [`SearchWindow`](index.md#Main.SearchWindow)
- [`clear(c)`](index.md#Main.clear-Tuple{Any})
