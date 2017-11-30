defmodule Worker do
  use GenServer
  @recent_feed_size 5

  def init({commonDB, workerId}) do
    IO.inspect self(), label: "worker started->"
    state = %{
      common_db: commonDB,
      user_dbs: {},
      worker_id: workerId,
      tweet_count: 0,
    }
    {:ok, state}
  end

  def handle_call({:register_user, userId, password}, _from, state) do
    commonDB = Map.get(state, :common_db)
    isUserIdExist = GenServer.call(commonDB, {:is_user_id_exist, userId})
    case isUserIdExist do
      true ->
        {:reply, {:failed, "user id already exist!"}, state}
      false ->
        # get random elastic_user_DB 
        userDbTuple = Map.get(state, :user_dbs)
        userDBTupleSize = tuple_size(userDbTuple)
        randomNum = Enum.random(0..userDBTupleSize-1)
        randomUserDBId = elem(userDbTuple, randomNum)
        
        # update userId and UserDB in commonDb
        GenServer.cast(commonDB, {:set_user_database_id, userId, password, randomUserDBId})
        # update userId and UserDB in elastic_user_db
        GenServer.cast(randomUserDBId, {:register_user, userId})
        {:reply, {:ok, "user added"}, state}
        
    end
  end

  def handle_cast({:add_new_user_db, userDBIdList}, state) do
    currentUserDBs = Map.get(state, :user_dbs)

    updatedUserDBs = 
    Enum.reduce(
      userDBIdList,
      currentUserDBs,
      fn(dbId, userDbAcc) ->
        Tuple.append(userDbAcc, dbId)
      end
    )
    
    {:noreply, Map.put(state, :user_dbs, updatedUserDBs)}
  end

  def handle_cast({:tweet, userId, tweet}, state) do
    commonDB = Map.get(state, :common_db)
    workerId = Map.get(state, :worker_id)

    #create tweet content in commonDB
    tweetCount = Map.get(state, :tweet_count)
    state = Map.put(state, :tweet_count, tweetCount+1)
    tweetId = "tweet#{workerId}#{tweetCount}"
    GenServer.cast(commonDB, {:set_tweet, tweetId, {userId, tweet}})

    userDBId = GenServer.call(commonDB, {:get_user_database_id, userId})
    # update hashtags info in userDB
    hashTagsList = Utility.get_hash_tags(tweet)
    if length(hashTagsList) > 0 do
      GenServer.cast(userDBId, {:update_hash_tags, hashTagsList, tweetId})
    end

    #update mentions info in userDB
    mentionsList = Utility.get_mentions(tweet)
    if length(mentionsList) > 0 do
      GenServer.cast(self(), {:update_mentions, tweetId, mentionsList})
    end

    GenServer.cast(self(), {:distribute_tweet, userDBId, tweetId, userId})
    {:noreply, state}
  end

  def handle_cast({:distribute_tweet, userDBId, tweetId, userId}, state) do
    commonDB = Map.get(state, :common_db)
    #add tweet to user's profile in userDB
    GenServer.cast(userDBId, {:update_users_tweet_id_list, userId, tweetId})

    #add tweet (tweetId) to subscriber's feed
    Utility.add_tweet_to_subscribers_feed(userDBId, userId, commonDB, tweetId, self())
    
    {:noreply, state}
  end

  def handle_cast({:update_mentions, tweetId, mentionsList}, state) do
    commonDB = Map.get(state, :common_db)
    Utility.update_mentions_with_tweet_id(commonDB, tweetId, mentionsList)
    {:noreply, state}
  end

  def handle_cast({:active_users_list, tweetFromUserId, tweetId, activeUsersPidList}, state) do
    # TODO send tweet and tweet id directly to the client
    # tweet id is required inorder to identify the tweet to retweet
    commonDB = Map.get(state, :common_db)
    {createrUserId, tweet} = GenServer.call(commonDB, {:get_tweet, tweetId})
    Utility.send_tweet_to_clients(tweetFromUserId, createrUserId, tweet, tweetId, activeUsersPidList)
    {:noreply, state}
  end

  def handle_cast({:retweet, retweeterUserId, tweetId}, state) do
    commonDB = Map.get(state, :common_db)
    #rest all steps do as tweet
    userDBId = GenServer.call(commonDB, {:get_user_database_id, retweeterUserId})
    GenServer.cast(self(), {:distribute_tweet, userDBId, tweetId, retweeterUserId})
    {:noreply, state}
  end

  def handle_cast({:subscribe, subscriber, toUserId}, state) do
    commonDB = Map.get(state, :common_db)
    if GenServer.call(commonDB, {:is_user_id_exist, toUserId}) do
        toUserDBId = GenServer.call(commonDB, {:get_user_database_id, toUserId})
        GenServer.cast(toUserDBId, {:update_user_subscribers_set, toUserId, subscriber})
    end
    # TODO updated following list
    {:noreply, state}
  end

  def handle_cast(:print, state) do
    userDbTuple = Map.get(state, :user_dbs)
    size = tuple_size(userDbTuple)
    Enum.map(0..size-1,
      fn(i)->
        GenServer.cast(elem(userDbTuple, i), :print)
      end
    )
    {:noreply, state}
  end

  def handle_cast({:user_active, userId, pid}, state) do
    commonDB = Map.get(state, :common_db)
    userDBId = GenServer.call(commonDB, {:get_user_database_id, userId})
    GenServer.cast(userDBId, {:user_id_active, userId, pid})
    feed = GenServer.call(userDBId, {:get_feeds, userId})
    topFeed = Utility.get_recent_feed(commonDB, feed, @recent_feed_size, [])
    GenServer.cast(pid, {:receive_recent_feed, topFeed})
    {:noreply, state}
  end

  def handle_cast({:user_inactive, userId}, state) do
    commonDB = Map.get(state, :common_db)
    userDBId = GenServer.call(commonDB, {:get_user_database_id, userId})
    GenServer.cast(userDBId, {:user_id_inactive, userId})
    {:noreply, state}
  end

end