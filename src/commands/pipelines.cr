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
          error_msg = ex.message || ""
          if error_msg.blank? || error_msg == ""
            output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
            output.puts "      1. Is the server running? (rails server)"
            output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
            output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
            output.puts "      Debug: #{ex.class.name}"
          else
            output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
          end
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
            
            # Display environments if present
            if pipeline.responds_to?(:environments) && pipeline.environments
              envs = pipeline.environments
              if envs && !envs.empty?
                output.puts("Environments:")
                envs.each do |env|
                  if env.responds_to?(:kind) && env.responds_to?(:id)
                    kind_display = env.kind.to_s.upcase
                    output.puts("  #{kind_display}: #{env.id}")
                  end
                end
                output.puts("")
              end
            end
            
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
          error_msg = ex.message || ""
          if error_msg.blank? || error_msg == ""
            output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
            output.puts "      1. Is the server running? (rails server)"
            output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
            output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
            output.puts "      Debug: #{ex.class.name}"
          else
            output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
          end
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("pipelines:promote")]
      class Promote < Base
        protected def configure : Nil
          self
            .name("pipelines:promote")
            .option("app", "a", :required, "Source app to promote")
            .option("to", "t", :optional, "Comma-separated target app names (default: all downstream)")
            .option("no-wait", nil, :none, "Return immediately after creating the promotion")
            .option("json", "j", :none, "Output in JSON format")
            .description("promote the latest release of this app to its downstream app(s)")
            .help("Promotes the latest release from a source app to its downstream pipeline targets.\n\nExamples:\n  bld pipelines:promote -a my-app-staging\n  bld pipelines:promote -a my-app-staging --to my-app-prod,my-app-prod-eu\n  bld pipelines:promote -a my-app-staging --no-wait")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api
          json_mode = input.option("json", type: Bool)
          no_wait = input.option("no-wait", type: Bool)
          app_name = input.option("app", type: String)
          to_flag = input.option("to", type: String?) rescue nil

          # Resolve source app and its pipeline
          spinner = dots_spinner("Fetching app info")
          app = self.api.app(app_name)
          pipeline = app.pipeline
          unless pipeline && pipeline.id
            spinner.error("App #{app_name} is not in a pipeline")
            return ACON::Command::Status::FAILURE
          end
          pipeline_id = pipeline.id.not_nil!
          spinner.success

          # Build promotion request
          source = Build::CreatePipelinePromotionRequestSource.new(app: app_name)
          targets = if to_flag
                      to_flag.split(",").reject(&.empty?).map do |t|
                        Build::CreatePipelinePromotionRequestTargetsInner.new(app: t.strip)
                      end
                    else
                      nil
                    end
          request = Build::CreatePipelinePromotionRequest.new(source: source, targets: targets)

          # Create promotion
          promotions_api = Build::PipelinePromotionsApi.new
          target_desc = to_flag || "all downstream apps"
          spinner = dots_spinner("Promoting #{app_name} to #{target_desc}")
          promotion = promotions_api.create_pipeline_promotion(pipeline_id, request)
          spinner.success

          if no_wait
            if json_mode
              output.puts promotion.to_json
            else
              output.puts "Promotion #{promotion.id} created (status: #{promotion.status})"
            end
            return ACON::Command::Status::SUCCESS
          end

          # Poll until no longer pending
          spinner = dots_spinner("Waiting for promotion to complete")
          loop do
            break if promotion.status != "pending"
            sleep 1.5.seconds
            promotion = promotions_api.get_pipeline_promotion(pipeline_id, promotion.id)
          end
          spinner.success

          # Fetch and display targets
          promotion_targets = promotions_api.get_pipeline_promotion_targets(pipeline_id, promotion.id)

          if json_mode
            output.puts({promotion: promotion, targets: promotion_targets}.to_json)
          else
            any_failed = false
            name_width = 33
            status_width = 10

            output.puts ""
            output.puts((" app".ljust(name_width) + " status").colorize.bold)
            output.puts(" " + "─" * (name_width - 1) + " " + "─" * status_width)

            promotion_targets.each do |target|
              t_name = target.app.name || target.app.id || "unknown"
              t_status = target.status
              app_part = " ⬢ #{t_name}".colorize.fore(104_u8)
              visible_len = 2 + t_name.size
              padding = " " * ({name_width - visible_len, 1}.max)

              status_colored = case t_status
                               when "succeeded" then t_status.colorize(:green)
                               when "failed"    then t_status.colorize(:red)
                               else                  t_status.colorize(:yellow)
                               end
              line = "#{app_part}#{padding}#{status_colored}"
              if t_status == "failed" && target.error_message
                line = "#{line} — #{target.error_message}"
                any_failed = true
              end
              output.puts line
            end

            output.puts ""
            if any_failed
              output.puts "Promotion completed with failures.".colorize(:red)
            else
              output.puts "Promotion successful.".colorize(:green)
            end
          end

          if promotion_targets.any? { |t| t.status == "failed" }
            return ACON::Command::Status::FAILURE
          end
          ACON::Command::Status::SUCCESS
        rescue ex : Build::ApiError
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        rescue ex : Exception
          error_msg = ex.message || ""
          if error_msg.blank?
            output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
            output.puts "      1. Is the server running?"
            output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
            output.puts "      3. Is the API URL correct? Set BUILD_API_URL"
            output.puts "      Debug: #{ex.class.name}"
          else
            output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
          end
          ACON::Command::Status::FAILURE
        end
      end
    end
  end
end
