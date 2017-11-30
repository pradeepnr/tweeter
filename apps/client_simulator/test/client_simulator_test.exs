defmodule ClientSimulatorTest do
  use ExUnit.Case
  doctest ClientSimulator

  test "greets the world" do
    assert ClientSimulator.hello() == :world
  end

  test "get total users to follow" do
    IO.puts ""
    totalClients = 1
    {sum,totalSum} =
    Enum.reduce(1..totalClients,
    {0,0},
    fn(i,{sumAcc,totalSumAcc}) ->
      val = ClientUtility.get_total_subscription(i, totalClients)
      IO.puts "#{i} follows->#{val}"
      totalSumAcc = totalSumAcc + val
      if (i >=0.8*totalClients) do
        {sumAcc + val, totalSumAcc}
      else
        {sumAcc, totalSumAcc}
      end
    end)
    IO.puts "sum -> #{sum}"
    IO.puts "totalSum -> #{totalSum}"
    if( totalSum != 0) do
      IO.puts "distribution ratio -> #{sum/totalSum * 100}"
    end
  end

  test "get_subscription_ids(myId, totalClients)" do
    assert [2, 1] == ClientUtility.get_subscription_id_list(3, 10)
    assert [9, 8, 7, 6, 5, 4, 3, 2, 1] == ClientUtility.get_subscription_id_list(10, 10)
    assert [3, 2, 1] == ClientUtility.get_subscription_id_list(7, 10)
  end

  test "get_tweet_time_out" do
    IO.puts ""
    totalClients = 1000
    Enum.map(
      1..totalClients,
      fn(i) ->
        timeOut = ClientUtility.get_tweet_time_out(i, totalClients)
        IO.puts "timeout for #{i} is #{timeOut}"
      end
    )
  end
end
