require 'lotus/utils/class'
require 'lotus/utils/kernel'
require 'lotus/utils/string'
require 'lotus/routes'
require 'lotus/routing/default'

module Lotus
  class Loader
    def initialize(application)
      @application   = application
      @configuration = @application.configuration

      @mutex = Mutex.new
    end

    def load!
      @mutex.synchronize do
        load_frameworks!
        load_application!
        finalize!
      end
    end

    private
    attr_reader :application, :configuration

    def load_frameworks!
      config = configuration

      unless application_module.const_defined?('Controller')
        controller = Lotus::Controller.duplicate(application_module)
        application_module.const_set('Controller', controller)
      end

      unless application_module.const_defined?('View')
        view = Lotus::View.duplicate(application_module) do
          root Utils::Kernel.Pathname(config.root.join('app/templates'))

          unless config.layout.nil?
            layout config.layout
          end
        end

        application_module.const_set('View', view)
      end
    end

    def load_application!
      configuration.load_paths.load!

      resolver    = Lotus::Routing::EndpointResolver.new(pattern: configuration.controller_pattern, namespace: application_module)
      default_app = Lotus::Routing::Default.new
      application.routes = Lotus::Router.new(
        resolver:    resolver,
        default_app: default_app,
        scheme:      configuration.scheme,
        host:        configuration.host,
        port:        configuration.port,
        &configuration.routes
      )

      application.middleware # preload
    end

    def finalize!
      unless application_module.const_defined?('Routes')
        routes = Lotus::Routes.new(application.routes)
        application_module.const_set('Routes', routes)
      end

      application_module.module_eval do
        View.load!
      end
    end

    def application_module
      @application_module ||= Utils::Class.load!(
        Utils::String.new(application.class).namespace
      )
    end
  end
end
