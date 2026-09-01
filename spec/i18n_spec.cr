require "./spec_helper"
require "../src/i18n"

private def with_locale_env(overrides, &)
  previous = {} of String => String?
  keys = [Build::Locale::OVERRIDE_VAR, "LC_ALL", "LC_MESSAGES", "LANG"]
  keys.each { |key| previous[key] = ENV[key]? }

  keys.each { |key| ENV.delete(key) }
  overrides.each do |key, value|
    if value.nil?
      ENV.delete(key.to_s)
    else
      ENV[key.to_s] = value.to_s
    end
  end

  yield
ensure
  previous.try &.each do |key, value|
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
  Build::Locale.init
end

describe Build::Locale do
  it "normalizes Japanese locale variants" do
    Build::Locale.normalize("ja").should eq("ja")
    Build::Locale.normalize("ja_JP.UTF-8").should eq("ja")
    Build::Locale.normalize("ja-JP").should eq("ja")
  end

  it "falls back to English for POSIX and unsupported locales" do
    Build::Locale.normalize("C").should eq("en")
    Build::Locale.normalize("POSIX").should eq("en")
    Build::Locale.normalize("fr_FR.UTF-8").should eq("en")
  end

  it "lets BUILD_LOCALE override process locale variables" do
    with_locale_env({"BUILD_LOCALE" => "en", "LANG" => "ja_JP.UTF-8"}) do
      Build::Locale.selected.should eq("en")
    end
  end

  it "detects Japanese from LANG" do
    with_locale_env({"LANG" => "ja_JP.UTF-8"}) do
      Build::Locale.selected.should eq("ja")
    end
  end

  it "uses the selected locale as the platform Accept-Language" do
    with_locale_env({"LANG" => "ja_JP.UTF-8"}) do
      Build::Locale.accept_language.should eq("ja")
    end

    with_locale_env({"BUILD_LOCALE" => "fr"}) do
      Build::Locale.accept_language.should eq("en")
    end
  end
end
