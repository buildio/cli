require "http/server"
require "./spec_helper"
require "../src/i18n"
require "../src/ext/build_client_accept_language"

private def with_locale_override(locale : String, &)
  previous = ENV[Build::Locale::OVERRIDE_VAR]?
  ENV[Build::Locale::OVERRIDE_VAR] = locale
  yield
ensure
  previous.try { |value| ENV[Build::Locale::OVERRIDE_VAR] = value } || ENV.delete(Build::Locale::OVERRIDE_VAR)
end

describe Build::ApiClient do
  it "sends Accept-Language on generated SDK calls" do
    received = Channel(String?).new(1)
    server = HTTP::Server.new do |context|
      received.send context.request.headers["Accept-Language"]?
      context.response.content_type = "application/json"
      context.response.print({"ok" => true}.to_json)
    end
    address = server.bind_tcp "127.0.0.1", 0

    spawn { server.listen }

    previous_host = Build::Configuration.default.host
    previous_scheme = Build::Configuration.default.scheme

    begin
      with_locale_override("ja") do
        Build.configure do |config|
          config.host = "#{address.address}:#{address.port}"
          config.scheme = "http"
        end

        Build::ApiClient.new.call_api(:GET, "/ping", :"Spec.ping", "String", nil)
        received.receive.should eq("ja")
      end
    ensure
      server.close
      Build.configure do |config|
        config.host = previous_host
        config.scheme = previous_scheme
      end
    end
  end
end
