if (SERVER) then
  util.AddNetworkString("lib.load")
  util.AddNetworkString("lib.loadu") -- servers notification

  ---@param client? Player
  local function sendCachedLibraries(client)
    local cache = libloader.db:getCache()

    if (#cache == 0) then
      return
    end

    net.Start("lib.load")
    net.WriteUInt(#cache, 16)

    for _, v in ipairs(cache) do
      local key = next(v)
      net.WriteString(key) -- key
      net.WriteString(v[key]) -- value
    end

    if (IsValid(client)) then
      ---@diagnostic disable-next-line: param-type-mismatch
      net.Send(client)
    else
      net.Broadcast()
    end
  end

  hook.Add("libCacheUpdated", "_libloader", function()
    sendCachedLibraries()
  end)

  net.Receive("lib.load", function(_, client)
    sendCachedLibraries(client)
  end)

  -- if you put everything in one file, then return can break everything here.
  -- return
else
  --- Disables all client's installed libraries
  ---
  ---@private
  function libloader:disableLibraries()
    local installed = self.db:getInstalled()

    for _, lib in ipairs(installed) do
      if (lib.enabled == "1") then
        self.db:disable(lib.repo, lib.version)
      end
    end
  end

  net.Receive("lib.load", function(len)
    if (libloader:isBusy()) then
      return -- idi nahui lol
    end

    local list = {}
    local size = net.ReadUInt(16)

    for i=1, size do
      --        org/repo            = version
      list[i] = {[net.ReadString()] = net.ReadString()}
    end

    libloader:disableLibraries()

    local co = coroutine.create(function()
      libloader:downloadMany(list, true)
    end)

    coroutine.resume(co)
  end)

  local function getLibraries()
    net.Start("lib.load")
    net.SendToServer()
  end

  net.Receive("lib.loadu", getLibraries)

  timer.Simple(0, getLibraries)
end