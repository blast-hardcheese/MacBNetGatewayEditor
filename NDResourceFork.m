/*
 *  NDResourceFork.m
 *
 *  Created by nathan on Wed Dec 05 2001.
 *  Copyright (c) 2001 Nathan Day. All rights reserved.
 *
 *	Currently ResourceFork will not add resource forks to files
 *	or create new files with resource forks
 *
 */

#import "NDResourceFork.h"
#import "NSString+CarbonUtilities.h"

NSData * dataFromResourceHandle( Handle aResourceHandle );
BOOL operateOnResourceUsingFunction( short int afileRef, ResType aType, NSString * aName, short int anId, BOOL (*aFunction)(Handle) );

/*
 * class interface ResourceTypeEnumerator : NSEnumerator
 */
@interface ResourceTypeEnumerator : NSEnumerator
{
	@private
	SInt16	numberOfTypes,
				typeIndex;
}
+ (id)resourceTypeEnumerator;
@end

/*
 * class implementation NDResourceFork
 */
@implementation NDResourceFork

/*
 * resourceForkForReadingAtURL:
 */
+ (id)resourceForkForReadingAtURL:(NSURL *)aURL
{
	return [[[self alloc] initForReadingAtURL:aURL] autorelease];
}

/*
 * resourceForkForWritingAtURL:
 */
+ (id)resourceForkForWritingAtURL:(NSURL *)aURL
{
	return [[[self alloc] initForWritingAtURL:aURL] autorelease];
}

/*
 * resourceForkForReadingAtPath:
 */
+ (id)resourceForkForReadingAtPath:(NSString *)aPath
{
	return [[[self alloc] initForReadingAtPath:aPath] autorelease];
}

/*
 * resourceForkForWritingAtPath:
 */
+ (id)resourceForkForWritingAtPath:(NSString *)aPath
{
	return [[[self alloc] initForWritingAtPath:aPath] autorelease];
}

/*
 * initForReadingAtURL:
 */
- (id)initForReadingAtURL:(NSURL *)aURL
{
	return [self initForPermission:fsRdPerm AtURL:aURL];
}

/*
 * initForWritingAtURL:
 */
- (id)initForWritingAtURL:(NSURL *)aURL
{
	return [self initForPermission:fsWrPerm AtURL:aURL];
}

/*
 * initForPermission:AtURL:
 */
- (id)initForPermission:(char)aPermission AtURL:(NSURL *)aURL
{
	return [self initForPermission:aPermission AtPath:[aURL path]];
}

/*
 * -initForPermission:AtPath:
 */
- (id)initForPermission:(char)aPermission AtPath:(NSString *)aPath
{
	OSErr			theError = !noErr;
	FSRef			theFsRef,
					theParentFsRef;

	if( self = [self init] )
	{
		/*
		 * if write permission then create resource fork
		 */
		if( (aPermission & 0x06) != 0 )		// if write permission
		{
			if ( [[aPath stringByDeletingLastPathComponent] getFSRef:&theParentFsRef] )
			{
				unsigned int	theNameLength;
				unichar 			theUnicodeName[ PATH_MAX ];
				NSString			* theName;

				theName = [aPath lastPathComponent];
				theNameLength = [theName length];

				if( theNameLength <= PATH_MAX )
				{
					[theName getCharacters:theUnicodeName range:NSMakeRange(0,theNameLength)];

					FSCreateResFile( &theParentFsRef, theNameLength, theUnicodeName, 0, NULL, NULL, NULL );		// doesn't replace if already exists

					theError =  ResError( );

					if( theError == noErr || theError == dupFNErr )
					{
						[aPath getFSRef:&theFsRef];
						fileReference = FSOpenResFile ( &theFsRef, aPermission );
						theError = fileReference > 0 ? ResError( ) : !noErr;
					}
				}
				else
					theError = !noErr;
			}
		}
		else		// dont have write permission
		{
			[aPath getFSRef:&theFsRef];
			fileReference = FSOpenResFile ( &theFsRef, aPermission );
			theError = fileReference > 0 ? ResError( ) : !noErr;
		}

	}

	if( noErr != theError && theError != dupFNErr )
	{
		[self release];
		self = nil;
	}

	return self;
}

/*
 * initForReadingAtPath:
 */
- (id)initForReadingAtPath:(NSString *)aPath
{
	if( [[NSFileManager defaultManager] fileExistsAtPath:aPath] )
		return [self initForPermission:fsRdPerm AtURL:[NSURL fileURLWithPath:aPath]];
	else
	{
		[self release];
		return nil;
	}
}

/*
 * initForWritingAtPath:
 */
- (id)initForWritingAtPath:(NSString *)aPath
{
	return [self initForPermission:fsWrPerm AtURL:[NSURL fileURLWithPath:aPath]];
}

/*
 * dealloc
 */
- (void)dealloc
{
	if( fileReference > 0 )
		CloseResFile( fileReference );

	[super dealloc];
}

/*
 * -addData:type:Id:name:
 */
- (BOOL)addData:(NSData *)aData type:(ResType)aType Id:(short int)anId name:(NSString *)aName
{
	Handle		theResHandle;
	
	if( [self removeType:aType Id:anId] )
	{
		short int	thePreviousRefNum;

		thePreviousRefNum = CurResFile();	// save current resource
		UseResFile( fileReference );    			// set this resource to be current
	
		// copy NSData's bytes to a handle
		if ( noErr == PtrToHand ( [aData bytes], &theResHandle, [aData length] ) )
		{
			Str255			thePName;

			[aName pascalString:(StringPtr)thePName length:sizeof(thePName)];
			
			HLock( theResHandle );
			AddResource( theResHandle, aType, anId, thePName );
			HUnlock( theResHandle );

/*			if( noErr == ResError() )
				ChangedResource( theResHandle );
*/			
			UseResFile( thePreviousRefNum );     		// reset back to resource previously set
	
			return ( ResError( ) == noErr );
		}
	}
	
	return NO;
}

/*
 * -addData:type:name:
 */
- (BOOL)addData:(NSData *)aData type:(ResType)aType name:(NSString *)aName
{
	if( aName == nil ) NSLog(@"Adding a resource without specifying the name of id.");
	return [self addData:aData type:aType Id:Unique1ID(aType) name:aName];
}

/*
 * dataForType:Id:
 */
- (NSData *)dataForType:(ResType)aType Id:(short int)anId
{
	NSData	* theData;
	BOOL getDataFunction( Handle aResHandle )
	{
		theData = dataFromResourceHandle( aResHandle );
		return theData != nil;
	}
	
	if( operateOnResourceUsingFunction( fileReference, aType, nil, anId, getDataFunction )  )
		return theData;
	else
		return nil;
}
/*
 * dataForType:named:
 */
- (NSData *)dataForType:(ResType)aType named:(NSString *)aName
{
	NSData	* theData;
	BOOL getDataFunction( Handle aResHandle )
	{
		theData = dataFromResourceHandle( aResHandle );
		return theData != nil;
	}

	if( operateOnResourceUsingFunction( fileReference, aType, aName, 0, getDataFunction )  )
		return theData;
	else
		return nil;
}

/*
 * removeType: Id:
 */
- (BOOL)removeType:(ResType)aType Id:(short int)anId
{
	BOOL removeResourceFunction( Handle aResHandle )
	{
		if( aResHandle )
			RemoveResource( aResHandle );		// Disposed of in current resource file
		return !aResHandle || noErr == ResError( );
	}
	
	return operateOnResourceUsingFunction( fileReference, aType, nil, anId, removeResourceFunction );
}

/*
 * nameOfResourceType:Id:
 */
- (NSString *)nameOfResourceType:(ResType)aType Id:(short int)anId
{
	NSString		* theString = nil;

	BOOL getNameFunction( Handle aResHandle )
	{
		Str255		thePName;

		if( aResHandle )
		{
			GetResInfo( aResHandle, &anId, &aType, thePName );
			if( noErr ==  ResError( ) )
				theString = [NSString stringWithPascalString:thePName];
		}

		return theString != nil;
	}


	if( operateOnResourceUsingFunction( fileReference, aType, NULL, anId, getNameFunction ) )
		return theString;
	else
		return nil;

}

/*
 * getId:OfResourceType:Id:
 */
- (BOOL)getId:(short int *)anId ofResourceType:(ResType)aType named:(NSString *)aName
{
	BOOL getIdFunction( Handle aResHandle )
	{
		Str255		thePName;

		if( aResHandle && [aName pascalString:(StringPtr)thePName length:sizeof(thePName)] )
		{
			GetResInfo( aResHandle, anId, &aType, thePName );
			return noErr ==  ResError( );
		}
		else
			return NO;
	}

	return operateOnResourceUsingFunction( fileReference, aType, aName, 0, getIdFunction );
}

/*
 * -attributeFlags:forResourceType:Id:
 */
- (BOOL)getAttributeFlags:(short int*)attributes forResourceType:(ResType)aType Id:(short int)anId
{
	BOOL getAttributesFunction( Handle aResHandle )
	{
		if( aResHandle )
		{
			*attributes = GetResAttrs( aResHandle );
			return noErr ==  ResError( );
		}

		return NO;
	}

	return operateOnResourceUsingFunction( fileReference, aType, nil, anId, getAttributesFunction );
}

/*
 * -setAttributeFlags:forResourceType:Id:
 */
- (BOOL)setAttributeFlags:(short int)attributes forResourceType:(ResType)aType Id:(short int)anId
{
	BOOL		theSuccess;
	BOOL setAttributesFunction( Handle aResHandle )
	{
		if( aResHandle )
		{
			attributes &= ~(resPurgeable|resChanged); // these attributes should not be changed
			SetResAttrs( aResHandle, attributes);
			if( noErr ==  ResError( ) )
			{
				ChangedResource(aResHandle);
				return noErr ==  ResError( );
			}
		}

		return NO;
	}

	NSLog(@"WARRING: Currently the setAttributeFlags:forResourceType:Id: does not work");
	theSuccess = operateOnResourceUsingFunction( fileReference, aType, nil, anId, setAttributesFunction );
	return theSuccess;
}

/*
 * -resourceTypeEnumerator
 */
- (NSEnumerator *)resourceTypeEnumerator
{
	return [ResourceTypeEnumerator resourceTypeEnumerator];
}

/*
 * -everyResourceType
 */
- (NSArray *)everyResourceType
{
	return [[ResourceTypeEnumerator resourceTypeEnumerator] allObjects];
}

/*
 * -dataForEntireResourceFork
 */
- (NSData *)dataForEntireResourceFork
{
	NSMutableData		* theData = nil;
	ByteCount			theByteCount;
	signed long long	theForkSize;
	
	if( FSGetForkSize( fileReference, &theForkSize ) == noErr && theForkSize <= UINT_MAX )
	{
		theData = [NSMutableData dataWithLength:theForkSize];
		if( FSReadFork( fileReference, fsFromStart, 0, theForkSize, [theData mutableBytes], &theByteCount ) != noErr || theByteCount != theForkSize )
			theData = nil;
	}

	return theData;
}

/*
 * -writeEntireResourceFork:
 */
- (BOOL)writeEntireResourceFork:(NSData *)aData
{
	ByteCount		theWrittenBytes;
	unsigned int	theDataLength;

	theDataLength = [aData length];

	// return true if aData exists, length not zero, write succeeds, write length equals data length
	return aData && theDataLength != 0 && FSWriteFork( fileReference, fsFromStart, 0, theDataLength, [aData bytes], &theWrittenBytes ) == noErr && theDataLength == theWrittenBytes;
}

@end

/*
 * class implementation ResourceTypeEnumerator
 */
@implementation ResourceTypeEnumerator

/*
 * +resourceTypeEnumerator
 */
+ (id)resourceTypeEnumerator
{
	return [[[self alloc] init] autorelease];
}

/*
 * -init
 */
- (id)init
{
	if( self = [super init] )
	{
		NSAssert( sizeof(ResType) <= sizeof(unsigned long) ,@"WARNING: everyResourceType assumes that ResType is the same size as unsigned long" );

		numberOfTypes = Count1Types ();
		typeIndex = 1;
	}

	return self;
}

/*
 * -nextObject
 */
- (id)nextObject
{
	NSNumber		* theResTypeNumber = nil;
	ResType		theResType;

	if( typeIndex <=  numberOfTypes )
	{
		Get1IndType ( &theResType, typeIndex );

		if( noErr ==  ResError( ) )
			theResTypeNumber = [NSNumber numberWithUnsignedLong:theResType];
		else
			NSLog( @"Could not get type for resource %i", typeIndex);

		typeIndex++;
	}

	return theResTypeNumber;

}

@end

/*
 * dataFromResourceHandle()
 */
NSData * dataFromResourceHandle( Handle aResourceHandle )
{
	NSData		* theData = nil;
	if( aResourceHandle )
	{
		HLock(aResourceHandle);
		theData = [NSData dataWithBytes:*aResourceHandle length:GetHandleSize( aResourceHandle )];
		HUnlock(aResourceHandle);
	}

	return theData;
}

/*
 * operateOnResourceUsingFunction()
 */
BOOL operateOnResourceUsingFunction( short int afileRef, ResType aType, NSString * aName, short int anId, BOOL (*aFunction)(Handle) )
{
	Handle		theResHandle = NULL;
	short int	thePreviousRefNum;
	Str255		thePName;
	BOOL			theResult = NO;

	thePreviousRefNum = CurResFile();	// save current resource

	UseResFile( afileRef );    		// set this resource to be current

	if( noErr ==  ResError( ) && ((aName && [aName pascalString:(StringPtr)thePName length:sizeof(thePName)]) || !aName ))
	{
		if( aName && [aName pascalString:(StringPtr)thePName length:sizeof(thePName)] )
			theResHandle = Get1NamedResource( aType, thePName );
		else if( !aName )
			theResHandle = Get1Resource( aType, anId );

		if( noErr == ResError() )
			theResult = aFunction( theResHandle );

		if ( theResHandle )
			ReleaseResource( theResHandle );
	}

	UseResFile( thePreviousRefNum );     		// reset back to resource previously set

	return theResult;
}





