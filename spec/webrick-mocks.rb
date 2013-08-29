require 'webrick'

module Oaf
  class FakeReq

    attr_accessor :path, :request_method, :header, :query
    attr_writer :body

    @body = @path = @request_method = @query = nil
    @header = Hash.new

    def initialize opts={}
      @body = opts[:body] ? opts[:body] : nil
      @path, @query = opts[:path] ? opts[:path].split('?') : ['/']
      @request_method = opts[:method] ? opts[:method] : 'GET'
      @header = opts[:header] ? opts[:header] : Hash.new
    end

    def body
      if ['POST', 'PUT'].member? @request_method
        # Mock a webrick bug
        raise WEBrick::HTTPStatus::LengthRequired
      end
      @body
    end
  end

  class FakeRes

    attr_accessor :body, :status
    attr_reader :header

    def initialize
      @body = @status = nil
      @header = Hash.new
    end

    def [](field)
      @header[field]
    end

    def []=(field, value)
      @header[field] = value
    end
  end
end
