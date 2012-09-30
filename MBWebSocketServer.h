// Originally created by Max Howell in October 2011.
// This class is in the public domain.
//
// MBWebSocketServer accepts client connections as soon as it is created.
// MBWebSocketServer only accepts a single client connection at any time.
// Implementated against: http://tools.ietf.org/id/draft-ietf-hybi-thewebsocketprotocol-10

#import <CoreFoundation/CoreFoundation.h>
@protocol MBWebSocketServerDelegate;
@class AsyncSocket;


@interface MBWebSocketServer : NSObject {
    AsyncSocket *socket;
    NSMutableArray *clients;
}

- (id)initWithPort:(NSUInteger)port delegate:(id<MBWebSocketServerDelegate>)delegate;

- (void)send:(id)utf8StringOrData;

@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, weak) id<MBWebSocketServerDelegate> delegate;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSUInteger clientCount;
@end


@protocol MBWebSocketServerDelegate
// return a response for this client, NSData or NSString are valid
- (id)webSocketServerDidAcceptConnection:(MBWebSocketServer *)webSocket;
- (void)webSocketServerClientDisconnected:(MBWebSocketServer *)webSocket;
- (void)webSocketServer:(MBWebSocketServer *)webSocket didReceiveData:(NSData *)data;
@end
