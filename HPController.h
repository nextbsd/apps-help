/*
    HPController.h: Help's window, its navigation and search, and how
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

#ifndef __HP_CONTROLLER_H__
#define __HP_CONTROLLER_H__

#import <AppKit/AppKit.h>
#import "HPPage.h"
#import "HPSidebar.h"

/* The name Help registers its service under. Other apps (the NextBSD
   theme's Help menu, libs-gui's -showHelp:) ask a running Help through
   it; when Help isn't running they start it with the same three things
   as defaults on its command line: -NBHelpBook, -NBHelpTopic and
   -NBHelpSearch. */
#define HPServiceName @"org.nextbsd.Help"

@protocol HPService
/* book: a book's name (NextBSD, Workspace) or a .help bundle's path;
   topic: a topic's id or title in it; query: a search. Any may be nil
   or empty. */
- (oneway void) showBook: (NSString *)book
                   topic: (NSString *)topic
                  search: (NSString *)query;
@end

@class HPToolbar;

@interface HPController : NSObject <HPPageDelegate, HPSidebarDelegate, HPService>
{
  NSWindow *window;
  HPToolbar *toolbar;
  HPSidebar *sidebar;
  NSScrollView *sidebarScroll;
  HPPageView *pageView;
  NSScrollView *pageScroll;
  NSTextField *searchField;
  NSConnection *service;

  HPBook *book;
  HPTopic *topic;
  NSString *query;
  NSMutableArray *back;
  NSMutableArray *forward;
}

- (void) goBack: (id)sender;
- (void) goForward: (id)sender;
- (void) goHome: (id)sender;
- (void) search: (id)sender;
- (void) findInHelp: (id)sender;
@end

#endif
