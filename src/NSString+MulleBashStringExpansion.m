#import "import-private.h"

#import "NSString+MulleBashStringExpansion.h"


#define token_operator  0x7E000000

enum token_type
{
   token_eof       = 0,
   token_error     = -1,
   // token_character = 1,  // everything else (unused)

   token_strlen = token_operator,                         // ${#parameter}
   token_expand,                                          // ${parameter}
   token_expand_with_default_value,                       // ${parameter:-value}
   token_expand_with_default_key,                         // ${parameter:=key}
                                                          // ${parameter:?key} makes no sense
   token_expand_with_value,                               // ${parameter:+value}
   token_expand_substring_offset = token_operator + ';',  // ${parameter:offset}
   token_expand_substring_offset_length,                  // ${parameter:offset:length}
   token_expand_remove_prefix = token_operator + '#',     // ${parameter#regex}
   token_expand_remove_prefix_all,                        // ${parameter##regex}
   token_expand_remove_suffix = token_operator + '%',     // ${parameter%regex}
   token_expand_remove_suffix_all,                        // ${parameter%%regex}
   token_expand_replace = token_operator + '/',           // ${parameter/regex/string}
   token_expand_replace_all,                              // ${parameter//regex/string}
   token_expand_replace_prefix,                           // ${parameter//regex/string}
   token_expand_replace_suffix,                           // ${parameter//regex/string}
                                                          // ${parameter/#regex/string} NYI
                                                          // ${parameter/%regex/string} NYI
   token_expand_upper_case = token_operator + '^',        // ${parameter^regex}
   token_expand_upper_case_all,                           // ${parameter^^regex}
   token_expand_lower_case =  token_operator + ',',       // ${parameter,regex}
   token_expand_lower_case_all,                           // ${parameter,,regex}
                                                          // ${parameter@operator}  NYI
   token_integer    = 0x7FFFFFFE,
   token_identifier = 0x7FFFFFFF,
};



// MEMO: we don't want to malloc anything for _parsing_ ${foo//x/y}.
//       "e will malloc once we get a sub $ expression or a '\\'
//       e.g.  ${fo\o:-x} or ${foo:-${bar}}
//       Problem: we don't want to extend bar in ${foo:-${bar}} if foo is set
//
struct parser
{
   struct MulleStringEnumerator   rover;
   NSMutableString                *output;     // filled on demand
   NSString                       *input;
   NSRange                        memo;
   unichar                        d;
   unichar                        c;
   id                             info;
};


struct parser_token
{
   enum token_type   type;
   id                value;  // usually a NSString but can also be a NSNumber
};


static struct parser_token   parser_token_make( enum token_type type, id value)
{
   return( (struct parser_token){ .type = type, .value = value});
}


static inline void  _parser_init_with_string( struct parser *parser,
                                              NSString *s,
                                              id info)
{
   memset( parser, 0, sizeof( struct parser));

   _MulleStringEnumeratorInit( &parser->rover, s);
   parser->output = nil;
   parser->input  = s;
   parser->info   = info;
}


static inline void  _parser_done( struct parser *parser)
{
   MulleStringEnumeratorDone( &parser->rover);
#ifdef DEBUG
   memset( parser, 0xFA, sizeof( struct parser));
#endif
}


//
// This gets the next character, '\\' will NOT be consumed
// 'd' will be set though
//
static inline BOOL   _parser_next_character( struct parser *parser)
{
   parser->d = parser->c;
   if( ! MulleStringEnumeratorNext( &parser->rover, &parser->c))
   {
      parser->c = -1;
      return( NO);
   }
   return( YES);
}


static inline BOOL   _parse_undo_next_character( struct parser *parser)
{
   return( _MulleStringEnumeratorUndoNext( &parser->rover, &parser->c, &parser->d));
}


static inline BOOL   _parser_next_character_with_escaping( struct parser *parser)
{
   BOOL   flag;

   flag = _parser_next_character( parser);
   if( flag)
   {
      if( parser->c == '\\')
         return( MulleStringEnumeratorNext( &parser->rover, &parser->c));
   }
   return( flag);
}


static NSString   *_parser_get_value_string( struct parser *parser, NSString *key)
{
   id   value;

   value = [parser->info valueForKeyPath:key];
   value = [value description];
   return( value ? value : @"");
}


static void   _parser_memo( struct parser *parser)
{
   parser->memo.location = MulleStringEnumeratorGetIndex( &parser->rover);
}


static void   _parser_memo_1( struct parser *parser)
{
   parser->memo.location = MulleStringEnumeratorGetIndex( &parser->rover) - 1;
   assert( parser->memo.location != (NSUInteger) -1);
}


static NSRange   _parser_recall( struct parser *parser)
{
   parser->memo.length = MulleStringEnumeratorGetIndex( &parser->rover) - parser->memo.location;
   return( parser->memo);
}


static NSRange   _parser_recall_1( struct parser *parser)
{
   parser->memo.length = MulleStringEnumeratorGetIndex( &parser->rover) - parser->memo.location - 1;
   return( parser->memo);
}


static NSString   *_parser_substring( struct parser *parser, NSRange range)
{
   return( [parser->input substringWithRange:range]);
}


static NSString   *_parser_recall_string( struct parser *parser)
{
   return( _parser_substring( parser, _parser_recall( parser)));
}


static NSString   *_parser_recall_string_1( struct parser *parser)
{
   return( _parser_substring( parser, _parser_recall_1( parser)));
}


// YES: delimiter found
static BOOL   _parser_grab_to_delimiter( struct parser *parser, unichar delimiter)
{
   NSString   *s;
   BOOL       flag;
   NSRange    range;

   flag = NO;
   _parser_memo( parser);
   for(;;)
   {
      parser->d = parser->c;
      if( ! MulleStringEnumeratorNext( &parser->rover, &parser->c))
         break;

      if( ! parser->output)
         parser->output = [NSMutableString string];

      flag = (parser->c == delimiter);
      if( flag)
      {
         s = _parser_recall_string_1( parser);
         [parser->output appendString:s];
         return( flag);
      }

      if( parser->c =='\\')
      {
         // don't touch 'd'
         if( ! MulleStringEnumeratorNext( &parser->rover, &parser->c))
            break;

         range = _parser_recall( parser);
         range.length--;
         s     = _parser_substring( parser, range);
         [parser->output appendString:s];

         _parser_memo( parser);
      }
   }

   // default, nothing found append everything to output (grabbing)
   // if we have output, otherwise keep output empty
   if( parser->output)
   {
      s = _parser_recall_string( parser);
      [parser->output appendString:s];
   }
   return( NO);
}


static int   _parser_skip_to_closer_partial( struct parser *parser,
                                             unichar opener,
                                             unichar closer)
{
   int   level;

   level = 0;
   for(;;)
   {
      if( ! _parser_next_character_with_escaping( parser))
         break;

      if( parser->c == opener)
         ++level;
      else
         if( parser->c == closer)
            if( ! level--)
               return( 1);
   }
   return( 0);
}


static int   _parser_skip_to_closers_partial( struct parser *parser,
                                              unichar opener,
                                              unichar closer1,
                                              unichar closer2)
{
   int   level;

   level = 0;
   for(;;)
   {
      if( ! _parser_next_character_with_escaping( parser))
         break;

      if( parser->c == opener)
         ++level;
      else
         if( parser->c == closer1 || parser->c == closer2)
            if( ! level--)
               return( 1);
   }
   return( 0);
}


static int   _parser_skip_to_closer( struct parser *parser,
                                     unichar opener,
                                     unichar closer)
{
   int   level;

   level = 1;

   assert( parser->c == opener);

   for(;;)
   {
      if( ! _parser_next_character_with_escaping( parser))
         break;

      if( parser->c == opener)
         ++level;
      else
         if( parser->c == closer)
            if( ! --level)
               return( 1);
   }
   return( 0);
}


static void   _parser_skip_to_identifier_end( struct parser *parser)
{
   assert( mulle_unicode_is_identifierstart( parser->c));

   while( _parser_next_character( parser))
      if( ! mulle_unicode_is_identifiercontinuation( parser->c))
      {
         _parse_undo_next_character( parser); // dial back
         break;
      }
}


// so we already have parser->c read, now tokenize
static inline enum token_type   _parser_next_operator( struct parser *parser)
{
   _parser_next_character( parser);
   switch( parser->c)
   {
   case '}' :
      return( token_expand);

   case ':' :
      _parser_next_character( parser);
      switch( parser->c)
      {
      case '-' : return( token_expand_with_default_value);
      case '=' : return( token_expand_with_default_key);
      case '+' : return( token_expand_with_value);
      }
      _parse_undo_next_character( parser);
      return( token_expand_substring_offset);

   case '/' :
      _parser_next_character( parser);
      switch( parser->c)
      {
      case '/' : return( token_expand_replace_all);
      case '#' : return( token_expand_replace_prefix);
      case '%' : return( token_expand_replace_suffix);
      }
      _parse_undo_next_character( parser);
      return( token_expand_replace);

   case '^' :
   case ',' :
   case '%' :
   case '#' :
      _parser_next_character( parser);
      if( parser->c == parser->d)
      {
         return( parser->c + token_operator + 1);  // trick :)
      }
      _parse_undo_next_character( parser);
      return( parser->d + token_operator);

   default :
      return( token_error);
   }
}


static struct parser_token   _parser_next_token( struct parser *parser)
{
   int           atEnd;
   NSUInteger    i;

   _parser_memo( parser);
   _parser_next_character( parser);
   if( mulle_unicode_is_identifierstart( parser->c))
   {
      do
      {
         if( ! _parser_next_character( parser))
            return( parser_token_make( token_identifier,
                                       _parser_recall_string( parser)));
      }
      while( mulle_unicode_is_identifiercontinuation( parser->c));

      _parse_undo_next_character( parser);
      return( parser_token_make( token_identifier,
                                 _parser_recall_string( parser)));
   }

   if( parser->c >= '0' && parser->c <= '9')
   {
      i = 0;
      do
      {
         i *= 10;
         i += parser->c - '0';

         if( (atEnd = ! _parser_next_character( parser)))
            break;
      }
      while( parser->c >= '0' && parser->c <= '9');

      if( ! atEnd)
         _parse_undo_next_character( parser);
      return( parser_token_make( token_integer, [NSNumber numberWithUnsignedLongLong:i]));
   }

   return( parser_token_make( parser->c, nil));
}


static inline NSString  *_parser_do_substring( struct parser *parser, NSString *key)
{
   NSUInteger            value_length;
   NSRange               range;
   struct parser_token   token;
   NSString              *value;

   value          = _parser_get_value_string( parser, key);
   value_length   = [value length];

   token          = _parser_next_token( parser);
   if( token.type != token_integer)
      return( nil);

   range.location = [token.value unsignedIntegerValue];
   range.length   = -1;

   if( parser->c == ':')
   {
      _parser_next_character( parser);

      token = _parser_next_token( parser);
      if( token.type != token_integer)
         return( nil);

      range.length =  [token.value unsignedIntegerValue];
      if( range.length + range.location > value_length)
         range.length = value_length - range.location;
   }

   range = mulle_range_validate_against_length( range, value_length);
   value = [value substringWithRange:range];
   return( value);
}


static id   _parser_do_expand( struct parser *parser, NSString *key)
{
   NSString     *value;

   //
   // we are here ${foo}
   //
   value = _parser_get_value_string( parser, key);
   return( value);
}


static id   _parser_do_expand_default_value_or_key( struct parser *parser,
                                                    NSString *key,
                                                    BOOL indirect)
{
   int          rc;
   id           other;
   NSString     *value;

   //
   // we are here ${foo:-
   //
   _parser_memo( parser);
   // this can't fail really, will consume '}'
   if( (rc = _parser_skip_to_closer_partial( parser, '{', '}')) <= 0)
      return( nil);

   value = _parser_get_value_string( parser, key);
   if( [value length])
      return( value);

   other = _parser_recall_string_1( parser);

   // now we need to expand this again, so we can do ${foo:-${bar}}
   value = [other mulleBashExpandWithDataSource:parser->info];
   if( indirect)
      value = _parser_get_value_string( parser, value);
   return( value);
}


static inline NSString   *_parser_do_expand_default_value( struct parser *parser,
                                                           NSString *key)
{
   return( _parser_do_expand_default_value_or_key( parser, key, NO));
}


// this is ${foo:=xxx}
static inline NSString   *_parser_do_expand_default_key( struct parser *parser,
                                                         NSString *key)
{
   return( _parser_do_expand_default_value_or_key( parser, key, YES));
}



// this is ${foo:+xxx}
static inline NSString   *_parser_do_expand_value( struct parser *parser,
                                                   NSString *key)
{
   NSUInteger   value_length;
   int          rc;
   id           other;
   NSString     *value;
   //
   // we are here ${foo:-
   //
   _parser_memo( parser);
   // this can't fail really, will consume '}'
   if( (rc = _parser_skip_to_closer_partial( parser, '{', '}')) <= 0)
      return( nil);

   value = _parser_get_value_string( parser, key);
   value_length = [value length];
   if( ! value_length)
      return( @"");

   other = _parser_recall_string_1( parser);

   // now we need to expand this again, so we can do ${foo:-${bar}}
   other = [other mulleBashExpandWithDataSource:parser->info];

   return( other);
}


static inline NSString   *_parser_do_prefix_suffix( struct parser *parser,
                                                    enum token_type token_type,
                                                    NSString *key)
{
   int                      rc;
   id                       other;
   NSString                 *value;
   NSRange                  range;
   NSStringCompareOptions   options;

   options = NSAnchoredSearch|MulleObjCWildcards;
   switch( token_type)
   {
   case token_expand_remove_suffix :
      options |= MulleObjCWildcardsShortestPath;  // fall thru
   case token_expand_remove_suffix_all :
      options |= NSBackwardsSearch;
      options &= ~NSAnchoredSearch;
   default :
      break;

   case token_expand_remove_prefix :
      options |= MulleObjCWildcardsShortestPath;
   }

   //
   // we are here ${foo#
   //
   _parser_memo( parser);
   // this can't fail really, will consume '}'
   if( (rc = _parser_skip_to_closer_partial( parser, '{', '}')) <= 0)
      return( nil);

   value = _parser_get_value_string( parser, key);
   other = _parser_recall_string_1( parser);
   other = [other mulleBashExpandWithDataSource:parser->info];

   range = [value mulleRangeOfPattern:other
                              options:options];

   if( range.length == 0)
      return( range.location == 0 ? value : nil);

   if( options & NSAnchoredSearch)
      return( [value substringFromIndex:range.length]);
   return( [value substringToIndex:range.location]);
}


// this is ${foo^[a-z]) and ^^ and , ,,
static inline NSString   *_parser_do_upper_lower_case( struct parser *parser,
                                                       enum token_type token_type,
                                                       NSString *key)
{
   BOOL         firstOnly;
   NSString     *pattern;
   NSString     *value;
   NSUInteger   pattern_length;
   int          rc;
   unichar      (*conversion)( unichar);
   unichar      *block;
   unichar      *buf;
   unichar      *dst;
   unichar      c;
   unichar      tmp[ 2];
   void         *r;

   value      = _parser_get_value_string( parser, key);
   firstOnly  = YES;
   conversion = mulle_unicode_tolower;

   switch( token_type)
   {
   case token_expand_upper_case_all :
      firstOnly = NO;
   case token_expand_upper_case :
      conversion = mulle_unicode_toupper;
   default :
      break;

   case token_expand_lower_case_all :
      firstOnly = NO;
   }

   //
   // we are here ${foo^^
   //
   _parser_memo( parser);
   // this can't fail really, will consume '}'
   if( (rc = _parser_skip_to_closer_partial( parser, '{', '}')) <= 0)
      return( nil);

   pattern        = _parser_recall_string_1( parser);
   pattern_length = [pattern length];
   r              = NULL;

   block          = mulle_malloc( ([value length] + 1) * sizeof( unichar));
   dst            = block;

   mulle_alloca_do( pattern_characters, unichar, pattern_length + 1 + 1)
   {
      if( pattern_length)
      {
         buf = pattern_characters;
         *buf++ = '^';
         [pattern getCharacters:buf];
         buf += pattern_length;
         *buf++ = 0;

         r = mulle_utf32regex_compile( pattern_characters);
      }

      tmp[ 1] = 0;
      MulleStringFor( value, c)
      {
         if( conversion)
         {
            if( r)
            {
               tmp[ 0] = c;
               rc  = mulle_utf32regex_execute( r, tmp);
               if( rc < 0)
                  break;
               if( rc > 0)
                  c = (*conversion)( c);
            }
            else
               c = (*conversion)( c);
         }
         if( firstOnly)
            conversion = 0;

         *dst++ = c;
      }

      mulle_utf32regex_free( r);

   }
   *dst++ = 0;
   return( [NSString mulleStringWithCharactersNoCopy:block
                                              length:dst - block
                                           allocator:&mulle_default_allocator]);
}


static NSString    *replace_all( NSString *value, NSString *pattern, NSString *string)
{
   NSMutableString   *s;
   NSUInteger        valueLength;
   NSRange           searchRange;
   NSRange           foundRange;
   NSRange           pieceRange;
   NSString          *piece;

   // because '//' is somewhat tricky to implement, we do the replacing manually
   s            = [NSMutableString string];
   valueLength  = [value length];
   searchRange  = NSMakeRange( 0, valueLength);
   for(;;)
   {
      foundRange = [value mulleRangeOfPattern:pattern
                                      options:MulleObjCWildcards
                                        range:searchRange];
      // nothing found, then
      if( foundRange.length == 0)
      {
         // error...
         if( searchRange.location == NSNotFound)
            return( nil);

         // get remaining string from value and add it
         piece = [value substringWithRange:searchRange];
         [s appendString:piece];
         return( [[s copy] autorelease]);
      }

      // get unmatched front portion of value and add it
      pieceRange = NSMakeRange( searchRange.location, foundRange.location - searchRange.location);
      piece      = [value substringWithRange:pieceRange];
      [s appendString:piece];

      // now add substitution string
      [s appendString:string];

      // continue with the rest of the value
      searchRange.location = foundRange.location + foundRange.length;
      searchRange.length   = valueLength - searchRange.location;
   }
}

// this is ${key/pattern/string}
static inline NSString   *_parser_do_replace( struct parser *parser,
                                              enum token_type token_type,
                                              NSString *key)
{
   int          rc;
   NSString     *value;
   NSString     *pattern;
   NSString     *string;
   NSUInteger   options;

   //
   // we are here ${foo:-
   //
   _parser_memo( parser);
   // this can't fail really, will consume '}' or '/'
   if( (rc = _parser_skip_to_closers_partial( parser, '{', '}', '/')) <= 0)
      return( nil);
   pattern = _parser_recall_string_1( parser);
   string  = @"";

   if( parser->c == '/')
   {
      _parser_memo( parser);
      // this can't fail really, will consume '}' or '/'
      if( (rc = _parser_skip_to_closer_partial( parser, '{', '}')) <= 0)
         return( nil);
      string = _parser_recall_string_1( parser);
   }

   value   = _parser_get_value_string( parser, key);
   pattern = [pattern mulleBashExpandWithDataSource:parser->info];
   string  = [string mulleBashExpandWithDataSource:parser->info];
   options = MulleObjCWildcards;
   switch( token_type)
   {
   case token_expand_replace_prefix  : options |= NSAnchoredSearch; break;
   case token_expand_replace_suffix  : options |= NSBackwardsSearch;
   default                           : break;
   }

   if( token_type != token_expand_replace_all)
      return( [value mulleStringByReplacingPattern:pattern
                                        withString:string
                                           options:options]);

   return( replace_all( value, pattern, string));
}



static inline id   _parser_do_operation( struct parser *parser, NSString *key)
{
   enum token_type   token_type;

   token_type = _parser_next_operator( parser);
   switch( token_type)
   {
   case token_expand                    : return( _parser_do_expand( parser, key));

   case token_expand_with_default_value : return( _parser_do_expand_default_value( parser, key));
   case token_expand_with_default_key   : return( _parser_do_expand_default_key( parser, key));
   case token_expand_with_value         : return( _parser_do_expand_value( parser, key));

   case token_expand_substring_offset   : return( _parser_do_substring( parser, key));

   case token_expand_remove_prefix      :
   case token_expand_remove_prefix_all  :
   case token_expand_remove_suffix      :
   case token_expand_remove_suffix_all  : return( _parser_do_prefix_suffix( parser, token_type, key));

   case token_expand_replace            :
   case token_expand_replace_prefix     :
   case token_expand_replace_suffix     :
   case token_expand_replace_all        : return( _parser_do_replace( parser, token_type, key));

   case token_expand_upper_case         :
   case token_expand_upper_case_all     :
   case token_expand_lower_case         :
   case token_expand_lower_case_all     : return( _parser_do_upper_lower_case( parser, token_type, key));

   default                              : return( nil);
   }
}


//
// here we know we have ${..${..}..}, reasonably well formed
// meaning the non-escaped openers and closers even out. We don't have to
// deal with prefix or suffix plaintext
//
static id   _parser_expand_expression( struct parser *p)
{
   struct parser_token   token;
   id                    value;


   token = _parser_next_token( p);
   if( token.type != '$')
      return( nil);

   token = _parser_next_token( p);
   if( token.type != '{')
      return( NULL);

   // we are here ${
   token = _parser_next_token( p);
   if( token.type == '#' || token.type == '|')
   {
      token = _parser_next_token( p);
      if( token.type != token_identifier)
         return( NULL);

      value = @( [token.value length]);

      token = _parser_next_token( p);
      if( token.type != '}')
         return( NULL);

      return( value);
   }

   if( token.type != token_identifier)
      return( NULL);

   // we are now here ${foo
   value = _parser_do_operation( p, token.value);
   return( value);
}

//
// expand stuff like "foo$xxx-1" or "x${abc}", the more interesting routine
// is _parser_expand, which is known to be of form ${foo...} only (no
// leading or trailing plain text
//
static NSString   *_parser_expand( struct parser *p)
{
   NSString         *value;
   int             rc;
   NSString        *s;

   for(;;)
   {
      // this adds to output string
      rc = _parser_grab_to_delimiter( p, '$');
      if( rc <= 0)
         break;

      // do not add input directly to output string now
      assert( p->c == '$');

      _parser_memo_1( p);  // memo at $

      rc = _parser_next_character( p);
      if( rc <= 0)
         break;

      if( p->c == '{')
      {
         if( (rc = _parser_skip_to_closer( p, '{', '}')) <= 0)
            break;

         s     = _parser_recall_string( p);
         value = [s mulleBashExpandExpressionWithDataSource:p->info];
         if( ! value)
         {
            rc = -1;
            break;
         }
      }
      else
      {
         if( (rc = mulle_unicode_is_identifierstart( p->c)) <= 0)
            break;

         _parser_skip_to_identifier_end( p);  // can't fail

         s     = _parser_recall_string( p);
         value = _parser_get_value_string( p, s);
      }
      assert( p->output);
      [p->output appendString:value];
   }

   if( rc == -1)
      return( nil);

   // so this in those cases, where we don't have anything to expand and
   // there were no escapes, will just yield the input string back which
   // has been stored temporarily in the NSMutableString :)
   if( p->output)
   {
      s = [[p->output copy] autorelease];
      p->output = nil;
      return( s);
   }
   return( p->input);
}


@implementation  NSString ( BashExpand)

- (id) mulleBashExpandExpressionWithDataSource:(id) info
{
   id              value;
   struct parser   parser;

   _parser_init_with_string( &parser, self, info);
   {
      value = _parser_expand_expression( &parser);
   }
   _parser_done( &parser);
   return( value);
}


- (id) mulleExpandExpressionWithDataSource:(id) info
{
   NSMutableString   *s;

   s = [NSMutableString string];
   [s appendString:@"${"];
   [s appendString:self];
   [s appendString:@"}"];
   return( [s mulleBashExpandExpressionWithDataSource:info]);
}


- (id) mulleBashExpandWithDataSource:(id) info
{
   id              value;
   struct parser   parser;

   _parser_init_with_string( &parser, self, info);
   {
      value = _parser_expand( &parser);
   }
   _parser_done( &parser);
   return( value);
}

@end

