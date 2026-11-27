/*
    HPPage.h: a help page, laid out as blocks (text, figures with
    numbered callouts, tips, key tables) and drawn in a view.

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

#ifndef __HP_PAGE_H__
#define __HP_PAGE_H__

#import <AppKit/AppKit.h>
#import "HPBook.h"

/* A link on a page: "topic:<book>/<id>", or a URL. */
@protocol HPPageDelegate
- (void) followLink: (NSString *)link;
@end

/* Something laid out down the page. Coordinates are flipped (y down),
   from the block's top left. */
@interface HPBlock : NSObject
{
  NSSize size;
  CGFloat spaceBefore;
}
- (CGFloat) spaceBefore;
- (void) setSpaceBefore: (CGFloat)s;
- (NSSize) size;
/* Lays it out to this width; returns the height. */
- (CGFloat) layoutForWidth: (CGFloat)width;
- (void) drawAt: (NSPoint)origin;
- (NSString *) linkAt: (NSPoint)p;
/* Each link's rectangle (NSValue), offset by origin. */
- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin;
@end

/* The page for a topic, or for search results. */
@interface HPPageBuilder : NSObject
+ (HPBlock *) pageForTopic: (HPTopic *)topic;
+ (HPBlock *) pageForResults: (NSArray *)topics query: (NSString *)query;
+ (HPBlock *) pageForBook: (HPBook *)book;
@end

@interface HPPageView : NSView
{
  HPBlock *page;
  id <HPPageDelegate> delegate;   /* not retained */
  CGFloat laidOutWidth;
}
- (void) setDelegate: (id <HPPageDelegate>)d;
- (void) setPage: (HPBlock *)p;
/* Lays the page out again for the scroll view's width. */
- (void) relayout;
@end

#endif
