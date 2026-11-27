/*
    HPBook.h: a help book (a .help bundle) and its topics.

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

#ifndef __HP_BOOK_H__
#define __HP_BOOK_H__

#import <AppKit/AppKit.h>
#import "HPXLP.h"

@class HPBook;

/* A topic: a <part>, <chapter>, <section> or <plain> of the book, shown
   as a page of its own. Topics inside it are listed in the sidebar
   below it, not shown on its page. */
@interface HPTopic : NSObject
{
  NSString *title;
  NSString *identifier;
  NSString *keywords;
  HPNode *node;
  NSMutableArray *subtopics;
  HPTopic *parent;              /* not retained */
  HPBook *book;                 /* not retained */
  NSString *searchText;
}

- (NSString *) title;
- (NSString *) identifier;
- (HPNode *) node;
- (NSArray *) subtopics;
- (HPTopic *) parent;
- (HPBook *) book;
- (NSUInteger) depth;
/* The page's own content: the node's children without the subtopics. */
- (NSArray *) content;
/* Lower-case title, keywords and text, for searching. */
- (NSString *) searchText;
- (NSString *) lowercaseTitle;
- (NSString *) keywords;
- (BOOL) isAncestorOf: (HPTopic *)t;
@end

@interface HPBook : NSObject
{
  NSString *path;
  NSString *name;
  NSString *title;
  NSString *appPath;
  NSImage *icon;
  NSMutableArray *topics;
  NSMutableArray *allTopics;
  NSMutableDictionary *byIdentifier;
  BOOL loaded;
}

/* path: the .help bundle; appPath: the app it came in, or nil. */
- (id) initWithPath: (NSString *)aPath app: (NSString *)anApp;

- (NSString *) path;
/* The bundle's name: NextBSD for NextBSD.help. */
- (NSString *) name;
/* The <title> in its header, else "<name> Help". */
- (NSString *) title;
- (NSString *) appPath;
- (NSImage *) icon;
- (NSArray *) topics;
/* Every topic, in reading order. */
- (NSArray *) allTopics;
- (HPTopic *) topicWithIdentifier: (NSString *)ident;
/* A file in the bundle (an image), for this appearance if there's one:
   name-dark.png or name-light.png before name.png. */
- (NSString *) pathForResource: (NSString *)file light: (BOOL)light;
@end

#endif
