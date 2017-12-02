defmodule LoadBalancer do
  use GenServer
  @engine :tweeter_engine
  @engine_cookie :tweeter_engine_cookie
  @global_engine_name :tweeter_engine
  @tweet_matrix_time 10000
  @call_timeout 30_000

  def start({numOfWorkers, numOfUserDBs, }) do
    {:ok, loadBalancerPid} = GenServer.start(__MODULE__, {numOfWorkers, numOfUserDBs}, name: :load_balancer)
    GenServer.cast(loadBalancerPid, :initialize)
    loadBalancerPid
  end

  def setup_server() do
    {:ok, [{ip, _gateway, _subnet}, {_, _, _}]} = :inet.getif()
    {a,b,c,d} = ip
    ipString = "#{a}.#{b}.#{c}.#{d}"
    serverName = :"#{@engine}@#{ipString}"
    case Node.start(serverName) do
      {:ok, _pid} ->
        Node.set_cookie(Node.self(), @engine_cookie)
        :global.register_name(@global_engine_name, self())
        IO.puts "Tweeter engine started at IP -> #{serverName}"
        :ok
      {:error, reason} ->
        IO.puts "Could not start the Node because #{reason}"
        :fail
    end
  end

  def init({numOfWorkers, numOfUserDBs}) do
    IO.inspect self(), label: "load balancer started->"
    res = setup_server()
    case res do
      :ok ->
        state = %{
          number_of_workers: numOfWorkers,
          number_of_user_dbs: numOfUserDBs,
          session_number: 0,
          session: %{}, # %{session_key => {userId, pid}}
          workers: [],
          tweet_count: 0
        }
        Process.send_after(self(), :calculate_tweet_matrix, 5_000)
        {:ok, state}
      :fail ->
        {:fail, "could not setup server"}
    end
  end

  def handle_call({:register_user, userId, password, userPid}, _from, state) do
    randomWorker = Map.get(state, :workers) |> Enum.random
    registrationResult = GenServer.call(randomWorker, {:register_user, userId, password}, @call_timeout)
    case registrationResult do
      {:ok,_} ->
        sessionKey = Map.get(state, :session_number)
        state = Map.put(state, :session_number, sessionKey + 1)
        session = Map.get(state, :session)
        updatedSession = Map.put(session, sessionKey, {userId, userPid})
        state = Map.put(state, :session, updatedSession)
        randomWorker = Map.get(state, :workers) |> Enum.random
        GenServer.cast(randomWorker, {:user_active, userId, userPid})
        {:reply, {:ok, sessionKey}, state}
      _ ->
        {:reply, registrationResult, state}
    end
  end

  def handle_call({:login, userId, password, userPid}, _from, state) do
    case GenServer.call(:common_db, {:verify_credentials, userId, password}, @call_timeout) do
      nil ->
        {:reply, {:failed, "invalid username/password"}, state}
      :ok ->
        sessionKey = Map.get(state, :session_number)
        state = Map.put(state, :session_number, sessionKey + 1)
        session = Map.get(state, :session)
        updatedSession = Map.put(session, sessionKey, {userId, userPid})
        state = Map.put(state, :session, updatedSession)
        randomWorker = Map.get(state, :workers) |> Enum.random
        GenServer.cast(randomWorker, {:user_active, userId, userPid})
        {:reply, {:ok, sessionKey}, state}
    end
  end

  def handle_cast({:search_mentions, sessionKey, userId, mention}, state) do
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      tweetList = GenServer.call(randomWorker, {:get_mentions_list, mention}, @call_timeout)
      clientPid = Kernel.get_in(state, [:session, sessionKey]) |> elem(1)
      GenServer.cast(clientPid, {:receive_search_mentions, tweetList})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:search_hash_tag, sessionKey, userId, hashTag}, state) do
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      tweetList = GenServer.call(randomWorker, {:get_hash_tag_list, hashTag}, @call_timeout)
      clientPid = Kernel.get_in(state, [:session, sessionKey]) |> elem(1)
      GenServer.cast(clientPid, {:receive_search_hash_tag, hashTag, tweetList})
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:initialize, state) do
    {:ok, commonDbPid} = GenServer.start(CommonDB, nil, name: :common_db)
    numOfUserDBs = Map.get(state, :number_of_user_dbs)
    userDbList =
    Enum.reduce(1..numOfUserDBs,
      [],
      fn(_, userDbAcc) ->
        {:ok,userDbPid} = GenServer.start(ElasticUserDB, nil)
        [userDbPid | userDbAcc]
      end
    )

    numOfworkers = Map.get(state, :number_of_workers)
    workerList = 
    Enum.reduce(1..numOfworkers,
      [],
      fn(id, workersAcc) ->
        {:ok, workerPid} = GenServer.start(Worker, {commonDbPid, id})
        GenServer.cast(workerPid, {:add_new_user_db, userDbList})
        [workerPid | workersAcc]
      end
    )
    state = Map.put(state, :workers, workerList)
    {:noreply, state}
  end

  def handle_cast({:subscribe, sessionKey, userId, subscribeTo}, state) do
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      GenServer.cast(randomWorker, {:subscribe, userId, subscribeTo})
    end
    {:noreply, state}
  end

  def handle_cast({:logout, sessionKey, userId}, state) do
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
        sessionsMap = Map.get(state, :session)
        updatedSessionsMap = Map.delete(sessionsMap, sessionKey)
        state = Map.put(state, :session, updatedSessionsMap)
        randomWorker = Map.get(state, :workers) |> Enum.random
        GenServer.cast(randomWorker, {:user_inactive, userId})
        {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:tweet, sessionKey, userId, tweet}, state) do
    tweetCount = Map.get(state, :tweet_count)
    state = Map.put(state, :tweet_count, tweetCount+1)

    sessionMap = Map.get(state, :session)
    validateSessionResult = validate_session(sessionMap, sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      GenServer.cast(randomWorker, {:tweet, userId, tweet})
    end
    {:noreply, state}
  end

  def handle_cast({:retweet, sessionKey, userId, msgId}, state) do
    tweetCount = Map.get(state, :tweet_count)
    state = Map.put(state, :tweet_count, tweetCount+1)
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      GenServer.cast(randomWorker, {:retweet, userId, msgId})
    end
    {:noreply, state}
  end

  # all below are for testing 
  def handle_cast(:print, state) do
    randomWorker = Map.get(state, :workers) |> Enum.random
    IO.inspect state, label: "load balancer start->"
    IO.puts ""
    GenServer.cast(:common_db, :print)
    GenServer.cast(randomWorker, :print)
    {:noreply, state}
  end

  def handle_info(:calculate_tweet_matrix, state) do
      tweetCount = Map.get(state, :tweet_count)
      if tweetCount > 0 do
        tweetsPerSec = tweetCount * 1000 |> Kernel.div(@tweet_matrix_time)
        IO.puts "#{tweetsPerSec} Tweets/Retweets per Second"
      end
      state = Map.put(state, :tweet_count, 0)
      Process.send_after(self(), :calculate_tweet_matrix, @tweet_matrix_time) 
      {:noreply, state}
    end

  defp validate_session(session, sessionKey, userId) do
    cond do
      (true == Map.has_key?(session, sessionKey)) and (userId == Map.get(session, sessionKey) |> elem(0)) ->
        true
      true ->
        false
    end
  end
end
