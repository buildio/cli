require "../spec_helper"
require "athena-console"
require "athena-console/spec"
require "../../src/i18n"
require "../../src/console/localized_text_descriptor"
require "../../src/commands/help"

CJK_DESCRIPTION = "\u{8AAC}\u{660E}\u{6587}"
CJK_OPTION = "\u{540D}\u{524D}"

class LocalizedHelpCjkCommand < ACON::Command
  protected def configure : Nil
    self
      .name("cjk")
      .description(CJK_DESCRIPTION)
      .option("name", "x", :optional, CJK_OPTION)
  end

  protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
    ACON::Command::Status::SUCCESS
  end
end

private def with_build_locale(locale : String, &)
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

private def localized_test_app
  app = ACON::Application.new("test", "1.0.0")
  app.auto_exit = false
  app.definition = Build::Console.default_input_definition
  app.add Build::Commands::Help.new
  app.add Build::Commands::List.new
  app.add LocalizedHelpCjkCommand.new
  app
end

describe Build::Console::LocalizedTextDescriptor do
  it "renders fallback help headings, global options, and CJK command metadata" do
    with_build_locale("ja") do
      tester = ACON::Spec::ApplicationTester.new localized_test_app
      tester.run command: "help", command_name: "cjk", decorated: false
      output = tester.display

      output.should contain("Description:\n  #{CJK_DESCRIPTION}")
      output.should contain("Usage:")
      output.should contain("Options:")
      output.should contain("-x, --name[=NAME]     #{CJK_OPTION}")
      output.should contain("-h, --help")
      output.should contain("Display help for the given command")
    end
  end

  it "renders fallback list headings" do
    with_build_locale("ja") do
      tester = ACON::Spec::ApplicationTester.new localized_test_app
      tester.run command: "list", decorated: false
      output = tester.display

      output.should contain("Available commands:")
      output.should contain("help        Display help for a command")
      output.should contain("list        List available commands")
    end
  end
end
