-- sc-plugins-arm64
-- 64-bit ARM SC plugins installer
--
-- Detects your architecture and installs
-- the correct community SC plugin binaries.
-- Replaces schollz/supercollider-plugins
-- on 64-bit ARM systems.

local RELEASE_URL = "https://github.com/seajaysec/sc-plugins-arm64/releases/download/v0.1.0/sc-plugins-arm64.tar.gz"
local EXTENSIONS = "/home/we/.local/share/SuperCollider/Extensions"

local state = "checking"
local message = ""
local arch = ""
local installed_count = 0
local is_arm64 = false

function init()
  -- detect architecture
  local f = io.popen("uname -m")
  arch = f:read("*a"):gsub("%s+", "")
  f:close()

  is_arm64 = (arch == "aarch64" or arch == "arm64")

  -- count existing .so files
  f = io.popen("find " .. EXTENSIONS .. " -name '*.so' 2>/dev/null | wc -l")
  installed_count = tonumber(f:read("*a"):gsub("%s+", "")) or 0
  f:close()

  if not is_arm64 then
    state = "wrong_arch"
    message = "This installer is for aarch64.\nYour system is " .. arch .. ".\nUse schollz/supercollider-plugins instead."
  elseif installed_count > 30 then
    state = "already_installed"
    message = installed_count .. " plugins already installed.\nK3 to reinstall, or you're done."
  else
    state = "ready"
    message = arch .. " detected. " .. installed_count .. " plugins found.\nK3 to install 64-bit SC plugins."
  end

  redraw()
end

function key(n, z)
  if z ~= 1 then return end

  if n == 3 and is_arm64 and (state == "ready" or state == "already_installed") then
    clock.run(function()
      do_install()
    end)
  end
end

function do_install()
  state = "installing"
  message = "Downloading plugins..."
  redraw()

  os.execute("mkdir -p " .. EXTENSIONS)
  os.execute("wget -q -O /tmp/sc-plugins-arm64.tar.gz " .. RELEASE_URL)

  message = "Extracting..."
  redraw()

  os.execute("tar xzf /tmp/sc-plugins-arm64.tar.gz -C " .. EXTENSIONS .. "/../")
  os.execute("rm -f /tmp/sc-plugins-arm64.tar.gz")

  -- strip any 32-bit .so files that might be mixed in
  os.execute([[
    for f in $(find ]] .. EXTENSIONS .. [[ -name "*.so" 2>/dev/null); do
      case "$(file -b "$f")" in *32-bit*) rm -f "$f" ;; esac
    done
  ]])

  -- count what we installed
  local f = io.popen("find " .. EXTENSIONS .. " -name '*.so' 2>/dev/null | wc -l")
  installed_count = tonumber(f:read("*a"):gsub("%s+", "")) or 0
  f:close()

  state = "done"
  message = installed_count .. " plugins installed.\nGo to SYSTEM > RESTART\nthen load your script."
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)

  screen.move(64, 10)
  screen.text_center("sc-plugins-arm64")

  screen.level(4)
  screen.move(64, 20)
  screen.text_center("community SC plugins for 64-bit ARM")

  screen.level(15)
  local y = 35
  for line in message:gmatch("[^\n]+") do
    screen.move(64, y)
    screen.text_center(line)
    y = y + 10
  end

  screen.update()
end

function enc(n, d) end
function cleanup() end
