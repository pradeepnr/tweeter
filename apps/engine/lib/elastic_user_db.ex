defmodule ElasticUserDB do
  use GenServer
  def start do
    GenServer.start(__MODULE__, nil, name: :tweeter_engine)
  end

  def init(_args) do
    IO.inspect self(), label: "ElasticUserDB started->"
    state = %{
        registered_users: %{}, # map<userId, profile>. profile -> %{subscribers: [], following: [], tweet_ids: [{tweetId, fromUserId}], feed: []}
        hash_tags: %{}, # map<hash_tags, tweet_id_list>
        mentions: %{}, #map<userId, tweet_id_list> all the tweets in which user is mentioned
        active_users: %{} # map<userId, pid> 
    }
    {:ok, state}
  end

  # Getters - call
  # 1) subscribers of a user
  def handle_call({:get_subscribers, userId}, _from, state)  do
    {:reply, Map.get(state, :registered_users) |> Map.get(userId) |> Map.get(:subscribers), state}
  end
  # 2) get following of a user
  def handle_call({:get_followings, userId}, _from, state)  do
    {:reply, Map.get(state, :registered_users) |> Map.get(userId) |> Map.get(:following), state}
  end
  # 3) get tweet_ids of a user
  def handle_call({:get_tweet_ids, userId}, _from, state)  do
    {:reply, Map.get(state, :registered_users) |> Map.get(userId) |> Map.get(:tweet_ids), state}
  end
  # 4) get feed of user
  def handle_call({:get_feeds, userId}, _from, state)  do
    {:reply, Map.get(state, :registered_users) |> Map.get(userId) |> Map.get(:feed), state}
  end
  # 5) get active users
  def handle_call({:get_active_users}, _from, state)  do
    {:reply, Map.get(state, :active_users), state}
  end

  # 6) get tweet_ids containing given hash_tags
  def handle_call({:get_tweets_having_hash_tags, hashTags}, _from, state)  do
    {:reply, Map.get(state, :hash_tags) |> Map.get(hashTags), state}
  end
  # 7) get tweet_id list containing given mentions 
  def handle_call({:get_tweets_having_mentions, userId}, _from, state)  do
    {:reply, Map.get(state, :mentions) |> Map.get(userId), state}
  end


  # Setters - cast
  # 1) register user
  def handle_cast({:register_user, userId}, state) do
      new_user_profile = %{
                            subscribers: MapSet.new, 
                            following: [], 
                            tweet_ids: [], 
                            feed: []
                          }
      updatedRegisteredUsersMap = Map.get(state, :registered_users) |> Map.put(userId, new_user_profile)
      {:noreply, Map.put(state, :registered_users, updatedRegisteredUsersMap)}
  end
  
  # 2) set subscriber to a user. list of userIds, can also be one item
  # assumption: subscriber is a valid users. i.e it is verified by worker
  def handle_cast({:update_user_subscribers_set, userId, subscriber}, state) do
    currentRegisteredUsersMap = Map.get(state, :registered_users)
    currentUserProfile = Map.get(currentRegisteredUsersMap, userId)
    currentSubscribersSet = Map.get(currentUserProfile, :subscribers)

    updatedSubscribersSet = MapSet.put(currentSubscribersSet, subscriber)
    # Enum.reduce(
    #   subscribersList,
    #   currentSubscribersSet, #init
    #   fn(subscriber, subscribersSetAcc) ->
    #     MapSet.put(subscribersSetAcc, subscriber)
    #   end
    # )

    updatedUserProfile = Map.put(currentUserProfile, :subscribers, updatedSubscribersSet)
    updatedRegisteredUsersMap = Map.put(currentRegisteredUsersMap, userId, updatedUserProfile)
    updatedState = Map.put(state, :registered_users, updatedRegisteredUsersMap)
    {:noreply, updatedState}
  end
  # 3) set following to a user. list of userIds, can also be one item
  # TODO use Kernel.put_in()
  def handle_cast({:update_user_following_list, userId, followingList}, state) do
    currentRegisteredUsersMap = Map.get(state, :registered_users)
    currentUserProfile = Map.get(currentRegisteredUsersMap, userId)
    currentFollowingList = Map.get(currentUserProfile, :following)
    updatedFollowingList = Enum.concat(currentFollowingList, followingList)
    updatedUserProfile = Map.put(currentUserProfile, :following, updatedFollowingList)
    updatedRegisteredUsersMap = Map.put(currentRegisteredUsersMap, userId, updatedUserProfile)
    updatedState = Map.put(state, :registered_users, updatedRegisteredUsersMap)
    {:noreply, updatedState}
  end
  # 4) set tweet id to a user's tweet_ids
  def handle_cast({:update_users_tweet_id_list, userId, tweetId}, state) do
    currentRegisteredUsersMap = Map.get(state, :registered_users)
    currentUserProfile = Map.get(currentRegisteredUsersMap, userId)
    currentTweetIdList = Map.get(currentUserProfile, :tweet_ids)
    
    updatedUserProfile = Map.put(currentUserProfile, :tweet_ids, [tweetId | currentTweetIdList])
    updatedRegisteredUsersMap = Map.put(currentRegisteredUsersMap, userId, updatedUserProfile)
    updatedState = Map.put(state, :registered_users, updatedRegisteredUsersMap)
    {:noreply, updatedState}
  end
  # 5) set tweet id to feed of list of users
  def handle_cast({:update_users_feed_return_active_list, tweetFromUserId, subscribersList, tweetId, workerPid}, state) do
    #updating the tweet to all the subscribers in this user db
    currentRegisteredUsersMap = Map.get(state, :registered_users)
    updatedRegisteredUsersMap = 
    Enum.reduce(
      subscribersList,
      currentRegisteredUsersMap,
      fn(subscriber, registeredUsersMapAcc) ->
        currentUserProfile = Map.get(registeredUsersMapAcc, subscriber)
        currentFeedList = Map.get(currentUserProfile, :feed)
        updatedUserProfile = Map.put(currentUserProfile, :feed, [{tweetId, tweetFromUserId}| currentFeedList])
        Map.put(registeredUsersMapAcc, subscriber, updatedUserProfile)
      end
    )
    state = Map.put(state, :registered_users, updatedRegisteredUsersMap)
    # get all the active subscribers and send back the details to the worker
    activeUsersMap = Map.get(state, :active_users)
    activeUsersPidList = 
    Enum.reduce(
      subscribersList,
      [],
      fn(subscriber, activeUsersPidAcc) ->
        case Map.has_key?(activeUsersMap, subscriber) do
          true ->
            [Map.get(activeUsersMap, subscriber) | activeUsersPidAcc]
          false ->
            activeUsersPidAcc
        end
      end
    )
    GenServer.cast(workerPid, {:active_users_list, tweetFromUserId, tweetId, activeUsersPidList})
  {:noreply, state}
  end
  # 6) set user active -> add userId to map
  def handle_cast({:user_id_active, userId, pid}, state) do
    currentActiveUsersMap = Map.get(state, :active_users)
    updatedActiveUsersMap = Map.put(currentActiveUsersMap, userId, pid)
    updatedState = Map.put(state, :active_users, updatedActiveUsersMap)
    {:noreply, updatedState}
  end
  # 7) set user Inactive -> remove userId from map
  def handle_cast({:user_id_inactive, userId}, state) do
    currentActiveUsersMap = Map.get(state, :active_users)
    updatedActiveUsersMap = Map.delete(currentActiveUsersMap, userId)
    updatedState = Map.put(state, :active_users, updatedActiveUsersMap)
    {:noreply, updatedState}
  end
  # 8) set <hash_tag, tweet_ids>, if hash_tag present then append the tweet_ids list otherwise create entry and ass the list
  def handle_cast({:update_hash_tags, newHashTagsList, tweetId}, state) do
    currentHashTagsMap = Map.get(state, :hash_tags)
    updatedHashTagsMap = Utility.update_hash_tag_map(currentHashTagsMap, newHashTagsList, tweetId)
    state = Map.put(state, :hash_tags, updatedHashTagsMap)
    {:noreply, state}
  end
  # 9) set <mentions, tweet_ids>, if mention userId present then append the tweet_ids list otherwise create entry and add the list
  def handle_cast({:update_mentions, newMentionsList, tweetId}, state) do
    currentMentionsMap = Map.get(state, :mentions)
    updateMentionsMap = Utility.update_mentions_map(currentMentionsMap, newMentionsList, tweetId)
    state = Map.put(state, :mentions, updateMentionsMap)
    {:noreply, state}
  end

  def handle_cast(:print, state) do
    IO.inspect state, label: "elastic user_db state ->"
    {:noreply, state}
  end

end
