defmodule HSDiffTest do
  use ExUnit.Case

  test "diff with small localized changes in short list" do
    left = ["Line A", "Line B", "Line C", "Line D", "Line E", "Line F"]
    right = ["Line A", "Line B changed", "Line C", "Line D", "Line E new", "Line F"]

    assert HSDiff.diff(left, right) == [
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

  test "diff with small localized changes in short text" do
    left = ["Line A", "Line B", "Line C", "Line D", "Line E", "Line F"] |> Enum.join("\n")
    right = ["Line A", "Line B changed", "Line D", "Line E new", "Line F"] |> Enum.join("\n")

    assert HSDiff.diff(left, right) == [
             {:eq, ["Line A"]},
             {:del, ["Line B", "Line C"]},
             {:ins, ["Line B changed"]},
             {:eq, ["Line D"]},
             {:del, ["Line E"]},
             {:ins, ["Line E new"]},
             {:eq, ["Line F"]}
           ]
  end

  test "diff+patch with small localized changes in medium text" do
    left = File.read!("test/contents/lorem_5.txt")
    right = File.read!("test/contents/lorem_5_mod_sm.txt")
    diff = HSDiff.diff(left, right)
    assert HSDiff.patch(left, diff) == right
  end

  test "diff+patch with large changes in large texts" do
    left = File.read!("test/contents/lorem_40.txt")
    right = File.read!("test/contents/lorem_20.txt")
    diff = HSDiff.diff(left, right)
    assert HSDiff.patch(left, diff) == right
  end

  test "diff+optimize+patch with very large changes in large texts" do
    left = File.read!("test/contents/lorem_40.txt")
    right = File.read!("test/contents/lorem_40_b.txt")

    diff = HSDiff.diff(left, right)
    optimized = HSDiff.optimize(diff)

    assert optimized == [
             eq: 8,
             del: 1,
             ins: [
               "Amet CHANGE pulvinar malesuada erat habitant sodales pretium commodo. Leo magna amet ridiculus taciti blandit. Vestibulum imperdiet mi vulputate sit est. Pellentesque nec sociosqu malesuada do"
             ],
             eq: 25,
             del: 1,
             eq: 1,
             del: 4,
             eq: 14,
             del: 1,
             eq: 7,
             ins: [
               "Ex fames et natoque; ligula turpis semper arcu. Odio nascetur diam condimentum nisl tellus. Nam semper nisl quisque blandit phasellus aenean; cursus class metus. Maximus etiam potenti odio; montes venenatis nunc hendrerit vel ac. Nec phasellus ad facilisi congue tristique hac inceptos tristique. Suspendisse ornare ut iaculis interdum fusce massa tristique vestibulum. Enim elit mattis suscipit aliquam et."
             ],
             eq: 17
           ]

    assert HSDiff.patch(left, optimized) == right
  end

  test "README.md example" do
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

    diff = HSDiff.diff(left, right)
    optimized = HSDiff.optimize(diff)
    restored = HSDiff.patch(left, optimized)
    assert restored == right
  end
end
