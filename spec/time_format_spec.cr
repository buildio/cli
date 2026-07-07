require "./spec_helper"
require "../src/time_format"

describe Build::TimeFormat do
  describe ".parse?" do
    it "parses the millisecond+Z form the API commonly emits" do
      t = Build::TimeFormat.parse?("2024-01-15T10:30:00.123Z")
      t.should_not be_nil
      t.not_nil!.to_utc.should eq(Time.utc(2024, 1, 15, 10, 30, 0, nanosecond: 123_000_000))
    end

    it "parses timestamps without fractional seconds" do
      Build::TimeFormat.parse?("2024-01-15T10:30:00Z").try(&.to_utc)
        .should eq(Time.utc(2024, 1, 15, 10, 30, 0))
    end

    it "parses microsecond precision" do
      Build::TimeFormat.parse?("2024-01-15T10:30:00.123456Z").should_not be_nil
    end

    it "parses a numeric UTC offset instead of Z" do
      Build::TimeFormat.parse?("2024-01-15T10:30:00+00:00").try(&.to_utc)
        .should eq(Time.utc(2024, 1, 15, 10, 30, 0))
    end

    it "parses a fractional time with a non-zero offset" do
      Build::TimeFormat.parse?("2024-01-15T10:30:00.5+02:00").try(&.to_utc)
        .should eq(Time.utc(2024, 1, 15, 8, 30, 0, nanosecond: 500_000_000))
    end

    it "returns nil for an empty string instead of raising" do
      Build::TimeFormat.parse?("").should be_nil
    end

    it "returns nil for nil instead of raising" do
      Build::TimeFormat.parse?(nil).should be_nil
    end

    it "returns nil for unparseable input instead of raising" do
      Build::TimeFormat.parse?("not-a-time").should be_nil
      Build::TimeFormat.parse?("2024-13-99").should be_nil
    end

    it "returns nil for well-formed but out-of-range timestamps (raises ArgumentError, not Format::Error)" do
      Build::TimeFormat.parse?("2024-02-30T10:00:00Z").should be_nil  # Feb 30
      Build::TimeFormat.parse?("2024-01-15T25:00:00Z").should be_nil  # hour 25
      Build::TimeFormat.parse?("2024-13-01T00:00:00Z").should be_nil  # month 13
    end
  end
end
