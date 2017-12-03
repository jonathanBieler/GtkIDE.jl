##

s = """
# fill *asd*

```
fill(x, dims)
```

Create an array filled with the value `x`. For example, `fill(1.0, (5,5))` returns a 5×5 array of floats, with each element initialized to `1.0`.

Test *italic* 


"""

m = string(@doc collect)

m = Base.Markdown.parse(m)

el = m.content[1]


##

import Base.Markdown


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
    i = 1
    for el in m.content
        i = insert_MD!(buffer,el,i)
        insert!(buffer,"\n\n")
        i += 2
    end
end

type MarkdownTextView <: GtkTextView

    handle::Ptr{Gtk.GObject}
    view::GtkTextView
    buffer::GtkTextBuffer

    function MarkdownTextView(txt::Markdown.MD)
        
        buffer = GtkTextBuffer()
        
        view = GtkTextView(buffer)

        setproperty!(view,:margin_left,1)
        setproperty!(view,:monospace,true)
        setproperty!(view,:wrap_mode,true)

        Gtk.create_tag(buffer, "normal", font="13")
        Gtk.create_tag(buffer, "h1", font="Bold 15")
        Gtk.create_tag(buffer, "h2", font="bold 14")
        Gtk.create_tag(buffer, "bold", font="bold")
        Gtk.create_tag(buffer, "italic", font="italic")
        Gtk.create_tag(buffer, "code", font="bold", background="#eee")

        insert_MD!(buffer,m)
        tag(buffer,"normal",1,length(buffer))
        
        n = new(view.handle,view,buffer)
        Gtk.gobject_move_ref(n, view)
    end

end

##



using Gtk
import Gtk.GtkTextIter

#buffer = GtkTextBuffer()
#setproperty!(buffer,:text,"wesh")

view = MarkdownTextView(m)

w = GtkWindow("",600,400)
push!(w,view)
showall(w)


