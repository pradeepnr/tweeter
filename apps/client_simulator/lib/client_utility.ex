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

  def print_feed(feed, myUserId) do
    str = get_feed_string(feed, "")
    if str != "" do
      IO.puts "########## FEED of #{myUserId} #########\n#{str}############# End of Feed #############\n"
    end
  end

  def get_feed_string([], str) do
    str
  end

  def get_feed_string([ {tweetType, fromUserId, tweet} | restFeed], str) do
    tweetTypeStr =
    case tweetType do
      :tweet ->
        "TWEET"
      :retweet ->
        "RETWEET"
      _->
        ""
    end
    updatedStr = "#{str}RECEIVED #{tweetTypeStr} from #{fromUserId} \n tweet-> #{tweet}\n"
    get_feed_string(restFeed, updatedStr)
  end

  def print_tweet_for_mentions(mentionUserId, tweetContentList) do
    prefix = "########## SEARCH mentions of #{mentionUserId} #########\n"
    str = get_tweet_from_tweet_content_list(tweetContentList, "")
    suffix = "############# End of SEARCH mentions #############\n"

    IO.puts "#{prefix}#{str}#{suffix}"
  end

  def print_tweet_for_hash_tag(hashTag, tweetContentList) do
    prefix = "########## SEARCH hash tag for #{hashTag} #########\n"
    str = get_tweet_from_tweet_content_list(tweetContentList, "")
    suffix = "############# End of SEARCH hash tag #############\n"

    IO.puts "#{prefix}#{str}#{suffix}"
  end

  def get_tweet_from_tweet_content_list([], tweetString) do
    cond do
      tweetString == "" ->
        "     SEARCH EMPTY\n"  
      true ->
        tweetString
    end
  end  

  def get_tweet_from_tweet_content_list([tweetContent | tweetContentList], tweetString) do
    get_tweet_from_tweet_content_list(tweetContentList, "#{tweetString}#{elem(tweetContent, 1)} -> from #{elem(tweetContent, 0)}\n")
  end
end
