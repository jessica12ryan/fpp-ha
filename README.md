# FPP - Falcon Player App for Home Assistant
> **Home Assistant App for [Falcon Player (FPP)](https://github.com/FalconChristmas/fpp)**

&emsp;&emsp;![Version](https://img.shields.io/badge/dynamic/yaml?label=Version&query=%24.upstream_version&url=https%3A%2F%2Fraw.githubusercontent.com%2Fjessica12ryan%2Ffpp-ha%2Fmaster%2Ffpp-ha%2Fupdater.json)
![Update](https://img.shields.io/badge/dynamic/json?label=Updated&query=%24.last_update&url=https%3A%2F%2Fraw.githubusercontent.com%2Fjessica12ryan%2Ffpp-ha%2Fmaster%2Ffpp-ha%2Fupdater.json)
![aarch64][aarch64-badge]
![amd64][amd64-badge]

[![FPP logo](https://raw.githubusercontent.com/jessica12ryan/fpp-ha/master/fpp-ha/logo.png)](https://github.com/FalconChristmas/fpp/)

FPP-HA currently uses the master branch of FPP which contains the unstable version of FPP 10. Once FPP 10 is released, we will switch to stable builds.

FPP-HA is not officially supported by the FalconChristmas/FPP team. All issues from this installation should be logged to THIS repo. We will test and confirm whether the issue is isolated to our repo, and recreate the ticket on the FPP repo if necessary. The FPP team will not respond to any issues from this installation.

---

## Getting Started

[![Add repository to Home Assistant][repository-badge]][repository-url]

If you want to add the repository manually, please follow the procedure highlighted in the [Home Assistant website](https://home-assistant.io/hassio/installing_third_party_addons). Use the following URL to add this repository: https://github.com/jessica12ryan/fpp-ha

## Installation

- After clicking install, it may take several minutes to download, compile, and install FPP. If you refresh or browse to another page, the app will continue downloading. The app page will appear in your app list when the app has been successfully installed.
- You can open FPP by browsing to http://HA_IP or clicking the Open Web UI button.

## More Info

For more information, check the included app documentation.


[aarch64no-badge]: https://img.shields.io/badge/aarch64-no-red.svg
[aarch64-badge]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-badge]: https://img.shields.io/badge/amd64-yes-green.svg
[repository-badge]: https://img.shields.io/badge/Add%20repository%20to%20my-Home%20Assistant-41BDF5?logo=home-assistant&style=for-the-badge
[repository-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fjessica12ryan%2Ffpp-ha
