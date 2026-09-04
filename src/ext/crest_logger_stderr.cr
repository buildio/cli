require "crest"

# The SDK turns on Crest's request logging when debugging. Crest logs to STDOUT
# by default, which corrupts -j output; this is Crest's own initializer with
# the default IO switched to STDERR.
module Crest
  abstract class Logger
    def initialize(@io : IO = STDERR)
      backend = ::Log::IOBackend.new(@io, dispatcher: ::Log::DispatchMode::Sync)
      @logger = ::Log.new("crest", backend, ::Log::Severity::Info)
      @logger.backend.as(::Log::IOBackend).formatter = default_formatter
      @filters = [] of Tuple(String | Regex, String)
    end
  end
end
