defmodule EngineTest do
  use ExUnit.Case
  doctest Engine

  test "get hash tags" do
    assert ["#test3", "#test2", "#test1"] == Utility.get_hash_tags("This is a test tweet hash, #test1 ok #test2 what else ? #test3 fine @hih")
  end

  test "get hash tags empty" do
    assert [] == Utility.get_hash_tags("This is a test tweet hash, ok what else ? fine")
  end

  test "get mentions" do
    assert ["test3", "test2", "test1"] == Utility.get_mentions("This is a test tweet hash, @test1 ok @test2 what else ? @test3 fine #test")
  end

  test "get mentions empty" do
    assert [] == Utility.get_mentions("This is a test tweet hash, ok what else ? fine")
  end

  test "update hash tags" do
    assert %{"#hash1" => [23], "#tag1" => [43], "#tag2" => [43], "#tag3" => [43]} == Utility.update_hash_tags(%{"#hash1" => [23]}, ["#tag1", "#tag2", "#tag3"], 43)
    assert %{"#tag1" => [43, 23], "#tag2" => [43], "#tag3" => [43]} == Utility.update_hash_tags(%{"#tag1" => [23]}, ["#tag1", "#tag2", "#tag3"], 43)
  end

  # test "get_recent_feed" do
  #   assert [3,2,1] == Utility.get_recent_feed([1,2,3,4,5], 3, [])
  #   assert [5,4,3,2,1] == Utility.get_recent_feed([1,2,3,4,5], 7, [])
  #   assert [] == Utility.get_recent_feed([], 7, [])
  # end
end
