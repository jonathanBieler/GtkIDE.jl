module MarkdownTextViews

    using ..Gtk
    using ..GtkExtensions
    import Gtk.GtkTextIter

    import Base.Markdown
    
    export MarkdownTextView, MarkdownColors
    
    type MarkdownColors
        color::String
        background::String
        highlight_color::String
        highlight_background::String
    end
    
    MarkdownColors() =  MarkdownColors("#000","#fff","#111","#eee")
    
    type MarkdownTextView <: GtkTextView

        handle::Ptr{Gtk.GObject}
        view::GtkTextView
        buffer::GtkTextBuffer

        function MarkdownTextView(m::Markdown.MD, prelude::String, mc::MarkdownColors = MarkdownColors())
            
            buffer = GtkTextBuffer()
            setproperty!(buffer,:text,prelude)  
            view = GtkTextView(buffer)
            
            GtkExtensions.style_css(view,"window, view, textview, buffer, text {
                background-color: $(mc.background);
                color: $(mc.color);
                font-family: Monaco, Consolas, Courier, monospace;
                margin:0px;
              }"
            )

            #setproperty!(view,:margin_left,1)
            setproperty!(view,:monospace,true)
            setproperty!(view,:wrap_mode,true)

            Gtk.create_tag(buffer, "normal", font="13")
            Gtk.create_tag(buffer, "h1", font="Bold 15")
            Gtk.create_tag(buffer, "h2", font="bold 14")
            Gtk.create_tag(buffer, "bold", font="bold")
            Gtk.create_tag(buffer, "italic", font="italic")
            Gtk.create_tag(buffer, "code", font="bold", foreground=mc.highlight_color, background=mc.highlight_background)

            insert_MD!(buffer,m)
#            tag(buffer,"normal",1,length(buffer))
            
            n = new(view.handle,view,buffer)
            Gtk.gobject_move_ref(n, view)
        end
        
        MarkdownTextView(m::String) = MarkdownTextView(Base.Markdown.parse(m),"")
        MarkdownTextView(m::String,prelude::String, mc::MarkdownColors) = MarkdownTextView(Base.Markdown.parse(m),prelude,mc)
        MarkdownTextView(m::String, mc::MarkdownColors) = MarkdownTextView(Base.Markdown.parse(m),"",mc)

    end

    function tag(buffer,what,i,j)
        Gtk.apply_tag(buffer,what, 
            GtkTextIter(buffer,i) , GtkTextIter(buffer,j) 
        )
    end

    function insert_MD!(buffer,m::Markdown.Header,i)
        ip = i
       
        insert!(buffer,"    ")
        i += 4
        for el in m.text
            i = insert_MD!(buffer,el,i)
        end
        tag(buffer, "h1", ip, i)
        i
    end

    function insert_MD!(buffer,m::String,i)
        insert!(buffer,m)
        i += length(m)
    end

    function insert_MD!(buffer,m::Markdown.LaTeX,i)
        i = insert_MD!(buffer,m.formula,i)
    end


    function insert_MD!(buffer,m::Markdown.Paragraph,i)
    #    insert!(buffer,"\n\n")
    #    i += 2
        for el in m.content
            i = insert_MD!(buffer,el,i)
        end
        i
    end

    function insert_MD!(buffer,m::Markdown.Code,i)
        insert!(buffer,m.code)
        tag(buffer, "code", i, i+sizeof(m.code)) 
        i += length(m.code)
    end

    function insert_MD!(buffer,m::Markdown.List,i)
        for it in m.items
            insert!(buffer,"    - ")
            i += 6
            for el in it
                i = insert_MD!(buffer,el,i)
            end
            insert!(buffer,"\n")
            i += 1
        end 
        i
    end

    function insert_MD!(buffer,m::Markdown.Italic,i)
        
        ip = i
        for el in m.text
            i = insert_MD!(buffer,el,i)
        end
        tag(buffer, "italic", ip, i) 
        i
    end


    function insert_MD!(buffer,m,i)
        if isdefined(m,:text) 
            for el in m.text
                i = insert_MD!(buffer,el,i)
            end
        end
        if isdefined(m,:content) 
            for el in m.content
                i = insert_MD!(buffer,el,i)
            end
        end
        i
    end

    function insert_MD!(buffer,m::Markdown.MD)
        i = length(buffer)+1
        for el in m.content
            i = insert_MD!(buffer,el,i)
            insert!(buffer,"\n\n")
            i += 2
        end
    end

    
end
    