JsonBuilder.jl
==============

[![Build Status](https://travis-ci.org/ylxdzsw/JsonBuilder.jl.svg?branch=master)](https://travis-ci.org/ylxdzsw/JsonBuilder.jl)
[![Coverage Status](https://coveralls.io/repos/github/ylxdzsw/JsonBuilder.jl/badge.svg?branch=master)](https://coveralls.io/github/ylxdzsw/JsonBuilder.jl?branch=master)

Build json strings with specific schemas. Useful when calling Web APIs.

```
using JsonBuilder

title  = "hello"
tags   = ["meta", "introduction"]
author = ("name"=>"ylxdzsw", "email"=>"xxx@example.com")

minified_json_str = @json """
{
    title: $title,              # use hash symbol to leave a comment just like julia code
    tags: $tags,                # support all types that `JSON2.jl` can handle
    author: {id:2, $author...}, # use `...` to iterpolate as "mixin", support any iterable (of course including `Associative{K, V}`)
    nested: {                   # nested objects and arrays just work
        num: 123,               # plain JSON literals are kept "as-is" without check.
        bool: true,
        "or anything json": [{}, {}]
    }
}
"""
```
