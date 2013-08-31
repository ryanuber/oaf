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

require 'spec_helper'

module Oaf
  describe "Returning HTTP Responses" do
    it "should return safe defaults if output is empty" do
      headers, status, body = Oaf::HTTP::Server.parse_response ''
      headers.should eq({})
      status.should eq(200)
      body.should eq("\n")
    end

    it "should return safe defaults when only body is present" do
      text = "This is a test\n"
      headers, status, body = Oaf::HTTP::Server.parse_response text
      headers.should eq({})
      status.should eq(200)
      body.should eq("This is a test\n")
    end

    it "should return headers correctly" do
      text = "---\nx-powered-by: oaf"
      headers, status, body = Oaf::HTTP::Server.parse_response text
      headers.should eq({'x-powered-by' => 'oaf'})
    end

    it "should return status correctly" do
      text = "---\n201"
      headers, status, body = Oaf::HTTP::Server.parse_response text
      status.should eq(201)
    end

    it "should return body correctly" do
      text = "This is a test\n---\n200"
      headers, status, body = Oaf::HTTP::Server.parse_response text
      body.should eq("This is a test\n")
    end

    it "should return body correctly when no metadata is present" do
      text = "This is a test"
      headers, status, body = Oaf::HTTP::Server.parse_response text
      body.should eq("This is a test\n")
    end
  end

  describe "Running an HTTP Server" do
    before(:all) do
      require 'webrick-mocks'
      @tempdir1 = Dir.mktmpdir
      @f1 = Tempfile.new ['oaf', '.GET'], @tempdir1
      @f1.write "This is a test.\n---\n201\nx-powered-by: oaf"
      @f1.close
      @f1request = File.basename(@f1.path).sub!(/\.GET$/, '')

      @f2 = Tempfile.new ['oaf', '.PUT'], @tempdir1
      @f2.write "Containable Test\n---\n202\nx-powered-by: oaf"
      @f2.close
      @f2request = File.basename(@f2.path).sub!(/\.PUT$/, '')
    end

    after(:all) do
      @f1.delete
      @f2.delete
      Dir.delete @tempdir1
    end

    it "should start an HTTP server" do
      @webrick = double()
      @webrick.should_receive(:start).once.and_return(true)
      WEBrick::HTTPServer.stub(:new).and_return(@webrick)
      @webrick.should_receive(:mount) \
        .with('/', Oaf::HTTP::Handler, '/tmp').once \
        .and_return(true)
      Oaf::HTTP::Server.serve '/tmp', 9000
    end

    it "should parse the request properly" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      handler = Oaf::HTTP::Handler.new Oaf::FakeServlet.new, @tempdir1
      handler.process_request req, res
      res.body.should eq("This is a test.\n")
      res.status.should eq(201)
      res.header.should eq('x-powered-by' => 'oaf')
    end

    it "should accept containable methods properly" do
      req = Oaf::FakeReq.new({:path => @f2request, :method => 'PUT'})
      res = Oaf::FakeRes.new
      handler = Oaf::HTTP::Handler.new Oaf::FakeServlet.new, @tempdir1
      handler.process_request req, res
      res.body.should eq("Containable Test\n")
      res.status.should eq(202)
      res.header.should eq('x-powered-by' => 'oaf')
    end

    it "should respond to any HTTP method" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      Oaf::HTTP::Handler.any_instance.stub(:process_request).and_return(true)
      handler = Oaf::HTTP::Handler.new Oaf::FakeServlet.new, @tempdir1
      handler.should_receive(:process_request).with(req, res).once
      handler.respond_to?(:do_GET).should be_true
      handler.respond_to?(:do_get).should be_false
      handler.respond_to?(:nonexistent).should be_false
      handler.do_PUT(req, res)
    end

    it "should call our custom methods for built-ins" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      Oaf::HTTP::Handler.any_instance.stub(:process_request).and_return(true)
      handler = Oaf::HTTP::Handler.new Oaf::FakeServlet.new, @tempdir1
      handler.should_receive(:process_request).with(req, res).exactly(4).times
      handler.do_GET(req, res)
      handler.do_POST(req, res)
      handler.do_HEAD(req, res)
      handler.do_OPTIONS(req, res)
    end
  end
end
