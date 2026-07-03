require "http/client"
require "json"
require "uri"
require "netrc"

module Build
  # Once-per-day GitHub release check. Fully silent on any failure. Records
  # every attempt (success or failure) so a bad network cannot cause every
  # invocation to re-fetch. Disable with BUILD_NO_UPDATE_CHECK=1.
  #
  # State is stored as an extended attribute on the user's ~/.netrc:
  #
  #   user.io.build.update-check = "<RFC3339 timestamp>|<version or 'none'>"
  #
  # This keeps the state cost-free (no extra dotfile, no separate lockfile)
  # and — critically — never touches the netrc's contents, so nothing we do
  # here can corrupt the user's auth tokens. Individual setxattr/getxattr
  # calls are atomic in the kernel, so no locking is needed either.
  #
  # Fallback strategy: if we can't persist the state (Windows, or a
  # filesystem like FAT/exFAT that returns ENOTSUP from setxattr), the
  # check is skipped entirely rather than run without back-off. Without a
  # working persistent cache we would otherwise hit GitHub on every
  # invocation, which is exactly the "hammering when offline" behavior
  # we're trying to avoid. Users on those platforms simply don't get
  # update notices — that's the correct trade.
  #
  # Startup latency is bounded by TOTAL_BUDGET. HTTP::Client's connect and
  # read timeouts don't cover the blocking getaddrinfo DNS lookup, so a
  # captive portal or dead resolver could otherwise hang startup for the OS
  # DNS timeout (many seconds). We work around this by running the fetch in
  # a fiber and racing it against `select`'s timeout, and by pre-recording
  # a "none" result *before* the fetch so back-off is guaranteed even if
  # the process is killed mid-hang.
  module UpdateCheck
    GITHUB_REPO  = "buildio/cli"
    RELEASE_URL  = "https://api.github.com/repos/#{GITHUB_REPO}/releases/latest"
    CACHE_TTL    = 24.hours
    # Wall-clock cap on how long we'll block the CLI waiting for the fetch.
    # If exceeded the fetch fiber keeps running in the background — it may
    # still populate the cache before the process exits, which surfaces the
    # notice on the next invocation.
    TOTAL_BUDGET = 700.milliseconds
    # Backup timeouts on the TCP connect and each socket read once DNS is done.
    IO_TIMEOUT   = 500.milliseconds
    # user.* namespace is required by Linux for non-root xattr writes and is
    # accepted by macOS without special handling.
    XATTR_NAME   = "user.io.build.update-check"
    NO_VERSION   = "none"
    DISABLE_VAR  = "BUILD_NO_UPDATE_CHECK"
    # Argv tokens that indicate a fast/non-interactive path where the check
    # would add user-visible latency for no benefit (shell completion) or
    # where the user is asking a specific quick question (--version / --help).
    SKIP_ARGV    = {"_complete", "--version", "-V", "--help", "-h"}

    def self.check!(current : String, io : IO = STDERR) : Nil
      return if disabled? || !interactive?(io) || fast_path?
      return unless current =~ /^\d+\.\d+\.\d+/
      entry = read_entry
      latest =
        if entry && Time.utc - entry[:checked_at] <= CACHE_TTL
          # Fresh — trust the record even if it's "none" (means the last
          # attempt failed and we're still within the back-off window).
          entry[:latest_version]
        else
          refresh
        end
      io.puts notice(current, latest) if latest && newer?(latest, current)
    rescue
      # Never surface an error to the user.
    end

    def self.disabled? : Bool
      val = ENV[DISABLE_VAR]?
      !!val && !val.empty? && val != "0" && val.downcase != "false"
    end

    # An interactive TTY is a prerequisite: notices to a redirected STDERR
    # would be invisible, and non-TTY contexts (CI, subshells running
    # completion) shouldn't pay the network latency.
    def self.interactive?(io : IO) : Bool
      io.responds_to?(:tty?) && io.tty?
    end

    # Skip on shell completion and on --version / --help, which are the
    # quick-answer paths where an extra HTTP round-trip is most annoying.
    def self.fast_path? : Bool
      ARGV.any? { |a| SKIP_ARGV.includes?(a) }
    end

    def self.read_entry : NamedTuple(checked_at: Time, latest_version: String?)?
      raw = read_xattr(netrc_path)
      return nil unless raw
      ts_str, sep, version = raw.partition('|')
      return nil if ts_str.empty? || sep.empty?
      ts = Time.parse_rfc3339(ts_str)
      latest = version == NO_VERSION ? nil : version
      {checked_at: ts, latest_version: latest}
    rescue
      nil
    end

    # Refresh the cached "latest" version with a strict wall-clock budget.
    # Pre-records "none" so a hang or DNS block that outlives startup still
    # counts toward back-off. The fetch fiber records its own result so that
    # if it eventually beats the process exit (but not our budget), the next
    # invocation still gets the notice.
    #
    # If the pre-record fails (xattrs unsupported), skip the network fetch
    # entirely: without a working back-off cache we'd hit GitHub on every
    # invocation, which is worse than not checking at all.
    def self.refresh : String?
      return nil unless record(nil)
      ch = Channel(String?).new(1)
      spawn do
        result = fetch
        record(result) if result
        ch.send(result)
      rescue
        ch.send(nil)
      end
      select
      when result = ch.receive
        result
      when timeout(TOTAL_BUDGET)
        nil
      end
    end

    def self.fetch : String?
      uri = URI.parse(RELEASE_URL)
      client = HTTP::Client.new(uri)
      client.connect_timeout = IO_TIMEOUT
      client.read_timeout = IO_TIMEOUT
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

    # Persists a new attempt as an xattr on the netrc file. Nil is stored as
    # "none" to distinguish "we tried and failed" from "we never tried".
    # Returns true iff the xattr was written; callers use false to mean
    # "we have no working back-off cache — skip the network entirely".
    def self.record(latest : String?) : Bool
      path = netrc_path
      # Ensure the netrc exists so we have something to attach an xattr to.
      # Match the perms bld login itself would create.
      unless File.exists?(path)
        File.open(path, "w", 0o600) { }
      end
      write_xattr(path, "#{Time.utc.to_rfc3339}|#{latest || NO_VERSION}")
    rescue
      false
    end

    def self.netrc_path : String
      Netrc.default_path
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

    # --- xattr syscall bindings ------------------------------------------
    #
    # Linux and macOS both expose setxattr/getxattr but with different
    # signatures (macOS has an extra `position` and `options`). Everything
    # else compiles to a no-op.

    {% if flag?(:darwin) %}
      # libSystem is already linked implicitly; no @[Link(...)] needed.
      lib LibXattr
        fun setxattr(path : LibC::Char*, name : LibC::Char*, value : Void*, size : LibC::SizeT, position : UInt32, options : Int32) : Int32
        fun getxattr(path : LibC::Char*, name : LibC::Char*, value : Void*, size : LibC::SizeT, position : UInt32, options : Int32) : LibC::SSizeT
      end
    {% elsif flag?(:linux) %}
      lib LibXattr
        fun setxattr(path : LibC::Char*, name : LibC::Char*, value : Void*, size : LibC::SizeT, flags : Int32) : Int32
        fun getxattr(path : LibC::Char*, name : LibC::Char*, value : Void*, size : LibC::SizeT) : LibC::SSizeT
      end
    {% end %}

    # Read the xattr as a UTF-8 string, or nil if absent / unsupported.
    def self.read_xattr(path : String) : String?
      {% if flag?(:darwin) || flag?(:linux) %}
        buf = Bytes.new(256)
        {% if flag?(:darwin) %}
          size = LibXattr.getxattr(path, XATTR_NAME, buf.to_unsafe.as(Void*), buf.size, 0_u32, 0)
        {% else %}
          size = LibXattr.getxattr(path, XATTR_NAME, buf.to_unsafe.as(Void*), buf.size)
        {% end %}
        return nil if size < 0
        String.new(buf[0, size.to_i])
      {% else %}
        nil
      {% end %}
    rescue
      nil
    end

    # Returns true iff the syscall succeeded. False signals to callers that
    # this platform/filesystem can't persist state, so the check should be
    # skipped rather than repeated without back-off.
    def self.write_xattr(path : String, value : String) : Bool
      {% if flag?(:darwin) || flag?(:linux) %}
        bytes = value.to_slice
        {% if flag?(:darwin) %}
          rc = LibXattr.setxattr(path, XATTR_NAME, bytes.to_unsafe.as(Void*), bytes.size, 0_u32, 0)
        {% else %}
          rc = LibXattr.setxattr(path, XATTR_NAME, bytes.to_unsafe.as(Void*), bytes.size, 0)
        {% end %}
        rc == 0
      {% else %}
        false
      {% end %}
    rescue
      false
    end
  end
end
