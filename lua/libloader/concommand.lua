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
        return libloader.log.err("invalid flag argument")
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

---@class RepoData
---@field repo string
---@field version? string

---@param str string
---@return RepoData?
local function parseRepo(str)
  local version;

  local splitted = (str or ""):Split("/");

  if (#splitted ~= 2) then
    return libloader.log.err("the specified repository has an invalid format (org/repo@version?)")
  end

  local splittedVersion = splitted[2]:Split("@")

  if (#splittedVersion == 2) then
    version = splittedVersion[2]
  end

  return {
    repo = str:Split("@")[1],
    version = version
  }
end

-- Console commands

local actions = {
  --- Library installation
  ---@param args CliArguments
  install = function(args)
    local data = parseRepo(args.commands[1])

    if (not data) then
      return
    end

    coroutine.resume(coroutine.create(function()
      libloader:download(data.repo, data.version or args.flags["version"])
    end))
  end,

  --- Library deletion
  ---@param args CliArguments
  remove = function(args)
    local data = parseRepo(args.commands[1])
    local version = (data or {}).version or args.flags["version"]

    if (not data) then
      return
    end

    if (not version) then
      return libloader.log.err("You must specify the version of the library!")
    end

    libloader.db:remove(data.repo, version)
    libloader.fs:delete(data.repo, version)

    libloader.log.log(("Library %s@%s has been deleted"):format(data.repo, version))
  end,

  --- Library enabling
  ---@param args CliArguments
  enable = function(args)
    local data = parseRepo(args.commands[1])
    local version = (data or {}).version or args.flags["version"]

    if (not data) then
      return
    end

    if (not version) then
      return libloader.log.err("You must specify the version of the library!")
    end

    libloader:enable(data.repo, version)
  end,

  --- Library disabling
  ---@param args CliArguments
  disable = function(args)
    local data = parseRepo(args.commands[1])
    local version = (data or {}).version or args.flags["version"]

    if (not data) then
      return
    end

    if (not version) then
      return libloader.log.err("You must specify the version of the library!")
    end

    libloader.db:disable(data.repo, version)
  end,

  list = function()
    local libs = libloader.db:getInstalled()

    if (#libs == 0) then
      return libloader.log.log("You have not installed any libraries yet")
    end

    libloader.log.log("List of installed libraries")

    for _, record in ipairs(libs) do
      libloader.log.empty(("  • %s@%s (%s)"):format(record.repo, record.version, record.enabled == "1" and "enabled" or "disabled"))
      libloader.log.empty(("    %s"):format(libloader.fs:getLibPath(record.repo, record.version)))
    end
  end,

  unbusy = function()
    libloader.log.warn("Use this only if you have caught a bug!")
    libloader:setBusy(false)
    libloader.log.log("Unbusied!")
  end
}

-- aliases
actions["i"] = actions["install"]
actions["en"] = actions["enable"]
actions["r"] = actions["remove"]
actions["delete"] = actions["remove"]

concommand.Add("lib", function(ply, _, args)
  if (libloader:isBusy() and args[1] ~= "unbusy") then
    return
  end

  if (IsValid(ply) and not ply:IsSuperAdmin()) then
    return ply:ChatPrint("you are not permitted to do that")
  end

  local commands = parseCli(args)

  if (not commands) then
    return
  end

  local action = commands.commands[1];

  if (not action) then
    return libloader.log.err("argument #1 (command) is not specified")
  end

  local cmds = table.Copy(commands.commands)
  table.remove(cmds, 1);

  commands.commands = cmds

  local actionFunc = actions[action]

  if (not actionFunc) then
    return libloader.log.err("command not found")
  end

  actionFunc(commands)
end)