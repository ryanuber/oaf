require 'oaf/util'
require 'oaf/httpserver'
require 'webrick'

module Oaf

  # Provides all required handlers to WEBrick for serving all basic HTTP
  # methods. WEBrick handles GET, POST, HEAD, and OPTIONS out of the box,
  # but to mock most RESTful applications we are going to want PUT and
  # DELETE undoubtedly.
  class HTTPHandler < WEBrick::HTTPServlet::AbstractServlet

    # Remove the predefined WEBrick methods. WEBrick comes with some defaults
    # for GET, POST, OPTIONS, and HEAD, but let's use our own instead.
    instance_methods.each do |method|
      undef_method method if method.to_s =~ /^do_[A-Z]+$/
    end

    # Creates a new abstract server object and allows passing in the root
    # path of the server via an argument.
    #
    # == Parameters:
    # server::
    #   A WEBrick::HTTPServer object
    # path::
    #   A string containing the root path
    #
    def initialize server, path
      super server
      @path = path
    end

    # Main server method. Oaf does not really differentiate between different
    # HTTP methods, but needs to at least support passing them all.
    #
    # == Parameters:
    # req::
    #   A WEBrick::HTTPRequest object
    # res::
    #   A WEBrick::HTTPResponse object
    #
    def process_request req, res
      req_headers = req.header
      req_query = req.query
      req_body = Oaf::HTTPServer.get_request_body req
      file = Oaf::Util.get_request_file @path, req.path, req.request_method
      out = Oaf::Util.get_output(@path, file, req.path, req_headers, req_body,
                                 req_query)
      res_headers, res_status, res_body = Oaf::HTTPServer.parse_response out
      Oaf::HTTPServer.set_response! res, res_headers, res_body, res_status
    end

    # A magic respond_to? implementation to trick WEBrick into thinking that any
    # do_* methods are already defined. This allows method_missing to do its job
    # once WEBrick makes its call to the method.
    #
    # == Parameters:
    # method::
    #   The name of the class method being checked
    #
    # == Returns:
    # Boolean, true if the method name matches do_[A-Z]+, else super.
    #
    def respond_to? method
      method.to_s =~ /^do_[A-Z]+$/ ? true : super
    end

    # A magic method to handle any and all do_* methods. This allows Oaf to
    # claim some degree of support for any HTTP method, be it a known and
    # commonly used method such as PUT or DELETE, or custom methods.
    #
    # == Parameters:
    # method::
    #   The name of the method being called
    # *opt::
    #   A list of arguments to pass along to the processing method
    #
    def method_missing method, *opt
      method.to_s =~ /^do_[A-Z]+$/ ? process_request(*opt) : super
    end
  end
end
