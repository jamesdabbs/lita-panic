module Lita
  module Handlers
    class Panic < Handler
      config :hostname, type: String, required: false

      route \
        /how(?: i|\'|\’)s every\w+\s*(in \#([\w-]+))?/i,
        :poll,
        command: true,
        restrict_to: [:instructors],
        help: { "how's everyone (in #room)?" => "start a new panic poll" }
      route \
        /^\D*(?<score>\d)\D*$/,
        :answer,
        command: true
      route \
        /panic export\s*(\#([\.\w-]+))?/i,
        :export,
        command: true,
        restrict_to: [:instructors, :staff],
        help: { "panic export (#room)" => "get a CSV dump of panic scores" }

      http.get "/panic/:token(/:channel)" do |request, response|
        token = request.env["router.params"][:token]
        channel = request.env["router.params"][:channel]

        user  = Lita::Panic::Store.user_from_token token, redis: redis
        if user
          response.body << Lita::Panic::Store.to_csv(redis: redis, channel: channel)
        else
          response.status = 403
        end
      end


      def poll msg
        msg.reply "I don't know. I'll ask them."

        channel = channel_by(msg) {|m| m.matches[0][1]}

        responders = pollable_users_for_room(channel)

        Lita::Panic::Poll.create poster: msg.user, responders: responders, redis: redis, channel: channel
        responders.each { |user| ping_with_poll user, msg }
      end


      def answer msg
        poll = Lita::Panic::Poll.for user: msg.user, redis: redis
        return unless poll # Assume this is a false positive match?

        poll.record user: msg.user, response: msg.message.body
        msg.reply_privately "Roger, thanks for the feedback"

        notify_poster_of_complete_poll(poll) if poll.complete?

        score = msg.match_data[:score].to_i
        if score > 4
          username = msg.user.name || msg.user.mention_name
          robot.send_message Source.new(user: poll.poster),
            "FYI: #{username} is at a #{score}"
        end
      end


      def export msg
        token = Lita::Panic::Store.export_token_for(msg.user, redis: redis)
        room = msg.matches[0][0]
        path_component = room ? "/#{URI.encode room}" : nil
        msg.reply_privately "#{config.hostname}/panic/#{token}#{path_component}"
      end

      private

      def pollable_users_for_room(channel, without_members_of: ['staff'])
        users = robot.roster(channel).map { |user_id| Lita::User.find_by_id user_id }

        users.reject do |user|
          without_members_of.any? {|group| Lita::Authorization.new(config).user_in_group?(user, group)}
        end
      end

      def notify_poster_of_complete_poll(poll)
        msg =  "The results are in for <#{poll.channel.id}|#{poll.channel.name}>\n"
        msg += poll.user_responses.map do |(user, response)|
          "<@#{user.id}|#{user.name}>: #{response}"
        end.join("\n")

        robot.send_message Source.new(user: poll.poster), msg
      end

      def channel_by msg
        if name = yield(msg)
          Lita::Room.find_by_name name
        else
          msg.room
        end
      end

      def ping_with_poll user, response
        return if user.mention_name == robot.mention_name

        robot.send_message Source.new(user: user),
          "Hey, how are you doing (on a scale of 1 (boredom) to 6 (panic))?"
      rescue RuntimeError => e
        unless e.message =~ /cannot_dm_bot/
          response.reply_privately("Shoot, I couldn't reach #{user.mention_name} because we hit this bug `#{e.message}`")
        end
      end

      Lita.register_handler self
    end
  end
end
