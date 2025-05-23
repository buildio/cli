require "./base"

module Build
  module Commands
    module ReviewApps
      @[ACONA::AsCommand("review-apps:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("review-apps:list")
            .description("list review apps for a pipeline")
            .argument("pipeline", :required, "pipeline name or ID")
            .option("json", "j", :none, "Output in JSON format")
            .help("Lists all review apps for a given pipeline")
            .aliases(["review-apps"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          pipeline_id = input.argument("pipeline", type: String)
          review_apps_api = Build::ReviewAppsApi.new
          review_apps = review_apps_api.list_review_apps(pipeline_id)

          if input.option("json", type: Bool)
            output.puts review_apps.to_json
          else
            if review_apps.empty?
              output.puts("No review apps found for this pipeline.")
            else
              output.puts("=== Review Apps for #{pipeline_id}")
              review_apps.each do |app|
                output.puts("#{app.name}")
              end
            end
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("review-apps:create")]
      class Create < Base
        protected def configure : Nil
          self
            .name("review-apps:create")
            .description("create a review app for a pipeline")
            .argument("pipeline", :required, "pipeline name or ID")
            .argument("branch", :required, "branch to build the review app from")
            .argument("pull_request_number", :required, "pull request number")
            .option("source-blob-url", nil, :optional, "URL to the source code archive")
            .option("title", nil, :optional, "title of the pull request")
            .option("description", nil, :optional, "description of the pull request")
            .option("github-repo", nil, :optional, "GitHub repository stub (owner/repo)")
            .option("stack", nil, :optional, "Stack to use for the app (e.g., heroku-24, heroku-22)")
            .option("env", nil, :optional, "environment variables for the app (JSON format)")
            .option("json", "j", :none, "Output in JSON format")
            .help("Creates a new review app for a pipeline from a pull request")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          pipeline_id = input.argument("pipeline", type: String)
          branch = input.argument("branch", type: String)
          pull_request_number = input.argument("pull_request_number", type: String).to_i

          environment = nil
          if env_json = input.option("env", type: String | Nil)
            environment = Hash(String, String).from_json(env_json)
          end

          request = Build::CreateReviewAppRequest.new(
            branch: branch,
            pull_request_number: pull_request_number,
            source_blob_url: input.option("source-blob-url", type: String | Nil),
            title: input.option("title", type: String | Nil),
            description: input.option("description", type: String | Nil),
            github_repo: input.option("github-repo", type: String | Nil),
            stack: input.option("stack", type: String | Nil),
            environment: environment
          )

          review_apps_api = Build::ReviewAppsApi.new
          app = review_apps_api.create_review_app(pipeline_id, request)

          if input.option("json", type: Bool)
            output.puts app.to_json
          else
            output.puts("Creating review app... done")
            output.puts("#{app.name}")
            output.puts("ID: #{app.id}")
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("review-apps:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("review-apps:info")
            .description("show detailed information for a review app")
            .argument("id", :required, "review app ID")
            .option("json", "j", :none, "Output in JSON format")
            .help("Displays information about a specific review app")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          review_app_id = input.argument("id", type: String)
          review_apps_api = Build::ReviewAppsApi.new
          app = review_apps_api.get_review_app(review_app_id)

          if input.option("json", type: Bool)
            output.puts app.to_json
          else
            output.puts("=== #{app.name}")
            output.puts("ID:          #{app.id}")
            output.puts("Region:      #{app.region}")
            output.puts("Stack:       #{app.stack}")
            output.puts("Team:        #{app.team.name}")
            if app.description
              output.puts("Description: #{app.description}")
            end
            if app.pipeline_stage
              output.puts("Stage:       #{app.pipeline_stage}")
            end
            output.puts("Created:     #{app.created_at}")
            output.puts("Updated:     #{app.updated_at}")
          end

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end

      @[ACONA::AsCommand("review-apps:delete")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("review-apps:delete")
            .description("delete a review app")
            .argument("id", :required, "review app ID")
            .option("confirm", nil, :optional, "app name to confirm deletion")
            .help("Deletes a specific review app")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          api  # Ensure authentication is set up
          review_app_id = input.argument("id", type: String)
          
          # Get app info first to show app name
          review_apps_api = Build::ReviewAppsApi.new
          app = review_apps_api.get_review_app(review_app_id)

          # Check for confirmation if required
          if confirm = input.option("confirm", type: String | Nil)
            if confirm != app.name
              output.puts("Confirmation #{confirm} did not match #{app.name}. Aborted.")
              return ACON::Command::Status::FAILURE
            end
          else
            output.puts("WARNING: This will delete the review app #{app.name}.")
            output.puts("To proceed, type \"#{app.name}\" or re-run this command with --confirm #{app.name}")
            return ACON::Command::Status::FAILURE
          end

          review_apps_api.delete_review_app(review_app_id)
          output.puts("Deleting #{app.name}... done")

          ACON::Command::Status::SUCCESS
        rescue ex : Exception
          output.puts ">".colorize(:red).to_s + "   Error: #{ex.message}"
          ACON::Command::Status::FAILURE
        end
      end
    end
  end
end 