module Build
  module Commands
    @[ACONA::AsCommand("skills")]
    class Skills < Base
      private SKILL_SECTION_KEYS = {
        "runtime.skills.intro",
        "runtime.skills.cold_start",
        "runtime.skills.command_reference_auth",
        "runtime.skills.command_reference_apps",
        "runtime.skills.command_reference_config_vars",
        "runtime.skills.command_reference_git_push",
        "runtime.skills.command_reference_processes",
        "runtime.skills.command_reference_buildpacks",
        "runtime.skills.command_reference_addons",
        "runtime.skills.command_reference_domains",
        "runtime.skills.command_reference_pipelines",
        "runtime.skills.command_reference_logs",
        "runtime.skills.command_reference_teams",
        "runtime.skills.tips",
      }

      protected def configure : Nil
        self
          .name("skills")
          .description(t("commands.skills.description"))
          .help(t("commands.skills.help"))
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        output.puts(String.build do |io|
          SKILL_SECTION_KEYS.each_with_index do |section, index|
            io << "\n\n" unless index == 0
            io << t(section)
          end
        end)
        ACON::Command::Status::SUCCESS
      end
    end
  end
end
