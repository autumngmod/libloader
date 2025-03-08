---@class AddonSchema
---@field name string
---@field description string
---@field authors string[]
---@field version string
---@field side string[]
---@field githubRepo string
---@field dependencies? {string: string}

libloader = libloader || {}
libloader.version = "0.1.2"
libloader.showChecksums = true

local showHints = CreateConVar("libloader_showhints", "1", nil, nil, 0, 1)

if (!libloader.showChecksums) then
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

local trustedOrgs = {"autumngmod", "smokingplaya"}

---@param repo string
---@param version? string
---@param msg string | number
---@param co? thread
local function handleError(repo, version, msg, co)
  libloader.log.err(("Failed to get %s: %s"):format(repo .. (version and "@" .. version or ""), msg))

  libloader:setBusy(false)

  resume(co)
end

---@param repo string
local function getLatestVersion(repo)
  local co = coroutine.running()
  local url = ("https://api.github.com/repos/%s/releases/latest"):format(repo)
  local result;

  http.Fetch(url, function(b, _, _, c)
    if (c != 200) then
      resume(co)

      return libloader.log.err("Failed to fetch GitHub API")
    end

    result = util.JSONToTable(b)
      .tag_name

    libloader.log.log("Found the latest version of the library: " .. result)

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

---@return boolean
function libloader:isBusy()
  return self.busy or false
end

---@private
---@param list {string: string}[]
---@param shouldEnable? boolean
function libloader:downloadMany(list, shouldEnable)
  for _, tab in ipairs(list) do
    local repo = next(tab)
    local version = tab[repo]

    self:download(repo, version)

    if (shouldEnable) then
      self:load(repo, version)
    end
  end
end

--- Downloads library from GitHub repository
---
---@param repo string
---@param version? string
function libloader:download(repo, version)
  self:setBusy(true)

  version = version and "v" .. version or getLatestVersion(repo)

  if (!version) then
    self:setBusy(false)
    return self.log.err("Failed to get latest release of " .. repo)
  end

  local baseCo = coroutine.running()
  local url = ("http://github.com/%s/releases/download/%s/addon.json"):format(repo, version)

  if (!table.HasValue(trustedOrgs, repo:Split("/")[1])) then
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

      self:handleDownload(repo, body, co)

      self:setBusy(false)

      coroutine.resume(baseCo)
    end)

    coroutine.resume(co, co)
  end, function(e)
    handleError(repo, version, e)
  end)

  coroutine.yield()
end

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
    if (c != 200) then
      return self.log.err(("Unable to get release for %s@%s (%s)"):format(repo, version, c))
    end

    local base = self.fs:getLibPath(repo, body.version)

    self.log.custom(Color(0, 255, 0), "[200 OK] ", libloader.log.greyColor, "Release found")
    self.log.log(("Saving library in data/%s"):format(base))

    if (libloader.showChecksums) then
      self.log.log(("SHA256: %s, CRC32: %s"):format(
        util.SHA256(content),
        util.CRC(content)
      ))
    end

    self.fs:write(repo, version, content)
    self.db:save(repo, body)

    self.log.custom(Color(85, 255, 85), ("The %s@%s library has been installed"):format(repo, version))

    if (showHints:GetBool()) then
      self.log.custom(self.log.orangeColor, "* Libraries are not enabled by default, use ", self.log.greyColor, "lib enable org/repo@version", self.log.orangeColor, " to enable.")
    end

    hook.Run("libInstalled", repo, version)

    resume(co)
  end, function(e)
    handleError(repo, version, e, co)
  end)

  coroutine.yield()
end

function libloader:load(repo, version)
  local path = self.fs:getLibPath(repo, version)

  if (!file.Exists(path, "DATA")) then
    return self.log.err(("The lib.txt file for %s@%s was not found. Most likely you already deleted it."):format(repo, version))
  end

  local err = RunString(file.Read(path, "DATA"), repo, false)

  if (err) then
    return self.log.err("Error while running " .. err)
  end

  self.log.log(("Library %s@%s has been loaded"):format(repo, version))
end

function libloader:loadLibraries()
  local libraries = self.db:getInstalled()

  for _, lib in ipairs(libraries) do
    if (lib.enabled != "1") then
      continue
    end

    self:load(lib.repo, lib.version)
  end
end

libloader:loadLibraries()

-- RunString test --
RunString("RSTEST=0")
assert(RSTEST == 0, "RunString not working")
RSTEST = nil