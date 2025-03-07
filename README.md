# Hunt-Szymanski-diff


Hunt–Szymanski is a well-known approach for a line-based LCS that’s more memory-friendly than naive dynamic programming (Myers’ algorithm is also fairly heavy for very large inputs).

The elixir standard library already provides String.myers_difference/2 to generate diffs between strings, lists,...
However, String.myers_difference/2 memory usage quickly blow up for strings past a certain size.
Computing a diff for a typical article or blog post can quickly require gigabytes of memory.

String.myers_difference/2 stays performant for short strings, or for comparing larger strings with small changes between them.

Depending on your use case, String.myers_difference might be exactly what you need.

This library provides a line-based diff algorithm which is more memory and computation efficient, and probably more appropriate to track changes in longer texts like wiki pages, blog articles,... 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hunt_szymanski_diff` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hunt_szymanski_diff, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/hunt_szymanski_diff>.

