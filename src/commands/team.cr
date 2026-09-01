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
            .description(t("commands.teams.list.description"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.teams.list.help"))
            .aliases(["teams"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          teams = api.teams
          if input.option("json", type: Bool)
            output.puts teams.to_json
          else
            output.puts t("runtime.teams.list.header")
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
            .description(t("commands.teams.info.description"))
            .argument("team", :optional, t("commands.common.arguments.team"))
            .option("team", "t", :optional, t("commands.common.options.team"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.teams.info.help"))
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          team_input = input.argument("team", type: String | Nil) || input.option("team", type: String | Nil)
          if team_input.nil?
            output.puts t("runtime.errors.must_specify_team")
            return ACON::Command::Status::FAILURE
          end
          team = api.team(team_input)
          if input.option("json", type: Bool)
            output.puts team.to_json
          else
            output.puts t("runtime.teams.info.title", name: team.name, id: team.id)
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
