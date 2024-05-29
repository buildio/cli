require "io/console"
require "uuid"
require "term-spinner"
require "netrc"

module Build
  module Commands
    module Team
      @[ACONA::AsCommand("teams:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("teams:list")
            .description("List the teams you are a member of")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Teams include teams that you are a member of, and teams that you own.")
            .aliases(["teams"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          teams = api.teams
          if input.option("json", type: Bool)
            output.puts teams.to_json
          else
            output.puts "Teams you have access to:"
            output.puts ""
            teams.each do |team|
              output.puts "  #{team.name} (#{team.id})"
            end
          end
          return ACON::Command::Status::SUCCESS
        end
      end

      @[ACONA::AsCommand("teams:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("teams:info")
            .description("Get information about a team")
            .argument("team", :optional, "The team ID or name")
            .option("team", "t", :optional, "The team.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Get information about a team.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          team_input = input.argument("team", type: String | Nil) || input.option("team", type: String | Nil)
          if team_input.nil?
            output.puts "You must specify a team ID or name."
            return ACON::Command::Status::FAILURE
          end
          team = api.team(team_input)
          if input.option("json", type: Bool)
            output.puts team.to_json
          else
            output.puts "Team: #{team.name} (#{team.id})"
            # output.puts "  Owner: #{team.owner}"
            # output.puts "  Members:"
            # team.members.each do |member|
              # output.puts "    #{member.name} (#{member.email})"
            # end
          end
          return ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end
