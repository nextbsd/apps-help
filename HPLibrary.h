/*
    HPLibrary.h: every help book on the system, and searching them.

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

#ifndef __HP_LIBRARY_H__
#define __HP_LIBRARY_H__

#import "HPBook.h"

/* Books are .help bundles: Help.app's own (NextBSD Help) and those in
   each app's Resources, in CoreServices, /System/Applications,
   /Applications and ~/Applications. */
@interface HPLibrary : NSObject
{
  NSMutableArray *books;
}

+ (HPLibrary *) sharedLibrary;
- (void) rescan;
- (NSArray *) books;
- (HPBook *) bookNamed: (NSString *)name;
/* The book at this path, added to the library if it isn't in it. */
- (HPBook *) bookAtPath: (NSString *)path;
/* Topics whose title, keywords or text have every word of the query,
   best first. */
- (NSArray *) search: (NSString *)query;
@end

/* A sentence around the first match, for a search result. */
NSString *HPSnippet(HPTopic *t, NSString *query);

#endif
