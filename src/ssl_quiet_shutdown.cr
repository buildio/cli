require "openssl"

# Alpine's statically-linked OpenSSL 3.3.1 raises during SSL_shutdown
# when the remote has already closed the TCP connection (common behind
# load-balancers). Dynamically-linked OpenSSL 3.6.2 handles it fine.
#
# Fix: set quiet shutdown at the context level so ALL sockets created
# from any context skip the close_notify handshake. This is what curl,
# Go, and Python do for HTTP clients.
lib LibSSL
  fun ssl_ctx_set_quiet_shutdown = SSL_CTX_set_quiet_shutdown(ctx : SSLContext, mode : LibC::Int)
end

class OpenSSL::SSL::Context::Client
  def initialize(method : LibSSL::SSLMethod = Context.default_method)
    previous_def
    LibSSL.ssl_ctx_set_quiet_shutdown(@handle, 1)
  end
end
