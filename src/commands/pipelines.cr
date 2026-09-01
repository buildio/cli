require "./base"

module Build
  module Commands
    module Pipeline
      @[ACONA::AsCommand("pipelines:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("pipelines:list")
            .description(t("commands.pipelines.list.description"))
            .option("team", "t", :required, t("commands.common.options.team"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.pipelines.list.help"))
            .usage(t("runtime.pipelines.list.usage"))
            .aliases(["pipelines"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          team_filter = input.option("team", type: String?)
          pipelines_api = Build::PipelinesApi.new
          pipelines = pipelines_api.list_pipelines(team_id: team_filter).sort_by(&.name)

          if input.option("json", type: Bool)
            output.puts pipelines.to_json
          else
            output.puts(t("runtime.pipelines.list.title"))
            output.puts("")
            pipelines.each do |pipeline|
              colored_symbol = "►".colorize.fore(46_u8).dim
              pipeline_name_colored = pipeline.name.colorize.fore(46_u8).dim
              output.puts("#{colored_symbol} #{pipeline_name_colored}")
            end
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          print_api_error(output, ex)
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("pipelines:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("pipelines:info")
            .description(t("commands.pipelines.info.description"))
            .argument("pipeline", :required, t("commands.common.arguments.pipeline"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.pipelines.info.help"))
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
            output.puts(t("runtime.pipelines.info.owner", owner: pipeline.team.name))
            output.puts("")
            
            # Display environments if present
            if pipeline.responds_to?(:environments) && pipeline.environments
              envs = pipeline.environments
              if envs && !envs.empty?
                output.puts(t("runtime.pipelines.info.environments"))
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
              output.puts(t("runtime.pipelines.info.no_apps"))
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
              
              output.puts((t("runtime.pipelines.headers.app_name").ljust(name_width) + t("runtime.pipelines.headers.stage").ljust(stage_width)).colorize.bold)
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
          print_api_error(output, ex)
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("pipelines:diff")]
      class Diff < Base
        protected def configure : Nil
          self
            .name("pipelines:diff")
            .option("app", "a", :required, t("commands.pipelines.diff.options.app"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .description(t("commands.pipelines.diff.description"))
            .help(t("commands.pipelines.diff.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api
          json_mode = input.option("json", type: Bool)
          app_name = input.option("app", type: String?) rescue nil
          if app_name.nil? || app_name.empty?
            print_error(output, t("runtime.errors.specify_app_with_app_flag"))
            return ACON::Command::Status::FAILURE
          end

          spinner = dots_spinner(t("runtime.pipelines.diff.fetching"))
          app = self.api.app(app_name)
          pipeline = app.pipeline
          unless pipeline && pipeline.id
            spinner.error(t("runtime.pipelines.app_not_in_pipeline", app: app_name))
            return ACON::Command::Status::FAILURE
          end
          pipeline_id = pipeline.id.not_nil!

          pipelines_api = Build::PipelinesApi.new
          diff_response = pipelines_api.get_pipeline_diff(pipeline_id, app_name)
          spinner.success

          if json_mode
            output.puts diff_response.to_json
            return ACON::Command::Status::SUCCESS
          end

          diffs = diff_response.diffs
          source_name = diff_response.source.try(&.name) || app_name

          if diffs.nil? || diffs.empty?
            output.puts t("runtime.pipelines.diff.no_downstream")
            return ACON::Command::Status::SUCCESS
          end

          diffs.each do |d|
            target_name = d.app.try(&.name) || "unknown"

            if d.status == "error"
              output.puts ""
              output.puts t("runtime.pipelines.diff.not_compared", source: source_name.colorize.fore(104_u8).to_s, target: target_name.colorize.fore(104_u8).to_s, error: d.error_message)
              next
            end

            ahead = d.ahead_by || 0
            behind = d.behind_by || 0
            commits = d.commits

            if ahead == 0 && behind == 0
              output.puts ""
              output.puts t("runtime.pipelines.diff.up_to_date", source: source_name.colorize.fore(104_u8).to_s, target: target_name.colorize.fore(104_u8).to_s)
              next
            end

            # Header
            output.puts ""
            parts = [] of String
            parts << t("runtime.pipelines.diff.ahead", count: ahead, plural: ahead != 1 ? "s" : "") if ahead > 0
            parts << t("runtime.pipelines.diff.behind", count: behind, plural: behind != 1 ? "s" : "") if behind > 0
            output.puts t("runtime.pipelines.diff.summary", source: source_name.colorize.fore(104_u8).to_s, changes: parts.join(", "), target: target_name.colorize.fore(104_u8).to_s)

            # Commit table
            if commits && !commits.empty?
              rows = commits.map do |c|
                {
                  (c.sha || "")[0, 7],
                  c.date || "",
                  c.author || "",
                  (c.message || "").split("\n").first,
                }
              end
              output.puts ""
              print_table(output, {t("runtime.pipelines.headers.sha"), t("runtime.pipelines.headers.date"), t("runtime.pipelines.headers.author"), t("runtime.pipelines.headers.message")}, rows)
            end
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Build::ApiError
          print_error(output, ex.message || "")
          ACON::Command::Status::FAILURE
        rescue ex : Exception
          print_api_error(output, ex, local_server_hint: false)
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("pipelines:promote")]
      class Promote < Base
        protected def configure : Nil
          self
            .name("pipelines:promote")
            .option("app", "a", :required, t("commands.pipelines.promote.options.app"))
            .option("to", "t", :optional, t("commands.pipelines.promote.options.to"))
            .option("no-wait", nil, :none, t("commands.pipelines.promote.options.no_wait"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .description(t("commands.pipelines.promote.description"))
            .help(t("commands.pipelines.promote.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api
          json_mode = input.option("json", type: Bool)
          no_wait = input.option("no-wait", type: Bool)
          app_name = input.option("app", type: String?) rescue nil
          if app_name.nil? || app_name.empty?
            print_error(output, t("runtime.errors.specify_app_with_app_flag"))
            return ACON::Command::Status::FAILURE
          end
          to_flag = input.option("to", type: String?) rescue nil

          # Resolve source app and its pipeline
          spinner = dots_spinner(t("runtime.pipelines.promote.fetching_app"))
          app = self.api.app(app_name)
          pipeline = app.pipeline
          unless pipeline && pipeline.id
            spinner.error(t("runtime.pipelines.app_not_in_pipeline", app: app_name))
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
          target_desc = to_flag || t("runtime.pipelines.promote.all_downstream")
          spinner = dots_spinner(t("runtime.pipelines.promote.promoting", app: app_name, target: target_desc))
          promotion = promotions_api.create_pipeline_promotion(pipeline_id, request)
          spinner.success

          if no_wait
            if json_mode
              output.puts promotion.to_json
            else
              output.puts t("runtime.pipelines.promote.created", id: promotion.id, status: promotion.status)
            end
            return ACON::Command::Status::SUCCESS
          end

          # Poll until no longer pending
          spinner = dots_spinner(t("runtime.pipelines.promote.waiting"))
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
            output.puts((t("runtime.pipelines.headers.app").ljust(name_width) + t("runtime.pipelines.headers.status")).colorize.bold)
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
              output.puts t("runtime.pipelines.promote.completed_with_failures").colorize(:red)
            else
              output.puts t("runtime.pipelines.promote.successful").colorize(:green)
            end
          end

          if promotion_targets.any? { |t| t.status == "failed" }
            return ACON::Command::Status::FAILURE
          end
          ACON::Command::Status::SUCCESS
        rescue ex : Build::ApiError
          print_error(output, ex.message || "")
          ACON::Command::Status::FAILURE
        rescue ex : Exception
          print_api_error(output, ex, local_server_hint: false)
          ACON::Command::Status::FAILURE
        end
      end
    end
  end
end
