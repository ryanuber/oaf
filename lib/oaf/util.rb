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
      {parts[0].strip => parts[1].strip}
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
    def prepare_environment uri, headers, query, body
      result = Hash.new
      {'header' => headers, 'query' => query}.each do |prefix, data|
        data.each do |name, value|
          result.merge! Oaf::Util.environment_item prefix, name, value
        end
      end
      result.merge! Oaf::Util.environment_item 'request', 'uri', uri
      result.merge Oaf::Util.environment_item 'request', 'body', body
    end

    # Prepares a key for placement in the execution environment. This includes
    # namespacing variables and converting characters to predictable and
    # easy-to-use names.
    #
    # == Parameters:
    # prefix::
    #   A prefix for the key. This helps with separation.
    # key::
    #   The key to sanitize
    #
    # == Returns:
    # A string with the prepared value
    #
    def prepare_key prefix, key
      "oaf_#{prefix}_#{key.gsub('-', '_').downcase}"
    end

    # Formats a single environment item into a hash, which can be merged into a
    # collective environment mapping later on.
    #
    # == Parameters:
    # prefix::
    #   The prefix for the type of item being added.
    # key::
    #   The key name of the environment property
    # value::
    #   The value for the environment property
    #
    # == Returns:
    # A hash with prepared values ready to merge into an environment hash
    #
    def environment_item prefix, key, value
      {Oaf::Util.prepare_key(prefix, key) => Oaf::Util.flatten(value)}
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
      parts = text.split /^---$/
      if parts.length > 1
        for part in parts.last.split "\n"
          if Oaf::Util.is_http_header? part
            headers.merge! Oaf::Util.get_http_header part
          elsif Oaf::Util.is_http_status? part
            status = Oaf::Util.get_http_status part
          else next
          end
          size += size == 0 ? 2 : 1  # compensate for delimiter
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

    # Fork a new process, in which we can safely modify the running environment
    # and run a command, sending data back to the parent process using an IO
    # pipe. This can be done in a single line in ruby >= 1.9, but we will do it
    # the hard way to maintain compatibility with older rubies.
    #
    # == Parameters:
    # env::
    #   The environment data to use in the subprocess.
    # command::
    #   The command to execute against the server
    #
    # == Returns:
    # A string of stderr concatenated to stdout.
    #
    def run_buffered env, command
      out, wout = IO.pipe
      pid = fork do
        out.close
        ENV.replace env
        wout.write %x(#{command} 2>&1)
        at_exit { exit! }
      end
      wout.close
      Process.wait pid
      out.read
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
    def get_output file, uri=nil, headers=[], body=[], query=[]
      if file.nil?
        out = Oaf::Util.get_default_response
      elsif File.executable? file
        env = Oaf::Util.prepare_environment uri, headers, query, body
        out = Oaf::Util.run_buffered env, file
      else
        out = File.open(file).read
      end
      out
    end
  end
end
