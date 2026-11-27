/*
    HPXLP.h: reading XLP help files into a tree of nodes.

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

#ifndef __HP_XLP_H__
#define __HP_XLP_H__

#import <Foundation/Foundation.h>

/* An element (name and attributes, with children) or a run of text
   (name nil). Element names are lower case. */
@interface HPNode : NSObject
{
  NSString *name;
  NSMutableDictionary *attributes;
  NSMutableArray *children;
  NSString *text;
  HPNode *parent;               /* not retained */
}

+ (HPNode *) elementNamed: (NSString *)aName
               attributes: (NSDictionary *)attrs;
+ (HPNode *) textNode: (NSString *)aText;

- (NSString *) name;
- (BOOL) isText;
- (BOOL) is: (NSString *)aName;
- (NSString *) text;
- (NSString *) attribute: (NSString *)key;
- (NSDictionary *) attributes;
- (void) setAttribute: (NSString *)value forKey: (NSString *)key;
- (NSArray *) children;
- (HPNode *) parent;
- (void) addChild: (HPNode *)child;
- (void) insertChildren: (NSArray *)nodes atIndex: (NSUInteger)index;
- (void) removeChildAtIndex: (NSUInteger)index;
/* The first child element with this name, at any depth. */
- (HPNode *) find: (NSString *)aName;
/* The text of this node and everything in it, white space folded. */
- (NSString *) plainText;
@end

/* XLP is HTML-like: <br> and <img> needn't be closed, end tags may be
   missing or out of order, and entities are HTML's. This reads it all
   forgivingly into a tree under an element named "#root". */
@interface HPParser : NSObject
+ (HPNode *) parseData: (NSData *)data;
+ (HPNode *) parseFile: (NSString *)path;
@end

/* White space runs folded to one space. */
NSString *HPFoldSpace(NSString *s);

#endif
