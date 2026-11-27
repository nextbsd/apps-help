/*
    HPStyle.m: Help's colours and fonts, in the NextBSD theme's Dark and
    Light appearances.

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

#import "HPStyle.h"
#import "GNUstep.h"
#import <GNUstepGUI/GSTheme.h>

NSString *const HPStyleChangedNotification = @"HPStyleChanged";

static BOOL light = NO;
static BOOL haveRead = NO;

static NSColor *
HPRGB(unsigned v, CGFloat a)
{
  return [NSColor colorWithCalibratedRed: ((v >> 16) & 255) / 255.0
                                   green: ((v >> 8) & 255) / 255.0
                                    blue: (v & 255) / 255.0
                                   alpha: a];
}

#define PICK(d, l) (([HPStyle light]) ? (l) : (d))

@implementation HPStyle

+ (void) reload
{
  NSArray *allowed = [NSArray arrayWithObjects: @"dark", @"light", nil];
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  id v;

  [defs synchronize];
  v = [[defs persistentDomainForName: NSGlobalDomain]
        objectForKey: @"NBAppearance"];
  if (![allowed containsObject: v])
    v = [defs objectForKey: @"NBAppearance"];
  if (![allowed containsObject: v])
    v = [[[GSTheme theme] infoDictionary] objectForKey: @"NBAppearance"];
  light = [v isEqual: @"light"];
  haveRead = YES;
}

+ (BOOL) light
{
  if (!haveRead)
    [self reload];
  return light;
}

+ (NSColor *) page { return PICK(HPRGB(0x1c1e23, 1), HPRGB(0xf7f7f9, 1)); }
+ (NSColor *) bar { return PICK(HPRGB(0x24272d, 1), HPRGB(0xe8e9ed, 1)); }
+ (NSColor *) sidebar { return PICK(HPRGB(0x202227, 1), HPRGB(0xeef0f3, 1)); }
+ (NSColor *) line { return PICK(HPRGB(0xffffff, .08), HPRGB(0x000000, .10)); }
+ (NSColor *) text { return PICK(HPRGB(0xe9ebef, 1), HPRGB(0x1d1f24, 1)); }
+ (NSColor *) dim { return PICK(HPRGB(0x9aa0ac, 1), HPRGB(0x5f6470, 1)); }
+ (NSColor *) faint { return PICK(HPRGB(0x6b7180, 1), HPRGB(0x8d929c, 1)); }
+ (NSColor *) accent { return PICK(HPRGB(0x00d4ff, 1), HPRGB(0x00a3c7, 1)); }
+ (NSColor *) accentText { return PICK(HPRGB(0x04141a, 1), HPRGB(0xffffff, 1)); }
+ (NSColor *) selection { return PICK(HPRGB(0x00d4ff, .16), HPRGB(0x00a3c7, .14)); }
+ (NSColor *) keyCap { return PICK(HPRGB(0x2a2d35, 1), HPRGB(0xe6e8ec, 1)); }
+ (NSColor *) noteFill { return PICK(HPRGB(0x00d4ff, .08), HPRGB(0x00a3c7, .07)); }
+ (NSColor *) noteRule { return PICK(HPRGB(0x00d4ff, .35), HPRGB(0x00a3c7, .4)); }
+ (NSColor *) callout { return PICK(HPRGB(0x00d4ff, 1), HPRGB(0x0091b3, 1)); }
+ (NSColor *) calloutText { return PICK(HPRGB(0x04141a, 1), HPRGB(0xffffff, 1)); }

static NSFont *
HPFont(NSString *name, CGFloat size, BOOL bold)
{
  NSFont *f = [NSFont fontWithName: name size: size];

  if (f == nil)
    f = bold ? [NSFont boldSystemFontOfSize: size]
             : [NSFont systemFontOfSize: size];
  return f;
}

+ (NSFont *) fontOfSize: (CGFloat)size
{
  return HPFont(@"Inter-Regular", size, NO);
}

+ (NSFont *) semiboldFontOfSize: (CGFloat)size
{
  return HPFont(@"Inter-SemiBold", size, YES);
}

+ (NSFont *) boldFontOfSize: (CGFloat)size
{
  return HPFont(@"Inter-Bold", size, YES);
}

+ (NSFont *) monoFontOfSize: (CGFloat)size
{
  NSFont *f = [NSFont fontWithName: @"JetBrainsMono-Regular" size: size];

  return f != nil ? f : [NSFont userFixedPitchFontOfSize: size];
}

+ (NSBezierPath *) roundedRect: (NSRect)r radius: (CGFloat)radius
{
  NSBezierPath *p = [NSBezierPath bezierPath];

  radius = MIN(radius, MIN(NSWidth(r), NSHeight(r)) / 2);
  [p appendBezierPathWithRoundedRect: r xRadius: radius yRadius: radius];
  return p;
}

@end
