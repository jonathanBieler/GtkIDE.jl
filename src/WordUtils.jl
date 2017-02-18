
module WordsUtils

const HOMEDIR = joinpath(Pkg.dir(),"GtkIDE","src")

using JSON
import Base: startswith, endswith, search
export WordList, startswith, endswith, search, synonyms, definition

type WordList{T<:AbstractString}
    words::Array{T,1}
    WordList(w::Array{T,1}) = new(w)
end
WordList() = WordList{String}(Array(String,0))
WordList{T<:AbstractString}(w::Array{T,1}) = WordList{T}(w)

function startswith{T<:AbstractString}(l::WordList{T},prefix::T)
    out = Array(T,0)
    for w in l.words
        startswith(w,prefix) && push!(out,w)
    end
    out
end
function endswith{T<:AbstractString}(l::WordList{T},prefix::T)
    out = Array(T,0)
    for w in l.words
        endswith(w,prefix) && push!(out,w)
    end
    out
end
function search{T<:AbstractString}(l::WordList{T},prefix::T)
    out = Array(T,0)
    for w in l.words
        r = search(w,prefix)
        r.start > 0 && push!(out,w)
    end
    out
end

function loadwordlist()
    #http://wordlist.aspell.net/12dicts/
    w = open(joinpath(HOMEDIR,"..","data","2of12.txt")) do f
        w = Array(String,0)
        for l in eachline(f)
            push!(w,l[1:end-2])
        end
        w
    end
    WordList(w)
end
function load_dict(name::AbstractString)
    j = JSON.parsefile( joinpath(HOMEDIR,"..","data",string(name,".json")) )
    syns = Dict{String}{Array{String,1}}()
    for k in keys(j)
        syns[k] = j[k]
    end
    syns
end

global const wordlist = loadwordlist()
global const synonyms_dict = load_dict("syndict")
global const definition_dict = load_dict("defdict")

function synonyms(k::AbstractString) 
    k = ascii(k)
    if haskey(synonyms_dict,k)
        return synonyms_dict[k]
    end
    String[]
end
function definition(k::AbstractString) 
    k = ascii(k)
    if haskey(definition_dict,k)
        return definition_dict[k]
    end
    String[]
end

end

using WordsUtils

##
#
#using WordNet
#db = DB("/Users/bieler/.julia/v0.4/GtkIDE/data/WordNet/")
#
#function synonyms(k)
#
#    out = String[]
#    for pos in ['n', 'v', 'a', 'r']
#        try
#            lemma = db[pos, k]
#            ss = synsets(db, lemma)
#            for s in ss
#                for syn in collect(words(s))
#                    syn = replace(ascii(syn),'_',' ')
#                    if syn != k
#                        push!(out,syn)
#                    end
#                end
#            end
#        end
#    end
#
#    out = sort(unique(out))
#end
#
#function def(k)
#
#    out = String[]
#    for pos in ['n', 'v', 'a', 'r']
#        try
#            lemma = db[pos, k]
#            ss = synsets(db, lemma)
#            for s in ss
#                push!(out,s.gloss)
#            end
#        end
#    end
#    out
#end
#
#
#
#lemma = db['n', "heavy"]
#ss = synsets(db, lemma)
#x = ss[1]
#
#WordNet.antonyms(db, ss[2])
#
#words(x)
#
#
#
#k = w.words[202]
#@time synonyms(k)
#
# get all synonyms
#
#function build_synonyms_dict(n)
#    syns = Dict{String}{Array{String,1}}()
#
#    for i=1:n
#        k = w.words[i]
#        syns[k] = synonyms(k)
#    end
#    syns    
#end
#
#out = build_synonyms_dict(200)
#out = build_synonyms_dict(length(w.words))
#
#0.4/1000 * 41242
#
#
#
#k = w.words[202]
#@time out[k]
#
# save with JLD ?
#
#using JLD
#synonyms_dict = out
#
#JLD.save("../data/synonyms.jld", "synonyms_dict", synonyms_dict)
#
#
#
#JLD.load("../data/synonyms.jld", "synonyms_dict")
#
#2
#
# Save with JSON
#
#    open( joinpath(HOMEDIR,"../data","syndict.json") ,"w") do io
#        JSON.print(io,out)
#    end
#    
#    j = JSON.parsefile( joinpath(HOMEDIR,"../data","syndict.json") )
#    2
#    
#    @time j["sex"]
#    
# convert to proper type
#
#    j = JSON.parsefile( joinpath(HOMEDIR,"../data","syndict.json") )
#    syns = Dict{String}{Array{String,1}}()
#
#    for k in keys(j)
#        syns[k] = j[k]
#    end
#
# get all gloss
#
#function build_def_dict(n)
#    syns = Dict{String}{Array{String,1}}()
#
#    for i=1:n
#        k = w.words[i]
#        syns[k] = def(k)
#    end
#    syns    
#end
#
#definitions_dict = build_def_dict(length(w.words))
#
#open( joinpath(HOMEDIR,"../data","defdict.json") ,"w") do io
#    JSON.print(io,definitions_dict)
#end

##




