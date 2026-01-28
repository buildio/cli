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
          .description("Run a command in a once-off dyno on the Build platform")
          .help("This command is used to run a once-off dyno on the Build platform. It is useful for running tasks that are not part of a web process type such as database migrations, console sessions, or one-off scripts. The run command takes a command to run as an argument. The command will be executed in a one-off dyno on the Build platform.")
          .usage("bash -a my-app")
          #.aliases(["exec", "shell", "console"])
      end

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
        command_array = input.argument("cmd", type: Array(String)) rescue [] of String

        terminal = ACON::Terminal.new
        width = terminal.width
        height = terminal.height

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
            # This command gets:   ERR -22: Unable to complete request for channel-setenv  
            if verbose
              output.puts "Requesting PTY with terminal type: xterm-256color"
            end
            
            channel.request_pty( "xterm-256color", width: width, height: height )

            if verbose
              output.puts "Setting environment variables"
            end
            
            channel.setenv("TERM", "xterm-256color") # This should be set with the PTY request below.
            # channel.setenv("PS1", "\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]")

            # channel << "export TERM=xterm-256color\n"
            # export PS1="\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]"
            # channel << "export PS1=\"\\[\\033[01;34m\\]\\w\\[\\033[00m\\] \\[\\033[01;32m\\]\\$ \\[\\033[00m\\]\"\n"
            if !command_array.empty?
              spinner.update(status: "Running command")
              cmd_string = ["/cnb/lifecycle/launcher", *command_array].join(" ")
              if verbose
                output.puts "Executing command: #{cmd_string}"
              end
              channel.command(cmd_string)
            else
              spinner.update(status: "Starting shell")
              if verbose
                output.puts "Starting interactive shell"
              end
              # channel.command("/cnb/lifecycle/launcher bash")
              channel.shell
            end
            #session.blocking = false
            STDIN.noecho do
              STDIN.raw do
                spinner.success
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
                buffer = Bytes.new(1)
                slice = buffer.to_slice
                loop do
                  if channel.eof?
                    if verbose
                      output.puts "Channel closed by remote host"
                    end
                    break
                  end
                  count = channel.read(slice)
                  if count > 0
                    STDOUT.write(slice[0, count])
                  end
                end
              end
            end
          end
        end

        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
{% end %}
