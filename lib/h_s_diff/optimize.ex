defmodule HSDiff.Optimize do
  @doc """
  Optimize the diff by:
    - merging consecutive eq: blocks into eq: count
    - merging consecutive del: blocks into del: count
    - merging consecutive ins: blocks into a single ins: [lines...]

  Example input:
      [
        eq: ["Line A"],
        del: ["Line B"],
        ins: ["Line B changed"],
        eq: ["Line C", "Line D"],
        del: ["Line E"],
        ins: ["Line E new"],
        eq: ["Line F"]
      ]

  becomes:
      [
        eq: 1,
        del: 1,
        ins: ["Line B changed"],
        eq: 2,
        del: 1,
        ins: ["Line E new"],
        eq: 1
      ]
  """
  def optimize(diff_blocks) do
    # We'll accumulate optimized blocks in `acc` via do_optimize.
    # Then reverse at the end so we return them in original order.
    diff_blocks
    |> do_optimize([])
    |> Enum.reverse()
  end

  # -- Private recursive function that processes each block, merging with the last one if possible --

  # 1) eq: lines
  #    If last block is eq: count, merge them by adding length(lines).
  defp do_optimize([{:eq, lines} | rest], [{:eq, count} | acc_rest]) do
    do_optimize(rest, [{:eq, count + length(lines)} | acc_rest])
  end

  #    Otherwise, start a new eq: length(lines).
  defp do_optimize([{:eq, lines} | rest], acc) do
    do_optimize(rest, [{:eq, length(lines)} | acc])
  end

  # 2) del: lines
  #    If last block is del: count, merge by adding length(lines).
  defp do_optimize([{:del, lines} | rest], [{:del, count} | acc_rest]) do
    do_optimize(rest, [{:del, count + length(lines)} | acc_rest])
  end

  #    Otherwise, start a new del: length(lines).
  defp do_optimize([{:del, lines} | rest], acc) do
    do_optimize(rest, [{:del, length(lines)} | acc])
  end

  # 3) ins: lines
  #    If last block is ins: existing, merge by concatenating line lists.
  defp do_optimize([{:ins, new_lines} | rest], [{:ins, existing_lines} | acc_rest]) do
    do_optimize(rest, [{:ins, existing_lines ++ new_lines} | acc_rest])
  end

  #    Otherwise, start a new ins: new_lines.
  defp do_optimize([{:ins, new_lines} | rest], acc) do
    do_optimize(rest, [{:ins, new_lines} | acc])
  end

  # If it's some other block type (in normal usage, we only have eq/del/ins),
  # just keep it as is.
  defp do_optimize([block | rest], acc) do
    do_optimize(rest, [block | acc])
  end

  # No more blocks => return the accumulator.
  defp do_optimize([], acc), do: acc
end
