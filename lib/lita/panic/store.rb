module Lita::Panic
  class Store
    class << self
      def export_token_for user, redis:
        tokens = redis.hgetall "export_tokens"
        if token = tokens[user.id]
          token
        else
          token = SecureRandom.uuid
          redis.hset "export_tokens", user.id, token
          token
        end
      end

      def user_from_token token, redis:
        tokens = redis.hgetall "export_tokens"
        tokens.keys.find { |user_id| tokens[user_id] == token }
      end

      def polls_for_channel redis:, channel_id: nil
        redis.keys.
                select  { |k| k.start_with?("poll:#{channel_id}") }.
                map     { |k| Poll.new key: k, redis: redis }.
                sort_by { |p| p.created_at }
      end

      def to_csv redis:, channel: nil
        polls = polls_for_channel redis: redis, channel_id: channel

        user_ids = polls.map(&:responder_ids).flatten.uniq

        CSV.generate do |csv|
          csv << ["User"] + polls.map { |p| p.created_at.iso8601 }

          user_ids.each do |id|
            user = Lita::User.find_by_id id
            csv << [user.name] + polls.map { |poll| poll.response_from(id) }
          end
        end
      end
    end
  end
end
