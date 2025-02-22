module DocstringChef

using Markdown
using InteractiveUtils: gen_call_with_extracted_types
using OpenAI: create_chat

export @code
export @explain

_promptfn(code) = """
Generate JuliaLang docstring for the following Julia function:

```julia
$(code)
```

Always show the signature of a function at the top of the documentation, with a four-space indent so that it is printed as Julia code.

Just return the output as string. 
Do not add codefence.
"""

"""
	extractcode(lines::Vector{String})

Extract code that reporensents the definition of a function from `lines`, scanning
`lines` line by line using `Meta.parse`.
"""
function extractcode(lines::Vector{String})
    r = -1
    for n in eachindex(lines)
        try
            expr = Meta.parse(join(lines[1:n], "\n"), raise = true)
            if expr.head !== :incomplete
                r = n
                break
            end
        catch e
            e isa Meta.ParseError && continue
        end
    end
    join(lines[begin:r], "\n")
end

"""
	code(Function, types)

Print the definition of a function
"""
function code(args...)
    file, linenum = functionloc(args...)
    lines = readlines(file)[linenum:end]
    println(extractcode(lines))
end

"""
	@code(ex0)

Applied to a function or macro call, it evaluates the arguments to the specified call, and returns code giving the location for the method that would be called for those arguments. 
It calls out to the functionloc function.
"""
macro code(ex0)
    ex = gen_call_with_extracted_types(__module__, :code, ex0)
end

"""
    explain(args...)

Returns a Markdown parsed explanation docstring for the given arguments by querying the OpenAI GPT-4o-mini model with the associated code.

### Returns

  * A Markdown object containing the explanation of the function represented by `args`.

### Notes

  * Ensure that the `OPENAI_API_KEY` environment variable is set with a valid key for the OpenAI API.
  * The model used for generating the explanation is "gpt-4o-mini".

### Example

```julia-repl
julia> explain(sin, (Float64,))
```

"""
function explain(args...)
    file, linenum = functionloc(args...)
    lines = readlines(file)[linenum:end]
    code = extractcode(lines)
    prompt = _promptfn(code)
    model = "gpt-4o-mini"
    r = create_chat(
        ENV["OPENAI_API_KEY"],
        model,
        [Dict("role" => "user", "content" => prompt)],
    )
    content = r.response[:choices][begin][:message][:content]
    doclines = split(content, "\n")
    if startswith(first(doclines), "\"\"\"")
        popfirst!(doclines)
    end
    if startswith(last(doclines), "\"\"\"")
        pop!(doclines)
    end
    doc = join(doclines, "\n")
    Markdown.parse(doc)
end

"""
    explain ex0

It calls out `explain` function.
"""
macro explain(ex0)
    return gen_call_with_extracted_types(__module__, :explain, ex0)
end

end # module DocstringChef
