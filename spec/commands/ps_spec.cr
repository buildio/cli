require "../spec_helper"
require "athena-console"
require "athena-console/spec"
require "netrc"
require "../../src/utils"

module Build
  def self.api_host
    "app.build.io"
  end

  def self.api_host_scheme
    "https"
  end
end

require "../../src/commands/base"
require "../../src/commands/ps"

class PsListApi < Build::DefaultApi
  def initialize(@dynos : Array(Build::Dyno))
    super()
  end

  def list_dynos(app_id_or_name : String)
    @dynos
  end
end

class PsListCommand < Build::Commands::Process::List
  def initialize(@dynos : Array(Build::Dyno))
    super()
  end

  def api : Build::DefaultApi
    PsListApi.new(@dynos)
  end
end

describe Build::Commands::Process::List do
  it "prints ps timestamps it cannot parse" do
    dynos = [
      Build::Dyno.new("web", 1, "Standard-1X", "bundle exec", [
        Build::Process.new(1, "Running", "2024-02-30T10:00:00Z", 1, "not-a-time"),
      ]),
    ]

    tester = ACON::Spec::CommandTester.new(PsListCommand.new(dynos))
    tester.execute({"--app" => "myapp"})

    tester.status.should eq(ACON::Command::Status::SUCCESS)
    tester.display.gsub(/\e\[[0-9;]*m/, "").should contain("web.1: up 2024-02-30T10:00:00Z 1 restarts (last at not-a-time)")
  end

  it "accepts valid ISO 8601 variants" do
    dynos = [
      Build::Dyno.new("worker", 1, "Standard-1X", "worker", [
        Build::Process.new(1, "Running", "2024-01-15T10:30:00+00:00", nil, nil),
      ]),
    ]

    tester = ACON::Spec::CommandTester.new(PsListCommand.new(dynos))
    tester.execute({"--app" => "myapp"})

    tester.status.should eq(ACON::Command::Status::SUCCESS)
    tester.display.gsub(/\e\[[0-9;]*m/, "").should contain("worker.1: up 2024-01-15 10:30:00 +00:00 (~")
  end
end
