// Originally created by Max Howell in October 2011.
// This class is in the public domain.

#import "AsyncSocket.h"
#import <CommonCrypto/CommonDigest.h>
#import "MBWebSocketServer.h"


@interface MBWebSocketServer () <AsyncSocketDelegate>
@end

@interface NSArray (MBWebSocketServer)
- (id)secWebSocketKey;
- (id)secWebSocketAccept;
@end

@interface NSString (MBWebSocketServer)
- (id)sha1base64;
@end



@implementation MBWebSocketServer

- (id)initWithPort:(NSUInteger)aport delegate:(id<MBWebSocketServerDelegate>)adelegate {
    port = aport;
    delegate = adelegate;
    socket = [[AsyncSocket alloc] initWithDelegate:self];

    NSError *error = nil; //TODO
    [socket acceptOnPort:port error:&error];

    return self;
}

- (void)close {
    if (client) {
        [client release];
        client = nil;
        [delegate webSocketServerDidDisconnect:self];
    }
}

- (void)respondToHandshake:(NSData *)data {
    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    NSArray *strings = [string componentsSeparatedByString:@"\r\n"];
    
    if (strings.count == 0 || ![[strings objectAtIndex:0] isEqualToString:@"GET / HTTP/1.1"]) {
        NSLog(@"MBWebSocketServer invalid handshake from client");
        return [self close];
    }
    
    NSString *response = [NSString stringWithFormat:
                          @"HTTP/1.1 101 Switching Protocols\r\n"
                          "Upgrade: websocket\r\n"
                          "Connection: Upgrade\r\n"
                          "Sec-WebSocket-Accept: %@\r\n\r\n",
                          [strings secWebSocketAccept]];
    
    [client writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
}

- (unsigned int)readFrame:(const char*)bytes {
    if (!bytes[0] & 0x81)
        @throw @"Cannot handle this websocket frame format!";
    
    if (!bytes[1] & 0x80)
        @throw @"Can only handle websocket frames with masks!";
    
    unsigned n = 2;
    int16_t N = bytes[1] & 0x7f;
    switch (N) {
        case 126: {
            N = ntohs((short) bytes[3] << 8 | bytes[2]);
            n += 2;
            break;
        }
        case 127:
            @throw @"8 byte lengths unsupported currently!";
        default:
            break;
    }
    
    const char *mask = bytes + n;
    char unmaskedData[N];
    for (int x = 0; x < N; ++x)
        unmaskedData[x] = bytes[x+n+4] ^ mask[x%4];
    
    [delegate webSocketServer:self didReceiveData:[NSData dataWithBytes:unmaskedData length:N]];
    
    return n + 4 + N;
}

- (void)readFrames:(NSData *)data {
    @try {
        uint x = 0;
        while (x < data.length)
            x += [self readFrame:data.bytes + x];
    }
    @catch (id e) {
        NSLog(@"%@", e);
    }
}

- (void)send:(NSData *)payload {
    if ([payload isKindOfClass:[NSString class]])
         payload = [[(NSString *)payload dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    
    NSMutableData *data = [NSMutableData dataWithLength:4];
    char *header = data.mutableBytes;
    header[0] = 0x81;

    if (payload.length > 125) {
        header[1] = 126;
        header[2] = payload.length >> 8;
        header[3] = payload.length & 0xff;
    } else {
        header[1] = payload.length;
        data.length = 2;
    }

    [data appendData:payload];
    [client writeData:data withTimeout:-1 tag:3];
}


#pragma mark - ASyncSocketDelegate

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)aclient {
    client = [aclient retain];
    [client readDataWithTimeout:-1 tag:1];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{    
    if (tag == 1) { // waiting for handshake
        [self respondToHandshake:data];
    } else {
        [self readFrames:data];
        [client readDataWithTimeout:-1 tag:3];
    }
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (sock == client) {
        switch (tag) {
            case 2:
                [delegate webSocketServerDidConnect:self];
            case 3:
                [client readDataWithTimeout:-1 tag:3];
        }
    }
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
    if (sock == client)
        [self close];
}


#pragma mark - Boilerplate

- (void)dealloc {
    [socket release];
    [client release];
    [super dealloc];
}

@synthesize port;
@synthesize delegate;
@end



@implementation NSArray (MBWebSocketServer)

- (id)secWebSocketKey {
    for (NSString *line in self) {
        //TODO better efficiency!
        NSArray *parts = [line componentsSeparatedByString:@":"];
        if (parts.count == 2) {
            if ([[parts objectAtIndex:0] isEqualToString:@"Sec-WebSocket-Key"])
                return [[parts objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
        }
    }
    return nil;
}

- (id)secWebSocketAccept {
    return [[NSString stringWithFormat:@"%@%@", [self secWebSocketKey], @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"] sha1base64];
}

@end



@implementation NSString (MBWebSocketServer)

- (id)sha1base64 {
    NSMutableData* data = (id) [self dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char input[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (unsigned)data.length, input);

//////
    static const char map[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    data = [NSMutableData dataWithLength:28];
    uint8_t* out = (uint8_t*) data.mutableBytes;
    
    for (int i = 0; i < 20;) {
        int v  = 0;
        for (const int N = i + 3; i < N; i++) {
            v <<= 8;
            v |= 0xFF & input[i];
        }
        *out++ = map[v >> 18 & 0x3F];
        *out++ = map[v >> 12 & 0x3F];
        *out++ = map[v >> 6 & 0x3F];
        *out++ = map[v >> 0 & 0x3F];
    }
    out[-2] = map[(input[19] & 0x0F) << 2];
    out[-1] = '=';
    return [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
}

@end