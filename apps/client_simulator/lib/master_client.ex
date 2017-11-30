defmodule MasterClient do
  use GenServer

  def start(masterClientId, totalClients, engineIP) do
    case ClientUtility.setup_connection(masterClientId, engineIP) do
      true ->
        IO.puts ("Master client started")
        GenServer.start(__MODULE__, {masterClientId, totalClients}, name: :"#{masterClientId}")
      false ->
        IO.puts "Failed to connect to engine"
      end
  end

  

  def init({masterClientId, totalClients}) do
    Enum.map(1..totalClients,
      fn(i) ->
        GenServer.start(Client, {i, masterClientId, totalClients}, name: ClientUtility.get_client_id(masterClientId, i))
      end)

    state = %{
              master_client_id: masterClientId,
              total_clients: totalClients,
              clients_initialized_count: 0
             }
    GenServer.cast(self(), :clients_created)
    {:ok, state}
  end

  def handle_cast(:clients_created, state) do
    totalClients = Map.get(state, :total_clients)
    masterClientId = Map.get(state, :master_client_id)
    Enum.map(1..totalClients,
      fn(i) ->
        GenServer.cast(ClientUtility.get_client_id(masterClientId, i), :subscribe)
      end)
    {:noreply, state}
  end

  def handle_cast(:subscription_done, state) do
    # IO.puts "received subscription_done"
    clientsInitializedCount = Map.get(state, :clients_initialized_count)
    state = Map.put(state, :clients_initialized_count, clientsInitializedCount+1)
    totalClients = Map.get(state, :total_clients)
    if (clientsInitializedCount + 1) >= totalClients do
      IO.puts "all clients initialized so start tweeting"
      GenServer.cast(self(), :send_start_tweeting_msg)
    end
    {:noreply, state}
  end

  def handle_cast(:send_start_tweeting_msg, state) do
    # IO.puts "all clients initialized so start tweeting - send tweeting msg"
    masterClientId = Map.get(state, :master_client_id)
    totalClients = Map.get(state, :total_clients)
    Enum.map(1..totalClients,
      fn(i) ->
        GenServer.cast(ClientUtility.get_client_id(masterClientId, i), :tweet)
      end)
  {:noreply, state}
  end

end