/*
    HPBook.m: a help book (a .help bundle) and its topics.

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

#import "HPBook.h"
#import "GNUstep.h"

static BOOL
HPIsTopicNode(HPNode *n)
{
  return [n is: @"part"] || [n is: @"chapter"] || [n is: @"section"]
    || [n is: @"plain"] || [n is: @"topic"];
}

@implementation HPTopic

- (id) initWithNode: (HPNode *)aNode book: (HPBook *)aBook
             parent: (HPTopic *)aParent
{
  if ((self = [super init]) != nil)
    {
      NSString *t = [aNode attribute: @"name"];

      if (t == nil)
        t = [aNode attribute: @"title"];
      ASSIGN(node, aNode);
      ASSIGN(title, t != nil ? HPFoldSpace(t) : @"Untitled");
      ASSIGN(identifier, [aNode attribute: @"id"] != nil
                           ? [aNode attribute: @"id"] : title);
      ASSIGN(keywords, [aNode attribute: @"keywords"]);
      subtopics = [[NSMutableArray alloc] init];
      book = aBook;
      parent = aParent;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(title);
  RELEASE(identifier);
  RELEASE(keywords);
  RELEASE(node);
  RELEASE(subtopics);
  RELEASE(searchText);
  [super dealloc];
}

- (NSString *) title { return title; }
- (NSString *) identifier { return identifier; }
- (NSString *) keywords { return keywords; }
- (HPNode *) node { return node; }
- (NSArray *) subtopics { return subtopics; }
- (HPTopic *) parent { return parent; }
- (HPBook *) book { return book; }
- (void) addSubtopic: (HPTopic *)t { [subtopics addObject: t]; }

- (NSUInteger) depth
{
  return parent == nil ? 0 : [parent depth] + 1;
}

- (BOOL) isAncestorOf: (HPTopic *)t
{
  for (t = [t parent]; t != nil; t = [t parent])
    if (t == self)
      return YES;
  return NO;
}

- (NSArray *) content
{
  NSMutableArray *a = [NSMutableArray array];
  NSEnumerator *e = [[node children] objectEnumerator];
  HPNode *c;

  while ((c = [e nextObject]) != nil)
    if (!HPIsTopicNode(c))
      [a addObject: c];
  return a;
}

- (NSString *) lowercaseTitle
{
  return [title lowercaseString];
}

- (NSString *) searchText
{
  if (searchText == nil)
    {
      NSMutableString *s = [NSMutableString stringWithString: title];
      NSEnumerator *e = [[self content] objectEnumerator];
      HPNode *c;

      if (keywords != nil)
        [s appendFormat: @" %@", keywords];
      while ((c = [e nextObject]) != nil)
        [s appendFormat: @" %@", [c plainText]];
      ASSIGN(searchText, [HPFoldSpace(s) lowercaseString]);
    }
  return searchText;
}

@end

@implementation HPBook

- (id) initWithPath: (NSString *)aPath app: (NSString *)anApp
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(path, aPath);
      ASSIGN(appPath, anApp);
      ASSIGN(name, [[aPath lastPathComponent] stringByDeletingPathExtension]);
      topics = [[NSMutableArray alloc] init];
      allTopics = [[NSMutableArray alloc] init];
      byIdentifier = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(path);
  RELEASE(name);
  RELEASE(title);
  RELEASE(appPath);
  RELEASE(icon);
  RELEASE(topics);
  RELEASE(allTopics);
  RELEASE(byIdentifier);
  [super dealloc];
}

/* <chapter src="file.xlp"> takes the file's content in its place, and
   so on inside it. */
- (void) include: (HPNode *)n depth: (int)depth
{
  NSUInteger i;

  if (depth > 8)
    return;
  for (i = 0; i < [[n children] count]; i++)
    {
      HPNode *c = [[n children] objectAtIndex: i];
      NSString *src;

      if ([c isText])
        continue;
      src = [c attribute: @"src"];
      /* Its own text comes first, before any topics inside it. */
      if (HPIsTopicNode(c) && src != nil)
        {
          HPNode *file = [HPParser parseFile:
                            [path stringByAppendingPathComponent: src]];
          HPNode *body = [file find: @"document"];

          if (body == nil)
            body = file;
          [c insertChildren: [body children] atIndex: 0];
          [c setAttribute: nil forKey: @"src"];
        }
      [self include: c depth: depth + 1];
    }
}

- (void) collectTopicsIn: (HPNode *)n parent: (HPTopic *)p
{
  NSEnumerator *e = [[n children] objectEnumerator];
  HPNode *c;

  while ((c = [e nextObject]) != nil)
    {
      if (HPIsTopicNode(c))
        {
          HPTopic *t = [[HPTopic alloc] initWithNode: c book: self parent: p];

          if (p != nil)
            [p addSubtopic: t];
          else
            [topics addObject: t];
          [allTopics addObject: t];
          if ([byIdentifier objectForKey: [t identifier]] == nil)
            [byIdentifier setObject: t forKey: [t identifier]];
          if ([byIdentifier objectForKey: [t title]] == nil)
            [byIdentifier setObject: t forKey: [t title]];
          [self collectTopicsIn: c parent: t];
          RELEASE(t);
        }
      else if (![c isText] && ([c is: @"document"] || [c is: @"group"]))
        [self collectTopicsIn: c parent: p];
    }
}

- (void) load
{
  NSString *main;
  HPNode *root, *doc, *header;

  if (loaded)
    return;
  loaded = YES;
  main = [path stringByAppendingPathComponent: @"main.xlp"];
  root = [HPParser parseFile: main];
  if (root == nil)
    {
      NSLog(@"Help: %@ has no main.xlp", path);
      return;
    }
  doc = [root find: @"document"];
  if (doc == nil)
    doc = root;
  header = [doc find: @"header"];
  if ([header find: @"title"] != nil)
    ASSIGN(title, [[header find: @"title"] plainText]);
  if ([[header find: @"icon"] attribute: @"src"] != nil)
    {
      NSString *p = [path stringByAppendingPathComponent:
                       [[header find: @"icon"] attribute: @"src"]];

      ASSIGN(icon, AUTORELEASE([[NSImage alloc] initWithContentsOfFile: p]));
    }
  [self include: doc depth: 0];
  [self collectTopicsIn: doc parent: nil];
}

- (NSString *) path { return path; }
- (NSString *) name { return name; }
- (NSString *) appPath { return appPath; }

- (NSString *) title
{
  [self load];
  return title != nil ? title
                      : [NSString stringWithFormat: @"%@ Help", name];
}

- (NSImage *) icon
{
  [self load];
  if (icon == nil && appPath != nil)
    ASSIGN(icon, [[NSWorkspace sharedWorkspace] iconForFile: appPath]);
  return icon;
}

- (NSArray *) topics
{
  [self load];
  return topics;
}

- (NSArray *) allTopics
{
  [self load];
  return allTopics;
}

- (HPTopic *) topicWithIdentifier: (NSString *)ident
{
  [self load];
  return ident != nil ? [byIdentifier objectForKey: ident] : nil;
}

- (NSString *) pathForResource: (NSString *)file light: (BOOL)light
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *ext = [file pathExtension];
  NSString *base = [file stringByDeletingPathExtension];
  NSString *variant = [NSString stringWithFormat: @"%@-%@.%@", base,
                                light ? @"light" : @"dark", ext];
  NSString *p = [path stringByAppendingPathComponent: variant];

  if ([fm fileExistsAtPath: p])
    return p;
  return [path stringByAppendingPathComponent: file];
}

@end
