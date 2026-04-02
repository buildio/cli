module Build
  module Commands
    module Buildpacks
      def self.urls_from(installations : Array(BuildpackInstallation)) : Array(String)
        installations.sort_by(&.ordinal).map(&.buildpack.url)
      end

      def self.display(output, app_name : String, buildpacks : Array(String))
        if buildpacks.empty?
          output.puts "#{app_name} has no Buildpacks."
        else
          output.puts "=== #{app_name} Buildpack#{buildpacks.size == 1 ? "" : "s"}"
          output.puts ""
          buildpacks.each_with_index do |bp, i|
            output.puts "#{i + 1}. #{bp}"
          end
        end
      end

      def self.display_after_mutation(output, verb : String, app_name : String, buildpacks : Array(String))
        output.puts "Buildpack #{verb}."
        if buildpacks.empty?
          output.puts "#{app_name} has no Buildpacks."
        else
          output.puts "Next release on #{app_name} will use:"
          buildpacks.each_with_index do |bp, i|
            output.puts "  #{i + 1}. #{bp}"
          end
        end
      end

      def self.put_buildpacks(bp_api : Build::BuildpacksApi, app_id : String, urls : Array(String)) : Array(BuildpackInstallation)
        req = UpdateBuildpacksRequest.new(
          updates: urls.map { |u| UpdateBuildpacksRequestUpdatesInner.new(buildpack: u) }
        )
        bp_api.update_buildpacks(app_id, req)
      end

      @[ACONA::AsCommand("buildpacks:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("buildpacks:list")
            .description("List the buildpacks for an app.")
            .option("app", "a", :optional, "The app.")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Display the buildpacks configured for an application, in order.

            Example:
              $ bld buildpacks -a my-app
            HELP
            )
            .aliases(["buildpacks"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app with -a or --app."
            return ACON::Command::Status::FAILURE
          end
          installations = buildpacks_api.list_buildpacks(app_input)
          if input.option("json", type: Bool)
            output.puts installations.to_json
          else
            app = api.app(app_input)
            Buildpacks.display(output, app.name.not_nil!, Buildpacks.urls_from(installations))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:add")]
      class Add < Base
        protected def configure : Nil
          self
            .name("buildpacks:add")
            .description("Add a buildpack to an app.")
            .argument("buildpack", :required, "The buildpack URL or name to add.")
            .option("app", "a", :optional, "The app.")
            .option("index", "i", :optional, "1-based position to insert at.")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Append a buildpack to the list, or insert at a specific position with -i.

            Examples:
              $ bld buildpacks:add heroku/nodejs -a my-app
              $ bld buildpacks:add heroku/ruby -a my-app -i 1
            HELP
            )
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app with -a or --app."
            return ACON::Command::Status::FAILURE
          end
          buildpack = input.argument("buildpack", type: String)
          index_str = input.option("index", type: String | Nil)

          current = Buildpacks.urls_from(buildpacks_api.list_buildpacks(app_input))
          if current.includes?(buildpack)
            output.puts "The buildpack #{buildpack} is already set on #{app_input}."
            return ACON::Command::Status::FAILURE
          end

          if index_str
            idx = index_str.to_i - 1
            current.insert(idx.clamp(0, current.size), buildpack)
          else
            current << buildpack
          end

          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, current)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            app = api.app(app_input)
            Buildpacks.display_after_mutation(output, "added", app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:set")]
      class Set < Base
        protected def configure : Nil
          self
            .name("buildpacks:set")
            .description("Set a buildpack on an app.")
            .argument("buildpack", :required, "The buildpack URL or name to set.")
            .option("app", "a", :optional, "The app.")
            .option("index", "i", :optional, "1-based position to replace.")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Replace the first buildpack (or the one at a given index) with a new one.

            Examples:
              $ bld buildpacks:set heroku/nodejs -a my-app
              $ bld buildpacks:set heroku/ruby -a my-app -i 2
            HELP
            )
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app with -a or --app."
            return ACON::Command::Status::FAILURE
          end
          buildpack = input.argument("buildpack", type: String)
          index_str = input.option("index", type: String | Nil)

          current = Buildpacks.urls_from(buildpacks_api.list_buildpacks(app_input))
          idx = index_str ? index_str.to_i - 1 : 0

          if current.empty?
            current = [buildpack]
          elsif idx >= 0 && idx < current.size
            current[idx] = buildpack
          else
            output.puts "Invalid index: #{idx + 1}. App has #{current.size} buildpack#{current.size == 1 ? "" : "s"}."
            return ACON::Command::Status::FAILURE
          end

          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, current)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            app = api.app(app_input)
            Buildpacks.display_after_mutation(output, "set", app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:remove")]
      class Remove < Base
        protected def configure : Nil
          self
            .name("buildpacks:remove")
            .description("Remove a buildpack from an app.")
            .argument("buildpack", :optional, "The buildpack URL or name to remove.")
            .option("app", "a", :optional, "The app.")
            .option("index", "i", :optional, "1-based index of buildpack to remove.")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Remove a buildpack by name/URL or by index. Specify one, not both.

            Examples:
              $ bld buildpacks:remove heroku/nodejs -a my-app
              $ bld buildpacks:remove -i 2 -a my-app
            HELP
            )
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app with -a or --app."
            return ACON::Command::Status::FAILURE
          end
          buildpack = input.argument("buildpack", type: String | Nil)
          index_str = input.option("index", type: String | Nil)

          if buildpack && index_str
            output.puts "Specify a buildpack name or an index, not both."
            return ACON::Command::Status::FAILURE
          end
          if buildpack.nil? && index_str.nil?
            output.puts "Specify a buildpack name or use -i to specify an index."
            return ACON::Command::Status::FAILURE
          end

          current = Buildpacks.urls_from(buildpacks_api.list_buildpacks(app_input))

          if index_str
            idx = index_str.to_i - 1
            if idx < 0 || idx >= current.size
              output.puts "Invalid index: #{idx + 1}. App has #{current.size} buildpack#{current.size == 1 ? "" : "s"}."
              return ACON::Command::Status::FAILURE
            end
            current.delete_at(idx)
          else
            bp = buildpack.not_nil!
            unless current.includes?(bp)
              output.puts "Buildpack #{bp} is not set on #{app_input}."
              return ACON::Command::Status::FAILURE
            end
            current.delete(bp)
          end

          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, current)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            app = api.app(app_input)
            Buildpacks.display_after_mutation(output, "removed", app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:clear")]
      class Clear < Base
        protected def configure : Nil
          self
            .name("buildpacks:clear")
            .description("Clear all buildpacks for an app.")
            .option("app", "a", :optional, "The app.")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Remove all buildpacks from an application.

            Example:
              $ bld buildpacks:clear -a my-app
            HELP
            )
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts "You must specify an app with -a or --app."
            return ACON::Command::Status::FAILURE
          end
          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, [] of String)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            output.puts "Buildpacks cleared."
          end
          ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end
