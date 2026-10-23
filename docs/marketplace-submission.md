### Repository URL

https://github.com/dreamsgarage/OmarCraft

### Category

Productivity

### Tags

launcher, media

### Suggest a missing tag

office

### Maintainer notes

OmarCraft is a productivity launcher and installer for the Omarchy bar, made for people who come to Omarchy for office, design and creative work and not only for code. One native panel shows which tools are installed, which are available and which have a newer build, with one action per tool: launch, install one or a group, update, remove. It is open to any desktop tool that meets one rule: a stable desktop release, prebuilt in the Arch repos or as an AUR <id>-bin with a desktop entry, from a maintained open-source upstream. Release 0.5.1 carries the thirteen ArtCraft Craft apps by Storyteller (PhotoCraft, VectorCraft, FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft, SoundCraft, FigCraft) in the groups Creative and Office, Typesetter (Typst documents with a live preview, from the Arch repos) in Office, and Memospot, the desktop build of Memos, in Notes; fifteen tools in all, and more follow by the same rule. The README says how to propose one. (0.5.0 also carried Vikunja; 0.5.1 removes it, because its desktop app could not sign in reliably.)

How it works: only prebuilt packages are ever installed, so nothing is compiled. AUR installs go through Omarchy's omarchy-pkg-aur-add and Arch repo installs through omarchy-pkg-add, removals through omarchy-pkg-drop; AUR updates are package-exact through the AUR helper Omarchy ships (yay -S <id>-bin) for the named packages only, and Arch repo tools update with the system through Omarchy's update. All of them run inside Omarchy's floating presentation terminal, which asks for the password itself; the plugin contains no sudo or pkexec. Only catalog apps reach a package command, by an id checked against a strict pattern; each maps to its <id>-bin or a fixed repo package name. Installed state is read from the local package database. Network use: the ArtCraft catalog from raw.githubusercontent.com (storytold/craft-launcher) and versions from the AUR RPC, every 24 hours with bounded timeouts; offline, the panel keeps the cached list and says so. The plugin changes no user configuration on its own: the Omarchy menu section and the keybinding are opt-in commands documented in the README. Where 0.5.0 installed Vikunja, 0.5.1 deletes once the desktop entry and launcher 0.5.0 wrote for it, and nothing else.

Unofficial and unaffiliated with Storyteller, Memos or Memospot; the plugin uses no project logo, only the app names and colours (ArtCraft's public catalog, the Memospot icon). Expected baseline: review-required with the package-manager capability only (the yay line of the update job and the omarchy pkg drop lines of the README), the same path as Entangled Forge's OmasteelRGB; the local baseline scan on 0.5.1 reports no other capability and no findings. On tags: the allowed list has nothing for office or design work; "office" is suggested above and "design" would fit as well, since the audience this plugin serves is not a technical one.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
