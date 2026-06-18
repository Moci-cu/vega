hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
  { description = "Edit user keybinds" })
hl.bind("SUPER + Z", hl.dsp.global("quickshell:mediaModeToggle"), { description = "Shell: Toggle media mode (lyrics)" })
hl.bind("CTRL + SUPER + M", hl.dsp.global("quickshell:mangaToggle"), { description = "Shell: Toggle manga reader" })
