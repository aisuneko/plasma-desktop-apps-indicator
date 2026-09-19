# Plasma Desktop Apps Indicator

![](screenshot.png)

A Desktop indicator for KDE Plasma 6, forked from [Very Minimal Desktop Indicator](https://github.com/serfreeman1337/plasma-desktop-indicator), but with app icons grouped by desktops to allow for a clear glance of what's on each virtual desktop.

We have:
- windows grouped by desktops, each represented by its application icons
- the current desktop tab highlighted
- a reserved space in front for "Global" windows (that appears on every desktop) to reduce clutter
- a neat triangular indicator at the bottom right corner of its tab whenever a window demands attention

Recommended to pair with [Krohnkite](https://codeberg.org/anametologin/Krohnkite) and [application-title-bar](https://github.com/antroids/application-title-bar) to get that i3-ish WM-like experience on KDE Plasma.

There are no config options at the moment, and I may add some if I happen to need these.

(same as the original fork) Also, it uses the kwin dbus api to switch desktops because no one ever put `Q_INVOKABLE` for that plasma api.
