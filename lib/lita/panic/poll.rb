module Lita::Panic
  class Poll
    class << self
      def create poster:, responders:, redis:, channel:
        start    = Time.now.to_f
        finish   = start.to_i + 12 * 60 * 60
        poll_key = "poll:#{channel.id}:#{poster.id}:#{start}"

        values = responders.map { |r| [r.id, ""] }.flatten
        redis.hmset poll_key, *values
        responders.each { |r| redis.setex "open:#{r.id}", finish, poll_key }
      end

      def for user:, redis:
        key = redis.get "open:#{user.id}"
        Poll.new(key: key, redis: redis) if key
      end
    end

    def initialize key:, redis:
      @key, @redis = key, redis

      # Handle keys that include a channel
      if key.split(":").length == 4
        pref, @channel_id, @poster_id, @at = key.split ":"
      else
        # Backwards compatibility
        pref, @poster_id, @at = key.split ":"
      end

      raise "Invalid poll key: #{key}" unless pref == "poll"
    end

    # The user who asked the inital question.
    def poster
      @_poster ||= Lita::User.find_by_id(poster_id)
    end

    def channel
      @_channel ||= Lita::Room.find_by_id(channel_id)
    end

    def created_at
      @_created_at ||= Time.at Float(at)
    end

    def record user:, response:
      redis.hset key, user.id, response
      redis.del("open:#{user.id}")
    end

    def complete?
      missing = redis.hgetall(key).select { |id, response| response.empty? }
      (missing.keys - [poster_id.to_s]).empty?
    end

    def to_h
      @_to_h ||= redis.hgetall(key).freeze
    end

    def user_responses
      @_user_responses ||= to_h.each_with_object({}) do |(user_id, value), resp|
        resp[Lita::User.find_by_id(user_id)] = value
      end
    end

    def responder_ids
      redis.hkeys key
    end

    def response_from id
      to_h[id]
    end

    private

    attr_reader :key, :redis, :poster_id, :channel_id, :at
  end
end
