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
            .option("team", "t", :optional, "Team.")
            .option("json", "j", :none, "Output in JSON format")
            .help("Lists pipelines accessible to the current user")
            .aliases(["pipelines"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          team_id = input.option("team", type: String | Nil)
          pipelines = list_pipelines_with_team(team_id)

          if input.option("json", type: Bool)
            output.puts pipelines.to_json
          else
            if pipelines.empty?
              output.puts("You have no pipelines.")
            else
              if team_id
                output.puts("Pipelines for team #{team_id}:")
              else
                output.puts("Pipelines you have access to:")
              end
              output.puts("")
              pipelines.each do |pipeline|
                output.puts("  #{pipeline.name} (#{pipeline.id})")
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