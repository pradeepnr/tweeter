defmodule Client do
  use GenServer
  @password "forTesting"
  @global_engine_name :tweeter_engine
  @redo_timer 3000

  defp serverPid() do
    :global.whereis_name(@global_engine_name)
  end

  def init({myId, masterClientId, totalClients}) do
    {readResult, data} = File.read("input/sentences.txt")

    state = %{
      my_id: myId,
      master_client_id: masterClientId,
      total_clients: totalClients,
      sentences: String.split(data, "\n") |> List.to_tuple,
      session_key: nil
    }
    
    #register
    {registerResult, info} = GenServer.call(serverPid(), {:register_user, ClientUtility.get_client_id(masterClientId, myId), @password, self()})
    cond do
      readResult == :error ->
        IO.puts "sentences file missing"
        {:bad, nil}
      :ok == registerResult ->
        # IO.puts "successfull registration"
        state = Map.put(state, :session_key, info)    
      {:ok, state}

      true ->
        # IO.puts "registration failed, trying to login"
        {loginResult, info} = GenServer.call(serverPid(), {:login, ClientUtility.get_client_id(masterClientId, myId), @password, self()})
        cond do
          :ok == loginResult ->
            # IO.puts "login succesfull"
            state = Map.put(state, :session_key, info)
            {:ok, state}
          true ->
            {:bad, nil}
        end
    end
  end

  def handle_cast(:subscribe, state) do
    totalClients = Map.get(state, :total_clients)
    masterClientId = Map.get(state, :master_client_id)
    myId = Map.get(state, :my_id)
    #subscribe
    subscriptionIdList = ClientUtility.get_subscription_id_list(myId, totalClients)
    Enum.map(
      subscriptionIdList,
      fn(id) ->
        myUserId = ClientUtility.get_client_id(masterClientId, myId)
        subscribeTo = ClientUtility.get_client_id(masterClientId, id)
        # IO.puts "#{myUserId} , #{subscribeTo}"
        GenServer.cast(serverPid(), {:subscribe, myUserId, subscribeTo})
      end
    )
    GenServer.cast(:"#{masterClientId}", :subscription_done)
    {:noreply, state}
  end

  def handle_cast(:tweet, state) do
    sessionKey = Map.get(state, :session_key)
    myId = Map.get(state, :my_id)
    masterClientId = Map.get(state, :master_client_id)
    myUserId = ClientUtility.get_client_id(masterClientId, myId)
    sentences = Map.get(state, :sentences)
    randomSentenceId = Enum.random(1..tuple_size(sentences)-1)
    randomSentenceToTweet = elem(sentences, randomSentenceId)
    str1 = "####### TWEETING ########\n"
    str2 = "#{myUserId} Tweeting\n"
    str3 = "tweet -> #{randomSentenceToTweet}\n"
    str4 = "###############\n"
    IO.puts "#{str1}#{str2}#{str3}#{str4}"
    GenServer.cast(serverPid(), {:tweet, sessionKey, myUserId, randomSentenceToTweet})
    Process.send_after(self(), {:cast, {self(),{:tweet}}}, @redo_timer * myId)
    {:noreply, state}
  end

  def handle_cast({:receive_tweet, tweetFromUserId, createrUserId, tweetId, tweet}, state) do
    masterClientId = Map.get(state, :master_client_id)
    myId = Map.get(state, :my_id)
    myUserId = ClientUtility.get_client_id(masterClientId, myId)
    if(tweetFromUserId == createrUserId) do
      str1 = "####### RECEIVE TWEET ########\n"
      str2 = "#{myUserId} received Tweet from #{tweetFromUserId}\n"
      str3 = "tweet -> #{tweet}\n"
      str4 = "###############\n"
      IO.puts "#{str1}#{str2}#{str3}#{str4}"
      # randon 1:10 times retweet
      if Enum.random(1..10) == 9 do
        str1 = "####### RETWEETING ########\n"
        str2 = "#{myUserId} Retweeting\n"
        str3 = "tweet -> #{tweet}\n"
        str4 = "###############\n"
        IO.puts "#{str1}#{str2}#{str3}#{str4}"
        sessionKey = Map.get(state, :session_key)
        GenServer.cast(serverPid(), {:retweet, sessionKey, myUserId, tweetId})
      end
    else
      str1 = "####### RECEIVE RETWEET ########\n"
      str2 = "#{myUserId} received Retweet of #{createrUserId} from #{tweetFromUserId}\n"
      str3 = "tweet->#{tweet}\n"
      str4 = "###############\n"
      IO.puts "#{str1}#{str2}#{str3}#{str4}"
      #TODO randon 1:20 times retweet
      if Enum.random(1..20) == 9 do
        str1 = "####### RETWEETING ########\n"
        str2 = "#{myUserId} Retweeting\n"
        str3 = "tweet -> #{tweet}\n"
        str4 = "###############\n"
        IO.puts "#{str1}#{str2}#{str3}#{str4}"
        sessionKey = Map.get(state, :session_key)
        GenServer.cast(serverPid(), {:retweet, sessionKey, myUserId, tweetId})
      end
    end
    {:noreply, state}
  end

  def handle_cast({:receive_recent_feed, feed}, state) do
    ClientUtility.print_feed(feed)
    {:noreply, state}
  end

  def handle_info({type, {toPid, {action}}}, state) do
    case type do
      :cast ->
        GenServer.cast(toPid, action)
      :call ->
        GenServer.call(toPid, action)
      _->
        IO.puts "Unknow type, can't send"
    end
    {:noreply, state}
  end

end