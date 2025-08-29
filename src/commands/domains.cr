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
            .description("List all domains for an app.")
            .option("app", "a", :required, "App name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("List all domains (default domain + custom domains) for an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            result = api_instance.list_domains(app_name)
            
            if json_output
              output.puts result.to_json
            else
              display_domains(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to list domains: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def display_domains(output : ACON::Output::Interface, domains : Array(Build::Domain))
          if domains.empty?
            output.puts "No domains found"
            return
          end
          
          app_name = domains.first.app.try(&.name) || "app"
          
          # Group domains by kind
          platform_domains = domains.select { |d| d.kind == "platform" }
          custom_domains = domains.select { |d| d.kind == "custom" }
          
          if !platform_domains.empty?
            gray_equals = "===".colorize(:dark_gray)
            title = "#{app_name} Build.io Domain".colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            platform_domains.each do |domain|
              output.puts domain.hostname.to_s
            end
            output.puts ""
          end
          
          if !custom_domains.empty?
            gray_equals = "===".colorize(:dark_gray)
            title = "#{app_name} Custom Domains".colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            
            # Calculate column widths
            max_domain_width = custom_domains.map { |d| d.hostname.to_s.size }.max
            max_domain_width = [max_domain_width, "Domain Name".size].max
            
            # Print header - bold white
            header = " Domain Name".ljust(max_domain_width + 2)
            header += "DNS Record Type".ljust(17)
            header += "DNS Target".ljust(55)
            header += "SNI Endpoint"
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
            title = "#{app_name} Custom Domains".colorize.bold
            output.puts "#{gray_equals} #{title}"
            output.puts ""
            output.puts "No custom domains. Add one with: bld domains:add <hostname> -a <app-name>"
          end
        end
      end

      @[ACONA::AsCommand("domains:add")]
      class Add < Base
        protected def configure : Nil
          self
            .name("domains:add")
            .description("Add a domain to an app.")
            .argument("hostname", :required, "The domain name to add.")
            .option("app", "a", :required, "App name or ID.")
            .option("cert", "c", :optional, "The name of the SSL cert to use for this domain.")
            .option("wait", "w", :none, "Wait for domain to be active.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Add a custom domain to an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          cert = input.option("cert", type: String?)
          wait = input.option("wait", type: Bool)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            request_body = Build::CreateDomainRequest.new(hostname: hostname, cert: cert)
            
            result = api_instance.create_domain(app_name, request_body)
            
            if wait
              wait_for_domain(output, app_name, result.id.to_s)
            end
            
            if json_output
              output.puts result.to_json
            else
              output.puts "<info>Added domain #{hostname} to #{app_name}</info>"
              display_domain_details(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to add domain: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:remove")]
      class Remove < Base
        protected def configure : Nil
          self
            .name("domains:remove")
            .description("Remove a domain from an app.")
            .argument("hostname", :required, "The domain name to remove.")
            .option("app", "a", :required, "App name or ID.")
            .help("Remove a custom domain from an app.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            # First, get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>Domain #{hostname} not found for app #{app_name}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            api_instance.remove_domain(app_name, domain.id.to_s)
            output.puts "<info>Removed domain #{hostname} from #{app_name}</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to remove domain: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:clear")]
      class Clear < Base
        protected def configure : Nil
          self
            .name("domains:clear")
            .description("Clear all custom domains from an app.")
            .option("app", "a", :required, "App name or ID.")
            .help("Remove all custom domains from an app. Platform domains cannot be removed.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            # Get all domains for the app
            domains = api_instance.list_domains(app_name)
            
            # Filter out platform domains (we can't delete those)
            custom_domains = domains.select { |d| d.kind != "platform" }
            
            if custom_domains.empty?
              output.puts "<info>No custom domains to clear for #{app_name}</info>"
              return ACON::Command::Status::SUCCESS
            end
            
            # Delete each custom domain
            custom_domains.each do |domain|
              api_instance.remove_domain(app_name, domain.id.to_s)
              output.puts "<info>Removed domain #{domain.hostname}</info>"
            end
            
            output.puts "<info>Cleared all custom domains from #{app_name}</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to clear domains: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:info")]
      class Info < Base
        protected def configure : Nil
          self
            .name("domains:info")
            .description("Show detailed information about a domain.")
            .argument("hostname", :required, "The domain name.")
            .option("app", "a", :required, "App name or ID.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Display detailed information about a specific domain.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>Domain #{hostname} not found for app #{app_name}</error>"
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
          rescue e : Build::ApiError
            output.puts "<error>Failed to get domain info: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def display_domain_details(output : ACON::Output::Interface, domain : Build::Domain)
          output.puts "=== <info>#{domain.hostname}</info>"
          output.puts "ID:          #{domain.id}"
          output.puts "Kind:        #{domain.kind}"
          output.puts "Status:      #{domain.status}"
          
          if domain.cname
            output.puts "CNAME:       #{domain.cname}"
          end
          
          if domain.acm_status
            output.puts "ACM Status:  #{domain.acm_status}"
            if reason = domain.acm_status_reason
              if !reason.to_s.empty?
                output.puts "ACM Reason:  #{reason}"
              end
            end
          end
          
          if sni = domain.sni_endpoint
            output.puts "SNI Endpoint: #{sni.name}" if sni.responds_to?(:name)
          end
          
          output.puts "Created:     #{domain.created_at}"
          output.puts "Updated:     #{domain.updated_at}"
        end
      end

      @[ACONA::AsCommand("domains:update")]
      class Update < Base
        protected def configure : Nil
          self
            .name("domains:update")
            .description("Update a domain's SSL certificate.")
            .argument("hostname", :required, "The domain name.")
            .option("app", "a", :required, "App name or ID.")
            .option("cert", "c", :required, "The name of the SSL cert to use for this domain.")
            .option("json", "j", :none, "Output in JSON format.")
            .help("Update a domain's SSL certificate configuration.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          cert = input.option("cert", type: String)
          json_output = input.option("json", type: Bool)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>Domain #{hostname} not found for app #{app_name}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            request_body = Build::UpdateDomainRequest.new(cert: cert)
            
            result = api_instance.update_domain(app_name, domain.id.to_s, request_body)
            
            if json_output
              output.puts result.to_json
            else
              output.puts "<info>Updated domain #{hostname} for #{app_name}</info>"
              display_domain_details(output, result)
            end
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to update domain: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end
      end

      @[ACONA::AsCommand("domains:wait")]
      class Wait < Base
        protected def configure : Nil
          self
            .name("domains:wait")
            .description("Wait for a domain to become active.")
            .argument("hostname", :required, "The domain name.")
            .option("app", "a", :required, "App name or ID.")
            .help("Wait for a domain to finish provisioning and become active.")
        end

        protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
          hostname = input.argument("hostname", type: String)
          app_name = input.option("app", type: String)
          
          begin
            api  # Ensure authentication is set up
            api_instance = Build::DomainsApi.new
            
            # Get the list of domains to find the one with the matching hostname
            domains = api_instance.list_domains(app_name)
            domain = domains.find { |d| d.hostname == hostname }
            
            if domain.nil?
              output.puts "<error>Domain #{hostname} not found for app #{app_name}</error>"
              return ACON::Command::Status::FAILURE
            end
            
            wait_for_domain(output, app_name, domain.id.to_s)
            output.puts "<info>Domain #{hostname} is active</info>"
            
            return ACON::Command::Status::SUCCESS
          rescue e : Build::ApiError
            output.puts "<error>Failed to wait for domain: #{e.message}</error>"
            return ACON::Command::Status::FAILURE
          end
        end

        private def wait_for_domain(output : ACON::Output::Interface, app_id : String, domain_id : String)
          api_instance = Build::DomainsApi.new
          max_attempts = 60  # Wait up to 5 minutes
          attempt = 0
          
          output.puts "<info>Waiting for domain to become active...</info>"
          
          loop do
            attempt += 1
            
            begin
              domain = api_instance.show_domain(app_id, domain_id)
              
              if domain.status == "succeeded"
                return
              elsif domain.status == "failed"
                raise "Domain activation failed"
              end
              
              if attempt >= max_attempts
                raise "Timeout waiting for domain activation"
              end
              
              sleep 5.seconds
            rescue e : Build::ApiError
              raise "Failed to check domain status: #{e.message}"
            end
          end
        end
      end

      # Helper module with shared methods
      module SharedHelpers
        def display_domain_details(output : ACON::Output::Interface, domain : Build::Domain)
          output.puts "=== <info>#{domain.hostname}</info>"
          output.puts "ID:          #{domain.id}"
          output.puts "Kind:        #{domain.kind}"
          output.puts "Status:      #{domain.status}"
          
          if domain.cname
            output.puts "CNAME:       #{domain.cname}"
          end
          
          if domain.acm_status
            output.puts "ACM Status:  #{domain.acm_status}"
            if reason = domain.acm_status_reason
              if !reason.to_s.empty?
                output.puts "ACM Reason:  #{reason}"
              end
            end
          end
          
          if sni = domain.sni_endpoint
            output.puts "SNI Endpoint: #{sni.name}" if sni.responds_to?(:name)
          end
          
          output.puts "Created:     #{domain.created_at}"
          output.puts "Updated:     #{domain.updated_at}"
        end

        def wait_for_domain(output : ACON::Output::Interface, app_id : String, domain_id : String)
          api_instance = Build::DomainsApi.new
          max_attempts = 60  # Wait up to 5 minutes
          attempt = 0
          
          output.puts "<info>Waiting for domain to become active...</info>"
          
          loop do
            attempt += 1
            
            begin
              domain = api_instance.show_domain(app_id, domain_id)
              
              if domain.status == "succeeded"
                return
              elsif domain.status == "failed"
                raise "Domain activation failed"
              end
              
              if attempt >= max_attempts
                raise "Timeout waiting for domain activation"
              end
              
              sleep 5.seconds
            rescue e : Build::ApiError
              raise "Failed to check domain status: #{e.message}"
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