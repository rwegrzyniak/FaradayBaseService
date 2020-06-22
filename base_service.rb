class BaseService
  attr_reader :resp, :errors, :status, :client_error
  private_class_method :new

  MESS = 'Subclass have to implement call() method'.freeze
  RESERVED_NAME_ERR = 'Method name %<name>s is reserved for internaly use of %<class_name>s'.freeze
  RESERVED_NAMES = %i[internal_call boot].freeze
  BASE_CLASS_NAME = to_s.freeze
  CONNECTION_FAILED_ERR = 'Failed to connect to external service'.freeze
  # using send intentionaly to keep boot and handle_errors private
  def self.call(params)
    service = new(params)
    service.send :boot
    # check if subclass call() was already wrapped
    wrap_call(service.class) unless service.respond_to?(:internal_call, true)

    service.send :set_success! if service.call
    service.send :handle_errors if service.failure?
    yield(service) if block_given?
    service
  end

  def method_missing(method)
    return @parsed_resp[method] if @parsed_resp&.key? method

    super
  end

  def respond_to_missing?(method, *args)
    @parsed_resp&.key?(method) || super
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def success
    yield(self) if success?
  end

  def failure
    yield(self) if failure?
  end

  def self.wrap_call(subclass)
    subclass.alias_method :internal_call, :call
    subclass.define_method(:call) do |*args|
      return true if internal_call(*args) == true

      false
    rescue ::Faraday::Error => e
      @succes = false
      @errors << e.message
      @is_client_error = true
      handle_internal_errors(e)
      false
    end
  end

  def error
    return @client_error if @is_client_error

    errors
  end

  def client_error?
    @is_client_error
  end

  def context
    { response_status: @status, parsed_response: @parsed_res } if @resp
  end

  private

  # another name to avoid shadowing by subclass initialize()
  def boot
    @errors = []
    @success = false
    @client_opts = { url: "http://#{base_url}/" }
    @client_opts.merge!(client_options) if respond_to?(:client_options)

    @conn = Faraday.new(@client_opts)
    raise NotImplementedError, MESS unless respond_to? :call # check if call is implemented in subclass
  end

  def handle_errors
    return if @is_client_error # no response if there is Faraday error

    @errors << @parsed_resp[:message]
    @status = @resp.status
  end

  def handle_internal_errors(exception)
    @client_error = CONNECTION_FAILED_ERR if exception.is_a? Faraday::ConnectionFailed
  end

  def set_success!
    @success = true
  end

  def resp=(resp)
    @resp = resp
    @parsed_resp = JSON.parse(@resp.body).symbolize_keys!
  end

  def base_url
    @base_url ||= Rails.configuration.public_send(to_s.split('::')[-2].underscore).base_url
  end

  # explicity setting public for code readabilty
  # rubocop:disable Lint/UselessAccessModifier

  public

  # rubocop:enable Lint/UselessAccessModifier

  def self.method_added(name)
    return unless respond_to?(name)
    return if name == :internal_call && try(:method, name)&.original_name == :call
    raise StandardError, format(RESERVED_NAME_ERR, { name: name, class_name: BASE_CLASS_NAME }) if RESERVED_NAMES.include? name
  end

end
