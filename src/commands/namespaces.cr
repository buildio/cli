module Build
  module Commands
    module Namespace
      @[ACONA::AsCommand("namespaces:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("namespaces:list")
            .description("List the namespaces you are a member of")
            .option("team", "t", :optional, "The team ID or name.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Namespaces include namespaces that you are a member of, and namespaces that you own.")
            .aliases(["namespaces"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespaces = api.namespaces
          if input.option("json", type: Bool)
            output.puts namespaces.to_json
          else
            output.puts "Namespaces you have access to:"
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
            .description("Get information about a namespace")
            .argument("namespace", :optional, "The namespace ID or name")
            .option("namespace", "t", :optional, "The namespace.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Get information about a namespace.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespace_input = input.argument("namespace", type: String | Nil) || input.option("namespace", type: String | Nil)
          if namespace_input.nil?
            output.puts "You must specify a namespace ID or name."
            return ACON::Command::Status::FAILURE
          end
          namespace = api.namespace(namespace_input)
          if input.option("json", type: Bool)
            output.puts namespace.to_json
          else
            output.puts "Namespace: #{namespace.name} (#{namespace.id})"
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
            .description("Create a new namespace")
            .argument("name", :required, "The name of the namespace")
            .option("team", "t", :optional, "The team ID or name (default: personal).")
            .option("region", "r", :optional, "The region (default: #{self.default_region}).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Create a new namespace.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status

          region = input.option("region", type: String | Nil) || self.default_region
          name = input.argument("name")
          raise "Name must be a string" unless name.is_a?(String)

          #namespace = api.create_namespace(
          #  name: name,
          #  team_id: input.option("team", type: String | Nil),
          #  description: nil,
          #  region: region
          #)
          req = CreateNamespaceRequest.new(
            name: name,
            team_id: input.option("team", type: String | Nil),
            description: nil,
            region: region
          )
          namespace = api.create_namespace(req)
          
          if input.option("json", type: Bool)
            output.puts namespace.to_json
          else
            output.puts "Namespace created: #{namespace.name} (#{namespace.id})"
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
            .description("Delete a namespace")
            .argument("namespace", :required, "The namespace ID or name")
            .help("Delete a namespace.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          namespace_input = input.argument("namespace", type: String | Nil) || input.option("namespace", type: String | Nil)
          if namespace_input.nil?
            output.puts "You must specify a namespace ID or name."
            return ACON::Command::Status::FAILURE
          end
          api.delete_namespace(namespace_input)
          return ACON::Command::Status::SUCCESS
        end
      end

    end
  end
end
