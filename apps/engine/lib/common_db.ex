defmodule CommonDB do
  use GenServer

  def init(_args) do
    IO.inspect self(), label: "CommonDB started->"
    state = %{
        user_id_user_database_id_map: %{}, # map <userId, {password, UserDBId}>
        global_tweets: %{}, # map<tweetId, {createrUserId, tweet}>
        # global_tweets: %{}, # map<tweetId, %{createrUserId:, tweet:, retweeterSet:}>
        # global_messages: %{}, # map <messageId, {fromUserId, :tweet/:retweet, tweetId, parentUserId}>
    }
    {:ok, state}
  end

  def handle_call({:is_user_id_exist, userId}, _from, state) do
    is_present = Map.get(state, :user_id_user_database_id_map) |> Map.has_key?(userId)
    {:reply, is_present, state}
  end

# Getters
  def handle_call({:get_user_database_id, userId}, _from, state) do
    userIdUserDatabaseIdMap = Map.get(state, :user_id_user_database_id_map)
    case Map.has_key?(userIdUserDatabaseIdMap, userId) do
      true ->
        {:reply, userIdUserDatabaseIdMap |> Map.get(userId) |> elem(1), state}
      false ->
        {:reply, nil , state}
    end
  end

  def handle_call({:get_tweet, tweetId}, _from, state) do
    {:reply, Map.get(state, :global_tweets) |> Map.get(tweetId), state}
  end

  def handle_call({:verify_credentials, userId, password}, _from, state) do
    userIdUserDatabaseIdMap = Map.get(state, :user_id_user_database_id_map)
    cond do
      Map.has_key?(userIdUserDatabaseIdMap, userId) == false ->
        {:reply, nil, state}
      Map.get(userIdUserDatabaseIdMap, userId) |> elem(0) != password ->
        {:reply, nil, state}
      true ->
        {:reply, :ok, state}
    end
  end

# Setters
  def handle_cast({:set_user_database_id, userId, password, userDBId}, state) do
    updatedUserIdUserDBIdMap = Map.get(state, :user_id_user_database_id_map) |> Map.put(userId, {password, userDBId})
    {:noreply, Map.put(state, :user_id_user_database_id_map, updatedUserIdUserDBIdMap)}
  end

  def handle_cast({:set_tweet, tweetId, tweetContent}, state) do # tweetContent -> {fromUserId, tweet}
    updatedGlobalTweets = Map.get(state, :global_tweets) |> Map.put(tweetId, tweetContent)
    {:noreply, Map.put(state, :global_tweets, updatedGlobalTweets)}
  end

  def handle_cast(:print, state) do
    IO.inspect state, label: "common_db state ->"
    {:noreply, state}
  end
end
