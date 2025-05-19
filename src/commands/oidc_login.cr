require "io/console"
require "uuid"
require "term-spinner"
require "netrc"

# This command is used to login to the Build API. The Build API token is stored in
# the user's netrc file. Because the commandline needs the token, it does a three-way
# OAuth authentication. This command requests a login authorization from Build, then
# opens a browser to have the users OAuth-accept that authorization. Once the user
# accepts the authorization, the command polls the Build API to get the user's token.
module Build
  module Commands
    @[ACONA::AsCommand("run")]
    class OidcLogin < Base
      protected def configure : Nil
        self
          .name("oidc-login")
          .option("region", "r", :required, "The region of the cluster to access")
          .description("Login to your Build cluster")
          .help("Login to your Build cluster")
          .usage("oidc-login -r eu-west-1")
      end
      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        region = input.option("region")
        unless region
          output.puts "<error>   Missing required option --region</error>"
          return ACON::Command::Status::FAILURE
        end
        output.puts api.oidc_login(region: region).to_json
        return ACON::Command::Status::SUCCESS
      end
    end
  end
end

