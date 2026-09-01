module Build
  module Commands
    @[ACONA::AsCommand("whoami")]
    class Whoami < Base
      protected def configure : Nil
        self
          .name("whoami")
          .description(t("commands.whoami.description"))
          .help(t("commands.whoami.help"))
          .aliases(["me"])
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        output.puts "#{api.me.email}"
        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
