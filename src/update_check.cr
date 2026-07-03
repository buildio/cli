require "http/client"
require "json"
require "uri"
require "netrc"

module Build
  # Once-per-day GitHub release check. Fully silent on any failure. Records
  # every attempt (success or failure) so a bad network cannot cause every
  # invocation to re-fetch. Disable with BUILD_NO_UPDATE_CHECK=1.
  #
  # State is piggybacked onto ~/.netrc as a synthetic entry — no extra
  # dotfile for the user to find:
  #
  #   machine bld-update-check
  #     login  <RFC3339 timestamp of last attempt>
  #     password <latest release version, or "none" if the attempt failed>
  module UpdateCheck
    GITHUB_REPO    = "buildio/cli"
    RELEASE_URL    = "https://api.github.com/repos/#{GITHUB_REPO}/releases/latest"
    CACHE_TTL      = 24.hours
    # Deliberately tight — below the ~200ms "the tool is slow" threshold.
    TIMEOUT        = 200.milliseconds
    NETRC_MACHINE  = "bld-update-check"
    NO_VERSION     = "none"
    DISABLE_VAR    = "BUILD_NO_UPDATE_CHECK"

    def self.check!(current : String, io : IO = STDERR) : Nil
      return if disabled? || !(current =~ /^\d+\.\d+\.\d+/)
      latest = cached { fetched = fetch; record(fetched); fetched }
      io.puts notice(current, latest) if latest && newer?(latest, current)
    rescue
      # Never surface an error to the user.
    end

    def self.disabled? : Bool
      val = ENV[DISABLE_VAR]?
      !!val && !val.empty? && val != "0" && val.downcase != "false"
    end

    # Yields to fetch a fresh version only when the last attempt is stale
    # or missing. Returns the version to use (nil if last attempt failed).
    def self.cached(& : -> String?) : String?
      if (entry = read_entry) && Time.utc - entry[:checked_at] <= CACHE_TTL
        entry[:latest_version]
      else
        yield
      end
    end

    def self.read_entry : NamedTuple(checked_at: Time, latest_version: String?)?
      entry = Netrc.read[NETRC_MACHINE]
      return nil unless entry
      ts = Time.parse_rfc3339(entry.login)
      version = entry.password == NO_VERSION ? nil : entry.password
      {checked_at: ts, latest_version: version}
    rescue
      nil
    end

    def self.fetch : String?
      uri = URI.parse(RELEASE_URL)
      client = HTTP::Client.new(uri)
      client.connect_timeout = TIMEOUT
      client.read_timeout = TIMEOUT
      res = client.get(uri.request_target, headers: HTTP::Headers{
        "Accept" => "application/vnd.github+json", "User-Agent" => "bld-cli-update-check",
      })
      return nil unless res.status_code == 200
      JSON.parse(res.body)["tag_name"]?.try(&.as_s?).try(&.lchop("v"))
    rescue
      nil
    ensure
      client.try &.close rescue nil
    end

    # Records this attempt in ~/.netrc so failures don't retry until the
    # TTL elapses. Nil is stored as "none" (netrc password can't be empty).
    def self.record(latest : String?) : Nil
      netrc = Netrc.read
      netrc[NETRC_MACHINE] = {Time.utc.to_rfc3339, latest || NO_VERSION}
      netrc.save
    rescue
      # Missing / bad-permission / unwritable netrc — silently skip.
    end

    def self.newer?(latest : String, current : String) : Bool
      a = latest.split(/[-+]/, 2).first.split(".")
      b = current.split(/[-+]/, 2).first.split(".")
      {a.size, b.size}.max.times do |i|
        av, bv = a[i]?.try(&.to_i?) || 0, b[i]?.try(&.to_i?) || 0
        return true if av > bv
        return false if av < bv
      end
      false
    end

    private def self.notice(current : String, latest : String) : String
      String.build do |s|
        s << "\n  A new release of bld is available: "
        s << current.colorize(:yellow) << " → " << latest.colorize(:green) << "\n"
        s << "  https://github.com/" << GITHUB_REPO << "/releases/tag/v" << latest << "\n"
        s << "  Set BUILD_NO_UPDATE_CHECK=1 to disable this check.\n"
      end
    end
  end
end
