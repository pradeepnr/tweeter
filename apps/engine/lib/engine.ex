defmodule Engine do
  def main(_args) do
      # IO.inspect args, label: "args->"
      res = LoadBalancer.start({4,4})
      if res==:fail do
        IO.puts "failed to start"
      else
        # Process.sleep(20000)
        IO.puts ""
        # GenServer.cast(res, :print)
      end

      # result = GenServer.call(loadBalancerPid, {:register_user, "pnr","password", self()})
      # IO.inspect result
      # GenServer.cast(loadBalancerPid, {:tweet, "pnr", "Hi tweeter #wow @dhriti"})
      # Process.sleep(4000)
      # GenServer.cast(loadBalancerPid, :print)
      # Process.sleep(2000)
      # IO.puts "######"
      # ###
      # GenServer.call(loadBalancerPid, {:register_user, "dhriti","password", self()})
      # GenServer.cast(loadBalancerPid, {:retweet, "dhriti", "tweet10"})
      # GenServer.cast(loadBalancerPid, {:tweet, "dhriti", "Hi appa #wow @pnr"})
      # Process.sleep(4000)
      # GenServer.cast(loadBalancerPid, :print)
      # Process.sleep(2000)
      # IO.puts "######"
      # GenServer.call(loadBalancerPid, {:register_user, "shilpa","password", self()})
      # GenServer.cast(loadBalancerPid, {:subscribe, "shilpa", "dhriti"})
      # GenServer.cast(loadBalancerPid, {:subscribe, "pnr", "dhriti"})
      # GenServer.cast(loadBalancerPid, {:subscribe, "dhriti", "pnr"})
      # Process.sleep(2000)
      # GenServer.cast(loadBalancerPid, {:tweet, "dhriti", "oota maadu pappa"})
      # Process.sleep(4000)
      # GenServer.cast(loadBalancerPid, :print)
      # Process.sleep(2000)
      receive do

      end
  end

end