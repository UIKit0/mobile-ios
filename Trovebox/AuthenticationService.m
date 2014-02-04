//
//  AuthenticationService.m
//  Trovebox
//
//  Created by Patrick Santana on 5/10/12.
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

#import "AuthenticationService.h"

@implementation AuthenticationService

-(NSURL*) getOAuthInitialUrl{
    // get the url
    NSString *server = [[NSUserDefaults standardUserDefaults] valueForKey:kTroveboxServer];
    NSString *path = @"/v1/oauth/authorize?oauth_callback=openphoto://&name=";
    NSString *appName = [[UIDevice currentDevice] name];
    NSString *fullPath = [[NSString alloc]initWithFormat:@"%@%@%@",server,path,[appName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ] ;
    
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"URL for OAuth initialization = %@",fullPath);
#endif
    NSURL *url = [NSURL URLWithString:fullPath];
    
    if (!url){
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"URL is invalid, use the default.");
#endif
        return [NSURL URLWithString:[[NSString alloc]initWithFormat:@"%@%@%@",server,path,@"Trovebox%20App"] ];
    }
    
    return url;
}

-(NSURL*) getOAuthAccessUrl{
    // get the url
    NSString* server = [[NSUserDefaults standardUserDefaults] valueForKey:kTroveboxServer];
    NSString* url = [[NSString alloc]initWithFormat:@"%@%@",server,@"/v1/oauth/token/access"] ;
    
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"URL for OAuth Access = %@",url);
#endif
    
    return [NSURL URLWithString:url];
}

-(NSURL*) getOAuthTestUrl{
    // get the url
    NSString* server = [[NSUserDefaults standardUserDefaults] valueForKey:kTroveboxServer];
    NSString* url = [[NSString alloc]initWithFormat:@"%@%@",server,@"/v1/oauth/test"] ;
    
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"URL for OAuth Test = %@",url);
#endif
    
    return [NSURL URLWithString:url];
}


+ (BOOL) isLogged{
    /*
     * check if the client id is valid.
     * Possible values: nil, INVALID or other
     *
     * If it is nil or text INVALID, return that is INVALID = NO
     */
    if (![[NSUserDefaults standardUserDefaults] stringForKey:kAuthenticationValid] ||
        [[[NSUserDefaults standardUserDefaults] stringForKey:kAuthenticationValid] isEqualToString:@"INVALID"]){
        return NO;
    }
    
    // otherwise return that it is valid
    return YES;
}

- (void) logout{
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]initWithTroveboxConsumer];
    
    // remove the credentials from the server in case of internet
    if ([SharedAppDelegate internetActive]){
        NSString *consumerKey = [keychainItem objectForKey:(__bridge id)(kSecAttrAccount)];
        
        dispatch_queue_t removeCredentials = dispatch_queue_create("remove_credentials", NULL);
        dispatch_async(removeCredentials, ^{
            
            @try {
                WebService *service = [[WebService alloc] init];
                [service removeCredentialsForKey:consumerKey];
            }@catch (NSException *exception) {
#ifdef DEVELOPMENT_ENABLED
                NSLog(@"Error to remove the credentials from server %@",exception.description);
#endif
            }
            
        });
    }
    
    // set the variable client id to INVALID
    [standardUserDefaults setValue:@"INVALID" forKey:kAuthenticationValid];
    [standardUserDefaults setValue:nil forKey:kHomeScreenPicturesTimestamp];
    [standardUserDefaults setValue:nil forKey:kHomeScreenPictures];
    
    // reset profile information
    [standardUserDefaults setValue:nil forKey:kTroveboxEmailUser];
    [standardUserDefaults setValue:nil forKey:kProfileLatestUpdateDate];
    [standardUserDefaults setValue:nil forKey:kProfileAccountType];
    [standardUserDefaults setValue:nil forKey:kProfileLimitRemaining];
    [standardUserDefaults setValue:nil forKey:kTroveboxNameUser];
    
    // synchronize the keys
    [standardUserDefaults synchronize];
    
    // keychain for credentials reset
    [keychainItem resetKeychainItem];
    
    // reset core data
    [Timeline deleteAllTimelineInManagedObjectContext:[SharedAppDelegate managedObjectContext]];
    [Synced deleteAllSyncedPhotosInManagedObjectContext:[SharedAppDelegate managedObjectContext]];
    
    NSError *saveError = nil;
    if (![[SharedAppDelegate managedObjectContext] save:&saveError]){
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"Error deleting objects from core data = %@",[saveError localizedDescription]);
#endif
    }
    
    // reset cache
    [[SDImageCache sharedImageCache] cleanDisk];
    [[SDImageCache sharedImageCache] clearDisk];
    [[SDImageCache sharedImageCache] clearMemory];
    
    // send notification to clear the Menu
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNeededsUpdate object:nil];
    
    // display
    [SharedAppDelegate presentLoginViewController];
}

- (void) startOAuthProcedure:(NSURL*) url{
    
    /*
     * This is the step where the User allowed the iOS App to use the OpenPhoto service in his behalf.
     * The URL will be like that: openphoto://?oauth_consumer_key=e826d2647851aac26948b7a56044fc&oauth_consumer_secret=ba0c75dfa9&oauth_token=ba27ffebfbc07251a5fbf3529492d7&oauth_token_secret=5a9dc1c212&oauth_verifier=6b741d57c1
     * the openphoto is the callback that makes iOS to open our app, we also use openphoto-test in case of
     * TestFlight users.
     */
    
    // get the token and the verifier from the URL
    NSString *oauthConsumerKey = nil;
    NSString *oauthConsumerSecret = nil;
    NSString *oauthToken = nil;
    NSString *oauthTokenSecret = nil;
    NSString *oauthVerifier = nil;
    
    // we just care after ?
    NSArray *comp1 = [[url absoluteString] componentsSeparatedByString:@"?"];
    NSString *query = [comp1 lastObject];
    NSArray *queryElements = [query componentsSeparatedByString:@"&"];
    for (NSString *element in queryElements) {
        NSArray *keyVal = [element componentsSeparatedByString:@"="];
        NSString *variableKey = [keyVal objectAtIndex:0];
        NSString *value = [keyVal lastObject];
        
        // get all details from the request and save it
        if ([variableKey isEqualToString:@"oauth_consumer_key"]){
            oauthConsumerKey = value;
        }else if ([variableKey isEqualToString:@"oauth_consumer_secret"]){
            oauthConsumerSecret = value;
        }else if ([variableKey isEqualToString:@"oauth_token"]){
            oauthToken = value;
        }else if ([variableKey isEqualToString:@"oauth_token_secret"]){
            oauthTokenSecret = value;
        }else if ([variableKey isEqualToString:@"oauth_verifier"]){
            oauthVerifier = value;
        }
    }
    
    // save consumer data
    // keychain for credentials
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]initWithTroveboxConsumer];
    [keychainItem setObject:oauthConsumerKey forKey:(__bridge id)(kSecAttrAccount)];
    [keychainItem setObject:oauthConsumerSecret  forKey:(__bridge id)(kSecValueData)];
    
    /*
     * With the token and verifier, we can request the ACCESS
     */
    NSURL* accessUrl = [self getOAuthAccessUrl];
    
    // from the callback get the details and create token and consumer
    OAToken *token = [[OAToken alloc] initWithKey:oauthToken secret:oauthTokenSecret];
    OAConsumer *consumer = [[OAConsumer alloc] initWithKey:oauthConsumerKey secret:oauthConsumerSecret];
    
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:accessUrl
                                                                   consumer:consumer
                                                                      token:token
                                                                      realm:nil
                                                          signatureProvider:nil];
    // the request must be POST
    [request setHTTPMethod:@"POST"];
    
    // set parameters
    OARequestParameter *parameterToken = [[OARequestParameter alloc] initWithName:@"oauth_token" value:oauthToken];
    OARequestParameter *parameterVerifier = [[OARequestParameter alloc] initWithName:@"oauth_verifier"
                                                                               value:oauthVerifier];
    NSArray *params = [NSArray arrayWithObjects: parameterToken, parameterVerifier, nil];
    [request setParameters:params];
    
    // create data fetcher and send the request
    OADataFetcher *fetcher = [[OADataFetcher alloc] init];
    [fetcher fetchDataWithRequest:request
                         delegate:self
                didFinishSelector:@selector(requestTokenAccess:didFinishWithData:)
                  didFailSelector:@selector(requestToken:didFailWithError:)];
}


- (void)requestTokenAccess:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        /*
         *The Access Token will receive these information, eg:
         * oauth_token=9dd1869a9cf07fd5daa9b4e8785978
         * oauth_token_secret=18c2927518
         */
        NSString *oauthToken = nil;
        NSString *oauthTokenSecret = nil;
        
        
        // parse the data
        NSArray *queryElements = [responseBody componentsSeparatedByString:@"&"];
        
        for (NSString *element in queryElements) {
            NSArray *keyVal = [element componentsSeparatedByString:@"="];
            NSString *variableKey = [keyVal objectAtIndex:0];
            NSString *value = [keyVal lastObject];
            
            if ([variableKey isEqualToString:@"oauth_token"]){
                oauthToken = value;
            }else if ([variableKey isEqualToString:@"oauth_token_secret"]){
                oauthTokenSecret = value;
            }
        }
        
        
        // save data to the user information
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        
        [standardUserDefaults setValue:@"OK"        forKey:kAuthenticationValid];
        [standardUserDefaults setValue:nil          forKey:kHomeScreenPicturesTimestamp];
        [standardUserDefaults setValue:nil          forKey:kHomeScreenPictures];
        [standardUserDefaults setValue:[[UpdateUtilities instance] getVersion] forKey:kVersionApplicationInstalled];
        
        // synchronize the keys
        [standardUserDefaults synchronize];
        
        // save credentials
        // keychain for credentials
        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc]initWithTroveboxOAuth];
        
        [keychainItem setObject:oauthToken forKey:(__bridge id)(kSecAttrAccount)];
        [keychainItem setObject:oauthTokenSecret forKey:(__bridge id)(kSecValueData)];
        
        
        // send notification to the system that it can shows the screen:
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLoginAuthorize object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNeededsUpdate object:nil];
        
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"OAuth procedure finished");
#endif
        
    }
}

- (void)requestToken:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Error = %@", [error userInfo]);
#endif
    PhotoAlertView *alert = [[PhotoAlertView alloc] initWithMessage:NSLocalizedString(@"Authentication failed: try again.",@"Authentication method") duration:5000];
    [alert showAlertOnTop];
}

+ (NSArray *) signIn:(NSString*) email password:(NSString*) pwd
{
    return [PrivateAuthenticationService signIn:email password:pwd];
}

+ (NSString *) recoverPassword:(NSString *) email
{
    return [PrivateAuthenticationService recoverPassword:email];
}

+ (void) sendToServerReceipt:(NSData *) receipt forUser:(NSString *) email
{
    return [PrivateAuthenticationService sendToServerReceipt:receipt forUser:email];
}

@end

