# Adding third-party modules to nginx official image

It's possible to extend a mainline image with third-party modules either from
your own instuctions following a simple filesystem layout/syntax using
`build_module.sh` helper script, or falling back to package sources from
[pkg-oss](https://hg.nginx.org/pkg-oss).

## Usage

```
$ docker build --build-arg ENABLED_MODULES="ndk lua" -t my-nginx-with-lua .
```
This command will attempt to build an image called `my-nginx-with-lua` based on
official nginx docker hub image with two modules: `ndk` and `lua`.
By default, a Debian-based image will be used.  If you wish to use Alpine
instead, add `-f Dockerfile.alpine` to the command line.

The build script will look for module build definition files on filesystem
directory under the same name as the module (and resulting package) and if
those are not found will try to look up requested modules in the pkg-oss
repository.

For well-known modules we maintain a set of build sources packages over at
`pkg-oss`, so it's probably a good idea to rely on those instead of providing
your own implementation.

As of the time of writing this README, the following modules and their versions
are available from `pkg-oss` repository:

```
/pkg-oss $ LC_ALL=C make -C debian list-all-modules
make: Entering directory '/pkg-oss/debian'
auth-spnego             1.1.0-1
brotli                  1.0.0-1
encrypted-session       0.08-1
fips-check              0.1-1
geoip                   1.21.0-1
geoip2                  3.3-1
headers-more            0.33-1
image-filter            1.21.0-1
lua                     0.10.19-1
modsecurity             1.0.1-2
ndk                     0.3.1-1
njs                     0.5.3-1
opentracing             0.14.0-1
passenger               6.0.8-1
perl                    1.21.0-1
rtmp                    1.2.1-1
set-misc                0.32-1
subs-filter             0.6.4-1
xslt                    1.21.0-1
make: Leaving directory '/pkg-oss/debian'
```

If you still want to provide your own instructions for a specific module,
organize the build directory in a following way, e.g. for `echo` module:

```
docker-nginx/modules $ tree echo
echo
├── build-deps
├── prebuild
└── source

0 directories, 3 files
```

The scripts expect one file to always exist for a module you wish to build
manually: `source`.  It should contain a link to a zip/tarball source code of a
module you want to build.  In `build-deps` you can specify build dependencies
for a module as found in Debian or Alpine repositories.  `prebuild` is a shell
script (make it `chmod +x prebuild`!) that will be executed prior to building
the module but after installing the dependencies, so it can be used to install
additional build dependencies if they are not available from Debian or Alpine.
Keep in mind that those dependencies wont be automatically copied to the
resulting image and if you're building a library, build it statically.

Once the build is done in the builder image, the built packages are copied over
to resulting image and installed via apt/apk.  The resulting image will be
tagged and can be used the same way as an official docker hub image.

Note that we can not provide any support for those modifications and in no way
guarantee they will work as nice as a build without third-party modules.  If
you encounter any issues running your image with the modules enabled, please
reproduce with a vanilla image first.

## Examples

### docker-compose with pre-packaged modules

If desired modules are already packaged in
[pkg-oss](https://hg.nginx.org/pkg-oss/) - e.g. `debian/Makefile.module-*`
exists for a given module, you can use this example.

1. Create a directory for your project:

```
mkdir myapp
cd myapp
````

2.  Populate the build context for a custom nginx image:

```
mkdir my-nginx
curl -o my-nginx/Dockerfile https://raw.githubusercontent.com/nginxinc/docker-nginx/master/modules/Dockerfile
```

3. Create a `docker-compose.yml` file:

```
cat > docker-compose.yml << __EOF__
version: "3.3"
services:
  web:
    build:
      context: ./my-nginx/
      args:
        ENABLED_MODULES: ndk lua
    image: my-nginx-with-lua:v1
    ports:
      - "80:8000"
__EOF__
```

Now, running `docker-compose up --build -d` will build the image and run the application for you.

### docker-compose with a non-packaged module

If a needed module is not available via `pkg-oss`, you can use this example.

We're going to build the image with [ngx_cache_purge](https://github.com/FRiCKLE/ngx_cache_purge) module.

The steps are similar to a previous example, with a notable difference of
providing a URL to fetch the module source code from.

1. Create a directory for your project:

```
mkdir myapp-cache
cd myapp-cache
````

2.  Populate the build context for a custom nginx image:

```
mkdir my-nginx
curl -o my-nginx/Dockerfile https://raw.githubusercontent.com/nginxinc/docker-nginx/master/modules/Dockerfile
mkdir my-nginx/cachepurge
echo "https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz" > my-nginx/cachepurge/source
```

3. Create a `docker-compose.yml` file:

```
cat > docker-compose.yml << __EOF__
version: "3.3"
services:
  web:
    build:
      context: ./my-nginx/
      args:
        ENABLED_MODULES: cachepurge
    image: my-nginx-with-cachepurge:v1
    ports:
      - "80:8080"
__EOF__
```

Now, running `docker-compose up --build -d` will build the image and run the application for you.
