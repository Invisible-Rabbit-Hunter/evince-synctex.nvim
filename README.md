# evince-synctex.nvim

## Use
Use the command `:EvinceView` to open/connect to the pdf-document associated
with the currently opened buffer. Make sure it's a `.tex` file compiled with
synctex.

## Dependencies:
Depends on `dbus_proxy`, which itself depends on `lgi`, for communication
with evince via dbus.

## Installation via packer
Add
```lua
use {
  'Invisible-Rabbit-Hunter/evince-synctex.nvim',
  rocks = {'dbus_proxy'}
}
```
