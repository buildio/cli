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
            .usage("config:get KEY... -a my-app  OR  config:get KEY... -e ENV-ID")
            .description("Get the config variables for an app or environment.")
            .argument("KEY", ACON::Input::Argument::Mode[:required, :is_array], "The name of the config variable(s) to get.")
            .option("app", "a", :optional, "The name of the application.")
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
            .usage("config:set KEY1=VALUE1 [KEY2=VALUE2 ...] -a my-app  OR  -e ENV-ID  OR  ... < env.out")
            .description("Set config variables for an app or environment. Reads from STDIN when piped.")
            .argument("KEY=VALUE", ACON::Input::Argument::Mode[:optional, :is_array], "The name and value of the config variable(s) to set. Omit to read from STDIN.")
            .option("app", "a", :optional, "The name of the application.")
            .option("environment", "e", :optional, "The environment ID (for pipeline environments).")
            .option("chunk-size", nil, :optional, "Max vars per API call when setting many at once (default: 20).")
            .option("json", "j", :none, "Output in JSON format.")
            .help(<<-HELP
            Set config variables for an app or environment.

            Values can be provided as KEY=VALUE arguments, or piped on STDIN using
            the shell format emitted by `bld config -s` (KEY=value or KEY='value').
            Blank lines, `#` comments, and an optional `export` prefix are ignored.

            Large batches are sent in chunks (default 20 vars per call) to avoid
            upstream request timeouts. Tune with --chunk-size.

            Examples:
              bld config:set KEY1=val1 KEY2=val2 -a my-app
              bld config -a src-app -s | bld config:set -a dst-app
              bld config -a src-app -s > env.out && bld config:set -a dst-app < env.out
              bld config:set -a my-app --chunk-size 10 < big.env
            HELP
            )
        end

        # Translate an exception into a short, user-facing string. Upstream
        # gateways (load balancers, proxies) often return HTML error pages
        # on timeout or backend crash — surface a terse message instead of
        # dumping markup at the user.
        private def friendly_error(ex : Exception) : String
          body = (ex.message || "").strip
          code = ex.is_a?(Build::ApiError) ? ex.code : nil
          looks_html = body.starts_with?("<") ||
                       body.includes?("<!DOCTYPE") ||
                       body.includes?("<html")
          if looks_html
            status = code ? " (HTTP #{code})" : ""
            "upstream gateway returned an error page#{status}. The backend likely timed out or errored mid-request. For large config:set batches, try a smaller --chunk-size."
          elsif code
            "HTTP #{code}: #{body}"
          else
            body.empty? ? ex.class.name : body
          end
        end

        # Parse shell-style env lines from STDIN. Matches the output of
        # `config:list -s` and is lenient enough to accept common .env formats.
        private def parse_stdin_env(raw : String) : Hash(String, String)
          result = Hash(String, String).new
          raw.each_line do |line|
            line = line.strip
            next if line.empty? || line.starts_with?("#")
            line = line.sub(/^export\s+/, "")
            idx = line.index('=')
            next unless idx
            key = line[0...idx].strip
            val = line[(idx + 1)..]
            next if key.empty?
            if val.size >= 2 && val.starts_with?('\'') && val.ends_with?('\'')
              val = val[1...-1].gsub("'\\''", "'")
            elsif val.size >= 2 && val.starts_with?('"') && val.ends_with?('"')
              val = val[1...-1].gsub("\\\"", "\"").gsub("\\\\", "\\")
            end
            result[key] = val
          end
          result
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

            # Parse the key=value pairs from arguments
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

            # Merge in any values piped on STDIN (shell format from `config -s`).
            # CLI args take precedence over STDIN on key conflicts.
            if !STDIN.tty?
              stdin_data = STDIN.gets_to_end
              unless stdin_data.empty?
                stdin_updates = parse_stdin_env(stdin_data)
                stdin_updates.each do |k, v|
                  updates[k] = v unless updates.has_key?(k)
                end
              end
            end

            if updates.empty?
              output.puts("<error>   Must specify KEY=VALUE or pipe shell-format env vars on STDIN</error>")
              return ACON::Command::Status::FAILURE
            end
            
            # Chunk large batches to keep each request under upstream
            # gateway timeouts. PATCH has merge semantics, so splitting is
            # safe: each chunk adds its keys without disturbing others.
            chunk_size = (input.option("chunk-size", type: String?).try(&.to_i?) || 20)
            chunk_size = 1 if chunk_size < 1
            chunks = updates.to_a.each_slice(chunk_size).to_a
            target = env_id && !env_id.blank? ? "environment #{env_id}" : app_name_or_id.to_s

            chunks.each_with_index do |pairs, idx|
              chunk_hash = pairs.to_h
              begin
                if env_id && !env_id.blank?
                  api.api_v1_environments_id_patch(env_id, chunk_hash)
                else
                  api.set_config_vars(app_name_or_id.not_nil!, chunk_hash)
                end
              rescue ex : Exception
                if !show_json && idx > 0
                  output.puts ">".colorize(:red).to_s + "   Partial failure: #{idx}/#{chunks.size} chunks applied before this error."
                end
                output.puts ">".colorize(:red).to_s + "   Error: #{friendly_error(ex)}"
                return ACON::Command::Status::FAILURE
              end
            end

            if !show_json
              output.puts "Setting config vars for #{target}... done".colorize(:green).to_s
              updates.each { |key, value| output.puts "#{key}: #{value}" }
            else
              output.puts updates.to_json
            end

            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            output.puts ">".colorize(:red).to_s + "   Error: #{friendly_error(ex)}"
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