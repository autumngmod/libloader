---@class DbRecord
---@field repo string org/repo
---@field version string 0.1.0
---@field github string https://github.com/org/repo
---@field enabled number 0/1 (boolean)

if (!sql.TableExists("loaderDb")) then
  sql.Query("CREATE TABLE loaderDb (id INTEGER PRIMARY KEY AUTOINCREMENT, repo TEXT, version TEXT, github TEXT, enabled INTEGER)")
end

libloader.db = libloader.db || {}
---@param repo string
---@param body AddonSchema
function libloader.db:save(repo, body)
  if (self:has(repo, body.version)) then
    return
  end

  local query = ("INSERT INTO loaderDb(repo, version, github, enabled) VALUES(%s, %s, %s, 0)"):format(SQLStr(repo), SQLStr(body.version), SQLStr(body.githubRepo))
  sql.Query(query)

  libloader.log.log(("Library %s@%s has been stored in the database"):format(repo, body.version))
end

---@param repo string
---@param version string
function libloader.db:enable(repo, version)
  if (!self:has(repo, version)) then
    return libloader.log.err(("Library %s/%s was not found!"):format(repo, version))
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

  libloader.log.log(("Library %s@%s was disabled in the database"):format(repo, version))
end

function libloader.db:remove(repo, version)
  print(repo, version)
  local query = ("DELETE FROM loaderDb WHERE repo=%s AND version=%s"):format(SQLStr(repo), SQLStr(version))
  sql.Query(query)

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
  local query = ("SELECT * FROM loaderDb");

  return sql.Query(query) or {}
end