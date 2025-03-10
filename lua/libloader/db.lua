---@class DbRecord
---@field repo string org/repo
---@field version string 0.1.0
---@field mode number 0/1/2 (shared, client, server)
---@field enabled number 0/1 (boolean)
---@field deps string '["autumngmod/binloader@0.1.0"]'
---@field crc string

if (not sql.TableExists("loaderDb")) then
  sql.Query("CREATE TABLE loaderDb (id INTEGER PRIMARY KEY AUTOINCREMENT, repo TEXT, version TEXT, mode INTEGER, enabled INTEGER, deps TEXT, crc INTEGER)")
end

libloader.db = libloader.db or {}
--- cache for the clients
---
---@type {string: string}[]
libloader.db.cache = libloader.db.cache or {}

--- Adds the library to the client cache
---
---@private
---@param repo string
---@param version string
function libloader.db:addToCache(repo, version)
  for _, v in ipairs(self.cache) do
    local key = next(v)

    if (key == repo and v[key] == version) then
      return
    end
  end

  self.cache[#self.cache+1] = {
    [repo] = version
  }

  hook.Run("libCacheUpdated", repo, version)
end

--- Removes the library to the client cache
---@private
---@param repo string
---@param version string
function libloader.db:clearFromCache(repo, version)
  for i, v in ipairs(self.cache) do
    local key = next(v)

    if (key == repo and v[key] == version) then
      table.remove(self.cache, i)
      break;
    end
  end
end

--- Returns the client cache
---
---@return {string: string}[]
function libloader.db:getCache()
  return self.cache
end

--- Handler of “side” array from AddonSchema
---
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

--- Adds a library to the database
---
---@param repo string
---@param body AddonSchema
---@param crc number
function libloader.db:save(repo, body, crc)
  if (self:has(repo, body.version)) then
    return
  end

  -- saving deps
  local deps = {}

  for repo, version in pairs(body.dependencies or {}) do
    deps[#deps+1] = repo .. "@" .. version
  end

  local query = ("INSERT INTO loaderDb(repo, version, mode, deps, enabled, crc) VALUES(%s, %s, %s, %s, 0, %s)"):format(
    ---@diagnostic disable-next-line: param-type-mismatch
    SQLStr(repo), SQLStr(body.version), SQLStr(getMode(body.side)), SQLStr(util.TableToJSON(deps)), SQLStr(crc)
  )

  sql.Query(query)

  libloader.log.log(("Library %s@%s has been stored in the database"):format(repo, body.version))
end

--- Enables the library in the database
---
---@param repo string
---@param version string
function libloader.db:enable(repo, version)
  if (not self:has(repo, version)) then
    return libloader.log.err(("Library %s/%s was not found!"):format(repo, version))
  end

  local query = ("SELECT mode, deps FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  ---@type {mode: string, deps: string}
  local result = sql.Query(query)
  local library = istable(result) and result[1]

  if (not library) then
    return libloader.log.err(("Record of library %s/%s not found in the database!"):format(repo, version));
  end

  -- checking for a deps (enabling deps)
  ---@type string[]
  local deps = util.JSONToTable(library.deps or "[]") -- can be null

  if (#deps ~= 0) then
    for _, dep in ipairs(deps) do
      local splitted = dep:Split("@")
      local depRepo, depVersion = splitted[1], splitted[2]

      local record = self:get(depRepo, depVersion)

      if (not record) then
        return libloader.log.err(("Unable to find dependency %s@%s of %s@%s"):format(depRepo, depVersion, repo, version))
      end

      if (record.enabled ~= "1") then
        self:enable(depRepo, depVersion)
      end
    end
  end

  -- client/shared (but not server)
  if (library.mode ~= "2") then
    self:addToCache(repo, version)
  end

  local query = ("UPDATE loaderDb SET enabled='1' WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  libloader.log.log(("Library %s@%s was enabled in the database"):format(repo, version))
end

--- Disables the library in the database
---
---@param repo string
---@param version string
function libloader.db:disable(repo, version)
  if (not self:has(repo, version)) then
    return libloader.log.err(("Library %s/%s was not found!"):format(repo, version))
  end

  -- It's irresponsible to turn off dependencies here,
  -- even if other libraries don't use the current one,
  -- it doesn't mean it's not used;
  --
  -- but there is a idea: SELECT deps FROM loaderDb WHERE enabled=“1”;
  --                      then search through the deps and look for the current
  --                       one among them, if not, turn it off. profit.

  local query = ("UPDATE loaderDb SET enabled=0 WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  self:clearFromCache(repo, version)

  libloader.log.log(("Library %s@%s was disabled in the database"):format(repo, version))
end

--- Deletes a library record from the database
---
---@param repo string
---@param version string
function libloader.db:remove(repo, version)
  local query = ("DELETE FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

  self:clearFromCache(repo, version)

  libloader.log.log(("Library %s@%s has been removed from the database"):format(repo, version))
end

--- Returns the full library record from the database
---
---@param repo string
---@param version string
---@return DbRecord
function libloader.db:get(repo, version)
  local query = ("SELECT * FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))

  return sql.Query(query)
end

--- Returns the CRC sum of lib.txt stored in the database
---
---@param repo string
---@param version string
function libloader.db:getCrc(repo, version)
  local query = ("SELECT crc FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  local result = sql.Query(query)

end

--- Is database contains library record?
---
---@param repo string
---@param version string
---@return boolean
function libloader.db:has(repo, version)
  local query = ("SELECT * FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  local result = sql.Query(query)

  if (type(result) ~= "table") then
    return false
  end

  return #result ~= 0
end

--- Returns all installed libraries from the database
---
---@return DbRecord[]
function libloader.db:getInstalled()
  ---@type DbRecord[]
  local result = sql.Query("SELECT * FROM loaderDb") or {};

  for _, v in ipairs(result) do
    if (v.enabled == "1" and v.mode ~= "2") then -- skip it if serverside only
      self:addToCache(v.repo, v.version)
    end
  end

  return result
end