//
//  NSDictionarySerializer.m
//  Trovebox
//
//  Created by Patrick Santana on 05/07/12.
//  Copyright 2013 Trovebox
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "NSDictionarySerializer.h"

@implementation NSDictionarySerializer

static NSString * const KEY_NSDICTIONARY = @"key_nsdictionary_to_data_and_vice_versa";

+ (NSData*) nsDictionaryToNSData:(NSDictionary *) dict
{
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:dict forKey:KEY_NSDICTIONARY];
    [archiver finishEncoding];
    
    return data;
}

+ (NSDictionary*) nsDataToNSDictionary:(NSData *) data
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    NSDictionary *dic = [unarchiver decodeObjectForKey:KEY_NSDICTIONARY];
    [unarchiver finishDecoding];
    
    return dic;
}

@end
