# Passenger Binary Builder Automation System

This repository contains scripts for automating the building of Linux and OS X binaries for [Phusion Passenger](https://www.phusionpassenger.com/). The goal is for us (Phusion) to setup an automated build infrastructure so that every Phusion Passenger release comes with binaries that work for most users. These binaries are built immediately after we push a tag a Github, to minimize the release delay between source code and binaries. Once this infrastructure is in place, most users should never have to compile by themselves again, saving precious time and resources. If you are security minded, then you may want to run this infrastructure on your internal network instead of using our binaries.

The built binaries are signed with GPG and are stored on https://oss-binaries.phusionpassenger.com/. The key used for signing is "auto-software-signing@phusion.nl", key ID 561F9B9CAC40B2F7, fingerprint 1637 8A33 A6EF 1676 2922 526E 561F 9B9C AC40 B2F7.

## Linux

On Linux, passenger_autobuilder provides a build environment that is built with pbuilder. The build environment is based on Ubuntu 10.04 and is custom-built to be able to generate Linux binaries that can run on a wide range of Linux distributions. Why Ubuntu 10.04? [Read this comment.](http://www.reddit.com/r/ruby/comments/1jyazd/phusion_passenger_binary_building_automation/cbjiydc)

Because building binaries involves running build systems that may execute arbitrary code, passenger_autobuilder utilizes multiple user accounts, plus the use of sudo, to protect against build systems wrecking havoc on the system. See the "Local security" section for more information.

passenger_autobuilder must be run on a 64-bit Ubuntu system. It builds x86 and x86-64 binaries. All dependencies besides glibc are statically linked into the produced binaries. The latest glibc symbol version that the produced binaries utilize is `GLIBC_2.11`, which should make the binaries compatible with all Linux distributions starting from 2009. This includes Ubuntu >= 10.04, Debian >= 6 and Red Hat >= 6.

passenger_autobuilder generates binaries for:

 * The Phusion Passenger support files (e.g. the agent executables).
 * Apache modules built against multiple versions of Apache: 2.0, 2.2, 2.4
 * Phusion Passenger Ruby extensions built against multiple versions of Ruby: 1.8.7, 1.9.2, 1.9.3, 2.0.0
 * Nginx.

The Nginx version that will be compiled is the version preferred by the Phusion Passenger codebase. It includes the following modules:

 * `http_ssl_module`
 * `http_spdy_module`
 * `http_gzip_static_module`
 * `http_proxy_module`
 * `http_fastcgi_module`
 * `http_scgi_module`
 * `http_uwsgi_module`
 * `http_status_stub_module`
 * `http_addition_module`
 * `http_geoip_module`

The Nginx binary is built with prefix `/tmp` which will make it store log files, proxy_module buffer files, etc in `/tmp` by default. Such a prefix has the useful property of working on almost any system, but this prefix should not be used in production because of potential security issues. To solve this, you must there run the Nginx binary with the `-p` option to force it to use a different prefix (e.g. `-p /opt/local/nginx`).

passenger_autobuilder can optionally be configured to sign the built binaries using GPG, either by running GPG locally or by forwarding the data through SSH to a remote host for signing. The latter approach provides additional security: in case the build host is compromised, the signing key is not.

### Requirements

 * A 64-bit kernel
 * git

### Getting started

Run the following commands to install passenger_autobuilder:

    sudo mkdir /srv/passenger_autobuilder
    sudo git clone https://github.com/phusion/passenger_autobuilder.git /srv/passenger_autobuilder/app
    cd /srv/passenger_autobuilder/app
    sudo ./setup-system
    sudo ./setup-images
    sudo -u psg_autobuilder_run -H s3cmd --configure
    sudo -u psg_autobuilder_chroot -H s3cmd --configure

### Building binaries

To build binaries for the latest git commit, run the following as `psg_autobuilder_run`. It will call sudo automatically (because it needs to invoke pbuilder).

    ./autobuild-with-pbuilder <GIT_URL> <NAME>

Build output will be stored in `/srv/passenger_autobuilder/output/<NAME>`. For example, you can run:

    ./autobuild-with-pbuilder https://github.com/phusion/passenger.git passenger

To build binaries for a tag (a release), add the `--tag=...` option, like this:

    ./autobuild-with-pbuilder https://github.com/phusion/passenger.git passenger --tag=release-4.0.6

### Updating passenger_autobuilder itself

    cd /srv/passenger_autobuilder/app
    sudo -u psg_autobuilder git pull
    sudo ./setup-system

Sometimes the images have changed drastically, and need to be rebuilt. In that case, also run:

    sudo rm -rf ../images
    sudo ./setup-system
    sudo ./setup-images

### Local security

passenger_autobuilder uses multiple user accounts to ensure security. The following users exist, and their roles are as follows:

 * `psg_autobuilder` is the owner of the passenger autobuilder source files (i.e. the files in the `passenger_autobuilder` git repository) and has read-write access to these files. This user is only used for updating passenger autobuilder itself, not for anything else.
 * `psg_autobuilder_run` is the user that invokes `./autobuild-with-pbuilder`. Internally, `./autobuild-with-pbuilder` invokes pbuilder to run the actual build process. After the build process is finished, it signs the build products.

   The `psg_autobuilder_run` user has the following rights:

    * Read-only access to the passenger autobuilder source files.
    * Read-write access to the output directory in which built binaries are stored, so that it can sign files.
    * Passwordless sudo access to run a specific form of the `pbuilder` command, in order to start the build process. For details, see sudoers.conf. The reason why this is necessary is because pbuilder calls chroot(), which is only possible with root privileges.
    * Read-write access to a directory in which it stores a summary of the build results.

 * `psg_autobuilder_chroot` is the user that runs inside the pbuilder chroot jail to build binaries. This user has the following rights:

    * Read-only access to the passenger autobuilder source files.
    * Read-write access to the output directory in which built binaries are stored.
    * Read-write access to the ccache directory.
    * Read-write access to a directory in which it stores a summary of the build results.

The most dangerous part of the setup is probably the part where `./autobuilder-with-pbuilder` calls sudo. By ensuring that `psg_autobuilder_run` and `psg_autobuilder_chroot` only have read-only access to the passenger autobuilder source files, and by locking down the sudo policy, we prevent the system from being able to gain arbitrary root privileges.

The PGP signing key can be secured by means of a signing server. See signing_configuration.example for more information.

## OS X

On OS X, passenger autobuilder provides a build environment for generating binaries compatible with OS X 10.7 (Lion) and beyond. Only x86_64 binaries are supported. Unlike the Linux version, the OS X version does not use multiple user accounts. OS X does not have convenient facilities to run things under multiple user accounts like other Unices do. Technically OS X can do this but its tooling is very very sucky, so we don't bother. The OS X version is designed to be run from an OS X desktop or laptop, since the availability of cheap OS X servers is problematic, to say the least.

passenger_autobuilder generates binaries for:

 * The Phusion Passenger support files (e.g. the agent executables).
 * Nginx.

The Nginx version that will be compiled is the version preferred by the Phusion Passenger codebase. It includes the following modules:

 * `http_ssl_module`
 * `http_spdy_module`
 * `http_gzip_static_module`
 * `http_proxy_module`
 * `http_fastcgi_module`
 * `http_scgi_module`
 * `http_uwsgi_module`
 * `http_status_stub_module`
 * `http_addition_module`

The Nginx binary is built with prefix `/tmp` which will make it store log files, proxy_module buffer files, etc in `/tmp` by default. Such a prefix has the useful property of working on almost any system, but this prefix should not be used in production because of potential security issues. To solve this, you must there run the Nginx binary with the `-p` option to force it to use a different prefix (e.g. `-p /opt/local/nginx`).

### Requirements

 * All Phusion Passenger dependencies.
 * The OS X 10.7 SDK.
 * RVM installed in single-user mode.
 * Ruby 2.0.0 installed via RVM.
 * git

### Getting started

Run the following command to create the build environment:

    ./setup-libraries-osx

### Building binaries

Running the following command will generate binaries for the latest commit, sign them with auto-software-sigining@phusion.nl and upload them to a remote server. The remote server is assumed to have passenger_autobuilder installed.

    ./autobuild-osx https://github.com/phusion/passenger.git passenger psg_autobuilder_chroot@yourserver.com

## Maintenance

Over time, there will be a lot of `by_commit` subdirectories that don't have a reference from `by_date` or `by_release`. You can clean them up with the `cleanup_commits` script.

Linux (run as `psg_autobuilder_run`):

    ./cleanup_commits /srv/passenger_autobuilder/output/passenger

OS X:

    ./cleanup_commits osx/output/passenger
