JsonBuilder.jl
==============

Build json strings with specific schemas fast. Useful when calling Web APIs.

```
using JsonBuilder

title  = "hello"
tags   = ["meta", "introduction"]
text   = "Hello World!"
author = Dict("name"=>"ylxdzsw", "email"=>"xxx@example.com")

minified_json_str = @json """
{
    title: $title,                      # use hashtag to leave a comment
    tags: $tags,                        # just like julia code
    text: $(string(text, "\n", now())), # use inteprolation incase you need a hash or dollar
    author: $author,                    # or something need escape (like \uxxxx) in the key
    nested: {
        num: 123,
        bool: true,
        "or anything json": [{}, {}]
    }
}
"""

@json STDOUT "['direct', 'output', 'to', $("an IO object")]"
```
