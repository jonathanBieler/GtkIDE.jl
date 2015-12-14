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

function select_word(it::MutableGtkTextIter)

    iter_end, iter_start = it, copy(it)

    iter_start = _extend_word(iter_start,true)
    iter_end = _extend_word(iter_end,false)

    return (text_iter_get_text(iter_start+1, iter_end+1), iter_start+1, iter_end+1)
end
select_word(it::Gtk.GtkTextIter) = select_word(mutable(it))

function select_word_backward(it::MutableGtkTextIter,include_dot::Bool)

    iter_end, iter_start = it, copy(it)
    iter_start = _extend_word(iter_start,true,include_dot)

    return (text_iter_get_text(iter_start+1, iter_end+1), iter_start+1, iter_end+1)
end
select_word_backward(it::Gtk.GtkTextIter,include_dot::Bool) = select_word_backward(mutable(it),include_dot)
