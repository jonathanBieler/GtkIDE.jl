## save window size, pan positions, etc
## create folder if necessary

type Workspace
    path::AbstractString
    files::Array{AbstractString,1}

    Workspace() = new("",Array(AbstractString,0))
end

function update!(w::Workspace)

    w.path = pwd()
    w.files = Array(AbstractString,0)

    for i=1:length(ntbook)
        t = get_tab(ntbook,i)
        if typeof(t) == EditorTab #in case we want to have something else in the editor
            push!(w.files,t.filename)
        end
    end

end

function save(w::Workspace)

    open(HOMEDIR * "config\\workspace","w") do io
        JSON.print(io,w)
    end
end

function load(w::Workspace)
    j = JSON.parsefile(HOMEDIR * "config\\workspace")
    w.path = j["path"]
    w.files = j["files"]
end

workspace = Workspace()
load(workspace)
cd(workspace.path)
