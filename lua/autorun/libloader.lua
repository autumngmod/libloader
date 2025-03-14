---@class AddonSchema
---@field name string
---@field description string
---@field authors string[]
---@field version string
---@field side string[]
---@field githubRepo string
---@field dependencies? {string: string}

---@diagnostic disable-next-line: lowercase-global
libloader = libloader or {}
libloader.version = "0.1.6"
libloader.showChecksums = true

local showHints = CreateConVar("libloader_showhints", "1", nil, nil, 0, 1)

if (not libloader.showChecksums) then
  libloader.log.warn("Attention! You have disabled printing of file checksums. It's not safe!")
end

IncludeCS("libloader/db.lua")
IncludeCS("libloader/fs.lua")
IncludeCS("libloader/log.lua")
IncludeCS("libloader/concommand.lua")
IncludeCS("libloader/client.lua")

local greyColor = libloader.log.greyColor
local orangeColor = libloader.log.orangeColor

---@param co? thread
local function resume(co, ...)
  if (co) then
    coroutine.resume(co, ...)
  end
end

---@param deps {string: string}
---@return string
local function concatDeps(deps)
  local result = ""

  for k in pairs(deps) do
    result = result .. k .. ", "
  end

  return result:Left(#result-2)
end

---@param repo string
---@param version? string
---@param msg string | number
---@param co? thread
local function handleError(repo, version, msg, co)
  libloader.log.err(("Failed to get %s: %s"):format(repo .. (version and "@" .. version or ""), msg))

  libloader:setBusy(false)

  resume(co)
end

--- Fetches the GitHub API and gets the latest release of the library
---
---@param repo string
local function getLatestVersion(repo)
  local co = coroutine.running()
  local url = ("https://api.github.com/repos/%s/releases/latest"):format(repo)
  local result;

  http.Fetch(url, function(b, _, _, c)
    if (c ~= 200) then
      resume(co)

      return libloader.log.err("Failed to fetch GitHub API")
    end

    result = util.JSONToTable(b)
      .tag_name

    libloader.log.log("Downloading the latest version: " .. result)

    resume(co)
  end, function(e)
    handleError(repo, nil, e, co)
  end)

  coroutine.yield()

  return result
end

---@private
---@param b boolean
function libloader:setBusy(b)
  self.busy = b
end

--- Is libloader busy?
---@return boolean
function libloader:isBusy()
  return self.busy or false
end

--- Downloads a bunch of libraries
---
---@private
---@param list {string: string}[]
---@param shouldEnable? boolean
function libloader:downloadMany(list, shouldEnable)
  for _, tab in ipairs(list) do
    local repo = next(tab)
    local version = tab[repo]

    self:download(repo, version)

    if (shouldEnable) then
      self:enable(repo, version)
    end
  end
end

local trustedOrgs = {"autumngmod", "smokingplaya"}

--- Downloads library from GitHub repository
---
---@param repo string
---@param argVersion? string
function libloader:download(repo, argVersion)
  self:setBusy(true)

  local version = argVersion and "v" .. argVersion or getLatestVersion(repo)

  if (not version) then
    self:setBusy(false)
    return self.log.err("Failed to get latest release of " .. repo)
  end

  -- skip if downloaded
  local vers = version:Replace("v", "")
  local result = self.db:get(repo, vers)
  local downloaded = istable(result) and result[1]

  if (downloaded) then
    if (downloaded.crc == util.CRC(self.fs:read(repo, vers) or "")) then
      self:setBusy(false)
      return self.log.warn(("%s@%s is already installed"):format(repo, vers))
    end
  end

  -- downloading

  local baseCo = coroutine.running()
  local url = ("http://github.com/%s/releases/download/%s/addon.json"):format(repo, version)

  if (not table.HasValue(trustedOrgs, repo:Split("/")[1])) then
    MsgC(greyColor, "We are not responsible for third-party libraries. Their use may lead to harmful consequences.")
    MsgN()
  end

  libloader.log.log(("Retrieving %s@%s library metadata"):format(repo, version))

  http.Fetch(url, function(b, _, _, c)
    if (c > 300) then
      return handleError(repo, version, c)
    end

    local co = coroutine.create(function(co)
      ---@type AddonSchema
      local body = util.JSONToTable(b)

      libloader.log.custom(Color(0, 255, 0), "[200 OK] ", libloader.log.greyColor, "Metadata found")

      local dependencies = body.dependencies
      if (dependencies) then
        libloader.log.custom("Found ", orangeColor, "dependencies: ", greyColor, concatDeps(dependencies))

        for repo, version in pairs(dependencies) do
          self:download(repo, version, co)
        end
      end

      -- skip downloading if the library is client-only
      if (CLIENT or SERVER and (#body.side == 2 or body[1] == "server")) then
        self:handleDownload(repo, body, co)
      else
        self:install(repo, body)
      end

      self:setBusy(false)

      coroutine.resume(baseCo)
    end)

    coroutine.resume(co, co)
  end, function(e)
    handleError(repo, version, e)
  end)

  coroutine.yield()
end

--- Fetches lib.lua file and saves it
---
---@private
---@param repo string
---@param body AddonSchema
---@param co? thread
function libloader:handleDownload(repo, body, co)
  print()

  local version = body.version
  local url = ("http://github.com/%s/releases/download/v%s/lib.lua"):format(repo, version)

  self.log.log(("Trying to find GitHub release %s@%s"):format(repo, version))

  http.Fetch(url, function(content, _, _, c)
    if (c ~= 200) then
      return self.log.err(("Unable to get release for %s@%s (%s)"):format(repo, version, c))
    end

    local base = self.fs:getLibPath(repo, body.version)

    self.log.custom(Color(0, 255, 0), "[200 OK] ", libloader.log.greyColor, "Release found")
    self.log.log(("Saving library in data/%s"):format(base))

    local crc = util.CRC(content)

    if (libloader.showChecksums) then
      self.log.log(("SHA256: %s, CRC32: %s"):format(
        util.SHA256(content),
        crc
      ))
    end

    self:install(repo, body, content, crc)

    resume(co)
  end, function(e)
    handleError(repo, version, e, co)
  end)

  coroutine.yield()
end

---@private
---@param repo string
---@param body AddonSchema
---@param content string?
---@param crc string?
function libloader:install(repo, body, content, crc)
  local version = body.version

  if (content) then
    self.fs:write(repo, version, content)
  end

  self.db:save(repo, body, crc or "0")

  self.log.custom(Color(85, 255, 85), ("The %s@%s library has been installed"):format(repo, version))

  if (showHints:GetBool()) then
    self.log.custom(self.log.orangeColor, "* The library is disabled after installation, you can enable it with this command:")
    self.log.custom(self.log.greyColor, ("\tlib enable %s@%s"):format(repo, version))
  end

  hook.Run("LibLoader.Installed", repo, version)
end

--- Enables library
---
---@param repo string
---@param version string
function libloader:enable(repo, version)
  self.db:enable(repo, version)
  self:load(repo, version)
end

--- Loads library via RunString
---
---@param repo string
---@param version string
function libloader:load(repo, version)
  local result = self.db:get(repo, version)
  local row = istable(result) and result[1]

  -- client-only
  if (not row or (SERVER and row.mode == "1")) then
    return
  end

  local path = self.fs:getLibPath(repo, version)

  if (not file.Exists(path, "DATA")) then
    return self.log.err(("The lib.txt file for %s@%s was not found. Most likely you already deleted it."):format(repo, version))
  end

  if (util.CRC(self.fs:read(repo, version)) ~= self.db:getCrc(repo, version)) then
    return
  end

  local err = RunString(file.Read(path, "DATA"), repo .. "@" .. version, false)

  if (err) then
    return self.log.err("Error while running " .. err)
  end

  hook.Run("LibLoader.Loaded", repo, version)

  self.log.log(("Library %s@%s has been loaded"):format(repo, version))
end

--- Loads enabled in database libraries
---
---@private
function libloader:loadLibraries()
  local libraries = self.db:getInstalled()

  for _, lib in ipairs(libraries) do
    if (lib.enabled ~= "1") then
      continue
    end

    self:load(lib.repo, lib.version)
  end
end

libloader:loadLibraries()

-- RunString test --
RunString("RSTEST=0")
assert(RSTEST == 0, "RunString isn't working")
RSTEST = nil