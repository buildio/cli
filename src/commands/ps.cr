require "term-spinner"

module Build
  module Commands
    module Process
      @[ACONA::AsCommand("ps:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("ps:list")
            .description("List running processes for an application")
            .option("app", "a", :required, "The ID or NAME of the application")
            .help("List running processes for an application")
            .usage("ps -a <app>")
            .aliases(["ps", "ps:ls"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          dynos = api.list_dynos(app_name_or_id)
          unless dynos
            output.puts("<info>   No processes found for app #{app_name_or_id}</info>")
            return ACON::Command::Status::FAILURE
          end

          dynos.each do |dyno|
            # output.puts("=== #{app_name_or_id} Processes")
            output.puts("=== #{dyno._type.colorize.green.bold} (#{dyno.size.colorize.cyan.bold}): #{dyno.display.colorize.white.bold} (#{dyno.processes.size.colorize.yellow.bold})")
            dyno.processes.each do |process|
              # output.puts("  #{process.index}: #{process.status} (#{process.started_at}) #{process.restarts} restarts")
              # Specify the expected format of the timestamp (ISO 8601 in this example)
              started_at = Time.parse(process.started_at, "%Y-%m-%dT%H:%M:%S.%LZ", location: Time::Location::UTC)
              status = process.status == "Running" ? "up".colorize.green : "down".colorize.red

              # dotiw = (Time.utc - started_at).total_seconds.to_i.seconds
              dotiw = distance_of_time_in_words(started_at)

              output.puts "#{dyno._type.colorize(:white)}.#{process.index}: #{status} " +
                "#{started_at.to_s.colorize(:dark_gray)} (~ #{dotiw.colorize.yellow} ago)"

            end
            output.puts "" # Line break
          end
          return ACON::Command::Status::SUCCESS
        end
      end
      @[ACONA::AsCommand("ps:restart")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("ps:restart")
            .description("Restart processes on the application")
            .option("app", "a", :required, "The ID or NAME of the application")
            .argument("process", :optional, "The NAME of the process type to restart")
            .help("Restart processes on the application")
            .usage("ps:restart -a <app> [process]")
            .aliases(["restart"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          process_name = input.argument("process", type: String?)
          if process_name.nil?
            spin = "Restarting the application #{app_name_or_id}"
          else
            spin = "Restarting the #{process_name} process on the application #{app_name_or_id}"
          end
          spinner = dots_spinner(spin)
          if process_name.nil?
            api.restart_all_dynos(app_name_or_id)
          else
            api.restart_dynos(app_name_or_id, process_name)
          end
          spinner.success
          return ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end
