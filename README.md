# Help

NextBSD's help viewer, `Help.app`. It shows **help books**: NextBSD Help,
which comes with it, and a book for each app that has one. It is a fork of
[HelpViewer](http://www.roard.com/helpviewer) by Nicolas Roard and Riccardo
Mottola (GAP), and reads HelpViewer's XLP help files, with a few additions
for pictures with numbered callouts, tips and key tables. See
[NU-GAP-IMPORT.md](NU-GAP-IMPORT.md) for where the HelpViewer sources came
from, and [ChangeLog](ChangeLog) for their history.

The window has a toolbar (back and forward, the book's title, and **Search
all help**), a sidebar with the books and the chosen book's topics, and the
page. It follows the NextBSD theme's appearance (`NBAppearance`, Dark or
Light, set in Workspace Preferences) and changes with it at once.

## Where it goes

nextbsd/nextbsd-desktop builds it into `/System/Library/CoreServices/Help.app`
(`Help_INSTALL_DIR`). Built by hand:

```sh
. /System/Library/Makefiles/GNUstep.sh
gmake
gmake install Help_INSTALL_DIR=/System/Library/CoreServices
```

## Books

A book is a folder named `<Name>.help` with a `main.xlp` in it, and the
pictures and other `.xlp` files its topics use. Help finds books in:

1. its own Resources: `NextBSD.help`, NextBSD Help, listed first;
2. the Resources of every app in `/System/Library/CoreServices`,
   `/System/Applications`, `/Applications`, `/Local/Applications`,
   `/Network/Applications` and `~/Applications` (localized ones in
   `Resources/<Language>.lproj` too).

**To give an app a book, put `<Executable>.help` in its Resources** (for
gnustep-make, add `Resources/<Executable>.help` to the app's
`RESOURCE_FILES`). That is all: Help lists it, the app's Help menu gets
an "*App* Help" item (the NextBSD theme), and `-[NSApplication showHelp:]`
opens it (nextbsd/libs-gui). An app whose book has another name sets
`GSHelpContentsFile = "Other.help";` in its Info.plist.

## Opening Help from another app

- `-[NSApplication showHelp:]` (the Help menu's *App* Help item, or
  Command-?) opens the app's `.help` with the help viewer the
  `GSHelpViewer` default names; the NextBSD desktop sets it to
  `/System/Library/CoreServices/Help.app`. An app with no book gets Help
  with NextBSD Help.
- A running Help vends an object under the Distributed Objects name
  `org.nextbsd.Help` with one method:

  ```objc
  - (oneway void) showBook: (NSString *)book   // NextBSD, Workspace, or a .help path
                     topic: (NSString *)topic  // a topic's id or name, or nil
                    search: (NSString *)query; // a search, or nil
  ```

- When Help isn't running, start it with the same three as defaults:
  `Help.app/Help -NBHelpBook Workspace -NBHelpTopic views -NBHelpSearch "eject"`.
- Opening a `.help` bundle (or `Book.help/<topic id>`) with Help, as
  `NSWorkspace -openFile:withApplication:` does, shows that book.

The NextBSD theme's Help menu (nextbsd/nextbsd-theme, `NBHelpMenu.m`) uses
these: its search field lists topics from every book and the app's own menu
commands.

## The format: XLP

XLP is HTML-like XML. Help reads it forgivingly: `<br>` and `<img>` need no
end tag, a missing end tag is closed for you, and HTML's named entities
(`&nbsp;`, `&eacute;`, `&rarr;` ...) work. Write UTF-8 (the default; an
`<?xml encoding="ISO-8859-1"?>` declaration is honoured).

### main.xlp

```xml
<?xml version="1.0" encoding="utf-8"?>
<document>
<header>
  <title>NextBSD Help</title>        <!-- the book's name everywhere -->
  <icon src="NextBSD.png"/>          <!-- optional; else the app's icon -->
</header>

<chapter id="getting-started" name="Getting started" src="getting-started.xlp"/>
<chapter id="desktop" name="The desktop" src="desktop.xlp" keywords="background wallpaper">
  <section id="desktop-icons" name="Desktop icons" src="desktop-icons.xlp"/>
  <section id="eject" name="Ejecting a disk" src="eject.xlp"/>
</chapter>
</document>
```

- Each `<part>`, `<chapter>`, `<section>` or `<plain>` is a **topic**: a
  page of its own, listed in the sidebar. Topics inside it are listed
  below it, and its page ends with links to them.
- `name` is its title; `id` is how links and other apps find it (the name
  is used when there's no id); `keywords` are extra words for search.
- `src` takes the topic's content from another file, which may hold topics
  of its own. Content written inside the element works too.

### A page

```xml
<p>With desktop icons on, the desktop shows your disks ...</p>

<aside>                                 <!-- a column at the right -->
  <h2>From the keyboard</h2>
  <table>
    <tr><td><kbd>Return</kbd> or <kbd>⌘↓</kbd></td><td>Open</td></tr>
    <tr><td>Drag a box</td><td>Choose several items</td></tr>
  </table>
  <tip>The NeXT style keeps the desktop clear ...</tip>
  <related>
    <ref id="eject">Ejecting a disk</ref>
    <ref book="Workspace" id="locations">The Locations list</ref>
  </related>
</aside>

<legendfig src="desktop-icons.png" width="186">
  <legend x="300" y="62"><b>NextBSD</b> is the startup disk ...</legend>
  <legend x="300" y="250">Then what's in your <b>Desktop</b> folder ...</legend>
</legendfig>
```

| Element | What it is |
|---|---|
| `<p>` | A paragraph. Text outside any element is one too. |
| `<h2>`, `<h3>` | A heading in the page (the topic's name is its title). |
| `<ul>`, `<ol>` with `<li>` | Lists. |
| `<legendfig src="" width="">` | A picture with numbered callouts. Each `<legend x="" y="">` puts a numbered dot at that point of the picture (in its pixels, from the top left) and its text, with the same number, beside the picture, or below it when the page is narrow. `width` is the width to show it at, in points. |
| `<img src="" width="">` | A picture on its own. |
| `<tip>`, `<note>`, `<caution>` | A tinted note with a rule down its left, starting with **Tip**, **Note** or **Important** (`label=""` to say something else). `<information>` has no label. |
| `<table>` with `<tr>`, `<td>`, `<th>` | A table in a rounded box, ruled between rows; the first column is as wide as its widest cell. |
| `<kbd>` | A key cap: `<kbd>⌘F</kbd>`, `<kbd>Return</kbd>`. |
| `<aside>` | Everything in it goes in a column at the right of what follows it, when the window is wide enough; below it otherwise. |
| `<related>` | "Related" and a list of links (`title=""` for another heading). |
| `<ref id="" book="">` | A link to a topic, in this book or another. |
| `<url>`, `<a href="">` | A link to a web page. |
| `<b>`, `<i>`, `<code>`, `<sc>`, `<br>` | Bold, italic, code, small capitals, a line break. |
| `<pre>`, `<listing>` | Text as it is, in a box. |
| `<center>`, `<hr>` | HelpViewer's, still read. |

**Pictures in both appearances:** for `src="desktop.png"`, Help shows
`desktop-dark.png` in Dark and `desktop-light.png` in Light when they're
there, and `desktop.png` otherwise. Take screenshots at 1x; set `width`
to show a large one smaller.

The `Examples` folder has HelpViewer's own test books, which still open.

## Licence

GNU General Public License, version 2 or later: see [COPYING](COPYING).
