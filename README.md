# libloader
``libloader`` is an attempt to make a package manager for Garry's Mod. \
All packages are searched on GitHub, in open source repositories.

![showcase](./assets/showcase.png)

*join us on discord!*\
<a href="https://discord.gg/HspPfVkHGh">
  <img src="https://discordapp.com/api/guilds/1161025351099625625/widget.png?style=shield">
</a>

# Table of contents
* [Official available libraries](#official-available-libraries)
* [Installation](#installation)
* [Usage](#usage)
  * [Installation](#library-installation)
  * [Library enabling](#library-enabling)
  * [Library disabling](#library-disabling)
  * [Library removing](#library-removing)
* [For developers](#for-developers)

# Official available libraries
* [@autumngmod/cream](https://github.com/autumngmod/cream) - Web based UI (React/Vue/etc) in Garry's Mod
* [@autumngmod/binloader](https://github.com/autumngmod/binloader) - Auto ``DLL`` module loader
* [@autumngmod/workyaround](https://github.com/autumngmod/workyaround) - Creates a data/worky folder whose contents are passed to the client anyway, bypassing Garry's Mod's prohibitions on extensions.

# Installation
Download [latest release](https://github.com/autumngmod/libloader/releases/latest/download/libloader_minified.lua), and put it to ``GarrymodDS/garrysmod/lua/autorun/`` (its minified version of ``libloader``)

> [!NOTE]
> Alternatively, you can just download this repository, and install libloader as an addon. This way you can make sure that the code is not modified and does not contain anything dangerous.

# Usage
> [!NOTE]
> You can hide tooltips (hints) by using the ``libloader_showhints 0`` command

### Library installation
```bash
# Installation of latest version of library
lib i/install autumngmod/binloader

# Forcing a version
lib i autumngmod/binloader@0.1.0
# # Forcing a version with a flag
lib i autumngmod/binloader --version 0.1.0
```

### Library enabling
> [!NOTE]
> Libraries are disabled by default, so enable them after installation.

```bash
lib enable autumngmod/binloader@0.1.0
```

### Library disabling
```bash
lib disable autumngmod/binloader@0.1.0
```

### Library removing
```bash
lib remove/delete/r autumngmod/binloader@0.1.0
```

### Show the list of installed libraries
```bash
lib list
```

# * For developers
Your repository should have an addon.json file in GitHub release, and its contents should match [this json schema](https://raw.githubusercontent.com/autumngmod/json/refs/heads/main/addon.scheme.json).

Example:
```json
{
  "$schema": "https://raw.githubusercontent.com/autumngmod/json/refs/heads/main/addon.scheme.json",
  "name": "Addon's name",
  "description": "Short description",
  "authors": ["author1", "author2"],
  "version": "0.1.0",
  "githubRepo": "https://github.com/example/repo",
  "side": ["server", "client"]
}
```

Also, the library itself should be uploaded to GitHub Release under the name lib.lua.

> [!NOTE]
> Yes, the library itself should be compressed into a single file.

You can do this either manually or [via GitHub Actions like gm-donate/igs](https://github.com/GM-DONATE/IGS).

> [!NOTE]
> GitHub Release should have a name like “v*.*.*.*”, e.g. “v0.1.0”.

[Ideal example of a repository with an addon on GitHub](https://github.com/autumngmod/binloader)
