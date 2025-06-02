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
          pipelines = pipelines_api.list_pipelines.sort_by(&.name)

          if input.option("json", type: Bool)
            output.puts pipelines.to_json
          else
            output.puts("=== Pipelines")
            output.puts("")
            pipelines.each do |pipeline|
              colored_symbol = "►".colorize.fore(46_u8).dim
              pipeline_name_colored = pipeline.name.colorize.fore(46_u8).dim
              output.puts("#{colored_symbol} #{pipeline_name_colored}")
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
          apps = pipelines_api.list_pipeline_apps(pipeline_id).sort_by(&.name)

          if input.option("json", type: Bool)
            output.puts({pipeline: pipeline, apps: apps}.to_json)
          else
            output.puts("#{"===".colorize(:light_gray)} #{pipeline.name.colorize.bold}")
            output.puts("")
            output.puts("owner: #{pipeline.team.name} (team)")
            output.puts("")
            
            if apps.empty?
              output.puts("No apps found in this pipeline.")
            else
              # Sort by stage priority (review, staging, production), then by name
              stage_order = {"production" => 4, "staging" => 3, "development" => 2, "review" => 1}
              sorted_apps = apps.sort_by { |app| 
                stage = app.pipeline_stage || "unknown"
                stage_priority = stage_order[stage]? || 99
                {stage_priority, app.name}
              }
              
              # Calculate column width for app names - match Heroku's 33 char width
              name_width = 33
              stage_width = 10
              
              output.puts((" app name".ljust(name_width) + " stage".ljust(stage_width)).colorize.bold)
              output.puts(" " + "─" * (name_width - 1) + " " + "─" * stage_width)
              
              sorted_apps.each do |app|
                stage = app.pipeline_stage || "unknown"
                app_name_part = " ⬢ #{app.name}".colorize.fore(104_u8)
                stage_part = stage.ljust(stage_width)
                # Calculate padding needed after the colored app name
                visible_length = 2 + app.name.size  # " ⬢ " + name length
                padding = " " * (name_width - visible_length)
                output.puts("#{app_name_part}#{padding}#{stage_part}")
              end
            end
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