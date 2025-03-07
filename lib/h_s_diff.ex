defmodule HSDiff do
  @moduledoc """
  Provides a Hunt–Szymanski-based line diff:
    1) Compute the LCS (Longest Common Subsequence) using the Hunt–Szymanski approach.
    2) Build a diff result (eq/del/ins) from that LCS.

  Typically used for large lists of lines where changes are relatively sparse.
  This version also handles cases where left/right differ in length or contain
  multiple occurrences of the same line.
  """

  defdelegate optimize(diff), to: HSDiff.Optimize
  defdelegate patch(old, diff), to: HSDiff.Patch

  @doc """
  diff/2 entry point:

      diff(left, right)

  If `left` and `right` are strings, we split them by `\n` into lists of lines.
  If `left` and `right` are already lists, we pass them along.
  """
  def diff(left, right) when is_list(left) and is_list(right) do
    lcs_result = hunt_szymanski_lcs(left, right)
    build_diff(left, right, lcs_result)
  end

  def diff(left, right) when is_binary(left) and is_binary(right) do
    diff(String.split(left, "\n"), String.split(right, "\n"))
  end

  # --------------------------------------------------------------------------------
  #  HUNT–SZYMANSKI LCS
  # --------------------------------------------------------------------------------

  @doc """
  Compute the LCS of two lists (commonly lines) via Hunt–Szymanski.

  Returns just the **list of common elements** in order.
  You can then convert that LCS into a diff using `build_diff/3` or your own logic.
  """
  def hunt_szymanski_lcs(left, right) do
    pos_map = build_positions_map(right)

    # We'll maintain a structure for the "Longest Increasing Subsequence" (LIS)
    # on the indexes in `right`.
    lis_state = %{
      tails: [],
      links: %{},
      length: 0
    }

    {final_lis_state, _count} =
      Enum.reduce(left, {lis_state, 0}, fn line, {state, count} ->
        case Map.get(pos_map, line) do
          nil ->
            # line not in right at all
            {state, count}

          positions ->
            new_state = Enum.reduce(positions, state, &update_lis/2)
            {new_state, count + 1}
        end
      end)

    build_lcs_from_lis(final_lis_state, right)
  end

  defp build_positions_map(right) do
    right
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {line, idx}, acc ->
      Map.update(acc, line, [idx], fn old -> [idx | old] end)
    end)
    # we collected indexes in reverse; reverse each list to ascending
    |> Enum.map(fn {line, idxs} -> {line, Enum.reverse(idxs)} end)
    |> Map.new()
  end

  defp update_lis(i, %{tails: tails, links: links, length: length} = state) do
    {pos, _} = binary_search_lis(tails, i, 0, length - 1)

    new_tails =
      if pos == length do
        tails ++ [i]
      else
        List.replace_at(tails, pos, i)
      end

    new_links =
      if pos > 0 do
        Map.put(links, i, Enum.at(new_tails, pos - 1))
      else
        links
      end

    new_length = if pos == length, do: length + 1, else: length

    %{state | tails: new_tails, links: new_links, length: new_length}
  end

  defp binary_search_lis(_tails, _i, low, high) when high < low, do: {low, nil}

  defp binary_search_lis(tails, i, low, high) do
    mid = div(low + high, 2)
    mid_val = Enum.at(tails, mid)

    cond do
      i == mid_val ->
        {mid, mid_val}

      i < mid_val ->
        binary_search_lis(tails, i, low, mid - 1)

      true ->
        binary_search_lis(tails, i, mid + 1, high)
    end
  end

  defp build_lcs_from_lis(%{tails: tails, links: links, length: length}, right) do
    if length == 0 do
      []
    else
      last_idx = Enum.at(tails, length - 1)
      path = unwind_lis(last_idx, links, [])
      # Convert indexes to lines
      Enum.map(path, &Enum.at(right, &1))
    end
  end

  defp unwind_lis(nil, _links, acc), do: acc

  defp unwind_lis(idx, links, acc) do
    next = Map.get(links, idx, nil)
    unwind_lis(next, links, [idx | acc])
  end

  # --------------------------------------------------------------------------------
  #  DIFF BUILDING (POINTER-BASED)
  # --------------------------------------------------------------------------------

  @doc """
  Build a [eq: [...], del: [...], ins: [...]] diff from `left`, `right`,
  and `lcs` lines, using pointer arithmetic with a `reduce_while` call.

  We return `{:cont, {acc, i, j}}` to keep going,
  or `{:halt, {acc, i, j}}` if we detect the LCS line can't be found.

  After the reduce, we handle leftover lines in `left` or `right`.
  """
  def build_diff(left, right, lcs) do
    # 1. Run reduce_while to walk through LCS lines in order
    final_state =
      Enum.reduce_while(lcs, {[], 0, 0}, fn lcs_line, {acc, li, rj} ->
        case next_index_of(left, lcs_line, li) do
          nil ->
            # Can't find LCS line in left => fallback: leftover is all changed
            leftover_left = Enum.slice(left, li, length(left) - li)
            leftover_right = Enum.slice(right, rj, length(right) - rj)

            new_acc =
              acc
              |> maybe_add_block({:del, leftover_left})
              |> maybe_add_block({:ins, leftover_right})

            {:halt, {new_acc, length(left), length(right)}}

          found_li ->
            case next_index_of(right, lcs_line, rj) do
              nil ->
                # Can't find LCS line in right => fallback
                leftover_left = Enum.slice(left, li, length(left) - li)
                leftover_right = Enum.slice(right, rj, length(right) - rj)

                new_acc =
                  acc
                  |> maybe_add_block({:del, leftover_left})
                  |> maybe_add_block({:ins, leftover_right})

                {:halt, {new_acc, length(left), length(right)}}

              found_rj ->
                # Lines before found_li => :del
                segment_left = Enum.slice(left, li, found_li - li)
                # Lines before found_rj => :ins
                segment_right = Enum.slice(right, rj, found_rj - rj)

                new_acc =
                  acc
                  |> maybe_add_block({:del, segment_left})
                  |> maybe_add_block({:ins, segment_right})
                  |> maybe_add_block({:eq, [lcs_line]})

                # move pointers beyond the matched line
                {:cont, {new_acc, found_li + 1, found_rj + 1}}
            end
        end
      end)

    # 2. Now `final_state` is EITHER:
    #    - {acc, i, j}, if we never halted
    #    - {:halt, {acc, i, j}}, if we halted early
    {blocks, i, j} =
      case final_state do
        {:halt, triple} -> triple
        triple -> triple
      end

    # 3. Add leftover lines after we finish or halt
    leftover_left = Enum.slice(left, i, length(left) - i)
    leftover_right = Enum.slice(right, j, length(right) - j)

    blocks
    |> maybe_add_block({:del, leftover_left})
    |> maybe_add_block({:ins, leftover_right})
    |> Enum.reverse()
  end

  defp next_index_of(list, item, start_index) do
    Enum.drop(list, start_index)
    |> Enum.find_index(&(&1 == item))
    |> case do
      nil -> nil
      offset -> start_index + offset
    end
  end

  defp maybe_add_block(acc, {_tag, []}), do: acc
  defp maybe_add_block(acc, block), do: [block | acc]
end
