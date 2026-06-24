module Build
  # Lenient parsing of API timestamps for display.
  #
  # The API returns ISO 8601 / RFC 3339 timestamps, but the exact shape varies
  # (with or without fractional seconds, `Z` vs a numeric offset). Parsing with
  # a single hardcoded format string raises on any variant it doesn't match,
  # which previously crashed whole listings (e.g. `ps`) on one odd row.
  #
  # `parse?` accepts any ISO 8601 timestamp and returns `nil` on anything it
  # can't parse, so callers can degrade gracefully instead of raising.
  module TimeFormat
    def self.parse?(value : String?) : Time?
      return nil if value.nil? || value.empty?
      Time.parse_iso8601(value)
    rescue Time::Format::Error | ArgumentError
      # Time::Format::Error: malformed input. ArgumentError: well-formed but
      # out-of-range (e.g. "2024-02-30T..." or hour 25), which parse_iso8601
      # raises from Time.local after tokenizing successfully.
      nil
    end
  end
end
