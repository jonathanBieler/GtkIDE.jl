const fig_ntbook = @GtkNotebook()
const _display = Immerse._display

Base.show(io::IO,p::Gadfly.Plot) = write(io,"Gadfly.Plot(...)")

function Immerse.figure(;name::AbstractString="Figure $(Immerse.nextfig(Immerse._display))",
                 width::Integer=400,    # TODO: make configurable
                 height::Integer=400)
                 
    i = Immerse.nextfig(Immerse._display)
    f = Immerse.Figure()
    Gtk.on_signal_destroy((x...)->Immerse.dropfig(Immerse._display,i), f)

    idx = length(fig_ntbook)+1
    insert!(fig_ntbook,idx,f,name)
    
    showall(fig_ntbook)
    Immerse.initialize_toolbar_callbacks(f)
    Immerse.addfig(Immerse._display, i, f)
    
    set_current_page_idx(fig_ntbook,idx)
    i
end

function Immerse.figure(i::Integer; displayfig::Bool = true)

    Immerse.switchfig(_display, i)
    fig = Immerse.curfig(_display)
    displayfig && display(_display, fig)
    
    for idx = 1:length(fig_ntbook)
        f = fig_ntbook[idx]
        if typeof(f) == Figure && f.figno == i
            set_current_page_idx(fig_ntbook, idx)
        end    
    end
    fig
end

function Immerse.closefig(i::Integer) 

    fig = Immerse.getfig(Immerse._display,i)
    for idx = 1:length(fig_ntbook)
        f = fig_ntbook[idx]
        if typeof(f) == Figure && f.figno == i
            
            Immerse.clear_hit(fig)
            splice!(fig_ntbook,idx)
            set_current_page_idx(fig_ntbook,max(idx-1,0))
           
            destroy(fig)
            return
        end
    end
end


