# encoding: UTF-8

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cor1440Cinep
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'America/Bogota'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :es

    config.relative_url_root = "/act"

    config.active_record.schema_format = :sql

    config.x.formato_fecha = 'dd/M/yyyy'

    config.x.jn316_base = "ou=gente,dc=cinep,dc=org,dc=co"
    config.x.jn316_admin = "cn=admin,dc=cinep,dc=org,dc=co"
    config.x.jn316_servidor = "apbd2.cinep.org.co"
    config.x.jn316_puerto = 389
#    config.x.jn316_opcon = {
#      encryption: {
#        method: :start_tls,
#        tls_options: OpenSSL::SSL::SSLContext::DEFAULT_PARAMS
#      }
#    }


    #config.console.whitelisted_ips = '186.29.40.148'
  end
end
