# oaf - Care-free web app prototyping using files and scripts
# Copyright 2013 Ryan Uber <ru@ryanuber.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'oaf/util'
require 'oaf/http/handler'
require 'webrick'

module Oaf::HTTP

  module Server
    extend Oaf
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
      server.mount '/', Oaf::HTTP::Handler, path
      trap 'INT' do server.shutdown end
      server.start
    end
  end
end
