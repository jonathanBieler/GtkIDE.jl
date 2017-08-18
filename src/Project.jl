## save window size, pan positions, etc
## create folder if necessary

type Project
    name::String
    path::String
    files::Array{String,1}
    scroll_position::Array{Float64,1}
    ntbook_idx::Integer
    main_window::MainWindow

    Project(main_window::MainWindow,name::String) = new(name,"",Array{String}(0),Array{Float64}(0),1,main_window)
end

#let's not serialize main_window
JSON.lower(w::Project) = Dict(
    "name" => w.name,
    "path" => w.path,
    "files" => w.files,
    "scroll_position" => w.scroll_position,
     "ntbook_idx" => w.ntbook_idx
 )

function update!(w::Project)
    editor = _editor(w.main_window)
    w.path = pwd()
    w.files = Array{String}(0)
    w.scroll_position = Array{Float64}(0)
    w.ntbook_idx = get_current_page_idx(editor)

    for i=1:length(editor)
        t = get_tab(editor,i)
        if typeof(t) == EditorTab && t.filename != ""#in case we want to have something else in the editor

            adj = getproperty(t,:vadjustment, GtkAdjustment)
            push!(w.scroll_position,getproperty(adj,:value,AbstractFloat))

            push!(w.files,t.filename)
        end
    end
end

#upgrade smoothly from the old project system
function upgrade_project()
    !isdir( joinpath(HOMEDIR,"config","projects") ) && mkdir( joinpath(HOMEDIR,"config","projects") )
    if !isfile(joinpath(HOMEDIR,"config","projects","default.json"))
        isfile(joinpath(HOMEDIR,"config","project")) &&
        cp(joinpath(HOMEDIR,"config","project"),joinpath(HOMEDIR,"config","projects","default.json"))
    end
end

function save(w::Project)
    update!(w)
    !isdir( joinpath(HOMEDIR,"config","projects") ) && mkdir( joinpath(HOMEDIR,"config","projects") )
    open( joinpath(HOMEDIR,"config","projects","$(w.name).json") ,"w") do io
        JSON.print(io,w,4)
    end
end

function load(w::Project)
    !isdir( joinpath(HOMEDIR,"config","projects") ) && mkdir( joinpath(HOMEDIR,"config","projects") )
    pth = joinpath(HOMEDIR,"config","projects","$(w.name).json")
    if !isfile(pth)
        w.path = pwd()
        return
    end
#	println( joinpath(HOMEDIR,"config","project"))
    j = JSON.parsefile(pth)

    if haskey(j,"name")#allow smooth upgrade
        w.name = j["name"]
    else
        w.name = "default"
    end

    w.path = j["path"]
    w.files = j["files"]
    w.scroll_position = j["scroll_position"]
    w.ntbook_idx = j["ntbook_idx"]
end
