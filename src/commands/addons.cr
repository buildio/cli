module Build
  module Commands
    module Addons
      @[ACONA::AsCommand("addons")]
      class List < Base
        protected def configure : Nil
          self
            .name("addons")
            .description("List addons for an app.")
            .option("app", "a", :required, "App name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("List all addons provisioned for an app.")
            .aliases(["addons:list"])
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            addons_api = Build::AddonsApi.new
            addons = addons_api.list_app_addons(app_name)

            if json_output
              output.puts addons.to_json
            else
              if addons.empty?
                output.puts "No addons for #{app_name}"
              else
                addons.each do |addon|
                  plan_name = addon.plan.name
                  addon_name = addon.name || addon.id
                  output.puts "#{addon_name}  (#{plan_name})  #{addon.state}"
                end
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to list addons: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
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
            .option("json", "j", :none, "Output in JSON format.")
            .help("Provision a new addon for an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          plan = input.argument("plan", type: String)
          addon_name = input.option("name", type: String?)
          json_output = input.option("json", type: Bool)

          begin
            api
            addons_api = Build::AddonsApi.new
            req = Build::CreateAddonRequest.new(plan: plan, name: addon_name, config: nil)
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
            .option("app", "a", :required, "App name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Show detailed information about an addon.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          addon_id = input.argument("addon", type: String)
          json_output = input.option("json", type: Bool)

          begin
            api
            addons_api = Build::AddonsApi.new
            addon = addons_api.get_addon(app_name, addon_id)

            if json_output
              output.puts addon.to_json
            else
              name = addon.name || addon.id
              output.puts "=== #{name}"
              output.puts "Plan:         #{addon.plan.name}"
              output.puts "Service:      #{addon.addon_service.name}"
              output.puts "App:          #{addon.app.name}"
              output.puts "State:        #{addon.state}"
              if config_vars = addon.config_vars
                output.puts "Config Vars:  #{config_vars.join(", ")}" unless config_vars.empty?
              end
              if url = addon.web_url
                output.puts "Web URL:      #{url}" unless url.empty?
              end
              if price = addon.billed_price
                output.puts "Price:        #{price}"
              end
            end
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to get addon info: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
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
