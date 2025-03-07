defmodule HSDiff do
  @moduledoc """
  Provides a Hunt–Szymanski-based line diff:
  1. Compute the LCS (Longest Common Subsequence) using the Hunt–Szymanski approach.
  2. Build a diff result (eq/del/ins) from that LCS.

  Typically used for large lists of lines where changes are relatively sparse.
  """

  @doc """
  Returns a diff in the form:
  [
  eq: [...lines...],
  del: [...lines only in left...],
  ins: [...lines only in right...],
  eq: [...],
  ...
  ]

  `left` and `right` can be lists of lines (strings).
  """
  def diff(left, right) do
    lcs_result = hunt_szymanski_lcs(left, right)
    build_diff(left, right, lcs_result)
  end

  # --------------------------------------------------------------------------------
  #  HUNT–SZYMANSKI LCS
  #
  #  The core idea:
  #  1) Build a map of each line -> sorted list of indexes where it appears in `right`.
  #  2) Traverse `left` in order; for each line in `left`, get that line's positions in `right`,
  #     feed them in ascending order to a "longest increasing sequence" builder on the `right` indexes.
  #  3) Reconstruct the sequence of matched lines from that LIS of indexes.
  #
  #  This yields the LCS. Because we only do a LIS on the index array, memory usage is
  #  generally much lower than naive DP for large texts with many repeated lines.
  # --------------------------------------------------------------------------------

  @doc """
  Compute the LCS of two lists (commonly lines) via Hunt–Szymanski.

  Returns just the **list of common elements** in order.
  You can then convert that LCS into a diff using `build_diff/3` or your own logic.
  """
  def hunt_szymanski_lcs(left, right) do
    # 1) Build a map: item -> sorted list of indexes in `right`.
    pos_map = build_positions_map(right)

    # 2) We'll maintain a structure for the "Longest Increasing Subsequence" (LIS) of indexes in `right`.
    #    This approach uses an array of "tails" (the smallest possible last index for an LIS of each length),
    #    plus a 'prev' array to reconstruct the final LIS path.

    # We'll keep:
    #   tails:  list of the last index in right for an LIS of length i+1
    #   links:  a map from index_in_right -> predecessor_index_in_right
    #   length: length of the LIS found so far
    lis_state = %{
      tails: [],
      links: %{},
      length: 0
    }

    # 3) Traverse each line in `left`. For each line, get all positions in `right`.
    #    Then feed those positions (in ascending order) into our LIS builder.
    #    This effectively picks out a longest common subsequence of lines in left & right.

    {final_lis_state, _count} =
      Enum.reduce(left, {lis_state, 0}, fn line, {state, count} ->
        case Map.get(pos_map, line) do
          nil ->
            # line not in right at all
            {state, count}

          positions ->
            # positions is an ascending list of indexes in right
            new_state = Enum.reduce(positions, state, &update_lis/2)
            {new_state, count + 1}
        end
      end)

    # 4) Reconstruct the LIS from final_lis_state
    build_lcs_from_lis(final_lis_state, right)
  end

  # -- Build a map of item -> sorted list of indexes in `right`
  defp build_positions_map(right) do
    right
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {line, idx}, acc ->
      Map.update(acc, line, [idx], fn old -> [idx | old] end)
    end)
    # we collected positions in reverse; each entry needs to be reversed for ascending indexes
    |> Enum.map(fn {line, idxs} -> {line, Enum.reverse(idxs)} end)
    |> Map.new()
  end

  # -- The LIS update step for each index from `positions`
  #
  # We maintain:
  #   tails: list of indexes in `right`, where tails[k] is the smallest possible
  #          index that ends an increasing subsequence of length (k+1).
  #   links: map from an index_in_right -> the predecessor index_in_right in the LIS
  #   length: the length of the LIS found so far
  #
  # When we get a new index i, we do a binary search in tails to see where i should go.
  defp update_lis(i, %{tails: tails, links: links, length: length} = state) do
    # 1) Binary search in tails to find the place to put i
    {pos, _} = binary_search_lis(tails, i, 0, length - 1)

    # 2) If pos == length, we extend the tails by one
    new_tails =
      if pos == length do
        tails ++ [i]
      else
        # else we overwrite tails[pos] with i (a smaller index for that subsequence length)
        List.replace_at(tails, pos, i)
      end

    # 3) Update predecessor links (for reconstructing the final LIS)
    #    If pos>0, then the predecessor is tails[pos-1], else none
    new_links =
      if pos > 0 do
        Map.put(links, i, Enum.at(new_tails, pos - 1))
      else
        links
      end

    # 4) Possibly increase the length
    new_length = if pos == length, do: length + 1, else: length

    %{state | tails: new_tails, links: new_links, length: new_length}
  end

  # -- Standard binary search to find the LIS position for i
  # We'll look for the leftmost location in tails where i can be placed
  # (where tails[pos] >= i).
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

  # -- Reconstruct the LCS lines from the LIS
  defp build_lcs_from_lis(%{tails: tails, links: links, length: length}, right) do
    if length == 0 do
      []
    else
      # The last index of the LIS is tails[length-1]
      last_idx = Enum.at(tails, length - 1)
      # Walk backwards via links
      path = unwind_lis(last_idx, links, [])
      # Convert indexes to lines in correct order
      Enum.map(path, &Enum.at(right, &1))
    end
  end

  defp unwind_lis(nil, _links, acc), do: acc

  defp unwind_lis(idx, links, acc) do
    next = Map.get(links, idx, nil)
    unwind_lis(next, links, [idx | acc])
  end

  # --------------------------------------------------------------------------------
  #  DIFF BUILDING
  #
  #  Once we have the LCS, we can build an eq/del/ins diff:
  #   For each consecutive LCS line, we produce eq: [...],
  #   between them, we produce del: ... / ins: ... as needed.
  # --------------------------------------------------------------------------------

  @doc """
  Build a diff in [eq:, del:, ins:] format from two lists (`left`, `right`) plus
  a list of lines that is their LCS in order.

  If you already have the LCS (e.g. from `hunt_szymanski_lcs/2`), pass it here.
  Otherwise, you can just call `diff(left, right)` which does it all in one go.
  """
  def build_diff(left, right, lcs) do
    do_build_diff(left, right, lcs, [])
    |> Enum.reverse()

    # merge consecutive eq/del/ins blocks of same type if you want
  end

  defp do_build_diff([], [], [], acc), do: acc

  defp do_build_diff(left, right, [], acc) do
    # no more LCS lines => whatever remains is all changed
    cond do
      left != [] and right == [] ->
        [{:del, left} | acc]

      left == [] and right != [] ->
        [{:ins, right} | acc]

      left != [] and right != [] ->
        [{:del, left}, {:ins, right} | acc]

      true ->
        acc
    end
  end

  defp do_build_diff(left, right, [line | lcs_rest], acc) do
    # find `line` in left and right
    {left_before, [^line | left_after]} = Enum.split_while(left, &(&1 != line))
    {right_before, [^line | right_after]} = Enum.split_while(right, &(&1 != line))

    # everything in left_before is del, everything in right_before is ins
    new_acc =
      acc
      |> maybe_add_block({:del, left_before})
      |> maybe_add_block({:ins, right_before})
      # the matched line is eq
      |> maybe_add_block({:eq, [line]})

    do_build_diff(left_after, right_after, lcs_rest, new_acc)
  end

  # Helper to skip empty blocks
  defp maybe_add_block(acc, {_tag, []}), do: acc
  defp maybe_add_block(acc, block), do: [block | acc]
end
