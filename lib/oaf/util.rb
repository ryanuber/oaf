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

require 'open3'
require 'json'

module Oaf

  module Util
    extend Oaf
    extend self

    # Determines if a line of output looks anything like an HTTP header
    # declaration.
    #
    # == Parameters:
    # line::
    #   A line of text to examine
    #
    # == Returns:
    # A boolean, true if it can be read as a header string, else false.
    #
    def is_http_header? line
      line.split(':').length == 2
    end

    # Retrieves a hash in the form `name` => `value` from a string that
    # describes an HTTP response header.
    #
    # == Parameters:
    # line::
    #   A line of text to parse
    #
    # == Returns
    # A hash in the form `name` => `value`, or `nil`
    #
    def get_http_header line
      return nil if not is_http_header? line
      parts = line.split(':')
      [parts[0].strip, parts[1].strip]
    end

    # Retrieves the numeric value from a line of text as an HTTP status code.
    #
    # == Parameters:
    # line::
    #   A line of text to parse
    #
    # == Returns:
    # An integer if valid, else `nil`.
    #
    def get_http_status line
      is_http_status?(line) ? line.to_i : nil
    end

    # Determines if an HTTP status code is valid per RFC2616
    #
    # == Parameters:
    # code::
    #   A number to validate
    #
    # == Returns
    # A boolean, true if valid, else false.
    #
    def is_http_status? code
      (200..206).to_a.concat((300..307).to_a).concat((400..417).to_a) \
        .concat((500..505).to_a).include? code.to_i
    end

    # Convert various pieces of data about the request into a single hash, which
    # can then be passed on as environment data to a script.
    #
    # == Parameters:
    # headers::
    #   A hash of request headers
    # query::
    #   A hash of query parameters
    # body::
    #   A string containing the request body
    #
    # == Returns:
    # A flat hash containing namespaced environment parameters
    #
    def prepare_environment headers, query, body
      result = Hash.new
      headers.each do |name, value|
        name = Oaf::Util.prepare_key name
        result["oaf_header_#{name}"] = Oaf::Util.flatten value
      end
      query.each do |name, value|
        name = Oaf::Util.prepare_key name
        result["oaf_query_#{name}"] = Oaf::Util.flatten value
      end
      result["oaf_request_body"] = Oaf::Util.flatten body
      result
    end

    # Replace characters that would not be suitable for an environment variable
    # name. Currently this only replaces dashes with underscores. If the need
    # arises, more can be added here later.
    #
    # == Parameters:
    # key::
    #   The key to sanitize
    #
    # == Returns:
    # A string with the prepared value
    #
    def prepare_key key
      key.gsub('-', '_').downcase
    end

    # Flatten a hash or array into a string. This is useful for preparing some
    # data for passing in via the environment, because multi-dimension data
    # structures are not supported for that.
    #
    # == Parameters:
    # data::
    #   The data to flatten
    #
    # == Returns:
    # A flattened string. It will be empty if the object passed in was not
    # flatten-able.
    #
    def flatten data
      result = ''
      if data.kind_of? Hash
        data.each do |key, val|
          val = Oaf::Util.flatten val if not val.kind_of? String
          result += "#{key}#{val}"
        end
      elsif data.kind_of? Array
        data.each do |item|
          item = Oaf::Util.flatten item if not item.kind_of? String
          result += item
        end
      elsif data.kind_of? String
        result = data
      else
        result = ''
      end
      result
    end

    # Given an array of text lines, iterate over each of them and determine if
    # they may be interpreted as headers or status. If they can, add them to
    # the result.
    #
    # == Parameters:
    # text::
    #   Plain text data to examine
    #
    # == Returns:
    # A 3-item structure containing headers, status, and the number of lines
    # which the complete metadata (including the "---" delimiter) occupies.
    #
    def parse_http_meta text
      headers = {}
      status = 200
      size = 0
      if text.to_s != ''
        parts = text.split /^---$/
        if parts.length > 1
          meta = parts.last.split "\n"
          for part in meta
            if Oaf::Util.is_http_header? part
              header, value = Oaf::Util.get_http_header part
              headers.merge! header => value
            elsif Oaf::Util.is_http_status? part
              status = Oaf::Util.get_http_status part
            else
              next
            end
            size += size == 0 ? 2 : 1  # compensate for delimiter
          end
        end
      end
      [headers, status, size]
    end

    # Return a default response string indicating that nothing could be
    # done and no response files were found.
    #
    # == Returns:
    # A string with response output for parsing.
    #
    def get_default_response
      "oaf: Not Found\n---\n404"
    end

    # Returns the path to the file to use for the request. If the provided
    # file path does not exist, this method will search for a file within
    # the same directory matching the default convention "_*_".
    #
    # == Parameters:
    # root::
    #   The root path to search within.
    # uri::
    #   The URI of the request
    # method::
    #   The HTTP method of the request
    #
    # == Returns:
    # The path to a file to use, or `nil` if none is found.
    #
    def get_request_file root, uri, method
      file = File.join root, "#{uri}.#{method}"
      if not File.exist? file
        Dir.glob(File.join(File.dirname(file), "_*_.#{method}")).each do |f|
          file = f
          break
        end
      end
      File.exist?(file) ? file : nil
    end

    # Run a command with stdout and stderr buffered. This suppresses error
    # messages from the server process and enables us to return them in the
    # HTTP response instead.
    #
    # == Parameters:
    # command::
    #   The command to execute against the server
    #
    # == Returns:
    # A string of stderr concatenated to stdout.
    #
    def run_buffered env, command
      stdin, stdout, stderr = Open3.popen3 env, "#{command} 2>&1"
      stdout.read
    end

    # Executes a file, or reads its contents if it is not executable, passing
    # it the request headers and body as arguments, and returns the result.
    #
    # == Parameters:
    # file::
    #   The path to the file to use for output
    # headers::
    #   The HTTP request headers to pass
    # body::
    #   The HTTP request body to pass
    # query::
    #   The HTTP query parameters to pass
    #
    # == Returns:
    # The result from the file, or a default result if the file is not found.
    #
    def get_output file, headers=[], body=[], query=[]
      if file.nil?
        out = Oaf::Util.get_default_response
      elsif File.executable? file
        env = Oaf::Util.prepare_environment headers, query, body
        out = Oaf::Util.run_buffered env, file
      else
        out = File.open(file).read
      end
      out
    end
  end
end
