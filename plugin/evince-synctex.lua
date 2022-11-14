local dbus = require 'dbus_proxy'
local lgi = require 'lgi'

local main_loop = lgi.GLib.MainLoop()
local ctx = main_loop:get_context()
local active_windows = {}

local timer = vim.loop.new_timer()
local timer_running = false

local function is_table_empty(t)
  return next(t) == nil
end

local function keys(t)
  local result = {}
  for k, v in pairs(t) do
    result[#result] = k
  end
  return result
end

local function get_window(win_name)
  if not timer_running then
    timer:start(0, 250, function () ctx:iteration() end)
    timer_running = true
  end

  if active_windows[win_name] ~= nil then
    return active_windows[win_name]
  else
    local function signal_callback(_, file_uri, pos, _)
      vim.schedule(function()
        local file = vim.uri_to_fname(file_uri)
        if vim.api.nvim_buf_get_name(0) ~= file then
          vim.api.nvim_command(':e '..file)
        end
        vim.api.nvim_win_set_cursor(0, {pos[1], pos[2]+1})
				vim.api.nvim_command('normal! zz')
      end)
    end

    local function closed_callback(proxy)
      active_windows[proxy.name] = nil
      if is_table_empty(active_windows) then
        timer:stop()
        timer_running = false
      end
    end

    local window = dbus.Proxy:new {
      bus = dbus.Bus.SESSION,
      interface = 'org.gnome.evince.Window',
      name = win_name,
      path = '/org/gnome/evince/Window/0'
    }

    active_windows[win_name] = window
    window:connect_signal(signal_callback, 'SyncSource')
    window:connect_signal(closed_callback, 'Closed')
    return window
  end
end

local function file_exists(path)
  local f = io.open(path, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function find_document(path, should_open)
  if file_exists(path) then
    local daemon = dbus.Proxy:new {
      bus = dbus.Bus.SESSION,
      interface = 'org.gnome.evince.Daemon',
      name = 'org.gnome.evince.Daemon',
      path = '/org/gnome/evince/Daemon'
    }
    return daemon:FindDocument(vim.uri_from_fname(path), should_open)
  else
    return nil, "File does not exist: "..path
  end
end

local function evince_view(file_name, pdf_name)
  local win_name, err = find_document(pdf_name, true)
  if err ~= nil then
    print("Error:", err)
    return nil, err
  end

  local function sync_callback(proxy, _, _, err)
    if err ~= nil then
      vim.schedule(function ()
        print("Sync error:", err)
      end)
    end
  end

  local window = get_window(win_name)
  vim.schedule(function ()
    local pos = vim.api.nvim_win_get_cursor(0)
    window:SyncViewAsync(sync_callback, {}, file_name, pos, os.time())
  end)
end

local function find_latexmkrc(start_dir)
  local dir = start_dir
  while vim.fn.file_readable(vim.fn.fnamemodify(dir, ":p").."/.latexmkrc") == 0 do
    dir = dir:gsub("/[^/]+/?$", "")
    if dir == "~" or dir == "" or dir == "/" then return nil, "no latexmkrc" end
  end
  
  return vim.fn.fnamemodify(dir, ":p")
end

local function find_build_dir(latexmkrc_dir)
  local file = io.open(latexmkrc_dir .. "/.latexmkrc")
  for line in file:lines() do
    local _, _, out_dir = line:find("%$out_dir = \'(.+)\';$")
    if out_dir then
      return latexmkrc_dir..out_dir
    end
  end
end

local function find_pdf()
  local head, matched = vim.fn.getline(1):gsub("%%!TEX root = ", "")

  local source_file
  if matched == 0 then
    source_file = vim.fn.expand("%:p")
  else
    source_file = vim.fn.fnamemodify(vim.fn.expand("%:h").."/"..head, ":p")
  end
  
  local latexmkrc_dir = find_latexmkrc(vim.fn.expand("%:~:h")) 

  local pdf_path
  if latexmkrc_dir == nil then
    pdf_path = vim.fn.fnamemodify(source_file, ":r") .. ".pdf"
  else
    local diff = source_file:sub(#latexmkrc_dir+1)
    build_dir = find_build_dir(latexmkrc_dir)
    pdf_path = vim.fn.fnamemodify(build_dir.."/" .. diff, ":r") .. ".pdf"
  end


  return pdf_path
end

vim.api.nvim_create_user_command('EvinceView', function(tbl)
  evince_view(vim.fn.expand('%:p'), find_pdf())
end, {})

