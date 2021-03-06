Oaf
---

Care-free web app prototyping using files and scripts

[![Gem Version](https://badge.fury.io/rb/oaf.png)](http://badge.fury.io/rb/oaf)
[![Build Status](https://travis-ci.org/ryanuber/oaf.png)](https://travis-ci.org/ryanuber/oaf)
[![Coverage Status](https://coveralls.io/repos/ryanuber/oaf/badge.png)](https://coveralls.io/r/ryanuber/oaf)
[![Code Climate](https://codeclimate.com/github/ryanuber/oaf.png)](https://codeclimate.com/github/ryanuber/oaf)

[Documentation](http://rubydoc.info/gems/oaf/frames)

`Oaf` provides stupid-easy way of creating dynamic web applications by setting
all best practices and security considerations aside until you are sure that you
want to invest your time doing so.

`Oaf` was created as a weekend project to create a small, simple HTTP server
program that uses script execution as its primary mechanism for generating
responses.

Example
-------

Create an executable file named `hello.GET`:

```
#!/bin/bash
echo "Hello, ${USER}!"
```

Start the server by running the `oaf` command, then make a request:

```
$ curl localhost:9000/hello
Hello, ryanuber!
```

Installation
------------

Oaf is available on [rubygems](http://rubygems.org/gems/oaf), which means you
can do:

```
gem install oaf
```

Basic Usage
-----------

```
SYNOPSIS:
  oaf [options] [path]

OPTIONS:
    -p, --port PORT                  Listening port. Default=9000
        --default-response FILE      Path to default response file
        --version                    Show the version number
    -h, --help                       Show this message
```

### Accepted files

`Oaf` will run *ANY* file with the executable bit set, be it shell, Python, Ruby,
compiled binary, or whatever else you might have.

`Oaf` can also use plain text files.

### How file permissions affect output

* If the file in your request is executable, the output of its execution will
  be used as the return data.
* If the file is *NOT* executable, then the contents of the file will be used
  as the return data.

### Nested methods

You can create nested methods using simple directories. Example:

```
$ ls ./examples/
hello.GET

$ curl http://localhost:8000/examples/hello
Hello, world!
```

### HTTP Methods
Files must carry the extension of the HTTP method used to invoke them.
Oaf should support any HTTP method, including custom methods.

### Headers and Status
You can indicate HTTP headers and status using stdout from your script.

```
#!/bin/bash
cat <<EOF
Hello, world!
---
content-type: text/plain
200
EOF
```

Separated by 3 dashes on a line of their own (`---`), the very last block
of output can contain headers and response status.

### Getting request headers, query parameters, and body

Headers, query parameters, and request body are all passed to executables using
the environment. To defeat overlap in variables, they are namespaced using a
prefix. The environment variables are as follows:

* Headers: `oaf_header_*`
* Request parameters: `oaf_param_*`
* Request body: `oaf_request_body`
* Request path: `oaf_request_path`

Below is a quick example of a shell script which makes use of the request data:

```
#!/bin/bash
echo "You passed the Accept header: $oaf_header_accept"
echo "You passed the 'message' value: $oaf_param_message"
echo "You passed the request body: $oaf_request_body"
echo "This method is located at: $oaf_request_path"
```

Headers query parameter names are converted to all-lowercase, and dashes are
replaced with underscores. This is due to the way the environment works. For
example, if you wanted to get at the `Content-Type` header, you could with the
environment variable `$oaf_header_content_type`.

### Catch-all methods

Catch-all's can be defined by naming a file inside of a directory, beginning and
ending with underscores (`_`). So for example, `test/_default_.GET` will match:
`GET /test/anything`, `GET /test/blah`, etc.

### Request handling priority

Direct file matches are always prioritized over catch-all methods. Take the
following directory structure as an example with the request for `/hello`:

```
.
├── hello
│   └── _default_.GET
└── hello.GET
```

In this case, the file `hello.GET` will be executed during a request to
`/hello`. If `hello.GET` did not exist, then `hello/_default_.GET` would be
executed instead. If neither existed, then the default response would be
returned.

### Default response file

If no files match a given request, Oaf must fall back to a default response to
let the end user know that nothing was found. This is typically a 404 error
page. Oaf gives you flexibility here by providing a `--default-response` command
line option. The value of this argument should be the path to a file, which can
be a script or flat text file, just like any other Oaf script, and supports the
same format and backmatter to specify HTTP response headers, status code, etc.

Q&A
---

**Why are the headers and status at the bottom of the response?**
Because it is much easier to echo these last. Since Oaf reads response
data directly from stdout/stderr, it is very easy for debug or error messages
to interfere with them. By specifying the headers and status last, we minimize
the chances of unexpected output damaging the response, as all processing is
already complete.

**Why the name `Oaf`?**
It's a bit of a clumsy and "oafish" approach at web application prototyping. I
constantly find myself trying to write server parts of programs before I have
even completed basic functionality, and sometimes even before I have a clear
idea of what it is I want the program to do.

Acknowledgements
----------------

`Oaf` is inspired by [Stubb](https://github.com/knuton/stubb). A number of ideas
and conventions were borrowed from it. Kudos to
[@knuton](https://github.com/knuton) for having a great idea.
