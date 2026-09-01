# FPP - Falcon Player App for Home Assistant (Dev)

&emsp;&emsp;![Version](https://img.shields.io/badge/dynamic/json?label=Version&query=%24.upstream_version&url=https%3A%2F%2Fraw.githubusercontent.com%2Fjessica12ryan%2Ffpp-ha%2Fmaster%2Ffpp-ha-dev%2Fupdater.json)
![Update](https://img.shields.io/badge/dynamic/json?label=Updated&query=%24.last_update&url=https%3A%2F%2Fraw.githubusercontent.com%2Fjessica12ryan%2Ffpp-ha%2Fmaster%2Ffpp-ha-dev%2Fupdater.json)
![aarch64][aarch64-badge]
![amd64][amd64-badge]

[![FPP logo](https://raw.githubusercontent.com/jessica12ryan/fpp-ha/master/fpp-ha/logo.png)](https://github.com/FalconChristmas/fpp/)

> **Dev variant** — always builds the `master` branch of FalconChristmas/fpp locally on your Home Assistant host. Unlike `fpp-ha`, this add-on is **not prebuilt** (no GHCR image); it compiles from source on install/rebuild so you always get the latest `master`.

## Requirements:
- Home Assistant Operating System
- Atleast 1GB free space (minimum), 16GB recommended
- Longer initial install time (source build) and enough RAM/CPU for compilation

## Getting Started

[![Add repository to Home Assistant][repository-badge]][repository-url]

If you want to add the repository manually, please follow the procedure highlighted in the [Home Assistant website](https://home-assistant.io/hassio/installing_third_party_addons). Use the following URL to add this repository: https://github.com/jessica12ryan/fpp-ha

Then install **FPP - Falcon Player (Dev)** (`fpp-ha-dev`) from Settings > Apps.

## Installation

- After clicking install, it may take a while to build from source (10-30+ minutes depending on hardware).
- Rebuild/reinstall pulls the latest `master` again (cache busted via GitHub API ref check).
- You can open FPP by browsing to http://HA_IP or clicking the Open Web UI button.

## Dev vs Stable

| Feature | `fpp-ha` (stable) | `fpp-ha-dev` (this) |
|---|---|---|
| Image | Prebuilt GHCR `ghcr.io/jessica12ryan/{arch}-addon-fpp-ha` | Locally built (`build.yaml` + `Dockerfile`) |
| FPP ref | Tagged version (`v10.0`, etc. via workflow) | Always `master` |
| Build time | Fast (pull) | Slow (compile) |
| Updates | Via add-on version bump | Rebuild add-on to get latest master |

## Troubleshooting:
- [FPP App Repo](https://github.com/jessica12ryan/homesync-ha-apps)
- [FPP App Issues](https://github.com/jessica12ryan/homesync-ha-apps/issues)
- [FPP Repo](https://github.com/FalconChristmas/fpp)
- [FPP Issues](https://github.com/FalconChristmas/fpp/issues)
- [xLights Zoom Room](https://xlightszoomroom.com)

## Credits:
- [FalconChristmas](https://github.com/FalconChristmas/fpp) for Falcon Player (FPP)
- [jessica12ryan](https://github.com/jessica12ryan/fpp-ha) for FPP App for Home Assistant


[aarch64no-badge]: https://img.shields.io/badge/aarch64-no-red.svg
[aarch64-badge]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-badge]: https://img.shields.io/badge/amd64-yes-green.svg
[repository-badge]: https://img.shields.io/badge/Add%20repository%20to%20my-Home%20Assistant-41BDF5?logo=home-assistant&style=for-the-badge
[repository-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fjessica12ryan%2Ffpp-ha
