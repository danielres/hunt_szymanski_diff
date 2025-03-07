# Hunt-Szymanski diff

A port of the [Hunt-Szymanski](https://en.wikipedia.org/wiki/Hunt%E2%80%93Szymanski_algorithm) diff algorithm to Elixir, with a focus on performance and memory efficiency.

This library is particularly suited for longer texts such as wiki pages or blog articles.

- [Package on Hex.pm](https://hex.pm/packages/hunt_szymanski_diff)
- [Documentation](https://hexdocs.pm/hunt_szymanski_diff)

## Credits

This library was generated with assistance from ChatGPT.\
While I guided its development and reviewed the implementation, the core algorithm was recreated by AI.

## Usage

```elixir
left = """
Roses are red,
Violets are blue,
Sugar is sweet,
And so are you.
"""

right = """
Roses are blue,
Violets are blue,
I love fluffy clouds,
And so are you.
"""

# 1. Diff two strings

diff = HSDiff.diff(left, right)

# => 
# [
#   del: ["Roses are red,"],
#   ins: ["Roses are blue,"],
#   eq: ["Violets are blue,"],
#   del: ["Sugar is sweet,"],
#   ins: ["I love fluffy clouds,"],
#   eq: ["And so are you."],
#   eq: [""]
# ]


# 2. Optimize the diff result

optimized = HSDiff.optimize(diff)

# => 
# [
#   del: 1,
#   ins: ["Roses are blue,"],
#   eq: 1,
#   del: 1,
#   ins: ["I love fluffy clouds,"],
#   eq: 2
# ]


# 3. Patch 

restored = HSDiff.patch(left, optimized) 

# => "Roses are blue,\nViolets are blue,\nI love fluffy clouds,\nAnd so are you.\n"
```

## Why Use Hunt-Szymanski Diff?

Elixir’s standard library already provides `String.myers_difference/2` to generate diffs between strings (and lists). However:

- **High Memory Usage**: For larger inputs (e.g., a typical article or blog post), `String.myers_difference/2` can quickly use gigabytes of memory. (Note: this can be alleviated by chunking the input into smaller pieces)
- **Small vs Large Inputs**: `String.myers_difference/2` performs well for short strings or larger strings with small changes. But for large-scale diffs—such as comparing entire documents—the Hunt–Szymanski line-based diff is more memory-efficient and performs better.

In short, if you need a diff algorithm for big textual data, Hunt–Szymanski can help you avoid the heavy memory footprint that comes with other approaches.

## Installation

Add `hunt_szymanski_diff` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hunt_szymanski_diff, "~> 0.1.0"}
  ]
end
```