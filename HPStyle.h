/*
    HPStyle.h: Help's colours and fonts, in the NextBSD theme's Dark and
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

#ifndef __HP_STYLE_H__
#define __HP_STYLE_H__

#import <AppKit/AppKit.h>

/* Posted (in this process) when the appearance changes. */
extern NSString *const HPStyleChangedNotification;

@interface HPStyle : NSObject
/* Light, from NBAppearance: the person's choice in NSGlobalDomain, else
   the theme's default, else dark, as every NextBSD app reads it. */
+ (BOOL) light;
+ (void) reload;

+ (NSColor *) page;          /* the page */
+ (NSColor *) bar;           /* the toolbar */
+ (NSColor *) sidebar;
+ (NSColor *) line;          /* hairlines and borders */
+ (NSColor *) text;
+ (NSColor *) dim;           /* breadcrumb, secondary text */
+ (NSColor *) faint;         /* sidebar headings, placeholders */
+ (NSColor *) accent;
+ (NSColor *) accentText;    /* text on the accent */
+ (NSColor *) selection;     /* the chosen book */
+ (NSColor *) keyCap;        /* key caps' face */
+ (NSColor *) noteFill;      /* a tip's tint */
+ (NSColor *) noteRule;      /* and the rule at its left */
+ (NSColor *) callout;       /* the numbered dots on figures */
+ (NSColor *) calloutText;

+ (NSFont *) fontOfSize: (CGFloat)size;
+ (NSFont *) semiboldFontOfSize: (CGFloat)size;
+ (NSFont *) boldFontOfSize: (CGFloat)size;
+ (NSFont *) monoFontOfSize: (CGFloat)size;

/* A rounded rectangle. */
+ (NSBezierPath *) roundedRect: (NSRect)r radius: (CGFloat)radius;
@end

#endif
