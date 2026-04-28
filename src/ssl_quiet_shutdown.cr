require "openssl"

# Tell OpenSSL to skip the bidirectional close_notify handshake when
# shutting down TLS connections. Without this, SSL_shutdown raises
# when the remote (typically a load-balancer) has already closed the
# TCP socket — even though the request completed successfully.
#
# This matches the behavior of curl, Go's net/http, and most HTTP
# clients. Real SSL errors (bad cert, connection refused, read/write
# failures) are unaffected — only the shutdown handshake is skipped.
lib LibSSL
  fun ssl_set_quiet_shutdown = SSL_set_quiet_shutdown(ssl : SSL, mode : LibC::Int)
end

class OpenSSL::SSL::Socket::Client
  def initialize(io, context : OpenSSL::SSL::Context::Client = OpenSSL::SSL::Context::Client.new, sync_close : Bool = false, hostname : String? = nil)
    previous_def
    LibSSL.ssl_set_quiet_shutdown(@ssl, 1)
  end
end
