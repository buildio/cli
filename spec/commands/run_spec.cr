require "../spec_helper"
require "athena-console"
require "../../src/i18n"
require "../../src/commands/base"
require "../../src/commands/run"

{% unless flag?(:win32) %}
  describe Build::Commands::Run do
    before_each { Build::Locale.init }

    it "has a --size/-s option" do
      Build::Commands::Run.new.definition.option("size").shortcut.should eq("s")
    end

    it "shows the server's message when the size is rejected" do
      e = Build::ApiError.new(code: 422, message: %({"code":"bad_request","message":"invalid size 'huge'"}))
      Build::Commands::Run.size_error(e, "huge").should eq("Could not get a huge session: invalid size 'huge'")
    end

    it "says the platform is too old when it does not know attach" do
      old = [
        Build::ApiError.new(code: 422, message: %({"code":"bad_request","message":"command is required"})),
        Build::ApiError.new(code: 404, message: %({"code":"not_found"})),
        KeyError.new("Missing hash key: \"ticket\""),
      ]
      old.each do |e|
        Build::Commands::Run.size_error(e, "standard-2x").should contain("--size needs a newer Build platform")
      end
    end
  end
{% end %}
