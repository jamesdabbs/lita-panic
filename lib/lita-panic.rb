require "lita"
require "csv"
require "securerandom"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require_relative "./lita/panic/poll"
require_relative "./lita/panic/store"
require "lita/handlers/panic"

Lita::Handlers::Panic.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
