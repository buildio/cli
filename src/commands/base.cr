require "build-client"
require "../display_width"
require "uri"

module Build
  module Commands
    class Base < ACON::Command
      def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : Athena::Console::Command::Status
        raise "NotImplementedError"
      end
      def token : String | Nil
        ENV.fetch("BUILD_API_KEY", nil) || Netrc.read[::Build.api_host].try &.password
      end
      def default_region : String
        ENV.fetch("BUILD_DEFAULT_REGION", "us-east-1")
      end
      def api : ::Build::DefaultApi
        user_token = ENV.fetch("BUILD_API_KEY", nil)
        ent = Netrc.read[::Build.api_host]
        user_token ||= ent.password if ent
        if user_token.nil?
          puts ">".colorize(:red).to_s + "   " + ::Build.t("runtime.errors.not_logged_in")
          exit(1)
        end

        # Host, scheme, and debugging are set globally.
        # We only need to configure the access_token here.
        ::Build.configure do |config|
          config.access_token = user_token
        end

        # Configure the API client
        @api_instance = ::Build::DefaultApi.new
      end

      def buildpacks_api : ::Build::BuildpacksApi
        api # ensure access_token is configured
        ::Build::BuildpacksApi.new
      end
      def t(message_key : String | Symbol, params : Hash | NamedTuple | Nil = nil) : String
        ::Build.t(message_key, params)
      end

      def t(message_key : String | Symbol, **kwargs) : String
        ::Build.t(message_key, kwargs)
      end

      def print_error(output : ACON::Output::Interface, message : String) : Nil
        output.puts ">".colorize(:red).to_s + "   " + t("runtime.errors.error", message: message)
      end

      def print_api_request_failed(output : ACON::Output::Interface, ex : Exception, local_server_hint : Bool = true) : Nil
        output.puts ">".colorize(:red).to_s + "   " + t("runtime.errors.api_request_failed")
        output.puts "      " + t(local_server_hint ? "runtime.errors.check_server_rails" : "runtime.errors.check_server")
        output.puts "      " + t("runtime.errors.check_token")
        output.puts "      " + t(local_server_hint ? "runtime.errors.check_api_url_local" : "runtime.errors.check_api_url")
        output.puts "      " + t("runtime.errors.debug", class_name: ex.class.name)
      end

      def print_api_error(output : ACON::Output::Interface, ex : Exception, local_server_hint : Bool = true) : Nil
        error_msg = ex.message || ""
        if error_msg.blank? || error_msg == ""
          print_api_request_failed(output, ex, local_server_hint)
        else
          print_error(output, error_msg)
        end
      end

      # Cursor from an RFC 8288 Link header's rel="next" URL, or nil on the last page.
      def next_cursor(headers : Hash(String, Array(String) | String)) : String?
        link = headers["Link"]? || headers["link"]?
        link = link.join(",") if link.is_a?(Array)
        link.try &.split(",").each do |part|
          next unless part.includes?(%(rel="next"))
          url = part[/<([^>]+)>/, 1]?
          return URI.parse(url).query_params["cursor"]? if url
        end
        nil
      end

      def print_table(output : ACON::Output::Interface, headers : Tuple, rows : Array(Tuple))
        widths = Array(Int32).new(headers.size, 0)
        headers.each_with_index { |h, i| widths[i] = {widths[i], ::Build.display_width(h.to_s)}.max }
        rows.each do |row|
          row.each_with_index { |val, i| widths[i] = {widths[i], ::Build.display_width(val.to_s)}.max if i < widths.size }
        end
        output.puts headers.each_with_index.map { |header, i| i == widths.size - 1 ? header.to_s : ::Build.ljust_display(header.to_s, widths[i]) }.join("  ")
        output.puts widths.map { |w| "─" * w }.join("  ")
        rows.each do |row|
          output.puts row.each_with_index.map { |val, i| i == widths.size - 1 ? val.to_s : ::Build.ljust_display(val.to_s, widths[i]) }.join("  ")
        end
      end
    end
  end
end
