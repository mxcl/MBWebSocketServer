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
    NSUInteger port;
    id<MBWebSocketServerDelegate> delegate;
    AsyncSocket *socket;
    AsyncSocket *client;
}

- (id)initWithPort:(NSUInteger)port delegate:(id<MBWebSocketServerDelegate>)delegate;

- (void)send:(id)utf8StringOrData;

@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, assign) id<MBWebSocketServerDelegate> delegate;
@property (nonatomic, readonly) BOOL connected;
@end


@protocol MBWebSocketServerDelegate
- (void)webSocketServerDidConnect:(MBWebSocketServer *)webSocket;
- (void)webSocketServerDidDisconnect:(MBWebSocketServer *)webSocket;
- (void)webSocketServer:(MBWebSocketServer *)webSocket didReceiveData:(NSData *)data;
@end
