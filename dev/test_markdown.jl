##

s = """
# fill *asd*

```
fill(x, dims)
```

Create an array filled with the value `x`. For example, `fill(1.0, (5,5))` returns a 5×5 array of floats, with each element initialized to `1.0`.

Test *italic* 


"""

m = string(@doc rand)

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

function insert_MD!(buffer,m::Markdown.Code,i)
    insert!(buffer,m.code)
    tag(buffer, "code", i, i+sizeof(m.code)) 
    i += length(m.code)
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

#

using Gtk
import Gtk.GtkTextIter

buffer = GtkTextBuffer()
#setproperty!(buffer,:text,"wesh")

view = GtkTextView(buffer)
setproperty!(view,:margin_left,10)
setproperty!(view,:monospace,true)

Gtk.create_tag(buffer, "normal", font="13")
Gtk.create_tag(buffer, "h1", font="Bold 15")
Gtk.create_tag(buffer, "h2", font="bold 14")
Gtk.create_tag(buffer, "bold", font="bold")
Gtk.create_tag(buffer, "italic", font="italic")
Gtk.create_tag(buffer, "code", font="normal", background="#eee")

insert_MD!(buffer,m)
tag(buffer,"normal",1,length(buffer))

w = GtkWindow(view)
showall(w)