# DocstringChef.jl

This Julia package supports docstring generation or explaining code given the function or method definition.

## Setup

- [Install Julia](https://julialang.org/downloads/)
- Set `OPENAI_API_KEY`
  - See https://github.com/JuliaML/OpenAI.jl to learn more.

⚠️ We strongly suggest setting up your API key as an ENV variable.

To confirm `ENV["OPENAI_API_KEY"]` is set properly, open Julia REPL in your terminal and run:

```julia
julia> using OpenAI

julia> function main()
               secret_key = ENV["OPENAI_API_KEY"]
               model = "gpt-4o-mini"
               prompt =  "Say \"this is a test\""

               r = create_chat(
                   secret_key,
                   model,
                   [Dict("role" => "user", "content"=> prompt)]
                 )
               println(r.response[:choices][begin][:message][:content])
       end
main (generic function with 1 method)

julia> main()
This is a test.
```

You can also use `DotEnv.jl` package.

```julia
julia> # store API key in `.env` in advance
julia> using DotEnv
julia> DotEnv.load!()
julia> @assert haskey(ENV, "OPENAI_API_KEY")
```

## Clone our repository and resolve dependencies:

```
$ git clone https://github.com/AtelierArith/DocstringChef.jl.git
$ cd DocstringChef.jl
$ julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Usage

### The `@code` macro

We provide `@code` macro. It works like `@less` except `@code` extracts only a function definition. Below shows several examples:

```julia
$ julia --project
julia> using DocstringChef

julia> @code 1+1
(+)(x::T, y::T) where {T<:BitInteger} = add_int(x, y)

julia> @code @macroexpand @show x
macro macroexpand(code)
    return :(macroexpand($__module__, $(QuoteNode(code)), recursive=true))
end

julia> @code sin(1)
    @eval function ($f)(x::Real)
        xf = float(x)
        x === xf && throw(MethodError($f, (x,)))
        return ($f)(xf)
    end

julia> @code sin(1.0)
function sin(x::T) where T<:Union{Float32, Float64}
    absx = abs(x)
    if absx < T(pi)/4 #|x| ~<= pi/4, no need for reduction
        if absx < sqrt(eps(T))
            return x
        end
        return sin_kernel(x)
    elseif isnan(x)
        return x
    elseif isinf(x)
        sin_domain_error(x)
    end
    n, y = rem_pio2_kernel(x)
    n = n&3
    if n == 0
        return sin_kernel(y)
    elseif n == 1
        return cos_kernel(y)
    elseif n == 2
        return -sin_kernel(y)
    else
        return -cos_kernel(y)
    end
end
```

### `@explain`

The `@doc <expr>` macro defined in the Base packages shows docstring for a given `<expr>`. Not all source codes provide docstrings.

The `@explain` macro provides a function to retrieve the source code, decode the source code using OpenAI's functions, and create a (yet another) docstring.

```julia
julia> @explain sin(1.0)
  sin(x::T) where T<:Union{Float32, Float64}

  Compute the sine of the input value x.

  The function calculates the sine of x using a specialized
  algorithm that optimizes performance for both Float32 and
  Float64 types. The computation handles various edge
  cases, such as very small input values, NaN, and
  infinity. For absolute values of x less than π/4, the
  function computes the sine directly. For larger values,
  it reduces the input using the periodicity of the sine
  function and computes the sine of the reduced value.

  Parameters
  ––––––––––

    •  x: A Float32 or Float64 value representing the
       angle in radians.

  Returns
  –––––––

    •  Returns the sine of the input value as a
       Float32 or Float64, depending on the input
       type.

    •  If x is NaN, the result will be NaN.

    •  If x is infinite, a domain error is raised.

  Examples
  ––––––––

  julia> sin(0.0)        # 0.0
  julia> sin(π/6)       # 0.5
  julia> sin(π/2)       # 1.0
  julia> sin(3π/2)      # -1.0

  Notes
  –––––

    •  The function optimizes performance for small
       values close to zero by returning x directly
       instead of calculating the sine.

    •  For large values of x, the function utilizes
       the periodicity of sine to reduce the input
       before calculation.

julia>
```

