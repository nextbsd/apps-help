/*
    HPSidebar.m: the books, and the chosen book's topics.

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

#import "HPSidebar.h"
#import "HPStyle.h"
#import "GNUstep.h"

enum { HPRowHeading, HPRowBook, HPRowTopic };

@implementation HPSidebar

- (id) initWithFrame: (NSRect)f
{
  if ((self = [super initWithFrame: f]) != nil)
    rows = [[NSMutableArray alloc] init];
  return self;
}

- (void) dealloc
{
  RELEASE(books);
  RELEASE(book);
  RELEASE(topic);
  RELEASE(rows);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) setDelegate: (id <HPSidebarDelegate>)d
{
  delegate = d;
}

- (void) addRow: (int)kind object: (id)o height: (CGFloat)h at: (CGFloat *)y
{
  NSRect r = NSMakeRect(8, *y, NSWidth([self bounds]) - 16, h);

  [rows addObject: [NSArray arrayWithObjects: [NSNumber numberWithInt: kind],
                            o, [NSValue valueWithRect: r], nil]];
  *y += h;
}

- (void) addTopics: (NSArray *)topics at: (CGFloat *)y
{
  NSEnumerator *e = [topics objectEnumerator];
  HPTopic *t;

  while ((t = [e nextObject]) != nil)
    {
      [self addRow: HPRowTopic object: t height: 24 at: y];
      *y += 1;
      if (t == topic || [t isAncestorOf: topic])
        [self addTopics: [t subtopics] at: y];
    }
}

- (void) rebuild
{
  CGFloat y = 12;
  NSScrollView *sv = [self enclosingScrollView];
  NSEnumerator *e;
  HPBook *b;

  [rows removeAllObjects];
  [self addRow: HPRowHeading object: @"Books" height: 22 at: &y];
  e = [books objectEnumerator];
  while ((b = [e nextObject]) != nil)
    {
      [self addRow: HPRowBook object: b height: 26 at: &y];
      y += 1;
    }
  if (book != nil)
    {
      y += 10;
      [self addRow: HPRowHeading object: [book name] height: 22 at: &y];
      [self addTopics: [book topics] at: &y];
    }
  y += 12;
  [self setFrameSize: NSMakeSize(NSWidth([self frame]),
                                 MAX(y, sv ? [sv contentSize].height : 0))];
  [self setNeedsDisplay: YES];
}

- (void) setBooks: (NSArray *)b
{
  ASSIGN(books, b);
  [self rebuild];
}

- (void) showBook: (HPBook *)b topic: (HPTopic *)t
{
  ASSIGN(book, b);
  ASSIGN(topic, t);
  [self rebuild];
  /* Keep the topic in view. */
  {
    NSEnumerator *e = [rows objectEnumerator];
    NSArray *row;

    while ((row = [e nextObject]) != nil)
      if ([row objectAtIndex: 1] == t)
        [self scrollRectToVisible: [[row objectAtIndex: 2] rectValue]];
  }
}

- (void) resizeWithOldSuperviewSize: (NSSize)old
{
  [super resizeWithOldSuperviewSize: old];
  [self rebuild];
}

- (void) drawRect: (NSRect)dirty
{
  NSEnumerator *e = [rows objectEnumerator];
  NSArray *row;

  [[HPStyle sidebar] set];
  NSRectFill(dirty);
  while ((row = [e nextObject]) != nil)
    {
      int kind = [[row objectAtIndex: 0] intValue];
      id o = [row objectAtIndex: 1];
      NSRect r = [[row objectAtIndex: 2] rectValue];

      if (!NSIntersectsRect(r, dirty))
        continue;
      if (kind == HPRowHeading)
        {
          NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
            [HPStyle semiboldFontOfSize: 11], NSFontAttributeName,
            [HPStyle faint], NSForegroundColorAttributeName,
            [NSNumber numberWithFloat: 0.9], NSKernAttributeName, nil];

          [[o uppercaseString] drawAtPoint: NSMakePoint(NSMinX(r) + 10,
                                                        NSMinY(r) + 4)
                            withAttributes: a];
        }
      else if (kind == HPRowBook)
        {
          HPBook *b = o;
          NSImage *icon = [b icon];
          NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
            [HPStyle semiboldFontOfSize: 12], NSFontAttributeName,
            [HPStyle text], NSForegroundColorAttributeName, nil];
          CGFloat x = NSMinX(r) + 10;

          if (b == book)
            {
              [[HPStyle selection] set];
              [[HPStyle roundedRect: r radius: 6] fill];
            }
          if (icon != nil)
            [icon drawInRect: NSMakeRect(x, NSMinY(r) + 4, 18, 18)
                    fromRect: NSZeroRect
                   operation: NSCompositeSourceOver
                    fraction: 1.0 respectFlipped: YES hints: nil];
          [[b name] drawAtPoint: NSMakePoint(x + 26, NSMinY(r) + 5)
                 withAttributes: a];
        }
      else
        {
          HPTopic *t = o;
          BOOL chosen = (t == topic);
          NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
            chosen ? [HPStyle semiboldFontOfSize: 12]
                   : [HPStyle fontOfSize: 12], NSFontAttributeName,
            chosen ? [HPStyle accentText] : [HPStyle text],
            NSForegroundColorAttributeName, nil];
          CGFloat x = NSMinX(r) + 10 + 16 * [t depth];
          NSString *title = [t title];

          if (chosen)
            {
              [[HPStyle accent] set];
              [[HPStyle roundedRect: r radius: 6] fill];
            }
          /* Cut long titles short with an ellipsis. */
          while ([title length] > 4
                 && [title sizeWithAttributes: a].width > NSMaxX(r) - x - 6)
            title = [[title substringToIndex: [title length] - 2]
                      stringByAppendingString: @"…"];
          [title drawAtPoint: NSMakePoint(x, NSMinY(r) + 4) withAttributes: a];
        }
    }
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
  NSEnumerator *e = [rows objectEnumerator];
  NSArray *row;

  while ((row = [e nextObject]) != nil)
    {
      int kind = [[row objectAtIndex: 0] intValue];

      if (!NSPointInRect(p, [[row objectAtIndex: 2] rectValue]))
        continue;
      if (kind == HPRowBook)
        [delegate sidebarChoseBook: [row objectAtIndex: 1]];
      else if (kind == HPRowTopic)
        [delegate sidebarChoseTopic: [row objectAtIndex: 1]];
      return;
    }
}

@end
