defmodule HSDiff.Patch do
  @moduledoc """
  Applies a diff ([eq:, del:, ins:]) to an old text, producing the new text.

  If the old text is a string, we return a **string** (with lines joined by "\n").
  If the old text is a list of lines, we return a **list of lines**.
  """

  @doc """
  Patches the `old_text` with the given `diff`.

  - If `old_text` is a string, returns a **string**.
  - If `old_text` is a list of lines, returns a list of lines.
  """
  def patch(old_text, diff) when is_binary(old_text) do
    old_lines = String.split(old_text, "\n")
    new_lines = patch_lines(old_lines, diff, 0, [])
    # If old_text was a string, re-join so we return a string
    Enum.reverse(new_lines) |> Enum.join("\n")
  end

  def patch(old_lines, diff) when is_list(old_lines) do
    # Return a list of lines
    patch_lines(old_lines, diff, 0, []) |> Enum.reverse()
  end

  # ---------------------------------------------------------------------------
  # Internal pointer-based patch logic
  # `patch_lines/4` always returns a list of lines (in reverse order).
  # We finalize it in patch/2 above, reversing it and re-joining if needed.
  # ---------------------------------------------------------------------------
  defp patch_lines([], _diff, _i, new_lines_acc), do: new_lines_acc

  # In a typical scenario we keep applying each diff block. But we do
  # pointer-based processing inside a reduce or recursion. Let’s do
  # a simple approach: we define a private function do_patch_diff/3
  # that processes a single block, then recursively proceed.
  defp patch_lines(_old_lines, [], _i, new_lines_acc) do
    # no more diff blocks => we do nothing with leftover old_lines,
    # because that leftover is presumably deleted or unreachable.
    new_lines_acc
  end

  defp patch_lines(old_lines, [block | rest], i, new_lines_acc) do
    {new_acc, new_i} = apply_block(block, old_lines, i, new_lines_acc)
    patch_lines(old_lines, rest, new_i, new_acc)
  end

  # Each block can be optimized or non-optimized:
  defp apply_block({:eq, block_data}, old_lines, i, new_lines_acc) do
    eq_count = eq_length(block_data)
    eq_segment = Enum.slice(old_lines, i, eq_count)
    # Prepend eq_segment in reverse
    new_acc = Enum.reverse(eq_segment, new_lines_acc)
    {new_acc, i + eq_count}
  end

  defp apply_block({:del, block_data}, _old_lines, i, new_lines_acc) do
    del_count = del_length(block_data)
    # We skip these lines from the old text => do not add to new_lines_acc
    {new_lines_acc, i + del_count}
  end

  defp apply_block({:ins, block_data}, _old_lines, i, new_lines_acc) do
    ins_segment = ins_lines(block_data)
    # Prepend ins_segment in reverse
    new_acc = Enum.reverse(ins_segment, new_lines_acc)
    # We do not advance i because insertion has no counterpart in old text
    {new_acc, i}
  end

  # If there's any other block type, just skip it or handle it as no-op
  defp apply_block(_block, _old_lines, i, new_lines_acc) do
    {new_lines_acc, i}
  end

  # ---------------------------------------------------------------------------
  # Helpers for eq/del/ins data
  # ---------------------------------------------------------------------------

  # eq can be an integer (# lines to copy) or a list of lines.
  defp eq_length(block_data) when is_integer(block_data), do: block_data
  defp eq_length(block_data) when is_list(block_data), do: length(block_data)

  # del can be an integer (# lines to skip) or a list of lines.
  defp del_length(block_data) when is_integer(block_data), do: block_data
  defp del_length(block_data) when is_list(block_data), do: length(block_data)

  # ins is typically a list of lines. If it’s a single string, wrap in list.
  defp ins_lines(block_data) when is_list(block_data), do: block_data
  defp ins_lines(block_data) when is_binary(block_data), do: [block_data]
end
