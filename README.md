# Getting started

Setup users and clone the repository.

    sudo addgroup --gid 2456 passenger_autobuilder
    sudo adduser --uid 2456 --gid 2456 --disabled-password --gecos "Passenger Autobuilder" passenger_autobuilder
    sudo mkdir /srv/passenger_autobuilder
    sudo chown passenger_autobuilder:passenger_autobuilder /srv/passenger_autobuilder
    cd /srv/passenger_autobuilder
    sudo -H -u passenger_autobuilder git clone https://github.com/phusion/passenger_autobuilder.git .
    sudo ./setup

## Build binaries

    sudo ./autobuild-with-pbuilder https://github.com/FooBarWidget/passenger.git passenger
