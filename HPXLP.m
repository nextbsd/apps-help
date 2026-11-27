/*
    HPXLP.m: reading XLP help files into a tree of nodes.

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

#import "HPXLP.h"
#import "GNUstep.h"
#include <string.h>

NSString *
HPFoldSpace(NSString *s)
{
  NSMutableString *out = [NSMutableString stringWithCapacity: [s length]];
  NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSUInteger i, n = [s length];
  BOOL space = NO;

  for (i = 0; i < n; i++)
    {
      unichar c = [s characterAtIndex: i];

      if ([ws characterIsMember: c] && c != 0xa0)
        space = YES;
      else
        {
          if (space)
            [out appendString: @" "];
          space = NO;
          [out appendFormat: @"%C", c];
        }
    }
  if (space)
    [out appendString: @" "];
  return out;
}

@implementation HPNode

+ (HPNode *) elementNamed: (NSString *)aName
               attributes: (NSDictionary *)attrs
{
  HPNode *n = AUTORELEASE([HPNode new]);

  ASSIGN(n->name, [aName lowercaseString]);
  n->attributes = [[NSMutableDictionary alloc] init];
  if (attrs != nil)
    [n->attributes addEntriesFromDictionary: attrs];
  n->children = [[NSMutableArray alloc] init];
  return n;
}

+ (HPNode *) textNode: (NSString *)aText
{
  HPNode *n = AUTORELEASE([HPNode new]);

  ASSIGN(n->text, aText);
  return n;
}

- (void) dealloc
{
  RELEASE(name);
  RELEASE(attributes);
  RELEASE(children);
  RELEASE(text);
  [super dealloc];
}

- (NSString *) name { return name; }
- (BOOL) isText { return name == nil; }
- (BOOL) is: (NSString *)aName { return [name isEqualToString: aName]; }
- (NSString *) text { return text; }
- (NSDictionary *) attributes { return attributes; }
- (NSArray *) children { return children; }
- (HPNode *) parent { return parent; }

- (NSString *) attribute: (NSString *)key
{
  return [attributes objectForKey: key];
}

- (void) setAttribute: (NSString *)value forKey: (NSString *)key
{
  if (value != nil)
    [attributes setObject: value forKey: key];
  else
    [attributes removeObjectForKey: key];
}

- (void) addChild: (HPNode *)child
{
  child->parent = self;
  [children addObject: child];
}

- (void) insertChildren: (NSArray *)nodes atIndex: (NSUInteger)index
{
  NSUInteger i;

  for (i = 0; i < [nodes count]; i++)
    {
      HPNode *c = [nodes objectAtIndex: i];

      c->parent = self;
      [children insertObject: c atIndex: index + i];
    }
}

- (void) removeChildAtIndex: (NSUInteger)index
{
  [children removeObjectAtIndex: index];
}

- (HPNode *) find: (NSString *)aName
{
  NSEnumerator *e = [children objectEnumerator];
  HPNode *c, *found;

  while ((c = [e nextObject]) != nil)
    {
      if ([c is: aName])
        return c;
      if (![c isText] && (found = [c find: aName]) != nil)
        return found;
    }
  return nil;
}

- (void) appendPlainTextTo: (NSMutableString *)s
{
  NSEnumerator *e;
  HPNode *c;

  if (text != nil)
    {
      [s appendString: text];
      return;
    }
  if ([name isEqual: @"br"])
    [s appendString: @" "];
  e = [children objectEnumerator];
  while ((c = [e nextObject]) != nil)
    {
      static NSSet *inl = nil;

      if (inl == nil)
        inl = [[NSSet alloc] initWithObjects: @"b", @"strong", @"i", @"em",
          @"code", @"tt", @"sc", @"kbd", @"key", @"ref", @"url", @"a",
          @"span", @"menu", @"ui", @"u", nil];
      [c appendPlainTextTo: s];
      /* Blocks end in a space; text in <b> runs on. */
      if (![c isText] && ![inl containsObject: [c name]])
        [s appendString: @" "];
    }
}

- (NSString *) plainText
{
  NSMutableString *s = [NSMutableString string];

  [self appendPlainTextTo: s];
  return [HPFoldSpace(s) stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

/* HTML's entities that help text uses; anything else is kept as it is. */
static NSString *
HPEntity(NSString *ent)
{
  static NSDictionary *names = nil;
  unichar c = 0;
  NSString *v;

  if (names == nil)
    {
      names = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"<", @"lt", @">", @"gt", @"&", @"amp", @"\"", @"quot", @"'", @"apos",
        @" ", @"nbsp", @"©", @"copy", @"®", @"reg",
        @"•", @"bull", @"—", @"mdash", @"–", @"ndash",
        @"…", @"hellip", @"’", @"rsquo", @"‘", @"lsquo",
        @"“", @"ldquo", @"”", @"rdquo", @"→", @"rarr",
        @"←", @"larr", @"↑", @"uarr", @"↓", @"darr",
        @"×", @"times", @"·", @"middot", @"›", @"rsaquo",
        @"⌘", @"cmd", @"⇧", @"shift", @"⌥", @"opt",
        @"⌃", @"ctrl", @"⌫", @"bksp", @"⏎", @"ret", nil];
    }
  if ([ent hasPrefix: @"#x"] || [ent hasPrefix: @"#X"])
    {
      unsigned u = 0;

      [[NSScanner scannerWithString: [ent substringFromIndex: 2]]
        scanHexInt: &u];
      c = (unichar)u;
    }
  else if ([ent hasPrefix: @"#"])
    c = (unichar)[[ent substringFromIndex: 1] intValue];
  if (c != 0)
    return [NSString stringWithCharacters: &c length: 1];
  v = [names objectForKey: ent];
  if (v == nil)
    {
      /* Latin-1's, from &nbsp; (160) to &yuml; (255). */
      static const char *latin1[] = {
        "nbsp", "iexcl", "cent", "pound", "curren", "yen", "brvbar", "sect",
        "uml", "copy", "ordf", "laquo", "not", "shy", "reg", "macr", "deg",
        "plusmn", "sup2", "sup3", "acute", "micro", "para", "middot",
        "cedil", "sup1", "ordm", "raquo", "frac14", "frac12", "frac34",
        "iquest", "Agrave", "Aacute", "Acirc", "Atilde", "Auml", "Aring",
        "AElig", "Ccedil", "Egrave", "Eacute", "Ecirc", "Euml", "Igrave",
        "Iacute", "Icirc", "Iuml", "ETH", "Ntilde", "Ograve", "Oacute",
        "Ocirc", "Otilde", "Ouml", "times", "Oslash", "Ugrave", "Uacute",
        "Ucirc", "Uuml", "Yacute", "THORN", "szlig", "agrave", "aacute",
        "acirc", "atilde", "auml", "aring", "aelig", "ccedil", "egrave",
        "eacute", "ecirc", "euml", "igrave", "iacute", "icirc", "iuml",
        "eth", "ntilde", "ograve", "oacute", "ocirc", "otilde", "ouml",
        "divide", "oslash", "ugrave", "uacute", "ucirc", "uuml", "yacute",
        "thorn", "yuml" };
      const char *e = [ent UTF8String];
      unsigned i;

      for (i = 0; i < sizeof(latin1) / sizeof(latin1[0]); i++)
        if (strcmp(latin1[i], e) == 0)
          {
            c = (unichar)(160 + i);
            return [NSString stringWithCharacters: &c length: 1];
          }
    }
  return v != nil ? v : [NSString stringWithFormat: @"&%@;", ent];
}

static NSString *
HPDecode(NSString *s)
{
  NSMutableString *out;
  NSRange r, semi;
  NSUInteger pos = 0, n = [s length];

  if ([s rangeOfString: @"&"].location == NSNotFound)
    return s;
  out = [NSMutableString stringWithCapacity: n];
  while (pos < n)
    {
      r = [s rangeOfString: @"&" options: 0
                     range: NSMakeRange(pos, n - pos)];
      if (r.location == NSNotFound)
        {
          [out appendString: [s substringFromIndex: pos]];
          break;
        }
      [out appendString: [s substringWithRange:
                              NSMakeRange(pos, r.location - pos)]];
      semi = [s rangeOfString: @";" options: 0
                        range: NSMakeRange(r.location,
                                           MIN(n - r.location, 12))];
      if (semi.location == NSNotFound)
        {
          [out appendString: @"&"];
          pos = r.location + 1;
          continue;
        }
      [out appendString: HPEntity([s substringWithRange:
        NSMakeRange(r.location + 1, semi.location - r.location - 1)])];
      pos = semi.location + 1;
    }
  return out;
}

@implementation HPParser

static BOOL
HPIsVoid(NSString *n)
{
  return [n isEqual: @"br"] || [n isEqual: @"img"] || [n isEqual: @"hr"]
    || [n isEqual: @"label"] || [n isEqual: @"meta"];
}

/* The attributes in a start tag's text after its name. */
static NSDictionary *
HPAttributes(NSString *s)
{
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  NSScanner *sc = [NSScanner scannerWithString: s];
  NSCharacterSet *nameEnd = [NSCharacterSet characterSetWithCharactersInString:
                                              @"= \t\r\n/"];

  [sc setCharactersToBeSkipped:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  while (![sc isAtEnd])
    {
      NSString *key = nil, *value = @"";

      if (![sc scanUpToCharactersFromSet: nameEnd intoString: &key])
        {
          [sc setScanLocation: [sc scanLocation] + 1];
          continue;
        }
      if ([sc scanString: @"=" intoString: NULL])
        {
          NSString *q = nil;

          if ([sc scanString: @"\"" intoString: &q]
              || [sc scanString: @"'" intoString: &q])
            {
              if (![sc scanUpToString: q intoString: &value])
                value = @"";
              [sc scanString: q intoString: NULL];
            }
          else
            [sc scanUpToCharactersFromSet:
                  [NSCharacterSet whitespaceAndNewlineCharacterSet]
                               intoString: &value];
        }
      [d setObject: HPDecode(value) forKey: [key lowercaseString]];
    }
  return d;
}

+ (HPNode *) parseString: (NSString *)src
{
  HPNode *root = [HPNode elementNamed: @"#root" attributes: nil];
  NSMutableArray *stack = [NSMutableArray arrayWithObject: root];
  NSUInteger pos = 0, n = [src length];

  while (pos < n)
    {
      NSRange lt = [src rangeOfString: @"<" options: 0
                                range: NSMakeRange(pos, n - pos)];
      NSUInteger end;
      NSString *tag;
      HPNode *top = [stack lastObject];

      if (lt.location == NSNotFound)
        lt.location = n;
      if (lt.location > pos)
        [top addChild: [HPNode textNode: HPDecode([src substringWithRange:
                         NSMakeRange(pos, lt.location - pos)])]];
      if (lt.location >= n)
        break;
      if ([src length] >= lt.location + 4
          && [[src substringWithRange: NSMakeRange(lt.location, 4)]
               isEqual: @"<!--"])
        {
          NSRange e = [src rangeOfString: @"-->" options: 0
                       range: NSMakeRange(lt.location, n - lt.location)];

          pos = e.location == NSNotFound ? n : NSMaxRange(e);
          continue;
        }
      /* The tag ends at the first '>' outside quotes. */
      {
        unichar q = 0;

        for (end = lt.location + 1; end < n; end++)
          {
            unichar c = [src characterAtIndex: end];

            if (q != 0)
              {
                if (c == q)
                  q = 0;
              }
            else if (c == '"' || c == '\'')
              q = c;
            else if (c == '>')
              break;
          }
      }
      tag = [src substringWithRange: NSMakeRange(lt.location + 1,
                                                 MIN(end, n) - lt.location - 1)];
      pos = MIN(end + 1, n);
      if ([tag hasPrefix: @"?"] || [tag hasPrefix: @"!"])
        continue;
      if ([tag hasPrefix: @"/"])
        {
          NSString *nm = [[[tag substringFromIndex: 1]
                            stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                           lowercaseString];
          NSInteger i;

          /* Close it and anything left open inside it; an end tag
             with nothing open to match is ignored. */
          for (i = [stack count] - 1; i > 0; i--)
            if ([[stack objectAtIndex: i] is: nm])
              {
                [stack removeObjectsInRange:
                         NSMakeRange(i, [stack count] - i)];
                break;
              }
          continue;
        }
      {
        BOOL selfClosing = [tag hasSuffix: @"/"];
        NSRange sp;
        NSString *nm, *rest;
        HPNode *el;

        if (selfClosing)
          tag = [tag substringToIndex: [tag length] - 1];
        sp = [tag rangeOfCharacterFromSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        nm = sp.location == NSNotFound ? tag
                                       : [tag substringToIndex: sp.location];
        rest = sp.location == NSNotFound ? @""
                                         : [tag substringFromIndex: sp.location];
        el = [HPNode elementNamed: nm attributes: HPAttributes(rest)];
        nm = [el name];
        /* A new paragraph or list item ends the one before. */
        if (([nm isEqual: @"p"] || [nm isEqual: @"li"])
            && [[stack lastObject] is: nm])
          [stack removeLastObject];
        [[stack lastObject] addChild: el];
        if (!selfClosing && !HPIsVoid(nm))
          [stack addObject: el];
      }
    }
  return root;
}

+ (HPNode *) parseData: (NSData *)data
{
  NSString *s = nil;
  NSString *head;
  NSStringEncoding enc = NSUTF8StringEncoding;

  if (data == nil)
    return nil;
  /* The encoding the <?xml?> declaration names, else UTF-8, else
     Latin-1 (which reads anything). */
  head = AUTORELEASE([[NSString alloc]
           initWithData: [data subdataWithRange:
                            NSMakeRange(0, MIN([data length], 200))]
               encoding: NSISOLatin1StringEncoding]);
  head = [head lowercaseString];
  if ([head rangeOfString: @"iso-8859-15"].location != NSNotFound)
    enc = NSISOLatin9StringEncoding;
  else if ([head rangeOfString: @"iso-8859-1"].location != NSNotFound)
    enc = NSISOLatin1StringEncoding;
  s = AUTORELEASE([[NSString alloc] initWithData: data encoding: enc]);
  if (s == nil)
    s = AUTORELEASE([[NSString alloc] initWithData: data
                                          encoding: NSISOLatin1StringEncoding]);
  return [self parseString: s];
}

+ (HPNode *) parseFile: (NSString *)path
{
  return [self parseData: [NSData dataWithContentsOfFile: path]];
}

@end
