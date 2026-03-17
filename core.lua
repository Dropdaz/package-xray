-- Package-Xray - A Neovim-inspired CLI Package Manager
-- Copyright (C) 2026 Ernesto Vives Femenia
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
-- Contact: ernestovivesxalo@gmail.com | https://github.com/Dropdaz

local M = {}

-- Helper to run shell commands and capture output
local function capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

-- Get APT packages
function M.get_apt_packages()
  -- Get user-installed packages
  local manual_output = capture("apt-mark showmanual 2>/dev/null")
  local manual_set = {}
  for line in manual_output:gmatch("[^\r\n]+") do
    manual_set[line] = true
  end

  local packages = {}
  -- Fetch Package, Version, Status, Priority, and Essential flag
  local output = capture("dpkg-query -W -f='${Package}|${Version}|${Status}|${Priority}|${Essential}\n' 2>/dev/null")
  for line in output:gmatch("[^\r\n]+") do
    local name, version, status, priority, essential = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    if status and status:find("installed") then
      -- A package is "User" if it's marked manual AND it's not a core system component
      local is_core = (priority == "required" or priority == "important" or essential == "yes")
      local is_user = manual_set[name] and not is_core
      
      table.insert(packages, {
        name = name,
        version = version,
        source = "APT",
        description = "",
        is_user = is_user
      })
    end
  end
  return packages
end

-- Get Snap packages
function M.get_snap_packages()
  local packages = {}
  local output = capture("snap list 2>/dev/null")
  local first = true
  for line in output:gmatch("[^\r\n]+") do
    if first then
      first = false
    else
      local name, version = line:match("([^%s]+)%s+([^%s]+)")
      if name then
        table.insert(packages, {
          name = name,
          version = version,
          source = "Snap",
          description = "",
          is_user = true
        })
      end
    end
  end
  return packages
end

-- Get Flatpak packages
function M.get_flatpak_packages()
  local packages = {}
  local output = capture("flatpak list --columns=application,version 2>/dev/null")
  for line in output:gmatch("[^\r\n]+") do
    local name, version = line:match("([^%s]+)%s+([^%s]+)")
    if name then
      table.insert(packages, {
        name = name,
        version = version,
        source = "Flatpak",
        description = "",
        is_user = true
      })
    end
  end
  return packages
end

-- Get Manual apps (.desktop files not owned by package managers)
function M.get_manual_apps()
  local apps = {}
  local paths = {
    "/usr/share/applications/",
    os.getenv("HOME") .. "/.local/share/applications/"
  }
  
  for _, path in ipairs(paths) do
    local p = io.popen("ls " .. path .. "/*.desktop 2>/dev/null")
    if p then
      for file in p:lines() do
        local name = file:match("([^/]+)%.desktop$")
        table.insert(apps, {
          name = name,
          version = "Manual",
          source = "Desktop",
          description = "Standalone application",
          is_user = true,
          path = file -- Store absolute path for deletion
        })
      end
      p:close()
    end
  end
  return apps
end

function M.get_all_packages()
  local apt = M.get_apt_packages()
  local snap = M.get_snap_packages()
  local flatpak = M.get_flatpak_packages()
  
  -- Build a lookup set of known package names
  local known = {}
  for _, p in ipairs(apt) do known[p.name:lower()] = true end
  for _, p in ipairs(snap) do known[p.name:lower()] = true end
  for _, p in ipairs(flatpak) do known[p.name:lower()] = true end
  
  local manual = M.get_manual_apps()
  local orphaned = {}
  for _, app in ipairs(manual) do
    if not known[app.name:lower()] then
      table.insert(orphaned, app)
    end
  end
  
  local all = {}
  for _, src in ipairs({apt, snap, flatpak, orphaned}) do
    for _, pkg in ipairs(src) do
      table.insert(all, pkg)
    end
  end
  return all
end

-- Sorting and Grouping
function M.group_packages(packages)
  local groups = {
    ["All"] = {}, -- Added global group
    ["Apps"] = {},
    ["Snaps"] = {},
    ["Flatpaks"] = {},
    ["Packages"] = {}
  }
  
  for _, pkg in ipairs(packages) do
    table.insert(groups["All"], pkg) -- Add to global group
    if pkg.source == "Snap" then
      table.insert(groups["Snaps"], pkg)
    elseif pkg.source == "Flatpak" then
      table.insert(groups["Flatpaks"], pkg)
    elseif pkg.source == "Desktop" then
      table.insert(groups["Apps"], pkg)
    else
      table.insert(groups["Packages"], pkg)
    end
  end
  
  -- Remove empty groups
  local final_groups = {}
  for k, v in pairs(groups) do
    if #v > 0 then
      final_groups[k] = v
    end
  end
  
  return final_groups
end

-- Get detailed information for a specific package
function M.get_package_details(name, source)
  local info = {}
  if source == "APT" then
    local output = capture("apt-cache show " .. name .. " 2>/dev/null")
    -- apt-cache show can return multiple records, take the first one
    local record = output:match("(Package:.-)\n\n") or output
    info.description = record:match("\nDescription%-[^:]+: (.-)\n%S") or record:match("\nDescription: (.-)\n%S") or record:match("\nDescription: (.*)$")
    info.maintainer = record:match("\nMaintainer: (.-)\n")
    info.homepage = record:match("\nHomepage: (.-)\n")
    info.section = record:match("\nSection: (.-)\n")
    info.size = record:match("\nSize: (.-)\n")
  elseif source == "Snap" then
    local output = capture("snap info " .. name .. " 2>/dev/null")
    info.description = output:match("\nsummary: (.-)\n")
    if info.description then
      local long_desc = output:match("\ndescription: |?\n(.-)\ncommands:") or output:match("\ndescription: |?\n(.-)\nsnap-id:")
      if long_desc then info.description = info.description .. "\n\n" .. long_desc:gsub("^%s+", "") end
    end
    info.maintainer = output:match("\npublisher: (.-)\n")
    info.homepage = output:match("\nwebsite: (.-)\n") or output:match("\ncontact: (.-)\n")
  elseif source == "Flatpak" then
    local output = capture("flatpak info " .. name .. " 2>/dev/null")
    info.description = output:match("\nDescription: (.-)\n")
    info.maintainer = output:match("\nOrigin: (.-)\n")
    info.homepage = output:match("\nDownload: (.-)\n")
  else
    info.description = "Manual application entry."
  end
  
  -- Cleanup description newlines and formatting
  if info.description then
    info.description = info.description:gsub("\n%s+%.", "\n"):gsub("\n%s+", " ")
  end
  return info
end

-- Open a URL in the browser (supports WSL host and native Linux)
function M.open_url(url)
  local is_wsl = capture("grep -i microsoft /proc/version"):lower():find("microsoft")
  if is_wsl then
    -- WSL: Use PowerShell to open on Windows host
    local cmd = string.format("powershell.exe -NoProfile -Command \"Start-Process '%s'\"", url)
    os.execute(cmd .. " 2>/dev/null")
  else
    -- Native Linux: Use xdg-open
    vim.fn.jobstart({"xdg-open", url}, {detach = true})
  end
end

-- Batch uninstall packages with verification and error capture
function M.uninstall_packages(package_list, on_progress)
  local results = {}
  for i, pkg in ipairs(package_list) do
    if on_progress then on_progress(i, pkg.name) end
    
    local cmd = ""
    local verify_cmd = ""
    
    if pkg.source == "APT" then
      cmd = "sudo apt-get purge -y " .. pkg.name
      verify_cmd = "dpkg -l " .. pkg.name .. " 2>/dev/null | grep -q '^ii'"
    elseif pkg.source == "Snap" then
      cmd = "sudo snap remove " .. pkg.name
      verify_cmd = "snap list " .. pkg.name .. " 2>/dev/null"
    elseif pkg.source == "Flatpak" then
      cmd = "sudo flatpak uninstall -y " .. pkg.name
      verify_cmd = "flatpak info " .. pkg.name .. " 2>/dev/null"
    elseif pkg.source == "Desktop" and pkg.path then
      cmd = "rm -f '" .. pkg.path .. "'"
      verify_cmd = "[ ! -f '" .. pkg.path .. "' ]"
    end
    
    local reason = ""
    if cmd ~= "" then
      -- Primary command
      local output = vim.fn.system(cmd .. " 2>&1")
      local cmd_success = (vim.v.shell_error == 0)
      
      -- Independent verification
      vim.fn.system(verify_cmd)
      local is_removed = (pkg.source == "Desktop" and vim.v.shell_error == 0 or vim.v.shell_error ~= 0)
      
      local success = is_removed -- If it's gone, it's a success
      
      if not success then
        reason = output:match("([^\n]+)\n?$") or "Removal verification failed"
      else
        reason = "Cleanly removed"
      end
      
      table.insert(results, { 
        name = pkg.name, 
        version = pkg.version or "unknown",
        source = pkg.source, 
        success = success,
        reason = reason
      })
    end
  end
  
  -- Save results to persistent session-based log
  M.save_activity_log("Uninstall", results)
  
  return results
end

-- Professional Session Logging
local LOG_BASE_DIR = vim.fn.getcwd() .. "/logs"

function M.save_activity_log(type, results)
  if #results == 0 then return end
  
  os.execute("mkdir -p " .. LOG_BASE_DIR)
  
  local timestamp = os.date("%d-%m-%Y_%H-%M")
  local filename = string.format("%s/%s_%s.json", LOG_BASE_DIR, timestamp, type)
  
  local session = {
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    type = type,
    packages = results
  }
  
  local f = io.open(filename, "w")
  if f then
    f:write(vim.fn.json_encode(session))
    f:close()
  end
end

function M.get_activity_sessions()
  local sessions = {}
  local p = io.popen("ls " .. LOG_BASE_DIR .. "/*.json 2>/dev/null")
  if p then
    for file in p:lines() do
      local name = file:match("([^/]+)%.json$")
      table.insert(sessions, { name = name, path = file })
    end
    p:close()
  end
  -- Sort by filename (date/time) reversed
  table.sort(sessions, function(a, b) return a.name > b.name end)
  return sessions
end

function M.get_session_details(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return vim.fn.json_decode(content)
end

function M.clear_activity_logs()
  os.execute("rm -f " .. LOG_BASE_DIR .. "/*.json")
  return true
end

-- Revert/Install Logic
function M.reinstall_package(pkg)
  local cmd = ""
  local fallback_cmd = ""
  
  if pkg.source == "APT" then
    -- Try to install specific version, with fallback to latest available
    cmd = string.format("sudo apt-get install -y %s=%s", pkg.name, pkg.version)
    fallback_cmd = string.format("sudo apt-get install -y %s", pkg.name)
  elseif pkg.source == "Snap" then
    cmd = "sudo snap install " .. pkg.name
  elseif pkg.source == "Flatpak" then
    cmd = "sudo flatpak install -y flathub " .. pkg.name
  end
  
  if cmd ~= "" then
    local output = vim.fn.system(cmd .. " 2>&1")
    local success = (vim.v.shell_error == 0)
    local reason = ""
    
    -- Robust fallback for APT pinned versions
    if not success and fallback_cmd ~= "" then
      local fb_output = vim.fn.system(fallback_cmd .. " 2>&1")
      success = (vim.v.shell_error == 0)
      if success then
        reason = "Restored (Latest version, pin failed: " .. (output:match("([^\n]+)\n?$") or "unknown") .. ")"
      else
        reason = fb_output:match("([^\n]+)\n?$") or "Revert failed"
      end
    else
      reason = success and "Successfully restored" or (output:match("([^\n]+)\n?$") or "Unknown error")
    end
    
    -- Log this installation event
    M.save_activity_log("Install", {{
      name = pkg.name,
      version = pkg.version,
      source = pkg.source,
      success = success,
      reason = reason
    }})
    
    return success, reason
  end
  return false, "Unsupported source for automatic revert"
end

return M
