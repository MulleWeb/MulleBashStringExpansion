#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

#include <stdio.h>


static NSString  *expressions[] =
{
   @"foo.bar",
   @"url#https://",
   @"zlib%@*",
   nil,
};


int   main( void)
{
   NSString       *value;
   NSDictionary   *info;
   S              *sInstance;
   NSString       **p;

   info  = @{ @"foo": @{ @"bar": @"foobar" },
              @"bar": @"baz",
              @"url": @"https://www.github.com/archive/archive",
              @"zlib": @"zlib:mulle-c/mulle-container@*"
            };

   sInstance = [S objectWithMulleScionLocalVariables:nil
                                          dataSource:info];
   for( p = expressions; *p; p++)
   {
      value = [sInstance $:*p];
      mulle_printf( "\"%@\" -> \"%@\"\n", *p, value);
   }
   return 0;
}
