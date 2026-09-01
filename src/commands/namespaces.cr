module Build
  module Commands
    module Namespace
      @[ACONA::AsCommand("namespaces:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("namespaces:list")
            .description(t("commands.namespaces.list.description"))
            .option("team", "t", :optional, t("commands.common.options.team"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.namespaces.list.help"))
            .aliases(["namespaces"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespaces = api.namespaces
          if input.option("json", type: Bool)
            output.puts namespaces.to_json
          else
            output.puts t("runtime.namespaces.list.header")
            output.puts ""
            namespaces.each do |namespace|
              output.puts "  #{namespace.name} (#{namespace.id})"
            end
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("namespaces:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("namespaces:info")
            .description(t("commands.namespaces.info.description"))
            .argument("namespace", :optional, t("commands.common.arguments.namespace"))
            .option("namespace", "t", :optional, t("commands.common.options.namespace"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.namespaces.info.help"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespace_input = input.argument("namespace", type: String | Nil) || input.option("namespace", type: String | Nil)
          if namespace_input.nil?
            output.puts t("runtime.errors.must_specify_namespace")
            return ACON::Command::Status::FAILURE
          end
          namespace = api.namespace(namespace_input)
          if input.option("json", type: Bool)
            output.puts namespace.to_json
          else
            output.puts t("runtime.namespaces.info.title", name: namespace.name, id: namespace.id)
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      # namespaces:create             Create a new namespace
      @[ACONA::AsCommand("namespaces:create")]
      class Create < Base
        protected def configure : Nil
          # Region defaults to us-east-1
          # Team defaults to personal team
          self
            .name("namespaces:create")
            .description(t("commands.namespaces.create.description"))
            .argument("name", :required, t("commands.namespaces.create.arguments.name"))
            .option("zone", "z", :required, t("commands.common.options.zone"))
            .option("team", "t", :optional, t("commands.namespaces.create.options.team"))
            .option("region", "r", :optional, t("commands.common.options.region", region: self.default_region))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.namespaces.create.help"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status

          region = input.option("region", type: String | Nil) || self.default_region
          zone_id = input.option("zone", type: String)
          name = input.argument("name")
          raise "Name must be a string" unless name.is_a?(String)

          req = CreateNamespaceRequest.new(
            name: name,
            zone_id: zone_id,
            team_id: input.option("team", type: String | Nil),
            description: nil,
            region: region
          )
          api.create_namespace(req)
          if input.option("json", type: Bool)
            output.puts({name: name, zone_id: zone_id, region: region}.to_json)
          else
            output.puts t("runtime.namespaces.create.created", name: name)
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      # namespaces:delete             Delete a namespace
      @[ACONA::AsCommand("namespaces:delete")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("namespaces:delete")
            .description(t("commands.namespaces.delete.description"))
            .argument("namespace", :required, t("commands.common.arguments.namespace"))
            .help(t("commands.namespaces.delete.help"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespace_input = input.argument("namespace", type: String | Nil) || input.option("namespace", type: String | Nil)
          if namespace_input.nil?
            output.puts t("runtime.errors.must_specify_namespace")
            return ACON::Command::Status::FAILURE
          end
          api.delete_namespace(namespace_input)
          return ACON::Command::Status::SUCCESS
        end
      end

    end
  end
end
