JsonBuilder.jl
==============

Build json strings with specific schemas. Useful when calling Web APIs.

```
using JsonBuilder

title  = "hello"
tags   = ["meta", "introduction"]
author = ("name"=>"ylxdzsw", "email"=>"xxx@example.com")

minified_json_str = @json """
{
    title: $title,              # use hash symbol to leave a comment just like julia code
    tags: $tags,                # support all types that `JSON.jl` can handle
    author: {id:2, $author...}, # use `...` to iterpolate as "mixin", support any iterable (of course including `Associative{K, V}`)
    nested: {                   # nested objects and arrays just work
        num: 123,               # plain JSON literals are keeped "as-is" without check.
        bool: true,
        "or anything json": [{}, {}]
    }
}
"""
```
