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

local core = require("core")

local M = {}

-- Tokyonight palette
local colors = {
  bg = "#1a1b26",
  fg = "#a9b1d6",
  blue = "#7aa2f7",
  magenta = "#bb9af7",
  orange = "#ff9e64",
  green = "#9ece6a",
  red = "#f7768e",
  selection = "#292e42",
  dim = "#565f89",
}
local main_win, side_win, help_win, search_win, search_buf, side_buf, main_buf, help_buf
local log_side_win, log_main_win, log_side_buf, log_main_buf

local view_mode = "explorer" -- "explorer" or "logs"
local logs_sessions = {}
local selected_session_idx = 1
local session_details = nil
local selected_log_pkg_idx = 1
local log_focus = "side" -- "side" or "main"

local packages = {}
local grouped_pkgs = {}
local categories = {}
local active_cat_idx = 1
local selected_item_idx = 1
local expanded_folders = {}
local search_query = ""
local marked_packages = {} -- map of pkg_name -> pkg_object

function M.setup_highlights()
  vim.o.termguicolors = true
  vim.o.mouse = "a"
  vim.o.laststatus = 0
  vim.o.showmode = false
  vim.o.ruler = false
  vim.o.showcmd = false
  vim.cmd("set guicursor=a:block") 
  
  vim.api.nvim_set_hl(0, "Normal", { bg = colors.bg, fg = colors.fg })
  vim.api.nvim_set_hl(0, "PkgrayTitle", { fg = colors.blue, bold = true })
  vim.api.nvim_set_hl(0, "PkgrayDim", { fg = colors.dim })
  vim.api.nvim_set_hl(0, "PkgraySelected", { bg = colors.selection, fg = colors.blue, bold = true })
  vim.api.nvim_set_hl(0, "PkgrayMarked", { bg = "#332b33", fg = colors.red, bold = true })
  vim.api.nvim_set_hl(0, "PkgrayHeader", { bg = colors.blue, fg = colors.bg, bold = true })
  vim.api.nvim_set_hl(0, "PkgrayBorder", { fg = colors.dim })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = colors.blue })
end

function M.draw_dashboard()
  -- Reset Neovim to a clean state
  vim.cmd("only")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  
  local ui_info = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local use_simple = ui_info.width < 55 or ui_info.height < 15
  
  local lines = {}
  if use_simple then
    lines = {
      "",
      "   [#] PKG-RAY (v1.0.0)",
      "   -------------------",
      "   [e] Explore Inventory",
      "   [q] Quit System",
      ""
    }
  else
    lines = {
      "", "", "",
      "   ██████╗ ██╗  ██╗ ██████╗ ██████╗  █████╗ ██╗   ██╗",
      "   ██╔══██╗██║ ██╔╝██╔════╝ ██╔══██╗██╔══██╗╚██╗ ██╔╝",
      "   ██████╔╝█████╔╝ ██║  ███╗██████╔╝███████║ ╚████╔╝ ",
      "   ██╔═══╝ ██╔═██╗ ██║   ██║██╔══██╗██╔══██║  ╚██╔╝  ",
      "   ██║     ██║  ██╗╚██████╔╝██║  ██║██║  ██║   ██║   ",
      "   ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ",
      "",
      "  ─────────── Package Audit Engine ───────────",
      "           Version 1.0.0 (Stable)         ",
      "",
      "     |   [e] Explore System Inventory     |    ",
      "     |   [l] Activity & Recovery Console  |    ",
      "     |   [q] Exit Application             |    ",
      "",
      "    Powered by Neovim & Debian Engine    ",
    }
  end
  
  -- Center lines
  local centered_lines = {}
  local v_padding = math.floor((ui_info.height - #lines) / 2)
  for _ = 1, v_padding do table.insert(centered_lines, "") end
  for _, line in ipairs(lines) do
    local display_width = vim.fn.strdisplaywidth(line)
    local h_padding = math.floor((ui_info.width - display_width) / 2)
    table.insert(centered_lines, string.rep(" ", math.max(0, h_padding)) .. line)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, centered_lines)
  
  -- Highlighting Dashboard
  for i = 0, #centered_lines - 1 do
    local line = centered_lines[i+1]
    if line:find("─") or line:find("█") then
      vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayBorder", i, 0, -1)
    end
    if line:find("▄▄▄▄") or line:find("PKG RAY") then
      vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayTitle", i, 0, -1)
    end
  end
  
  -- Resize listener for dashboard
  local dashboard_group = vim.api.nvim_create_augroup("PkgrayDashboard", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = dashboard_group,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
          M.draw_dashboard()
        end
      end)
    end
  })

  vim.keymap.set('n', 'e', M.open_explorer, { buffer = buf })
  vim.keymap.set('n', 'l', M.open_log_explorer, { buffer = buf })
  vim.keymap.set('n', 'q', ':qa!<CR>', { buffer = buf })
end

  function M.inject_scroll_indicators(lines, selected_idx, win)
    local max_vis = vim.api.nvim_win_get_height(win) - 2
    local total = #lines
    local orig_to_vis = {}
    
    if total > max_vis then
      local start_idx = math.max(1, selected_idx - math.floor(max_vis / 2))
      if start_idx + max_vis > total then start_idx = math.max(1, total - max_vis + 1) end
      
      local visible_lines = {}
      local show_up = start_idx > 1
      local show_down = (start_idx + max_vis - 1) < total
      
      local limit = max_vis
      if show_up then limit = limit - 1 end
      if show_down then limit = limit - 1 end
      
      if show_up then table.insert(visible_lines, "   ▲ ▲ ▲ SCROLL UP ▲ ▲ ▲") end
      
      for i = start_idx, math.min(total, start_idx + limit - 1) do
        table.insert(visible_lines, lines[i])
        orig_to_vis[i] = #visible_lines
      end
      
      if show_down then table.insert(visible_lines, "   ▼ ▼ ▼ SCROLL DOWN ▼ ▼ ▼") end
      
      return visible_lines, show_up, orig_to_vis
    end
    
    for i = 1, total do orig_to_vis[i] = i end
    return lines, false, orig_to_vis
  end

function M.open_explorer()
  vim.cmd("only")
  search_buf = vim.api.nvim_create_buf(false, true)
  side_buf = vim.api.nvim_create_buf(false, true)
  main_buf = vim.api.nvim_create_buf(false, true)
  help_buf = vim.api.nvim_create_buf(false, true)
  
  view_mode = "explorer"
  selected_item_idx = 1
  
  -- Layout setup  
  vim.cmd("vsplit")
  local wins = vim.api.nvim_list_wins()
  side_win = wins[1]
  main_win = wins[2]
  vim.api.nvim_win_set_buf(side_win, side_buf)
  vim.api.nvim_win_set_buf(main_win, main_buf)
  vim.api.nvim_win_set_width(side_win, 30)
  
  vim.wo[side_win].fillchars = "eob: "
  vim.wo[main_win].fillchars = "eob: "
  
  -- Fetch initial data
  packages = core.get_all_packages()
  grouped_pkgs = core.group_packages(packages)
  categories = {}
  for cat, _ in pairs(grouped_pkgs) do table.insert(categories, cat) end
  table.sort(categories)

  -- Forward declarations for recursive calls or cross-references
  local redraw_main, redraw_side, redraw_help
  local get_visible_items, move_down, move_up
  
  local function group_pkgs(pkgs, folder_prefix, base_level)
    base_level = base_level or 0
    local filtered = {}
    if search_query ~= "" then
      local q = search_query:lower()
      for _, p in ipairs(pkgs) do
        if p.name:lower():find(q, 1, true) then table.insert(filtered, p) end
      end
    else
      filtered = pkgs
    end
    
    if #filtered == 0 then return {} end
    
    local prefix_counts = {}
    for _, p in ipairs(filtered) do
      local raw_prefix = p.name:match("^([^-_]+)[-_]") or p.name
      local prefix = raw_prefix:gsub("[%d%.]+$", "")
      if prefix ~= p.name and #prefix > 1 then
        prefix_counts[prefix] = (prefix_counts[prefix] or 0) + 1
      end
    end
    
    local visible = {}
    local groups = {}
    local ungrouped = {}
    
    for prefix, count in pairs(prefix_counts) do
      if count >= 3 then groups[prefix] = { count = 0, pkgs = {} } end
    end
    
    for _, p in ipairs(filtered) do
      local matched = false
      for prefix, g in pairs(groups) do
        if p.name:sub(1, #prefix) == prefix then
          table.insert(g.pkgs, p)
          g.count = g.count + 1
          matched = true
          break
        end
      end
      if not matched then table.insert(ungrouped, p) end
    end
    
    local sorted_prefixes = {}
    for p, _ in pairs(groups) do table.insert(sorted_prefixes, p) end
    table.sort(sorted_prefixes)
    
    for _, prefix in ipairs(sorted_prefixes) do
      local g = groups[prefix]
      local folder_id = (folder_prefix or "") .. ":" .. prefix
      local is_exp = expanded_folders[folder_id] or false
      
      table.insert(visible, { is_folder = true, name = prefix, count = g.count, id = folder_id, level = base_level })
      if is_exp then
        for _, p in ipairs(g.pkgs) do
          local p_copy = vim.deepcopy(p)
          p_copy.level = base_level + 1
          table.insert(visible, p_copy)
        end
      end
    end
    
    for _, p in ipairs(ungrouped) do
      local p_copy = vim.deepcopy(p)
      p_copy.level = base_level
      table.insert(visible, p_copy)
    end
    return visible
  end
  
  get_visible_items = function()
    local cat = categories[active_cat_idx]
    local all_pkgs = grouped_pkgs[cat]
    local system_pkgs = {}
    local user_pkgs = {}
    
    for _, p in ipairs(all_pkgs) do
      if not p.is_user then table.insert(system_pkgs, p)
      else table.insert(user_pkgs, p) end
    end
    
    local visible = {}
    if #system_pkgs > 0 then
      local sys_grouped = group_pkgs(system_pkgs, "Default", 1)
      if #sys_grouped > 0 then
        local is_exp = expanded_folders["Default"] or false
        
        table.insert(visible, { is_folder = true, name = "Default", count = #system_pkgs, id = "Default", level = 0 })
        if is_exp then
          for _, item in ipairs(sys_grouped) do table.insert(visible, item) end
        end
      end
    end
    
    local user_items = group_pkgs(user_pkgs, "User", 0)
    for _, item in ipairs(user_items) do table.insert(visible, item) end
    return visible
  end
  
  redraw_main = function()
    local items = get_visible_items()
    local lines = { string.format(" %-45s %-20s %s", "Package", "Version", "Source"), string.rep("─", vim.api.nvim_win_get_width(main_win) - 2) }
    
    for i, item in ipairs(items) do
      local level = item.level or 0
      local indent = string.rep("  ", level)
      if item.is_folder then
        local is_exp = expanded_folders[item.id] or false
        table.insert(lines, string.format("   %s%s %-42s (%d)", indent, is_exp and "v" or ">", item.name, item.count))
      else
        local marker = marked_packages[item.name] and "[x]" or "   "
        table.insert(lines, string.format(" %s %s%-42s %-20s %s", marker, indent, item.name, item.version, item.source))
      end
    end
    
    local vis_lines, has_up, orig_to_vis = M.inject_scroll_indicators(lines, selected_item_idx + 2, main_win)
    vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, vis_lines)
    
    -- Highlights
    vim.api.nvim_buf_clear_namespace(main_buf, -1, 0, -1)
    
    if has_up then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgraySelected", 0, 0, -1) end
    if orig_to_vis[1] then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgrayHeader", orig_to_vis[1] - 1, 0, -1) end
    if orig_to_vis[2] then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgrayHeader", orig_to_vis[2] - 1, 0, -1) end
    if vis_lines[#vis_lines] and vis_lines[#vis_lines]:match("SCROLL DOWN") then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgraySelected", #vis_lines - 1, 0, -1) end
    
    local actual_selected_line = -1
    if orig_to_vis[selected_item_idx + 2] then
      actual_selected_line = orig_to_vis[selected_item_idx + 2]
      vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgraySelected", actual_selected_line - 1, 0, -1)
    end
    
    for i, item in ipairs(items) do
      local vis_idx = orig_to_vis[i + 2]
      if vis_idx then
        if item.is_folder then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgrayTitle", vis_idx - 1, 0, -1)
        elseif marked_packages[item.name] then vim.api.nvim_buf_add_highlight(main_buf, -1, "PkgrayMarked", vis_idx - 1, 0, -1) end
      end
    end
    
    if actual_selected_line > 0 then
      pcall(vim.api.nvim_win_set_cursor, main_win, { actual_selected_line, 0 })
    end
  end
  
  redraw_side = function()
    local lines = {}
    local query = search_query:lower()
    for i, cat in ipairs(categories) do
      local pkgs = grouped_pkgs[cat]
      local count = 0
      if query == "" then
        count = #pkgs
      else
        for _, p in ipairs(pkgs) do
          if p.name:lower():find(query, 1, true) then count = count + 1 end
        end
      end
      local prefix = (i == active_cat_idx) and " > " or "   "
      table.insert(lines, string.format("%s%-15s (%d)", prefix, cat, count))
    end
    
    local vis_lines, has_up, orig_to_vis = M.inject_scroll_indicators(lines, active_cat_idx, side_win)
    vim.api.nvim_buf_set_lines(side_buf, 0, -1, false, vis_lines)
    vim.api.nvim_buf_clear_namespace(side_buf, -1, 0, -1)
    
    if has_up then vim.api.nvim_buf_add_highlight(side_buf, -1, "PkgraySelected", 0, 0, -1) end
    if vis_lines[#vis_lines] and vis_lines[#vis_lines]:match("SCROLL DOWN") then vim.api.nvim_buf_add_highlight(side_buf, -1, "PkgraySelected", #vis_lines - 1, 0, -1) end
    
    local actual_selected_line = -1
    if orig_to_vis[active_cat_idx] then
      actual_selected_line = orig_to_vis[active_cat_idx]
      vim.api.nvim_buf_add_highlight(side_buf, -1, "PkgraySelected", actual_selected_line - 1, 0, -1)
      pcall(vim.api.nvim_win_set_cursor, side_win, { actual_selected_line, 0 })
    end
  end

  -- New: Mark/Unmark package
  local function toggle_mark()
    local item = get_visible_items()[selected_item_idx]
    if item and not item.is_folder then
      if marked_packages[item.name] then
        marked_packages[item.name] = nil
      else
        marked_packages[item.name] = item
      end
      redraw_main()
    end
  end

  -- Mark all visible packages (Toggle behavior)
  local function mark_all()
    local items = get_visible_items()
    local all_marked = true
    local pkg_items = {}
    
    for _, item in ipairs(items) do
      if not item.is_folder then
        table.insert(pkg_items, item)
        if not marked_packages[item.name] then
          all_marked = false
        end
      end
    end
    
    if #pkg_items == 0 then return end
    
    if all_marked then
      -- Deselect all visible
      for _, item in ipairs(pkg_items) do
        marked_packages[item.name] = nil
      end
    else
      -- Select all visible
      for _, item in ipairs(pkg_items) do
        marked_packages[item.name] = item
      end
    end
    redraw_main()
  end

  -- New: Start uninstall process
  local function start_uninstall()
    local marked_list = {}
    for _, pkg in pairs(marked_packages) do table.insert(marked_list, pkg) end
    if #marked_list == 0 then
      vim.notify("No packages marked for uninstall.", vim.log.levels.INFO)
      return
    end

    M.show_uninstall_confirm(marked_list, function()
      local progress = M.show_progress(#marked_list)
      
      local results = core.uninstall_packages(marked_list, function(idx, name)
        progress.update(idx, name)
      end)
      
      -- Final state: Pass verification results!
      progress.finish(results)
      
      -- Refresh and reset (background)
      marked_packages = {}
      packages = core.get_all_packages()
      grouped_pkgs = core.group_packages(packages)
      categories = {}
      for cat, _ in pairs(grouped_pkgs) do table.insert(categories, cat) end
      table.sort(categories)
      
      active_cat_idx = 1
      selected_item_idx = 1
      redraw_side()
      redraw_main()
    end)
  end

  redraw_help = function()
    local lines = {
      " [ NAVIGATION ]",
      "  ↑/↓/k/j : Navigate list",
      "  ←/→/h/l : Panes / Folders",
      "  Enter   : Details / Folder",
      "  /       : Focus search",
      "",
      " [ SELECTION ]",
      "  Space   : Mark / Unmark",
      "  a       : Mark all visible",
      "  U       : Uninstall marked",
      "",
      " [ SYSTEM ]",
      "  r       : Refresh list",
      "  Esc     : Dashboard",
      "  q       : Quit system",
      "",
      " [ Search Mode: Esc=Exit ]"
    }
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(help_buf, -1, 0, -1)
    for i = 0, #lines - 1 do
      local line = lines[i+1]
      if line:find("^ %-") or line:find("^ %[") then
        vim.api.nvim_buf_add_highlight(help_buf, -1, "PkgrayHeader", i, 1, -1)
      else
        vim.api.nvim_buf_add_highlight(help_buf, -1, "PkgrayDim", i, 2, 9)
        vim.api.nvim_buf_add_highlight(help_buf, -1, "PkgrayTitle", i, 12, -1)
      end
    end
  end

  local ns_search = vim.api.nvim_create_namespace("pkgray_search")
  
  open_search_palette = function()
    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local width = math.min(60, math.floor(ui.width * 0.6))
    
    if search_win and vim.api.nvim_win_is_valid(search_win) then
      vim.api.nvim_set_current_win(search_win)
      vim.cmd("startinsert!")
      return
    end
    
    search_win = vim.api.nvim_open_win(search_buf, true, {
      relative = "editor",
      row = math.floor(ui.height * 0.2),
      col = math.floor((ui.width - width) / 2),
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      title = " * SEARCH APPS * ",
      title_pos = "center"
    })
    
    vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, { search_query == "" and "  " or "  " .. search_query })
    
    if search_query == "" then
      vim.api.nvim_buf_set_extmark(search_buf, ns_search, 0, 0, {
        virt_text = {{"[ Type to search packages... ]", "PkgrayDim"}},
        virt_text_pos = "overlay",
        hl_mode = "combine"
      })
    end
    
    vim.cmd("startinsert!")
  end

  move_down = function()
    local cur_win = vim.api.nvim_get_current_win()
    if cur_win == side_win then
      active_cat_idx = math.min(#categories, active_cat_idx + 1)
      selected_item_idx = 1
      redraw_side() redraw_main()
    else
      selected_item_idx = math.min(#get_visible_items(), selected_item_idx + 1)
      redraw_main()
    end
  end
  
  move_up = function()
    local cur_win = vim.api.nvim_get_current_win()
    if cur_win == side_win then
      if active_cat_idx > 1 then
        active_cat_idx = active_cat_idx - 1
        selected_item_idx = 1
        redraw_side() redraw_main()
      end
    else
      if selected_item_idx > 1 then
        selected_item_idx = selected_item_idx - 1
        redraw_main()
      end
    end
  end

  -- Help Window Setup (Bottom Right)
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  help_win = vim.api.nvim_open_win(help_buf, false, {
    relative = "editor",
    row = ui.height - 21,
    col = ui.width - 45,
    width = 45,
    height = 19,
    style = "minimal",
    border = "rounded",
    title = " * CONTROLS * ",
    title_pos = "center"
  })
  
  local function on_search_change()
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(search_buf) then return end
      local lines = vim.api.nvim_buf_get_lines(search_buf, 0, -1, false)
      local new_query = vim.trim(lines[1] or "")
      
      vim.api.nvim_buf_clear_namespace(search_buf, ns_search, 0, -1)
      
      if (lines[1] or ""):sub(1,2) ~= "  " then
        vim.api.nvim_buf_set_lines(search_buf, 0, 1, false, { "  " .. new_query })
        pcall(vim.api.nvim_win_set_cursor, search_win, {1, #new_query + 2})
      end
      
      if new_query == "" and vim.api.nvim_get_mode().mode ~= 'i' then
        vim.api.nvim_buf_set_extmark(search_buf, ns_search, 0, 0, {
          virt_text = {{"[ Type to search packages... ]", "PkgrayDim"}},
          virt_text_pos = "overlay",
          hl_mode = "combine"
        })
      end
      
      if new_query ~= search_query then
        search_query, selected_item_idx = new_query, 1
        redraw_side() redraw_main()
      end
    end)
  end
  
  vim.api.nvim_buf_attach(search_buf, false, { on_lines = on_search_change })
  
  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = search_buf,
    callback = function()
      vim.api.nvim_buf_clear_namespace(search_buf, ns_search, 0, -1)
    end
  })
  
  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = search_buf,
    callback = function()
      if search_query == "" then
        vim.api.nvim_buf_set_extmark(search_buf, ns_search, 0, 0, {
          virt_text = {{"[ Type to search packages... ]", "PkgrayDim"}},
          virt_text_pos = "overlay",
          hl_mode = "combine"
        })
      end
      pcall(vim.api.nvim_win_close, search_win, true)
      search_win = nil
    end
  })

  vim.keymap.set('i', '<CR>', function()
    vim.cmd("stopinsert")
  end, { buffer = search_buf })
  vim.keymap.set('i', '<Esc>', function()
    vim.cmd("stopinsert")
  end, { buffer = search_buf })
  vim.keymap.set('i', '<Tab>', '<Esc>', { buffer = search_buf })
  vim.keymap.set('i', '<Down>', '<NOP>', { buffer = search_buf })
  vim.keymap.set('i', '<Up>', '<NOP>', { buffer = search_buf })
  
  for _, b in ipairs({side_buf, main_buf}) do
    vim.keymap.set('n', 'j', move_down, { buffer = b })
    vim.keymap.set('n', 'k', move_up, { buffer = b })
    vim.keymap.set('n', '<Down>', move_down, { buffer = b })
    vim.keymap.set('n', '<Up>', move_up, { buffer = b })
    vim.keymap.set('n', '<S-Down>', move_down, { buffer = b })
    vim.keymap.set('n', '<S-Up>', move_up, { buffer = b })
    vim.keymap.set('n', '<ScrollWheelDown>', move_down, { buffer = b })
    vim.keymap.set('n', '<ScrollWheelUp>', move_up, { buffer = b })
    vim.keymap.set('n', 'q', ':qa!<CR>', { buffer = b })
    vim.keymap.set('n', '<Esc>', function()
      pcall(vim.api.nvim_win_close, help_win, true)
      M.draw_dashboard()
    end, { buffer = b })
    vim.keymap.set('n', '<Tab>', "wincmd w", { buffer = b })
    vim.keymap.set('n', '/', open_search_palette, { buffer = b })
    vim.keymap.set('n', 's', open_search_palette, { buffer = b })
    vim.keymap.set('n', 'U', start_uninstall, { buffer = b })
    vim.keymap.set('n', '<Space>', toggle_mark, { buffer = b })
    vim.keymap.set('n', 'a', mark_all, { buffer = b })
    
    vim.keymap.set('n', '<Right>', function()
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win == side_win then vim.api.nvim_set_current_win(main_win)
      elseif cur_win == main_win then
        local item = get_visible_items()[selected_item_idx]
        if item and item.is_folder and not expanded_folders[item.id] then
          expanded_folders[item.id] = true
          redraw_main()
        end
      end
    end, { buffer = b })
    
    vim.keymap.set('n', '<Left>', function()
      if vim.api.nvim_get_current_win() == main_win then
        local item = get_visible_items()[selected_item_idx]
        if item and item.is_folder and expanded_folders[item.id] then
          expanded_folders[item.id] = false
          selected_item_idx = math.min(selected_item_idx, #get_visible_items())
          redraw_main()
        else vim.api.nvim_set_current_win(side_win) end
      end
    end, { buffer = b })

    vim.keymap.set('n', '<CR>', function()
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win == main_win then
        local items = get_visible_items()
        local item = items[selected_item_idx]
        if item then
          if item.is_folder then
            expanded_folders[item.id] = not expanded_folders[item.id]
            selected_item_idx = math.min(selected_item_idx, #get_visible_items())
            redraw_main()
          else
            M.show_details(item)
          end
        end
      else
        vim.api.nvim_set_current_win(main_win)
      end
    end, { buffer = b })
  end
  
  vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, { "  " })
  redraw_side() redraw_main() redraw_help()
  vim.api.nvim_set_current_win(side_win)

  local resize_group = vim.api.nvim_create_augroup("PkgrayResize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = resize_group,
    callback = function()
      vim.schedule(function()
        local cur_win = vim.api.nvim_get_current_win()
        if cur_win == side_win or cur_win == main_win or cur_win == search_win then
          local new_ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
          if new_ui.height < 15 or new_ui.width < 50 then pcall(vim.api.nvim_win_close, help_win, true)
          else
            if not pcall(vim.api.nvim_win_get_config, help_win) then
              help_win = vim.api.nvim_open_win(help_buf, false, {
                relative = "editor", row = new_ui.height - 21, col = new_ui.width - 45,
                width = 45, height = 18, style = "minimal", border = "rounded", title = " HELP ", title_pos = "center"
              })
            else vim.api.nvim_win_set_config(help_win, { row = new_ui.height - 21, col = new_ui.width - 45, width = 45, height = 18 }) end
          end
          
          if search_win and vim.api.nvim_win_is_valid(search_win) then
            local sw = math.min(60, math.floor(new_ui.width * 0.6))
            vim.api.nvim_win_set_config(search_win, {
              relative = "editor",
              row = math.floor(new_ui.height * 0.2),
              col = math.floor((new_ui.width - sw) / 2),
              width = sw,
              height = 1
            })
          end
          
          redraw_side() redraw_main() redraw_help()
        end
      end)
    end
  })
end

function M.show_details(item)
  local details = core.get_package_details(item.name, item.source)
  local buf = vim.api.nvim_create_buf(false, true)
  
  local lines = {
    " " .. item.name:upper(),
    " " .. string.rep("─", #item.name),
    " Source:     " .. item.source,
    " Version:    " .. item.version,
  }
  
  local homepage_line = nil
  if details.maintainer then table.insert(lines, " Maintainer: " .. details.maintainer) end
  if details.homepage then 
    homepage_line = #lines
    table.insert(lines, " Homepage:   " .. details.homepage)
    table.insert(lines, "             [o] Open in Browser")
  end
  if details.size then table.insert(lines, " Size:       " .. details.size) end
  
  table.insert(lines, "")
  local desc_header_line = #lines
  table.insert(lines, " DESCRIPTION")
  table.insert(lines, " " .. string.rep("─", 11))
  
  if details.description then
    -- Simple line wrapping for description
    local width = 55
    local desc = details.description
    while #desc > 0 do
      local chunk = desc:sub(1, width)
      if #desc > width then
        local last_space = chunk:match(".*%s()")
        if last_space then
          chunk = desc:sub(1, last_space - 1)
          desc = desc:sub(last_space)
        else
          desc = desc:sub(width + 1)
        end
      else
        desc = ""
      end
      table.insert(lines, " " .. vim.trim(chunk))
    end
  else
    table.insert(lines, " No description available.")
  end
  
  table.insert(lines, "")
  table.insert(lines, " [q/Esc] Close View")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((ui.height - 15) / 2),
    col = math.floor((ui.width - 60) / 2),
    width = 60,
    height = 15,
    style = "minimal",
    border = "rounded",
    title = " PACKAGE DETAILS ",
    title_pos = "center"
  })
  
  -- Highlights for details
  vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayTitle", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayHeader", desc_header_line, 1, 12)
  if homepage_line then
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgraySelected", homepage_line, 13, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayDim", homepage_line + 1, 13, -1)
  end
  vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayDim", #lines - 1, 0, -1)
  
  local function close() pcall(vim.api.nvim_win_close, win, true) end
  vim.keymap.set('n', 'q', close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf })
  vim.keymap.set('n', '<CR>', close, { buffer = buf })
  
  if details.homepage then
    vim.keymap.set('n', 'o', function()
      core.open_url(details.homepage)
      vim.notify("Opening browser: " .. details.homepage, vim.log.levels.INFO)
    end, { buffer = buf })
  end
end

function M.open_log_explorer()
  view_mode = "logs"
  logs_sessions = core.get_activity_sessions()
  selected_session_idx = 1
  log_focus = "side"
  
  if #logs_sessions > 0 then
    session_details = core.get_session_details(logs_sessions[selected_session_idx].path)
  end
  
  -- Hide explorer wins
  pcall(vim.api.nvim_win_close, side_win, true)
  pcall(vim.api.nvim_win_close, main_win, true)
  pcall(vim.api.nvim_win_close, help_win, true)
  
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  log_side_buf = vim.api.nvim_create_buf(false, true)
  log_main_buf = vim.api.nvim_create_buf(false, true)
  
  local side_width = math.floor(ui.width * 0.25)
  log_side_win = vim.api.nvim_open_win(log_side_buf, true, {
    relative = "editor", row = 2, col = 2, width = side_width, height = ui.height - 6,
    style = "minimal", border = "rounded", title = " SESSIONS ", title_pos = "center"
  })
  log_main_win = vim.api.nvim_open_win(log_main_buf, false, {
    relative = "editor", row = 2, col = side_width + 4, width = ui.width - side_width - 8, height = ui.height - 6,
    style = "minimal", border = "rounded", title = " ACTIVITY DETAILS ", title_pos = "center"
  })
  
  vim.wo[log_side_win].fillchars = "eob: "
  vim.wo[log_main_win].fillchars = "eob: "
  
  M.setup_log_keys(log_side_buf)
  M.setup_log_keys(log_main_buf)
  
  M.redraw_logs_side()
  M.redraw_logs_main()
end

function M.redraw_logs_side()
  local lines = {}
  for i, session in ipairs(logs_sessions) do
    local prefix = (i == selected_session_idx) and "> " or "  "
    table.insert(lines, prefix .. session.name)
  end
  local vis_lines, has_up, orig_to_vis = M.inject_scroll_indicators(lines, selected_session_idx, log_side_win)
  vim.api.nvim_buf_set_lines(log_side_buf, 0, -1, false, vis_lines)
  vim.api.nvim_buf_clear_namespace(log_side_buf, -1, 0, -1)
  
  if has_up then vim.api.nvim_buf_add_highlight(log_side_buf, -1, "PkgraySelected", 0, 0, -1) end
  if vis_lines[#vis_lines] and vis_lines[#vis_lines]:match("SCROLL DOWN") then vim.api.nvim_buf_add_highlight(log_side_buf, -1, "PkgraySelected", #vis_lines - 1, 0, -1) end
  
  local actual_selected_line = -1
  if orig_to_vis[selected_session_idx] then
    actual_selected_line = orig_to_vis[selected_session_idx]
    vim.api.nvim_buf_add_highlight(log_side_buf, -1, "PkgraySelected", actual_selected_line - 1, 0, -1)
    pcall(vim.api.nvim_win_set_cursor, log_side_win, { actual_selected_line, 0 })
  end
end

function M.redraw_logs_main()
  if not session_details then
    vim.api.nvim_buf_set_lines(log_main_buf, 0, -1, false, { "", "  No session data available." })
    return
  end
  
  local lines = {
    string.format("  SESSION: %s  |  TYPE: %s", session_details.timestamp, session_details.type),
    string.rep("─", 70),
    string.format("  %-25s %-10s %-10s %s", "Package", "Version", "Source", "Result"),
    string.rep("─", 70),
  }
  
  local orig_pkg_lines = {}
  local selection_orig_line = 4
  
  for i, pkg in ipairs(session_details.packages) do
    local status = pkg.success and "✓ Success" or "✗ Failed"
    local line = string.format("  %-25s %-10s %-10s %s", pkg.name, pkg.version, pkg.source, status)
    table.insert(lines, line)
    
    orig_pkg_lines[#lines] = { pkg = pkg, idx = i }
    if i == selected_log_pkg_idx then selection_orig_line = #lines end
    
    if not pkg.success then
      table.insert(lines, "    └─ Reason: " .. (pkg.reason or "Unknown Error"))
      orig_pkg_lines[#lines] = { is_reason = true }
    end
  end
  
  table.insert(lines, "")
  local actions = "  [q/Esc] Back to Menu    [Tab] Switch Panes    [C] Clear"
  if session_details.type == "Uninstall" then
    actions = "  [r] Revert Selection    " .. actions
  end
  table.insert(lines, actions)
  
  local vis_lines, has_up, orig_to_vis = M.inject_scroll_indicators(lines, selection_orig_line, log_main_win)
  vim.api.nvim_buf_set_lines(log_main_buf, 0, -1, false, vis_lines)
  vim.api.nvim_buf_clear_namespace(log_main_buf, -1, 0, -1)
  
  if has_up then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgraySelected", 0, 0, -1) end
  if vis_lines[#vis_lines] and vis_lines[#vis_lines]:match("SCROLL DOWN") then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgraySelected", #vis_lines - 1, 0, -1) end

  local actual_selected_line = -1
  for orig_idx, vis_idx in pairs(orig_to_vis) do
    if orig_idx == 1 then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayTitle", vis_idx - 1, 0, -1)
    elseif orig_idx == 3 then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayDim", vis_idx - 1, 0, -1)
    elseif orig_idx == #lines then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayHeader", vis_idx - 1, 0, -1)
    else
      local pinfo = orig_pkg_lines[orig_idx]
      if pinfo then
        if pinfo.is_reason then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayDim", vis_idx - 1, 0, -1)
        else
          if pinfo.pkg.success then vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayHeader", vis_idx - 1, 0, -1)
          else vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgrayMarked", vis_idx - 1, 0, -1) end
          
          if pinfo.idx == selected_log_pkg_idx then
             actual_selected_line = vis_idx
          end
        end
      end
    end
  end
  
  if actual_selected_line > 0 then
    vim.api.nvim_buf_add_highlight(log_main_buf, -1, "PkgraySelected", actual_selected_line - 1, 0, -1)
    if log_focus == "main" then pcall(vim.api.nvim_win_set_cursor, log_main_win, { actual_selected_line, 0 }) end
  end
end

function M.setup_log_keys(buf)
  local function close()
    pcall(vim.api.nvim_win_close, log_side_win, true)
    pcall(vim.api.nvim_win_close, log_main_win, true)
    M.draw_dashboard()
  end
  
  local function move_down()
    if log_focus == "side" then
      selected_session_idx = math.min(#logs_sessions, selected_session_idx + 1)
      session_details = core.get_session_details(logs_sessions[selected_session_idx].path)
      M.redraw_logs_side() M.redraw_logs_main()
    else
      selected_log_pkg_idx = math.min(#session_details.packages, selected_log_pkg_idx + 1)
      M.redraw_logs_main()
    end
  end
  
  local function move_up()
    if log_focus == "side" then
      selected_session_idx = math.max(1, selected_session_idx - 1)
      session_details = core.get_session_details(logs_sessions[selected_session_idx].path)
      M.redraw_logs_side() M.redraw_logs_main()
    else
      selected_log_pkg_idx = math.max(1, selected_log_pkg_idx - 1)
      M.redraw_logs_main()
    end
  end

  local function move_right()
    if log_focus == "side" then
      log_focus = "main"
      vim.api.nvim_set_current_win(log_main_win)
      M.redraw_logs_main()
    end
  end

  local function move_left()
    if log_focus == "main" then
      log_focus = "side"
      vim.api.nvim_set_current_win(log_side_win)
      M.redraw_logs_main()
    end
  end
  
  -- Keybindings
  vim.keymap.set('n', 'j', move_down, { buffer = buf })
  vim.keymap.set('n', 'k', move_up, { buffer = buf })
  vim.keymap.set('n', '<Down>', move_down, { buffer = buf })
  vim.keymap.set('n', '<Up>', move_up, { buffer = buf })
  vim.keymap.set('n', '<S-Down>', move_down, { buffer = buf })
  vim.keymap.set('n', '<S-Up>', move_up, { buffer = buf })
  vim.keymap.set('n', '<ScrollWheelDown>', move_down, { buffer = buf })
  vim.keymap.set('n', '<ScrollWheelUp>', move_up, { buffer = buf })
  
  vim.keymap.set('n', 'l', move_right, { buffer = buf })
  vim.keymap.set('n', 'h', move_left, { buffer = buf })
  vim.keymap.set('n', '<Right>', move_right, { buffer = buf })
  vim.keymap.set('n', '<Left>', move_left, { buffer = buf })
  
  -- Switch Panes (Alt Cycle)
  vim.keymap.set('n', '<Tab>', function()
    if log_focus == "side" then move_right() else move_left() end
  end, { buffer = buf })
  
  -- Clear Logs Action
  vim.keymap.set('n', 'C', function()
    vim.ui.input({ prompt = "Clear ALL activity logs? [y/N] " }, function(input)
      if input and input:lower() == 'y' then
        core.clear_activity_logs()
        logs_sessions = core.get_activity_sessions()
        selected_session_idx = 1
        session_details = nil
        M.redraw_logs_side() M.redraw_logs_main()
        vim.notify("Activity history cleared", vim.log.levels.INFO)
      end
    end)
  end, { buffer = buf })

  -- Revert Action
  vim.keymap.set('n', 'r', function()
    if log_focus == "main" and session_details and session_details.type == "Uninstall" then
      local pkg = session_details.packages[selected_log_pkg_idx]
      if not pkg then return end
      
      vim.ui.input({ prompt = "Revert (Reinstall) " .. pkg.name .. "? [y/N] " }, function(input)
        if input and input:lower() == 'y' then
          local progress = M.show_progress(1, "Install")
          progress.update(1, pkg.name)
          
          local success, reason = core.reinstall_package(pkg)
          
          progress.finish({{
            name = pkg.name,
            success = success,
            reason = reason
          }})
        end
      end)
    end
  end, { buffer = buf })
  
  vim.keymap.set('n', 'q', close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf })
end

function M.show_uninstall_confirm(items, on_confirm)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    " CONFIRM UNINSTALLATION",
    " " .. string.rep("─", 22),
    string.format(" You are about to remove %d packages:", #items),
    ""
  }
  for i = 1, math.min(8, #items) do
    table.insert(lines, "  • " .. items[i].name)
  end
  if #items > 8 then table.insert(lines, "    ... and " .. (#items - 8) .. " more") end
  
  table.insert(lines, "")
  table.insert(lines, " [Enter] Confirm     [q/Esc] Cancel")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((ui.height - 15) / 2),
    col = math.floor((ui.width - 50) / 2),
    width = 50,
    height = 13,
    style = "minimal",
    border = "rounded",
    title = " FINAL REVIEW ",
    title_pos = "center"
  })
  
  vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayHeader", 0, 1, 23)
  vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayDim", #lines - 1, 0, -1)
  
  local function close() pcall(vim.api.nvim_win_close, win, true) end
  vim.keymap.set('n', 'q', close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf })
  vim.keymap.set('n', '<CR>', function()
    close()
    on_confirm()
  end, { buffer = buf })
end

function M.show_progress(total, mode)
  mode = mode or "Uninstall"
  local buf = vim.api.nvim_create_buf(false, true)
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local win_width = math.min(80, ui.width - 4)
  local win_height = 20
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((ui.height - win_height) / 2),
    col = math.floor((ui.width - win_width) / 2),
    width = win_width,
    height = win_height,
    style = "minimal",
    border = "double"
  })

  local function build_lines(current_idx, name, is_finish)
    local percent = math.floor((current_idx - 1) / total * 100)
    local bar_width = win_width - 20
    local filled = math.floor(percent / 100 * bar_width)
    local bar = " " .. string.rep("█", filled) .. string.rep("░", bar_width - filled) .. " "
    
    local title = mode == "Uninstall" and "UNINSTALLING PACKAGES" or "RESTORING PACKAGES"
    local lines = {
      "",
      string.rep(" ", math.floor((win_width - #title)/2)) .. title,
      string.rep(" ", math.floor((win_width - #title)/2)) .. string.rep("─", #title),
      "",
      string.format("  Processing: %s", name),
      string.format("  Progress:   %d%% (%d/%d)", percent, current_idx - 1, total),
      "",
      string.rep(" ", 8) .. bar,
      "",
      ""
    }
    
    if is_finish then
      local done_text = mode == "Uninstall" and "SUCCESSFULLY UNINSTALLED!" or "SUCCESSFULLY RESTORED!"
      table.insert(lines, string.rep(" ", math.floor((win_width - #done_text)/2)) .. done_text)
      table.insert(lines, "")
      table.insert(lines, string.rep(" ", math.floor((win_width - 26)/2)) .. "[ Press Any Key to Close ]")
    else
      table.insert(lines, "")
      table.insert(lines, "")
      table.insert(lines, "")
    end
    
    table.insert(lines, "")
    table.insert(lines, string.rep(" ", math.floor((win_width - 28)/2)) .. "▄▄▄▄ ▄ ▄  ▄▄▄   ▄▄▄  ▄▄▄ ▄ ▄")
    table.insert(lines, string.rep(" ", math.floor((win_width - 28)/2)) .. "█▄▄█ █▀▄  █ ▄  █▄▄▀ █▄▄█  █ ")
    table.insert(lines, string.rep(" ", math.floor((win_width - 28)/2)) .. "█    █  █ █▄▄█ █  █ █  █  █ ")
    table.insert(lines, "")
    table.insert(lines, string.rep(" ", math.floor((win_width - 30)/2)) .. "[ Please do not close pkgray ]")
    
    return lines
  end

  local function update(current_idx, name)
    local lines = build_lines(current_idx, name, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayTitle", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgraySelected", 7, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayDim", #lines - 1, 0, -1)
    vim.cmd("redraw")
  end

  local function finish(results)
    local success_count = 0
    for _, res in ipairs(results) do if res.success then success_count = success_count + 1 end end
    
    local is_all_success = (success_count == #results)
    local lines = build_lines(#results + 1, "Complete", true)
    
    -- Overwrite the finish lines with detailed summary
    if is_all_success then
      local done_text = mode == "Uninstall" and "SUCCESSFULLY UNINSTALLED!" or "SUCCESSFULLY RESTORED!"
      lines[11] = string.rep(" ", math.floor((win_width - #done_text)/2)) .. done_text
    else
      local fail_text = mode == "Uninstall" and "REMOVED %d/%d PACKAGES" or "RESTORED %d/%d PACKAGES"
      lines[11] = string.rep(" ", math.floor((win_width - #fail_text - 4)/2)) .. string.format(fail_text, success_count, #results)
      lines[12] = string.rep(" ", math.floor((win_width - 32)/2)) .. "SOME ENTRIES COULD NOT BE PROCESSED"
    end
    
    table.insert(lines, "")
    table.insert(lines, string.rep(" ", math.floor((win_width - 35)/2)) .. "[l] View Log    [q/Esc/Enter] Close")
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if is_all_success then
      local done_text = mode == "Uninstall" and "SUCCESSFULLY UNINSTALLED!" or "SUCCESSFULLY RESTORED!"
      local start_col = math.floor((win_width - #done_text)/2)
      vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayHeader", 10, start_col, -1)
    else
      local fail_text = mode == "Uninstall" and "REMOVED %d/%d PACKAGES" or "RESTORED %d/%d PACKAGES"
      local fail_str = string.format(fail_text, success_count, #results)
      local start_col = math.floor((win_width - #fail_str - 4)/2)
      vim.api.nvim_buf_add_highlight(buf, -1, "PkgrayMarked", 10, start_col, -1)
    end
    vim.api.nvim_buf_add_highlight(buf, -1, "PkgraySelected", #lines - 1, 0, -1)
    vim.cmd("redraw")
    
    local function close() pcall(vim.api.nvim_win_close, win, true) end
    vim.keymap.set('n', '<Esc>', close, { buffer = buf })
    vim.keymap.set('n', 'q', close, { buffer = buf })
    vim.keymap.set('n', '<CR>', close, { buffer = buf })
    vim.keymap.set('n', ' ', close, { buffer = buf })
    vim.keymap.set('n', 'l', function() close() M.open_log_explorer() end, { buffer = buf })
  end

  return { update = update, finish = finish }
end
function M.run()
  M.setup_highlights()
  vim.schedule(M.draw_dashboard)
end

return M
