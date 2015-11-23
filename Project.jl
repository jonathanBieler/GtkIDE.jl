## save window size, pan positions, etc
## create folder if necessary

type Project
    path::AbstractString
    files::Array{AbstractString,1}
    scroll_position::Array{AbstractFloat,1}
    ntbook_idx::Integer

    Project() = new("",Array(AbstractString,0),Array(AbstractFloat,0),1)
end

function update!(w::Project)

    w.path = pwd()
    w.files = Array(AbstractString,0)
    w.scroll_position = Array(AbstractFloat,0)
    w.ntbook_idx = get_current_page_idx(ntbook)

    for i=1:length(ntbook)
        t = get_tab(ntbook,i)
        if typeof(t) == EditorTab && t.filename != ""#in case we want to have something else in the editor

            adj = getproperty(t,:vadjustment, GtkAdjustment)
            push!(w.scroll_position,getproperty(adj,:value,AbstractFloat))

            push!(w.files,t.filename)
        end
    end
end

function save(w::Project)
    update!(w::Project)
    open(HOMEDIR * "config\\project","w") do io
        JSON.print(io,w)
    end
end

function load(w::Project)

    if !isfile( HOMEDIR * "config\\project" )
        w.path = pwd()
        return
    end
    j = JSON.parsefile(HOMEDIR * "config\\project")
    @show j
    w.path = j["path"]
    w.files = j["files"]
    w.scroll_position = j["scroll_position"]
    w.ntbook_idx = j["ntbook_idx"]
end

project = Project()
load(project)
cd(project.path)
