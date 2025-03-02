# libloader
``libloader`` is an attempt to make a package manager for Garry's Mod.

All packages are searched on GitHub, in open source repositories.

![showcase](./assets/showcase.png)

# Installation
Download [latest release](https://github.com/autumngmod/libloader/releases/download/latest/libloader.lua), and put it to ``GarrymodDS/garrysmod/lua/autorun/``

# For developers
Your repository should have an addon.json file in root directory, and its contents should match [this json schema](https://raw.githubusercontent.com/autumngmod/json/refs/heads/main/addon.scheme.json).

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

# Usage
> [!NOTE]
> This commands should be running in the srcds console (gmod-ds)

### Library installation
```bash
lib install autumngmod/binloader
# or
lib i autumngmod/binloader

# with version
lib i autumngmod/binloader@0.1.0
# aliases
lib i autumngmod/binloader --version 0.1.0
lib i autumngmod/binloader --version 0.1.0 --branch master
```

### Library enabling
```bash
lib enable autumngmod/binloader@0.1.0
```

### Library disabling
```bash
lib disable autumngmod/binloader@0.1.0
```

### Library removing
```bash
lib remove autumngmod/binloader@0.1.0
# aliases
lib delete autumngmod/binloader@0.1.0
lib r autumngmod/binloader@0.1.0
```

### Show the list of installed libraries
```bash
lib list
```