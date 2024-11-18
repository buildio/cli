require "io/console"
require "uuid"
require "term-spinner"
require "netrc"

# This command is used to login to the Build API. The Build API token is stored in
# the user's netrc file. Because the commandline needs the token, it does a three-way
# OAuth authentication. This command requests a login authorization from Build, then
# opens a browser to have the users OAuth-accept that authorization. Once the user
# accepts the authorization, the command polls the Build API to get the user's token.
module Build
  module Commands
    module App
      @[ACONA::AsCommand("apps:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("apps:list")
            .description("List the apps you have access to.")
            .option("team", "t", :optional, "Team.")
            # Allow --json to be passed in
            .option("json", "j", :none, "Output in JSON format.")
            .help("Apps are Build.io native applications that you have access to.")
            .aliases(["apps"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          team_id = input.option("team", type: String | Nil)
          apps = api.apps(team_id: team_id)
          if input.option("json", type: Bool)
            output.puts apps.to_json
          else
            if team_id
              output.puts "Apps for team #{team_id}:"
            else
              output.puts "Personal Apps you have access to:"
            end
            output.puts ""
            apps.each do |app|
              output.puts "  #{app.name} (#{app.id})"
            end
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("apps:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("apps:info")
            .description("Show the details of a specific application.")
            .argument("app", :optional, "The ID or NAME of the app to show.")
            .option("app", "a", :optional, "The app")
            .option("json", "j", :none, "Output in JSON format.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.argument("app", type: String | Nil) || input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app ID or NAME."
            return ACON::Command::Status::FAILURE
          end
          app = api.app(app_input)
          if input.option("json", type: Bool)
            output.puts app.to_json
          else
            output.puts "App details:"
            output.puts ""
            output.puts "  Name: #{app.name}"
            output.puts "  ID:   #{app.id}"
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("apps:create")]
      class Create < Base
        protected def configure : Nil
          self
            .name("apps:create")
            .description("Create a new application.")
            .argument("name", :required, "The name of the app to create.")
            .option("team", "t", :optional, "The team to create the app in.")
            .option("region", "r", :optional, "The region (default: #{self.default_region}).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Create a new application.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          name = input.argument("name", type: String)
          team_id = input.option("team", type: String | Nil)
          region = input.option("region", type: String | Nil) || self.default_region
          req = CreateAppRequest.new( name: name, team_id: team_id, region: region, description: nil )
          app = api.create_app(req)
          if input.option("json", type: Bool)
            output.puts app.to_json
          else
            output.puts "App created:"
            output.puts ""
            output.puts "  Name: #{app.name}"
            output.puts "  ID:   #{app.id}"
          end
          return ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end

