## WORD BREAKING
# maybe not the most efficient way of doing this.
const _word_bounardy = [' ', '\n','\t','(',')','[',']',',','\'',
                       '*','+','/','\\','%','{','}','#',':',
                       '&','|','?','!']
const _word_bounardy_dot = [_word_bounardy; '.']#include dot in function of the context

function is_word_boundary(s::Char,include_dot::Bool)

    w = include_dot ? _word_bounardy_dot : _word_bounardy
    for c in w
        s == c && return true
    end
    false
end

function extend_word_backward(it::Integer,txt::AbstractString,include_dot::Bool)

    it <= 1 && return 1

    while !is_word_boundary(txt[it],include_dot)
        it == 1 && return it
        it = it-1
    end
    return it+1 #I stopped at the boundary
end
function extend_word_forward(it::Integer,txt::AbstractString,include_dot::Bool)

    it >= length(txt) && return length(txt)

    while !is_word_boundary(txt[it],include_dot)
        it == length(txt) && return it
        it = it+1
    end
    return it-1 #I stopped at the boundary
end

function select_word(it::GtkTextIter,buffer::GtkTextBuffer,include_dot::Bool)#include_dot means we include "." in word boundary def

    (txt, line_start, line_end) = get_line_text(buffer,it)

    pos = offset(it) - offset(line_start) +1#not sure about the +1 but it feels better
    if pos <= 0
        warn("negative position $pos ($(offset(it)) - $(offset(line_start)) )")
        return ("",GtkTextIter(buffer,offset(it)),
        GtkTextIter(buffer,offset(it)))
    end

    i = extend_word_backward(pos,txt,include_dot)
    j = extend_word_forward(pos,txt,include_dot)

    if j < length(txt) && txt[j+1] == '!' #allow for a single ! at the end of words
        j = j + 1
    end

    its = GtkTextIter(buffer, i + offset(line_start) )
    ite = GtkTextIter(buffer, j + offset(line_start) + 1)

    return (txt[i:j],its,ite)
end
select_word(it::GtkTextIter,buffer::GtkTextBuffer) = select_word(it,buffer,true)

function select_word_backward(it::GtkTextIter,buffer::GtkTextBuffer,include_dot::Bool)

    (txt, line_start, line_end) = get_line_text(buffer,it)
    pos = offset(it) - offset(line_start) #position of cursor in txt

    if pos <= 0 || length(txt) == 0
        warn("negative positon $pos ($(offset(it)) - $(offset(line_start)))")
        return ("",GtkTextIter(buffer,offset(it)),
        GtkTextIter(buffer,offset(it)))
    end

    #allow for autocomplete on functions
    j = pos
    pos = txt[pos] == '(' ? pos-1 : pos

    i = extend_word_backward(pos,txt,include_dot)

    #allow for \alpha and such
    i = (i > 1 && txt[i-1] == '\\') ? i-1 : i

    its = GtkTextIter(buffer, i + offset(line_start) )
    ite = GtkTextIter(buffer, offset(it))

    return (txt[i:j],its,it)
end
#select_word_backward(it::Gtk.GtkTextIter,include_dot::Bool) = select_word_backward(mutable(it),include_dot)

## Utility functions

get_buffer(view::GtkTextView) = getproperty(view,:buffer,GtkTextBuffer)

get_text_iter_at_cursor(buffer::GtkTextBuffer) =
GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int)+1) #+1 because there's a -1 in gtk.jl

function get_current_line_text(buffer::GtkTextBuffer)
    it = get_text_iter_at_cursor(buffer)
    return get_line_text(buffer,it)
end
function get_line_text(buffer::GtkTextBuffer,it::GtkTextIter)

    itstart, itend = mutable(it), mutable(it)
    li = getproperty(itstart,:line,Integer)

    text_iter_backward_line(itstart)#seems there's no skip to line start
    li != getproperty(itstart,:line,Integer) && skip(itstart,1,:line)#for fist line
    text_iter_forward_to_line_end(itend)

    return (text_iter_get_text(itstart, itend), itstart, itend)
end
