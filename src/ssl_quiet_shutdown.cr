require "openssl"

# Crystal's OpenSSL::SSL::Socket#unbuffered_close raises on any
# SSL_shutdown error that isn't WANT_READ, WANT_WRITE, or SYSCALL.
# Behind load-balancers that close TCP before TLS close_notify, this
# raises "decryption failed or bad record mac" even though the
# request completed. Patch unbuffered_close to treat all shutdown
# errors as non-fatal — matching curl, Go, and Python behavior.
# Real SSL errors (cert, connect, read, write) are unaffected.
abstract class OpenSSL::SSL::Socket < IO
  def unbuffered_close : Nil
    return if @closed
    @closed = true

    begin
      loop do
        ret = LibSSL.ssl_shutdown(@ssl)
        break if ret == 1
        break if ret == 0 && sync_close?
        break if ret < 0 # treat all shutdown errors as non-fatal
      end
    ensure
      if sync_close?
        bio.io.close
      end
    end
  end
end
