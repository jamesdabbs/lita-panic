require "simplecov"
require "coveralls"
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start { add_filter "/spec/" }

require "lita-panic"
require "lita/rspec"

begin
  require "pry"
rescue LoadError
end

require_relative "./support/factories"
require_relative "./support/replies"

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.warnings = false
  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  # config.profile_examples = ENV.fetch("RSPEC_PROFILE_COUNT", 10).to_i
  config.order = :random
  Kernel.srand config.seed
end
