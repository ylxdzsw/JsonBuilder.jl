JsonBuilder.jl
==============

[![Build Status](https://travis-ci.org/ylxdzsw/JsonBuilder.jl.svg?branch=master)](https://travis-ci.org/ylxdzsw/JsonBuilder.jl)
![Julia v1.0 ready](https://blog.ylxdzsw.com/_static/julia_v1.0_ready.svg?)
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

The schema is parsed and compiled in the compile time, so the performance should be at least as the same as the underlying library - [JSON2.jl](https://github.com/quinnj/JSON2.jl).

```
julia> using JSON2

julia> using JsonBuilder

julia> using BenchmarkTools

julia> a = (
           title = "Found a bug",
           body = "I'm having a problem with this.",
           assignees = (
               "octocat", "another octocat"
           ),
           milestone = 1,
           labels = ("bug",)
       )
(title = "Found a bug", body = "I'm having a problem with this.", assignees = ("octocat", "another octocat"), milestone = 1, labels = ("bug",))

julia> f(x) = JSON2.write(x)
f (generic function with 1 method)

julia> g(x) = @json """
           {
               title: "Found a bug",
               body: $(x.body),
               assignees: $(x.assignees),
               milestone: 1,
               labels: [$(x.labels)...]
           }
       """
g (generic function with 1 method)

julia> @btime f($a)
  1.363 μs (11 allocations: 960 bytes)
"{\"title\":\"Found a bug\",\"body\":\"I'm having a problem with this.\",\"assignees\":[\"octocat\",\"another octocat\"],\"milestone\":1,\"labels\":[\"bug\"]}"

julia> @btime g($a)
  1.152 μs (23 allocations: 1.56 KiB)
"{\"title\":\"Found a bug\",\"body\":\"I'm having a problem with this.\",\"assignees\":[\"octocat\",\"another octocat\"],\"milestone\":1,\"labels\":[\"bug\"]}"
```
