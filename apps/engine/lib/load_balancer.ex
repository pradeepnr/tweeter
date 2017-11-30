defmodule LoadBalancer do
  use GenServer
  @engine :tweeter_engine
  @engine_cookie :tweeter_engine_cookie
  @global_engine_name :tweeter_engine

  def start({numOfUserDBs, numOfWorkers}) do
    {:ok, loadBalancerPid} = GenServer.start(__MODULE__, {numOfUserDBs, numOfWorkers}, name: :load_balancer)
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

  def init({numOfUserDBs, numOfWorkers}) do
    IO.inspect self(), label: "load balancer started->"
    res = setup_server()
    case res do
      :ok ->
        state = %{
          number_of_user_dbs: numOfUserDBs,
          number_of_workers: numOfWorkers,
          session_number: 0,
          session: %{}, # %{session_key => {userId, pid}}
          workers: []
        }
        {:ok, state}
      :fail ->
        {:fail, "could not setup server"}
    end
  end

  def handle_call({:register_user, userId, password, userPid}, _from, state) do
    randomWorker = Map.get(state, :workers) |> Enum.random
    registrationResult = GenServer.call(randomWorker, {:register_user, userId, password})
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
    case GenServer.call(:common_db, {:verify_credentials, userId, password}) do
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

    numOfworkers = Map.get(state, :number_of_user_dbs)
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
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      GenServer.cast(randomWorker, {:tweet, userId, tweet})
    end
    {:noreply, state}
  end

  def handle_cast({:retweet, sessionKey, userId, msgId}, state) do
    validateSessionResult = Map.get(state, :session) |> validate_session(sessionKey, userId)
    if(validateSessionResult == true) do
      randomWorker = Map.get(state, :workers) |> Enum.random
      GenServer.cast(randomWorker, {:retweet, userId, msgId})
    end
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

  # all below are for testing 

  def handle_cast(:print, state) do
    randomWorker = Map.get(state, :workers) |> Enum.random
    IO.inspect state, label: "load balancer start->"
    IO.puts ""
    GenServer.cast(:common_db, :print)
    GenServer.cast(randomWorker, :print)
    {:noreply, state}
  end

  def handle_cast({:subscribe, userId, toUserId}, state) do
    randomWorker = Map.get(state, :workers) |> Enum.random
    GenServer.cast(randomWorker, {:subscribe, userId, toUserId})
    {:noreply, state}
  end

  # def handle_call({:register_user, userId}, _from, state) do
  #   randomWorker = Map.get(state, :workers) |> Enum.random
  #   result = GenServer.call(randomWorker, {:register_user, userId, "password"})
  #   {:reply, result, state}
  # end

end
