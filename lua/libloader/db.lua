---@class DbRecord
---@field repo string org/repo
---@field version string 0.1.0
---@field mode number 0/1/2 (shared, client, server)
---@field github string https://github.com/org/repo
---@field enabled number 0/1 (boolean)

if (!sql.TableExists("loaderDb")) then
  sql.Query("CREATE TABLE loaderDb (id INTEGER PRIMARY KEY AUTOINCREMENT, repo TEXT, version TEXT, github TEXT, mode INTEGER, enabled INTEGER)")
end

libloader.db = libloader.db || {}
--- cache for the clients
---
---@type {string: string}[]
libloader.db.cache = libloader.db.cache || {}

---@private
---@param repo string
---@param version string
function libloader.db:addToCache(repo, version)
  for _, v in ipairs(self.cache) do
    local key = next(v)

    if (key == repo && v[key] == version) then
      return
    end
  end

  self.cache[#self.cache+1] = {
    [repo] = version
  }

  hook.Run("libCacheUpdated", repo, version)
end

---@private
---@param repo string
---@param version string
function libloader.db:clearFromCache(repo, version)
  for i, v in ipairs(self.cache) do
    local key = next(v)

    if (key == repo && v[key] == version) then
      table.remove(self.cache, i)
      break;
    end
  end
end

function libloader.db:getCache()
  return self.cache
end

---@param sides string[]
---@return number 0/1/2
local function getMode(sides)
  if (#sides == 0) then
    return 0 -- shared
  elseif (#sides == 1) then
    return sides[1] == "client" and 1 or 2 -- server or client
  else
    return 0 -- shared
  end
end

---@param repo string
---@param body AddonSchema
function libloader.db:save(repo, body)
  if (self:has(repo, body.version)) then
    return
  end

  local query = ("INSERT INTO loaderDb(repo, version, github, mode, enabled) VALUES(%s, %s, %s, %s, 0)"):format(SQLStr(repo), SQLStr(body.version), SQLStr(getMode(body.side)), SQLStr(body.githubRepo))
  sql.Query(query)

  libloader.log.log(("Library %s@%s has been stored in the database"):format(repo, body.version))
end

---@param repo string
---@param version string
function libloader.db:enable(repo, version)
  if (!self:has(repo, version)) then
    return libloader.log.err(("Library %s/%s was not found!"):format(repo, version))
  end

  local record = ("SELECT mode FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  ---@type {mode: string}
  local library = sql.Query(record) or {}

  if (!library) then
    return libloader.log.err(("Record of library %s/%s not found in the database!"):format(repo, version));
  end

  if (library.mode != "2") then
    self:addToCache(repo, version)
  end

  local query = ("UPDATE loaderDb SET enabled='1' WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  libloader.log.log(("Library %s@%s was enabled in the database"):format(repo, version))
end

function libloader.db:disable(repo, version)
  if (!self:has(repo, version)) then
    return libloader.log.err(("Library %s/%s was not found!"):format(repo, version))
  end

  local query = ("UPDATE loaderDb SET enabled=0 WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  self:clearFromCache(repo, version)

  libloader.log.log(("Library %s@%s was disabled in the database"):format(repo, version))
end

function libloader.db:remove(repo, version)
  local query = ("DELETE FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  self:clearFromCache(repo, version)

  libloader.log.log(("Library %s@%s has been removed from the database"):format(repo, version))
end

function libloader.db:has(repo, version)
  local query = ("SELECT * FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  local result = sql.Query(query)

  if (type(result) != "table") then
    return false
  end

  return #result != 0
end

---@return DbRecord[]
function libloader.db:getInstalled()
  ---@type DbRecord[]
  local result = sql.Query("SELECT * FROM loaderDb") or {};

  for _, v in ipairs(result) do
    if (v.enabled == "1" && v.mode != "2") then -- skip it if serverside only
      self:addToCache(v.repo, v.version)
    end
  end

  return result
end