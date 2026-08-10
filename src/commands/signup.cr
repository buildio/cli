require "netrc"

# This command is used to sign up for a Build account entirely from the CLI, so an
# agent can sign a user up on their behalf with just an email address. It sends the
# email to the Build API, which sends a verification link to that address. Once the
# user clicks the link and finishes creating their account, they can authenticate
# with `bld login`.
#
# NOTE: `DefaultApi#signup` does not exist in the generated SDK yet — it is added
# by a follow-up buildio/sdk-crystal-lang PR, so this file does not compile until
# that SDK update is pinned.
module Build
  module Commands
    @[ACONA::AsCommand("signup")]
    class Signup < Base
      protected def configure : Nil
        self
          .name("signup")
          .description("Sign up for a Build account")
          .help("This command is used to sign up for a Build account without leaving the terminal. It sends a verification email to the given address. Click the link in the email to finish creating the account, then run `bld login` to authenticate. Note that region access is granted separately, so a newly created account may not have access to any region yet.")
          .option("email", "e", :required, "The email address to sign up with.")
          .usage("signup -e user@example.com")
      end
      def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        email = input.option("email")
        unless email
          output.puts "<error>   Missing required option --email</error>"
          return ACON::Command::Status::FAILURE
        end

        begin
          # Signup is unauthenticated, so build the client directly instead of
          # going through Base#api, which exits when no token is stored.
          api_instance = Build::DefaultApi.new
          api_instance.signup(email)
        rescue e : Build::ApiError
          error_message = begin
            JSON.parse(e.message.to_s)["error"].to_s
          rescue
            e.message
          end
          output.puts("Signup failed: #{error_message}".colorize(:red))
          return ACON::Command::Status::FAILURE
        end

        output.puts "Verification email sent to #{email.colorize(:green)}."
        output.puts "Click the link in the email to finish creating your account, then run #{"bld login".colorize(:cyan)} to authenticate."
        output.puts "Note: region access is granted separately — a new account may not have access to any region yet."
        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
