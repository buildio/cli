require "io/console"
require "uuid"
require "term-spinner"
require "netrc"

# This command is used to login to the Build API. The Build API token is stored in
# the user's netrc file. Because the commandline needs the token, it does a three-way
# OAuth authentication. This command requests a login authorization from Build, then
# opens a browser to have the users OAuth-accept that authorization. Once the user
# accepts the authorization, the command polls the Build API to get the user's token.
module Build
  module Commands
    @[ACONA::AsCommand("login")]
    class Login < Base
      protected def configure : Nil
        self
          .name("login")
          .description("Login to your Build account")
          .help("This command is used to login to the Build API. The Build API token is stored in the user's netrc file. Because the commandline needs the token, it does a three-way OAuth authentication. This command requests a login authorization from Build, then opens a browser to have the users OAuth-accept that authorization. Once the user accepts the authorization, the command polls the Build API to get the user's token.")
      end
      def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        input = prompt_any_key("Press any key to open up the browser to login or q to exit")
        return ACON::Command::Status::FAILURE if input == 'q'

        user_token = nil
        user_email = nil
        client_secret = UUID.random
        oauth_url = "https://#{Build.api_host}/cli_auth/authorize/#{client_secret}"
        output.puts "Opening browser to #{oauth_url.colorize.mode(:underline)}"

        frames = %w{⠙ ⠹ ⠸ ⠼ ⠴}
        # Turn each frame into a colorized string first in cyan then in magenta:
        cyan    = frames.map { |frame| frame.colorize(:cyan).to_s }
        frames = %w{⠦ ⠧ ⠇ ⠏ ⠋}
        magenta = frames.map { |frame| frame.colorize(:magenta).to_s }
        frames  = cyan + magenta
        spinner = Term::Spinner.new(":spinner Waiting for login", frames: frames, format: :dots, success_mark: "✓".colorize(:green).to_s, error_mark: "✗".colorize(:red).to_s)
        spinner.auto_spin # Automatic animation with default interval
        launch_browser(oauth_url)
        # Loop:
        poll_interval = 1
        timeout_seconds = (5 * 60)
        timeout = Time::Span.new(seconds: timeout_seconds)
        start_time = Time.utc
        loop do
          url = "https://#{Build.api_host}/api/cli_auth/resolve/#{client_secret}"
          response = HTTP::Client.get(url)
          if response.status_code == 200
            json_response = JSON.parse(response.body)
            if json_response["code"].to_s == "unresolved"
              sleep(1)
            else
              # puts json_response
              user_token = json_response["token"].to_s
              user_email = json_response["email"].to_s
              break
            end
          else
            raise("Error: #{response.status_code}")
          end
          if Time.utc - start_time > timeout
            break
          end
        end
        if user_token.nil? || user_email.nil? || user_token.empty? || user_email.empty?
          output.puts("Login failed".colorize(:red))
          return ACON::Command::Status::FAILURE
        end

        user_netrc = Netrc.read
        user_netrc[Build.api_host]  = {"#{user_email}", "#{user_token}"}
        user_netrc.save
        spinner.success
        output.puts "Logged in as #{user_email.colorize(:green)}"
        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
