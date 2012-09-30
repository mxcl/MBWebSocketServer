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

static unsigned long long ntohll(unsigned long long v) {
    union { unsigned long lv[2]; unsigned long long llv; } u;
    u.llv = v;
    return ((unsigned long long)ntohl(u.lv[0]) << 32) | (unsigned long long)ntohl(u.lv[1]);
}



@implementation MBWebSocketServer
@dynamic connected;
@dynamic clientCount;

- (id)initWithPort:(NSUInteger)port delegate:(id<MBWebSocketServerDelegate>)delegate {
    _port = port;
    _delegate = delegate;
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    clients = [NSMutableArray new];

    NSError *error = nil; //TODO
    [socket acceptOnPort:_port error:&error];

    return self;
}

- (BOOL)connected {
    return clients.count > 0;
}

- (NSUInteger)clientCount {
    return clients.count;
}

- (void)respondToHandshake:(NSData *)data client:(AsyncSocket *)client {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSArray *strings = [string componentsSeparatedByString:@"\r\n"];
    
    if (strings.count == 0 || ![strings[0] isEqualToString:@"GET / HTTP/1.1"]) {
        NSLog(@"MBWebSocketServer invalid handshake from client");
        return [client disconnect];
    }
    
    NSString *response = [NSString stringWithFormat:
                          @"HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
                          "Upgrade: websocket\r\n"
                          "Connection: Upgrade\r\n"
                          "Sec-WebSocket-Accept: %@\r\n\r\n",
                          [strings secWebSocketAccept]];
    
    [client writeData:[response dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
}

- (uint64_t)readFrame:(const unsigned char*)bytes length:(NSUInteger)length block:(void (^)(char *data, NSUInteger nbytes))block {
    if (length < 2)
        @throw @"Bad frame";
    if (!bytes[0] & 0x81)
        @throw @"Cannot handle this websocket frame format!";
    if (!bytes[1] & 0x80)
        @throw @"Can only handle websocket frames with masks!";

    unsigned n = 2;
    uint64_t N = bytes[1] & 0x7f;
    switch (N) {
        case 126: {
            if (length < 4)
                @throw @"Bad frame";
            uint16_t *p = (uint16_t *)(bytes + 2);
            N = ntohs(*p);
            n += 2;
            break;
        }
        case 127: {
            if (length < 10)
                @throw @"Bad frame";
            uint64_t *p = (uint64_t *)(bytes + 2);
            N = ntohll(*p);
            n += 8;
        }
        default:
            break;
    }

    if (length < n + 4 + N)
        @throw @"Bad frame";

    const unsigned char *mask = bytes + n;
    char unmaskedData[N];
    for (int x = 0; x < N; ++x)
        unmaskedData[x] = bytes[x+n+4] ^ mask[x%4];

    block(unmaskedData, N);

    return n + 4 + N;
}

- (NSData *)readFrames:(NSData *)indata {
    NSMutableData *data = [NSMutableData data];
    uint x = 0;
    while (x < indata.length) {
        x += [self readFrame:indata.bytes + x length:indata.length block:^(char *rawdata, NSUInteger length){
            [data appendBytes:rawdata length:length];
        }];
    }
    return data;
}

- (void)send:(NSData *)payload client:(id)client {
    if (!payload.length)
        return;

    if ([payload isKindOfClass:[NSString class]]) {
        payload = [[(NSString *)payload dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    }
    
    NSMutableData *data = [NSMutableData dataWithLength:10];
    char *header = data.mutableBytes;
    header[0] = 0x81;

    if (payload.length > 65535) {
        header[1] = 127;
        header[2] = (payload.length >> 56) & 255;
        header[3] = (payload.length >> 48) & 255;
        header[4] = (payload.length >> 40) & 255;
        header[5] = (payload.length >> 32) & 255;
        header[6] = (payload.length >> 24) & 255;
        header[7] = (payload.length >> 16) & 255;
        header[8] = (payload.length >>  8) & 255;
        header[9] = payload.length & 255;
    } else if (payload.length > 125) {
        header[1] = 126;
        header[2] = (payload.length >> 8) & 255;
        header[3] = payload.length & 255;
        data.length = 4;
    } else {
        header[1] = payload.length;
        data.length = 2;
    }

    [data appendData:payload];

    NSArray *cc = [client isKindOfClass:[NSArray class]] ? client : client ? @[client] : clients;
    for (AsyncSocket *client in cc)
        [client writeData:data withTimeout:-1 tag:3];
}

- (void)send:(id)payload {
    [self send:payload client:nil];
}


#pragma mark - ASyncSocketDelegate

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)client {
    [clients addObject:client];
    [client readDataWithTimeout:-1 tag:1];
}

- (void)onSocket:(AsyncSocket *)client didReadData:(NSData *)data withTag:(long)tag
{    
    if (tag == 1) { // waiting for handshake
        [self respondToHandshake:data client:client];
    } else {
        [_delegate webSocketServer:self didReceiveData:[self readFrames:data]];
        [client readDataWithTimeout:-1 tag:3];
    }
}

- (void)onSocket:(AsyncSocket *)client didWriteDataWithTag:(long)tag {
    switch (tag) {
        case 2: {
            id response = [_delegate webSocketServerDidAcceptConnection:self];
            [self send:response client:client];
            // fall through
        }
        case 3:
            [client readDataWithTimeout:-1 tag:3];
    }
}

- (void)onSocketDidDisconnect:(AsyncSocket *)client {
    [clients removeObjectIdenticalTo:client];
    [_delegate webSocketServerClientDisconnected:self];
}

@end



@implementation NSArray (MBWebSocketServer)

- (id)secWebSocketKey {
    for (NSString *line in self) {
        //TODO better efficiency!
        NSArray *parts = [line componentsSeparatedByString:@":"];
        if (parts.count == 2) {
            if ([parts[0] isEqualToString:@"Sec-WebSocket-Key"])
                return [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
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
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

@end