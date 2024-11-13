module Build
  module Commands
    @[ACONA::AsCommand("logs")]
    class Logs < Base
      protected def configure : Nil
        self
          .name("logs")
          .description("Display the logs for an application.")
          .help("Display the logs for an application.")
          .aliases(["log"])
          .usage("logs -t -a my-app -p web")
          .option("app", "a", :required, "The name of the application.")
          .option("process", "p", :optional, "The Procfile process to display logs for.")
          .option("tail", "t", :none, "Tail the logs.")
          .option("count", "c", :optional, "Number of lines to display.")
          .option("source", "s", :optional, "The log source to display from (app or build).")
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        query_params = {} of String => String
        app = input.option("app", type: String)
        return ACON::Command::Status::FAILURE if app.blank?
        process = input.option("process")
        query_params["process"] = process if process
        tail = input.option("tail", type: Bool)

        if tail
          output.puts("Tailing logs for #{app}... #{tail}") 
        else
          output.puts("Fetching logs for #{app}... #{tail}") 
        end

        query_params["tail"] = tail.to_s if tail
        num = input.option("count")
        query_params["num"] = num if num
        source = input.option("source")
        query_params["source"] = source if source

        user_token = Netrc.read[Build.api_host].try &.password
        if user_token.nil?
          output.puts "You need to be logged in to run a command."
          return ACON::Command::Status::FAILURE
        end

        params = URI::Params.encode(query_params)
        headers = HTTP::Headers.new
        headers["Authorization"] = "Bearer #{user_token}"

        output.puts("Query params: #{query_params}")
        output.puts("Params: #{params}")
        exit

        log_url_res = HTTP::Client.get(URI.new("https", Build.api_host, path: "/api/apps/#{app}/logs/log_url", query: params), headers: headers)
        if log_url_res.status_code != 200
          output.puts("Failed to get log URL for app #{app}.")
          return ACON::Command::Status::FAILURE
        end
        log_url = JSON.parse(log_url_res.body)["url"].to_s

        HTTP::Client.get(log_url) do |res|
          res.body_io.each_line do |line|
            output.puts(line)
          end
        end

        return ACON::Command::Status::SUCCESS
      end
    end
  end
end
