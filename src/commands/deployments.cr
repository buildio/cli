require "./base"
require "./builds"

module Build
  module Commands
    module Deployments
      def self.state(state : String) : String
        case state
        when "deployed", "succeeded", "tested", "vibed" then state.colorize(:green).to_s
        when "failed"                                   then state.colorize(:red).to_s
        else                                                 state.colorize(:yellow).to_s
        end
      end

      def self.version(d : ::Build::Deployment) : String
        v = d.version ? "v#{d.version}" : ""
        d.current ? "#{v}*" : v
      end

      @[ACONA::AsCommand("deployments:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("deployments:list")
            .description(t("commands.deployments.list.description"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("num", nil, :optional, t("commands.common.options.num"))
            .option("all", nil, :none, t("commands.common.options.all"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.deployments.list.help"))
            .aliases(["deployments", "releases", "releases:list"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String?)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          limit = input.option("num", type: String?).try(&.to_i)
          deployments = [] of ::Build::Deployment
          cursor = nil
          loop do
            page, _status, headers = api.deployments_with_http_info(app_input, limit, cursor)
            deployments.concat(page)
            cursor = input.option("all", type: Bool) ? next_cursor(headers) : nil
            break if cursor.nil?
          end

          if input.option("json", type: Bool)
            output.puts deployments.to_json
          elsif deployments.empty?
            output.puts t("runtime.deployments.none", app: app_input)
          else
            output.puts t("runtime.deployments.title", app: app_input)
            output.puts ""
            rows = deployments.map do |d|
              {
                d.id,
                Deployments.version(d),
                d.state,
                (d.description || "").split("\n").first,
                d.user.try(&.email) || "",
                d.created_at.to_s(Builds::TIME_FORMAT),
              }
            end
            print_table(output, {
              t("runtime.deployments.headers.id"),
              t("runtime.deployments.headers.version"),
              t("runtime.deployments.headers.state"),
              t("runtime.deployments.headers.description"),
              t("runtime.deployments.headers.user"),
              t("runtime.deployments.headers.created"),
            }, rows)
            output.puts ""
            output.puts t("runtime.deployments.current_footnote")
          end
          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          print_api_error(output, ex)
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("deployments:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("deployments:info")
            .description(t("commands.deployments.info.description"))
            .argument("deployment", :required, t("commands.deployments.common.arguments.deployment"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.deployments.info.help"))
            .aliases(["releases:info"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String?)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          d = api.deployment(app_input, input.argument("deployment", type: String))

          if input.option("json", type: Bool)
            output.puts d.to_json
          else
            output.puts "#{"===".colorize(:light_gray)} #{t("runtime.deployments.info.title", app: d.app.name || app_input).colorize.bold}"
            output.puts ""
            output.puts t("runtime.deployments.info.id", value: d.id)
            output.puts t("runtime.deployments.info.version", value: d.version ? "v#{d.version}" : "")
            output.puts t("runtime.deployments.info.state", value: Deployments.state(d.state))
            output.puts t("runtime.deployments.info.current", value: d.current ? t("runtime.deployments.current_yes") : t("runtime.deployments.current_no"))
            output.puts t("runtime.deployments.info.build", value: d.build.try(&.id) || "")
            output.puts t("runtime.deployments.info.user", value: d.user.try(&.email) || "")
            output.puts t("runtime.deployments.info.description", value: d.description || "")
            output.puts t("runtime.deployments.info.created", value: d.created_at.to_s(Builds::TIME_FORMAT))
            output.puts t("runtime.deployments.info.updated", value: d.updated_at.to_s(Builds::TIME_FORMAT))
          end
          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          print_api_error(output, ex)
          ACON::Command::Status::FAILURE
        end
      end
    end
  end
end
