require "./spec_helper"

# Force colors on so ANSI codes are present regardless of TTY
Colorize.enabled = true

# Crystal's Colorize uses \e[39m to reset foreground and \e[39;22m for foreground+bold reset.
# These helpers produce the exact sequences Crystal generates.
private def c_fg(text, code)
  "\e[#{code}m#{text}\e[39m"
end

private def c_bold(text, code)
  "\e[#{code};1m#{text}\e[39;22m"
end

describe Build::LogColorizer do
  describe "#colorize" do
    it "returns non-matching lines unchanged" do
      c = Build::LogColorizer.new
      c.colorize("just some random text").should eq "just some random text"
      c.colorize("").should eq ""
      c.colorize("no brackets here: stuff").should eq "no brackets here: stuff"
    end

    it "colors headers for pre-seeded identifiers" do
      c = Build::LogColorizer.new
      # run = index 0 = yellow
      line = "2024-01-15T10:30:00+00:00 app[run.1]: hello"
      result = c.colorize(line)
      result.should contain("\e[33m") # yellow for run header

      # router = index 1 = green
      line2 = "2024-01-15T10:30:00+00:00 app[router]: request"
      result2 = c.colorize(line2)
      result2.should contain("\e[32m") # green for router header

      # web = index 2 = cyan
      line3 = "2024-01-15T10:30:00+00:00 app[web.1]: booting"
      result3 = c.colorize(line3)
      result3.should contain("\e[36m") # cyan for web header
    end

    it "matches alphanumeric instance IDs" do
      c = Build::LogColorizer.new
      line = "2024-01-15T10:30:00+00:00 app[web.2c9rh]: State changed from starting to up"
      result = c.colorize(line)
      result.should contain(c_fg("starting", 93))
      result.should contain(c_fg("up", 92))
    end

    it "assigns same color to same base identifier" do
      c = Build::LogColorizer.new
      line1 = "ts app[worker.1]: a"
      line2 = "ts app[worker.2]: b"
      r1 = c.colorize(line1)
      r2 = c.colorize(line2)
      # Both should have the same ANSI code since base is "worker"
      code1 = r1.match(/\e\[(\d+(?:;\d+)?)m/)
      code2 = r2.match(/\e\[(\d+(?:;\d+)?)m/)
      code1.should_not be_nil
      code2.should_not be_nil
      code1.not_nil![1].should eq code2.not_nil![1]
    end

    it "wraps color assignment at 10" do
      c = Build::LogColorizer.new
      # Pre-seeded: run(0), router(1), web(2), postgres(3), heroku-postgres(4)
      # Next 5 new identifiers get indices 5-9, then 10th wraps to 0
      ids = %w[a b c d e f]
      ids.each do |id|
        c.colorize("ts app[#{id}.1]: x")
      end
      # "f" is the 11th identifier (5 preseeded + 6 new), index 10 % 10 = 0 = yellow
      result = c.colorize("ts app[f.1]: x")
      result.should contain("\e[33m") # yellow = index 0
    end

    it "adds space between header and body" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: hello world")
      # Should have " hello world" (space + body) after the colored header
      result.should contain(" hello world")
    end
  end

  describe "router body colorization" do
    it "colors method in bold magenta" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: method=GET path=/foo status=200")
      result.should contain(c_bold("GET", 35))
    end

    it "colors path in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: method=GET path=/hello status=200")
      result.should contain(c_fg("/hello", 32))
    end

    it "colors 2xx status in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: status=200")
      result.should contain(c_fg("200", 32))
    end

    it "colors 3xx status in cyan" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: status=301")
      result.should contain(c_fg("301", 36))
    end

    it "colors 4xx status in yellow" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: status=404")
      result.should contain(c_fg("404", 33))
    end

    it "colors 5xx status in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: status=503")
      result.should contain(c_fg("503", 31))
    end

    it "colors fast response times in light green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: service=50ms")
      result.should contain(c_fg("50ms", 92))
    end

    it "colors medium response times in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: service=200ms")
      result.should contain(c_fg("200ms", 32))
    end

    it "colors slow response times in yellow" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: service=3000ms")
      result.should contain(c_fg("3000ms", 33))
    end

    it "colors very slow response times in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: service=15000ms")
      result.should contain(c_fg("15000ms", 31))
    end

    it "colors at=error in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: at=error code=H12")
      result.should contain(c_fg("error", 31))
    end

    it "colors error code in bold red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: code=H12")
      result.should contain(c_bold("H12", 31))
    end

    it "dims other keys" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: host=example.com")
      result.should contain(c_fg("example.com", 90))
    end

    it "dims key= prefix" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[router]: status=200")
      result.should contain(c_fg("status=", 90))
    end
  end

  describe "web body colorization" do
    it "colors state changes" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: State changed from starting to up")
      result.should contain(c_fg("starting", 93))
      result.should contain(c_fg("up", 92))
    end

    it "colors SIGTERM in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Error R12 (Exit timeout) -> Process failed to exit within 30 seconds of SIGTERM")
      result.should contain("\e[31m")
    end

    it "colors Unidling in yellow" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Unidling")
      result.should contain("\e[33m")
    end

    it "colors Restarting in yellow" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Restarting")
      result.should contain("\e[33m")
    end

    it "colors starting process command in cyan bold" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Starting process with command `bundle exec puma`")
      result.should contain(c_bold("bundle exec puma", 36))
    end

    it "colors starting process user in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Starting process with command `puma` by user foo@bar.com")
      result.should contain(c_fg("foo@bar.com", 32))
    end

    it "colors exit code 0 in light green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Process exited with status 0")
      result.should contain(c_fg("0", 92))
    end

    it "colors non-zero exit code in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: Process exited with status 137")
      result.should contain(c_fg("137", 31))
    end

    it "colors Apache-style access log lines" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[web.1]: GET /index HTTP/1.1 200 1234")
      result.should contain(c_bold("GET", 35))
      result.should contain(c_fg("/index", 32))
      result.should contain(c_fg("200", 32))
    end
  end

  describe "run body colorization" do
    it "colors state changes" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: State changed from up to complete")
      result.should contain(c_fg("up", 92))
      result.should contain(c_fg("complete", 92))
    end

    it "colors SIGTERM in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: SIGTERM received")
      result.should contain("\e[31m")
    end

    it "colors starting process with command" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: Starting process with command `bash`")
      result.should contain(c_bold("bash", 36))
    end

    it "colors exit code 0 in light green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: Process exited with status 0")
      result.should contain(c_fg("0", 92))
    end

    it "colors non-zero exit code in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[run.1]: Process exited with status 1")
      result.should contain(c_fg("1", 31))
    end
  end

  describe "API body colorization" do
    it "colors Build succeeded in light green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[api]: Build succeeded")
      result.should contain("\e[92m")
    end

    it "colors Build failed in red" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[api]: Build failed")
      result.should contain("\e[31m")
    end

    it "colors build started user in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[api]: Build started by user dev@example.com")
      result.should contain(c_fg("dev@example.com", 32))
    end

    it "colors deploy hash in cyan and user in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[api]: Deploy abc123f by user dev@example.com")
      result.should contain(c_fg("abc123f", 36))
      result.should contain(c_fg("dev@example.com", 32))
    end

    it "colors release version in magenta and user in green" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[api]: Release v42 created by user dev@example.com")
      result.should contain(c_fg("v42", 35))
      result.should contain(c_fg("dev@example.com", 32))
    end
  end

  describe "postgres body colorization" do
    it "colors CREATE TABLE" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[postgres.1]: CREATE TABLE users")
      result.should contain("\e[35m") # magenta for CREATE TABLE
      result.should contain("\e[36m") # cyan for table name
    end

    it "dims sample metric lines" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[postgres.1]: sample#db_size=4321bytes")
      result.should contain("\e[90m") # dark_gray/dim
    end
  end

  describe "redis body colorization" do
    it "dims sample metric lines" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[redis.1]: sample#connected_clients=5")
      result.should contain("\e[90m") # dark_gray/dim
    end

    it "leaves non-sample lines unchanged" do
      c = Build::LogColorizer.new
      result = c.colorize("ts app[redis.1]: Ready to accept connections")
      result.should contain("Ready to accept connections")
      result.should_not contain("\e[90mReady")
    end
  end
end
