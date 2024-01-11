//
//  S.m
//  MulleBashStringExpansion
//
//  Copyright (c) 2023 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#import "S.h"

#import "import-private.h"

#import "NSString+MulleBashStringExpansion.h"


@implementation S

+ (instancetype) objectWithDataSource:(id) dataSource
{
   S   *s;

   s = [self object];
   [s setDataSource:dataSource];
   return( s);
}


+ (instancetype) objectWithMulleScionLocalVariables:(NSMutableDictionary *) locals
                                        dataSource:(id) dataSource
{
   S   *s;

   s = [self object];
   [s setLocals:locals];
   [s setDataSource:dataSource];
   return( s);
}


- (id) valueForKeyPath:(NSString *) key
{
   id   value;

   value = [_locals valueForKeyPath:key];
   if( value)
      return( value);
   return( [_dataSource valueForKeyPath:key]);
}


- (id) :(NSString *) s
{
   return( s);
}


- (id) $:(NSString *) s
{
   return( [s mulleExpandExpressionWithDataSource:self]);
}


- (NSRange) :(NSString *) s
            :(NSString *) p
{
   return( [s mulleRangeOfPattern:p]);
}


- (NSRange)  :(NSString *) s
            $:(NSString *) p
{
   p = [p mulleExpandExpressionWithDataSource:self];
   return( [s mulleRangeOfPattern:p]);
}


- (NSRange) $:(NSString *) s
             :(NSString *) p
{
   s = [s mulleExpandExpressionWithDataSource:self];
   return( [s mulleRangeOfPattern:p]);
}



- (NSRange) $:(NSString *) s
            $:(NSString *) p
{
   s = [s mulleExpandExpressionWithDataSource:self];
   p = [p mulleExpandExpressionWithDataSource:self];
   return( [s mulleRangeOfPattern:p]);
}



- (id) :(NSString *) s
       :(NSString *) p
       :(NSString *) r
{
   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}


- (id) :(NSString *) s
       :(NSString *) p
      $:(NSString *) r
{
   r = [r mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}

- (id) :(NSString *) s
      $:(NSString *) p
       :(NSString *) r
{
   p = [p mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}


- (id) :(NSString *) s
      $:(NSString *) p
      $:(NSString *) r
{
   p = [p mulleExpandExpressionWithDataSource:self];
   r = [r mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);
}


- (id) $:(NSString *) s
        :(NSString *) p
        :(NSString *) r
{
   s = [s mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}


- (id) $:(NSString *) s
        :(NSString *) p
       $:(NSString *) r
{
   s = [s mulleExpandExpressionWithDataSource:self];
   r = [r mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}

- (id) $:(NSString *) s
       $:(NSString *) p
        :(NSString *) r
{
   s = [s mulleExpandExpressionWithDataSource:self];
   p = [p mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);

}


- (id) $:(NSString *) s
       $:(NSString *) p
       $:(NSString *) r
{
   s = [s mulleExpandExpressionWithDataSource:self];
   p = [p mulleExpandExpressionWithDataSource:self];
   r = [r mulleExpandExpressionWithDataSource:self];

   return( [s mulleStringByReplacingPattern:p
                                 withString:r]);
}


@end
