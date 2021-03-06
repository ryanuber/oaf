require 'spec_helper'

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
      result.should eq('x-powered-by' => 'oaf')
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

  describe "Argument Sanitizers" do
    it "should replace dashes with underscores in key names" do
      result = Oaf::Util.prepare_key 'header', 'x-powered-by'
      result.should eq('oaf_header_x_powered_by')
    end

    it "should convert all letters to lowercase in key names" do
      result = Oaf::Util.prepare_key 'header', 'X-Powered-By'
      result.should eq('oaf_header_x_powered_by')
    end

    it "should flatten a hash into a string" do
      result = Oaf::Util.flatten('item1' => 'value1')
      result.should eq('item1value1')
    end

    it "should flatten hashes recursively into a string" do
      result = Oaf::Util.flatten({'one' => {'two' => {'three' => 'four'}}})
      result.should eq('onetwothreefour')
    end

    it "should flatten an array of multiple values" do
      result = Oaf::Util.flatten(['one', 'two'])
      result.should eq('onetwo')
    end

    it "should flatten arrays of multiple values recursively" do
      result = Oaf::Util.flatten(['one', ['two', 'three', ['four']]])
      result.should eq('onetwothreefour')
    end

    it "should not modify strings" do
      result = Oaf::Util.flatten 'oaf'
      result.should eq('oaf')
    end

    it "should flatten unknown object types into empty strings" do
      result = Oaf::Util.flatten true
      result.should eq('')
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

    it "should only consume metadata after the known delimiter" do
      text = ['hello',  'x-powered-by: oaf', '', '', '200', 'test'].join "\n"
      headers, status, size = Oaf::Util.parse_http_meta text
      size.should eq(0)
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
      @tempdir3 = Dir.mktmpdir

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
      Dir.delete @tempdir3
    end

    it "should find existing files correctly" do
      result = Oaf::Util.get_request_file @tempdir1, @f1request, 'GET'
      result.should eq(@f1.path)
    end

    it "should return the fall-through file if request file doesn't exist" do
      result = Oaf::Util.get_request_file @tempdir1, 'na', 'GET'
      result.should eq(@f2.path)
    end

    it "should return a custom default if configured" do
      result = Oaf::Util.get_request_file @tempdir3, 'na', 'GET', @f1.path
      result.should eq(@f1.path)
    end

    it "should still return the fall-through if default doesn't exist" do
      result = Oaf::Util.get_request_file @tempdir3, 'na', 'GET', '/n0n3x1st3nt'
      result.should eq(nil)
    end

    it "should return nil if neither the requested or default file exist" do
      result = Oaf::Util.get_request_file @tempdir2, 'na', 'GET'
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

      @f3 = Tempfile.new 'oaf'
      @f3.chmod 0755
      @f3.write "#!/bin/bash\necho 'test1'\necho 'test2' 1>&2\n"
      @f3.close

      @f4 = Tempfile.new 'oaf'
      @f4.chmod 0755
      @f4.write "#!/bin/bash\necho \"$oaf_header_x_powered_by\"\n" +
                "echo \"$oaf_param_myparam\"\necho \"$oaf_request_body\"\n" +
                "echo \"$oaf_request_path\""
      @f4.close

      @tempdir1 = Dir.mktmpdir
      @tempdir2 = File.join @tempdir1, 'sub'
      Dir.mkdir @tempdir2
      @f5 = Tempfile.new 'oaf', @tempdir2
      @f5.chmod 0755
      @f5.write "#!/bin/bash\npwd"
      @f5.close
    end

    after(:all) do
      @f1.delete
      @f2.delete
      @f3.delete
      @f4.delete
    end

    it "should execute a file if it is executable" do
      result = Oaf::Util.get_output @f1.path
      result.should eq("This is a test\n")
    end

    it "should read file contents if it is not executable" do
      result = Oaf::Util.get_output @f2.path
      result.should eq("This is a test\n")
    end

    it "should assume safe defaults if the file doesnt exist" do
      result = Oaf::Util.get_output nil
      result.should eq(Oaf::Util.get_default_response)
    end

    it "should catch stderr output instead of dumping it" do
      result = Oaf::Util.get_output @f3.path
      result.should eq("test1\ntest2\n")
    end

    it "should register environment variables for headers, query, and body" do
      headers = {'x-powered-by' => 'oaf'}
      params = {'myparam' => 'myval'}
      body = 'Test Body'
      path = '/test/path'
      result = Oaf::Util.get_output @f4.path, path, headers, body, params
      result.should eq("#{headers['x-powered-by']}\n#{params['myparam']}\n" +
                       "#{body}\n#{path}\n")
    end

    it "should chdir to the directory containing the script" do
      result = Oaf::Util.get_output @f5.path
      # If the temp dir is a symlink, we don't know about that here. Just
      # compare the basename instead.
      File.basename(result).should eq("#{File.basename(@tempdir2)}\n")
    end

    it "should error if the passed path does not exist" do
      # /nonexistent exists occasionally on Travis CI, so use a weird directory
      result = Oaf::Util.run_buffered '/n0n3x1st3nt', {}, ''
      result.should eq("No such file or directory - /n0n3x1st3nt")
    end
  end
end
