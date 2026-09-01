require "i18n"

module Build
  module Locale
    OVERRIDE_VAR = "BUILD_LOCALE"
    DETECTION_VARS = {"LC_ALL", "LC_MESSAGES", "LANG"}
    SUPPORTED = {"en", "ja"}
    DEFAULT = "en"

    @@initialized = false

    def self.init : Nil
      unless @@initialized
        I18n.config.loaders << I18n::Loader::YAML.embed("src/locales")
        I18n.config.default_locale = DEFAULT
        I18n.config.available_locales = SUPPORTED.to_a
        I18n.config.fallbacks = {"ja" => ["en"]}
        I18n.init
        @@initialized = true
      end

      I18n.activate(selected)
    end

    def self.selected(env = ENV) : String
      raw = env[OVERRIDE_VAR]?
      raw = DETECTION_VARS.compact_map { |name| env[name]? }.find { |value| !value.blank? } if raw.nil? || raw.blank?
      normalize(raw)
    end

    def self.accept_language(env = ENV) : String
      case selected(env)
      when "ja"
        "ja"
      else
        "en"
      end
    end

    def self.normalize(raw : String?) : String
      return DEFAULT if raw.nil? || raw.blank?

      locale = raw.split('.', 2).first.downcase.tr("_", "-")
      return DEFAULT if locale == "c" || locale == "posix"

      language = locale.split('-', 2).first
      SUPPORTED.includes?(language) ? language : DEFAULT
    end
  end

  def self.t(message_key : String | Symbol, params : Hash | NamedTuple | Nil = nil) : String
    I18n.t!(message_key, params)
  end

  def self.t(message_key : String | Symbol, **kwargs) : String
    I18n.t!(message_key, kwargs)
  end
end
