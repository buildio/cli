require "build-client"

module Build
  module Commands
    class Base < ACON::Command
      def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : Athena::Console::Command::Status
        raise "NotImplementedError"
      end
      def token : String | Nil
        ENV.fetch("BUILD_API_KEY", nil) || Netrc.read[Build.api_host].try &.password
      end
      def default_region : String
        ENV.fetch("BUILD_DEFAULT_REGION", "us-east-1")
      end
      def api : Build::DefaultApi
        user_token = ENV.fetch("BUILD_API_KEY", nil)
        ent = Netrc.read[Build.api_host]
        user_token ||= ent.password if ent
        if user_token.nil?
          puts ">".colorize(:red).to_s + "   Error: not logged in"
          exit(1)
        end

        # Host, scheme, and debugging are set globally.
        # We only need to configure the access_token here.
        Build.configure do |config|
          config.access_token = user_token
        end

        # Configure the API client
        @api_instance = Build::DefaultApi.new
      end
    end
  end
end
