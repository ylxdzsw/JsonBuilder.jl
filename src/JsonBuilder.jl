__precompile__()

module JsonBuilder

import JSON2

import Base: push!, iterate, convert, getindex

export JSON, @json, @json_str

struct JSON
    str::String
end

convert(::Type{JSON}, x) = JSON2.write(x) |> JSON
convert(::Type{T}, x::JSON) where T = JSON2.read(x.str, T)

# notes:
# `io` is a selected name in the generated code, no need to pass as arguments.

macro json(s)
    quote
        io = IOBuffer()
        $(json(s)...)
        String(take!(io))
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
        pushfirst!(s.args, " ")
    end

    x = Parser([], s.args, 1, 1)
    parse_value!(x)
    code_gen(x)
end

abstract type Token end
struct ObjectMixin <: Token end
struct ArrayMixin  <: Token end
struct EOF <: Token end
struct Var <: Token content end
struct Str <: Token content end
struct Raw <: Token content end

mutable struct Parser
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
            push!(p, Str(p[p.i, start+1:p.j-1]))
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
        push!(p, Raw('"'), Raw(p[p.i, start:p.j-1]), Raw('"'))
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
    :( push!($(esc(:result)), $(Expr(:quote, ex))) )
end

function code_gen(x)
    i, result, x = 1, Expr[], x.result

    push!(x, EOF()) # ensure that x[i+1] always valid

    while x[i] != EOF()
        if isa(x[i], Str)
            @gen write(io, '"', $(x[i].content), '"')
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
                    write(io, '"', string(k), '"')
                    write(io, ':')
                    write(io, convert(JSON, v).str)
                end
                i += 1 # skip the Mixin Token
            elseif isa(x[i+1], ArrayMixin)
                @gen join((io, x)->write(io, convert(JSON, x).str), io, $(esc(x[i].content)), ',')
                i += 1 # skip the Mixin Token
            else
                @gen write(io, convert(JSON, $(esc(x[i].content))).str)
            end
        else
            error("BUG, Please fire an issue with your json template string.")
        end

        i += 1
    end

    result
end

function join(f, io::IO, iter, delim)
    first = true

    for i in iter
        if first
            first = false
        else
            write(io, delim)
        end
        f(io, i)
    end
end

end # module
