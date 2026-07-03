require "./spec_helper"
require "../src/update_check"

describe Build::UpdateCheck do
  describe ".newer?" do
    it "compares patch, minor, major" do
      Build::UpdateCheck.newer?("1.1.79", "1.1.78").should be_true
      Build::UpdateCheck.newer?("1.2.0", "1.1.99").should be_true
      Build::UpdateCheck.newer?("2.0.0", "1.99.99").should be_true
      Build::UpdateCheck.newer?("1.1.78", "1.1.78").should be_false
      Build::UpdateCheck.newer?("1.1.77", "1.1.78").should be_false
    end

    it "handles differing segment counts and pre-release/build metadata" do
      Build::UpdateCheck.newer?("1.2", "1.2.0").should be_false
      Build::UpdateCheck.newer?("1.2.0.1", "1.2.0").should be_true
      Build::UpdateCheck.newer?("1.2.3-rc.1", "1.2.3").should be_false
      Build::UpdateCheck.newer?("1.2.3+build.5", "1.2.3").should be_false
    end
  end

  describe ".disabled?" do
    it "is true when BUILD_NO_UPDATE_CHECK is set to a truthy value" do
      with_env({"BUILD_NO_UPDATE_CHECK" => "1"}) { Build::UpdateCheck.disabled?.should be_true }
    end

    it "treats 0/false/empty/unset as not disabled" do
      {nil, "", "0", "false"}.each do |v|
        with_env({"BUILD_NO_UPDATE_CHECK" => v}) do
          Build::UpdateCheck.disabled?.should be_false
        end
      end
    end
  end

  describe ".check!" do
    it "skips on non-numeric versions" do
      io = IO::Memory.new
      Build::UpdateCheck.check!("dev", io)
      io.to_s.should be_empty
    end

    it "skips when disabled" do
      with_env({"BUILD_NO_UPDATE_CHECK" => "1"}) do
        io = IO::Memory.new
        Build::UpdateCheck.check!("1.0.0", io)
        io.to_s.should be_empty
      end
    end
  end
end

# Runs a block with env overrides, then restores.
def with_env(overrides, &)
  previous = {} of String => String?
  overrides.each do |key, value|
    k = key.to_s
    previous[k] = ENV[k]?
    if value.nil?
      ENV.delete(k)
    else
      ENV[k] = value
    end
  end
  yield
ensure
  previous.try &.each do |k, v|
    if v.nil?
      ENV.delete(k)
    else
      ENV[k] = v
    end
  end
end
