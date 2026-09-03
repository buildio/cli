require "./base"

module Build
  module Commands
    module Builds
      TIME_FORMAT = "%Y-%m-%d %H:%M:%S %:z"

      def self.state(state : String) : String
        case state
        when "succeeded" then state.colorize(:green).to_s
        when "failed"    then state.colorize(:red).to_s
        else                  state.colorize(:yellow).to_s
        end
      end

      @[ACONA::AsCommand("builds:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("builds:list")
            .description(t("commands.builds.list.description"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("num", nil, :optional, t("commands.common.options.num"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.builds.list.help"))
            .aliases(["builds"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String?)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          limit = input.option("num", type: String?).try(&.to_i)
          builds = api.builds(app_input, limit)

          if input.option("json", type: Bool)
            output.puts builds.to_json
          elsif builds.empty?
            output.puts t("runtime.builds.none", app: app_input)
          else
            output.puts t("runtime.builds.title", app: app_input)
            output.puts ""
            rows = builds.map do |b|
              {
                b.id,
                b.state,
                (b.source_blob.try(&.version) || "")[0, 7],
                b.user.try(&.email) || "",
                b.created_at.to_s(TIME_FORMAT),
              }
            end
            print_table(output, {
              t("runtime.builds.headers.id"),
              t("runtime.builds.headers.state"),
              t("runtime.builds.headers.version"),
              t("runtime.builds.headers.user"),
              t("runtime.builds.headers.created"),
            }, rows)
          end
          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          print_api_error(output, ex)
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("builds:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("builds:info")
            .description(t("commands.builds.info.description"))
            .argument("build", :required, t("commands.builds.common.arguments.build"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.builds.info.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String?)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          build = api.build(app_input, input.argument("build", type: String))

          if input.option("json", type: Bool)
            output.puts build.to_json
          else
            blob = build.source_blob
            output.puts "#{"===".colorize(:light_gray)} #{t("runtime.builds.info.title", app: build.app.name || app_input).colorize.bold}"
            output.puts ""
            output.puts t("runtime.builds.info.id", value: build.id)
            output.puts t("runtime.builds.info.state", value: Builds.state(build.state))
            output.puts t("runtime.builds.info.user", value: build.user.try(&.email) || "")
            output.puts t("runtime.builds.info.source", value: blob.try(&.url) || "")
            output.puts t("runtime.builds.info.version", value: blob.try(&.version) || "")
            output.puts t("runtime.builds.info.description", value: blob.try(&.version_description) || "")
            output.puts t("runtime.builds.info.stack", value: build.stack)
            output.puts t("runtime.builds.info.buildpacks", value: (build.buildpacks || [] of ::Build::BuildBuildpacksInner).compact_map(&.url).join(", "))
            output.puts t("runtime.builds.info.created", value: build.created_at.to_s(TIME_FORMAT))
            output.puts t("runtime.builds.info.updated", value: build.updated_at.to_s(TIME_FORMAT))
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
