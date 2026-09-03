require "../console/localized_text_descriptor"

module Build
  module Commands
    @[ACONA::AsCommand("help")]
    class Help < ACON::Commands::Help
      protected def configure : Nil
        self.ignore_validation_errors

        self
          .name("help")
          .description(::Build.t("console.commands.help.description"))
          .argument("command_name", description: ::Build.t("console.commands.help.argument"), default: "help") { ACON::Descriptor::Application.new(self.application).commands.keys }
          .option("format", value_mode: :required, description: ::Build.t("console.commands.help.format"), default: "txt") { ACON::Helper::Descriptor.new.formats }
          .option("raw", value_mode: :none, description: ::Build.t("console.commands.help.raw"))
          .help(::Build.t("console.commands.help.help"))
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        if @command.nil?
          @command = self.application.find input.argument("command_name", String)
        end

        ::Build::Console::LocalizedTextDescriptor.new.describe(
          output,
          @command.not_nil!,
          ACON::Descriptor::Context.new(
            format: input.option("format", String),
            raw_text: input.option("raw", Bool),
          )
        )

        @command = nil

        ACON::Command::Status::SUCCESS
      end
    end

    @[ACONA::AsCommand("list")]
    class List < ACON::Commands::List
      protected def configure : Nil
        self
          .name("list")
          .description(::Build.t("console.commands.list.description"))
          .argument("namespace", description: ::Build.t("console.commands.list.argument")) { ACON::Descriptor::Application.new(self.application).namespaces.keys }
          .option("raw", value_mode: :none, description: ::Build.t("console.commands.list.raw"))
          .option("format", value_mode: :required, description: ::Build.t("console.commands.list.format"), default: "txt") { ACON::Helper::Descriptor.new.formats }
          .option("short", value_mode: :none, description: ::Build.t("console.commands.list.short"))
          .help(::Build.t("console.commands.list.help"))
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        ::Build::Console::LocalizedTextDescriptor.new.describe(
          output,
          self.application,
          ACON::Descriptor::Context.new(
            format: input.option("format", String),
            raw_text: input.option("raw", Bool),
            namespace: input.argument("namespace", String?),
            short: input.option("short", Bool)
          )
        )

        ACON::Command::Status::SUCCESS
      end
    end

    @[ACONA::AsCommand("completion")]
    class Completion < ACON::Commands::DumpCompletion
      private SUPPORTED_SHELLS = {{ ACON::Completion::Output::Interface.subclasses.map(&.name.split("::").last.downcase) }}

      protected def configure : Nil
        full_command = ::Process.executable_path || ""
        command_name = ::File.basename full_command
        shell = self.class.guess_shell

        rc_file, completion_file = case shell
                                   when "fish" then {"~/.config/fish/config.fish", "/etc/fish/completions/#{command_name}.fish"}
                                   when "zsh"  then {"~/.zshrc", "$fpath[1]/_#{command_name}"}
                                   else             {"~/.bashrc", "/etc/bash_completion.d/#{command_name}"}
                                   end

        self
          .name("completion")
          .description(::Build.t("console.commands.completion.description"))
          .argument("shell", description: ::Build.t("console.commands.completion.argument"), suggested_values: SUPPORTED_SHELLS)
          .help(::Build.t("console.commands.completion.help", shells: SUPPORTED_SHELLS.join(", "), shell: shell, completion_file: completion_file, rc_file: rc_file, full_command: full_command))
      end
    end
  end
end
