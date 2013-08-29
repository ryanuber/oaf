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
      headers, status, body = Oaf::HTTP.parse_response ''
      headers.should eq({})
      status.should eq(200)
      body.should eq("\n")
    end

    it "should return safe defaults when only body is present" do
      text = "This is a test\n"
      headers, status, body = Oaf::HTTP.parse_response text
      headers.should eq({})
      status.should eq(200)
      body.should eq("This is a test\n")
    end

    it "should return headers correctly" do
      text = "---\nx-powered-by: oaf"
      headers, status, body = Oaf::HTTP.parse_response text
      headers.should eq({'x-powered-by' => 'oaf'})
    end

    it "should return status correctly" do
      text = "---\n201"
      headers, status, body = Oaf::HTTP.parse_response text
      status.should eq(201)
    end

    it "should return body correctly" do
      text = "This is a test\n---\n200"
      headers, status, body = Oaf::HTTP.parse_response text
      body.should eq("This is a test\n")
    end

    it "should return body correctly when no metadata is present" do
      text = "This is a test"
      headers, status, body = Oaf::HTTP.parse_response text
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

    before(:each) do
      @webrick = double()
      @webrick.should_receive(:start).once.and_return(true)
      WEBrick::HTTPServer.stub(:new).and_return(@webrick)
    end

    it "should start an HTTP server" do
      @webrick.should_receive(:mount_proc).with('/').once \
        .and_yield(Oaf::FakeReq.new, Oaf::FakeRes.new)
      Oaf::HTTP.serve '/tmp', 9000
    end

    it "should parse the request properly" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      @webrick.should_receive(:mount_proc).with('/').once \
        .and_yield(req, res)
      Oaf::HTTP.serve @tempdir1, 9000
      res.body.should eq("This is a test.\n")
      res.status.should eq(201)
      res.header.should eq('x-powered-by' => 'oaf')
    end

    it "should accept containable methods properly" do
      req = Oaf::FakeReq.new({:path => @f2request, :method => 'PUT'})
      res = Oaf::FakeRes.new
      @webrick.should_receive(:mount_proc).with('/').once \
        .and_yield(req, res)
      Oaf::HTTP.serve(@tempdir1, 9000)
      res.body.should eq("Containable Test\n")
      res.status.should eq(202)
      res.header.should eq('x-powered-by' => 'oaf')
    end
  end
end
