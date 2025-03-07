defmodule HSDiffTest do
  use ExUnit.Case

  test "diff with small localized changes in large text" do
    left = [
      "Line A",
      "Line B",
      "Line C",
      "Line D",
      "Line E",
      "Line F"
    ]

    right = [
      "Line A",
      "Line B changed",
      "Line C",
      "Line D",
      "Line E new",
      "Line F"
    ]

    diff_result = HSDiff.diff(left, right)

    assert diff_result == [
      eq: ["Line A"],
      del: ["Line B"],
      ins: ["Line B changed"],
      eq: ["Line C"],
      eq: ["Line D"],
      del: ["Line E"],
      ins: ["Line E new"],
      eq: ["Line F"]
    ]
  end
end
