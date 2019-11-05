# nerves_init_gadget

[![CircleCI](https://circleci.com/gh/nerves-project/nerves_init_gadget.svg?style=svg)](https://circleci.com/gh/nerves-project/nerves_init_gadget)
[![Hex version](https://img.shields.io/hexpm/v/nerves_init_gadget.svg "Hex version")](https://hex.pm/packages/nerves_init_gadget)

This project provides the basics for getting started with Nerves. This includes
bringing up networking, over-the-air firmware updates and many other little
things that make using Nerves a little better. At some point your project may
outgrow `nerves_init_gadget` and when that happens, you can use it as an
example.

By design, this project is mostly dependencies and only a little "glue" code.
Here's a summary of what you get:

* Basic network initialization for USB gadget devices (Raspberry Pi Zero and
  Beaglebone) and wired and wireless Ethernet
* mDNS support to advertise a name like `nerves.local` or `nerves-1234.local` if
  devices have serial numbers
* Device detection, filesystem mounting, and basic device control from
  `nerves_runtime`
* Over-the-air firmware updates using `nerves_firmware_ssh`
* System clock initialization and NTP support from
  [nerves_time](https://github.com/fhunleth/nerves_time)
* Easy setup of Erlang distribution to support remsh, Observer and other debug
  and tracing tools
* Access to the IEx console via `ssh` and transfer files with `sftp`
* IEx helpers for a happier commandline experience
* Logging via [ring_logger](https://github.com/nerves-project/ring_logger)
* [shoehorn](https://github.com/nerves-project/shoehorn)-aware instructions to
  reduce the number of SDCard reprogrammings that you need to do in regular
  development.

## Installation for a new project

To modify an existing Nerves project, please see the next section.

If you haven't set up your environment for Nerves, go to the [Nerves Project
Installation instructions](https://hexdocs.pm/nerves/installation.html) and come
back.

Make sure that your Nerves archive is up-to-date. The Nerves archive contains
the new project generator:

```sh
mix local.nerves

# or if you don't have it yet
mix archive.install hex nerves_bootstrap
```

Create a new project using the generator:

```sh
mix nerves.new mygadget --init-gadget
```

The defaults should work for most people. However, it's good to check.

Open up `config/config.exs` and look for the ssh key section. If the device
doesn't have your ssh public key installed, then firmware updates and ssh
console access won't work. The default operation is to insert the contents of
`~/.ssh/id_rsa.pub`. You can add as many public keys as you'd like or copy/paste
them manually into the list. See
[nerves_firmware_ssh](https://github.com/fhunleth/nerves_firmware_ssh) for more
details.

IEx prompt access and firmware updates use completely separate modules and TCP
ports. Prompt access is via the normal `ssh` port (port 22). Firmware updates
use the `ssh` protocol but on port 8989.

The next section to review is the `nerves_init_gadget` configuration. This one
depends on the device that you're using. The most important configuration key is
`ifname`. Set that to the Ethernet interface for your device. For the Raspberry
Pi Zero and Beaglebone Black, `"usb0"` is a virtual Ethernet device going over
USB. For other boards, `"eth0"` is the wired Ethernet interface and `"wlan0"` is
the Wireless interface.

The next key is the `address_method`. It specifies how the Ethernet interface
should get its IP address. Set it as follows:

* `"usb0"` - Set to `:dhcpd` (note the `d` at the end). This assigns an IP
  address to the device and uses DHCP to give your computer an IP address for
  the other end of the cable. You can also use `:linklocal` for an IPv4
  [link-local addresses](https://en.wikipedia.org/wiki/Link-local_address) if
  you know what you're doing.
* `"eth0"` and `"wlan0"` - Set to `:dhcp` and the device will use DHCP to get
  an IP address

The configuration specified here is passed on to `nerves_network`, so consult
[its documentation](https://hexdocs.pm/nerves_network/readme.html#content) if
you'd like to configure the network in a different way.

See the [configuration](#configuration) section below for the other parameters.

Finally, run the usual Elixir and Nerves build steps:

```sh
# Modify the target name for your board. See the mix.exs for the options
export MIX_TARGET=rpi0

mix deps.get
mix firmware

# Copy the firmware to a MicroSD card (or change this to how you do the
# first-time load of software onto your device.)
mix firmware.burn
```

Since debugging ssh is particularly painful, take this opportunity to double
check the authorized key one last time.

```sh
find . -name sys.config

# This should print out the configuration that was compiled into the image. If
# you have multiple ones since you've been compiling for more than one device,
# pick the one that makes sense. The following is the one that I had:

cat ./_build/rpi0/dev/rel/mygadget/releases/0.1.0/sys.config
```

Now you should be able to boot the device and push firmware updates to it. See
the sections below for doing this and troubleshooting.

## Installation for an existing project

These instructions assume that your existing project is configured to expose a
virtual Ethernet adapter and virtual serial port on the target. The official
`nerves_system_rpi0` does this.

This project works well with
[shoehorn](https://github.com/nerves-project/shoehorn). It's not mandatory, but
it's pretty convenient since it can handle your application crashing during
development without forcing you to re-burn an SDCard. Since other instructions
assume that it's around, update your `mix.exs` deps with it too:

```elixir
def deps do
  [
    {:shoehorn, "~> 0.4"},
    {:nerves_init_gadget, "~> 0.6"}
  ]
end
```

Shoehorn requires a plugin to the
[distillery](https://github.com/bitwalker/distillery) configuration, so add it
to your `rel/config.exs` (replace `:your_app`):

```elixir
release :your_app do
  plugin Shoehorn
  ...
end
```

Now, add the following configuration to your `config/config.exs`:

```elixir
config :shoehorn,
  init: [:nerves_runtime, :nerves_init_gadget],
  app: Mix.Project.config()[:app]
```

The final configuration item is to set up authorized keys for pushing firmware
updates to the device. This is documented in more detail at
[nerves_firmware_ssh](https://github.com/fhunleth/nerves_firmware_ssh).
Basically, the device will need to know the `ssh` public keys for all of the
users that are allowed to update the firmware. Copy the contents of the
`id_rsa.pub`, etc.  files from your `~/.ssh` directory or add something like
this:

```elixir
config :nerves_firmware_ssh,
  authorized_keys: [
    File.read!(Path.join(System.user_home!, ".ssh/id_rsa.pub"))
  ]
```

The last change to the `config.exs` is to enable
[ring_logger](https://github.com/nerves-project/ring_logger). Like many aspects
of `nerves_init_gadget`, this is optional and you can use the default Elixir
logger or a logger of your choosing if you'd like.

```elixir
config :logger, backends: [RingLogger]
```

That's it! Now you can do the normal Nerves development procedure for building
and installing the image to your device:

```sh
export MIX_TARGET=rpi0  # modify if necessary

# You shouldn't need to run this line unless you skipped this step
# when running `mix nerves.new` to create your project initially.
mix nerves.release.init

mix deps.get
mix firmware
mix firmware.burn
```

## Using

Connect your device over the USB port with your computer (if using a RPi0, it is
very important to use the port labeled "USB" and not the one labeled "PWR").
Give your device a few seconds to boot and initialize the virtual Ethernet
interface going through the USB cable. On your computer, run `ping` to see that
it's working:

```sh
ping nerves.local
```

If you're using Ubuntu and `ping` doesn't work, check the Network Settings for
the `usb0` interface and set the IPv4 Method to "Link-Local Only". Depending on
your kernel settings for "Predictable Network Interface Naming", the interface
might be called `enp0s26u1u2` or some variation thereof. Be aware that the
`NetworkManager` tool may have trouble holding on to configured settings for
this network interface between unplugging and replugging.

If the network still doesn't work, check that the virtual serial port to the
device works and see the troubleshooting section.

`ssh` is used to update firmware from now on. A script is available to simplify
its invocation. Generate it by running:

```sh
mix firmware.gen.script
```

Once you have the `upload.sh` script, run it after after `mix firmware` to
update your device:

```sh
export MIX_TARGET=rpi0
./upload.sh
```

Change `MIX_TARGET` to whatever you're using to build the firmware. You can also
specify the firmware file and device hostname as parameters. Assuming the script
completes successfully, the device will reboot with the new firmware.

## Configuration

You may customize `nerves_init_gadget` using your `config.exs`:

```elixir
config :nerves_init_gadget,
  ifname: "usb0",
  address_method: :dhcpd,
  mdns_domain: "nerves.local",
  node_name: nil,
  node_host: :mdns_domain
```

The above are the defaults and should work for most users. The following
sections go into more detail on the individual options.

### `:ifname`

This sets the network interface to configure and monitor on the device. For
gadget use, this is almost aways `usb0`. If you'd like to use
`nerves_init_gadget` on a real Ethernet interface or WiFi, modify this to `eth0`
or `wlan0`. You'll probably want to change the `:address_method` to `:dhcp`. For
wireless use, you'll need to supply a default configuration to specify the SSID
to associate with. See the [`nerves_network`
docs](https://github.com/nerves-project/nerves_network#configuring-defaults) for
details.

### `:address_method`

This sets how an IP address should be assigned to the network interface. You may
specify the following:

* `:linklocal` - assign a link-local IP address
* `:dhcp` - send a DHCP discovery request on the network to get assigned an IP
  address
* `:dhcpd` - set an automatically calculated IP address and start a DHCP server
  to assign an address to the other side of the link. Names are added to
  Erlang's DNS so that you can refer to the computer on the other side of the link
  as `peer.usb0.lan`. Substitute `usb0` for the interface if yours is different.
  See [OneDHCPD](https://github.com/fhunleth/one_dhcpd).

### `:mdns_domain`

This is the mDNS name for finding the device. It defaults to `nerves.local`.
This is very convenient when there's only one device on the network.

If you don't want mDNS, set this to `nil`.

You can set this to `:hostname` and the mDNS name will be set to the
`hostname.local`. The official Nerves systems all generate semi-unique hostnames
for devices. This makes it possible to discover devices via mDNS and also to
connect to them. Note that if your network uses DHCP, Nerves lists its hostname
in the DHCP request so if your router supports it, you may be able to connect to
the device via the hostname as well.

### `:node_name`

This is the node name for Erlang distribution. If specified (non-nil),
`nerves_init_gadget` will start `epmd` and configure the node as
`:<name>@<host>`. See the next option for the `host` part.

Currently only long names are supported (i.e., no snames).

### `:node_host`

This is the host part of the node name when using Erlang distribution. You may
specify a string to use as a host name or one of the following atoms:

* `:ip` - Set the host part to `:ifname`'s assigned IP address.
* `:dhcp` - Set the host part to the host name registered by dhcp.
* `:mdns_domain` Set the host part to the value advertised by mDNS.

The default is `:mdns_domain` so that the following remsh invocation works:

```bash
iex --name me@0.0.0.0 --cookie acookie --remsh node_name@nerves.local
```

### `:ssh_console_port`

By default, `nerves_init_gadget` will start an IEx console on port 22 or
whatever port is specified with this option. The SFTP subsystem is also enabled
so that you can transfer files back and forth as well. To disable this feature,
set `:ssh_console_port` to `nil`.  This console will use the same ssh public
keys as those configured for `:nerves_firmware_ssh`. Usernames are ignored.
Connect by running:

```bash
ssh nerves.local
```

To exit the SSH session, type `~.`. This is an `ssh` escape sequence (See the
[ssh man page](https://linux.die.net/man/1/ssh) for other escape sequences).
Typing `Ctrl+D` or `logoff` at the IEx prompt to exit the session won't work.

## Troubleshooting

If things aren't working, try the following to figure out what's wrong:

1. Check that you're plugged into the right USB port on the target. The
   Raspberry Pi Zero, for example, has two USB ports but one of them is only for
   power.
2. Check that the USB cable works (some cables are power-only and don't have the
   data lines hooked up). Try connecting to the virtual serial port using
   `picocom` or `screen` to get to the IEx prompt. Depending on your host system
   the virtual serial port may be named `/dev/ttyUSB0`, `/dev/ttyACM0`, or some
   variation of that.
3. Check your host machine's Ethernet settings. You'll want to make sure that
   link-local addressing is enabled on the virtual Ethernet interface. Static
   addresses won't work. DHCP addressing should eventually work since link-local
   addressing is what happens when DHCP fails. The IP address that's assigned to
   the virtual Ethernet interface should be in the 169.254.0.0/16 subnet.
4. Reboot the target and connect over the virtual serial port as soon as it
   allows. Watch the log messages to see that an IP address is assigned to the
   virtual Ethernet port. Try pinging that directly. If nothing is assigned,
   it's possible that something is wrong with the Ethernet gadget device drivers
   but that's more advanced to debug and shouldn't be an issue if you haven't
   modified the official Nerves systems.
5. If you're having trouble with firmware updates, check out the
   [`nerves_firmware_ssh` troubleshooting steps](https://github.com/fhunleth/nerves_firmware_ssh#troubleshooting).
6. If all else fails, please file an [issue](https://github.com/fhunleth/nerves_init_gadget/issues/new)
   or try the `#nerves` channel on the [Elixir Slack](https://elixir-slackin.herokuapp.com/).
   Inevitably someone else will hit your problem too and we'd like to improve
   the experience for future users.

## FAQ

### What should I put in my config for Raspberry Pi 3 w/ wired Ethernet

Try this if you're on a DHCP-enabled network:

```elixir
config :nerves_init_gadget,
  ifname: "eth0",
  address_method: :dhcp,
  node_name: "murphy"
```

This also starts up Erlang distribution with a node name of "murphy". Get your
cookie from `rel/vm.args` (look for the `-setcookie` line) and run the following
to connect to your device:

```bash
iex --name me@0.0.0.0 --cookie acookie --remsh murphy@nerves.local
```

### How do I register a callback before the system reboots

If you need to save data or notify the user of an impending reboot or power off,
take a look at OTP's
[`Application.stop/1`](https://hexdocs.pm/elixir/Application.html#c:stop/1) and
[`Application.prep_stop/1`](https://hexdocs.pm/elixir/Application.html#c:prep_stop/1)
callbacks. Reboots and shutdowns initiated through
[`Nerves.Runtime.reboot/0`](https://hexdocs.pm/nerves_runtime/Nerves.Runtime.html#reboot/0)
or
[`Nerves.Runtime.poweroff/0`](https://hexdocs.pm/nerves_runtime/Nerves.Runtime.html#poweroff/0)
have a timer that restricts how long the OTP shut down process can take. This
prevents shutdown hangs. The timer duration is specified in
[`erlinit.config`](https://hexdocs.pm/nerves/advanced-configuration.html#overwriting-files-in-the-root-filesystem).

### Why do I see `x\360~` when I reboot

You may also see things like this:

```elixir
x\360~
** (SyntaxError) iex:4: invalid sigil delimiter: "\360" (column 3, codepoint U+00F0). The available delimiters are: //, ||, "", '', (), [], {}, <>
```

You're probably also using Linux. This is
[ModemManager](https://www.freedesktop.org/wiki/Software/ModemManager/) probing
the serial port to see if there's a modem. ModemManager prevents anything from
using the serial port until it gives up on finding a modem at the other end.
This takes a second or two and leaves junk behind at the IEx prompt.

Check out the ModemManager description to see whether this software is even
something that you want. Here's a popular solution:

```bash
sudo apt remove modemmanager
```

## License

This code is licensed under the Apache License 2.0.
