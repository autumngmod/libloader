file.CreateDir("libloader")

if (!sql.TableExists("loaderDb")) then
  sql.Query("CREATE TABLE IF NOT EXISTS loaderDb(id AUTO_INCREMENT INT, name TEXT, version TEXT, repo TEXT)")
end

---@class AddonSchema
---@field name string
---@field description string
---@field authors string[]
---@field version string
---@field githubRepo string
---@field dependencies? {string: string}

libloader = libloader || {}
libloader.version = "0.1.0"
libloader.showChecksums = true

local defaultBranch = "main"
local libloaderColor = Color(255, 0, 0)
local greyColor = Color(200, 200, 200)

local function log(msg)
  MsgC(libloaderColor, "[libLoader]", greyColor, " ", msg)
  MsgN()
end

if (!LIBLOADER_INITIALIZED) then
  LIBLOADER_INITIALIZED = true
  log(("Loading libLoader v%s by smokingplaya"):format(libloader.version))
end

local function log_custom(...)
  MsgC(libloaderColor, "[libLoader] ", greyColor, ...)
  MsgN()
end

local redColor = Color(200, 10, 25)
---@param msg string
local function log_err(msg)
  MsgC(libloaderColor, "[libLoader]", " ", redColor, msg)
  MsgN()
end

local orangeColor = Color(255, 204, 0)
---@param msg string
local function log_warn(msg)
  MsgC(libloaderColor, "[libLoader]", " ", orangeColor, msg)
  MsgN()
end

if (!libloader.showChecksums) then
  log_warn("Attention! You have disabled printing of file checksums. It's not safe!")
end

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

--- Downloads library from GitHub repository
---
---@param repo string
---@param branch? string
---@param version? string
---@param parentCo? thread


-- TODO version <<
function libloader:download(repo, branch, version, parentCo)
  local url = ("https://raw.githubusercontent.com/%s/refs/heads/%s/addon.json"):format(repo, branch or defaultBranch)

  log(("Fetching library %s"):format(repo))

  if (!table.HasValue(trustedOrgs, repo:Split("/")[1])) then
    MsgC(greyColor, "We are not responsible for problems with third-party libraries. Be careful.")
    MsgN()
  end

  http.Fetch(url, function(b, s)
    local co = coroutine.create(function(co)
      ---@type AddonSchema
      local body = util.JSONToTable(b)

      log(("Found %s@%s"):format(repo, body["version"]))

      local dependencies = body.dependencies
      if (dependencies) then
        log_custom("Found ", orangeColor, "dependencies: ", greyColor, concatDeps(dependencies))

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
    log_err(("Failed to fetch \"%s\": %s"):format(url, err))

    resume(parentCo)
  end)
end

---@private
---@param repo string
---@param body AddonSchema
---@param co? thread
function libloader:handleDownload(repo, body, co)
  print()
  log(("Trying to find GitHub release %s@%s"):format(repo, body.version))

  local url = ("http://github.com/%s/releases/download/v%s/lib.lua"):format(repo, body.version)

  http.Fetch(url, function(b, _, _, c)
    if (c != 200) then
      return log_err(("Unable to get release for %s@%s"):format(repo, body.version))
    end

    log_custom(Color(0, 255, 0), "[200 OK] ", greyColor, "Release found")
    local base = "libloader/" .. repo .. "/" .. body.version

    log(("Saving library in data/%s/lib.txt"):format(base))

    if (libloader.showChecksums) then
      log(("SHA256: %s, CRC32: %s"):format(
        util.SHA256(b),
        util.CRC(b)
      ))
    end

    file.CreateDir(base)

    file.Write(base .. "/lib.txt", b)

    self.db:save(repo, body)

    log_custom(Color(85, 255, 85), ("%s@%s installed"):format(repo, body.version))

    resume(co)
  end, function(err)
    log_err(("Failed to get lib.lua file \"%s\": %s"):format(url, err))

    resume(co)
  end)
end

-- todo
function libloader:load(name)

end

-- todo
---@private
---@param repo string
---@param version string
function libloader:remove(repo, version)

end

---@class CliArguments
---@field flags {string: string}
---@field commands string[]

--- Fast cli args parsing
---
---@param args string[]
local function parseCli(args)
  local flags = {}
  local commands = {}
  ---@type string?
  local lastFlag;

  for i, arg in ipairs(args) do
    local flag = arg:Split("--")
    -- flag
    if (#flag == 2) then
      if (lastFlag) then
        return log_err("invalid flag argument")
      end

      lastFlag = flag[2]
      continue;
    elseif (lastFlag) then
      flags[lastFlag] = arg
      lastFlag = nil
    else
      commands[#commands+1] = arg
    end
  end

  return {
    flags = flags,
    commands = commands,
  }
end

local actions = {
  ---@param args CliArguments
  install = function(args)
    local repo = args.commands[1];

    local splitted = repo:Split("/");
    -- PrintTable(splitted)
    if (#splitted != 2) then
      return log_err("the specified repository has an invalid format (org/repo@version?)")
    end

    libloader:download(repo, args.flags["branch"], args.flags["version"])
  end,

  ---@param args CliArguments
  remove = function(args)
    -- todo
  end,

  list = function()
    -- todo
  end
}

-- aliases
actions["i"] = actions["install"]
actions["r"] = actions["remove"]
actions["delete"] = actions["remove"]

concommand.Add("lib", function(ply, _, args)
  if (IsValid(ply) && !ply:IsSuperAdmin()) then
    return ply:ChatPrint("you are not permitted to do that")
  end

  local commands = parseCli(args)

  if (!commands) then
    return
  end

  local action = commands.commands[1];

  if (!action) then
    return log_err("argument #1 (command) is not specified")
  end

  local cmds = table.Copy(commands.commands)
  table.remove(cmds, 1);

  commands.commands = cmds

  local actionFunc = actions[action]

  if (!actionFunc) then
    return log_err("command not found")
  end

  actionFunc(commands)
end)

libloader.db = {}
---@param repo string
---@param body AddonSchema
function libloader.db:save(repo, body)
  local query = ("INSERT INTO loaderDb(name, version, repo) VALUES(%s, %s, %s)"):format(SQLStr(body.name), SQLStr(body.version), SQLStr(body.githubRepo))
  sql.Query(query)

  log(("%s@%s has been saved in local database (sqlite)"):format(repo, body.version))
end

function libloader.db:remove(name, version)
  local query = ("DELETE FROM loaderDb WHERE name=%s AND version=%s"):format(name, version)
  sql.Query(query)
end