require "term-spinner"

module Build
  module Commands
    module Process
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
