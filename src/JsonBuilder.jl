__precompile__()

module JsonBuilder

import JSON: print
import Base: push!, getindex

export @json, @json_str

macro json_str(s)
    json(STDOUT, parse("\"$(escape_string(s))\""))
end

macro json(s)
    json(STDOUT, s)
end

macro json(io, s)
    json(io, s)
end

function json(io::IO, s)
    isa(s, String) && return s

    if !isa(s, Expr) || s.head != :string
        error("invalid invocation of json macro")
    end

    x = Parser([], s.args, 1, 1)
    parse_value!(x)
    code_gen(x.result)
end

type Parser
    result; s; i::Int; j::Int
end

type ObjectMixin end
type ArrayMixin end

push!(p::Parser, x) = push!(p.result, x)
getindex(p::Parser, x) = p.s[x]
getindex(p::Parser, x, y) = p.s[x][y]
done(p::Parser) = p.j > length(p[p.i])
eof(p::Parser)  = p.i > length(p.s)
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
            push!(p, p[p.i+1])
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
    push!(p, p[p.i, start:p.j-1])
end

function parse_object!(p::Parser)
    parse_char!('{', p)
    parse_space!(p)
    if next(p) == '}'
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
            push!(p, '}')
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
    if next(p) == ']'
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

function parse_string!(x, p)
    start, q = p.j, next(p)
    p.j += 1
    while !done(p)
        if next(p) == q
            push!(p, p[p.i, start:p.j-1]) # JSON.print will add quotes around them, so no need to insert quotes here
            p.j += 1
            return
        end
        p.j += 1
    end
    error("non-terminated string literal. hint: if you need interpolations within string literals, interpolate the whole string like `\$(\"some \$var\")`")
end

function parse_key!(p)
    if done(p)
        push!(p, p[p.i+1])
        p.i, p.j = p.i + 2, 1
    else
        start = p.j
        while !done(p) && any(next(p) in x for x in ('a':'z', 'A':'Z', '0':'9', "\$_")) # allow starting with digits; just trust the user
            p.j += 1
        end
        push!(p, p[p.i, start:p.j-1])
    end
end

function parse_char!(x, p)
    if next(p) == x
        p.j += 1
        push!(p, x)
    else
        error("unexpected $x")
    end
end

function code_gen(x)
    :( $x )
end

end # module
