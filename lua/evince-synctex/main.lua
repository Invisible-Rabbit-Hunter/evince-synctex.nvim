local _2afile_2a = "fnl/evince-synctex/main.fnl"
local _0_0
do
  local name_0_ = "evince-synctex.main"
  local module_0_
  do
    local x_0_ = package.loaded[name_0_]
    if ("table" == type(x_0_)) then
      module_0_ = x_0_
    else
      module_0_ = {}
    end
  end
  module_0_["aniseed/module"] = name_0_
  module_0_["aniseed/locals"] = ((module_0_)["aniseed/locals"] or {})
  module_0_["aniseed/local-fns"] = ((module_0_)["aniseed/local-fns"] or {})
  package.loaded[name_0_] = module_0_
  _0_0 = module_0_
end
local autoload = (require("evince-synctex.aniseed.autoload")).autoload
local function _1_(...)
  local ok_3f_0_, val_0_ = nil, nil
  local function _1_()
    return {autoload("evince-synctex.aniseed.core"), autoload("dbus_proxy"), autoload("lgi"), autoload("evince-synctex.aniseed.nvim")}
  end
  ok_3f_0_, val_0_ = pcall(_1_)
  if ok_3f_0_ then
    _0_0["aniseed/local-fns"] = {autoload = {a = "evince-synctex.aniseed.core", dbus = "dbus_proxy", lgi = "lgi", nvim = "evince-synctex.aniseed.nvim"}}
    return val_0_
  else
    return print(val_0_)
  end
end
local _local_0_ = _1_(...)
local a = _local_0_[1]
local dbus = _local_0_[2]
local lgi = _local_0_[3]
local nvim = _local_0_[4]
local _2amodule_2a = _0_0
local _2amodule_name_2a = "evince-synctex.main"
do local _ = ({nil, _0_0, nil, {{}, nil, nil, nil}})[2] end
local GLib = lgi.GLib
local main_loop = GLib.MainLoop()
local ctx = main_loop:get_context()
local active_windows = {}
_G.pretty = function(...)
  return a["pr-str"](...)
end
local timer = vim.loop.new_timer()
local timer_running = false
local table_empty_3f
do
  local v_0_
  local function table_empty_3f0(t)
    local next = next
    return (next(t) == nil)
  end
  v_0_ = table_empty_3f0
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["table-empty?"] = v_0_
  table_empty_3f = v_0_
end
local keys
do
  local v_0_
  do
    local v_0_0
    local function keys0(t)
      local result = {}
      for k, v in pairs(t) do
        result[(#result + 1)] = k
      end
      return result
    end
    v_0_0 = keys0
    _0_0["keys"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["keys"] = v_0_
  keys = v_0_
end
local get_window
do
  local v_0_
  local function get_window0(win_name)
    if not timer_running then
      local function _2_()
        return ctx:iteration()
      end
      timer:start(0, 250, _2_)
      timer_running = true
    end
    if (active_windows[win_name] ~= nil) then
      return active_windows[win_name]
    else
      local function signal_callback(_, file_uri, _3_0, _0)
        local _arg_0_ = _3_0
        local line = _arg_0_[1]
        local col = _arg_0_[2]
        local function _4_()
          local file = vim.uri_to_fname(file_uri)
          if (vim.api.nvim_buf_get_name(0) ~= file) then
            vim.api.nvim_command((":vsplit " .. file))
          end
          return vim.api.nvim_win_set_cursor(0, {line, (col + 1)})
        end
        return vim.schedule(_4_)
      end
      local function closed_callback(proxy)
        active_windows[proxy.name] = nil
        if table_empty_3f(active_windows) then
          timer:stop()
          timer_running = false
          return nil
        end
      end
      local window = (dbus.Proxy):new({bus = dbus.Bus.SESSION, interface = "org.gnome.evince.Window", name = win_name, path = "/org/gnome/evince/Window/0"})
      active_windows[win_name] = window
      window:connect_signal(signal_callback, "SyncSource")
      window:connect_signal(closed_callback, "Closed")
      return window
    end
  end
  v_0_ = get_window0
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["get-window"] = v_0_
  get_window = v_0_
end
local file_exists_3f
do
  local v_0_
  local function file_exists_3f0(path)
    local f = io.open(path, "r")
    if (f ~= nil) then
      io.close(f)
      return true
    else
      return false
    end
  end
  v_0_ = file_exists_3f0
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["file-exists?"] = v_0_
  file_exists_3f = v_0_
end
local find_document
do
  local v_0_
  local function find_document0(path, open_3f)
    if file_exists_3f(path) then
      local daemon = (dbus.Proxy):new({bus = dbus.Bus.SESSION, interface = "org.gnome.evince.Daemon", name = "org.gnome.evince.Daemon", path = "/org/gnome/evince/Daemon"})
      return daemon:FindDocument(vim.uri_from_fname(path), open_3f)
    else
      return nil, ("File does not exist: " .. path)
    end
  end
  v_0_ = find_document0
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["find-document"] = v_0_
  find_document = v_0_
end
_G.EvinceView = function(file_name, pdf_name)
  local win_name, err = find_document(pdf_name, true)
  local sync_view_cb
  local function _2_(proxy, _, _0, err0)
    if (err0 ~= nil) then
      return print("Sync error:", a["pr-str"](err0))
    end
  end
  sync_view_cb = _2_
  if (err ~= nil) then
    local function _3_()
      return print("Error:", err)
    end
    return vim.schedule(_3_)
  else
    local window = get_window(win_name)
    local function _3_()
      local pos = nvim.win_get_cursor(0)
      return window:SyncViewAsync(sync_view_cb, {}, file_name, pos, os.time())
    end
    return vim.schedule(_3_)
  end
end
local setup
do
  local v_0_
  do
    local v_0_0
    local function setup0()
      return vim.cmd("command EvinceView :lua _G.EvinceView(vim.fn.expand('%:p'), vim.fn.expand('%:p:r')..'.pdf')")
    end
    v_0_0 = setup0
    _0_0["setup"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["setup"] = v_0_
  setup = v_0_
end
return nil