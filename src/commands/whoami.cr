module Build
  module Commands
    @[ACONA::AsCommand("whoami")]
    class Whoami < Base
      protected def configure : Nil
        self
          .name("whoami")
          .description("Display the current logged in user")
          .help("Build commands run through the CLI use the API with permission level of this user. To see the current user, run this command. To change users, see the login command.")
          .aliases(["me"])
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        output.puts "#{api.me.email}"
        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
