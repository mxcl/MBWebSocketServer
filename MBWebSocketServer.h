// Originally created by Max Howell in October 2011.
// This class is in the public domain.
//
// MBWebSocketServer accepts client connections as soon as it is instantiated.
// Implementated against: http://tools.ietf.org/id/draft-ietf-hybi-thewebsocketprotocol-10

#import "AsyncSocket.h"

@protocol MBWebSocketServerDelegate;


@interface MBWebSocketServer : NSObject {
    AsyncSocket *socket;
    NSMutableArray *connections;
}

- (id)initWithPort:(NSUInteger)port delegate:(id<MBWebSocketServerDelegate>)delegate;

// Sends this data to all open connections. The object must respond to
// webSocketFrameData. We provide implementations for NSData and NSString.
- (void)send:(id)object;

@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, weak) id<MBWebSocketServerDelegate> delegate;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSUInteger clientCount;
@end


@protocol MBWebSocketServerDelegate
- (void)webSocketServer:(MBWebSocketServer *)webSocketServer didAcceptConnection:(AsyncSocket *)connection;
- (void)webSocketServerClientDisconnected:(MBWebSocketServer *)webSocketServer;
- (void)webSocketServer:(MBWebSocketServer *)webSocket didReceiveData:(NSData *)data fromConnection:(AsyncSocket *)connection;

// data is passed to you as it was received from the socket, ie. with header & masked
- (void)webSocketServer:(MBWebSocketServer *)webSocketServer couldNotParseRawData:(NSData *)rawData fromConnection:(AsyncSocket *)connection error:(NSError *)error;
@end


@interface AsyncSocket (MBWebSocketServer)
- (void)writeWebSocketFrame:(id)object;
@end


@interface NSData (MBWebSocketServer)
- (id)webSocketFrameData;
+ (NSData *)dataWithWebSocketFrameData:(NSData *)webSocketData;
@end
