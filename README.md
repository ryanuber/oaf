Oaf
---

Care-free web app prototyping using files and scripts

[![Gem Version](https://badge.fury.io/rb/oaf.png)](http://badge.fury.io/rb/oaf)
[![Build Status](https://travis-ci.org/ryanuber/oaf.png)](https://travis-ci.org/ryanuber/oaf)

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
Files must carry the extension of the HTTP method used to invoke them. Some
examples: `hello.GET`, `hello.POST`, `hello.PUT`, `hello.DELETE`

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

Separated by 3 dashes on a line of their own (`\n---\n`), the very last block
of output can contain headers and response status.

### Getting request headers and body
The headers and body of the HTTP request will be passed to the script as
arguments. The headers will be passed as $1, and the body as $2.

### Catch-all methods
Catch-all's can be defined by naming a file inside of a directory, beginning and
ending with underscores (`_`). So for example, `test/_default_.GET` will match:
`GET /test/anything`, `GET /test/blah`, etc.

If you want to define a top-level method for `/test`, you would do so in the
file at `/test.GET`.

### Requirements
There aren't any really. Oaf currently uses WEBrick since it was the most built-
in web server implementation in ruby.

If you want to run the tests you can do so with:

Ruby 1.8.x:
- rspec
- rcov

Ruby 1.9.x:
- rspec
- simplecov

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
