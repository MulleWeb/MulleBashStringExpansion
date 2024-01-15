#import "import.h"


#define MULLE_BASH_STRING_EXPANSION_VERSION  ((0UL << 20) | (0 << 8) | 2)


static inline unsigned int   MulleBashStringExpansionG_get_version_major( void)
{
   return( MULLE_BASH_STRING_EXPANSION_VERSION >> 20);
}


static inline unsigned int   MulleBashStringExpansion_get_version_minor( void)
{
   return( (MULLE_BASH_STRING_EXPANSION_VERSION >> 8) & 0xFFF);
}


static inline unsigned int   MulleBashStringExpansion_get_version_patch( void)
{
   return( MULLE_BASH_STRING_EXPANSION_VERSION & 0xFF);
}


MULLE_BASH_STRING_EXPANSION_GLOBAL
uint32_t   MulleBashStringExpansion_get_version( void);


#import "_MulleBashStringExpansion-export.h"


#ifdef __has_include
# if __has_include( "_MulleBashStringExpansion-versioncheck.h")
#  include "_MulleBashStringExpansion-versioncheck.h"
# endif
#endif

