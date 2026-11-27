/*
    HPLibrary.m: every help book on the system, and searching them.

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

#import "HPLibrary.h"
#import "GNUstep.h"

static NSInteger HPCompareResults(id a, id b, void *context);

@implementation HPLibrary

+ (HPLibrary *) sharedLibrary
{
  static HPLibrary *shared = nil;

  if (shared == nil)
    {
      shared = [HPLibrary new];
      [shared rescan];
    }
  return shared;
}

- (void) dealloc
{
  RELEASE(books);
  [super dealloc];
}

- (void) addBooksOfBundle: (NSBundle *)b app: (NSString *)app
                     into: (NSMutableArray *)list seen: (NSMutableSet *)seen
{
  NSArray *paths = [b pathsForResourcesOfType: @"help" inDirectory: nil];
  NSEnumerator *e = [[paths sortedArrayUsingSelector: @selector(compare:)]
                      objectEnumerator];
  NSString *p;

  while ((p = [e nextObject]) != nil)
    {
      NSString *name = [[p lastPathComponent] stringByDeletingPathExtension];
      HPBook *book;

      /* HelpViewer's own book, from the app this was forked from. */
      if ([name isEqual: @"HelpViewer"] || [seen containsObject: name])
        continue;
      [seen addObject: name];
      book = [[HPBook alloc] initWithPath: p app: app];
      [list addObject: book];
      RELEASE(book);
    }
}

- (void) rescan
{
  NSMutableArray *list = [NSMutableArray array];
  NSMutableSet *seen = [NSMutableSet set];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray *dirs = [NSMutableArray arrayWithObjects:
    @"/System/Library/CoreServices", @"/System/Applications", nil];
  NSEnumerator *e;
  NSString *d;

  /* NextBSD Help, which comes with Help, first. */
  [self addBooksOfBundle: [NSBundle mainBundle] app: nil
                    into: list seen: seen];
  [dirs addObjectsFromArray: NSSearchPathForDirectoriesInDomains(
    NSApplicationDirectory, NSAllDomainsMask, YES)];
  e = [dirs objectEnumerator];
  while ((d = [e nextObject]) != nil)
    {
      NSArray *apps = [[fm directoryContentsAtPath: d]
                        sortedArrayUsingSelector:
                          @selector(caseInsensitiveCompare:)];
      NSEnumerator *ae = [apps objectEnumerator];
      NSString *a;

      while ((a = [ae nextObject]) != nil)
        {
          NSString *app = [d stringByAppendingPathComponent: a];
          NSBundle *b;

          if (![[a pathExtension] isEqual: @"app"]
              || [app isEqual: [[NSBundle mainBundle] bundlePath]])
            continue;
          b = [NSBundle bundleWithPath: app];
          if (b != nil)
            [self addBooksOfBundle: b app: app into: list seen: seen];
        }
    }
  ASSIGN(books, list);
}

- (NSArray *) books
{
  return books;
}

- (HPBook *) bookNamed: (NSString *)name
{
  NSEnumerator *e = [books objectEnumerator];
  HPBook *b;

  while ((b = [e nextObject]) != nil)
    if ([[b name] isEqual: name] || [[b title] isEqual: name])
      return b;
  return nil;
}

- (HPBook *) bookAtPath: (NSString *)p
{
  NSEnumerator *e = [books objectEnumerator];
  HPBook *b;

  p = [p stringByStandardizingPath];
  while ((b = [e nextObject]) != nil)
    if ([[[b path] stringByStandardizingPath] isEqual: p])
      return b;
  {
    /* A book in an app's Resources belongs to that app. */
    NSRange r = [p rangeOfString: @".app/"];
    NSString *app = r.location != NSNotFound
      ? [p substringToIndex: r.location + 4] : nil;

    b = AUTORELEASE([[HPBook alloc] initWithPath: p app: app]);
  }
  [books addObject: b];
  return b;
}

static NSArray *
HPWords(NSString *q)
{
  NSMutableArray *a = [NSMutableArray array];
  NSEnumerator *e = [[[q lowercaseString] componentsSeparatedByString: @" "]
                      objectEnumerator];
  NSString *w;

  while ((w = [e nextObject]) != nil)
    if ([w length] > 0)
      [a addObject: w];
  return a;
}

/* Does `word` start a word in `s`? */
static BOOL
HPStartsWord(NSString *s, NSString *word)
{
  NSRange r = NSMakeRange(0, [s length]);

  while (r.length > 0)
    {
      NSRange f = [s rangeOfString: word options: 0 range: r];

      if (f.location == NSNotFound)
        return NO;
      if (f.location == 0
          || ![[NSCharacterSet alphanumericCharacterSet]
                characterIsMember: [s characterAtIndex: f.location - 1]])
        return YES;
      r = NSMakeRange(NSMaxRange(f), [s length] - NSMaxRange(f));
    }
  return NO;
}

- (NSArray *) search: (NSString *)query
{
  NSArray *words = HPWords(query);
  NSMutableArray *found = [NSMutableArray array];
  NSEnumerator *be = [books objectEnumerator];
  HPBook *b;
  NSInteger rank = 0;

  if ([words count] == 0)
    return found;
  while ((b = [be nextObject]) != nil)
    {
      NSEnumerator *te = [[b allTopics] objectEnumerator];
      HPTopic *t;

      while ((t = [te nextObject]) != nil)
        {
          NSString *title = [t lowercaseTitle];
          NSString *kw = [[t keywords] lowercaseString];
          NSString *text = [t searchText];
          NSEnumerator *we = [words objectEnumerator];
          NSString *w;
          NSInteger score = 0;

          while ((w = [we nextObject]) != nil)
            {
              if (HPStartsWord(title, w))
                score += 100;
              else if ([title rangeOfString: w].location != NSNotFound)
                score += 60;
              else if (kw != nil && HPStartsWord(kw, w))
                score += 40;
              else if (HPStartsWord(text, w))
                score += 10;
              else
                {
                  score = 0;
                  break;
                }
            }
          if (score > 0)
            [found addObject: [NSArray arrayWithObjects: t,
              [NSNumber numberWithInteger: score],
              [NSNumber numberWithInteger: rank++], nil]];
        }
    }
  [found sortUsingFunction: HPCompareResults context: NULL];
  {
    NSMutableArray *topics = [NSMutableArray array];
    NSEnumerator *e = [found objectEnumerator];
    NSArray *r;

    while ((r = [e nextObject]) != nil)
      [topics addObject: [r objectAtIndex: 0]];
    return topics;
  }
}

static NSInteger
HPCompareResults(id a, id b, void *context)
{
  NSInteger sa = [[a objectAtIndex: 1] integerValue];
  NSInteger sb = [[b objectAtIndex: 1] integerValue];

  if (sa != sb)
    return sa > sb ? NSOrderedAscending : NSOrderedDescending;
  return [[a objectAtIndex: 2] compare: [b objectAtIndex: 2]];
}

@end

NSString *
HPSnippet(HPTopic *t, NSString *query)
{
  NSMutableString *body = [NSMutableString string];
  NSEnumerator *e = [[t content] objectEnumerator];
  HPNode *n;
  NSArray *words = HPWords(query);
  NSRange r = NSMakeRange(NSNotFound, 0);
  NSUInteger start, end, len;

  while ((n = [e nextObject]) != nil)
    [body appendFormat: @"%@ ", [n plainText]];
  body = (NSMutableString *)[HPFoldSpace(body) stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
  len = [body length];
  if ([words count] > 0)
    r = [body rangeOfString: [words objectAtIndex: 0]
                    options: NSCaseInsensitiveSearch];
  if (r.location == NSNotFound)
    r = NSMakeRange(0, 0);
  /* From the start of its sentence, about 160 characters. */
  start = r.location;
  while (start > 0 && start + 120 > r.location)
    {
      unichar c = [body characterAtIndex: start - 1];

      if (c == '.' || c == '!' || c == '?')
        break;
      start--;
    }
  while (start < len && [body characterAtIndex: start] == ' ')
    start++;
  end = MIN(len, start + 160);
  if (end < len)
    {
      NSRange sp = [body rangeOfString: @" " options: NSBackwardsSearch
                                 range: NSMakeRange(start, end - start)];

      if (sp.location != NSNotFound && sp.location > start)
        end = sp.location;
    }
  return [NSString stringWithFormat: @"%@%@%@", start > 0 ? @"…" : @"",
                   [body substringWithRange: NSMakeRange(start, end - start)],
                   end < len ? @"…" : @""];
}
