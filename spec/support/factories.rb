module Lita::RSpec::Handler
  def build_user name, groups: []
    @_user_id ||= 0
    @_user_id  += 1

    Lita::User.create(@_user_id, mention_name: name, name: name.capitalize).tap do |u|
      groups.each { |g| robot.auth.add_user_to_group! u, g }
    end
  end
end
