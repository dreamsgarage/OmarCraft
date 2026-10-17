### Repository URL
https://github.com/dreamsgarage/OmarCraft
### Category
Productivity
### Tags
launcher, bar, quickshell
### Suggest a missing tag
apps
### Maintainer notes
Unofficial bar panel for the ArtCraft Craft apps by Storyteller (PhotoCraft, FilmCraft, WordCraft and ten more) plus ArtCraft Studio as a web app. A native KeyboardPanel shows installed, available and update-ready apps with one action per row: launch, install one app or a group, update. Only the prebuilt <id>-bin AUR packages are installed, so nothing is compiled. Installs go through Omarchy's omarchy-pkg-aur-add; updates are package-exact and call the AUR helper Omarchy ships (yay -S <id>-bin) for the named packages only, both inside Omarchy's floating presentation terminal. No sudo or pkexec is called by the plugin; the password prompt belongs to the helper in the open terminal. Package names are validated against the app catalog and a strict pattern before they reach any command. Installed state is read from the local package database. Network use: the app catalog from raw.githubusercontent.com (storytold/craft-launcher) and versions from the AUR RPC, every 24 hours with bounded timeouts. The plugin changes no user configuration on its own: the Omarchy menu section and the keybinding are opt-in commands documented in the README.
### Submission checklist
- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
