## save window size, pan positions, etc
## create folder if necessary

type Project
    path::AbstractString
    files::Array{AbstractString,1}

    Project() = new("",Array(AbstractString,0))
end

function update!(w::Project)

    w.path = pwd()
    w.files = Array(AbstractString,0)

    for i=1:length(ntbook)
        t = get_tab(ntbook,i)
        if typeof(t) == EditorTab && t.filename != ""#in case we want to have something else in the editor
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
    w.path = j["path"]
    w.files = j["files"]
end

project = Project()
load(project)
cd(project.path)
