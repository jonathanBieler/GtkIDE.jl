function opt(block::AbstractString, key::AbstractString)
    conf = ConfParse(ascii(joinpath(HOMEDIR, "config", "user_settings.ini")))
    parse_conf!(conf)

    r = ""
    try
        r = retrieve(conf, ascii(lowercase(block)), ascii(lowercase(key)))
    catch
        r = retrieve(default_settings, ascii(lowercase(block)), ascii(lowercase(key)))
    end
    Meta.parse(r)
end
opt(key::AbstractString) = opt("default", key)

# runtime
function init_opt()

    suffix = Sys.islinux() ? "_linux" : ""
    default_settings = ConfParse(ascii(joinpath(HOMEDIR, "config", "default_settings$(suffix).ini")))
    parse_conf!(default_settings)

    if !isfile(joinpath(HOMEDIR, "config", "user_settings.ini"))
        cp(joinpath(HOMEDIR, "config", "default_settings$(suffix).ini"), joinpath(HOMEDIR, "config", "user_settings.ini"))
    end

end