require "build-client"
require "../i18n"

module Build
  class ApiClient
    def call_api(http_method : Symbol, path : String, operation : Symbol, return_type : String?, post_body : String?, auth_names = [] of String, header_params = {} of String => String, query_params = {} of String => String, cookie_params = {} of String => String, form_params = {} of Symbol => (String | ::File))
      header_params["Accept-Language"] ||= Build::Locale.accept_language
      previous_def
    end
  end
end
