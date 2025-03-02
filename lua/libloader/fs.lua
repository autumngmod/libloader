file.CreateDir("libloader")

libloader.fs = {}

---@param repo string
---@param version string
---@return string
function libloader.fs:getLibPath(repo, version)
  local splitted = repo:Split("/")
  local org = splitted[1]
  local repo = splitted[2]

  return "libloader/" .. org .. "/" .. repo .. "/v" .. version .. "/lib.txt"
end

function libloader.fs:write(repo, version, content)
  local path = self:getLibPath(repo, version)
  local dir = path:GetPathFromFilename()

  file.CreateDir(dir)

  file.Write(path, content)
end

function libloader.fs:delete(repo, version)
  local path = self:getLibPath(repo, version)

  file.Delete(path, "DATA")
end