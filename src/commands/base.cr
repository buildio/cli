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

      # Custom method to list pipelines with team filtering
      def list_pipelines_with_team(team_id : String | Nil)
        # Create a custom API call to support team filtering for pipelines
        local_var_path = "/api/v1/pipelines"
        query_params = Hash(String, String).new
        query_params["team_id"] = team_id.to_s unless team_id.nil?

        header_params = Hash(String, String).new
        header_params["Accept"] = "application/json"

        cookie_params = Hash(String, String).new
        form_params = Hash(Symbol, (String | ::File)).new
        post_body = nil
        auth_names = ["bearer"]

        data, status_code, headers = Build::ApiClient.default.call_api(
          :GET,
          local_var_path,
          :"DefaultApi.list_pipelines",
          "Array(Pipeline)",
          post_body,
          auth_names,
          header_params,
          query_params,
          cookie_params,
          form_params
        )

        Array(Build::Pipeline).from_json(data)
      end
    end
  end
end
