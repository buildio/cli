module Build
  module Commands
    module Addons
      @[ACONA::AsCommand("addons")]
      class List < Base
        protected def configure : Nil
          self
            .name("addons")
            .description(t("commands.addons.list.description"))
            .option("app", "a", :optional, t("commands.common.options.app_id_or_name"))
            .option("team", "t", :optional, t("commands.common.options.team"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.list.help"))
            .aliases(["addons:list"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String?)
          team_name = input.option("team", type: String?)
          json_output = input.option("json", type: Bool)

          if (app_name.nil? || app_name.blank?) && (team_name.nil? || team_name.blank?)
            output.puts "<error>#{t("runtime.errors.specify_app_or_team")}</error>"
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
                output.puts t("runtime.addons.list.none", label: label)
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
            output.puts "<error>#{t("runtime.addons.list.failed", error: e.message)}</error>"
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

      @[ACONA::AsCommand("addons:services")]
      class Services < Base
        protected def configure : Nil
          self
            .name("addons:services")
            .description(t("commands.addons.services.description"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.services.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          json_output = input.option("json", type: Bool)

          begin
            api
            data = self.fetch_services
            if json_output
              output.puts data
            else
              parsed = JSON.parse(data)
              headers = {t("runtime.addons.headers.slug"), t("runtime.addons.headers.name"), t("runtime.addons.headers.summary"), t("runtime.addons.headers.state")}
              rows = parsed.as_a.map do |svc|
                {svc["name"].as_s, svc["human_name"]?.try(&.as_s?) || svc["name"].as_s, svc["summary"]?.try(&.as_s?) || "", svc["state"]?.try(&.as_s?) || ""}
              end
              print_table(output, headers, rows)
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>#{t("runtime.addons.services.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def fetch_services : String
          path = "/api/v1/addon-services"
          api_client = Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          data, _status, _headers = api_client.call_api(:GET, path,
            :"AddonServicesApi.index", "String", nil, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          data
        end
      end

      @[ACONA::AsCommand("addons:plans")]
      class Plans < Base
        protected def configure : Nil
          self
            .name("addons:plans")
            .description(t("commands.addons.plans.description"))
            .argument("service", :required, t("commands.addons.plans.arguments.service"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.plans.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          service_name = input.argument("service", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            data = self.fetch_plans(service_name)
            if json_output
              output.puts data
            else
              parsed = JSON.parse(data)
              headers = {t("runtime.addons.headers.default"), t("runtime.addons.headers.slug"), t("runtime.addons.headers.name"), t("runtime.addons.headers.price")}
              rows = parsed.as_a.map do |plan|
                is_default = plan["default"]?.try(&.as_bool?) ? t("runtime.addons.default_marker") : ""
                slug = "#{service_name}:#{plan["name"].as_s}"
                human = plan["human_name"]?.try(&.as_s?) || plan["name"].as_s
                cents = plan["monthly_price"]?.try(&.["cents"]?.try(&.as_i?))
                unit = plan["monthly_price"]?.try(&.["unit"]?.try(&.as_s?))
                price = (cents && unit) ? "$#{"%.2f" % (cents / 100.0)}/#{unit}" : ""
                {is_default, slug, human, price}
              end
              print_table(output, headers, rows)
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>#{t("runtime.addons.plans.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def fetch_plans(service_name : String) : String
          path = "/api/v1/addon-services/#{URI.encode_path(service_name)}/plans"
          api_client = Build::ApiClient.default
          header_params = Hash(String, String).new
          header_params["Accept"] = "application/json"
          auth_names = ["bearer", "oauth2"]
          data, _status, _headers = api_client.call_api(:GET, path,
            :"AddonServicesApi.plans", "String", nil, auth_names,
            header_params, Hash(String, String).new, Hash(String, String).new,
            Hash(Symbol, (String | ::File)).new)
          data
        end
      end

      @[ACONA::AsCommand("addons:create")]
      class Create < Base
        protected def configure : Nil
          self
            .name("addons:create")
            .description(t("commands.addons.create.description"))
            .argument("plan", :required, t("commands.addons.create.arguments.plan"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("name", nil, :optional, t("commands.addons.create.options.name"))
            .option("human-name", nil, :optional, t("commands.addons.create.options.human_name"))
            .option("description", "d", :optional, t("commands.addons.create.options.description"))
            .option("config", "c", ACON::Input::Option::Value[:optional, :is_array], t("commands.addons.create.options.config"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.create.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          plan = input.argument("plan", type: String)
          addon_name = input.option("name", type: String?)
          addon_human_name = input.option("human-name", type: String?)
          addon_description = input.option("description", type: String?)
          config_opts = input.option("config", type: Array(String))
          json_output = input.option("json", type: Bool)

          config = nil.as(Hash(String, String)?)
          unless config_opts.empty?
            config = Hash(String, String).new
            config_opts.each do |opt|
              k, _, v = opt.partition('=')
              config.not_nil![k] = v
            end
          end

          begin
            api
            addons_api = Build::AddonsApi.new
            req = Build::CreateAddonRequest.new(plan: plan, name: addon_name, human_name: addon_human_name, description: addon_description, config: config)
            addon = addons_api.create_addon(app_name, req)

            if json_output
              output.puts addon.to_json
            else
              name = addon.name || addon.id
              output.puts t("runtime.addons.create.done", plan: plan, app: app_name, name: name, state: addon.state)
              if config_vars = addon.config_vars
                unless config_vars.empty?
                  output.puts t("runtime.labels.config_vars_inline", vars: config_vars.join(", "))
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            # Try to parse structured error response for actionable suggestions
            if body = e.message
              begin
                parsed = JSON.parse(body)
                msg = parsed["message"]?.try(&.as_s?) || body
                output.puts "<error>#{msg}</error>"
                if plans = parsed["available_plans"]?
                  plan_list = plans.as_a.map(&.as_s).join(", ")
                  output.puts t("runtime.addons.create.available_plans", plans: plan_list)
                  service_name = plan.split(":").first?
                  output.puts t("runtime.addons.create.plans_hint", service: service_name) if service_name
                elsif hint = parsed["hint"]?.try(&.as_s?)
                  output.puts t("runtime.addons.create.services_hint")
                end
              rescue JSON::ParseException
                output.puts "<error>#{t("runtime.addons.create.failed", error: e.message)}</error>"
              end
            else
              output.puts "<error>#{t("runtime.addons.create.failed_no_error")}</error>"
            end
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("addons:info")
            .description(t("commands.addons.info.description"))
            .argument("addon", :required, t("commands.common.arguments.addon"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.info.help"))
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
              if human_name = parsed["human_name"]?.try(&.as_s?)
                output.puts t("runtime.labels.display_name", value: human_name) unless human_name.empty?
              end
              if desc = parsed["description"]?.try(&.as_s?)
                output.puts t("runtime.labels.description", value: desc) unless desc.empty?
              end
              output.puts t("runtime.labels.plan", value: parsed["plan"]["name"])
              output.puts t("runtime.labels.service", value: parsed["addon_service"]["name"])
              output.puts t("runtime.labels.app_padded", value: parsed["app"]["name"])
              output.puts t("runtime.labels.state", value: parsed["state"])
              if cvs = parsed["config_vars"]?
                vars = cvs.as_a.map(&.as_s)
                output.puts t("runtime.labels.config_vars", value: vars.join(", ")) unless vars.empty?
              end
              if url = parsed["web_url"]?.try(&.as_s?)
                output.puts t("runtime.labels.web_url_wide", value: url) unless url.empty?
              end
              if price = parsed["billed_price"]?
                cents = price["cents"]?.try(&.as_i?)
                unit = price["unit"]?.try(&.as_s?)
                if cents && unit
                  output.puts t("runtime.labels.price", value: "$#{"%.2f" % (cents / 100.0)}/#{unit}")
                end
              end
              if attachments = parsed["attachments"]?
                atts = attachments.as_a
                unless atts.empty?
                  output.puts ""
                  output.puts t("runtime.addons.info.attachments_title")
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
            output.puts "<error>#{t("runtime.addons.info.failed", error: e.message)}</error>"
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
            .description(t("commands.addons.destroy.description"))
            .argument("addon", :required, t("commands.common.arguments.addon"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.destroy.help"))
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
              output.puts t("runtime.addons.destroy.done", name: name, app: app_name)
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>#{t("runtime.addons.destroy.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:attach")]
      class Attach < Base
        protected def configure : Nil
          self
            .name("addons:attach")
            .description(t("commands.addons.attach.description"))
            .argument("addon", :required, t("commands.common.arguments.addon"))
            .option("app", "a", :required, t("commands.addons.attach.options.app"))
            .option("as", nil, :optional, t("commands.addons.attach.options.as"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.attach.help"))
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
              output.puts t("runtime.addons.attach.done", addon: addon_id, attachment: attachment.name, app: app_name)
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>#{t("runtime.addons.attach.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("addons:detach")]
      class Detach < Base
        protected def configure : Nil
          self
            .name("addons:detach")
            .description(t("commands.addons.detach.description"))
            .argument("attachment", :required, t("commands.addons.detach.arguments.attachment"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.addons.detach.help"))
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
              output.puts t("runtime.addons.detach.done", attachment: attachment.name)
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>#{t("runtime.addons.detach.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end
    end
  end
end
