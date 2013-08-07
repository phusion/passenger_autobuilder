# Passenger Binary Builder Automation System

This repository contains scripts for automating the building of Linux binaries for [Phusion Passenger](https://www.phusionpassenger.com/). It provides a build environment that is built with pbuilder. The build environment is based on Ubuntu 10.04 and is custom-built to be able to generate Linux binaries that can run on a wide range of Linux distributions.

Because building binaries involves running build systems that may execute arbitrary code, passenger_autobuilder utilizes multiple user accounts, plus the use of sudo, to protect against build systems wrecking havoc on the system.

passenger_autobuilder must be run on a 64-bit Debian-compatible system. It builds x86 and x86-64 binaries. All dependencies besides glibc are statically linked into the produced binaries. The latest glibc symbol version that the produced binaries utilize is `GLIBC_2.11`, which should make the binaries compatible with all Linux distributions starting from 2009. This includes Ubuntu >= 10.04, Debian >= 6 and Red Hat >= 6.

Binaries for Nginx are also generated. The Nginx version that will be compiled is the version preferred by the Phusion Passenger codebase. It includes the following modules:

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

## Requirements

 * A 64-bit kernel
 * `apt-get install pbuilder`
 * `apt-get install sudo`

## Getting started

Run the following commands to install passenger_autobuilder:

    sudo mkdir /srv/passenger_autobuilder
    sudo git clone https://github.com/phusion/passenger_autobuilder.git /srv/passenger_autobuilder/app
    cd /srv/passenger_autobuilder/app
    sudo ./setup-system
    sudo ./setup-images

## Building binaries

To build binaries for the latest git commit, run the following as `psg_autobuilder_run`. It will call sudo automatically (because it needs to invoke pbuilder).

    ./autobuild-with-pbuilder <GIT_URL> <NAME>

Build output will be stored in `/srv/passenger_autobuilder/output/<NAME>`. For example, you can run:

    ./autobuild-with-pbuilder https://github.com/FooBarWidget/passenger.git passenger

To build binaries for a tag (a release), add the `--tag=...` option, like this:

    ./autobuild-with-pbuilder https://github.com/FooBarWidget/passenger.git passenger --tag=release-4.0.6

## Updating passenger_autobuilder itself

    cd /srv/passenger_autobuilder/app
    sudo -u psg_autobuilder git pull
    sudo ./setup-system

Sometimes the images have changed drastically, and need to be rebuilt. In that case, also run:

    sudo rm -rf ../images
    sudo ./setup-system
    sudo ./setup-images

## Security

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
