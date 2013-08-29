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

require 'oaf'
require 'ostruct'
require 'tempfile'

module Oaf
  describe "Header Lines" do
    it "should detect a valid header line" do
      result = Oaf::Util.is_http_header? 'x-powered-by: oaf'
      result.should be_true
    end

    it "should detect an invalid header line" do
      result = Oaf::Util.is_http_header? 'invalid header line'
      result.should be_false
    end

    it "should parse a name and value from a header line" do
      result = Oaf::Util.get_http_header 'x-powered-by: oaf'
      result.should eq(['x-powered-by', 'oaf'])
    end

    it  "should detect an invalid header line during header parsing" do
      result = Oaf::Util.get_http_header 'invalid header line'
      result.should be_nil
    end
  end

  describe "Status Lines" do
    it "should detect all valid HTTP status codes" do
      [200, 201, 202, 203, 204, 205, 206,
       300, 301, 302, 303, 304, 305, 306, 307,
       400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411,
       412, 413, 414, 415, 416, 417,
       500, 501, 502, 503, 504, 505].each do  |status|
        result = Oaf::Util.is_http_status? status
        result.should be_true
      end
    end

    it "should be able to validate a string http status line" do
      result = Oaf::Util.is_http_status? '200'
      result.should be_true
    end

    it "should detect an invalid http status code" do
      result1 = Oaf::Util.is_http_status? 199
      result2 = Oaf::Util.is_http_status? 'not a status'
      result1.should be_false
      result2.should be_false
    end

    it "should retrieve an http status code" do
      result = Oaf::Util.get_http_status '200'
      result.should eq(200)
    end

    it "should detect an invalid status code during parsing" do
      result = Oaf::Util.get_http_status 'not a status'
      result.should be_nil
    end
  end

  describe "Format Request Headers" do
    it "should return a single key/value for just one header" do
      headers = [['x-powered-by', 'oaf']]
      result = Oaf::Util.format_request_headers headers
      result.should eq('x-powered-by:oaf')
    end

    it "should return a comma-delimited list for multiple headers" do
      headers = [['x-powered-by', 'oaf'], ['content-type', 'text/plain']]
      result = Oaf::Util.format_request_headers headers
      result.should eq('x-powered-by:oaf,content-type:text/plain')
    end

    it "should return nil if no headers present" do
      headers = []
      result = Oaf::Util.format_request_headers headers
      result.should be_nil
    end
  end

  describe "Parse Request Metadata From Output" do
    it "should find headers in request metadata" do
      text = ['---', 'x-powered-by: oaf', '201'].join "\n"
      headers, status, size = Oaf::Util.parse_http_meta text
      headers.should eq('x-powered-by' => 'oaf')
    end

    it "should return the number of lines the metadata consumes" do
      text = ['---', 'x-powered-by: oaf', '200'].join "\n"
      headers, status, size = Oaf::Util.parse_http_meta text
      size.should eq(3)
    end

    it "should assume 200 as the default return code" do
      text = ['---', 'x-powered-by: oaf'].join "\n"
      headers, status, size = Oaf::Util.parse_http_meta text
      status.should eq(200)
    end

    it "should assume meta size 0 if no metadata is present" do
      text = 'this response uses default metadata'
      headers, status, size = Oaf::Util.parse_http_meta text
      size.should eq(0)
    end

    it "should return safe defaults if the response is empty" do
      text = ''
      headers, status, size = Oaf::Util.parse_http_meta text
      headers.should eq({})
      status.should eq(200)
      size.should eq(0)
    end
  end

  describe "Determine File Paths" do
    before(:all) do
      @tempdir1 = Dir.mktmpdir
      @tempdir2 = Dir.mktmpdir

      @f1 = Tempfile.new ['oaf', '.GET'], @tempdir1
      @f1.write "This is a test.\n"
      @f1.close
      @f1request = File.basename(@f1.path).sub!(/\.GET$/, '')

      @f2 = Tempfile.new ['_', '_.GET'], @tempdir1
      @f2.write "This is a default file.\n"
      @f2.close
    end

    after(:all) do
      @f1.delete
      @f2.delete
      Dir.delete @tempdir1
      Dir.delete @tempdir2
    end

    it "should find existing files correctly" do
      result = Oaf::Util.get_request_file @tempdir1, @f1request, 'GET'
      result.should eq(@f1.path)
    end

    it "should return the fall-through file if request file doesn't exist" do
      result = Oaf::Util.get_request_file @tempdir1, 'nonexistent', 'GET'
      result.should eq(@f2.path)
    end

    it "should return nil if neither the requested or default file exist" do
      result = Oaf::Util.get_request_file @tempdir2, 'nonexistent', 'GET'
      result.should be_nil
    end
  end

  describe "Executing and Reading Files" do
    before(:all) do
      @f1 = Tempfile.new 'oaf'
      @f1.chmod 0755
      @f1.write "#!/bin/bash\necho 'This is a test'"
      @f1.close

      @f2 = Tempfile.new 'oaf'
      @f2.chmod 0644
      @f2.write "This is a test\n"
      @f2.close
    end

    after(:all) do
      @f1.delete
      @f2.delete
    end

    it "should execute a file if it is executable" do
      result = Oaf::Util.get_output @f1.path, nil, nil
      result.should eq("This is a test\n")
    end

    it "should read file contents if it is not executable" do
      result = Oaf::Util.get_output @f2.path, nil, nil
      result.should eq("This is a test\n")
    end

    it "should assume safe defaults if the file doesnt exist" do
      result = Oaf::Util.get_output nil, nil, nil
      result.should eq(Oaf::Util.get_default_response)
    end
  end
end
