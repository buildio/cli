module Build
  module Commands
    module Buildpacks
      def self.urls_from(installations : Array(BuildpackInstallation)) : Array(String)
        installations.sort_by(&.ordinal).map(&.buildpack.url)
      end

      def self.display(output, app_name : String, buildpacks : Array(String))
        if buildpacks.empty?
          output.puts Build.t("runtime.buildpacks.none", app: app_name)
        else
          output.puts Build.t("runtime.buildpacks.title", app: app_name, plural: buildpacks.size == 1 ? "" : "s")
          output.puts ""
          buildpacks.each_with_index do |bp, i|
            output.puts "#{i + 1}. #{bp}"
          end
        end
      end

      def self.display_after_mutation(output, verb : String, app_name : String, buildpacks : Array(String))
        output.puts Build.t("runtime.buildpacks.mutated", verb: verb)
        if buildpacks.empty?
          output.puts Build.t("runtime.buildpacks.none", app: app_name)
        else
          output.puts Build.t("runtime.buildpacks.next_release", app: app_name)
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
            .description(t("commands.buildpacks.list.description"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.buildpacks.list.help"))
            .aliases(["buildpacks"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
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
            .description(t("commands.buildpacks.add.description"))
            .argument("buildpack", :required, t("commands.buildpacks.common.arguments.buildpack"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("index", "i", :optional, t("commands.buildpacks.common.options.index_insert"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.buildpacks.add.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          buildpack = input.argument("buildpack", type: String)
          index_str = input.option("index", type: String | Nil)

          current = Buildpacks.urls_from(buildpacks_api.list_buildpacks(app_input))
          if current.includes?(buildpack)
            output.puts t("runtime.buildpacks.already_set", buildpack: buildpack, app: app_input)
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
            Buildpacks.display_after_mutation(output, t("runtime.verbs.added"), app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:set")]
      class Set < Base
        protected def configure : Nil
          self
            .name("buildpacks:set")
            .description(t("commands.buildpacks.set.description"))
            .argument("buildpack", :required, t("commands.buildpacks.common.arguments.buildpack"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("index", "i", :optional, t("commands.buildpacks.common.options.index_replace"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.buildpacks.set.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
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
            output.puts t("runtime.buildpacks.invalid_index", index: idx + 1, count: current.size, plural: current.size == 1 ? "" : "s")
            return ACON::Command::Status::FAILURE
          end

          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, current)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            app = api.app(app_input)
            Buildpacks.display_after_mutation(output, t("runtime.verbs.set"), app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:remove")]
      class Remove < Base
        protected def configure : Nil
          self
            .name("buildpacks:remove")
            .description(t("commands.buildpacks.remove.description"))
            .argument("buildpack", :optional, t("commands.buildpacks.common.arguments.buildpack"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("index", "i", :optional, t("commands.buildpacks.common.options.index_remove"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.buildpacks.remove.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          buildpack = input.argument("buildpack", type: String | Nil)
          index_str = input.option("index", type: String | Nil)

          if buildpack && index_str
            output.puts t("runtime.buildpacks.specify_name_or_index_not_both")
            return ACON::Command::Status::FAILURE
          end
          if buildpack.nil? && index_str.nil?
            output.puts t("runtime.buildpacks.specify_name_or_index")
            return ACON::Command::Status::FAILURE
          end

          current = Buildpacks.urls_from(buildpacks_api.list_buildpacks(app_input))

          if index_str
            idx = index_str.to_i - 1
            if idx < 0 || idx >= current.size
              output.puts t("runtime.buildpacks.invalid_index", index: idx + 1, count: current.size, plural: current.size == 1 ? "" : "s")
              return ACON::Command::Status::FAILURE
            end
            current.delete_at(idx)
          else
            bp = buildpack.not_nil!
            unless current.includes?(bp)
              output.puts t("runtime.buildpacks.not_set", buildpack: bp, app: app_input)
              return ACON::Command::Status::FAILURE
            end
            current.delete(bp)
          end

          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, current)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            app = api.app(app_input)
            Buildpacks.display_after_mutation(output, t("runtime.verbs.removed"), app.name.not_nil!, Buildpacks.urls_from(result))
          end
          ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("buildpacks:clear")]
      class Clear < Base
        protected def configure : Nil
          self
            .name("buildpacks:clear")
            .description(t("commands.buildpacks.clear.description"))
            .option("app", "a", :optional, t("commands.common.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.buildpacks.clear.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_input = input.option("app", type: String | Nil)
          if app_input.nil?
            output.puts t("runtime.errors.must_specify_app_option")
            return ACON::Command::Status::FAILURE
          end
          result = Buildpacks.put_buildpacks(buildpacks_api, app_input, [] of String)
          if input.option("json", type: Bool)
            output.puts result.to_json
          else
            output.puts t("runtime.buildpacks.cleared")
          end
          ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end
