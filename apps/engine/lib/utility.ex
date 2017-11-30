defmodule Utility do

  def isInteger(val) do
        try do
          _ = String.to_integer(val)
          true
        catch
          _what, _value -> 
            IO.puts "numNodes must be integer"
            false
        end
    end

  def print_valid_format_info do
    IO.puts "Valid format:"
    IO.puts "project3 numNodes numRequests"
    IO.puts "  numNodes: Integer type"
    IO.puts "  numRequests: Integer type"
  end

  def get_hash_tags(tweet) do
    tweetWordList = String.split(tweet, " ")
    find_hash_tags(tweetWordList, [])
  end

  defp find_hash_tags([], hash_tags) do
    hash_tags
  end

  defp find_hash_tags([word | restOfWords], hash_tags) do
    case String.starts_with?(word, "#") do
      true -> find_hash_tags(restOfWords, [ word | hash_tags])
      false -> find_hash_tags(restOfWords, hash_tags)
    end
  end

  def get_mentions(tweet) do
    tweetWordList = String.split(tweet, " ")
    find_mentions(tweetWordList, [])
  end

  defp find_mentions([], mentions) do
    mentions
  end

  defp find_mentions([word | restOfWords], mentions) do
    case String.starts_with?(word, "@") do
      true -> find_mentions(restOfWords, [ String.slice(word, 1..-1 )| mentions])
      false -> find_mentions(restOfWords, mentions)
    end
  end

  def update_hash_tags(hashTagMap, [], _tweet) do
    hashTagMap
  end
  def update_hash_tags(hashTagMap, [hashTag | hashTagsList], tweetId) do
    case Map.has_key?(hashTagMap, hashTag) do
      true->
        tweetIdList = Map.get(hashTagMap, hashTag)
        update_hash_tags(Map.put(hashTagMap, hashTag, [tweetId | tweetIdList]), hashTagsList, tweetId)
      false->
        update_hash_tags(Map.put(hashTagMap, hashTag, [tweetId]), hashTagsList, tweetId)
    end
  end

  def update_mentions(mentionsMap, [], _tweetId) do
    mentionsMap
  end

  def update_mentions(mentionsMap, [mention | mentionsList], tweetId) do
    case Map.has_key?(mentionsMap, mention) do
      true->
        tweetIdList = Map.get(mentionsMap, mention)
        update_mentions(Map.put(mentionsMap, mention, [tweetId | tweetIdList]), mentionsList, tweetId)
      false->
        update_mentions(Map.put(mentionsMap, mention, [tweetId]), mentionsList, tweetId)
    end
  end

  def update_hash_tag_map(hashTagsMap, [], _tweetId) do
    hashTagsMap
  end

  def update_hash_tag_map(hashTagsMap, [hashTag | newHashTagsList], tweetId) do
    updatedHashTagsMap = 
    case Map.has_key?(hashTagsMap, hashTag) do
      true ->
        tweetIdList = Map.get(hashTagsMap, hashTag)
        Map.put(hashTagsMap, hashTag, [tweetId | tweetIdList])
      false ->
        Map.put(hashTagsMap, hashTag, [tweetId])
    end
    update_hash_tag_map(updatedHashTagsMap, newHashTagsList, tweetId)
  end

  def update_mentions_map(mentionsMap, [], _tweetId) do
    mentionsMap
  end

  def update_mentions_map(mentionsMap, [mentions | newMentionsList], tweetId) do
    updatedMentionsMap = 
    case Map.has_key?(mentionsMap, mentions) do
      true ->
        tweetIdList = Map.get(mentionsMap, mentions)
        Map.put(mentionsMap, mentions, [tweetId | tweetIdList])
      false ->
        Map.put(mentionsMap, mentions, [tweetId])
    end
    update_hash_tag_map(updatedMentionsMap, newMentionsList, tweetId)
  end

  def update_mentions_with_tweet_id(commonDB, tweetId, mentionsList) do
    updatedUserDbMentionsMap =
    Enum.reduce(
      mentionsList,
      %{}, # initial value of accumulator
      fn (mentions, userDbMentionsMapAcc) ->
        userDbId = GenServer.call(commonDB, {:get_user_database_id, mentions})
        cond do
          userDbId == nil ->
            userDbMentionsMapAcc
          Map.has_key?(userDbMentionsMapAcc, userDbId) == true ->
            mentionsList = Map.get(userDbMentionsMapAcc, userDbId)
            Map.put(userDbMentionsMapAcc, userDbId, [mentions | mentionsList])
          Map.has_key?(userDbMentionsMapAcc, userDbId) == false ->
            Map.put(userDbMentionsMapAcc, userDbId, [mentions])
        end
      end
    )
    Enum.map(updatedUserDbMentionsMap, 
      fn({userDb, mentionsList})->
        GenServer.cast(userDb, {:update_mentions, mentionsList, tweetId})
      end)
  end

  def add_tweet_to_subscribers_feed(userDBId, tweetFromUserId, commonDB, tweetId, workerId) do
    subscribersList = GenServer.call(userDBId, {:get_subscribers, tweetFromUserId})
    dbIdSubscribersMap = 
    Enum.reduce(
      subscribersList,
      %{},
      fn(subscriber, mapAcc) ->
        dbId = GenServer.call(commonDB, {:get_user_database_id, subscriber})
        case Map.has_key?(mapAcc, dbId) do
          true ->
            currentSubscriberList = Map.get(mapAcc, dbId)
            Map.put(mapAcc, dbId, [subscriber | currentSubscriberList])
          false ->
            Map.put(mapAcc, dbId, [subscriber])
        end
      end
    )
    Enum.map(dbIdSubscribersMap,
      fn({dbId, subscribersList}) ->
        GenServer.cast(dbId, {:update_users_feed_return_active_list, tweetFromUserId, subscribersList, tweetId, workerId})
      end
    )
  end

  def send_tweet_to_clients(_tweetFromUserId, _createrUserId, _tweet, _tweetId, []) do

  end

  def send_tweet_to_clients(tweetFromUserId, createrUserId, tweet, tweetId, [clientPid | activeUsersPidList]) do
      GenServer.cast(clientPid, {:receive_tweet, tweetFromUserId, createrUserId, tweetId, tweet})
      send_tweet_to_clients(tweetFromUserId, createrUserId, tweet, tweetId, activeUsersPidList)
  end

  def get_recent_feed(_commonDB, [], _recentFeedSize, recentFeed) do
    recentFeed
  end
  def get_recent_feed(commonDB, [feedid | restOfFeedList], recentFeedSize, recentFeed) do
    cond do
      length(recentFeed) + 1 == recentFeedSize ->
        [GenServer.call(commonDB, {:get_tweet, feedId}) | recentFeed]
      true ->
        get_recent_feed(restOfFeedList, recentFeedSize, [GenServer.call(commonDB, {:get_tweet, feedId}) | recentFeed])
    end
  end

end
