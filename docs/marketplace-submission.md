### Repository URL

https://github.com/dreamsgarage/OmarCraft

### Category

Productivity

### Tags

launcher, media

### Suggest a missing tag

office

### Maintainer notes

OmarCraft brings the ArtCraft Craft apps by Storyteller (PhotoCraft, VectorCraft, FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft, SoundCraft, FigCraft) to the Omarchy bar. The aim is wider Omarchy adoption beyond developers: office, design and creative users get simple, powerful tools without touching a terminal or the AUR by hand. One native panel shows what is installed, what is available and what has a newer build, with one action per app: launch, install one app or a group (Creative, Office), update, remove.

How it works: only the prebuilt <id>-bin AUR packages are ever installed, so nothing is compiled. Installs go through Omarchy's omarchy-pkg-aur-add, removals through omarchy-pkg-drop, and updates are package-exact through the AUR helper Omarchy ships (yay -S <id>-bin) for the named packages only. All three run inside Omarchy's floating presentation terminal, which asks for the password itself; the plugin contains no sudo or pkexec. Package names are validated against the app catalog and a strict pattern before they reach any command. Installed state is read from the local package database. Network use: the app catalog from raw.githubusercontent.com (storytold/craft-launcher) and versions from the AUR RPC, every 24 hours with bounded timeouts; offline, the panel keeps the cached list and says so. The plugin changes no user configuration on its own: the Omarchy menu section and the keybinding are opt-in commands documented in the README.

Unofficial and unaffiliated with Storyteller; the plugin uses no ArtCraft logo or mark, only the app names and the colours from their public catalog. Expected baseline: review-required with the package-manager capability (the yay line of the update job and the omarchy pkg drop lines of the README), the same path as Entangled Forge's OmasteelRGB. On tags: the allowed list has nothing for office or design work; "office" is suggested above and "design" would fit as well, since the audience this plugin serves is not a technical one.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
