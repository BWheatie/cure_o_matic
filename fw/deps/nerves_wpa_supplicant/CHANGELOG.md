# Changelog

## v0.5.2

* Bug fixes
  * Moved C build products under the `_build` directory to avoid compilation
    errors when switching targets.

## v0.5.1

* Enhancements
  * Enable support for WPA-EAP networks. This adds the following new messages:
    * `:"CTRL-EVENT-EAP-PEER-CERT"`
    * `:"CTRL-EVENT-EAP-STATUS"`
    * `:"CTRL-EVENT-EAP-FAILURE"`
    * `:"CTRL-EVENT-EAP-METHOD"`
    * `:"CTRL-EVENT-EAP-PROPOSED-METHOD`
* Bug fixes
  * Fix `:"CTRL-EVENT-EAP-PEER-CERT"` messages causing crashes

## v0.5.0

* Enhancements
  * Expand some notifications to include contextual information. This
    is a **backwards-incompatible** change to the following message types:
    * `:"CTRL-EVENT-CONNECTED"`
    * `:"CTRL-EVENT-DISCONNECTED"`
    * `:"CTRL-EVENT-REGDOM-CHANGE"`
    * `:"CTRL-EVENT-ASSOC-REJECT"`
    * `:"CTRL-EVENT-SSID-TEMP-DISABLED"`
    * `:"CTRL-EVENT-SUBNET-STATUS-UPDATE"`
    * `:"CTRL-EVENT-SSID-REENABLED"`

## v0.4.0

* Enhancements
  * Add ability to add multiple networks at once.
* Bug fixes
  * Fix p2p messages causing crashes.

## v0.3.3

* Enhancements
  * Add ability to pass map instead of Keyword list to `setup/2`
  * Add timeout for scanning for networks

## v0.3.2

* Enhancements
  * Fix deprecation warnings for Elixir 1.5

## v0.3.1

* Enhancements
  * Support compilation on OSX. It won't work, but it's good enough for
    generating docs and pushing to hex.

* Bug fixes
  * Fixed a couple bugs when scanning for WiFi networks

## v0.3.0

* Enhancements
  * Replaced GenEvent with Registry

## v0.2.3

* Bug fixes
  * Clean up warnings for Elixir 1.4

## v0.2.2

* Bug fixes
  * Invalid network settings would crash `set_network`. Now they
    return errors, since some can originate with bad user input.
    E.g., a short password

## v0.2.1

* Bug fixes
  * Fixes from integrating with nerves_interim_wifi

## v0.2.0

Renamed from `wpa_supplicant.ex` to `nerves_wpa_supplicant``
