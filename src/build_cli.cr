require "athena-console"
require "./utils"
require "./commands/base"
require "./commands/**"

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
Colorize.on_tty_only! # Don't colorize output if not on a TTY

module Build
  def self.api_host
    "app.build.io"
  end
  def self.api_host_scheme
    "https"
  end
  def self.debugging?
    false
  end
end

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

# apps:create  Create a new app
# config:get   Get a config variable for an app
# config:set   Set config variables for an app
# config:unset Un-Set config variables for an app
# ps           List all the processes of an app
# ps:restart   Restart all the processes of an app

# Run the application.
# By default this uses STDIN and STDOUT for its input and output.
application.run
