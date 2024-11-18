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
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
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
      end

      # Add config:get VARNAME1 VARNAME2 -a antimony-staging 
      # postgres://ucbr51k32p4sv1j...
      # rediss://:p660d780c02c93e9b...
      # config:get DATABASE_URL REDIS_URL -s -a antimony-staging 
      # DATABASE_URL='postgres://ucbr51k32p4sv1...'
      # REDIS_URL='rediss://:p660d780c...'
      @[ACONA::AsCommand("config:get")]
      class Info < Base
        protected def configure : Nil
          self
            .name("config:get")
            .usage("config:get KEY... -a my-app")
            .description("Get the config variables for an app.")
            .argument("KEY", ACON::Input::Argument::Mode[:required, :is_array], "The name of the config variable(s) to get.")
            .option("app",   "a", :required, "The name of the application.")
            .option("shell", "s", :none, "Output in shell format.")
            .option("json",  "j", :none, "Output in JSON format.")
            .help("Display the config variables for an app.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          config_vars    = api.config_vars(app_name_or_id)
          varnames       = input.argument("KEY", type: Array(String))
          if varnames.empty?
            output.puts("<error>   Missing required argument KEY</error>")
            return ACON::Command::Status::FAILURE
          end
          if input.option("json", type: Bool)
            output.puts "{"
            varnames.each do |varname|
              value = config_vars[varname]
              output.puts "  #{varname.to_json}".colorize(:light_blue).to_s + ":".colorize(:light_yellow).to_s + " #{value.to_json},".colorize(:light_green).to_s
            end
            output.puts "}"
          elsif input.option("shell", type: Bool)
            varnames.each do |varname|
              value = config_vars[varname]
              if value.match(/^[0-9a-zA-Z_\-\.]+$/)
                output.puts "#{varname}=#{value}"
              else
                output.puts "#{varname}='#{value.gsub(/'/, "'\\\\''")}'"
              end
            end
          else
            # Just print them out so this can be used in a script, etc...
            varnames.each do |varname|
              value = config_vars[varname]
              output.puts "#{value}"
            end
          end
          return ACON::Command::Status::SUCCESS
        end
      end
      

      # Add config:set VARNAME1=VALUE1 VARNAME2=VALUE2 -a antimony-staging
      @[ACONA::AsCommand("config:set")]
      class Create < Base
        protected def configure : Nil
          self
            .name("config:set")
            .usage("config:set KEY1=VALUE1 [KEY2=VALUE2 ...] -a my-app")
            .description("Set a config variable for an app.")
            .argument("KEY=VALUE", ACON::Input::Argument::Mode[:required, :is_array], "The name and value of the config variable(s) to set.")
            .option("app", "a", :required, "The name of the application.")
            .help("Set a config variable for an app.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          varname_values = input.argument("KEY=VALUE", type: Array(String))
          if varname_values.empty?
            output.puts("<error>   Must specify KEY and VALUE </error>")
            return ACON::Command::Status::FAILURE
          end
          config_vars = api.config_vars(app_name_or_id)
          varname_values.each do |varname_value|
            if varname_value !~ /=/
              output.puts("<error>   Must be in the format KEY=VALUE</error>")
              return ACON::Command::Status::FAILURE
            end
            varname, value = varname_value.split("=", 2)
            if varname.blank?
              output.puts("<error>   #{varname_value} is invalid. Must be in the format KEY=VALUE</error>")
              return ACON::Command::Status::FAILURE
            end
            config_vars[varname] = value
          end
          api.set_config_vars(app_name_or_id, config_vars)
          return ACON::Command::Status::SUCCESS
        end
      end

      # Add config:unset VARNAME1 VARNAME2 -a antimony-staging
      @[ACONA::AsCommand("config:unset")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("config:unset")
            .usage("config:unset KEY1 [KEY2 ...] -a my-app")
            .description("Unset config variables for an app.")
            .argument("KEY", :required, "The name of the config variable(s) to unset.")
            .option("app", "a", :required, "The name of the application.")
            .help("Unset a config variable for an app.")
        end
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name_or_id = input.option("app", type: String)
          if app_name_or_id.blank?
            output.puts("<error>   Missing required option --app</error>")
            return ACON::Command::Status::FAILURE
          end
          config_vars = api.config_vars(app_name_or_id)
          varnames    = input.argument("KEY", type: Array(String))
          if varnames.empty?
            output.puts("<error>   Missing required argument VARNAME</error>")
            return ACON::Command::Status::FAILURE
          end
          varnames.each do |varname|
            api.delete_config_var(app_name_or_id, varname)
          end
          return ACON::Command::Status::SUCCESS
        end
      end
    end
  end
end

