using ClusterManagers
@schedule ClusterManagers.elastic_worker("gtkide","127.0.0.1",9019; stdout_to_master=false)

while myid() == 1
    sleep(0.01)
end

remotecall(include_string,1,"
    eval(GtkIDE,:(
        add_worker_cb( $(myid()) ) 
    ))
")

# import Base.Distributed.myid
# myid() = 1 #hack to allow for precompilation

# overwrite to allow precompilation
eval(Base,quote
    function compilecache(name::String)
        #myid() == 1 || error("can only precompile from node 1")
        # decide where to get the source file from
        path = find_in_path(name, nothing)
        path === nothing && throw(ArgumentError("$name not found in path"))
        path = String(path)
        # decide where to put the resulting cache file
        cachepath = LOAD_CACHE_PATH[1]
        if !isdir(cachepath)
            mkpath(cachepath)
        end
        cachefile::String = abspath(cachepath, name*".ji")
        # build up the list of modules that we want the precompile process to preserve
        concrete_deps = copy(_concrete_dependencies)
        for existing in names(Main)
            if isdefined(Main, existing)
                mod = getfield(Main, existing)
                if isa(mod, Module) && !(mod === Main || mod === Core || mod === Base)
                    mod = mod::Module
                    if module_parent(mod) === Main && module_name(mod) === existing
                        push!(concrete_deps, (existing, module_uuid(mod)))
                    end
                end
            end
        end
        # run the expression and cache the result
        if isinteractive() || DEBUG_LOADING[]
            if isfile(cachefile)
                info("Recompiling stale cache file $cachefile for module $name.")
            else
                info("Precompiling module $name.")
            end
        end
        if !success(create_expr_cache(path, cachefile, concrete_deps))
            error("Failed to precompile $name to $cachefile.")
        end
        return cachefile
    end
end)