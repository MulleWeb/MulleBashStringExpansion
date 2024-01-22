#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

#include <stdio.h>


static NSString  *expressions[] =
{
   @"foo.bar",
   nil,
};


int   main( void)
{
   NSString       *value;
   NSDictionary   *info;
   S              *s;
   NSString       **p;

   info  = @{ @"foo": @{ @"bar": @"foobar" }};
   s     = [S objectWithMulleScionLocalVariables:nil
                                      dataSource:info];
   for( p = expressions; *p; p++)
   {
      value = [s $:*p];
      mulle_printf( "\"%@\" -> \"%@\"\n", *p, value);
   }
   return 0;
}
