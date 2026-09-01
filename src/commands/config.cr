require "io/console"
require "uuid"
require "term-spinner"
require "netrc"
require "../env_format"

module Build
  module Commands
    module Config
      @[ACONA::AsCommand("config:list")]
      class List < Base
        protected def configure : Nil
          self
            .name("config:list")
            .usage(t("runtime.config.list.usage"))
            .description(t("commands.config.list.description"))
            .option("app",   "a", :optional, t("commands.common.options.app_name"))
            .option("environment", "e", :optional, t("commands.common.options.environment"))
            .option("shell", "s", :none, t("commands.common.options.shell"))
            .option("json",  "j", :none, t("commands.common.options.json"))
            .help(t("commands.config.list.help"))
            .aliases(["config"])
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            # TODO: API v2 should be more than just a hash
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.missing_app_or_environment")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.app_and_environment_exclusive")}</error>")
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
                output.puts Build::EnvFormat.shell_format_kv(key, value)
              end
            else
              entity_name = (env_id && !env_id.blank?) ? t("runtime.labels.environment", id: env_id) : app_name_or_id
              output.puts "===".colorize(:dark_gray).to_s + " " + t("runtime.config.vars_title", target: entity_name).colorize.bold.to_s
              output.puts ""
              if config_vars.empty?
                output.puts t("runtime.config.no_vars_set").colorize(:dark_gray).to_s
              else
                key_width = config_vars.keys.map { |key| key.size }.max + 2
                config_vars.each do |key, value|
                  output.puts "#{key}:".ljust(key_width).colorize(:green).to_s + value
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            print_api_error(output, ex)
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("config:get")]
      class Info < Base
        protected def configure : Nil
          self
            .name("config:get")
            .usage(t("runtime.config.get.usage"))
            .description(t("commands.config.get.description"))
            .argument("KEY", ACON::Input::Argument::Mode[:required, :is_array], t("commands.config.get.arguments.key"))
            .option("app", "a", :optional, t("commands.common.options.app_name"))
            .option("environment", "e", :optional, t("commands.common.options.environment"))
            .option("shell", "s", :none, t("commands.common.options.shell"))
            .option("json",  "j", :none, t("commands.common.options.json"))
            .help(t("commands.config.get.help"))
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.missing_app_or_environment")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.app_and_environment_exclusive")}</error>")
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
              output.puts("<error>   #{t("runtime.errors.missing_key_argument")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if input.option("json", type: Bool)
              result = Hash(String, String).new
              varnames.each { |k| result[k] = config_vars[k] if config_vars.has_key?(k) }
              output.puts result.to_json
            elsif input.option("shell", type: Bool)
              varnames.each do |varname|
                output.puts Build::EnvFormat.shell_format_kv(varname, config_vars[varname])
              end
            else
              varnames.each do |varname|
                value = config_vars[varname]
                output.puts "#{value}"
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            print_api_error(output, ex)
            return ACON::Command::Status::FAILURE
          end
        end
      end
      
      @[ACONA::AsCommand("config:set")]
      class Create < Base
        protected def configure : Nil
          self
            .name("config:set")
            .usage(t("runtime.config.set.usage"))
            .description(t("commands.config.set.description"))
            .argument("KEY=VALUE", ACON::Input::Argument::Mode[:optional, :is_array], t("commands.config.set.arguments.key_value"))
            .option("app", "a", :optional, t("commands.common.options.app_name"))
            .option("environment", "e", :optional, t("commands.common.options.environment"))
            .option("chunk-size", nil, :optional, t("commands.config.set.options.chunk_size"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.config.set.help"))
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
            t("runtime.config.upstream_gateway_error", status: status)
          elsif code
            "HTTP #{code}: #{body}"
          else
            body.empty? ? ex.class.name : body
          end
        end

        # Parser lives in Build::EnvFormat. See env_format.cr for grammar
        # and the security guarantee (this never evaluates shell).
        private def parse_stdin_env(raw : String) : Hash(String, String)
          Build::EnvFormat.parse(raw)
        end


        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            show_json = input.option("json", type: Bool)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.missing_app_or_environment")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.app_and_environment_exclusive")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            varname_values = input.argument("KEY=VALUE", type: Array(String))

            # Parse the key=value pairs from arguments
            updates = Hash(String, String).new
            varname_values.each do |varname_value|
              if varname_value !~ /=/
                output.puts("<error>   #{t("runtime.config.must_be_key_value")}</error>")
                return ACON::Command::Status::FAILURE
              end
              varname, value = varname_value.split("=", 2)
              if varname.blank?
                output.puts("<error>   #{t("runtime.config.invalid_key_value", value: varname_value)}</error>")
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
              output.puts("<error>   #{t("runtime.config.must_specify_key_value_or_stdin")}</error>")
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
                  output.puts ">".colorize(:red).to_s + "   " + t("runtime.config.partial_failure", index: idx, count: chunks.size)
                end
                print_error(output, friendly_error(ex))
                return ACON::Command::Status::FAILURE
              end
            end

            if !show_json
              output.puts t("runtime.config.setting_done", target: target).colorize(:green).to_s
              updates.each { |key, value| output.puts "#{key}: #{value}" }
            else
              output.puts updates.to_json
            end

            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            print_error(output, friendly_error(ex))
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("config:unset")]
      class Delete < Base
        protected def configure : Nil
          self
            .name("config:unset")
            .usage(t("runtime.config.unset.usage"))
            .description(t("commands.config.unset.description"))
            .argument("KEY", :required, t("commands.config.unset.arguments.key"))
            .option("app", "a", :optional, t("commands.common.options.app_name"))
            .option("environment", "e", :optional, t("commands.common.options.environment"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.config.unset.help"))
        end
        
        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          begin
            app_name_or_id = input.option("app", type: String?)
            env_id = input.option("environment", type: String?)
            show_json = input.option("json", type: Bool)
            
            if (app_name_or_id.nil? || app_name_or_id.blank?) && (env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.missing_app_or_environment")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if !(app_name_or_id.nil? || app_name_or_id.blank?) && !(env_id.nil? || env_id.blank?)
              output.puts("<error>   #{t("runtime.errors.app_and_environment_exclusive")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            varnames = input.argument("KEY", type: Array(String))
            if varnames.empty?
              output.puts("<error>   #{t("runtime.errors.missing_key_argument")}</error>")
              return ACON::Command::Status::FAILURE
            end
            
            if env_id && !env_id.blank?
              # Use environment endpoint - delete each key
              varnames.each do |varname|
                api.api_v1_environments_id_key_delete(env_id, varname)
              end
              if !show_json
                output.puts t("runtime.config.unsetting_environment_done").colorize(:green).to_s
                varnames.each do |key|
                  output.puts t("runtime.config.removed", key: key)
                end
              end
            else
              # Use app endpoint
              if app_name_or_id
                varnames.each do |varname|
                  api.delete_config_var(app_name_or_id, varname)
                end
                if !show_json
                  output.puts t("runtime.config.unsetting_app_done", app: app_name_or_id).colorize(:green).to_s
                  varnames.each do |key|
                    output.puts t("runtime.config.removed", key: key)
                  end
                end
              end
            end
            
            if show_json
              output.puts "{\"removed\": #{varnames.to_json}}"
            end
            
            return ACON::Command::Status::SUCCESS
          rescue ex : Exception
            print_api_error(output, ex)
            return ACON::Command::Status::FAILURE
          end
        end
      end
    end
  end
end