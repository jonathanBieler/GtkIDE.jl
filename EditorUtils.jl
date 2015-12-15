#probably not the most efficient way of doing this.
const word_bounardy = [" ", "\n","\t","(",")","[","]",",","\"",
                       "*","+","/","\\","%","{","}","#",":",
                       "&","|","?","!"]
const word_bounardy_dot = [word_bounardy; "."]#include dot in function of the context

function is_word_boundary(it::GtkTextIters,dir::Bool,include_dot::Bool)

    w = include_dot ? word_bounardy_dot : word_bounardy

    for c in w
        if dir #backward
            get_text_left_of_iter(it) == c && return true
        else #forward
            get_text_right_of_iter(it) == c && return true
        end
    end
    false
end
is_word_boundary(it::GtkTextIters,dir::Bool) = is_word_boundary(it,dir,true)

function _extend_word(it::MutableGtkTextIter,dir::Bool,include_dot::Bool)

    while !is_word_boundary(it,dir,include_dot)
        it = dir ? it-1 : it+1
    end
    if !dir && get_text_right_of_iter(it) == "!" #allow for a single ! at the end of words
        it = it + 1
    end
    return it
end
_extend_word(it::MutableGtkTextIter,dir::Bool) = _extend_word(it,dir,true)

function select_word(it::MutableGtkTextIter,include_dot::Bool)#include_dot means we include "." in word boundary def

    iter_end, iter_start = it, copy(it)

    iter_start = _extend_word(iter_start,true,include_dot)
    iter_end = _extend_word(iter_end,false,include_dot)

    return (text_iter_get_text(iter_start+1, iter_end+1), iter_start+1, iter_end+1)
end
select_word(it::MutableGtkTextIter) = select_word(it,true)
select_word(it::Gtk.GtkTextIter) = select_word(mutable(it),true)
select_word(it::Gtk.GtkTextIter) = select_word(mutable(it),true)

function select_word_backward(it::MutableGtkTextIter,include_dot::Bool)

    iter_end, iter_start = it, copy(it)

    #allow for autocomplete on functions
    iter_start = get_text_left_of_iter(iter_start) == "(" ? iter_start-1 : iter_start

    iter_start = _extend_word(iter_start,true,include_dot)

    return (text_iter_get_text(iter_start+1, iter_end+1), iter_start+1, iter_end+1)
end
select_word_backward(it::Gtk.GtkTextIter,include_dot::Bool) = select_word_backward(mutable(it),include_dot)

## WORD BREAKING

const _word_bounardy = [' ', '\n','\t','(',')','[',']',',','\'',
                       '*','+','/','\\','%','{','}','#',':',
                       '&','|','?','!']
const _word_bounardy_dot = [_word_bounardy; '.']#include dot in function of the context

function is_word_boundary(s::Char,dir::Bool,include_dot::Bool)

    w = include_dot ? _word_bounardy_dot : _word_bounardy

    for c in w
        if dir #backward
            s == c && return true
        else #forward
            s == c && return true
        end
    end
    false
end
is_word_boundary(it::Integer,dir::Bool) = is_word_boundary(it,dir,true)

function extend_word(it::Integer,txt::AbstractString,dir::Bool,include_dot::Bool)

    (dir && it==1) && return it
    (!dir && it==length(txt)) && return it

    while !is_word_boundary(txt[it],dir,include_dot)

        it < 3 && return it
        it > length(txt)-1 && return it

        it = dir ? it-1 : it+1
    end

    return dir ? it+1 : it-1 #I stopped at the boundary
end
extend_word(it::Integer,dir::Bool) = extend_word(it,dir,true)

function select_word(it::GtkTextIters,buffer::GtkTextBuffer,include_dot::Bool)#include_dot means we include "." in word boundary def

    (txt, line_start, line_end) = get_current_line_text(buffer)

    pos = offset(it) - offset(line_start) + 1 #position of cursor in txt

    i = extend_word(pos,txt,true,include_dot)
    j = extend_word(pos,txt,false,include_dot)
    
    if j < length(txt) && txt[j+1] == '!' #allow for a single ! at the end of words
        j = j + 1
    end

    its = Gtk.GtkTextIter(buffer, i + offset(line_start) )
    ite = Gtk.GtkTextIter(buffer, j + offset(line_start) + 1)

    return (txt[i:j],its,ite)
end
select_word(it::GtkTextIters,buffer::GtkTextBuffer) = select_word(it,buffer,true)

##

get_text_iter_at_cursor(buffer::GtkTextBuffer) = Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))

function get_current_line_text(buffer::GtkTextBuffer)

    itstart = get_text_iter_at_cursor(buffer)
    itend = get_text_iter_at_cursor(buffer)

    itstart, itend = mutable(itstart), mutable(itend)

    text_iter_backward_line(itstart)
    skip(itstart,1,:line)
    text_iter_forward_to_line_end(itend)

    return (text_iter_get_text(itstart, itend), itstart, itend)
end

offset(it::GtkTextIters) = getproperty(it,:offset,Integer)
