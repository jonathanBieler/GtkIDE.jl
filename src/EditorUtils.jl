extension(f::AbstractString) = splitext(f)[2]

######################
## WORD BREAKING

immutable SolidString
    c::Array{Char,1}
    function SolidString(s::AbstractString,l::Integer)
        l > length(s) && error("Offset larger than string length.")

        c = Array(Char,0)
        i = start(s)
        count = 0
        while !done(s,i) && count < l
            push!(c,s[i])
            (k,i) = next(s,i)
            count +=1
        end
        new(c)
    end
    SolidString(s::AbstractString) = SolidString(s,length(s))
end

import Base: length, getindex, endof
length(s::SolidString) = length(s.c)
endof(s::SolidString) = length(s)
getindex(s::SolidString,i::Integer) = s.c[i]
getindex(s::SolidString,i::UnitRange) = string(s.c[i]...)

# maybe not the most efficient way of doing this.
const _word_bounardy = [' ', '\n','\t','(',')','[',']',',','\'',
                       '*','+','/','\\','%','{','}','#',':',
                       '&','|','?','!','"','$','=','>','<']
const _word_bounardy_dot = [_word_bounardy; '.']#include dot in function of the context

function is_word_boundary(s::Char,include_dot::Bool)
    w = include_dot ? _word_bounardy_dot : _word_bounardy
    for c in w
        s == c && return true
    end
    false
end

function extend_word_backward(it::Integer,txt::SolidString,include_dot::Bool)
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
#        warn("negative position $pos ($(offset(it)) - $(offset(line_start)) )")
        return ("",GtkTextIter(buffer,offset(it)),
        GtkTextIter(buffer,offset(it)))
    end

    stxt = SolidString(txt)#this is a bit of a mess
    i = extend_word_backward(pos,stxt,include_dot)
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
#        warn("negative positon $pos ($(offset(it)) - $(offset(line_start)))")
        return ("",GtkTextIter(buffer,offset(it)),
        GtkTextIter(buffer,offset(it)))
    end

    txt = SolidString(txt,pos)
    (i,j) = select_word_backward(pos,txt,include_dot)

    its = GtkTextIter(buffer, i + offset(line_start) )
    ite = GtkTextIter(buffer, offset(it))

    return (txt[i:j],its,it)
end
function select_word_backward(pos::Integer,txt::SolidString,include_dot::Bool)

    j = pos
    #allow for autocomplete on functions
    pos = txt[pos] == '(' ? pos-1 : pos
    pos = txt[pos] == '!' ? pos-1 : pos

    i = extend_word_backward(pos,txt,include_dot)

    #allow for \alpha and such
    i = (i > 1 && txt[i-1] == '\\') ? i-1 : i

    return (i,j)
end
select_word_backward(pos::Integer,txt::AbstractString,include_dot::Bool) =
select_word_backward(pos,SolidString(txt,pos),include_dot)


######################
## Utility functions

function select_tuple(it::GtkTextIter,buffer::GtkTextBuffer)

    (txt, line_start, line_end) = get_line_text(buffer,it)
    pos = offset(it) - offset(line_start) #position of cursor in txt

    if pos <= 1 || length(txt) < 2 || pos > length(txt)
        return (false,nothing,nothing)
    end
    txt = txt[1:pos]

    i = rsearch(txt,'(')
    i == 0 && return (false,nothing,nothing)

    its = GtkTextIter(buffer, i + offset(line_start))
    return (true,txt[i:pos],its)

end

function text_iter_line_start(it::GtkTextIter)

    b = getbuffer(it)
    (txt, line_start, line_end) = get_line_text(b,it)
    i = lstrip_idx(txt)
    i > length(txt) && return it

    return GtkTextIter(b, offset(line_start) + i)
end

function lstrip_idx(s::AbstractString, chars::Base.Chars=Base._default_delims)
    i = start(s)
    while !done(s,i)
        c, j = next(s,i)
        if !(c in chars)
            return i
        end
        i = j
    end
    i
end


get_buffer(view::GtkTextView) = getproperty(view,:buffer,GtkTextBuffer)
cursor_position(b::GtkTextBuffer) = getproperty(b,:cursor_position,Int)

get_text_iter_at_cursor(b::GtkTextBuffer) =
GtkTextIter(b,cursor_position(b)+1) #+1 because there's a -1 in gtk.jl

function get_current_line_text(buffer::GtkTextBuffer)
    it = get_text_iter_at_cursor(buffer)
    return get_line_text(buffer,it)
end
function get_line_text(buffer::GtkTextBuffer,it::GtkTextIter)

    itstart, itend = mutable(it), mutable(it)
    li = getproperty(itstart,:line,Integer)

    text_iter_backward_line(itstart)#seems there's no skip to line start
    li != getproperty(itstart,:line,Integer) && skip(itstart,1,:line)#for fist line
    !getproperty(itend,:ends_line,Bool) && text_iter_forward_to_line_end(itend)

    return (text_iter_get_text(itstart, itend), itstart, itend)
end

function get_text_right_of_cursor(buffer::GtkTextBuffer)
    it = mutable(get_text_iter_at_cursor(buffer))
    return text_iter_get_text(it,it+1)
end
function get_text_left_of_cursor(buffer::GtkTextBuffer)
    it = mutable(get_text_iter_at_cursor(buffer))
    return text_iter_get_text(it-1,it)
end

get_text_left_of_iter(it::MutableGtkTextIter) = text_iter_get_text(it-1,it)
get_text_right_of_iter(it::MutableGtkTextIter) = text_iter_get_text(it,it+1)

get_text_left_of_iter(it::GtkTextIter) = text_iter_get_text(mutable(it)-1,mutable(it))
get_text_right_of_iter(it::GtkTextIter) = text_iter_get_text(mutable(it),mutable(it)+1)

function move_cursor_to_sentence_start(buffer::GtkTextBuffer)
    it = mutable( get_text_iter_at_cursor(buffer) )
    text_iter_backward_sentence_start(it)
    text_buffer_place_cursor(buffer,it)
end
function move_cursor_to_sentence_end(buffer::GtkTextBuffer)
    it = mutable( get_text_iter_at_cursor(buffer) )
    text_iter_forward_sentence_end(it)
    text_buffer_place_cursor(buffer,it)
end

function toggle_wrap_mode(v::GtkTextView)
    wm = getproperty(v,:wrap_mode,Int)
    wm = convert(Bool,wm)
    setproperty!(v,:wrap_mode,!wm)
    nothing
end

