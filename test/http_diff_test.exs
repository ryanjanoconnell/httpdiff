defmodule HttpDiffTest do
  use ExUnit.Case
  doctest HttpDiff

  test "diff flat objects where there were deletes" do
    a = Jason.OrderedObject.new([{"a", 1}, {"b", 2}, {"c", 3}])
    b = Jason.OrderedObject.new([{"a", 1}])
    
    assert HttpDiff.diff(a, b).deletes == MapSet.new([
      %{type: :delete, path: ["b"], old_value: 2, new_value: nil},
      %{type: :delete, path: ["c"], old_value: 3, new_value: nil}
    ])
  end

  test "diff nested objects where there were deletes" do
    a_nested = Jason.OrderedObject.new([{"aa", 1}, {"bb", 2}, {"cc", 3}])
    a = Jason.OrderedObject.new([{"a", 1}, {"b", a_nested}, {"c", 3}])

    b_nested = Jason.OrderedObject.new([{"bb", 2}])
    b = Jason.OrderedObject.new([{"a", 1}, {"b", b_nested}])
    
    assert HttpDiff.diff(a, b).deletes == MapSet.new([
      %{type: :delete, path: ["c"], old_value: 3, new_value: nil},
      %{type: :delete, path: ["b", "aa"], old_value: 1, new_value: nil},
      %{type: :delete, path: ["b", "cc"], old_value: 3, new_value: nil}
    ])
  end

  test "diff flat objects where there were inserts" do
    a = Jason.OrderedObject.new([{"a", 1}])
    b = Jason.OrderedObject.new([{"a", 1}, {"b", 2}, {"c", 3}])
    
    assert HttpDiff.diff(a, b).inserts == MapSet.new([
      %{type: :insert, path: ["b"], old_value: nil, new_value: 2},
      %{type: :insert, path: ["c"], old_value: nil, new_value: 3}
    ])
  end

  test "diff nested objects where there were inserts" do
    a_nested = Jason.OrderedObject.new([{"bb", 2}])
    a = Jason.OrderedObject.new([{"a", 1}, {"b", a_nested}])

    b_nested = Jason.OrderedObject.new([{"aa", 1}, {"bb", 2}, {"cc", 3}])
    b = Jason.OrderedObject.new([{"a", 1}, {"b", b_nested}, {"c", 3}])
    
    assert HttpDiff.diff(a, b).inserts == MapSet.new([
      %{type: :insert, path: ["c"], old_value: nil, new_value: 3},
      %{type: :insert, path: ["b", "aa"], old_value: nil, new_value: 1},
      %{type: :insert, path: ["b", "cc"], old_value: nil, new_value: 3}
    ])
  end

  test "diff flat objects where there were value updates" do
    a = Jason.OrderedObject.new([{"a", 1}, {"b", 2}, {"c", 3}])
    b = Jason.OrderedObject.new([{"a", 1}, {"b", 20}, {"c", 30}])
    
    assert HttpDiff.diff(a, b).updates == MapSet.new([
      %{type: :update, path: ["b"], old_value: 2, new_value: 20},
      %{type: :update, path: ["c"], old_value: 3, new_value: 30}
    ])
  end

  test "diff nested objects where there were value updates" do
    a_nested = Jason.OrderedObject.new([{"aa", 1}, {"bb", 2}, {"cc", 3}])
    a = Jason.OrderedObject.new([{"a", 1}, {"b", a_nested}, {"c", 3}])

    b_nested = Jason.OrderedObject.new([{"aa", 10}, {"bb", 20}, {"cc", 3}])
    b = Jason.OrderedObject.new([{"a", 1}, {"b", b_nested}, {"c", 30}])
    
    assert HttpDiff.diff(a, b).updates == MapSet.new([
      %{type: :update, path: ["c"], old_value: 3, new_value: 30},
      %{type: :update, path: ["b", "aa"], old_value: 1, new_value: 10},
      %{type: :update, path: ["b", "bb"], old_value: 2, new_value: 20}
    ])
  end

  test "diff flat objects where keys were reordered" do
    a = Jason.OrderedObject.new([{"a", 1}, {"b", 2}, {"c", 3}])
    b = Jason.OrderedObject.new([{"b", 2}, {"a", 1}, {"c", 3}])
    
    assert HttpDiff.diff(a, b).reorders == MapSet.new([
      %{type: :reorder, path: ["a"], old_value: 0, new_value: 1},
      %{type: :reorder, path: ["b"], old_value: 1, new_value: 0}
    ])
  end

  test "diff nested objects where keys were reordered" do
    a_nested = Jason.OrderedObject.new([{"aa", 1}, {"bb", 2}, {"cc", 3}])
    a = Jason.OrderedObject.new([{"a", 1}, {"b", a_nested}, {"c", 3}])

    b_nested = Jason.OrderedObject.new([{"cc", 3}, {"aa", 1}, {"bb", 2}])
    b = Jason.OrderedObject.new([{"c", 3}, {"b", b_nested}, {"a", 1}])
    
    assert HttpDiff.diff(a, b).reorders == MapSet.new([
      %{type: :reorder, path: ["a"], old_value: 0, new_value: 2},
      %{type: :reorder, path: ["c"], old_value: 2, new_value: 0},
      %{type: :reorder, path: ["b", "aa"], old_value: 0, new_value: 1},
      %{type: :reorder, path: ["b", "bb"], old_value: 1, new_value: 2},
      %{type: :reorder, path: ["b", "cc"], old_value: 2, new_value: 0}
    ])
  end


end
