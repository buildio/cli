require "io/console"
require "uuid"
require "term-spinner"
require "netrc"

module Build
  module Commands
    module Config 
      @[ACONA::AsCommand("config:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("config:list")
            .usage("config:list -a my-app -s")
            .description("Get the config variables for an app.")
            .option("app",   "a", :required, "The name of the application.")
            .option("shell", "s", :none, "Output in shell format.")
            .option("json",  "j", :none, "Output in JSON format.")
            .help("Display the config variables for an app.")
            .aliases(["config"])
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          # TODO: API v2 should be more than just a hash
          app_name_or_id = input.option("app", type: String)
          config_vars    = api.config_vars(app_name_or_id)
          if input.option("json", type: Bool)
            # { "key".colorize(:blue).to_s ":".colorize(:yellow) "value".colorize(:green).to_s }
            output.puts "{"
            config_vars.each do |key, value|
              output.puts "  #{key.to_json}".colorize(:light_blue).to_s + ":".colorize(:light_yellow).to_s + " #{value.to_json},".colorize(:light_green).to_s
            end
            output.puts "}"
            # output.puts config_vars.to_json
          elsif input.option("shell", type: Bool)
            config_vars.each do |key, value|
              # If value contains [0-9a-zA-Z_\-\.], then it should be unquoted, otherwise single quote it
              # and escape its single quotes:
              if value.match(/^[0-9a-zA-Z_\-\.]+$/)
                output.puts "#{key}=#{value}"
              else
                output.puts "#{key}='#{value.gsub(/'/, "'\\\\''")}'"
              end
            end
          else
            # -> bold this part: #{app.name} Config Vars
            output.puts "===".colorize(:dark_gray).to_s + " #{app_name_or_id} Config Vars".colorize.bold.to_s
            output.puts ""
            # Widest key:
            key_width = config_vars.keys.map { |key| key.size }.max + 2
            # output.puts "Key width is #{key_width}"
            config_vars.each do |key, value|
              # Key should be GREEN
              # All keys should form a column wide as the largest key
              # that is left-aligned and one space away from the value
              output.puts "#{key}:".ljust(key_width).colorize(:green).to_s + value
            end
          end
          return ACON::Command::Status::SUCCESS
        end

#     @[ACONA::AsCommand("apps:info")]
#     class Info < Base
#       protected def configure : Nil
#         self
#           .name("apps:info")
#           .description("Show the details of a specific application.")
#           .argument("app", :optional, "The ID or NAME of the app to show.")
#           .option("app", "a", :optional, "The app")
#           .option("json", "j", :none, "Output in JSON format.")
#       end
#       protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
#         app_input = input.argument("app", type: String | Nil) || input.option("app", type: String | Nil)
#         if app_input.nil?
#           output.puts "You must specify an app ID or NAME."
#           return ACON::Command::Status::FAILURE
#         end
#         app = api.app(app_input)
#         if input.option("json", type: Bool)
#           output.puts app.to_json
#         else
#           output.puts "App details:"
#           output.puts ""
#           output.puts "  Name: #{app.name}"
#           output.puts "  ID:   #{app.id}"
#         end
#         return ACON::Command::Status::SUCCESS
#       end
      end
    end
  end
end

