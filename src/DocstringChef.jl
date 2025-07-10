module DocstringChef

using Markdown
using JLFzf: inter_fzf
using InteractiveUtils: gen_call_with_extracted_types
using OpenAI: create_chat

export @explain

function postprocess_content(content::AbstractString)
    # Replace each match with the text wrapped in a math code block
    return replace(content, r"\$\$(.*?)\$\$"s => s"```math\1```")
end

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

function extractlines_from_functionloc(args...)
    file, linenum = functionloc(args...)
    lines = readlines(file)[linenum:end]
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
function explain(io::IO, args...)
    ms = methods(args...)
    lines = if length(ms) >= 2
        x = inter_fzf(ms, "--read0")
        if isempty(x)
            error("could not determine location of method definition")
        end

        file_line = last(split(x))
        file, ln_str = split(file_line, ":")
        ln = Base.parse(Int, ln_str)
        ln > 0 || error("could not determine location of method definition")
        file, ln = (Base.find_source_file(expanduser(string(file))), ln)
        lines = readlines(file)[ln:end]
        lines
    else
        m = first(ms)
        lines = readlines(Base.find_source_file(expanduser(string(m.file))))[m.line:end]
    end

    c = extractcode(lines)
    @info "Explaining the following code..." code=Markdown.parse("```julia\n" * c * "\n```")

    prompt = _promptfn(c)
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
    doc = postprocess_content(doc)
    Markdown.parse(doc)
end

explain(args...) = (@nospecialize; explain(stdout, args...))

function explain(@nospecialize(f),
    mod::Union{Module,AbstractArray{Module},Nothing}=nothing)
    # return all matches
    return explain(f, Tuple{Vararg{Any}}, mod)
end

"""
    explain ex0 [mod]

It calls out `explain` function.
"""
macro explain(fn::Symbol)
    :(explain($(esc(fn))))
end

macro explain(fn::Symbol, mod)
    :(explain($(esc(fn)), $(esc(mod))))
end

macro explain(ex0::Expr)
    gen_call_with_extracted_types(__module__, :explain, ex0)
end


end # module DocstringChef
