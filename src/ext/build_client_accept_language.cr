require "build-client"
require "../i18n"

module Build
  # A request that has run this long gets one line on stderr saying so, when a
  # person is watching (stderr is a TTY) and -q was not given.
  SLOW_REQUEST_AFTER = 5.seconds

  def self.quiet?
    ARGV.includes?("-q") || ARGV.includes?("--quiet")
  end

  class ApiClient
    def call_api(http_method : Symbol, path : String, operation : Symbol, return_type : String?, post_body : String?, auth_names = [] of String, header_params = {} of String => String, query_params = {} of String => String, cookie_params = {} of String => String, form_params = {} of Symbol => (String | ::File))
      header_params["Accept-Language"] ||= ::Build::Locale.accept_language
      done = false
      spawn do
        sleep ::Build::SLOW_REQUEST_AFTER
        next if done || ::Build.quiet? || !STDERR.tty?
        STDERR.puts ::Build.t("runtime.slow_request", method: http_method.to_s.upcase, path: path,
          seconds: ::Build::SLOW_REQUEST_AFTER.total_seconds.to_i)
      end
      previous_def
    ensure
      done = true
    end
  end
end
