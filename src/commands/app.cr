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
            .description(t("commands.apps.list.description"))
            .option("team", "t", :optional, t("commands.common.options.team"))
            # Allow --json to be passed in
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.apps.list.help"))
            .aliases(["apps"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          team_id = input.option("team", type: String | Nil)
          apps = api.apps(team_id: team_id)
          if input.option("json", type: Bool)
            output.puts apps.to_json
          else
            if team_id
              output.puts t("runtime.apps.list.team_header", team: team_id)
            else
              output.puts t("runtime.apps.list.personal_header")
            end
            output.puts ""
            apps.each do |app|
              output.puts "  #{app.name} (#{app.id})"
            end
            if !team_id
              output.puts ""
              output.puts t("runtime.apps.list.team_hint")
              output.puts t("runtime.apps.list.teams_hint")
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
            .description(t("commands.apps.info.description"))
            .argument("app", :optional, t("commands.common.arguments.app"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.argument("app", type: String | Nil) || input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_id_or_name")
            return ACON::Command::Status::FAILURE
          end
          app = api.app(app_input)
          if input.option("json", type: Bool)
            output.puts app.to_json
          else
            output.puts "=== #{app.name}"
            output.puts t("runtime.labels.git_url", value: app.git_url) if app.git_url
            output.puts t("runtime.labels.region", value: app.region)
            output.puts t("runtime.labels.stack", value: app.stack || app.build_stack)
            output.puts t("runtime.labels.web_url", value: app.web_url) if app.web_url
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("apps:create")]
      class Create < Base
        protected def configure : Nil
          self
            .name("apps:create")
            .description(t("commands.apps.create.description"))
            .argument("name", :required, t("commands.apps.create.arguments.name"))
            .option("team", "t", :optional, t("commands.apps.create.options.team"))
            .option("region", "r", :optional, t("commands.common.options.region", region: self.default_region))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.apps.create.help"))
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
            output.puts t("runtime.apps.create.created")
            output.puts ""
            output.puts t("runtime.labels.indented_name", value: app.name)
            output.puts t("runtime.labels.indented_id", value: app.id)
            output.puts t("runtime.labels.indented_git_url", value: app.git_url) if app.git_url
            output.puts t("runtime.labels.indented_web_url", value: app.web_url) if app.web_url
          end
          return ACON::Command::Status::SUCCESS
        end
      end
      @[ACONA::AsCommand("apps:stacks")]
      class Stacks < Base
        protected def configure : Nil
          self
            .name("apps:stacks")
            .description(t("commands.apps.stacks.description"))
            .argument("app", :optional, t("commands.common.arguments.app"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .help(t("commands.apps.stacks.help"))
            .aliases(["stack"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.argument("app", type: String | Nil) || input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_id_or_name")
            return ACON::Command::Status::FAILURE
          end
          app = api.app(app_input)
          output.puts "#{app.stack}"
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("apps:stacks:set")]
      class StacksSet < Base
        protected def configure : Nil
          self
            .name("apps:stacks:set")
            .description(t("commands.apps.stacks_set.description"))
            .argument("stack", :required, t("commands.apps.stacks_set.arguments.stack"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .help(t("commands.apps.stacks_set.help"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          stack = input.argument("stack", type: String)
          req = UpdateAppRequest.new(build_stack: stack)
          app = api.update_app(app_input, req)
          output.puts t("runtime.apps.stacks_set.success", stack: app.stack, app: app.name)
          return ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end

