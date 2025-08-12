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
            .usage("config:list -a my-app -s  OR  config:list -e ENV-ID -j")
            .description("Get the config variables for an app or environment.")
            .option("app",   "a", :optional, "The name of the application.")
            .option("environment", "e", :optional, "The environment ID (for pipeline environments).")
            .option("shell", "s", :none, "Output in shell format.")
            .option("json",  "j", :none, "Output in JSON format.")
            .help("Display the config variables for an app or environment.")
            .aliases(["config"])
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            # TODO: API v2 should be more than just a hash
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   Missing required option --app or --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   Cannot specify both --app and --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            config_vars = if env_id && !env_id.blank?
              # Use environment endpoint
              response = api.api_v1_environments_id_get(env_id)
              # Convert response to Hash(String, String)
              if response.is_a?(Hash)
                Hash(String, String).new.tap do |h|
                  response.each do |k, v|
                    h[k.to_s] = v.to_s
                  end
                end
              else
                Hash(String, String).new
              end
            else
              api.config_vars(app_name_or_id.not_nil!)
            end
            
            if input.option("json", type: Bool)
              output.puts config_vars.to_json
            elsif input.option("shell", type: Bool)
              config_vars.each do |key, value|
                if value.match(/^[0-9a-zA-Z_\-\.]+$/)
                  output.puts "#{key}=#{value}"
                else
                  output.puts "#{key}='#{value.gsub(/'/, "'\\\\''")}'"
                end
              end
            else
              entity_name = (env_id && !env_id.blank?) ? "Environment #{env_id}" : app_name_or_id
              output.puts "===".colorize(:dark_gray).to_s + " #{entity_name} Config Vars".colorize.bold.to_s
              output.puts ""
              if config_vars.empty?
                output.puts "(no config vars set)".colorize(:dark_gray).to_s
              else
                key_width = config_vars.keys.map { |key| key.size }.max + 2
                config_vars.each do |key, value|
                  output.puts "#{key}:".ljust(key_width).colorize(:green).to_s + value
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            error_msg = ex.message || ""
            if error_msg.blank? || error_msg == ""
              output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
              output.puts "      1. Is the server running? (rails server)"
              output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
              output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
              output.puts "      Debug: #{ex.class.name}"
            else
              output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
            end
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("config:get")]
      class Info < Base
        protected def configure : Nil
          self
            .name("config:get")
            .usage("config:get KEY... -a my-app  OR  -e ENV-ID")
            .description("Get the config variables for an app or environment.")
            .argument("KEY", ACON::Input::Argument::Mode[:required, :is_array], "The name of the config variable(s) to get.")
            .option("app",   "a", :optional, "The name of the application.")
            .option("environment", "e", :optional, "The environment ID (for pipeline environments).")
            .option("shell", "s", :none, "Output in shell format.")
            .option("json",  "j", :none, "Output in JSON format.")
            .help("Display the config variables for an app or environment.")
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   Missing required option --app or --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   Cannot specify both --app and --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            config_vars = if env_id && !env_id.blank?
              # Use environment endpoint
              response = api.api_v1_environments_id_get(env_id)
              # Convert response to Hash(String, String)
              if response.is_a?(Hash)
                Hash(String, String).new.tap do |h|
                  response.each do |k, v|
                    h[k.to_s] = v.to_s
                  end
                end
              else
                Hash(String, String).new
              end
            else
              api.config_vars(app_name_or_id.not_nil!)
            end
            
            varnames = input.argument("KEY", type: Array(String))
            if varnames.empty?
              output.puts("<error>   Missing required argument KEY</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if input.option("json", type: Bool)
              result = Hash(String, String).new
              varnames.each { |k| result[k] = config_vars[k] if config_vars.has_key?(k) }
              output.puts result.to_json
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
              varnames.each do |varname|
                value = config_vars[varname]
                output.puts "#{value}"
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            error_msg = ex.message || ""
            if error_msg.blank? || error_msg == ""
              output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
              output.puts "      1. Is the server running? (rails server)"
              output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
              output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
              output.puts "      Debug: #{ex.class.name}"
            else
              output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
            end
            return ACON::Command::Status::FAILURE
          end
        end
      end
      
      @[ACONA::AsCommand("config:set")]
      class Create < Base
        protected def configure : Nil
          self
            .name("config:set")
            .usage("config:set KEY1=VALUE1 [KEY2=VALUE2 ...] -a my-app  OR  -e ENV-ID")
            .description("Set a config variable for an app or environment.")
            .argument("KEY=VALUE", ACON::Input::Argument::Mode[:required, :is_array], "The name and value of the config variable(s) to set.")
            .option("app", "a", :optional, "The name of the application.")
            .option("environment", "e", :optional, "The environment ID (for pipeline environments).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Set a config variable for an app or environment.")
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            show_json = input.option("json", type: Bool)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   Missing required option --app or --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   Cannot specify both --app and --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            varname_values = input.argument("KEY=VALUE", type: Array(String))
            if varname_values.empty?
              output.puts("<error>   Must specify KEY and VALUE </error>")
              return ACON::Command::Status::FAILURE
            end
            
            # Parse the key=value pairs
            updates = Hash(String, String).new
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
              updates[varname] = value
            end
            
            if env_id && !env_id.blank?
              # Use environment endpoint - PATCH with the updates
              api.api_v1_environments_id_patch(env_id, updates)
              if !show_json
                output.puts "Setting config vars for environment... done".colorize(:green).to_s
                updates.each do |key, value|
                  output.puts "#{key}: #{value}"
                end
              end
            else
              # Get existing config vars and merge
              if app_name_or_id
                config_vars = api.config_vars(app_name_or_id)
                updates.each do |k, v|
                  config_vars[k] = v
                end
                api.set_config_vars(app_name_or_id, config_vars)
                if !show_json
                  output.puts "Setting config vars for #{app_name_or_id}... done".colorize(:green).to_s
                  updates.each do |key, value|
                    output.puts "#{key}: #{value}"
                  end
                end
              end
            end
            
            if show_json
              output.puts updates.to_json
            end
            
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            error_msg = ex.message || ""
            if error_msg.blank? || error_msg == ""
              output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
              output.puts "      1. Is the server running? (rails server)"
              output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
              output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
              output.puts "      Debug: #{ex.class.name}"
            else
              output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
            end
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("config:unset")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("config:unset")
            .usage("config:unset KEY1 [KEY2 ...] -a my-app  OR  -e ENV-ID")
            .description("Unset config variables for an app or environment.")
            .argument("KEY", :required, "The name of the config variable(s) to unset.")
            .option("app", "a", :optional, "The name of the application.")
            .option("environment", "e", :optional, "The environment ID (for pipeline environments).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Unset a config variable for an app or environment.")
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            show_json = input.option("json", type: Bool)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   Missing required option --app or --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   Cannot specify both --app and --environment</error>")
              return ACON::Command::Status::FAILURE
            end
            
            varnames = input.argument("KEY", type: Array(String))
            if varnames.empty?
              output.puts("<error>   Missing required argument KEY</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if env_id && !env_id.blank?
              # Use environment endpoint - delete each key
              varnames.each do |varname|
                api.api_v1_environments_id_key_delete(env_id, varname)
              end
              if !show_json
                output.puts "Unsetting config vars for environment... done".colorize(:green).to_s
                varnames.each do |key|
                  output.puts "Removed: #{key}"
                end
              end
            else
              # Use app endpoint
              if app_name_or_id
                varnames.each do |varname|
                  api.delete_config_var(app_name_or_id, varname)
                end
                if !show_json
                  output.puts "Unsetting config vars for #{app_name_or_id}... done".colorize(:green).to_s
                  varnames.each do |key|
                    output.puts "Removed: #{key}"
                  end
                end
              end
            end
            
            if show_json
              output.puts "{\"removed\": #{varnames.to_json}}"
            end
            
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            error_msg = ex.message || ""
            if error_msg.blank? || error_msg == ""
              output.puts ">".colorize(:red).to_s + "   API request failed. Please check:"
              output.puts "      1. Is the server running? (rails server)"
              output.puts "      2. Is your API token valid? Check ~/.netrc or set BUILD_API_KEY"
              output.puts "      3. Is the API URL correct? Set BUILD_API_URL=http://localhost:3000"
              output.puts "      Debug: #{ex.class.name}"
            else
              output.puts ">".colorize(:red).to_s + "   Error: #{error_msg}"
            end
            return ACON::Command::Status::FAILURE
          end
        end
      end
    end
  end
end