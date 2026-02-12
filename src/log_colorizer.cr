module Build
  class LogColorizer
    # Regex to parse log lines: header[identifier.N]: body
    # e.g. "2024-01-15T10:30:00+00:00 app[web.1]: Starting process..."
    LINE_REGEX = /^(.*?\[([\w\-]+)(?:[\d.]+)?\]:)(.*)?$/

    # Pre-seeded identifiers for consistent colors across runs (order matters).
    # These common process types always get the same color.
    PRESET_IDENTIFIERS = %w[run router web postgres heroku-postgres]

    @assigned_colors = {} of String => Int32

    def initialize
      PRESET_IDENTIFIERS.each { |id| assign_color(id) }
    end

    def colorize(line : String) : String
      match = LINE_REGEX.match(line)
      return line unless match

      header = match[1]
      identifier = match[2]
      body = (match[3]? || "").strip

      index = assign_color(identifier)
      colored_body = colorize_body(identifier, body)

      apply_color(header, index) + " " + colored_body
    end

    private def assign_color(identifier : String) : Int32
      base = identifier.split('.').first
      unless @assigned_colors.has_key?(base)
        @assigned_colors[base] = @assigned_colors.size
      end
      @assigned_colors[base] % 10
    end

    # 10-color palette matching Heroku's approach:
    # 5 normal + 5 bold variants. Red is excluded (reserved for errors).
    private def apply_color(text : String, index : Int32) : String
      case index
      when 0 then text.colorize(:yellow).to_s
      when 1 then text.colorize(:green).to_s
      when 2 then text.colorize(:cyan).to_s
      when 3 then text.colorize(:magenta).to_s
      when 4 then text.colorize(:blue).to_s
      when 5 then text.colorize(:green).bold.to_s
      when 6 then text.colorize(:cyan).bold.to_s
      when 7 then text.colorize(:magenta).bold.to_s
      when 8 then text.colorize(:yellow).bold.to_s
      when 9 then text.colorize(:blue).bold.to_s
      else text
      end
    end

    # --- Body colorization dispatch ---

    private def colorize_body(identifier : String, body : String) : String
      case identifier
      when "router"
        colorize_router(body)
      when "web"
        colorize_web(body)
      when "run"
        colorize_run(body)
      when "api"
        colorize_api(body)
      when "redis"
        colorize_redis(body)
      when "postgres", "heroku-postgres"
        colorize_pg(body)
      else
        body
      end
    end

    # --- Helper methods ---

    private def color_status(code : String) : String
      c = code.to_i? || 0
      case
      when c < 200 then code
      when c < 300 then code.colorize(:green).to_s
      when c < 400 then code.colorize(:cyan).to_s
      when c < 500 then code.colorize(:yellow).to_s
      else              code.colorize(:red).to_s
      end
    end

    private def color_ms(s : String) : String
      ms = s.to_f? || 0.0
      # Strip "ms" suffix for parsing if present
      if s.ends_with?("ms")
        ms = s.rchop("ms").to_f? || 0.0
      end
      case
      when ms < 100   then s.colorize(:light_green).to_s
      when ms < 500   then s.colorize(:green).to_s
      when ms < 5000  then s.colorize(:yellow).to_s
      when ms < 10000 then s.colorize(:light_yellow).to_s
      else                  s.colorize(:red).to_s
      end
    end

    private def color_state(s : String) : String
      case s
      when "down"     then s.colorize(:red).to_s
      when "up"       then s.colorize(:light_green).to_s
      when "starting" then s.colorize(:light_yellow).to_s
      when "complete" then s.colorize(:light_green).to_s
      else                 s
      end
    end

    private def color_method(s : String) : String
      s.colorize(:magenta).bold.to_s
    end

    private def color_path(s : String) : String
      s.colorize(:green).to_s
    end

    private def dim(s : String) : String
      s.colorize(:dark_gray).to_s
    end

    # --- Router body colorizer ---
    # Parses key=value pairs and colors each semantically

    private def colorize_router(body : String) : String
      # Match key=value or key="quoted value" pairs
      body.gsub(/(\w+)=(\"[^\"]*\"|\S+)/) do |match|
        md = /(\w+)=(\"[^\"]*\"|\S+)/.match(match)
        next match unless md
        key = md[1]
        value = md[2]
        colored_value = case key
                        when "method"
                          color_method(value)
                        when "path"
                          color_path(value)
                        when "status"
                          color_status(value)
                        when "dyno"
                          value.colorize(:cyan).to_s
                        when "connect", "service"
                          color_ms(value)
                        when "at"
                          if value == "error"
                            value.colorize(:red).to_s
                          else
                            value
                          end
                        when "code"
                          value.colorize(:red).bold.to_s
                        when "desc"
                          value.colorize(:red).to_s
                        else
                          dim(value)
                        end
        "#{dim(key + "=")}#{colored_value}"
      end
    end

    # --- Web body colorizer ---

    private def colorize_web(body : String) : String
      # State changes: "State changed from X to Y"
      if body.includes?("State changed")
        return body.gsub(/\b(down|up|starting|complete)\b/) { |state| color_state(state) }
      end

      # SIGTERM
      if body.includes?("SIGTERM")
        return body.colorize(:red).to_s
      end

      # Unidling / Restarting
      if body.starts_with?("Unidling") || body.starts_with?("Restarting")
        return body.colorize(:yellow).to_s
      end

      # Starting process: "Starting process with command `...`"
      if md = /^(Starting process with command `)(.+)(` by user )(.+)$/.match(body)
        return md[1] + md[2].colorize(:cyan).bold.to_s + md[3] + md[4].colorize(:green).to_s
      end

      if md = /^(Starting process with command `)(.+)(`)$/.match(body)
        return md[1] + md[2].colorize(:cyan).bold.to_s + md[3]
      end

      # Process exited: "Process exited with status N"
      if md = /^(Process exited with status )(\d+)$/.match(body)
        code = md[2].to_i
        colored_code = code == 0 ? md[2].colorize(:light_green).to_s : md[2].colorize(:red).to_s
        return md[1] + colored_code
      end

      # Apache-style access log: "GET /path HTTP/1.1" status bytes
      if md = /^(\w+)\s+(\/\S*)\s+(HTTP\/[\d.]+)\s+(\d+)\s+(.*)$/.match(body)
        method = color_method(md[1])
        path = color_path(md[2])
        proto = md[3]
        status = color_status(md[4])
        rest = md[5]
        return "#{method} #{path} #{proto} #{status} #{rest}"
      end

      body
    end

    # --- Run body colorizer ---

    private def colorize_run(body : String) : String
      # State changes
      if body.includes?("State changed")
        return body.gsub(/\b(down|up|starting|complete)\b/) { |state| color_state(state) }
      end

      # SIGTERM
      if body.includes?("SIGTERM")
        return body.colorize(:red).to_s
      end

      # Starting process with command
      if md = /^(Starting process with command `)(.+)(` by user )(.+)$/.match(body)
        return md[1] + md[2].colorize(:cyan).bold.to_s + md[3] + md[4].colorize(:green).to_s
      end

      if md = /^(Starting process with command `)(.+)(`)$/.match(body)
        return md[1] + md[2].colorize(:cyan).bold.to_s + md[3]
      end

      # Process exited
      if md = /^(Process exited with status )(\d+)$/.match(body)
        code = md[2].to_i
        colored_code = code == 0 ? md[2].colorize(:light_green).to_s : md[2].colorize(:red).to_s
        return md[1] + colored_code
      end

      body
    end

    # --- API body colorizer ---

    private def colorize_api(body : String) : String
      # Build succeeded
      if body.includes?("Build succeeded")
        return body.colorize(:light_green).to_s
      end

      # Build failed
      if body.includes?("Build failed")
        return body.colorize(:red).to_s
      end

      # Build started by user
      if md = /^(Build started by user )(.+)$/.match(body)
        return md[1] + md[2].colorize(:green).to_s
      end

      # Deploy hash by user
      if md = /^(Deploy )(\w+)( by user )(.+)$/.match(body)
        return md[1] + md[2].colorize(:cyan).to_s + md[3] + md[4].colorize(:green).to_s
      end

      # Release version by user
      if md = /^(Release )(v\d+)( created by user )(.+)$/.match(body)
        return md[1] + md[2].colorize(:magenta).to_s + md[3] + md[4].colorize(:green).to_s
      end

      body
    end

    # --- Redis body colorizer ---

    private def colorize_redis(body : String) : String
      # Dim metric sample lines (key=value patterns typical of metric output)
      if body =~ /^sample#/
        return dim(body)
      end

      body
    end

    # --- Postgres body colorizer ---

    private def colorize_pg(body : String) : String
      # CREATE TABLE
      if md = /^(CREATE TABLE )(\w+)$/.match(body)
        return md[1].colorize(:magenta).to_s + md[2].colorize(:cyan).to_s
      end

      # Dim metric sample lines
      if body =~ /^sample#/
        return dim(body)
      end

      body
    end
  end
end
