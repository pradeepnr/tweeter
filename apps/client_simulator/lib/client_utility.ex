defmodule ClientUtility do
  @engine :tweeter_engine
  @engine_cookie :tweeter_engine_cookie

  def setup_connection(masterClientId, engineIP) do
    Process.flag(:trap_exit, true)
    {:ok, [{ip, _gateway, _subnet}, {_, _, _}]} = :inet.getif()
    {a,b,c,d} = ip
    ipString = "#{a}.#{b}.#{c}.#{d}"
    hostname = "client#{masterClientId}"
    IO.inspect hostname, label: "hostname->"
    _startRes = Node.start(:"#{hostname}@#{ipString}")
    # IO.inspect startRes, label: "startRes->"
    Node.set_cookie(@engine_cookie)
    connectionResult = Node.connect(:"#{@engine}@#{engineIP}")
    if true == connectionResult do
      :global.sync()
    else
      IO.puts "provide valid server IP"
    end
    # IO.inspect Node.list
    connectionResult
  end

  def get_client_id(masterClientId, id) do
    :"#{masterClientId}-#{id}"
  end

  def get_tweet_time_out(myId, totalClients) do
    Kernel.div(totalClients, myId)
    # rank = ClientUtility.get_total_subscription(totalClients - myId, totalClients)
    # cond do
    #   rank == 0 ->
    #     @tweet_time_out
    #   true ->
    #     Kernel.div(@tweet_time_out, rank)
    # end
  end

  def get_total_subscription(myId, totalClients) do
    rank =
    case totalClients - myId do
      0 -> 1
      _-> totalClients-myId
    end
    totalUsersToFollow = Kernel.div(totalClients, rank)
    cond do
      totalClients <= 1 -> 0
      totalClients == 2 -> 1
      totalClients == 3 -> 1
      
      totalUsersToFollow == totalClients -> totalUsersToFollow - 1
      totalUsersToFollow <= 1 -> 2
      true -> totalUsersToFollow
    end
  end

  def get_subscription_id_list(myId, totalClients) do
    totalSubscription = ClientUtility.get_total_subscription(myId, totalClients)
    generate_subscription_List(myId, 1, totalClients, totalSubscription,[])
  end

  defp generate_subscription_List(myId, iteratorId, totalClients, totalSubscription, subscriptionList) do
    cond do
      length(subscriptionList) == totalSubscription ->
        subscriptionList
      myId == iteratorId ->
        generate_subscription_List(myId, iteratorId+1, totalClients, totalSubscription, subscriptionList)
      true ->
        generate_subscription_List(myId, iteratorId+1, totalClients, totalSubscription, [iteratorId | subscriptionList])
      
    end
  end

  def print_feed(feed) do
    get_string(feed, "")
  end

  def get_string([{createrUserId, tweet} | restFeed], string)
    
  end
end
