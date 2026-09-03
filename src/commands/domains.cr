require "../utils"
require "json"
require "build-client"

module Build
  module Commands
    module Domains
      @[ACONA::AsCommand("domains")]
      class List < Base
        protected def configure : Nil
          self
            .name("domains")
            .description(t("commands.domains.list.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.domains.list.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            result = api_instance.list_domains(app_name)
            
            if json_output
              output.puts result.to_json
            else
              display_domains(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.list.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def display_domains(output : ACON::Output::Interface, domains : Array(::Build::Domain))
          if domains.empty?
            output.puts t("runtime.domains.list.none")
            return
          end
          
          app_name = domains.first.app.try(&.name) || "app"
          
          # Group domains by kind
          platform_domains = domains.select { |d| d.kind == "platform" }
          custom_domains = domains.select { |d| d.kind == "custom" }
          
          if !platform_domains.empty?
            gray_equals = "===".colorize(:dark_gray)
            title = ::Build.t("runtime.domains.list.platform_title", app: app_name).colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            platform_domains.each do |domain|
              output.puts domain.hostname.to_s
            end
            output.puts ""
          end
          
          if !custom_domains.empty?
            gray_equals = "===".colorize(:dark_gray)
            title = ::Build.t("runtime.domains.list.custom_title", app: app_name).colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            
            # Calculate column widths
            max_domain_width = custom_domains.map { |d| d.hostname.to_s.size }.max
            domain_name_header = ::Build.t("runtime.domains.headers.domain_name")
            max_domain_width = [max_domain_width, domain_name_header.size].max
            
            # Print header - bold white
            header = " #{domain_name_header}".ljust(max_domain_width + 2)
            header += ::Build.t("runtime.domains.headers.dns_record_type").ljust(17)
            header += ::Build.t("runtime.domains.headers.dns_target").ljust(55)
            header += ::Build.t("runtime.domains.headers.sni_endpoint")
            output.puts header.colorize.bold
            
            # Print separator line - bold white
            separator = " " + "─" * (max_domain_width + 1)
            separator += "─" * 16 + " "
            separator += "─" * 54 + " "
            separator += "─" * 18
            output.puts separator.colorize.bold
            
            # Print each domain - normal text
            custom_domains.each do |domain|
              row = " #{domain.hostname.to_s.ljust(max_domain_width + 1)}"
              row += "CNAME".ljust(16) + " "
              
              # DNS Target
              dns_target = domain.cname || ""
              row += dns_target.to_s.ljust(54) + " "
              
              # SNI Endpoint
              sni_name = ""
              if sni = domain.sni_endpoint
                sni_name = sni.name.to_s if sni.responds_to?(:name)
              end
              row += sni_name.to_s.ljust(18)
              
              output.puts row
            end
          else
            gray_equals = "===".colorize(:dark_gray)
            title = ::Build.t("runtime.domains.list.custom_title", app: app_name).colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            output.puts t("runtime.domains.list.no_custom")
          end
        end
      end

      @[ACONA::AsCommand("domains:add")]
      class Add < Base
        protected def configure : Nil
          self
            .name("domains:add")
            .description(t("commands.domains.add.description"))
            .argument("hostname", :required, t("commands.domains.common.arguments.hostname_add"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("cert", "c", :optional, t("commands.domains.common.options.cert"))
            .option("wait", "w", :none, t("commands.domains.add.options.wait"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.domains.add.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          cert = input.option("cert", type: String?)
          wait = input.option("wait", type: Bool)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            request_body = ::Build::CreateDomainRequest.new(hostname: hostname, cert: cert)
            
            result = api_instance.create_domain(app_name, request_body)
            
            if wait
              wait_for_domain(output, app_name, result.id.to_s)
            end
            
            if json_output
              output.puts result.to_json
            else
              output.puts "<info>#{t("runtime.domains.add.added", hostname: hostname, app: app_name)}</info>"
              display_domain_details(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.add.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:remove")]
      class Remove < Base
        protected def configure : Nil
          self
            .name("domains:remove")
            .description(t("commands.domains.remove.description"))
            .argument("hostname", :required, t("commands.domains.common.arguments.hostname_remove"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .help(t("commands.domains.remove.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            # First, get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>#{t("runtime.domains.not_found", hostname: hostname, app: app_name)}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            api_instance.remove_domain(app_name, domain.id.to_s)
            output.puts "<info>#{t("runtime.domains.remove.removed", hostname: hostname, app: app_name)}</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.remove.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:clear")]
      class Clear < Base
        protected def configure : Nil
          self
            .name("domains:clear")
            .description(t("commands.domains.clear.description"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .help(t("commands.domains.clear.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            # Get all domains for the app
            domains = api_instance.list_domains(app_name)
            
            # Filter out platform domains (we can't delete those)
            custom_domains = domains.select { |d| d.kind != "platform" }
            
            if custom_domains.empty?
              output.puts "<info>#{t("runtime.domains.clear.none", app: app_name)}</info>"
              return ACON::Command::Status::SUCCESS
            end
            
            # Delete each custom domain
            custom_domains.each do |domain|
              api_instance.remove_domain(app_name, domain.id.to_s)
              output.puts "<info>#{t("runtime.domains.clear.removed", hostname: domain.hostname)}</info>"
            end
            
            output.puts "<info>#{t("runtime.domains.clear.cleared", app: app_name)}</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.clear.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("domains:info")
            .description(t("commands.domains.info.description"))
            .argument("hostname", :required, t("commands.domains.common.arguments.hostname"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.domains.info.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>#{t("runtime.domains.not_found", hostname: hostname, app: app_name)}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            # Get detailed info for the domain
            result = api_instance.show_domain(app_name, domain.id.to_s)
            
            if json_output
              output.puts result.to_json
            else
              display_domain_details(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.info.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def display_domain_details(output : ACON::Output::Interface, domain : ::Build::Domain)
          output.puts "=== <info>#{domain.hostname}</info>"
          output.puts ::Build.t("runtime.labels.id", value: domain.id)
          output.puts ::Build.t("runtime.labels.kind", value: domain.kind)
          output.puts ::Build.t("runtime.labels.status", value: domain.status)
          
          if domain.cname
            output.puts ::Build.t("runtime.labels.cname", value: domain.cname)
          end
          
          if domain.acm_status
            output.puts ::Build.t("runtime.labels.acm_status", value: domain.acm_status)
            if reason = domain.acm_status_reason
              if !reason.to_s.empty?
                output.puts ::Build.t("runtime.labels.acm_reason", value: reason)
              end
            end
          end
          
          if sni = domain.sni_endpoint
            output.puts ::Build.t("runtime.labels.sni_endpoint", value: sni.name) if sni.responds_to?(:name)
          end
          
          output.puts ::Build.t("runtime.labels.created", value: domain.created_at)
          output.puts ::Build.t("runtime.labels.updated", value: domain.updated_at)
        end
      end

      @[ACONA::AsCommand("domains:update")]
      class Update < Base
        protected def configure : Nil
          self
            .name("domains:update")
            .description(t("commands.domains.update.description"))
            .argument("hostname", :required, t("commands.domains.common.arguments.hostname"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .option("cert", "c", :required, t("commands.domains.common.options.cert"))
            .option("json", "j", :none, t("commands.common.options.json"))
            .help(t("commands.domains.update.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          cert = input.option("cert", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>#{t("runtime.domains.not_found", hostname: hostname, app: app_name)}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            request_body = ::Build::UpdateDomainRequest.new(cert: cert)
            
            result = api_instance.update_domain(app_name, domain.id.to_s, request_body)
            
            if json_output
              output.puts result.to_json
            else
              output.puts "<info>#{t("runtime.domains.update.updated", hostname: hostname, app: app_name)}</info>"
              display_domain_details(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.update.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:wait")]
      class Wait < Base
        protected def configure : Nil
          self
            .name("domains:wait")
            .description(t("commands.domains.wait.description"))
            .argument("hostname", :required, t("commands.domains.common.arguments.hostname"))
            .option("app", "a", :required, t("commands.common.options.app_id_or_name"))
            .help(t("commands.domains.wait.help"))
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = ::Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>#{t("runtime.domains.not_found", hostname: hostname, app: app_name)}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            wait_for_domain(output, app_name, domain.id.to_s)
            output.puts "<info>#{t("runtime.domains.wait.active", hostname: hostname)}</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : ::Build::ApiError
            output.puts "<error>#{t("runtime.domains.wait.failed", error: e.message)}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def wait_for_domain(output : ACON::Output::Interface, app_id : String, domain_id : String)
          api_instance = ::Build::DomainsApi.new
          max_attempts = 60  # Wait up to 5 minutes
          attempt = 0
          
          output.puts "<info>#{::Build.t("runtime.domains.wait.waiting")}</info>"
          
          loop do
            attempt += 1
            
            begin
              domain = api_instance.show_domain(app_id, domain_id)
              
              if domain.status == "succeeded"
                return
              elsif domain.status == "failed"
                raise ::Build.t("runtime.domains.wait.activation_failed")
              end
              
              if attempt >= max_attempts
                raise ::Build.t("runtime.domains.wait.timeout")
              end
              
              sleep 5.seconds
            rescue e : ::Build::ApiError
              raise ::Build.t("runtime.domains.wait.check_failed", error: e.message)
            end
          end
        end
      end

      # Helper module with shared methods
      module SharedHelpers
        def display_domain_details(output : ACON::Output::Interface, domain : ::Build::Domain)
          output.puts "=== <info>#{domain.hostname}</info>"
          output.puts ::Build.t("runtime.labels.id", value: domain.id)
          output.puts ::Build.t("runtime.labels.kind", value: domain.kind)
          output.puts ::Build.t("runtime.labels.status", value: domain.status)
          
          if domain.cname
            output.puts ::Build.t("runtime.labels.cname", value: domain.cname)
          end
          
          if domain.acm_status
            output.puts ::Build.t("runtime.labels.acm_status", value: domain.acm_status)
            if reason = domain.acm_status_reason
              if !reason.to_s.empty?
                output.puts ::Build.t("runtime.labels.acm_reason", value: reason)
              end
            end
          end
          
          if sni = domain.sni_endpoint
            output.puts ::Build.t("runtime.labels.sni_endpoint", value: sni.name) if sni.responds_to?(:name)
          end
          
          output.puts ::Build.t("runtime.labels.created", value: domain.created_at)
          output.puts ::Build.t("runtime.labels.updated", value: domain.updated_at)
        end

        def wait_for_domain(output : ACON::Output::Interface, app_id : String, domain_id : String)
          api_instance = ::Build::DomainsApi.new
          max_attempts = 60  # Wait up to 5 minutes
          attempt = 0
          
          output.puts "<info>#{::Build.t("runtime.domains.wait.waiting")}</info>"
          
          loop do
            attempt += 1
            
            begin
              domain = api_instance.show_domain(app_id, domain_id)
              
              if domain.status == "succeeded"
                return
              elsif domain.status == "failed"
                raise ::Build.t("runtime.domains.wait.activation_failed")
              end
              
              if attempt >= max_attempts
                raise ::Build.t("runtime.domains.wait.timeout")
              end
              
              sleep 5.seconds
            rescue e : ::Build::ApiError
              raise ::Build.t("runtime.domains.wait.check_failed", error: e.message)
            end
          end
        end
      end

      # Include shared helpers in commands that need them
      class Add < Base
        include SharedHelpers
      end

      class Info < Base
        include SharedHelpers
      end

      class Update < Base
        include SharedHelpers
      end

      class Wait < Base
        include SharedHelpers
      end
    end
  end
end