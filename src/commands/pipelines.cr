require "./base"

module Build
  module Commands
    module Pipeline
      @[ACONA::AsCommand("pipelines:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("pipelines:list")
            .description("list your pipelines")
            .option("json", "j", :none, "Output in JSON format")
            .help("Lists pipelines accessible to the current user")
            .aliases(["pipelines"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          pipelines_api = Build::PipelinesApi.new
          pipelines = pipelines_api.list_pipelines

          if input.option("json", type: Bool)
            output.puts pipelines.to_json
          else
            if pipelines.empty?
              output.puts("You have no pipelines.")
            else
              output.puts("=== Pipelines")
              pipelines.each do |pipeline|
                output.puts("#{pipeline.name}")
              end
            end
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("pipelines:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("pipelines:info")
            .description("show detailed information for a pipeline")
            .argument("pipeline", :required, "pipeline name or ID")
            .option("json", "j", :none, "Output in JSON format")
            .help("Displays information about a specific pipeline")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          pipeline_id = input.argument("pipeline", type: String)
          pipelines_api = Build::PipelinesApi.new
          pipeline = pipelines_api.get_pipeline(pipeline_id)

          if input.option("json", type: Bool)
            output.puts pipeline.to_json
          else
            output.puts("=== #{pipeline.name}")
            output.puts("ID:      #{pipeline.id}")
            output.puts("Team:    #{pipeline.team.name}")
            output.puts("Created: #{pipeline.created_at}")
            output.puts("Updated: #{pipeline.updated_at}")
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end
    end
  end
end 