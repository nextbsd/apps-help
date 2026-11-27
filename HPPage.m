/*
    HPPage.m: a help page, laid out as blocks (text, figures with
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

#import "HPPage.h"
#import "HPStyle.h"
#import "HPLibrary.h"
#import "GNUstep.h"

/* The text attribute that marks a key cap (<kbd>). */
static NSString *const HPKeyAttribute = @"HPKey";

/* The page's margins and its widest paragraph. */
static const CGFloat HPMarginX = 40, HPMarginTop = 26, HPMarginBottom = 40;
static const CGFloat HPMeasure = 640;

/* ---- blocks ------------------------------------------------------------ */

@implementation HPBlock

- (CGFloat) spaceBefore { return spaceBefore; }
- (void) setSpaceBefore: (CGFloat)s { spaceBefore = s; }
- (NSSize) size { return size; }

- (CGFloat) layoutForWidth: (CGFloat)width
{
  size = NSMakeSize(width, 0);
  return 0;
}

- (void) drawAt: (NSPoint)origin
{
}

- (NSString *) linkAt: (NSPoint)p
{
  return nil;
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
}

@end

/* Text: a paragraph, a heading, a line of links. */
@interface HPTextBlock : HPBlock
{
  NSTextStorage *storage;
  NSLayoutManager *layout;
  NSTextContainer *container;
  CGFloat maxWidth;
}
- (id) initWithString: (NSAttributedString *)s;
- (void) setMaxWidth: (CGFloat)w;
- (CGFloat) naturalWidth;
- (BOOL) isEmpty;
@end

@implementation HPTextBlock

- (id) initWithString: (NSAttributedString *)s
{
  if ((self = [super init]) != nil)
    {
      storage = [[NSTextStorage alloc] initWithAttributedString: s];
      layout = [[NSLayoutManager alloc] init];
      container = [[NSTextContainer alloc]
                    initWithContainerSize: NSMakeSize(400, 1e7)];
      [container setLineFragmentPadding: 0];
      [layout addTextContainer: container];
      [storage addLayoutManager: layout];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(container);
  RELEASE(layout);
  RELEASE(storage);
  [super dealloc];
}

- (BOOL) isEmpty
{
  return [[[storage string] stringByTrimmingCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;
}

- (void) setMaxWidth: (CGFloat)w
{
  maxWidth = w;
}

- (NSRect) usedRectForWidth: (CGFloat)w
{
  [container setContainerSize: NSMakeSize(w, 1e7)];
  [layout glyphRangeForTextContainer: container];
  return [layout usedRectForTextContainer: container];
}

- (CGFloat) naturalWidth
{
  return ceil(NSWidth([self usedRectForWidth: 1e5]));
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSRect used;

  if (maxWidth > 0 && width > maxWidth)
    width = maxWidth;
  used = [self usedRectForWidth: width];
  size = NSMakeSize(width, ceil(NSMaxY(used)));
  return size.height;
}

- (NSRect) rectForCharacters: (NSRange)chars
{
  NSRange glyphs = [layout glyphRangeForCharacterRange: chars
                                  actualCharacterRange: NULL];

  return [layout boundingRectForGlyphRange: glyphs
                           inTextContainer: container];
}

- (void) drawAt: (NSPoint)origin
{
  NSRange all = NSMakeRange(0, [storage length]);
  NSUInteger i = 0;

  /* Key caps under their text. */
  while (i < all.length)
    {
      NSRange r;
      id key = [storage attribute: HPKeyAttribute atIndex: i
                    longestEffectiveRange: &r inRange: all];

      if (key != nil)
        {
          NSFont *f = [storage attribute: NSFontAttributeName atIndex: i
                          effectiveRange: NULL];
          NSRect cap = [self rectForCharacters: r];
          CGFloat h = ceil([f ascender] - [f descender]) + 5;
          NSBezierPath *p;

          cap.origin.x += origin.x;
          cap.origin.y += origin.y + floor(([f ascender] - [f descender]
                                            + 2 - h) / 2) + 1;
          cap.size.height = h;
          cap = NSInsetRect(cap, 0.5, 0.5);
          p = [HPStyle roundedRect: cap radius: 5];
          [[HPStyle keyCap] set];
          [p fill];
          [[HPStyle line] set];
          [p setLineWidth: 1];
          [p stroke];
        }
      i = NSMaxRange(r);
    }
  [layout drawGlyphsForGlyphRange:
            [layout glyphRangeForTextContainer: container]
                          atPoint: origin];
}

- (NSString *) linkAt: (NSPoint)p
{
  CGFloat frac;
  NSUInteger g, c;
  id link;
  NSRect r;

  if ([storage length] == 0)
    return nil;
  g = [layout glyphIndexForPoint: p inTextContainer: container
          fractionOfDistanceThroughGlyph: &frac];
  r = [layout boundingRectForGlyphRange: NSMakeRange(g, 1)
                        inTextContainer: container];
  if (!NSPointInRect(p, NSInsetRect(r, -1, -2)))
    return nil;
  c = [layout characterIndexForGlyphAtIndex: g];
  if (c >= [storage length])
    return nil;
  link = [storage attribute: NSLinkAttributeName atIndex: c
             effectiveRange: NULL];
  return [link isKindOfClass: [NSURL class]] ? [link absoluteString] : link;
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  NSRange all = NSMakeRange(0, [storage length]);
  NSUInteger i = 0;

  while (i < all.length)
    {
      NSRange r;
      id link = [storage attribute: NSLinkAttributeName atIndex: i
                 longestEffectiveRange: &r inRange: all];

      if (link != nil)
        {
          NSRect rect = [self rectForCharacters: r];

          rect.origin.x += origin.x;
          rect.origin.y += origin.y;
          [rects addObject: [NSValue valueWithRect: rect]];
        }
      i = NSMaxRange(r);
    }
}

@end

/* Blocks one below the other. */
@interface HPStack : HPBlock
{
  NSMutableArray *blocks;
  NSMutableArray *offsets;
}
- (void) addBlock: (HPBlock *)b;
- (NSArray *) blocks;
@end

@implementation HPStack

- (id) init
{
  if ((self = [super init]) != nil)
    {
      blocks = [[NSMutableArray alloc] init];
      offsets = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(blocks);
  RELEASE(offsets);
  [super dealloc];
}

- (void) addBlock: (HPBlock *)b
{
  if (b != nil)
    [blocks addObject: b];
}

- (NSArray *) blocks
{
  return blocks;
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSEnumerator *e = [blocks objectEnumerator];
  HPBlock *b;
  CGFloat y = 0;
  BOOL first = YES;

  [offsets removeAllObjects];
  while ((b = [e nextObject]) != nil)
    {
      if (!first)
        y += [b spaceBefore];
      first = NO;
      [offsets addObject: [NSNumber numberWithDouble: y]];
      y += [b layoutForWidth: width];
    }
  size = NSMakeSize(width, ceil(y));
  return size.height;
}

- (void) drawAt: (NSPoint)origin
{
  NSUInteger i;

  for (i = 0; i < [blocks count] && i < [offsets count]; i++)
    [[blocks objectAtIndex: i] drawAt:
      NSMakePoint(origin.x, origin.y + [[offsets objectAtIndex: i] doubleValue])];
}

- (NSString *) linkAt: (NSPoint)p
{
  NSUInteger i;

  for (i = 0; i < [blocks count] && i < [offsets count]; i++)
    {
      HPBlock *b = [blocks objectAtIndex: i];
      CGFloat y = [[offsets objectAtIndex: i] doubleValue];

      if (p.y >= y && p.y < y + [b size].height)
        return [b linkAt: NSMakePoint(p.x, p.y - y)];
    }
  return nil;
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  NSUInteger i;

  for (i = 0; i < [blocks count] && i < [offsets count]; i++)
    [[blocks objectAtIndex: i] addLinkRectsTo: rects at:
      NSMakePoint(origin.x, origin.y + [[offsets objectAtIndex: i] doubleValue])];
}

@end

/* <aside>: the page's main column at the left and the aside at the
   right, side by side when there's room, else one after the other. */
@interface HPColumns : HPBlock
{
  HPStack *main;
  HPStack *aside;
  BOOL beside;
  CGFloat asideX, asideY;
}
- (HPStack *) main;
- (HPStack *) aside;
@end

@implementation HPColumns

- (id) init
{
  if ((self = [super init]) != nil)
    {
      main = [HPStack new];
      aside = [HPStack new];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(main);
  RELEASE(aside);
  [super dealloc];
}

- (HPStack *) main { return main; }
- (HPStack *) aside { return aside; }

- (CGFloat) layoutForWidth: (CGFloat)width
{
  CGFloat gap = 28, asideWidth = floor(MAX(280, MIN(360, width * 0.36)));

  beside = width - asideWidth - gap >= 400 && [[main blocks] count] > 0;
  if (beside)
    {
      CGFloat h1 = [main layoutForWidth: width - asideWidth - gap];
      CGFloat h2 = [aside layoutForWidth: asideWidth];

      asideX = width - asideWidth;
      asideY = 0;
      size = NSMakeSize(width, MAX(h1, h2));
    }
  else
    {
      CGFloat h1 = [main layoutForWidth: width];
      CGFloat h2 = [aside layoutForWidth: MIN(width, 520)];

      asideX = 0;
      asideY = h1 > 0 ? h1 + 18 : 0;
      size = NSMakeSize(width, asideY + h2);
    }
  return size.height;
}

- (void) drawAt: (NSPoint)origin
{
  [main drawAt: origin];
  [aside drawAt: NSMakePoint(origin.x + asideX, origin.y + asideY)];
}

- (NSString *) linkAt: (NSPoint)p
{
  if (p.x >= asideX && p.y >= asideY)
    {
      NSString *l = [aside linkAt: NSMakePoint(p.x - asideX, p.y - asideY)];

      if (l != nil)
        return l;
    }
  return [main linkAt: p];
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  [main addLinkRectsTo: rects at: origin];
  [aside addLinkRectsTo: rects at:
    NSMakePoint(origin.x + asideX, origin.y + asideY)];
}

@end

/* <ul>, <ol>, and lists of links (no bullets). */
@interface HPListBlock : HPBlock
{
  NSMutableArray *items;
  NSMutableArray *offsets;
  BOOL ordered;
  BOOL bullets;
  CGFloat gap;
  NSFont *font;
}
- (id) initOrdered: (BOOL)o bullets: (BOOL)b font: (NSFont *)f;
- (void) addItem: (HPBlock *)b;
- (void) setGap: (CGFloat)g;
- (NSUInteger) count;
@end

@implementation HPListBlock

- (id) initOrdered: (BOOL)o bullets: (BOOL)b font: (NSFont *)f
{
  if ((self = [super init]) != nil)
    {
      items = [[NSMutableArray alloc] init];
      offsets = [[NSMutableArray alloc] init];
      ordered = o;
      bullets = b;
      gap = 6;
      ASSIGN(font, f);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(items);
  RELEASE(offsets);
  RELEASE(font);
  [super dealloc];
}

- (void) addItem: (HPBlock *)b { [items addObject: b]; }
- (void) setGap: (CGFloat)g { gap = g; }
- (NSUInteger) count { return [items count]; }

- (CGFloat) indent
{
  return bullets ? (ordered ? 24 : 18) : 0;
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSUInteger i;
  CGFloat y = 0;

  [offsets removeAllObjects];
  for (i = 0; i < [items count]; i++)
    {
      if (i > 0)
        y += gap;
      [offsets addObject: [NSNumber numberWithDouble: y]];
      y += [[items objectAtIndex: i] layoutForWidth: width - [self indent]];
    }
  size = NSMakeSize(width, y);
  return y;
}

- (void) drawAt: (NSPoint)origin
{
  NSUInteger i;
  NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName, [HPStyle dim], NSForegroundColorAttributeName,
    nil];

  for (i = 0; i < [items count] && i < [offsets count]; i++)
    {
      CGFloat y = origin.y + [[offsets objectAtIndex: i] doubleValue];

      if (bullets)
        {
          NSString *mark = ordered ? [NSString stringWithFormat: @"%lu.",
                                               (unsigned long)i + 1]
                                   : @"•";

          [mark drawAtPoint: NSMakePoint(origin.x + 2, y) withAttributes: a];
        }
      [[items objectAtIndex: i] drawAt:
        NSMakePoint(origin.x + [self indent], y)];
    }
}

- (NSString *) linkAt: (NSPoint)p
{
  NSUInteger i;

  for (i = 0; i < [items count] && i < [offsets count]; i++)
    {
      HPBlock *b = [items objectAtIndex: i];
      CGFloat y = [[offsets objectAtIndex: i] doubleValue];

      if (p.y >= y && p.y < y + [b size].height)
        return [b linkAt: NSMakePoint(p.x - [self indent], p.y - y)];
    }
  return nil;
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  NSUInteger i;

  for (i = 0; i < [items count] && i < [offsets count]; i++)
    [[items objectAtIndex: i] addLinkRectsTo: rects at:
      NSMakePoint(origin.x + [self indent],
                  origin.y + [[offsets objectAtIndex: i] doubleValue])];
}

@end

/* A numbered dot, as on figures and beside their notes. */
static void
HPDrawCallout(NSPoint centre, NSUInteger n)
{
  NSRect r = NSMakeRect(centre.x - 9, centre.y - 9, 18, 18);
  NSString *s = [NSString stringWithFormat: @"%lu", (unsigned long)n];
  NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:
    [HPStyle boldFontOfSize: 11], NSFontAttributeName,
    [HPStyle calloutText], NSForegroundColorAttributeName, nil];
  NSSize ts = [s sizeWithAttributes: a];

  [[HPStyle callout] set];
  [[NSBezierPath bezierPathWithOvalInRect: r] fill];
  [s drawAtPoint: NSMakePoint(floor(centre.x - ts.width / 2),
                              floor(centre.y - ts.height / 2))
  withAttributes: a];
}

static void
HPDrawImage(NSImage *image, NSRect r)
{
  NSBezierPath *clip = [HPStyle roundedRect: r radius: 8];

  [NSGraphicsContext saveGraphicsState];
  [clip addClip];
  [image drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver
           fraction: 1.0 respectFlipped: YES hints: nil];
  [NSGraphicsContext restoreGraphicsState];
  [[HPStyle line] set];
  [[HPStyle roundedRect: NSInsetRect(r, 0.5, 0.5) radius: 8] stroke];
}

/* <img>: a picture on its own. */
@interface HPImageBlock : HPBlock
{
  NSImage *image;
  CGFloat wanted;
}
- (id) initWithImage: (NSImage *)i width: (CGFloat)w;
@end

@implementation HPImageBlock

- (id) initWithImage: (NSImage *)i width: (CGFloat)w
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(image, i);
      wanted = w;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(image);
  [super dealloc];
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSSize s = [image size];
  CGFloat w = wanted > 0 ? wanted : s.width;

  if (s.width <= 0)
    return 0;
  w = MIN(w, width);
  size = NSMakeSize(w, floor(s.height * w / s.width));
  return size.height;
}

- (void) drawAt: (NSPoint)origin
{
  HPDrawImage(image, NSMakeRect(origin.x, origin.y, size.width, size.height));
}

@end

/* <legendfig>: a picture with numbered dots, and beside it (or below,
   when there's no room) a note for each number. */
@interface HPFigureBlock : HPBlock
{
  NSImage *image;
  CGFloat wanted;
  NSMutableArray *points;       /* NSValue, in the image's pixels */
  NSMutableArray *notes;        /* HPTextBlock */
  NSMutableArray *noteOffsets;
  NSSize imageSize;
  BOOL notesBeside;
}
- (id) initWithImage: (NSImage *)i width: (CGFloat)w;
- (void) addCalloutAt: (NSPoint)p note: (HPTextBlock *)note;
@end

@implementation HPFigureBlock

- (id) initWithImage: (NSImage *)i width: (CGFloat)w
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(image, i);
      wanted = w;
      points = [[NSMutableArray alloc] init];
      notes = [[NSMutableArray alloc] init];
      noteOffsets = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(image);
  RELEASE(points);
  RELEASE(notes);
  RELEASE(noteOffsets);
  [super dealloc];
}

- (void) addCalloutAt: (NSPoint)p note: (HPTextBlock *)note
{
  [points addObject: [NSValue valueWithPoint: p]];
  [notes addObject: note];
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSSize s = [image size];
  CGFloat w = wanted > 0 ? wanted : s.width, x, y, noteWidth;
  NSUInteger i;

  if (s.width <= 0)
    s = NSMakeSize(1, 1);
  w = MIN(w, width);
  imageSize = NSMakeSize(w, floor(s.height * w / s.width));
  notesBeside = [notes count] > 0 && width - w - 22 >= 200;
  if (notesBeside)
    {
      x = w + 22;
      y = 12;
      noteWidth = MIN(width - x, 340);
    }
  else
    {
      x = 0;
      y = imageSize.height + 16;
      noteWidth = MIN(width, 520);
    }
  [noteOffsets removeAllObjects];
  for (i = 0; i < [notes count]; i++)
    {
      HPTextBlock *n = [notes objectAtIndex: i];

      [noteOffsets addObject: [NSValue valueWithPoint:
                                 NSMakePoint(x + 28, y)]];
      y += MAX(18, [n layoutForWidth: noteWidth - 28]) + 14;
    }
  if ([notes count] > 0)
    y -= 14;
  size = NSMakeSize(width, notesBeside ? MAX(imageSize.height, y)
                                       : MAX(imageSize.height, y));
  return size.height;
}

- (void) drawAt: (NSPoint)origin
{
  NSRect r = NSMakeRect(origin.x, origin.y, imageSize.width, imageSize.height);
  CGFloat scale = [image size].width > 0
    ? imageSize.width / [image size].width : 1;
  NSUInteger i;

  HPDrawImage(image, r);
  for (i = 0; i < [points count]; i++)
    {
      NSPoint p = [[points objectAtIndex: i] pointValue];

      HPDrawCallout(NSMakePoint(origin.x + floor(p.x * scale),
                                origin.y + floor(p.y * scale)), i + 1);
    }
  for (i = 0; i < [notes count] && i < [noteOffsets count]; i++)
    {
      NSPoint o = [[noteOffsets objectAtIndex: i] pointValue];

      HPDrawCallout(NSMakePoint(origin.x + o.x - 19, origin.y + o.y + 10),
                    i + 1);
      [[notes objectAtIndex: i] drawAt:
        NSMakePoint(origin.x + o.x, origin.y + o.y)];
    }
}

- (NSString *) linkAt: (NSPoint)p
{
  NSUInteger i;

  for (i = 0; i < [notes count] && i < [noteOffsets count]; i++)
    {
      NSPoint o = [[noteOffsets objectAtIndex: i] pointValue];
      HPTextBlock *n = [notes objectAtIndex: i];

      if (p.y >= o.y && p.y < o.y + [n size].height && p.x >= o.x)
        return [n linkAt: NSMakePoint(p.x - o.x, p.y - o.y)];
    }
  return nil;
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  NSUInteger i;

  for (i = 0; i < [notes count] && i < [noteOffsets count]; i++)
    {
      NSPoint o = [[noteOffsets objectAtIndex: i] pointValue];

      [[notes objectAtIndex: i] addLinkRectsTo: rects at:
        NSMakePoint(origin.x + o.x, origin.y + o.y)];
    }
}

@end

/* <tip>, <note>, <caution>: tinted, with a rule down the left and the
   kind in bold before the text. */
@interface HPNoteBlock : HPBlock
{
  NSString *label;
  HPStack *body;
  CGFloat labelWidth;
}
- (id) initWithLabel: (NSString *)l body: (HPStack *)b;
@end

@implementation HPNoteBlock

- (id) initWithLabel: (NSString *)l body: (HPStack *)b
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(label, l);
      ASSIGN(body, b);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(label);
  RELEASE(body);
  [super dealloc];
}

- (NSDictionary *) labelAttributes
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    [HPStyle boldFontOfSize: 13], NSFontAttributeName,
    [HPStyle text], NSForegroundColorAttributeName, nil];
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  labelWidth = [label length] > 0
    ? ceil([label sizeWithAttributes: [self labelAttributes]].width) + 10 : 0;
  size = NSMakeSize(width,
                    [body layoutForWidth: width - 31 - labelWidth] + 24);
  return size.height;
}

- (void) drawAt: (NSPoint)origin
{
  NSRect r = NSMakeRect(origin.x, origin.y, size.width, size.height);

  [[HPStyle noteFill] set];
  [[HPStyle roundedRect: r radius: 8] fill];
  [NSGraphicsContext saveGraphicsState];
  [[HPStyle roundedRect: r radius: 8] addClip];
  [[HPStyle noteRule] set];
  NSRectFill(NSMakeRect(origin.x, origin.y, 3, size.height));
  [NSGraphicsContext restoreGraphicsState];
  [label drawAtPoint: NSMakePoint(origin.x + 17, origin.y + 12)
      withAttributes: [self labelAttributes]];
  [body drawAt: NSMakePoint(origin.x + 17 + labelWidth, origin.y + 12)];
}

- (NSString *) linkAt: (NSPoint)p
{
  return [body linkAt: NSMakePoint(p.x - 17 - labelWidth, p.y - 12)];
}

- (void) addLinkRectsTo: (NSMutableArray *)rects at: (NSPoint)origin
{
  [body addLinkRectsTo: rects at:
    NSMakePoint(origin.x + 17 + labelWidth, origin.y + 12)];
}

@end

/* <table>: rows of cells in a rounded box, ruled between rows; the
   first column as wide as its widest cell. */
@interface HPTableBlock : HPBlock
{
  NSMutableArray *rows;          /* arrays of HPTextBlock */
  NSMutableArray *widths;
  NSMutableArray *heights;
}
- (void) addRow: (NSArray *)cells;
- (NSUInteger) count;
@end

@implementation HPTableBlock

static const CGFloat HPCellX = 12, HPCellY = 8;

- (id) init
{
  if ((self = [super init]) != nil)
    {
      rows = [[NSMutableArray alloc] init];
      widths = [[NSMutableArray alloc] init];
      heights = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(rows);
  RELEASE(widths);
  RELEASE(heights);
  [super dealloc];
}

- (void) addRow: (NSArray *)cells
{
  if ([cells count] > 0)
    [rows addObject: cells];
}

- (NSUInteger) count
{
  return [rows count];
}

- (NSUInteger) columns
{
  NSUInteger n = 0, i;

  for (i = 0; i < [rows count]; i++)
    n = MAX(n, [[rows objectAtIndex: i] count]);
  return n;
}

- (CGFloat) layoutForWidth: (CGFloat)width
{
  NSUInteger cols = [self columns], r, c;
  CGFloat first = 0, rest, y = 0;

  [widths removeAllObjects];
  [heights removeAllObjects];
  if (cols == 0)
    return 0;
  for (r = 0; r < [rows count]; r++)
    {
      NSArray *row = [rows objectAtIndex: r];

      if ([row count] > 1)
        first = MAX(first, [[row objectAtIndex: 0] naturalWidth]);
    }
  first = cols > 1 ? MIN(first + 2 * HPCellX, floor(width * 0.5)) : width;
  rest = cols > 1 ? floor((width - first) / (cols - 1)) : 0;
  [widths addObject: [NSNumber numberWithDouble: first]];
  for (c = 1; c < cols; c++)
    [widths addObject: [NSNumber numberWithDouble: rest]];
  for (r = 0; r < [rows count]; r++)
    {
      NSArray *row = [rows objectAtIndex: r];
      CGFloat h = 0;

      for (c = 0; c < [row count]; c++)
        {
          CGFloat w = [[row count] == 1 ? [NSNumber numberWithDouble: width]
                                        : [widths objectAtIndex: c]
                        doubleValue];

          h = MAX(h, [[row objectAtIndex: c] layoutForWidth: w - 2 * HPCellX]);
        }
      h = MAX(h, 18) + 2 * HPCellY;
      [heights addObject: [NSNumber numberWithDouble: h]];
      y += h;
    }
  size = NSMakeSize(width, y);
  return y;
}

- (NSPoint) originOfRow: (NSUInteger)r column: (NSUInteger)c
{
  CGFloat x = 0, y = 0;
  NSUInteger i;

  for (i = 0; i < r; i++)
    y += [[heights objectAtIndex: i] doubleValue];
  for (i = 0; i < c; i++)
    x += [[widths objectAtIndex: i] doubleValue];
  return NSMakePoint(x + HPCellX, y + HPCellY);
}

- (void) drawAt: (NSPoint)origin
{
  NSRect box = NSMakeRect(origin.x, origin.y, size.width, size.height);
  NSUInteger r, c;
  CGFloat y = origin.y;

  if ([heights count] != [rows count])
    return;
  [[HPStyle line] set];
  for (r = 0; r < [rows count]; r++)
    {
      NSArray *row = [rows objectAtIndex: r];

      if (r > 0)
        NSRectFillUsingOperation(NSMakeRect(origin.x, y, size.width, 1),
                                 NSCompositeSourceOver);
      for (c = 0; c < [row count]; c++)
        {
          NSPoint o = [self originOfRow: r column: c];
          HPTextBlock *cell = [row objectAtIndex: c];
          CGFloat h = [[heights objectAtIndex: r] doubleValue];

          /* Centred in the row's height. */
          o.y += floor((h - 2 * HPCellY - [cell size].height) / 2);
          [cell drawAt: NSMakePoint(origin.x + o.x, origin.y + o.y)];
        }
      [[HPStyle line] set];
      y += [[heights objectAtIndex: r] doubleValue];
    }
  [[HPStyle line] set];
  [[HPStyle roundedRect: NSInsetRect(box, 0.5, 0.5) radius: 8] stroke];
}

- (NSString *) linkAt: (NSPoint)p
{
  NSUInteger r, c;

  for (r = 0; r < [rows count] && r < [heights count]; r++)
    {
      NSArray *row = [rows objectAtIndex: r];

      for (c = 0; c < [row count]; c++)
        {
          NSPoint o = [self originOfRow: r column: c];
          HPTextBlock *cell = [row objectAtIndex: c];
          NSString *l;

          if (p.x >= o.x && p.y >= o.y
              && (l = [cell linkAt: NSMakePoint(p.x - o.x, p.y - o.y)]) != nil)
            return l;
        }
    }
  return nil;
}

@end

/* A hairline across the page (<hr>). */
@interface HPRuleBlock : HPBlock
@end

@implementation HPRuleBlock

- (CGFloat) layoutForWidth: (CGFloat)width
{
  size = NSMakeSize(width, 1);
  return 1;
}

- (void) drawAt: (NSPoint)origin
{
  [[HPStyle line] set];
  NSRectFillUsingOperation(NSMakeRect(origin.x, origin.y, size.width, 1),
                           NSCompositeSourceOver);
}

@end

/* ---- building a page from a topic ----------------------------------------- */

static NSString *
HPTopicLink(HPTopic *t)
{
  return [NSString stringWithFormat: @"topic:%@/%@", [[t book] name],
                   [t identifier]];
}

@interface HPPageBuilder (Private)
- (id) initWithTopic: (HPTopic *)t;
- (HPStack *) build;
@end

@implementation HPPageBuilder
{
  HPTopic *topic;
  HPBook *book;
  NSMutableAttributedString *para;   /* inline content being collected */
  NSTextAlignment align;
}

static NSMutableParagraphStyle *
HPParagraphStyle(CGFloat spacing, NSTextAlignment a)
{
  NSMutableParagraphStyle *ps = AUTORELEASE([[NSParagraphStyle
                                    defaultParagraphStyle] mutableCopy]);

  [ps setLineSpacing: spacing];
  [ps setAlignment: a];
  return ps;
}

static NSDictionary *
HPAttrs(NSFont *font, NSColor *color, CGFloat spacing)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName, color, NSForegroundColorAttributeName,
    HPParagraphStyle(spacing, NSLeftTextAlignment),
    NSParagraphStyleAttributeName, nil];
}

static HPTextBlock *
HPText(NSString *s, NSDictionary *attrs, CGFloat before)
{
  NSAttributedString *as = AUTORELEASE([[NSAttributedString alloc]
                                         initWithString: s attributes: attrs]);
  HPTextBlock *b = AUTORELEASE([[HPTextBlock alloc] initWithString: as]);

  [b setSpaceBefore: before];
  return b;
}

static HPTextBlock *
HPHeading(NSString *s, CGFloat size, CGFloat before)
{
  return HPText(s, HPAttrs(size >= 20 ? [HPStyle boldFontOfSize: size]
                                      : [HPStyle semiboldFontOfSize: size],
                           [HPStyle text], 0), before);
}

/* A line of links ("Related", "In this section", search results). */
static HPTextBlock *
HPLinkLine(NSString *title, NSString *link, CGFloat size)
{
  NSMutableDictionary *a = [NSMutableDictionary dictionaryWithDictionary:
    HPAttrs([HPStyle semiboldFontOfSize: size], [HPStyle accent], 0)];

  [a setObject: link forKey: NSLinkAttributeName];
  return HPText(title, a, 0);
}

- (id) initWithTopic: (HPTopic *)t
{
  if ((self = [super init]) != nil)
    {
      topic = t;
      book = [t book];
      para = [[NSMutableAttributedString alloc] init];
      align = NSLeftTextAlignment;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(para);
  [super dealloc];
}

- (NSDictionary *) baseAttributes
{
  return HPAttrs([HPStyle fontOfSize: 14], [HPStyle text], 5.5);
}

/* Inline content into `s`, with the attributes in effect. */
- (void) appendInline: (HPNode *)n to: (NSMutableAttributedString *)s
           attributes: (NSDictionary *)attrs
{
  NSMutableDictionary *a;
  NSFont *font = [attrs objectForKey: NSFontAttributeName];
  CGFloat size = [font pointSize];
  NSEnumerator *e;
  HPNode *c;

  if ([n isText])
    {
      NSString *t = HPFoldSpace([n text]);
      NSString *have = [s string];

      if ([t hasPrefix: @" "]
          && ([have length] == 0 || [have hasSuffix: @" "]
              || [have hasSuffix: @"\n"]))
        t = [t substringFromIndex: 1];
      if ([t length] > 0)
        [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                                                 initWithString: t
                                                     attributes: attrs])];
      return;
    }
  if ([n is: @"br"])
    {
      [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                                    initWithString: @"\n" attributes: attrs])];
      return;
    }
  if ([n is: @"label"] || [n is: @"img"])
    return;
  a = [NSMutableDictionary dictionaryWithDictionary: attrs];
  if ([n is: @"b"] || [n is: @"strong"] || [n is: @"menu"] || [n is: @"ui"])
    [a setObject: [HPStyle semiboldFontOfSize: size] forKey: NSFontAttributeName];
  else if ([n is: @"i"] || [n is: @"em"])
    {
      NSFont *it = [[NSFontManager sharedFontManager]
                     convertFont: font toHaveTrait: NSItalicFontMask];

      [a setObject: it != nil ? it : font forKey: NSFontAttributeName];
      if (it == nil || it == font)
        [a setObject: [HPStyle dim] forKey: NSForegroundColorAttributeName];
    }
  else if ([n is: @"code"] || [n is: @"tt"])
    [a setObject: [HPStyle monoFontOfSize: size - 1]
          forKey: NSFontAttributeName];
  else if ([n is: @"sc"])
    [a setObject: [HPStyle fontOfSize: size - 2] forKey: NSFontAttributeName];
  else if ([n is: @"kbd"] || [n is: @"key"])
    {
      NSString *keys = [n plainText];
      NSMutableDictionary *k = [NSMutableDictionary dictionaryWithDictionary: a];

      [k setObject: [HPStyle fontOfSize: 12] forKey: NSFontAttributeName];
      [k setObject: [NSNumber numberWithBool: YES] forKey: HPKeyAttribute];
      /* The cap's own padding: no-break spaces inside it. */
      keys = [NSString stringWithFormat: @"  %@  ", keys];
      [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                                    initWithString: keys attributes: k])];
      return;
    }
  else if ([n is: @"ref"] || [n is: @"url"] || [n is: @"a"])
    {
      NSString *link = nil;

      if ([n is: @"url"])
        link = [n plainText];
      else if ([n attribute: @"href"] != nil)
        link = [n attribute: @"href"];
      else
        link = [NSString stringWithFormat: @"topic:%@/%@",
                         [n attribute: @"book"] != nil
                           ? [n attribute: @"book"] : [book name],
                         [n attribute: @"id"] != nil ? [n attribute: @"id"]
                                                     : [n plainText]];
      [a setObject: link forKey: NSLinkAttributeName];
      [a setObject: [HPStyle accent] forKey: NSForegroundColorAttributeName];
    }
  if ([n is: @"sc"])
    {
      NSString *t = [[n plainText] uppercaseString];

      [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                                    initWithString: t attributes: a])];
      return;
    }
  e = [[n children] objectEnumerator];
  while ((c = [e nextObject]) != nil)
    [self appendInline: c to: s attributes: a];
}

static BOOL
HPIsInline(HPNode *n)
{
  static NSSet *inl = nil;

  if (inl == nil)
    inl = [[NSSet alloc] initWithObjects: @"b", @"strong", @"i", @"em",
      @"code", @"tt", @"sc", @"kbd", @"key", @"ref", @"url", @"a", @"br",
      @"span", @"menu", @"ui", @"u", @"label", nil];
  return [n isText] || [inl containsObject: [n name]];
}

static NSAttributedString *
HPTrim(NSAttributedString *s)
{
  /* Not no-break spaces: they pad key caps. */
  NSCharacterSet *ws = [NSCharacterSet characterSetWithCharactersInString:
                                         @" \t\r\n"];
  NSString *str = [s string];
  NSUInteger start = 0, end = [str length];

  while (start < end && [ws characterIsMember: [str characterAtIndex: start]])
    start++;
  while (end > start && [ws characterIsMember: [str characterAtIndex: end - 1]])
    end--;
  return [s attributedSubstringFromRange: NSMakeRange(start, end - start)];
}

/* A paragraph from inline content. */
- (HPTextBlock *) textFrom: (NSAttributedString *)s maxWidth: (CGFloat)w
{
  NSMutableAttributedString *t = AUTORELEASE([HPTrim(s) mutableCopy]);
  HPTextBlock *b;

  if ([t length] == 0)
    return nil;
  if (align != NSLeftTextAlignment)
    [t addAttribute: NSParagraphStyleAttributeName
              value: HPParagraphStyle(5.5, align)
              range: NSMakeRange(0, [t length])];
  b = AUTORELEASE([[HPTextBlock alloc] initWithString: t]);
  [b setMaxWidth: w];
  return b;
}

- (void) flushInto: (HPStack *)stack
{
  HPTextBlock *b = [self textFrom: para maxWidth: HPMeasure];

  if (b != nil)
    {
      [b setSpaceBefore: 12];
      [stack addBlock: b];
    }
  [para setAttributedString: AUTORELEASE([NSAttributedString new])];
}

/* Inline children of n as one string, with these attributes. */
- (NSAttributedString *) inlineOf: (HPNode *)n attributes: (NSDictionary *)a
{
  NSMutableAttributedString *s = AUTORELEASE([NSMutableAttributedString new]);
  NSEnumerator *e = [[n children] objectEnumerator];
  HPNode *c;

  while ((c = [e nextObject]) != nil)
    [self appendInline: c to: s attributes: a];
  return s;
}

- (NSImage *) imageNamed: (NSString *)src
{
  NSString *p;

  if (src == nil)
    return nil;
  p = [book pathForResource: src light: [HPStyle light]];
  return AUTORELEASE([[NSImage alloc] initWithContentsOfFile: p]);
}

/* A block element. */
- (void) addBlock: (HPNode *)n to: (HPStack *)stack
{
  NSString *nm = [n name];

  if ([nm isEqual: @"p"] || [nm isEqual: @"div"] || [nm isEqual: @"left"])
    {
      [self flushInto: stack];
      [self addBlocksOf: [n children] to: stack];
      [self flushInto: stack];
    }
  else if ([nm isEqual: @"center"] || [nm isEqual: @"right"])
    {
      NSTextAlignment old = align;

      [self flushInto: stack];
      align = [nm isEqual: @"center"] ? NSCenterTextAlignment
                                      : NSRightTextAlignment;
      [self addBlocksOf: [n children] to: stack];
      [self flushInto: stack];
      align = old;
    }
  else if ([nm isEqual: @"h1"] || [nm isEqual: @"h2"] || [nm isEqual: @"h3"]
           || [nm isEqual: @"subtitle"])
    {
      CGFloat sz = [nm isEqual: @"h3"] ? 14 : 16;

      [self flushInto: stack];
      [stack addBlock: HPHeading([n plainText], sz,
                                 [[stack blocks] count] ? 20 : 0)];
    }
  else if ([nm isEqual: @"ul"] || [nm isEqual: @"ol"])
    {
      HPListBlock *l = AUTORELEASE([[HPListBlock alloc]
        initOrdered: [nm isEqual: @"ol"] bullets: YES
               font: [HPStyle fontOfSize: 14]]);
      NSEnumerator *e = [[n children] objectEnumerator];
      HPNode *li;

      [self flushInto: stack];
      while ((li = [e nextObject]) != nil)
        {
          HPStack *item;

          if (![li is: @"li"])
            continue;
          item = AUTORELEASE([HPStack new]);
          [self addBlocksOf: [li children] to: item];
          [self flushInto: item];
          [l addItem: item];
        }
      [l setSpaceBefore: 10];
      [stack addBlock: l];
    }
  else if ([nm isEqual: @"legendfig"] || [nm isEqual: @"figure"])
    {
      NSImage *img = [self imageNamed: [n attribute: @"src"]];
      HPFigureBlock *f;
      NSEnumerator *e = [[n children] objectEnumerator];
      HPNode *lg;

      [self flushInto: stack];
      if (img == nil)
        return;
      f = AUTORELEASE([[HPFigureBlock alloc]
            initWithImage: img width: [[n attribute: @"width"] doubleValue]]);
      while ((lg = [e nextObject]) != nil)
        {
          HPTextBlock *note;

          if (![lg is: @"legend"])
            continue;
          note = [self textFrom: [self inlineOf: lg attributes:
                                   HPAttrs([HPStyle fontOfSize: 13],
                                           [HPStyle text], 4)]
                       maxWidth: 0];
          if (note == nil)
            note = HPText(@"", [self baseAttributes], 0);
          [f addCalloutAt: NSMakePoint([[lg attribute: @"x"] doubleValue],
                                       [[lg attribute: @"y"] doubleValue])
                     note: note];
        }
      [f setSpaceBefore: 16];
      [stack addBlock: f];
    }
  else if ([nm isEqual: @"img"])
    {
      NSImage *img = [self imageNamed: [n attribute: @"src"]];
      HPImageBlock *b;

      [self flushInto: stack];
      if (img == nil)
        return;
      b = AUTORELEASE([[HPImageBlock alloc]
            initWithImage: img width: [[n attribute: @"width"] doubleValue]]);
      [b setSpaceBefore: 14];
      [stack addBlock: b];
    }
  else if ([nm isEqual: @"tip"] || [nm isEqual: @"note"]
           || [nm isEqual: @"caution"] || [nm isEqual: @"information"]
           || [nm isEqual: @"important"] || [nm isEqual: @"warning"])
    {
      NSString *label = [n attribute: @"label"];
      HPStack *body = AUTORELEASE([HPStack new]);
      HPNoteBlock *b;

      [self flushInto: stack];
      if (label == nil)
        label = [nm isEqual: @"tip"] ? @"Tip"
              : [nm isEqual: @"note"] ? @"Note"
              : [nm isEqual: @"information"] ? @"" : @"Important";
      [body addBlock: [self textFrom: [self inlineOf: n attributes:
                                         HPAttrs([HPStyle fontOfSize: 13],
                                                 [HPStyle text], 4)]
                            maxWidth: 0]];
      b = AUTORELEASE([[HPNoteBlock alloc] initWithLabel: label body: body]);
      [b setSpaceBefore: 16];
      [stack addBlock: b];
    }
  else if ([nm isEqual: @"table"] || [nm isEqual: @"keys"])
    {
      HPTableBlock *t = AUTORELEASE([HPTableBlock new]);
      NSEnumerator *e = [[n children] objectEnumerator];
      HPNode *tr;

      [self flushInto: stack];
      while ((tr = [e nextObject]) != nil)
        {
          NSMutableArray *cells = [NSMutableArray array];
          NSEnumerator *ce;
          HPNode *td;

          if (![tr is: @"tr"] && ![tr is: @"row"])
            continue;
          ce = [[tr children] objectEnumerator];
          while ((td = [ce nextObject]) != nil)
            {
              HPTextBlock *cell;

              if (![td is: @"td"] && ![td is: @"th"] && ![td is: @"cell"])
                continue;
              cell = [self textFrom: [self inlineOf: td attributes:
                         HPAttrs([td is: @"th"] ? [HPStyle semiboldFontOfSize: 13]
                                                : [HPStyle fontOfSize: 13],
                                 [HPStyle text], 3)]
                           maxWidth: 0];
              [cells addObject: cell != nil ? cell
                                 : HPText(@" ", [self baseAttributes], 0)];
            }
          [t addRow: cells];
        }
      [t setSpaceBefore: 10];
      if ([t count] > 0)
        [stack addBlock: t];
    }
  else if ([nm isEqual: @"related"])
    {
      HPListBlock *l = AUTORELEASE([[HPListBlock alloc]
        initOrdered: NO bullets: NO font: [HPStyle fontOfSize: 13]]);
      NSEnumerator *e = [[n children] objectEnumerator];
      HPNode *r;

      [self flushInto: stack];
      while ((r = [e nextObject]) != nil)
        if (![r isText])
          {
            NSMutableAttributedString *s = AUTORELEASE([NSMutableAttributedString new]);
            HPTextBlock *line;

            [self appendInline: r to: s attributes:
                    HPAttrs([HPStyle semiboldFontOfSize: 13], [HPStyle text], 0)];
            line = [self textFrom: s maxWidth: 0];
            if (line != nil)
              [l addItem: line];
          }
      if ([l count] > 0)
        {
          [stack addBlock: HPHeading([n attribute: @"title"] != nil
                                       ? [n attribute: @"title"] : @"Related",
                                     16, 22)];
          [l setSpaceBefore: 8];
          [stack addBlock: l];
        }
    }
  else if ([nm isEqual: @"listing"] || [nm isEqual: @"pre"])
    {
      NSString *t = [n plainText];
      HPStack *body = AUTORELEASE([HPStack new]);
      HPNoteBlock *b;

      [self flushInto: stack];
      if ([nm isEqual: @"pre"])
        {
          NSMutableString *raw = [NSMutableString string];
          NSEnumerator *e = [[n children] objectEnumerator];
          HPNode *c;

          while ((c = [e nextObject]) != nil)
            [raw appendString: [c isText] ? [c text] : [c plainText]];
          t = [raw stringByTrimmingCharactersInSet:
                     [NSCharacterSet newlineCharacterSet]];
        }
      [body addBlock: HPText(t, HPAttrs([HPStyle monoFontOfSize: 12],
                                        [HPStyle text], 2), 0)];
      b = AUTORELEASE([[HPNoteBlock alloc] initWithLabel: @"" body: body]);
      [b setSpaceBefore: 12];
      [stack addBlock: b];
    }
  else if ([nm isEqual: @"hr"])
    {
      HPRuleBlock *r = AUTORELEASE([HPRuleBlock new]);

      [self flushInto: stack];
      [r setSpaceBefore: 16];
      [stack addBlock: r];
    }
  else if ([nm isEqual: @"header"])
    ;
  else
    /* Anything else: what's in it. */
    [self addBlocksOf: [n children] to: stack];
}

- (void) addBlocksOf: (NSArray *)nodes to: (HPStack *)stack
{
  NSUInteger i;
  HPColumns *columns = nil;

  for (i = 0; i < [nodes count]; i++)
    {
      HPNode *n = [nodes objectAtIndex: i];

      if ([n is: @"aside"])
        {
          /* What comes after the aside goes in the main column beside
             it; the aside itself in the column at the right. */
          [self flushInto: stack];
          columns = AUTORELEASE([HPColumns new]);
          [columns setSpaceBefore: 16];
          [self addBlocksOf: [n children] to: [columns aside]];
          [self flushInto: [columns aside]];
          [stack addBlock: columns];
          stack = [columns main];
        }
      else if (HPIsInline(n))
        [self appendInline: n to: para attributes: [self baseAttributes]];
      else
        [self addBlock: n to: stack];
    }
  if (columns != nil)
    [self flushInto: stack];
}

- (HPStack *) build
{
  HPStack *page = AUTORELEASE([HPStack new]);
  NSMutableAttributedString *crumbs = AUTORELEASE([NSMutableAttributedString new]);
  NSDictionary *ca = HPAttrs([HPStyle fontOfSize: 12], [HPStyle dim], 0);
  NSMutableArray *path = [NSMutableArray array];
  HPTopic *t;
  NSUInteger i;
  HPTextBlock *b;

  /* NextBSD Help › The desktop */
  for (t = [topic parent]; t != nil; t = [t parent])
    [path insertObject: t atIndex: 0];
  [crumbs appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
            initWithString: [book title] attributes: ca])];
  for (i = 0; i < [path count]; i++)
    {
      NSMutableDictionary *la = [NSMutableDictionary dictionaryWithDictionary: ca];

      [la setObject: HPTopicLink([path objectAtIndex: i])
             forKey: NSLinkAttributeName];
      [crumbs appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                initWithString: @" › " attributes: ca])];
      [crumbs appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                initWithString: [[path objectAtIndex: i] title]
                    attributes: la])];
    }
  [page addBlock: AUTORELEASE([[HPTextBlock alloc] initWithString: crumbs])];
  [page addBlock: HPHeading([topic title], 26, 8)];

  [self addBlocksOf: [topic content] to: page];
  [self flushInto: page];

  /* A topic with topics in it lists them. */
  if ([[topic subtopics] count] > 0)
    {
      HPListBlock *l = AUTORELEASE([[HPListBlock alloc]
        initOrdered: NO bullets: NO font: [HPStyle fontOfSize: 14]]);
      NSEnumerator *e = [[topic subtopics] objectEnumerator];

      while ((t = [e nextObject]) != nil)
        [l addItem: HPLinkLine([t title], HPTopicLink(t), 14)];
      [l setGap: 8];
      [page addBlock: HPHeading(@"In this section", 16, 22)];
      [l setSpaceBefore: 10];
      [page addBlock: l];
    }
  /* The paragraph under the title sits close to it. */
  if ([[page blocks] count] > 2)
    {
      b = [[page blocks] objectAtIndex: 2];
      if ([b spaceBefore] == 12)
        [b setSpaceBefore: 6];
    }
  return page;
}

+ (HPBlock *) pageForTopic: (HPTopic *)topic
{
  HPPageBuilder *b = AUTORELEASE([[HPPageBuilder alloc] initWithTopic: topic]);

  return [b build];
}

+ (HPBlock *) pageForBook: (HPBook *)book
{
  HPStack *page = AUTORELEASE([HPStack new]);
  HPListBlock *l = AUTORELEASE([[HPListBlock alloc]
    initOrdered: NO bullets: NO font: [HPStyle fontOfSize: 14]]);
  NSEnumerator *e = [[book topics] objectEnumerator];
  HPTopic *t;

  [page addBlock: HPHeading([book title], 26, 0)];
  while ((t = [e nextObject]) != nil)
    [l addItem: HPLinkLine([t title], HPTopicLink(t), 14)];
  [l setGap: 8];
  [l setSpaceBefore: 14];
  [page addBlock: l];
  return page;
}

+ (HPBlock *) pageForResults: (NSArray *)topics query: (NSString *)query
{
  HPStack *page = AUTORELEASE([HPStack new]);
  NSEnumerator *e = [topics objectEnumerator];
  HPTopic *t;
  NSString *count;

  count = [topics count] == 0
    ? [NSString stringWithFormat: @"No topics found for “%@”.", query]
    : [NSString stringWithFormat: @"%lu topic%@ for “%@”",
                (unsigned long)[topics count],
                [topics count] == 1 ? @"" : @"s", query];
  [page addBlock: HPText(@"Search", HPAttrs([HPStyle fontOfSize: 12],
                                            [HPStyle dim], 0), 0)];
  [page addBlock: HPHeading(@"Search results", 26, 8)];
  [page addBlock: HPText(count, HPAttrs([HPStyle fontOfSize: 14],
                                        [HPStyle dim], 0), 6)];
  while ((t = [e nextObject]) != nil)
    {
      NSMutableAttributedString *s = AUTORELEASE([NSMutableAttributedString new]);
      NSMutableDictionary *ta = [NSMutableDictionary dictionaryWithDictionary:
        HPAttrs([HPStyle semiboldFontOfSize: 15], [HPStyle accent], 3)];
      NSString *where = [t parent] != nil
        ? [NSString stringWithFormat: @"%@ › %@", [[t book] title],
                    [[t parent] title]]
        : [[t book] title];
      HPTextBlock *b;

      [ta setObject: HPTopicLink(t) forKey: NSLinkAttributeName];
      [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
               initWithString: [t title] attributes: ta])];
      {
        NSString *line2 = [NSString stringWithFormat: @"\n%@", where];
        NSString *line3 = [NSString stringWithFormat: @"\n%@",
                                    HPSnippet(t, query)];
        NSDictionary *a2 = HPAttrs([HPStyle fontOfSize: 12], [HPStyle dim], 3);
        NSDictionary *a3 = HPAttrs([HPStyle fontOfSize: 13], [HPStyle text], 3);

        [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                 initWithString: line2 attributes: a2])];
        [s appendAttributedString: AUTORELEASE([[NSAttributedString alloc]
                 initWithString: line3 attributes: a3])];
      }
      b = AUTORELEASE([[HPTextBlock alloc] initWithString: s]);
      [b setMaxWidth: HPMeasure];
      [b setSpaceBefore: 20];
      [page addBlock: b];
    }
  return page;
}

@end

/* ---- the view ----------------------------------------------------------------- */

@implementation HPPageView

- (void) dealloc
{
  RELEASE(page);
  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) setDelegate: (id <HPPageDelegate>)d
{
  delegate = d;
}

- (CGFloat) visibleWidth
{
  NSScrollView *sv = [self enclosingScrollView];

  return sv != nil ? [sv contentSize].width : NSWidth([self frame]);
}

- (void) relayout
{
  CGFloat w = [self visibleWidth];
  CGFloat h = page != nil
    ? [page layoutForWidth: MAX(200, w - 2 * HPMarginX)] : 0;
  NSScrollView *sv = [self enclosingScrollView];

  laidOutWidth = w;
  h = MAX(h + HPMarginTop + HPMarginBottom,
          sv != nil ? [sv contentSize].height : 0);
  [self setFrameSize: NSMakeSize(w, h)];
  [[self window] invalidateCursorRectsForView: self];
  [self setNeedsDisplay: YES];
}

- (void) setPage: (HPBlock *)p
{
  ASSIGN(page, p);
  [self relayout];
  [self scrollPoint: NSZeroPoint];
}

- (void) resizeWithOldSuperviewSize: (NSSize)old
{
  [super resizeWithOldSuperviewSize: old];
  if (fabs([self visibleWidth] - laidOutWidth) >= 1)
    [self relayout];
}

- (void) drawRect: (NSRect)r
{
  [[HPStyle page] set];
  NSRectFill(r);
  [page drawAt: NSMakePoint(HPMarginX, HPMarginTop)];
}

- (NSString *) linkAtPoint: (NSPoint)p
{
  return [page linkAt: NSMakePoint(p.x - HPMarginX, p.y - HPMarginTop)];
}

- (void) mouseDown: (NSEvent *)event
{
  NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
  NSString *link = [self linkAtPoint: p];

  if (link != nil)
    [delegate followLink: link];
}

- (void) resetCursorRects
{
  NSMutableArray *rects = [NSMutableArray array];
  NSEnumerator *e;
  NSValue *v;

  [page addLinkRectsTo: rects at: NSMakePoint(HPMarginX, HPMarginTop)];
  e = [rects objectEnumerator];
  while ((v = [e nextObject]) != nil)
    [self addCursorRect: [v rectValue] cursor: [NSCursor pointingHandCursor]];
}

@end
