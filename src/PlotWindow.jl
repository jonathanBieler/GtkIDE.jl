const fig_ntbook = @GtkNotebook()
const _display = Immerse._display

type Image <: GtkBox

    handle::Ptr{Gtk.GObject}
    data
    c::GtkCanvas

    function Image(img)

        data = array_to_rgb(img)
        c = @GtkCanvas()
        setproperty!(c,:expand,true)

        @guarded Gtk.ShortNames.draw(c) do widget
            xview, yview = guidata[widget, :xview], guidata[widget, :yview]
            set_coords(Cairo.getgc(widget), xview, yview)

            roi = data[floor(Int,xview.min):ceil(Int,xview.max),
                       floor(Int,yview.min):ceil(Int,yview.max)]

            copy!(widget, roi)
        end

        b = @GtkBox(:v)
        push!(b,c)
        # Initialize panning & zooming
        panzoom(c, (1,size(data,1)), (1,size(data,2)))
        panzoom_mouse(c, factor=1.0)
        panzoom_key(c)

        i = new(b.handle,data,c)
        Gtk.gobject_move_ref(i, b)
    end
end

function array_to_rgb{T<:Number}(img::Array{T,2})
    data = Array(Colors.RGB{Colors.U8}, size(img)...)
    img = img - minimum(img)
    img = img / maximum(img)
    for i in eachindex(img)
        data[i] = Colors.RGB(img[i],img[i],img[i])
    end
    data
end
function array_to_rgb{T<:Number}(img::Array{T,3})
    size(img,3) != 3 && error("The size of the third dimension needs to be equal to 3 (RGB).")
    data = Array(Colors.RGB{Colors.U8}, size(img)...)
    img = img - minimum(img)
    img = img / maximum(img)
    for i = 1:size(img,1)
        for j = 1:size(img,2)
            data[i,j] = Colors.RGB(img[i,j,1],img[i,j,2],img[i,j,3])
        end
    end
    data
end

function image(img)
    i = Image(img)
    f = get_tab(fig_ntbook,get_current_page_idx(fig_ntbook))
    if typeof(f) == Image
        idx = get_current_page_idx(fig_ntbook)
        splice!(fig_ntbook,idx)
        insert!(fig_ntbook,idx,i,"Image")
    else
        idx = length(fig_ntbook)+1
        insert!(fig_ntbook,idx,i,"Image")

    end
    showall(fig_ntbook)
    set_current_page_idx(fig_ntbook,idx)
    nothing
end

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
