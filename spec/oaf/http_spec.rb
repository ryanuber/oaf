require 'spec_helper'

module Oaf
  describe "Returning HTTP Responses" do
    it "should return safe defaults if output is empty" do
      headers, status, body = Oaf::HTTPServer.parse_response ''
      headers.should eq({})
      status.should eq(200)
      body.should eq("\n")
    end

    it "should return safe defaults when only body is present" do
      text = "This is a test\n"
      headers, status, body = Oaf::HTTPServer.parse_response text
      headers.should eq({})
      status.should eq(200)
      body.should eq("This is a test\n")
    end

    it "should return headers correctly" do
      text = "---\nx-powered-by: oaf"
      headers, status, body = Oaf::HTTPServer.parse_response text
      headers.should eq({'x-powered-by' => 'oaf'})
    end

    it "should return status correctly" do
      text = "---\n201"
      headers, status, body = Oaf::HTTPServer.parse_response text
      status.should eq(201)
    end

    it "should return body correctly" do
      text = "This is a test\n---\n200"
      headers, status, body = Oaf::HTTPServer.parse_response text
      body.should eq("This is a test\n")
    end

    it "should return body correctly when no metadata is present" do
      text = "This is a test"
      headers, status, body = Oaf::HTTPServer.parse_response text
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

      @tempdir2 = Dir.mktmpdir
      Dir.mkdir File.join(@tempdir2, 'sub')
      @f3 = File.new File.join(@tempdir2, 'sub', '_default_.GET'), 'w'
      @f3.write "Directory wins"
      @f3.close
      @f3request = 'sub'

      @tempdir3 = Dir.mktmpdir
      @f4 = File.new File.join(@tempdir3, 'sub.GET'), 'w'
      @f4.write "File wins"
      @f4.close
      @f4request = 'sub'
      Dir.mkdir File.join(@tempdir3, 'sub')
      f5 = File.new File.join(@tempdir3, 'sub', '_default_.GET'), 'w'
      f5.write "Directory wins"
      f5.close
    end

    after(:all) do
      @f2.delete
      FileUtils.rm_rf @tempdir1
      FileUtils.rm_rf @tempdir2
    end

    it "should start an HTTP server" do
      options = {:path => '/tmp', :port => 9000}
      @webrick = double()
      @webrick.should_receive(:start).once.and_return(true)
      WEBrick::HTTPServer.stub(:new).and_return(@webrick)
      @webrick.should_receive(:mount) \
        .with('/', Oaf::HTTPHandler, options).once \
        .and_return(true)
      Oaf::HTTPServer.serve options
    end

    it "should parse the request properly" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir1}
      handler.process_request req, res
      res.body.should eq("This is a test.\n")
      res.status.should eq(201)
      res.header.should eq('x-powered-by' => 'oaf')
    end

    it "should accept containable methods properly" do
      req = Oaf::FakeReq.new({:path => @f2request, :method => 'PUT'})
      res = Oaf::FakeRes.new
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir1}
      handler.process_request req, res
      res.body.should eq("Containable Test\n")
      res.status.should eq(202)
      res.header.should eq('x-powered-by' => 'oaf')
    end

    it "should respond to any HTTP method" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      Oaf::HTTPHandler.any_instance.stub(:process_request).and_return(true)
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir1}
      handler.should_receive(:process_request).with(req, res).once
      handler.respond_to?(:do_GET).should be_true
      handler.respond_to?(:do_get).should be_false
      handler.respond_to?(:nonexistent).should be_false
      handler.do_PUT(req, res)
    end

    it "should call our custom methods for built-ins" do
      req = Oaf::FakeReq.new :path => @f1request
      res = Oaf::FakeRes.new
      Oaf::HTTPHandler.any_instance.stub(:process_request).and_return(true)
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir1}
      handler.should_receive(:process_request).with(req, res).exactly(4).times
      handler.do_GET(req, res)
      handler.do_POST(req, res)
      handler.do_HEAD(req, res)
      handler.do_OPTIONS(req, res)
    end

    it "should use directory default if no higher-level script exists" do
      req = Oaf::FakeReq.new :path => @f3request
      res = Oaf::FakeRes.new
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir2}
      handler.process_request req, res
      res.body.should eq("Directory wins\n")
    end

    it "should use a file if present with a similarly-named directory" do
      req = Oaf::FakeReq.new :path => @f4request
      res = Oaf::FakeRes.new
      handler = Oaf::HTTPHandler.new Oaf::FakeServlet.new, {:path => @tempdir3}
      handler.process_request req, res
      res.body.should eq("File wins\n")
    end
  end
end
