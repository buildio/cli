module Build
  module Commands
    module Addons
      @[ACONA::AsCommand("addons")]
      class List < Base
        protected def configure : Nil
          self
            .name("addons")
            .description("List addons for an app or team.")
            .option("app", "a", :optional, "App name or ID.")
            .option("team", "t", :optional, "Team name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("List all addons provisioned for an app or team.")
            .aliases(["addons:list"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String?)
          team_name = input.option("team", type: String?)
          json_output = input.option("json", type: Bool)

          if (app_name.nil? || app_name.blank?) && (team_name.nil? || team_name.blank?)
            output.puts "<error>Specify --app or --team</error>"
            return ACON::Command::Status::FAILURE
          end

          begin
            api
            if team_name && !team_name.blank?
              addons = self.list_team_addons(team_name)
            else
              addons_api = Build::AddonsApi.new
              addons = addons_api.list_app_addons(app_name.not_nil!)
            end

            label = team_name || app_name
            if json_output
              output.puts addons.to_json
            else
              if addons.empty?
                output.puts "No addons for #{label}"
              else
                addons.each do |addon|
                  plan_name = addon.plan.name
                  addon_name = addon.name || addon.id
                  app_label = addon.app.name
                  output.puts "#{addon_name}  (#{plan_name})  #{addon.state}  #{app_label}"
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to list addons: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def list_team_addons(team_name : String) : Array(Build::Addon)
          path = "/api/v1/teams/#{URI.encode_path(team_name)}/addons"
          api_client = Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          data, _status, _headers = api_client.call_api(:GET, path,
            :"AddonsApi.list_app_addons", "Array(Addon)", nil, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          Array(Build::Addon).from_json(data)
        end
      end

      @[ACONA::AsCommand("addons:create")]
      class Create < Base
        protected def configure : Nil
          self
            .name("addons:create")
            .description("Create an addon for an app.")
            .argument("plan", :required, "Addon service and plan (e.g. bld-postgres:essential-0).")
            .option("app", "a", :required, "App name or ID.")
            .option("name", nil, :optional, "Custom name for the addon.")
            .option("description", "d", :optional, "Description for the addon.")
            .option("config", "c", ACON::Input::Option::Value[:optional, :is_array], "Config key=value (repeatable).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Provision a new addon for an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          plan = input.argument("plan", type: String)
          addon_name = input.option("name", type: String?)
          addon_description = input.option("description", type: String?)
          config_opts = input.option("config", type: Array(String))
          json_output = input.option("json", type: Bool)

          config = nil.as(Hash(String, Object)?)
          unless config_opts.empty?
            config = Hash(String, Object).new
            config_opts.each do |opt|
              k, _, v = opt.partition('=')
              config.not_nil![k] = v.as(Object)
            end
          end

          begin
            api
            addons_api = Build::AddonsApi.new
            req = Build::CreateAddonRequest.new(plan: plan, name: addon_name, description: addon_description, config: config)
            addon = addons_api.create_addon(app_name, req)

            if json_output
              output.puts addon.to_json
            else
              name = addon.name || addon.id
              output.puts "Creating #{plan} on #{app_name}... done, #{name} (#{addon.state})"
              if config_vars = addon.config_vars
                unless config_vars.empty?
                  output.puts "Config vars: #{config_vars.join(", ")}"
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to create addon: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("addons:info")
            .description("Show info about an addon.")
            .argument("addon", :required, "Addon name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Show detailed information about an addon, including attachments.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          addon_id = input.argument("addon", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            data = self.fetch_addon_info(addon_id)

            if json_output
              output.puts data
            else
              parsed = JSON.parse(data)
              name = parsed["name"]?.try(&.as_s?) || parsed["id"].as_s
              output.puts "=== #{name}"
              if desc = parsed["description"]?.try(&.as_s?)
                output.puts "Description:  #{desc}" unless desc.empty?
              end
              output.puts "Plan:         #{parsed["plan"]["name"]}"
              output.puts "Service:      #{parsed["addon_service"]["name"]}"
              output.puts "App:          #{parsed["app"]["name"]}"
              output.puts "State:        #{parsed["state"]}"
              if cvs = parsed["config_vars"]?
                vars = cvs.as_a.map(&.as_s)
                output.puts "Config Vars:  #{vars.join(", ")}" unless vars.empty?
              end
              if url = parsed["web_url"]?.try(&.as_s?)
                output.puts "Web URL:      #{url}" unless url.empty?
              end
              if price = parsed["billed_price"]?
                cents = price["cents"]?.try(&.as_i?)
                unit = price["unit"]?.try(&.as_s?)
                if cents && unit
                  output.puts "Price:        $#{"%.2f" % (cents / 100.0)}/#{unit}"
                end
              end
              if attachments = parsed["attachments"]?
                atts = attachments.as_a
                unless atts.empty?
                  output.puts ""
                  output.puts "=== Attachments"
                  atts.each do |att|
                    att_name = att["name"].as_s
                    app_name = att["app"]["name"].as_s
                    att_state = att["state"].as_s
                    output.puts "  #{att_name}  #{app_name}  #{att_state}"
                  end
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to get addon info: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def fetch_addon_info(addon_id : String) : String
          path = "/api/v1/addons/#{URI.encode_path(addon_id)}"
          api_client = Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          data, _status, _headers = api_client.call_api(:GET, path,
            :"UserAddonsApi.show", "String", nil, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          data
        end
      end

      @[ACONA::AsCommand("addons:destroy")]
      class Destroy < Base
        protected def configure : Nil
          self
            .name("addons:destroy")
            .description("Destroy an addon.")
            .argument("addon", :required, "Addon name or ID.")
            .option("app", "a", :required, "App name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Destroy an addon (deprovisions and removes from all attached apps).")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          addon_id = input.argument("addon", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            addons_api = Build::AddonsApi.new
            addon = addons_api.destroy_addon(app_name, addon_id)

            if json_output
              output.puts addon.to_json
            else
              name = addon.name || addon.id
              output.puts "Destroying #{name} on #{app_name}... done"
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to destroy addon: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:attach")]
      class Attach < Base
        protected def configure : Nil
          self
            .name("addons:attach")
            .description("Attach an addon to an app.")
            .argument("addon", :required, "Addon name or ID.")
            .option("app", "a", :required, "App name or ID to attach to.")
            .option("as", nil, :optional, "Attachment name (e.g. DATABASE_RED).")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Attach an existing addon to an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          addon_id = input.argument("addon", type: String)
          as_name = input.option("as", type: String?)
          json_output = input.option("json", type: Bool)

          begin
            api
            attachments_api = Build::AddonAttachmentsApi.new
            req = Build::CreateAddonAttachmentRequest.new(
              addon: addon_id,
              app: app_name,
              name: as_name,
              confirm: nil
            )
            attachment = attachments_api.create_addon_attachment(req)

            if json_output
              output.puts attachment.to_json
            else
              output.puts "Attaching #{addon_id} as #{attachment.name} to #{app_name}... done"
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to attach addon: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:detach")]
      class Detach < Base
        protected def configure : Nil
          self
            .name("addons:detach")
            .description("Detach an addon from an app.")
            .argument("attachment", :required, "Addon attachment ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Detach an addon from an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          attachment_id = input.argument("attachment", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            attachments_api = Build::AddonAttachmentsApi.new
            attachment = attachments_api.delete_addon_attachment(attachment_id)

            if json_output
              output.puts attachment.to_json
            else
              output.puts "Detaching #{attachment.name}... done"
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to detach addon: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end
    end
  end
end
