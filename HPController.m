/*
    HPController.m: Help's window, its navigation and search, and how
    other apps ask it to show a book, a topic or a search.

    This file is part of Help, NextBSD's help viewer, based on HelpViewer
    (http://gap.nongnu.org/helpviewer/).
    Copyright (C) 2026 Joseph Maloney

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the
    Free Software Foundation, Inc.
    31 Milk Street #960789 Boston, MA 02196 USA
*/

#import "HPController.h"
#import "HPLibrary.h"
#import "HPStyle.h"
#import "GNUstep.h"

static const CGFloat HPToolbarHeight = 50, HPSidebarWidth = 230;

/* ---- the toolbar: back and forward, the title, "Search all help" ------- */

@interface HPNavButton : NSControl
{
  BOOL forward;
  BOOL pressed;
}
- (id) initWithFrame: (NSRect)f forward: (BOOL)fwd;
@end

@implementation HPNavButton

+ (Class) cellClass
{
  return [NSActionCell class];
}

- (id) initWithFrame: (NSRect)f forward: (BOOL)fwd
{
  if ((self = [super initWithFrame: f]) != nil)
    forward = fwd;
  return self;
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) drawRect: (NSRect)r
{
  NSBezierPath *p = [NSBezierPath bezierPath];
  NSRect b = [self bounds];
  CGFloat cx = NSMidX(b), cy = NSMidY(b), d = forward ? 1 : -1;

  if (pressed)
    {
      [[HPStyle selection] set];
      [[HPStyle roundedRect: b radius: 6] fill];
    }
  [p moveToPoint: NSMakePoint(cx - 2.5 * d, cy - 5)];
  [p lineToPoint: NSMakePoint(cx + 2.5 * d, cy)];
  [p lineToPoint: NSMakePoint(cx - 2.5 * d, cy + 5)];
  [p setLineWidth: 2];
  [p setLineCapStyle: NSRoundLineCapStyle];
  [p setLineJoinStyle: NSRoundLineJoinStyle];
  [([self isEnabled] ? [HPStyle dim] : [HPStyle faint]) set];
  [p stroke];
}

- (void) mouseDown: (NSEvent *)e
{
  if (![self isEnabled])
    return;
  pressed = YES;
  [self setNeedsDisplay: YES];
  e = [[self window] nextEventMatchingMask: NSLeftMouseUpMask];
  pressed = NO;
  [self setNeedsDisplay: YES];
  if (NSPointInRect([self convertPoint: [e locationInWindow] fromView: nil],
                    [self bounds]))
    [self sendAction: [self action] to: [self target]];
}

@end

@interface HPToolbar : NSView
{
  NSString *title;
}
- (void) setTitle: (NSString *)t;
@end

@implementation HPToolbar

- (void) dealloc
{
  RELEASE(title);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) setTitle: (NSString *)t
{
  ASSIGN(title, t);
  [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)r
{
  NSRect b = [self bounds];
  NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
    [HPStyle semiboldFontOfSize: 13], NSFontAttributeName,
    [HPStyle text], NSForegroundColorAttributeName, nil];
  NSSize s = title ? [title sizeWithAttributes: a] : NSZeroSize;

  [[HPStyle bar] set];
  NSRectFill(r);
  [[HPStyle line] set];
  NSRectFillUsingOperation(NSMakeRect(0, NSMaxY(b) - 1, NSWidth(b), 1),
                           NSCompositeSourceOver);
  /* Centred in the window, as the title bar's title is. */
  [title drawAtPoint: NSMakePoint(floor((NSWidth(b) - s.width) / 2),
                                  floor((NSHeight(b) - s.height) / 2))
      withAttributes: a];
}

@end

/* "Search all help": a rounded field with a magnifier, holding a plain
   text field. */
@interface HPSearchBox : NSView
@end

@implementation HPSearchBox

- (BOOL) isFlipped
{
  return YES;
}

- (void) drawRect: (NSRect)r
{
  NSRect b = NSInsetRect([self bounds], 0.5, 0.5);
  NSBezierPath *p = [HPStyle roundedRect: b radius: 7];
  NSBezierPath *m = [NSBezierPath bezierPath];

  [([HPStyle light] ? [NSColor whiteColor]
                    : [NSColor colorWithCalibratedRed: 0x12 / 255.0
                                                green: 0x14 / 255.0
                                                 blue: 0x18 / 255.0
                                                alpha: 1]) set];
  [p fill];
  [[HPStyle line] set];
  [p stroke];
  [m appendBezierPathWithOvalInRect: NSMakeRect(11, 8, 9, 9)];
  [m moveToPoint: NSMakePoint(18.5, 15.5)];
  [m lineToPoint: NSMakePoint(22, 19)];
  [m setLineWidth: 1.6];
  [m setLineCapStyle: NSRoundLineCapStyle];
  [[HPStyle faint] set];
  [m stroke];
}

@end

/* The window's background: the sidebar's colour, and the line between
   the sidebar and the page. */
@interface HPContentView : NSView
@end

@implementation HPContentView

- (void) drawRect: (NSRect)r
{
  [[HPStyle page] set];
  NSRectFill(r);
  [[HPStyle sidebar] set];
  NSRectFill(NSMakeRect(0, 0, HPSidebarWidth, NSHeight([self bounds])));
  [[HPStyle line] set];
  NSRectFillUsingOperation(NSMakeRect(HPSidebarWidth, 0, 1,
                                      NSHeight([self bounds])),
                           NSCompositeSourceOver);
}

@end

/* ---- the controller --------------------------------------------------- */

@implementation HPController

- (id) init
{
  if ((self = [super init]) != nil)
    {
      back = [[NSMutableArray alloc] init];
      forward = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(window);
  RELEASE(service);
  RELEASE(back);
  RELEASE(forward);
  RELEASE(book);
  RELEASE(topic);
  RELEASE(query);
  [super dealloc];
}

static NSMenu *
HPSubmenu(NSMenu *main, NSString *title)
{
  NSMenu *m = AUTORELEASE([[NSMenu alloc] initWithTitle: title]);

  [[main addItemWithTitle: title action: NULL keyEquivalent: @""]
    setSubmenu: m];
  return m;
}

- (void) makeMenu
{
  NSMenu *main = AUTORELEASE([[NSMenu alloc] initWithTitle: @"Help"]);
  NSMenu *m;

  /* The app's own menu, called Help as the app is. There's no Help menu
     of Help's own: the NextBSD theme adds one to every app, with the
     help search and NextBSD Help, and Go has NextBSD Help too. */
  m = HPSubmenu(main, @"Help");
  [m addItemWithTitle: @"About Help"
               action: @selector(orderFrontStandardAboutPanel:)
        keyEquivalent: @""];
  [m addItemWithTitle: @"Hide" action: @selector(hide:) keyEquivalent: @"h"];
  [m addItemWithTitle: @"Quit Help" action: @selector(terminate:)
        keyEquivalent: @"q"];
  m = HPSubmenu(main, @"Edit");
  [m addItemWithTitle: @"Cut" action: @selector(cut:) keyEquivalent: @"x"];
  [m addItemWithTitle: @"Copy" action: @selector(copy:) keyEquivalent: @"c"];
  [m addItemWithTitle: @"Paste" action: @selector(paste:) keyEquivalent: @"v"];
  [m addItemWithTitle: @"Select All" action: @selector(selectAll:)
        keyEquivalent: @"a"];
  [m addItemWithTitle: @"Search Help" action: @selector(findInHelp:)
        keyEquivalent: @"f"];
  m = HPSubmenu(main, @"Go");
  [m addItemWithTitle: @"Back" action: @selector(goBack:) keyEquivalent: @"["];
  [m addItemWithTitle: @"Forward" action: @selector(goForward:)
        keyEquivalent: @"]"];
  [m addItemWithTitle: @"NextBSD Help" action: @selector(goHome:)
        keyEquivalent: @""];
  m = HPSubmenu(main, @"Window");
  [m addItemWithTitle: @"Minimize" action: @selector(performMiniaturize:)
        keyEquivalent: @"m"];
  [m addItemWithTitle: @"Close" action: @selector(performClose:)
        keyEquivalent: @"w"];
  [NSApp setWindowsMenu: m];
  [NSApp setMainMenu: main];
}

- (void) makeWindow
{
  NSRect screen = [[NSScreen mainScreen] visibleFrame];
  NSSize sz = NSMakeSize(MIN(1160, NSWidth(screen) - 40),
                         MIN(720, NSHeight(screen) - 40));
  NSView *content;
  NSRect b;
  HPNavButton *nb;

  window = [[NSWindow alloc]
             initWithContentRect: NSMakeRect(0, 0, sz.width, sz.height)
                       styleMask: NSTitledWindowMask | NSClosableWindowMask
                                  | NSMiniaturizableWindowMask
                                  | NSResizableWindowMask
                         backing: NSBackingStoreBuffered
                           defer: NO];
  [window setTitle: @"Help"];
  [window setMinSize: NSMakeSize(640, 400)];
  [window setReleasedWhenClosed: NO];
  content = AUTORELEASE([[HPContentView alloc]
                          initWithFrame: NSMakeRect(0, 0, sz.width, sz.height)]);
  [window setContentView: content];
  b = [content bounds];

  toolbar = AUTORELEASE([[HPToolbar alloc] initWithFrame:
    NSMakeRect(0, NSHeight(b) - HPToolbarHeight, NSWidth(b), HPToolbarHeight)]);
  [toolbar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
  [content addSubview: toolbar];
  nb = AUTORELEASE([[HPNavButton alloc]
                     initWithFrame: NSMakeRect(12, 13, 24, 24) forward: NO]);
  [nb setTarget: self];
  [nb setAction: @selector(goBack:)];
  [nb setTag: 1];
  [toolbar addSubview: nb];
  nb = AUTORELEASE([[HPNavButton alloc]
                     initWithFrame: NSMakeRect(38, 13, 24, 24) forward: YES]);
  [nb setTarget: self];
  [nb setAction: @selector(goForward:)];
  [nb setTag: 2];
  [toolbar addSubview: nb];

  {
    HPSearchBox *box = AUTORELEASE([[HPSearchBox alloc] initWithFrame:
      NSMakeRect(NSWidth(b) - 14 - 240, 11, 240, 28)]);

    [box setAutoresizingMask: NSViewMinXMargin];
    [toolbar addSubview: box];
    searchField = AUTORELEASE([[NSTextField alloc] initWithFrame:
      NSMakeRect(30, 5, 240 - 38, 18)]);
    [searchField setAutoresizingMask: NSViewWidthSizable];
    [searchField setBezeled: NO];
    [searchField setBordered: NO];
    [searchField setDrawsBackground: NO];
    [searchField setFocusRingType: NSFocusRingTypeNone];
    [searchField setFont: [HPStyle fontOfSize: 12]];
    [searchField setTextColor: [HPStyle text]];
    [[searchField cell] setScrollable: YES];
    [[searchField cell] setPlaceholderString: @"Search all help"];
    [box addSubview: searchField];
  }
  [searchField setTarget: self];
  [searchField setAction: @selector(search:)];
  [searchField setDelegate: (id)self];

  sidebarScroll = AUTORELEASE([[NSScrollView alloc] initWithFrame:
    NSMakeRect(0, 0, HPSidebarWidth, NSHeight(b) - HPToolbarHeight)]);
  [sidebarScroll setAutoresizingMask: NSViewHeightSizable];
  [sidebarScroll setBorderType: NSNoBorder];
  [sidebarScroll setHasVerticalScroller: NO];
  [sidebarScroll setDrawsBackground: NO];
  sidebar = AUTORELEASE([[HPSidebar alloc] initWithFrame:
    NSMakeRect(0, 0, HPSidebarWidth, NSHeight(b) - HPToolbarHeight)]);
  [sidebar setAutoresizingMask: NSViewWidthSizable];
  [sidebar setDelegate: self];
  [sidebarScroll setDocumentView: sidebar];
  [content addSubview: sidebarScroll];

  pageScroll = AUTORELEASE([[NSScrollView alloc] initWithFrame:
    NSMakeRect(HPSidebarWidth + 1, 0, NSWidth(b) - HPSidebarWidth - 1,
               NSHeight(b) - HPToolbarHeight)]);
  [pageScroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [pageScroll setBorderType: NSNoBorder];
  [pageScroll setHasVerticalScroller: YES];
  [pageScroll setAutohidesScrollers: YES];
  [pageScroll setBackgroundColor: [HPStyle page]];
  pageView = AUTORELEASE([[HPPageView alloc] initWithFrame:
    NSMakeRect(0, 0, [pageScroll contentSize].width,
               [pageScroll contentSize].height)]);
  [pageView setAutoresizingMask: NSViewWidthSizable];
  [pageView setDelegate: self];
  [pageScroll setDocumentView: pageView];
  [content addSubview: pageScroll];

  [sidebar setBooks: [[HPLibrary sharedLibrary] books]];
  [window center];
  [window setFrameUsingName: @"Help"];
  [window setFrameAutosaveName: @"Help"];
}

/* ---- showing things ---------------------------------------------------- */

- (NSDictionary *) place
{
  if (query != nil)
    return [NSDictionary dictionaryWithObject: query forKey: @"query"];
  if (book != nil)
    return [NSDictionary dictionaryWithObjectsAndKeys: book, @"book",
                         topic, @"topic", nil];
  return nil;
}

- (void) updateButtons
{
  [[toolbar viewWithTag: 1] setEnabled: [back count] > 0];
  [[toolbar viewWithTag: 2] setEnabled: [forward count] > 0];
  [[toolbar viewWithTag: 1] setNeedsDisplay: YES];
  [[toolbar viewWithTag: 2] setNeedsDisplay: YES];
}

/* Show a place without touching the history. */
- (void) display: (NSDictionary *)place
{
  NSString *q = [place objectForKey: @"query"];

  if (q != nil)
    {
      ASSIGN(query, q);
      [toolbar setTitle: @"Search"];
      [sidebar showBook: book topic: nil];
      [pageView setPage: [HPPageBuilder pageForResults:
        [[HPLibrary sharedLibrary] search: q] query: q]];
      if (![[searchField stringValue] isEqual: q])
        [searchField setStringValue: q];
    }
  else
    {
      HPBook *b = [place objectForKey: @"book"];
      HPTopic *t = [place objectForKey: @"topic"];

      DESTROY(query);
      ASSIGN(book, b);
      ASSIGN(topic, t);
      [toolbar setTitle: [b title]];
      [sidebar showBook: b topic: t];
      [pageView setPage: t != nil ? [HPPageBuilder pageForTopic: t]
                                  : [HPPageBuilder pageForBook: b]];
    }
  [self updateButtons];
}

- (void) go: (NSDictionary *)place
{
  NSDictionary *here = [self place];

  if (place == nil || [place isEqual: here])
    return;
  /* Typing a search replaces the search being shown. */
  if (here != nil && !([here objectForKey: @"query"] != nil
                       && [place objectForKey: @"query"] != nil))
    [back addObject: here];
  [forward removeAllObjects];
  [self display: place];
}

- (void) showBook: (HPBook *)b topicNamed: (NSString *)ident
{
  HPTopic *t = [b topicWithIdentifier: ident];

  if (t == nil && [[b topics] count] > 0)
    t = [[b topics] objectAtIndex: 0];
  [self go: [NSDictionary dictionaryWithObjectsAndKeys: b, @"book",
                          t, @"topic", nil]];
}

- (void) showSearch: (NSString *)q
{
  q = [q stringByTrimmingCharactersInSet:
           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([q length] == 0)
    return;
  [self go: [NSDictionary dictionaryWithObject: q forKey: @"query"]];
}

- (HPBook *) bookFor: (NSString *)name
{
  HPLibrary *lib = [HPLibrary sharedLibrary];
  HPBook *b;

  if ([name length] == 0)
    return nil;
  if ([name isAbsolutePath])
    return [lib bookAtPath: name];
  b = [lib bookNamed: name];
  if (b == nil)
    {
      [lib rescan];
      [sidebar setBooks: [lib books]];
      b = [lib bookNamed: name];
    }
  return b;
}

- (oneway void) showBook: (NSString *)name
                   topic: (NSString *)ident
                  search: (NSString *)q
{
  HPBook *b = [self bookFor: name];

  if ([q length] > 0)
    {
      if (b != nil && book == nil)
        [self showBook: b topicNamed: nil];
      [self showSearch: q];
      [window makeFirstResponder: searchField];
    }
  else if (b != nil)
    [self showBook: b topicNamed: ident];
  else if (book == nil)
    [self goHome: nil];
  [window makeKeyAndOrderFront: nil];
  [NSApp activateIgnoringOtherApps: YES];
}

/* ---- actions --------------------------------------------------------- */

- (void) goBack: (id)sender
{
  NSDictionary *here = [self place];
  NSDictionary *p = RETAIN([back lastObject]);

  if (p == nil)
    return;
  [back removeLastObject];
  if (here != nil)
    [forward addObject: here];
  [self display: p];
  RELEASE(p);
}

- (void) goForward: (id)sender
{
  NSDictionary *here = [self place];
  NSDictionary *p = RETAIN([forward lastObject]);

  if (p == nil)
    return;
  [forward removeLastObject];
  if (here != nil)
    [back addObject: here];
  [self display: p];
  RELEASE(p);
}

- (void) goHome: (id)sender
{
  NSArray *books = [[HPLibrary sharedLibrary] books];

  if ([books count] > 0)
    [self showBook: [books objectAtIndex: 0] topicNamed: nil];
  [window makeKeyAndOrderFront: nil];
}

- (void) search: (id)sender
{
  NSString *q = [searchField stringValue];

  if ([[q stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]] length] == 0)
    {
      /* Clearing the field goes back to the topic. */
      if (query != nil && [back count] > 0)
        [self goBack: nil];
      return;
    }
  [self showSearch: q];
}

- (void) controlTextDidChange: (NSNotification *)n
{
  if ([n object] == searchField)
    [self search: searchField];
}

- (void) findInHelp: (id)sender
{
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: searchField];
}

- (BOOL) validateMenuItem: (id <NSMenuItem>)item
{
  if ([item action] == @selector(goBack:))
    return [back count] > 0;
  if ([item action] == @selector(goForward:))
    return [forward count] > 0;
  return YES;
}

/* ---- the sidebar and the page ------------------------------------------ */

- (void) sidebarChoseBook: (HPBook *)b
{
  if (b == book && query == nil)
    return;
  [self showBook: b topicNamed: nil];
}

- (void) sidebarChoseTopic: (HPTopic *)t
{
  [self go: [NSDictionary dictionaryWithObjectsAndKeys: [t book], @"book",
                          t, @"topic", nil]];
}

- (void) followLink: (NSString *)link
{
  if ([link hasPrefix: @"topic:"])
    {
      NSString *rest = [link substringFromIndex: 6];
      NSRange slash = [rest rangeOfString: @"/"];
      HPBook *b = book;
      NSString *ident = rest;
      HPTopic *t;

      if (slash.location != NSNotFound)
        {
          b = [self bookFor: [rest substringToIndex: slash.location]];
          ident = [rest substringFromIndex: NSMaxRange(slash)];
        }
      t = [b topicWithIdentifier: ident];
      if (t != nil)
        [self go: [NSDictionary dictionaryWithObjectsAndKeys: b, @"book",
                                t, @"topic", nil]];
      else
        NSBeep();
    }
  else if ([link rangeOfString: @":"].location != NSNotFound)
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: link]];
}

/* ---- appearance ------------------------------------------------------ */

- (void) settingsChanged: (NSNotification *)n
{
  NSString *key = [[n userInfo] objectForKey: @"key"];

  if (key != nil && ![key isEqual: @"NBAppearance"])
    return;
  [HPStyle reload];
  [pageScroll setBackgroundColor: [HPStyle page]];
  if ([self place] != nil)
    {
      NSPoint scrolled = [[pageScroll contentView] bounds].origin;

      [self display: [self place]];
      [pageView scrollPoint: scrolled];
    }
  [[window contentView] setNeedsDisplay: YES];
}

/* ---- the application ----------------------------------------------------- */

- (BOOL) application: (NSApplication *)app openFile: (NSString *)file
{
  NSArray *parts = [file pathComponents];
  NSUInteger i;

  /* A .help bundle, or something in one: Book.help/topic-id. */
  for (i = 0; i < [parts count]; i++)
    if ([[[parts objectAtIndex: i] pathExtension] isEqual: @"help"])
      {
        NSString *bookPath = [NSString pathWithComponents:
          [parts subarrayWithRange: NSMakeRange(0, i + 1)]];
        NSString *ident = i + 1 < [parts count]
          ? [parts objectAtIndex: i + 1] : nil;

        if (window == nil)
          [self makeWindow];
        [self showBook: bookPath topic: ident search: nil];
        return YES;
      }
  return NO;
}

- (void) applicationWillFinishLaunching: (NSNotification *)n
{
  [self makeMenu];
}

- (void) applicationDidFinishLaunching: (NSNotification *)n
{
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  NSString *b = [d stringForKey: @"NBHelpBook"];
  NSString *t = [d stringForKey: @"NBHelpTopic"];
  NSString *q = [d stringForKey: @"NBHelpSearch"];

  if (window == nil)
    [self makeWindow];
  service = [[NSConnection alloc] init];
  [service setRootObject: self];
  if (![service registerName: HPServiceName])
    NSLog(@"Help: couldn't register %@", HPServiceName);
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver: self selector: @selector(settingsChanged:)
           name: @"org.nextbsd.DesktopSettingsChanged" object: nil];
  if (book == nil || [b length] > 0 || [q length] > 0)
    [self showBook: b topic: t search: q];
  [window makeKeyAndOrderFront: nil];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)app
{
  return YES;
}

@end
