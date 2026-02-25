require "term-spinner"
require "http/web_socket"
require "base64"

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
            .option("json", "j", :none, "Output in JSON format")
            .help("List running processes for an application")
            .usage("ps -a <app> [-j]")
            .aliases(["ps", "ps:ls"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          json_output = input.option("json", type: Bool?) || false

          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          dynos = api.list_dynos(app_name_or_id)
          unless dynos
            if json_output
              output.puts("[]")
            else
              output.puts("<info>   No processes found for app #{app_name_or_id}</info>")
            end
            return ACON::Command::Status::FAILURE
          end

          if json_output
            output.puts(dynos.to_json)
            return ACON::Command::Status::SUCCESS
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

              entry = "#{dyno._type.colorize(:white)}.#{process.index}: #{status} " +
                "#{started_at.to_s.colorize(:dark_gray)} (~ #{dotiw.colorize.yellow} ago)"


              restarts     = process.restarts
              restarted_at = process.restarted_at
              if restarted_at && restarts && restarts > 0
                entry += " #{process.restarts} restarts"
                restarted_at_time = Time.parse(restarted_at, "%Y-%m-%dT%H:%M:%S.%LZ", location: Time::Location::UTC)
                dotiw = distance_of_time_in_words(restarted_at_time)
                entry += " (last at #{restarted_at.to_s.colorize(:dark_gray)} ~ #{dotiw.colorize.yellow} ago)"
              end
              output.puts entry
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
      @[ACONA::AsCommand("ps:exec")]
      class Exec < Base
        protected def configure : Nil
          self
            .name("ps:exec")
            .description("Execute a command in a running dyno")
            .option("app", "a", :required, "The ID or NAME of the application")
            .option("dyno", "d", :required, "The NAME of the dyno (e.g. web.1) to exec into")
            .option("status", "s", :none, "Show exec readiness for all dynos")
            .argument("CMD", ACON::Input::Argument::Mode[:optional, :is_array], "Command to run inside the dyno")
            .help("Execute a command in a running dyno.\n\nWith no CMD, opens an interactive bash session.\nWith CMD, executes the command and returns output.\nWith --status, shows exec readiness per dyno.")
            .usage("ps:exec -a <app> -d <dyno> -- ls -l")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)

          if input.option("status", type: Bool?)
            return self.exec_status(app_name_or_id, output)
          end

          dyno_name = input.option("dyno", type: String)

          if app_name_or_id.blank? || dyno_name.blank?
            output.puts("<error>   Missing required options --app and/or --dyno</error>")
            return ACON::Command::Status::FAILURE
          end

          command_parts = input.argument("CMD", type: Array(String))

          if command_parts.empty? && STDIN.tty?
            return self.interactive_exec(app_name_or_id, dyno_name, output)
          end

          if command_parts.empty?
            output.puts("<error>   No command specified and stdin is not a TTY</error>")
            return ACON::Command::Status::FAILURE
          end

          # Non-interactive: existing HTTP POST path
          spinner = dots_spinner("Executing '#{command_parts.join(" ")}' on #{dyno_name}")
          begin
            response_body = self.exec_dyno(app_name_or_id, dyno_name, command_parts)
            spinner.success
            output.puts response_body
            ACON::Command::Status::SUCCESS
          rescue ex : Exception
            spinner.error
            output.puts("<error>   #{ex.message}</error>")
            ACON::Command::Status::FAILURE
          end
        end

        private def exec_status(app_id : String, output : ACON::Output::Interface) : ACON::Command::Status
          if app_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          dynos = api.list_dynos(app_id)
          unless dynos
            output.puts("<info>   No processes found</info>")
            return ACON::Command::Status::SUCCESS
          end
          dynos.each do |dyno|
            dyno.processes.each do |process|
              status = process.status == "Running" ? "ready".colorize.green : "not ready".colorize.red
              output.puts "#{dyno._type}.#{process.index}: #{status}"
            end
          end
          ACON::Command::Status::SUCCESS
        end

        private def interactive_exec(app_id : String, dyno : String, output : ACON::Output::Interface) : ACON::Command::Status
          user_token = self.token
          unless user_token
            output.puts("<error>   Not logged in</error>")
            return ACON::Command::Status::FAILURE
          end

          spinner = dots_spinner("Connecting to #{dyno}")

          host = Build.api_host
          scheme = Build.api_host_scheme == "https" ? "wss" : "ws"
          uri = URI.parse("#{scheme}://#{host}/cable?token=#{user_token}")

          identifier = {channel: "ExecChannel", app: app_id, dyno: dyno, command: "bash"}.to_json

          ws = HTTP::WebSocket.new(uri)
          ready = Channel(Bool).new(1)
          done = Channel(Nil).new(1)

          ws.on_message do |msg|
            parsed = JSON.parse(msg)
            type = parsed["type"]?.try(&.as_s)

            case type
            when "welcome"
              ws.send({command: "subscribe", identifier: identifier}.to_json)
            when "confirm_subscription"
              # Waiting for server's "connected" message
            when "ping"
              # no-op
            when "reject_subscription"
              spinner.error
              select
              when ready.send(false)
              else
              end
            when "disconnect"
              select
              when done.send(nil)
              else
              end
            else
              if message = parsed["message"]?
                case message["type"]?.try(&.as_s)
                when "connected"
                  select
                  when ready.send(true)
                  else
                  end
                when "stdout"
                  if data = message["data"]?.try(&.as_s)
                    STDOUT.write(Base64.decode(data))
                    STDOUT.flush
                  end
                when "error"
                  STDERR.puts("\r\n#{message["message"]?.try(&.as_s) || "Unknown error"}")
                  select
                  when done.send(nil)
                  else
                  end
                when "exit"
                  select
                  when done.send(nil)
                  else
                  end
                end
              end
            end
          end

          ws.on_close do |code, reason|
            select
            when ready.send(false)
            else
            end
            select
            when done.send(nil)
            else
            end
          end

          # Run WebSocket in background fiber
          spawn do
            ws.run
          rescue
          end

          # Wait for connection
          unless ready.receive
            return ACON::Command::Status::FAILURE
          end
          spinner.success

          # Send initial terminal size
          terminal = ACON::Terminal.new
          self.send_cable(ws, identifier, {type: "resize", cols: terminal.width, rows: terminal.height})

          # Handle terminal resize (SIGWINCH is Unix-only)
          {% unless flag?(:win32) %}
            Signal::WINCH.trap do
              t = ACON::Terminal.new
              self.send_cable(ws, identifier, {type: "resize", cols: t.width, rows: t.height}) rescue nil
            end
          {% end %}

          # Enter raw mode and stream stdin
          STDIN.noecho do
            STDIN.raw do
              spawn do
                buf = Bytes.new(4096)
                loop do
                  count = STDIN.read(buf)
                  break if count == 0
                  data = Base64.strict_encode(buf[0, count])
                  self.send_cable(ws, identifier, {type: "stdin", data: data})
                rescue
                  break
                end
              end

              done.receive
            end
          end

          ws.close rescue nil
          ACON::Command::Status::SUCCESS
        end

        private def send_cable(ws : HTTP::WebSocket, identifier : String, data : NamedTuple)
          ws.send({command: "message", identifier: identifier, data: data.to_json}.to_json)
        end

        private def exec_dyno(app_id : String, dyno : String, command_parts : Array(String)) : String
          request = Build::DynoExecRequest.new(command_parts)
          result  = api.exec_dyno(app_id, dyno, request)
          result.output
        end
      end
    end
  end
end
