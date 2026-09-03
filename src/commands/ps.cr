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
            .description(t("commands.ps.list.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.ps.list.help"))
            .usage(t("runtime.ps.list.usage"))
            .aliases(["ps", "ps:ls"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          json_output = input.option("json", type: Bool?) || false

          if app_name_or_id.blank?
            output.puts("<error>   #{t("runtime.errors.missing_app_option")}</error>")
            return ACON::Command::Status::FAILURE
          end
          dynos = api.list_dynos(app_name_or_id)
          unless dynos
            if json_output
              output.puts("[]")
            else
              output.puts("<info>   #{t("runtime.ps.no_processes_for_app", app: app_name_or_id)}</info>")
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
              started_at_time = parse_timestamp?(process.started_at)
              status = process.status == "Running" ? t("runtime.status.up").colorize.green : t("runtime.status.down").colorize.red

              entry = if started_at_time
                dotiw = distance_of_time_in_words(started_at_time)
                "#{dyno._type.colorize(:white)}.#{process.index}: #{status} " +
                  "#{started_at_time.to_s.colorize(:dark_gray)} (~ #{dotiw.colorize.yellow} ago)"
              else
                "#{dyno._type.colorize(:white)}.#{process.index}: #{status} #{process.started_at.colorize(:dark_gray)}"
              end

              restarts     = process.restarts
              restarted_at = process.restarted_at
              if restarted_at && restarts && restarts > 0
                entry += " " + t("runtime.ps.restarts", count: process.restarts)
                if restarted_at_time = parse_timestamp?(restarted_at)
                  dotiw = distance_of_time_in_words(restarted_at_time)
                  entry += " " + t("runtime.ps.last_restart_ago", time: restarted_at.to_s.colorize(:dark_gray).to_s, ago: dotiw.colorize.yellow.to_s)
                else
                  entry += " " + t("runtime.ps.last_restart", time: restarted_at.to_s.colorize(:dark_gray).to_s)
                end
              end
              output.puts entry
            end
            output.puts "" # Line break
          end
          return ACON::Command::Status::SUCCESS
        end

        private def parse_timestamp?(value : String) : Time?
          Time.parse_iso8601(value)
        rescue Time::Format::Error | ArgumentError
          nil
        end
      end
      @[ACONA::AsCommand("ps:restart")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("ps:restart")
            .description(t("commands.ps.restart.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .argument("process", :optional, t("commands.ps.restart.arguments.process"))
            .help(t("commands.ps.restart.help"))
            .usage(t("runtime.ps.restart.usage"))
            .aliases(["restart"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   #{t("runtime.errors.missing_app_option")}</error>")
            return ACON::Command::Status::FAILURE
          end
          process_name = input.argument("process", type: String?)
          if process_name.nil?
            spin = t("runtime.ps.restart.spinner_all", app: app_name_or_id)
          else
            spin = t("runtime.ps.restart.spinner_process", process: process_name, app: app_name_or_id)
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
      @[ACONA::AsCommand("ps:scale")]
      class Scale < Base
        protected def configure : Nil
          self
            .name("ps:scale")
            .description(t("commands.ps.scale.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .argument("args", ACON::Input::Argument::Mode[:optional, :is_array], t("commands.ps.scale.arguments.args"))
            .help(t("commands.ps.scale.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          json_output = input.option("json", type: Bool?) || false
          scale_args = input.argument("args", type: Array(String))

          if app_name_or_id.blank?
            output.puts("<error>#{t("runtime.errors.missing_app_option")}</error>")
            return ACON::Command::Status::FAILURE
          end

          if scale_args.empty?
            return show_formation(app_name_or_id, json_output, output)
          end

          updates = Array(Hash(String, String | Int32)).new
          scale_args.each do |arg|
            type_part, _, rest = arg.partition('=')
            if rest.empty?
              output.puts("<error>#{t("runtime.ps.scale.invalid_arg", arg: arg)}</error>")
              return ACON::Command::Status::FAILURE
            end
            qty_part, _, size_part = rest.partition(':')
            qty = qty_part.to_i?
            unless qty
              output.puts("<error>#{t("runtime.ps.scale.invalid_quantity", quantity: qty_part, arg: arg)}</error>")
              return ACON::Command::Status::FAILURE
            end
            update = Hash(String, String | Int32).new
            update["type"] = type_part
            update["quantity"] = qty
            update["size"] = size_part unless size_part.empty?
            updates << update
          end

          begin
            api
            data = scale_formation(app_name_or_id, updates)
            if json_output
              output.puts data
            else
              parsed = JSON.parse(data)
              entries = parsed.as_a? || parsed.as_h.values.find(&.as_a?).try(&.as_a) || [parsed]
              entries.each do |entry|
                type = entry["type"]?.try(&.as_s?) || next
                qty = entry["quantity"]?.try(&.as_i?) || next
                size = entry["size"]?.try(&.as_s?) || ""
                label = size.empty? ? "#{type}=#{qty}" : "#{type}=#{qty}:#{size}"
                output.puts t("runtime.ps.scale.done", label: label)
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.ps.scale.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def show_formation(app_id : String, json_output : Bool, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            api
            data = fetch_formation(app_id)
            if json_output
              output.puts data
            else
              parsed = JSON.parse(data)
              entries = parsed.as_a? || parsed.as_h.values.find(&.as_a?).try(&.as_a) || [parsed]
              entries.each do |entry|
                type = entry["type"]?.try(&.as_s?) || next
                qty = entry["quantity"]?.try(&.as_i?) || next
                size = entry["size"]?.try(&.as_s?) || ""
                label = size.empty? ? "#{type}=#{qty}" : "#{type}=#{qty}:#{size}"
                output.puts label
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.ps.scale.failed_get_formation", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def fetch_formation(app_id : String) : String
          path = "/api/v1/apps/#{URI.encode_path(app_id)}/formation"
          api_client = ::Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          data, _status, _headers = api_client.call_api(:GET, path,
            :"FormationApi.list", "String", nil, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          data
        end

        private def scale_formation(app_id : String, updates : Array(Hash(String, String | Int32))) : String
          path = "/api/v1/apps/#{URI.encode_path(app_id)}/formation"
          api_client = ::Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          header_params["Content-Type"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          body = {"updates" => updates}.to_json
          data, _status, _headers = api_client.call_api(:PATCH, path,
            :"FormationApi.batch_update", "String", body, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          data
        end
      end

      @[ACONA::AsCommand("ps:exec")]
      class Exec < Base
        protected def configure : Nil
          self
            .name("ps:exec")
            .description(t("commands.ps.exec.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("dyno", "d", :required, t("commands.ps.exec.options.dyno"))
            .option("status", "s", :none, t("commands.ps.exec.options.status"))
            .argument("CMD", ACON::Input::Argument::Mode[:optional, :is_array], t("commands.ps.exec.arguments.cmd"))
            .help(t("commands.ps.exec.help"))
            .usage(t("runtime.ps.exec.usage"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)

          if input.option("status", type: Bool?)
            return self.exec_status(app_name_or_id, output)
          end

          dyno_name = input.option("dyno", type: String)

          if app_name_or_id.blank? || dyno_name.blank?
            output.puts("<error>   #{t("runtime.errors.missing_app_or_dyno")}</error>")
            return ACON::Command::Status::FAILURE
          end

          command_parts = input.argument("CMD", type: Array(String))

          if STDIN.tty?
            cmd = command_parts.empty? ? "bash" : command_parts.join(" ")
            return self.interactive_exec(app_name_or_id, dyno_name, cmd, output)
          end

          if command_parts.empty?
            output.puts("<error>   #{t("runtime.ps.exec.no_command_non_tty")}</error>")
            return ACON::Command::Status::FAILURE
          end

          # Non-interactive: existing HTTP POST path
          spinner = dots_spinner(t("runtime.ps.exec.executing", command: command_parts.join(" "), dyno: dyno_name))
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
            output.puts("<error>   #{t("runtime.errors.missing_app_option")}</error>")
            return ACON::Command::Status::FAILURE
          end
          dynos = api.list_dynos(app_id)
          unless dynos
            output.puts("<info>   #{t("runtime.ps.no_processes")}</info>")
            return ACON::Command::Status::SUCCESS
          end
          dynos.each do |dyno|
            dyno.processes.each do |process|
              status = process.status == "Running" ? t("runtime.status.ready").colorize.green : t("runtime.status.not_ready").colorize.red
              output.puts "#{dyno._type}.#{process.index}: #{status}"
            end
          end
          ACON::Command::Status::SUCCESS
        end

        private def interactive_exec(app_id : String, dyno : String, command : String, output : ACON::Output::Interface) : ACON::Command::Status
          user_token = self.token
          unless user_token
            output.puts("<error>   #{t("runtime.errors.not_logged_in_short")}</error>")
            return ACON::Command::Status::FAILURE
          end

          spinner = dots_spinner(t("runtime.ps.exec.connecting", dyno: dyno))

          host = ::Build.api_host
          scheme = ::Build.api_host_scheme == "https" ? "wss" : "ws"
          uri = URI.parse("#{scheme}://#{host}/cable?token=#{user_token}")

          identifier = {channel: "ExecChannel", app: app_id, dyno: dyno, command: command}.to_json

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
                  STDERR.puts("\r\n#{message["message"]?.try(&.as_s) || t("runtime.errors.unknown")}")
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
          request = ::Build::DynoExecRequest.new(command_parts)
          result  = api.exec_dyno(app_id, dyno, request)
          result.output
        end
      end
    end
  end
end
