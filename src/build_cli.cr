require "athena-console"
require "./utils"
require "./commands/base"
require "./commands/**"
require "uri"

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
Colorize.on_tty_only! # Don't colorize output if not on a TTY

module Build
  private DEFAULT_API_URL = "https://app.build.io"

  # This will now control both CLI debug messages and SDK debugging.
  def self.debugging?
    val = ENV["DEBUG"]?
    val == "true" || val == "1"
  end
  def self.api_url
    ENV.fetch("BUILD_API_URL", DEFAULT_API_URL)
  end

  def self.parsed_api_uri
    URI.parse(self.api_url)
  end

  def self.api_host
    uri = self.parsed_api_uri
    uri.host.not_nil! + (uri.port ? ":#{uri.port}" : "")
  end

  def self.api_host_scheme
    self.parsed_api_uri.scheme.not_nil!
  end

  # Method to setup global API client config
  def self.setup_global_api_config
    current_host = self.api_host
    current_scheme = self.api_host_scheme
    sdk_debugging_flag = self.debugging?
    if self.debugging?
      STDERR.puts "[DEBUG] Setting up global API config with:"
      STDERR.puts "[DEBUG]   Host: #{current_host}"
      STDERR.puts "[DEBUG]   Scheme: #{current_scheme}"
      STDERR.puts "[DEBUG]   SDK Debugging: #{sdk_debugging_flag}"
    end
    Build.configure do |config|
      config.host       = current_host
      config.scheme     = current_scheme
      config.debugging  = sdk_debugging_flag
    end
  end
end

Build.setup_global_api_config # Call it once to configure the API client globally

application = ACON::Application.new "Build.io CLI", version: VERSION

# Register commands using the `#add` method
application.add Build::Commands::Whoami.new
application.add Build::Commands::Login.new
application.add Build::Commands::OidcLogin.new
application.add Build::Commands::Run.new
application.add Build::Commands::Logs.new
application.add Build::Commands::App::Create.new
application.add Build::Commands::App::List.new
application.add Build::Commands::App::Info.new
application.add Build::Commands::Team::List.new
application.add Build::Commands::Team::Info.new
application.add Build::Commands::Namespace::List.new
application.add Build::Commands::Namespace::Info.new
application.add Build::Commands::Namespace::Create.new
application.add Build::Commands::Namespace::Delete.new

application.add Build::Commands::Config::List.new
application.add Build::Commands::Config::Info.new
application.add Build::Commands::Config::Create.new
application.add Build::Commands::Config::Delete.new

application.add Build::Commands::Process::List.new
application.add Build::Commands::Process::Delete.new
application.add Build::Commands::Process::Exec.new

application.add Build::Commands::Pipeline::List.new
application.add Build::Commands::Pipeline::Info.new

application.add Build::Commands::ReviewApps::List.new
application.add Build::Commands::ReviewApps::Create.new
application.add Build::Commands::ReviewApps::Info.new
application.add Build::Commands::ReviewApps::Delete.new

# Run the application.
# By default this uses STDIN and STDOUT for its input and output.
application.run
