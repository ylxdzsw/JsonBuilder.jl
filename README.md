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
    text: $(string(text, "\n", now())), # use inteprolation if the key contains anything
    author: $author,                    # other than just plain letters
    nested: {
        num: 123,
        bool: true,
        $("or anything json"): [{}, {}]
    }
}
"""
```

use `...` to force iterpolate as an object or array, like ` @json "{ name: 'something', $otherinfo... }" `
