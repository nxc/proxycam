## Introduction

__Proxycam__ is a containerized solution that provides a reverse proxy for
authorized access to video surveillance cameras. Incoming requests are
authorized using JWT bearer authentication. After successful authentication,
information from JWT claims is used at authorization stage to verify whether
the requester is allowed to access the reclaimed camera location. If so, the
proxy signs the request using digest authentication and routes it to its
destination. Credentials for each camera are kept in an internal database;
the requesting party is not required to have any knowledge of these.

The database is mapped to a text file on the hosting machine. Any changes in
this file are mapped back to the database in the real time, so that adding a
new camera or removing an existing one does not require any additional manual
intervention, aside from changing a line in the file that describes it.

This document discusses in detail how to install and maintain __proxycam__.

## Overview

The solution consists of two containers: a proxy itself and a Redis database
whose purpose is to keep session information. A docker composer framework is
provided that allows the user to get the system running with minimal effort.
The solution can be used both as a standalone server accessible via HTTPS, or
behind a proxy.

To start the __proxycam__ system, you will need the following software:

* Docker, 28.3.1 or later.
* Docker Compose plugin, 2.23.0 or later.
* Docker Buildx plugin, 0.29.1 or later.
* GNU make.

## Installation

First, clone the repository:

```shell
git clone git@gitlab.norse.digital:sep/proxycam.git
```

*[Editorial: For the moment, the URL is to my private workspace. It will
be changed when published.]*

After cloning, you will get the directory with the following content:

```
GNUmakefile
docker/
docker-compose.yml
syslog.yml
```

To begin with, run `make`. This will build the container images that the
system is going to use.

Now, create the file `.env`, which will contain definitions of several
configuration variables.  First, you will need `JWKS_JSON` variable,
which declares the URL from which the RSA public key for verifying JWT
tokens can be retrieved.

Another setting required prior to starting the system up, provides a
mapping to the directory on the hosting file system where the
proxy will look for a list of cameras to use. To set it up, select the
location suitable for the purpose, and define the variable
`NEWCONFIG_DIRECTORY` to the selected pathname. For example, assuming you
keep your configuration in directory `/usr/local/etc/proxycam`,
your `.env` will contain the following:

```
NEWCONFIG_DIRECTORY=/usr/local/etc/proxycam
```

The directory will be created, if it doesn't exist already.

Alternatively, you may create the `newconfig` volume using docker compose,
as covered in the [Configuration](#user-content-Configuration) section below.

If you plan to make __proxycam__ available via HTTPS, add the following
settings:

```
PROXYCAM_HTTP_PORT=80
PROXYCAM_HTTPS_PORT=443
PROXYCAM_TLS=DOMAIN
```

The purpose of the first two is obvious. The last one defines the domain name
under which the system will be known and for which TLS certificate will be
maintained. Refer to [TLS Setup](#user-content-tls-setup), for a detailed
discussion of these and related settings.

Logging is yet another thing to take care of prior to starting is . By default,
both containers will use the standard docker driver. The configuration provides
an easy way to send the logs to your `syslog` server, if you prefer so. First,
ensure your `syslog` is listening on port 514 [(1)](#user-content-syslog), then
initialize the variable `PIES_SYSLOG_SERVER'`in your `.env` file to the IP
address it is listening on. See [Environment](#user-content-environment) for
more information on this and related settings.

The last, optional step is to provide a list of accessible cameras in a
file with `.spec` suffix in your `newconfig` directory. See [Camera
Specification File](#user-content-camera-specification-file), for a detailed
discussion of this file. This step is optional, and you can postpone it
until a later time, as the cameras can be added or removed on the fly.

When everything is ready, type

```
make up
```

Once the system is up, examine its status by running `make ps`. If everything
worked right, you will see the following output:

```
NAME                  IMAGE               COMMAND                  SERVICE    CREATED         STATUS         PORTS
proxycam-proxycam-1   proxycam-proxycam   "/pies/conf/rc"          proxycam   4 seconds ago   Up 2 seconds   8073/tcp, 127.0.0.1:9090->80/tcp, 8080/tcp
proxycam-redis-1      redis:8.4.0         "docker-entrypoint.s|"   redis      4 seconds ago   Up 2 seconds   6379/tcp
```

(depending on your setup, some minor details may differ).

Let's inspect the logs of the proxy:

```
$ make proxylog
proxycam-proxycam-1  | /pies/sbin/pies: GNU pies 1.8.93 starting
proxycam-proxycam-1  | direvent: [INFO] direvent 5.2 started
proxycam-proxycam-1  | Waiting for redis:6379 to become available
proxycam-proxycam-1  | OK redis:6379
proxycam-proxycam-1  | Configured cameras:
proxycam-proxycam-1  |
proxycam-proxycam-1  | End of list
```

Now, you can add cameras.

## Camera Specification File

The system looks for surveillance camera definitions in files with names
ending with `.spec`, which are located in your `newconfig` directory. You
can have as many such files as you want, or just keep all definitions in
a single file, for simplicity. For the sake of the discussion below, we will
suppose you have one file, named `camera.spec`.

A `spec` file is a plaintext file with a simple line-oriented format. Empty
lines are ignored. Comments are introduced with a `#` sign at the start
of a line (leading whitespace allowed), and are ignored as well. The rest
of lines are taken to be camera definitions. A camera definition consists
of two to four fields, separated with any amount of horizontal whitespace.
The fields are as follows:

* Camera ID

  Defines a symbolic name used to uniquely identify the camera. The
  frontend will send this identifier in JWT claims to access that camera.
  The name may consist of arbitrary ASCII characters, excepting whitespace
  and control ones.

* Camera URL

  The URL of the camera.  It must contain all the required parts prescribed
  by RFC 2616, plus the access credentials, i.e. username and password.
  E.g.:

    ```
    http://smith:guessMe@192.0.10.1:1189
    https://foo:quu34-BAR@somehostname.com
    ```

  Missing port will be resolved in accordance to the scheme: 80 for `http`,
  and 443, for `https`. If a camera is using HTTPS, specify its hostname,
  not the IP, so the SNI will work.

* Camera IP [optional]

  IP address of the camera. Use this if you specify URL as symbolic host
  name (as in the `https` example above), to avoid DNS lookups.

* Port [optional]

  Port number the camera is listening on. Use this if you specify URL as
  symbolic host name and for some reason cannot specify port in it.

As an example, let's assume you edit your `cameras.spec` file as follows:

```
# CamID		URL
Front		http://smith:guessMe@192.0.2.10:1101
Back		http://foo:barMe@192.0.2.25:8085
Fullview	http://quux:baz-11-BEnam@10.10.1.125:1100
```

Save your edits. Wait for about 5 seconds for the changes to take effect
(the delay is introduced to avoid series of reconfigurations if several
files are changed in short intervals). Now, run `make proxylog` to inspect
the logs. You will see the following:

```
proxycam-proxycam-1  | Configured cameras:
proxycam-proxycam-1  | "camera:Back" active http 192.0.2.25:8085 alive
proxycam-proxycam-1  | "camera:Front" active http 192.0.2.10:1101 alive
proxycam-proxycam-1  | "camera:Fullview" active http 10.10.1.125:1100 alive
proxycam-proxycam-1  |
proxycam-proxycam-1  | End of list
```

The parts of the listing for each camera are:

1. Camera ID, prefixed with `Camera:`, in double-quotes.
2. Camera configuration status: `active` or `disabled`.
3. Protocol used: `http` or `https`.
4. IP address and port.
5. Camera backend status: `alive` if it is accessible, and `dead`, if it is not.

Similarly, to change camera settings or to remove it, just open that file,
edit it to your liking and save your changes.

## TLS Setup

To start the system as a standalone server and make it available via HTTPS,
the following settings should be added to the `.env` file:

```
PROXYCAM_HTTP_PORT=80
PROXYCAM_HTTPS_PORT=443
PROXYCAM_TLS=DOMAIN [DOMAIN...]
```

The first two define the ports to bind to. The `PROXYCAM_TLS` setting
declares one or more domain names, under which this system is to be known.
After startup, __proxycam__ will contact *LetsEncrypt* to issue certificates
for each domain name listed in `PROXYCAM_TLS`. The certificates will be
maintained, by re-issuing them in due time: the maintenance script will wake
up two days prior to expiry of the certificate.

In order to make sure that restarting the containers won't trigger certificate
re-issuing, they are kept on the host machine, in docker volume named
`proxycam_crt`. If you wish, you can instruct __proxycam__ to use a
local directory of your choice for that purpose. To do so, define the
variable `CRT_DIRECTORY` to the absolute pathname of that directory.

## Make Commands

In previous sections we have introduced a couple of most often used management
commands. Here is the full list of available commands in lexicographic order.

* `make build`

  Builds the containers. This command is assumed if `make` is run without
  arguments.

* `make config`

  Show the resulting configuration as one YAML file, without actually running
  anything.
  
* `make down`

  Stop both containers.
  
* `logs`

  Show logs of both containers.
  
* `proxylog`

  Show logs of the __proxycam__ container.

* `ps`

  List running containers.
  
* `restart`

  Restart the running containers.

* `up`

  Start up the system.

## Environment

This section lists all variables in the `.env` file that affect the behavior
of __proxycam__:

* `JWKS_JSON=`*URL*

  The URL where to obtain the RSA public key for JWT verification.

* `NEWCONFIG_DIRECTORY=`*DIR*

  Directory on the host file system where to look for camera specification
  files - the files with filename suffix `.spec` that contain camera
  definitions.

* `PIES_SYSLOG_SERVER=`*IPADDR*

  IP address of the syslog server. Defining this variable alone is enough
  to configure both containers and all programs in the proxycam container
  to send their logs to a remote syslog server.

* `PROXYCAM_HTTP_PORT=`[*IP*:]*PORT*

  IP address and port number on which the proxy container will listen for
  plain HTTP requests. The default is `127.0.0.1:9080`.

* `PROXYCAM_HTTPS_PORT=`[*IP*:]*PORT*

  IP address and port number on which the proxy container will listen for
  HTTPS requests. The default is `127.0.0.1:9443`.

* `PROXYCAM_TLS=`*DOMAIN* [*DOMAIN*...]

  A domain name (or a whitespace-delimited list of domain names), under which
  the system will be available via HTTPS. Certificates for each domain name
  will be issued via *LetsEncrypt*.

* `PROXYCAM_ACME_TEST`=*BOOL*

  If set to `true`, `yes`, `on`, or `1`, this variable instructs __proxycam__
  to use *LetsEncrypt* stage server for maintaining certificates. This is
  for debugging. Don't use it on production.

* `SYSLOG_SOCKET=`*URL*

  When set, diverts container logs to the given syslog URL.
  Setting this variable alone does not affect logging setup for
  programs in the _proxycam_ container. These continue to log to
  stdout/stderr; their output will be picked up by the docker
  driver and sent to syslog along with the rest of output. Comparing
  to using `PIES_SYSLOG_SERVER`, this has a drawback that messages
  from specific programs will not be tagged with their names and PIDs.
  Therefore, setting `PIES_SYSLOG_SERVER` is recommended.

  When both variables are initialized, `SYSLOG_SOCKET` controls
  container logs, and `PIES_SYSLOG_SERVER` those of utilities in
  _proxycam_.

* `SYSLOG_FACILITY=`*NAME*

  Defines syslog facility to use for container logs, instead of
  the default `local0`.

## Configuration

The main `docker-compose.yml` file was designed in such a way as to allow for
a wide variety of possible configurations. Most configuration settings are
supplied via environment variables in the `.env` file, as described above.
If that is not enough, or if you prefer to configure everything manually,
you can do so by creating the file named `docker-compose.override.yml` and
placing your overrides there.

## Notes

### syslog

Configuring your `syslog` for remote receiving is beyond the scope of this
document. Just as a hint, for `rsyslog`, which seems to be the most commonly
used implementation nowadays, it is done using the following two statements
in its configuration file:

```
module(load="imudp")
input(type="imudp" port="514")
```

Refer to your syslog documentation for more info.

