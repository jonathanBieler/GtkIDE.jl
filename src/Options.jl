
function opt(block::AbstractString,key::AbstractString)
    conf = ConfParse(ascii(joinpath(HOMEDIR,"config","user_settings.ini")))
    parse_conf!(conf)

    r = ""
    try
        r = retrieve(conf, ascii(lowercase(block)), ascii(lowercase(key)))
    catch
        r = retrieve(default_settings, ascii(lowercase(block)), ascii(lowercase(key)))
    end
    parse(r)
end
opt(key::AbstractString) = opt("default",key)

# runtime

function init_opt()

    default_settings = ConfParse(ascii(joinpath(HOMEDIR,"config","default_settings.ini")))
    parse_conf!(default_settings)

    if !isfile(joinpath(HOMEDIR,"config","user_settings.ini"))
        cp(joinpath(HOMEDIR,"config","default_settings.ini"),joinpath(HOMEDIR,"config","user_settings.ini"))
    end

end