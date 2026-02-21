# Very Minimal Desktop Indicator
<img width="172" height="56" src="https://github.com/user-attachments/assets/68ce7d57-3192-4d73-9f72-b015f5e719c0" />

Inspired by [Minimal Desktop Indicator](https://github.com/DualityKyle/plasma-desktop-indicator), which itself was inspired by [GNOME Workspace indicator](https://github.com/tty2/horizontal-workspace-indicator).  
Very simple virtual desktop indicator for Plasma 6. So simple that there is no configuration, white circles are what you get.

It draws circles as very round rectangles, and doesn't just print a circle as text.  
Also, it uses the kwin dbus api to switch desktops because no one ever put `Q_INVOKABLE` for that plasma api.