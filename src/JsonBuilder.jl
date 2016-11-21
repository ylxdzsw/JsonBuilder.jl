__precompile__()

module JsonBuilder

import JSON: print
import Base: push!, getindex, done, next, eof

export @json, @json_str

# notes:
# `io` is a selected name in the generated code, no need to pass as arguments.
# `print` is for printing as JSON, and `write` is for raw output.

macro json_str(s)
    quote
        io = IOBuffer()
        $(json(parse("\"$(escape_string(s))\""))...)
        takebuf_string(io)
    end
end

macro json(s)
    quote
        io = IOBuffer()
        $(json(s)...)
        takebuf_string(io)
    end
end

macro json(io, s)
    quote
        io = $io
        $(json(s)...)
        nothing
    end
end

function json(s)
    if !isa(s, Expr) || s.head != :string
        isa(s, String) ? (s = Expr(:string, s)) :
        error("invalid invocation of json macro")
    end

    if !isa(s.args[1], String) # quick fix for invocations like `@json "$x"`
        unshift!(s.args, " ")
    end

    x = Parser([], s.args, 1, 1)
    parse_value!(x)
    code_gen(x)
end

abstract Token
type ObjectMixin <: Token end
type ArrayMixin  <: Token end
type EOF <: Token end
type Var <: Token content end
type Str <: Token content end
type Raw <: Token content end

type Parser
    result::Vector{Token}; s; i::Int; j::Int
end

push!(p::Parser, x) = push!(p.result, x)
getindex(p::Parser, x) = p.s[x]
getindex(p::Parser, x, y) = p.s[x][y]
done(p::Parser) = p.j > length(p[p.i])
eof(p::Parser)  = p.i >= length(p.s)
next(p::Parser) = !done(p) ? p[p.i][p.j] :
                  !eof(p)  ? error("unexpected interpolation") :
                             error("unexpected EOF")

function parse_space!(p::Parser)
    while !done(p)
        if !isspace(next(p))
            if next(p) == '#'
                while !done(p) && next(p) != '\n'
                    p.j += 1
                end
            else
                return
            end
        else
            p.j += 1
        end
    end
end

function parse_value!(p::Parser)
    parse_space!(p)
    if done(p)
        if eof(p)
            error("malformed json")
        else
            push!(p, Var(p[p.i+1]))
            p.i, p.j = p.i + 2, 1
        end
    elseif next(p) == '{'
        parse_object!(p)
    elseif next(p) == '['
        parse_array!(p)
    elseif next(p) in ('"', '\'')
        parse_string!(p)
    else
        parse_literal!(p)
    end
end

function parse_literal!(p::Parser)
    start = p.j
    while !done(p) && (next(p) in "+-.0123456789Eaeflnrstu") # true, false, null, numbers; just hope the user won't misspell them :)
        p.j += 1
    end
    push!(p, Raw(p[p.i, start:p.j-1]))
end

function parse_object!(p::Parser)
    parse_char!('{', p)
    parse_space!(p)
    if !done(p) && next(p) == '}'
        parse_char!('}', p)
        return
    end

    while true
        parse_key!(p)
        if p.j+2 <= length(p[p.i]) && p[p.i, p.j:p.j+2] == "..."
            p.j += 3
            push!(p, ObjectMixin())
        else
            parse_space!(p)
            parse_char!(':', p)
            parse_space!(p)
            parse_value!(p)
        end
        parse_space!(p)
        if next(p) == '}'
            parse_char!('}', p)
            return
        else
            parse_char!(',', p)
            parse_space!(p)
        end
    end
end

function parse_array!(p::Parser)
    parse_char!('[', p)
    parse_space!(p)
    if !done(p) && next(p) == ']'
        parse_char!(']', p)
        return
    end

    while true
        parse_value!(p)
        if p.j+2 <= length(p[p.i]) && p[p.i, p.j:p.j+2] == "..."
            p.j += 3
            push!(p, ArrayMixin())
        end
        parse_space!(p)
        if next(p) == ']'
            parse_char!(']', p)
            return
        else
            parse_char!(',', p)
            parse_space!(p)
        end
    end
end

function parse_string!(p::Parser)
    start, q = p.j, next(p)
    p.j += 1
    while !done(p)
        if next(p) == q
            push!(p, Str(p[p.i, start+1:p.j-1])) # JSON.print will add quotes around them, so no need to insert quotes here
            p.j += 1
            return
        end
        p.j += 1
    end
    error("non-terminated string literal. hint: if you need interpolations within string literals, interpolate the whole string like `\$(\"some \$var\")`")
end

function parse_key!(p::Parser)
    if done(p)
        push!(p, Var(p[p.i+1]))
        p.i, p.j = p.i + 2, 1
    elseif next(p) in ('"', '\'')
        parse_string!(p)
    else # simple form, without quote marks
        start = p.j
        while !done(p) && any(next(p) in x for x in ('a':'z', 'A':'Z', '0':'9', "\$_"))
            p.j += 1
        end
        push!(p, Str(p[p.i, start:p.j-1]))
    end
end

function parse_char!(x::Char, p::Parser)
    if next(p) == x
        p.j += 1
        push!(p, Raw(x))
    else
        error("unexpected $(next(p))")
    end
end

macro gen(ex)
    :( push!(result, $(Expr(:quote, ex))) )
end

function code_gen(x)
    i, result, x = 1, Expr[], x.result

    push!(x, EOF()) # ensure that x[i+1] always valid

    while x[i] != EOF()
        if isa(x[i], Str)
            @gen print(io, $(x[i].content))
        elseif isa(x[i], Raw)
            if isa(x[i+1], Raw)
                x[i+1] = Raw(string(x[i].content, x[i+1].content))
            else
                @gen write(io, $(x[i].content))
            end
        elseif isa(x[i], Var)
            if isa(x[i+1], ObjectMixin)
                @gen join(io, $(esc(x[i].content)), ',') do io, x
                    k, v = x
                    print(io, string(k))
                    write(io, ':')
                    print(io, v)
                end
                i += 1 # skip the Mixin Token
            elseif isa(x[i+1], ArrayMixin)
                @gen join(print, io, $(esc(x[i].content)), ',')
                i += 1 # skip the Mixin Token
            else
                @gen print(io, $(esc(x[i].content)))
            end
        else
            error("BUG, Please fire an issue with your json template string.")
        end

        i += 1
    end

    result
end

function join(f, io::IO, iter, delim)
    i = start(iter)

    if !done(iter, i)
        str, i  = next(iter, i)
        f(io, str)
    end

    while !done(iter, i)
        write(io, delim)
        str, i  = next(iter,i)
        f(io, str)
    end
end

end # module
