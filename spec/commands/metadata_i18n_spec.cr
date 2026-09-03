require "../spec_helper"
require "athena-console"
require "athena-console/spec"
require "uri"
require "../../src/i18n"

module Build
  def self.api_host
    "app.build.io"
  end

  def self.api_host_scheme
    "https"
  end

  def self.api_url
    "https://app.build.io"
  end

  def self.parsed_api_uri
    URI.parse(api_url)
  end

  def self.git_host
    "git.build.io"
  end
end

require "../../src/commands/base"
require "../../src/commands/**"

private def with_metadata_locale(locale : String, &)
  previous = ENV[Build::Locale::OVERRIDE_VAR]?
  ENV[Build::Locale::OVERRIDE_VAR] = locale
  Build::Locale.init
  yield
ensure
  if previous.nil?
    ENV.delete(Build::Locale::OVERRIDE_VAR)
  else
    ENV[Build::Locale::OVERRIDE_VAR] = previous
  end
  Build::Locale.init
end

private def metadata_app
  app = ACON::Application.new("test", "1.0.0")
  app.auto_exit = false
  app.definition = Build::Console.default_input_definition
  app.add Build::Commands::Help.new
  app.add Build::Commands::List.new
  app.add Build::Commands::Completion.new
  app.add Build::Commands::Whoami.new
  app.add Build::Commands::Login.new
  app.add Build::Commands::OidcLogin.new
  {% unless flag?(:win32) %}
  app.add Build::Commands::Run.new
  {% end %}
  app.add Build::Commands::Logs.new
  app.add Build::Commands::Skills.new
  app.add Build::Commands::App::Create.new
  app.add Build::Commands::App::List.new
  app.add Build::Commands::App::Info.new
  app.add Build::Commands::App::Stacks.new
  app.add Build::Commands::App::StacksSet.new
  app.add Build::Commands::Team::List.new
  app.add Build::Commands::Team::Info.new
  app.add Build::Commands::Namespace::List.new
  app.add Build::Commands::Namespace::Info.new
  app.add Build::Commands::Namespace::Create.new
  app.add Build::Commands::Namespace::Delete.new
  app.add Build::Commands::Config::List.new
  app.add Build::Commands::Config::Info.new
  app.add Build::Commands::Config::Create.new
  app.add Build::Commands::Config::Delete.new
  app.add Build::Commands::Process::List.new
  app.add Build::Commands::Process::Delete.new
  app.add Build::Commands::Process::Scale.new
  app.add Build::Commands::Process::Exec.new
  app.add Build::Commands::Pipeline::List.new
  app.add Build::Commands::Pipeline::Info.new
  app.add Build::Commands::Pipeline::Diff.new
  app.add Build::Commands::Pipeline::Promote.new
  app.add Build::Commands::Builds::List.new
  app.add Build::Commands::Builds::Info.new
  app.add Build::Commands::Deployments::List.new
  app.add Build::Commands::Deployments::Info.new
  app.add Build::Commands::Addons::List.new
  app.add Build::Commands::Addons::Services.new
  app.add Build::Commands::Addons::Plans.new
  app.add Build::Commands::Addons::Create.new
  app.add Build::Commands::Addons::Info.new
  app.add Build::Commands::Addons::Destroy.new
  app.add Build::Commands::Addons::Attach.new
  app.add Build::Commands::Addons::Detach.new
  app.add Build::Commands::Buildpacks::List.new
  app.add Build::Commands::Buildpacks::Add.new
  app.add Build::Commands::Buildpacks::Set.new
  app.add Build::Commands::Buildpacks::Remove.new
  app.add Build::Commands::Buildpacks::Clear.new
  app.add Build::Commands::Domains::List.new
  app.add Build::Commands::Domains::Add.new
  app.add Build::Commands::Domains::Remove.new
  app.add Build::Commands::Domains::Clear.new
  app.add Build::Commands::Domains::Info.new
  app.add Build::Commands::Domains::Update.new
  app.add Build::Commands::Domains::Wait.new
  app
end

describe "command metadata i18n" do
  it "registers all command metadata through the English catalog" do
    with_metadata_locale("en") do
      tester = ACON::Spec::ApplicationTester.new metadata_app
      tester.run command: "help", command_name: "apps:list", decorated: false
      output = tester.display

      output.should contain("Description:\n  List the apps you have access to.")
      output.should contain("-t, --team[=TEAM]     Team name or ID.")
      output.should contain("-j, --json            Output in JSON format.")
      output.should contain("personal apps only")
    end
  end

  it "falls back to English when the selected locale has no catalog entries yet" do
    with_metadata_locale("ja") do
      tester = ACON::Spec::ApplicationTester.new metadata_app
      tester.run command: "list", decorated: false
      output = tester.display

      output.should contain("Available commands:")
      output.should contain("apps:list")
      output.should contain("List the apps you have access to.")
      output.should contain("login")
      output.should contain("Login to your Build account")
    end
  end
end
