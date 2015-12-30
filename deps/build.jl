warn("Patching Winston.ini")
pth = joinpath(Pkg.dir(),"Winston","src","Winston.ini")
try
    f = open(pth,"r")
    s = readall(f)
    s = replace(s, r"output_surface          = tk",
                    "output_surface          = gtk")
    close(f)

    f = open(pth,"w")
    write(f,s)
    close(f)
catch err
    warning("failed to patch Winston")
    close(f)
    rethrow(err)
end
