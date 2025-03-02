---@class AddonSchema
---@field name string
---@field description string
---@field authors string[]
---@field version string
---@field githubRepo string
---@field dependencies? {string: string}

libloader = libloader || {}
libloader.version = "0.1.1"
libloader.showChecksums = true

local defaultBranch = "main"

if (!libloader.showChecksums) then
  libloader.log.warn("Attention! You have disabled printing of file checksums. It's not safe!")
end

IncludeCS("libloader/db.lua")
IncludeCS("libloader/fs.lua")
IncludeCS("libloader/log.lua")
IncludeCS("libloader/concommand.lua")

local greyColor = libloader.log.greyColor
local orangeColor = libloader.log.orangeColor

---@param co? thread
local function resume(co)
  if (co) then
    coroutine.resume(co)
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

-- TODO version <<
--- Downloads library from GitHub repository
---
---@param repo string
---@param branch? string
---@param version? string
---@param parentCo? thread
function libloader:download(repo, branch, version, parentCo)
  local url = ("https://raw.githubusercontent.com/%s/refs/heads/%s/addon.json"):format(repo, branch or defaultBranch)

  libloader.log.log(("Fetching library %s"):format(repo))

  if (!table.HasValue(trustedOrgs, repo:Split("/")[1])) then
    MsgC(greyColor, "We are not responsible for problems with third-party libraries. Be careful.")
    MsgN()
  end

  http.Fetch(url, function(b, s)
    local co = coroutine.create(function(co)
      ---@type AddonSchema
      local body = util.JSONToTable(b)

      libloader.log.log(("Found %s@%s"):format(repo, body["version"]))

      local dependencies = body.dependencies
      if (dependencies) then
        libloader.log.custom("Found ", orangeColor, "dependencies: ", greyColor, concatDeps(dependencies))

        for depRepo, version in pairs(dependencies) do
          local splitted = depRepo:Split(":"); // org/repo or org/repo:master
          ---@type string, string?
          local repo, branch = splitted[1], splitted[2]
          self:download(repo, branch, version, co)
          coroutine.yield()
        end
      end

      self:handleDownload(repo, body, co)
      coroutine.yield()

      resume(parentCo)
    end)

    coroutine.resume(co, co)
  end, function(err)
    libloader.log.err(("Failed to fetch \"%s\": %s"):format(url, err))

    resume(parentCo)
  end)
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

    resume(co)
  end, function(err)
    self.log.err(("Failed to get lib.lua file \"%s\": %s"):format(url, err))

    resume(co)
  end)
end

-- todo
function libloader:load(repo, version)
  local path = self.fs:getLibPath(repo, version)

  if (!file.Exists(path, "DATA")) then
    return self.log.err(("The lib.txt file for %s@%s was not found. Most likely you already deleted it."):format(repo, version))
  end

  local err = RunString(file.Read(path, "DATA"), repo, false)

  if (err) then
    self.log.err("Error when starting " .. err)
  end
end

-- todo
---@private
---@param repo string
---@param version string
function libloader:remove(repo, version)
  self.db:remove(repo, version)
  self.fs:delete(repo, version)

  self.log.log(("Library %s@%s has been deleted"):format(repo, version))
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