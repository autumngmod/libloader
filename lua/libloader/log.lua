libloader.log = {}
libloader.log.greyColor = Color(200, 200, 200)
libloader.log.orangeColor = Color(255, 204, 0)

local libloaderColor = Color(255, 0, 0)
local greyColor = libloader.log.greyColor
local orangeColor = libloader.log.orangeColor

function libloader.log.log(msg)
  MsgC(libloaderColor, "[libLoader]", greyColor, " ", msg)
  MsgN()
end

function libloader.log.empty(msg)
  MsgC(greyColor, " ", msg)
  MsgN()
end

if (not LIBLOADER_INITIALIZED) then
  LIBLOADER_INITIALIZED = true
  libloader.log.log(("Loading libLoader v%s by smokingplaya"):format(libloader.version))
end

function libloader.log.custom(...)
  MsgC(libloaderColor, "[libLoader] ", greyColor, ...)
  MsgN()
end

local redColor = Color(200, 10, 25)
---@param msg string
function libloader.log.err(msg)
  MsgC(libloaderColor, "[libLoader]", " ", redColor, msg)
  MsgN()
end

---@param msg string
function libloader.log.warn(msg)
  MsgC(libloaderColor, "[libLoader]", " ", orangeColor, msg)
  MsgN()
end