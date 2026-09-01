require "../spec_helper"
require "athena-console"
require "../../src/i18n"
require "../../src/console/localized_text_descriptor"

private class EnglishCompatCommand < ACON::Command
  protected def configure : Nil
    self
      .name("demo:run")
      .description("Run the demo command")
      .argument("target", :optional, "Target name", "world")
      .option("count", "c", :optional, "Number of runs", "1")
      .option("json", "j", :none, "Output in JSON format")
      .usage("demo:run app -c 2")
      .help("Runs a small demo command.\n\nExamples:\n  demo:run app")
      .aliases(["demo"])
  end

  protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
    ACON::Command::Status::SUCCESS
  end
end

private def with_english_locale(&)
  previous = ENV[Build::Locale::OVERRIDE_VAR]?
  ENV[Build::Locale::OVERRIDE_VAR] = "en"
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

private def english_compat_app
  app = ACON::Application.new("English Compat", "1.2.3")
  app.auto_exit = false
  app.definition = Build::Console.default_input_definition
  app.add EnglishCompatCommand.new
  app
end

private def describe_with(descriptor, object) : String
  output = ACON::Output::IO.new IO::Memory.new
  context = ACON::Descriptor::Context.new
  context.raw_output = true
  descriptor.describe output, object, context
  output.to_s.gsub(EOL, "\n")
end

describe "English help compatibility" do
  it "matches Athena's text descriptor for English command help" do
    with_english_locale do
      command = EnglishCompatCommand.new
      expected = describe_with(ACON::Descriptor::Text.new, command)
      actual = describe_with(Build::Console::LocalizedTextDescriptor.new, command)

      actual.should eq(expected)
    end
  end

  it "matches Athena's text descriptor for English application help" do
    with_english_locale do
      app = english_compat_app
      expected = describe_with(ACON::Descriptor::Text.new, app)
      actual = describe_with(Build::Console::LocalizedTextDescriptor.new, app)

      actual.should eq(expected)
    end
  end
end
