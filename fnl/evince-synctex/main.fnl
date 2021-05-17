(module evince-synctex.main
  {autoload {a aniseed.core
             lgi lgi
             dbus dbus_proxy
             nvim aniseed.nvim}})

(macro schedule [...]
  `(vim.schedule (fn [] ,...)))

(local GLib lgi.GLib)
(local main-loop (GLib.MainLoop))
(local ctx (main-loop:get_context))
(local active-windows {})
(fn _G.pretty [...] (a.pr-str ...))

(local timer (vim.loop.new_timer))
(var timer-running false)

(defn- table-empty? [t]
  (let [next next]
    (= (next t) nil)))

(defn keys [t]
  (var result [])
  (each [k v (pairs t)]
    (tset result (+ (length result) 1) k))
  result)

(defn- get-window [win-name]
  (when (not timer-running)
    (timer:start 0 250 (fn [] (ctx:iteration)))
    (set timer-running true))
  (if (~= (. active-windows win-name) nil) (. active-windows win-name)
    (do
      (fn signal-callback [_ file-uri [line col] _]
        (schedule
          (let [file (vim.uri_to_fname file-uri)]
            (if (~= (vim.api.nvim_buf_get_name 0) file)
              (vim.api.nvim_command (.. ":vsplit " file)))
            (vim.api.nvim_win_set_cursor 0 [line (+ col 1)]))))
      (fn closed-callback [proxy]
        (tset active-windows proxy.name nil)
        (when (table-empty? active-windows)
          (timer:stop)
          (set timer-running false)))
      (let [window (dbus.Proxy:new
                     {:bus dbus.Bus.SESSION
                      :interface "org.gnome.evince.Window"
                      :name win-name
                      :path "/org/gnome/evince/Window/0"})]
        (tset active-windows win-name window)
        (window:connect_signal signal-callback "SyncSource")
        (window:connect_signal closed-callback "Closed")
        window))))

(defn- file-exists? [path]
  (let [f (io.open path "r")]
    (if (~= f nil) (do (io.close f) true) false)))

(defn- find-document [path open?]
  (if (file-exists? path)
    (let [daemon (dbus.Proxy:new {:bus dbus.Bus.SESSION
                                  :interface "org.gnome.evince.Daemon"
                                  :name "org.gnome.evince.Daemon"
                                  :path "/org/gnome/evince/Daemon"})]
       (daemon:FindDocument (vim.uri_from_fname path) open?))
   (values nil (.. "File does not exist: " path))))

(fn _G.EvinceView [file-name pdf-name]
  (let [(win-name err) (find-document pdf-name true)
        sync-view-cb (fn [proxy _ _ err] (if (~= err nil) (print "Sync error:" (a.pr-str err))))]
    (if (~= err nil)
      (schedule
        (print "Error:" err))
      (let [window (get-window win-name)]
        (schedule
          (let [pos (nvim.win_get_cursor 0)]
            (window:SyncViewAsync sync_view_cb {} file-name pos (os.time))))))))
(defn setup []
  (vim.cmd "command EvinceView :lua _G.EvinceView(vim.fn.expand('%:p'), vim.fn.expand('%:p:r')..'.pdf')"))
