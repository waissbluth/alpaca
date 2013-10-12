module Rack
  module Alpaca
    class << self
      attr_reader :whitelist, :blacklist
      attr_accessor :default

      def new (app)
        @app = app
        config = YAML.load_file('config/alpaca.yml')
        @whitelist ||= config['whitelist'].map { |ip| IPAddr.new(ip) }.freeze
        @blacklist ||= config['blacklist'].map { |ip| IPAddr.new(ip) }.freeze
        @default = config['default']
        @blocked_message = (config['blocked_message'] || "Service Unavailable") << "\n"

        self
      end

      def call (env)
        req = Rack::Request.new(env)

        if whitelisted?('whitelist', req)
          @app.call(env)
        elsif blacklisted?('blacklist', req)
          [503, {}, [@blocked_message]]
        else
          default_strategy(env)
        end
      end

      private

      def default_strategy (env)
        if @default == 'allow'
          @app.call(env)
        elsif @default == 'deny'
          [503, {}, [@blocked_message]]
        else
          raise 'Unknown default strategy'
        end
      end

      def check (type, req)
        instance_variable_get("@#{type}").any? do |ip|
          ip.include?(req.ip)
        end
      end

      alias_method :whitelisted?, :check
      alias_method :blacklisted?, :check
    end
  end
end
