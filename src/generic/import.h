/* DOS:   #import this files in public headers
 *
 * DONTS: #import this file in private headers
 *        #import this files directly in sources
 *        #include this file anywhere
 *
 * This is a central include file to keep dependencies out of the library
 *  Objective-C files. It is usally imported by Objective-C .h files only.
 *  .m and .aam use import-private.h.
 */

// this is a global symbol that is exposed, which can be used to detect
// if this library is available

#define HAVE_IMPORT_MULLE_BASH_STRING_EXPANSION

/*
 * Get C includes first. As "include.h" is a generic name,
 * testing could pick up the wrong one, so we test for an inferior header
 * that we assume to be there if "include.h" were to exist.
 *
 * #ifdef __has_include
 * # if __has_include( "_MulleBashStringExpansion-include.h")
 * #   include "include.h"
 * # endif
 * #endif
 */


#ifndef MULLE_BASH_STRING_EXPANSION_GLOBAL
# ifdef MULLE_BASH_STRING_EXPANSION_BUILD
#  define MULLE_BASH_STRING_EXPANSION_GLOBAL    MULLE_C_GLOBAL
# else
#  if defined( MULLE_BASH_STRING_EXPANSION_INCLUDE_DYNAMIC) || (defined( MULLE_INCLUDE_DYNAMIC) && ! defined( MULLE_BASH_STRING_EXPANSION_INCLUDE_STATIC))
#   define MULLE_BASH_STRING_EXPANSION_GLOBAL   MULLE_C_GLOBAL
#  else
#   define MULLE_BASH_STRING_EXPANSION_GLOBAL   extern
#  endif
# endif
#endif

/* Include the header file automatically generated by mulle-sourcetree-to-c.
   Here the prefix is harmless and serves disambiguation. If you have no
   sourcetree, then you don't need it.
 */

#import "_MulleBashStringExpansion-import.h"

/* You can add some more import statements here */
