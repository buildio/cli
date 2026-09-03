module Build
  module Commands
    @[ACONA::AsCommand("logs")]
    class Logs < Base
      protected def configure : Nil
        self
          .name("logs")
          .description(t("commands.logs.description"))
          .help(t("commands.logs.help"))
          .aliases(["log"])
          .usage(t("runtime.logs.usage"))
          .option("app", "a", :required, t("commands.common.options.app_name"))
          .option("process", "p", :optional, t("commands.logs.options.process"))
          .option("tail", "t", :none, t("commands.logs.options.tail"))
          .option("count", "c", :optional, t("commands.logs.options.count"))
          .option("source", "s", :optional, t("commands.logs.options.source"))
          .option("zone", "z", :optional, t("commands.logs.options.zone"))
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        query_params = {} of String => String
        app = input.option("app", type: String)
        return ACON::Command::Status::FAILURE if app.blank?
        process = input.option("process")
        query_params["process"] = process if process
        tail = input.option("tail", type: Bool)

        # if tail
        #   output.puts("Tailing logs for #{app}... #{tail}") 
        # else
        #   output.puts("Fetching logs for #{app}... #{tail}") 
        # end

        query_params["tail"] = tail.to_s if tail
        num = input.option("count")
        query_params["num"] = num if num
        source = input.option("source")
        query_params["source"] = source if source
        zone = input.option("zone")
        query_params["zone"] = zone if zone

        user_token = self.token
        if user_token.nil?
          output.puts t("runtime.errors.need_login_to_run")
          return ACON::Command::Status::FAILURE
        end

        params = URI::Params.encode(query_params)
        headers = HTTP::Headers.new
        headers["Authorization"] = "Bearer #{user_token}"
        headers["Accept-Language"] = ::Build::Locale.accept_language

        # output.puts("Query params: #{query_params}")
        # output.puts("Params: #{params}")
        api_uri = ::Build.parsed_api_uri
        log_url_res = HTTP::Client.get(URI.new(api_uri.scheme, api_uri.host, api_uri.port, path: "/api/apps/#{app}/logs/log_url", query: params), headers: headers)
        if log_url_res.status_code != 200
          output.puts(t("runtime.logs.failed_url", app: app))
          return ACON::Command::Status::FAILURE
        end
        log_url = JSON.parse(log_url_res.body)["url"].to_s

        colorizer = LogColorizer.new

        HTTP::Client.get(log_url) do |res|
          res.body_io.each_line do |line|
            output.puts(colorizer.colorize(line))
          end
        end

        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
