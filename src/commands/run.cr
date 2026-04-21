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
          .argument("cmd", :is_array, "The command to run", [] of String)
          .option("app", "a", :required, "The app to run the command on")
          .option("debug", nil, :none, "Show verbose debugging information")
          .option("no-tty", nil, :none, "Force the command to not run in a tty")
          .option("exit-code", "x", :none, "Passthrough the exit code of the remote command")
          .option("file", "f", :optional, "Send a local file as stdin to the remote command")
          .option("shell", "c", :none, "Pass the command to the remote shell for interpretation (enables $VAR, globs, pipes, multi-command)")
          .description("Run a command in a once-off dyno on the Build platform")
          .help(<<-HELP
          Run a one-off command on the Build platform. Useful for migrations,
          console sessions, or ad-hoc scripts.

          By default each argument is POSIX single-quoted before being sent to
          the remote side, so parentheses, braces, quotes, $VAR, globs, and
          other shell metacharacters reach the target process literally:

            bld run ruby -e 'puts ENV["HOME"]' -a my-app
            bld run rake 'test:unit[foo,bar]' -a my-app

          Use -c/--shell when you actually want the remote shell to interpret
          metacharacters (variable expansion, pipes, multiple commands):

            bld run -c 'echo $RAILS_ENV | tee /tmp/env' -a my-app

          Use --file (or stdin redirection) to send a local file as stdin and
          sidestep quoting entirely:

            bld run rails runner -a my-app --file script.rb
            bld run rails runner -a my-app < script.rb
          HELP
          )
          .usage("bash -a my-app")
          .usage("rails runner -a my-app --file script.rb")
          .usage("-c 'echo $HOME | wc -c' -a my-app")
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
          output.puts "You need to be logged in to run a command."
          return ACON::Command::Status::FAILURE
        end

        app_id = input.option("app")
        unless app_id
          output.puts "No app specified. Please use the --app option to specify the app to run the command on."
          return ACON::Command::Status::FAILURE
        end

        verbose = input.option("debug", type: Bool)
        no_tty = input.option("no-tty", type: Bool)
        exit_code_mode = input.option("exit-code", type: Bool)
        command_array = input.argument("cmd", type: Array(String)) rescue [] of String
        file_path = input.option("file", type: String?)

        # Validate --file if specified
        if file_path && !File.exists?(file_path)
          output.puts "File not found: #{file_path}"
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

        spinner = dots_spinner("Retrieving app region")

        app = self.api.app(app_id)

        ssh_host = app.ssh_host
        ssh_port = app.ssh_port
        spinner.update(status: "Connecting to server")

        if verbose
          output.puts "Verbose mode enabled"
          output.puts "Connecting to #{ssh_host}:#{ssh_port}"
          output.puts "App: #{app.name}"
          output.puts "Terminal size: #{width}x#{height}"
        end

        SSH2::Session.open(ssh_host, ssh_port) do |session|
          spinner.update(status: "Logging in")
          if verbose
            output.puts "SSH connection established"
            output.puts "Authenticating with app: #{app.name}"
          end
          
          begin
            session.login(app.name, user_token)
            if verbose
              output.puts "SSH authentication successful"
            end
          rescue e : SSH2::SessionError
            spinner.error("Login failed")
            if verbose
              output.puts "SSH authentication error: #{e.message}"
            end
            exit
          end

          spinner.update(status: "Opening channel")
          if verbose
            output.puts "Opening SSH channel"
          end
          
          session.open_session do |channel|
            # Request PTY only for interactive sessions
            if use_tty
              if verbose
                output.puts "Requesting PTY with terminal type: xterm-256color"
              end
              channel.request_pty("xterm-256color", width: width, height: height)
            elsif verbose
              output.puts "Running without PTY (--no-tty or non-interactive)"
            end

            if verbose
              output.puts "Setting environment variables"
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
              spinner.update(status: "Running #{display_cmd} on #{app.name}")
              if verbose
                output.puts "Executing command: #{cmd_string}"
              end
              channel.command(cmd_string)
            else
              spinner.update(status: "Starting shell on #{app.name}")
              if verbose
                output.puts "Starting interactive shell"
              end
              channel.shell
            end

            spinner.success

            if use_tty
              # Interactive TTY mode: raw input, handle special keys
              STDIN.noecho do
                STDIN.raw do
                  spawn do
                    buffer = Bytes.new(1)
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
                output.puts "Channel closed by remote host"
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
