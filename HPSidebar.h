/*
    HPSidebar.h: the books, and the chosen book's topics.

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

#ifndef __HP_SIDEBAR_H__
#define __HP_SIDEBAR_H__

#import <AppKit/AppKit.h>
#import "HPBook.h"

@protocol HPSidebarDelegate
- (void) sidebarChoseBook: (HPBook *)book;
- (void) sidebarChoseTopic: (HPTopic *)topic;
@end

/* BOOKS, then the chosen book's name and its topics. A topic's own
   topics show below it while it, or one of them, is the one shown. */
@interface HPSidebar : NSView
{
  NSArray *books;
  HPBook *book;
  HPTopic *topic;
  NSMutableArray *rows;   /* {kind, object, rect} */
  id <HPSidebarDelegate> delegate;
}
- (void) setDelegate: (id <HPSidebarDelegate>)d;
- (void) setBooks: (NSArray *)b;
- (void) showBook: (HPBook *)b topic: (HPTopic *)t;
@end

#endif
