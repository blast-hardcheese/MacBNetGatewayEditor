//
//  GatewayLists.h
//  MacBNetGatewayEditor
//
//  Created by Jeremy Knope on Sun May 16 2004.
//  Copyright (c) 2004 JfroWare. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark Defines
//                                              com.blizzard.WarcraftIII.16
// #define kWar3PrefsPath @"Library/Preferences/com.blizzard.WarcraftIII.16"
#define kWar3PrefsPath @"/Library/Preferences/com.blizzard.WarcraftIII.16"
#define kBNetPrefsPath @"/Library/Preferences/Battle.net Preferences"
#define kStarPrefsPath @"/Library/Preferences/Starcraft Prefs"

#define kWar3RegPath @"HKEY_CURRENT_USER\\Software\\Blizzard Entertainment\\Warcraft III\\Battle.net Gateways"
#define kD2RegPath @"HKEY_CURRENT_USER\\Software\\Battle.net\\Configuration\\Diablo II Battle.net gateways"
#define kSCRegPath @"HKEY_CURRENT_USER\\Software\\Battle.net\\Configuration\\Battle.net gateways"
#pragma mark -

@class BNGateway;
@class NDResourceFork;

@interface GatewayLists : NSObject {
	NSString *currentGame;
	
	id currentArray;
	
	NSMutableArray *W3gateways;
	NSMutableArray *SCgateways;
	NSMutableArray *D2gateways;
	
	NDResourceFork *bnetFork;   // Battle.net Preferences
	NDResourceFork *starFork;   // Starcraft Prefs
	NDResourceFork *war3Fork;   // com.blizzard.WarcraftIII.## where ## is version, 15 for 115
	
	NSData *w3Header;
	NSData *d2Header;
	NSData *scHeader;
	
	NSString *lastError;
	BOOL error;
	
	BOOL hasSC;
	BOOL hasD2;
	BOOL hasW3;
	
	BOOL changedSC;
	BOOL changedD2;
	BOOL changedW3;
}
#pragma mark -
#pragma mark Methods
- (id)init;
- (void)loadResourceData;
- (BOOL)saveResourceData;
- (BOOL)saveGateways:(NSArray *)arr toFork:(NDResourceFork *)aFork withHeader:(NSData *)aHeader name:(NSString *)aName resId:(int)theId;

- (NSString *)lastError;

// check to see if they have game prefs
- (BOOL)hasD2;
- (BOOL)hasW3;
- (BOOL)hasSC;

- (NSData *)processGatewayData:(NSData *)data intoArray:(NSMutableArray *)arr;
- (void)setCurrentGame:(NSString *)aGame;

- (void)addGateway:(BNGateway *)gate forGame:(NSString *)game;
- (void)removeGatewayAtIndex:(int)index forGame:(NSString *)game;
- (void)setDefaultGatewatAtIndex:(int)index forGame:(NSString *)game;
- (void)moveGatewayUpFromIndex:(int)index forGame:(NSString *)game;
- (void)moveGatewayDownFromIndex:(int)index forGame:(NSString *)game;

@end
