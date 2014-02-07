require 'oaf/util'
require 'oaf/httphandler'
require 'webrick'

module Oaf::HTTPServer
  extend self

  # Given output from a script, parse HTTP response details and return them
  # as a hash, including body, status, and headers.
  #
  # == Parameters:
  # output::
  #   The output text data returned by a script.
  #
  # == Returns:
  # A hash containing the HTTP response details (body, status, and headers).
  #
  def parse_response output
    has_meta = false
    headers = {'content-type' => 'text/plain'}
    status = 200
    headers, status, meta_size = Oaf::Util.parse_http_meta output
    lines = output.split("\n")
    body = lines.take(lines.length - meta_size).join("\n")+"\n"
    [headers, status, body]
  end

  # Safely retrieves the request body, and assumes an empty string if it
  # cannot be retrieved. This helps get around a nasty exception in WEBrick.
  #
  # == Parameters:
  # req::
  #   A WEBrick::HTTPRequest object
  #
  # == Returns:
  # A string containing the request body
  #
  def get_request_body req
    if ['POST', 'PUT'].member? req.request_method
      begin
        result = req.body
      rescue WEBrick::HTTPStatus::LengthRequired
        result = ''  # needs to be in rescue for coverage
      end
    end
    result
  end

  # Consume HTTP response details and set them into a response object.
  #
  # == Parameters:
  # res::
  #   A WEBrick::HTTPResponse object
  # headers::
  #   A hash containing HTTP response headers
  # body::
  #   A string containing the HTTP response body
  # status::
  #   An integer indicating the response status
  #
  def set_response! res, headers, body, status
    headers.each do |name, value|
      res.header[name] = value
    end
    res.body = body
    res.status = status
  end

  # Invokes the Webrick web server library to handle incoming requests, and
  # routes them to the appropriate scripts if they exist on the filesystem.
  #
  # == Parameters:
  # path::
  #   The path in which to search for files
  # port::
  #   The TCP port to listen on
  #
  def serve path, port
    server = WEBrick::HTTPServer.new :Port => port
    server.mount '/', Oaf::HTTPHandler, path
    trap 'INT' do server.shutdown end
    server.start
  end
end
