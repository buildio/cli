require "io/console"
require "uuid"
require "term-spinner"
require "netrc"
{% unless flag?(:win32) %}
require "ssh2"
{% end %}

# This command is used to run a once-off dyno on the Build platform.
# It is useful for running tasks that are not part of a web process .
# type such as database migrations, console sessions, or one-off scripts.
# The run command takes a command to run as an argument. The command will
# be executed in a one-off dyno on the Build platform.
{% unless flag?(:win32) %}
module Build
  module Commands
    @[ACONA::AsCommand("run")]
    class Run < Base
      protected def configure : Nil
        self
          .name("run")
          .argument("cmd", :is_array, t("commands.run.arguments.cmd"), [] of String)
          .option("app", "a", :required, t("commands.run.options.app"))
          .option("debug", nil, :none, t("commands.run.options.debug"))
          .option("no-tty", nil, :none, t("commands.run.options.no_tty"))
          .option("exit-code", "x", :none, t("commands.run.options.exit_code"))
          .option("file", "f", :optional, t("commands.run.options.file"))
          .option("shell", "c", :none, t("commands.run.options.shell"))
          .description(t("commands.run.description"))
          .help(t("commands.run.help"))
          .usage(t("runtime.run.usage.bash"))
          .usage(t("runtime.run.usage.file"))
          .usage(t("runtime.run.usage.shell"))
          #.aliases(["exec", "shell", "console"])
      end

      # POSIX single-quote escape: wraps arg in '...' and encodes embedded
      # single quotes as '\''. This is the only portable shell quoting form
      # that suppresses all expansion — no $VAR, no backticks, no globs.
      private def sh_quote(arg : String) : String
        "'" + arg.gsub("'", "'\\''") + "'"
      end

      # Sentinel used to capture exit code from remote command
      EXIT_CODE_SENTINEL = "\uFFFF bld-command-exit-status:"

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        user_token = self.token
        if user_token.nil?
          output.puts t("runtime.errors.need_login_to_run")
          return ACON::Command::Status::FAILURE
        end

        app_id = input.option("app")
        unless app_id
          output.puts t("runtime.run.no_app")
          return ACON::Command::Status::FAILURE
        end

        verbose = input.option("debug", type: Bool)
        no_tty = input.option("no-tty", type: Bool)
        exit_code_mode = input.option("exit-code", type: Bool)
        command_array = input.argument("cmd", type: Array(String)) rescue [] of String
        file_path = input.option("file", type: String?)

        # Validate --file if specified
        if file_path && !File.exists?(file_path)
          output.puts t("runtime.run.file_not_found", path: file_path)
          return ACON::Command::Status::FAILURE
        end

        # Determine if we should use a TTY
        # Use TTY for interactive shells, or when explicitly requested (not --no-tty)
        # and when stdin/stdout are actually TTYs
        # --file implies non-TTY since we're piping file content as stdin
        use_tty = !no_tty && !file_path && STDIN.tty? && STDOUT.tty?

        terminal = ACON::Terminal.new
        width = terminal.width
        height = terminal.height

        remote_exit_code : Int32? = nil

        spinner = dots_spinner(t("runtime.run.spinner.retrieving_region"))

        app = self.api.app(app_id)

        ssh_host = app.ssh_host
        ssh_port = app.ssh_port
        spinner.update(status: t("runtime.run.spinner.connecting_server"))

        if verbose
          output.puts t("runtime.run.verbose.enabled")
          output.puts t("runtime.run.verbose.connecting", host: ssh_host, port: ssh_port)
          output.puts t("runtime.labels.app", value: app.name)
          output.puts t("runtime.run.verbose.terminal_size", width: width, height: height)
        end

        SSH2::Session.open(ssh_host, ssh_port) do |session|
          spinner.update(status: t("runtime.run.spinner.logging_in"))
          if verbose
            output.puts t("runtime.run.verbose.ssh_established")
            output.puts t("runtime.run.verbose.authenticating", app: app.name)
          end
          
          begin
            session.login(app.name, user_token)
            if verbose
              output.puts t("runtime.run.verbose.auth_success")
            end
          rescue e : SSH2::SessionError
            spinner.error(t("runtime.login.failed"))
            if verbose
              output.puts t("runtime.run.verbose.auth_error", error: e.message)
            end
            exit
          end

          # Disable Nagle's algorithm on the SSH transport. Interactive shells
          # send ~1 byte per keystroke; with Nagle on (the Crystal/ssh2 default)
          # each small packet waits on the peer's delayed-ACK timer (~40ms+),
          # which is the "lag while typing" users feel. OpenSSH sets TCP_NODELAY
          # on interactive sessions for the same reason.
          session.socket.as(TCPSocket).tcp_nodelay = true
          if verbose
            output.puts t("runtime.run.verbose.tcp_nodelay")
          end

          spinner.update(status: t("runtime.run.spinner.opening_channel"))
          if verbose
            output.puts t("runtime.run.verbose.opening_channel")
          end
          
          session.open_session do |channel|
            # Request PTY only for interactive sessions
            if use_tty
              if verbose
                output.puts t("runtime.run.verbose.requesting_pty", term: "xterm-256color")
              end
              channel.request_pty("xterm-256color", width: width, height: height)
            elsif verbose
              output.puts t("runtime.run.verbose.no_pty")
            end

            if verbose
              output.puts t("runtime.run.verbose.setting_env")
            end

            # Set environment variables for proper terminal handling
            # Note: Server must allow these through security filter (TERM, COLUMNS, LINES)
            channel.setenv("TERM", "xterm-256color")
            if use_tty
              channel.setenv("COLUMNS", width.to_s)
              channel.setenv("LINES", height.to_s)
            end

            # Merge stderr with stdout for unified output handling
            channel.handle_extended_data(LibSSH2::ExtendedData::MERGE)

            if !command_array.empty?
              # Build display command (what user sees) vs execution command
              display_cmd = command_array.join(" ")
              shell_mode = input.option("shell", type: Bool)
              cmd_string = if shell_mode
                # -c/--shell: user explicitly wants remote shell interpretation
                # (variables, globs, pipes, multi-command). Pass args through raw.
                "/cnb/lifecycle/launcher #{command_array.join(" ")}"
              else
                # Default: single-quote every arg so the remote shell cannot
                # re-interpret parens, braces, quotes, $VAR, backticks, or globs.
                "/cnb/lifecycle/launcher #{command_array.map { |a| sh_quote(a) }.join(" ")}"
              end
              # Append exit code sentinel if --exit-code is enabled
              if exit_code_mode
                cmd_string = "#{cmd_string}; echo \"#{EXIT_CODE_SENTINEL} $?\""
              end
              spinner.update(status: t("runtime.run.spinner.running", command: display_cmd, app: app.name))
              if verbose
                output.puts t("runtime.run.verbose.executing", command: cmd_string)
              end
              channel.command(cmd_string)
            else
              spinner.update(status: t("runtime.run.spinner.starting_shell", app: app.name))
              if verbose
                output.puts t("runtime.run.verbose.starting_shell")
              end
              channel.shell
            end

            spinner.success

            if use_tty
              # Interactive TTY mode: raw input, handle special keys
              STDIN.noecho do
                STDIN.raw do
                  spawn do
                    # 4096 like the non-TTY path: read() returns on the first
                    # byte (keystrokes still forward instantly) but batches pastes.
                    buffer = Bytes.new(4096)
                    slice = buffer.to_slice
                    loop do
                      count = STDIN.read(slice)
                      if count > 0
                        channel.write(slice[0, count])
                      end
                    end
                  end
                  remote_exit_code = read_channel_output(channel, output, verbose, exit_code_mode)
                end
              end
            else
              # Non-TTY mode: pipe stdin (or --file) and read output without raw mode
              spawn do
                input_io : IO = if fp = file_path
                  File.open(fp)
                else
                  STDIN
                end
                buffer = Bytes.new(4096)
                slice = buffer.to_slice
                begin
                  loop do
                    count = input_io.read(slice)
                    if count > 0
                      channel.write(slice[0, count])
                    else
                      channel.send_eof
                      break
                    end
                  end
                ensure
                  input_io.close if file_path
                end
              end
              remote_exit_code = read_channel_output(channel, output, verbose, exit_code_mode)
            end
          end
        end

        # Handle exit code passthrough
        if exit_code_mode && remote_exit_code
          exit(remote_exit_code)
        end

        return ACON::Command::Status::SUCCESS
      end

      # Reads output from the SSH channel and writes to STDOUT
      # Returns the exit code if exit_code_mode is enabled and sentinel is found
      private def read_channel_output(channel, output, verbose, exit_code_mode) : Int32?
        buffer = Bytes.new(4096)
        slice = buffer.to_slice
        output_buffer = "" if exit_code_mode
        exit_code : Int32? = nil

        loop do
          # Use read(0, slice) to bypass the library's early eof? check
          # This ensures we drain all buffered data before exiting
          count = channel.read(0, slice)
          if count > 0
            data = String.new(slice[0, count])

            if exit_code_mode
              # Buffer output to detect exit code sentinel
              output_buffer = output_buffer.not_nil! + data

              # Check for exit code sentinel
              if output_buffer.includes?(EXIT_CODE_SENTINEL)
                # Parse exit code and remove sentinel from output
                if match = output_buffer.match(/#{Regex.escape(EXIT_CODE_SENTINEL)} (\d+)/)
                  exit_code = match[1].to_i
                  # Remove the sentinel line from output
                  clean_output = output_buffer.gsub(/#{Regex.escape(EXIT_CODE_SENTINEL)} \d+\n?/, "")
                  STDOUT.write(clean_output.to_slice)
                  STDOUT.flush
                  output_buffer = ""
                end
              else
                # Write buffered content that can't contain the sentinel
                # Keep only the last part that might be a partial sentinel
                safe_length = output_buffer.size - EXIT_CODE_SENTINEL.size - 10
                if safe_length > 0
                  STDOUT.write(output_buffer[0, safe_length].to_slice)
                  STDOUT.flush
                  output_buffer = output_buffer[safe_length..]
                end
              end
            else
              STDOUT.write(slice[0, count])
              STDOUT.flush
            end
          else
            # Only exit when read returns 0 AND channel is at EOF
            if channel.eof?
              # Flush any remaining buffered output
              if exit_code_mode && !output_buffer.not_nil!.empty?
                clean_output = output_buffer.not_nil!.gsub(/#{Regex.escape(EXIT_CODE_SENTINEL)} \d+\n?/, "")
                STDOUT.write(clean_output.to_slice) unless clean_output.empty?
                STDOUT.flush
              end
              if verbose
                output.puts t("runtime.run.verbose.channel_closed")
              end
              break
            end
          end
        end

        exit_code
      end
    end
  end
end
{% end %}
