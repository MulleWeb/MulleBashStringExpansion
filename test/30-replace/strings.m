#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

#include <stdio.h>


static NSString  *expressions[] =
{
   @"foo",
   @"foo:-baz",
   @"baz:-foo",
   @"baz:=foo",
   @"foo:3",
   @"foo:1:1",
   @"foo#bar",
   @"foo%bar",
   @"foo^^",
   @"foo^^[a-b]",
   @"foo//b/c",
   nil,
};


int   main( void)
{
   NSString       *value;
   NSDictionary   *info;
   S              *s;
   NSString       **p;

   info  = @{ @"foo": @"foobar" };
   s     = [S objectWithMulleScionLocalVariables:nil
                                      dataSource:info];
   value = [s:@"foobar"
             :@"(o+)"
             :@"x\\1x"];
   mulle_printf( "\"%@\"\n", value);

   for( p = expressions; *p; p++)
   {
      value = [s $:*p];
      mulle_printf( "\"%@\" -> \"%@\"\n", *p, value);
   }
   return 0;
}
