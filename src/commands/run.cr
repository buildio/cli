require "io/console"
require "uuid"
require "term-spinner"
require "netrc"
require "ssh2"

# This command is used to run a once-off dyno on the Build platform. 
# It is useful for running tasks that are not part of a web process .
# type such as database migrations, console sessions, or one-off scripts.
# The run command takes a command to run as an argument. The command will 
# be executed in a one-off dyno on the Build platform.
module Build
  module Commands
    @[ACONA::AsCommand("run")]
    class Run < Base
      protected def configure : Nil
        self
          .name("run")
          .argument("cmd", :is_array, "The command to run")
          .option("app", "a", :required, "The app to run the command on")
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

        command = input.argument("cmd", type: Array(String) | Nil)

        terminal = ACON::Terminal.new
        width = terminal.width
        height = terminal.height

        spinner = dots_spinner("Retrieving app region")

        app = self.api.app(app_id)

        region = app.region
        spinner.update(status: "Connecting to server")

        SSH2::Session.open("ssh.#{region}.antimony.io", 1849) do |session|
          spinner.update(status: "Logging in")
          begin
            session.login(app.name, user_token)
          rescue SSH2::SessionError
            spinner.error("Login failed")
            exit
          end

          spinner.update(status: "Opening channel")
          session.open_session do |channel|
            # This command gets:   ERR -22: Unable to complete request for channel-setenv  
            channel.request_pty( "xterm-256color", width: width, height: height )

            channel.setenv("TERM", "xterm-256color") # This should be set with the PTY request below.
            # channel.setenv("PS1", "\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]")

            # channel << "export TERM=xterm-256color\n"
            # export PS1="\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]$ \[\033[00m\]"
            # channel << "export PS1=\"\\[\\033[01;34m\\]\\w\\[\\033[00m\\] \\[\\033[01;32m\\]\\$ \\[\\033[00m\\]\"\n"
            if command
              spinner.update(status: "Running command")
              channel.command(["/cnb/lifecycle/launcher", *command].join(" "))
            else
              spinner.update(status: "Starting shell")
              channel.command("/cnb/lifecycle/launcher bash")
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
