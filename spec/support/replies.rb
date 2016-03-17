class TestMessage < SimpleDelegator
  attr_reader :to, :body

  def initialize to:, body:
                   @to, @body = to, body.clone.freeze
    super body
  end

  def inspect
    %|<Message("#{body}", to: #{to.user ? to.user.name : to.room.name})>|
  end

  def == other
    case other
    when String
      body == other
    when TestMessage
      to == other.to && body == other.body
    else
      raise "Can't compare #{self.class} with #{other.class}"
    end
  end
end

class Lita::Adapters::Test
  def send_messages _target, strings
    sent_messages.concat strings.map { |s| TestMessage.new to: _target, body: s }
  end
end

module Lita::RSpec::Handler
  def replies_to user
    replies.select { |r| r.to.user == user }
  end
end
