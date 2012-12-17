MBWebSocketServer
=================
A websocket *server implementation*, (you cannot instantiate an instance that
does not bind to a port).

NOTE! I have not tested it extensively and there are many old WS versions. So
you may well have to hack it to make it work. But! There is not much code.
And! I believe it is quite readable. I will help! Mail me!

Tested against recent Chrome, Safari and Firefox versions. Only tested on Mac.

If you want a client implementation, use Square’s SocketRocket.

Caveats
-------
* There's no support for fragmented frames.

Requirements
------------
* ARC or Garbage Collection
* Xcode 4.5

Example Usage
-------------
```objc
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.ws = [[MBWebSocketServer alloc] initWithPort:13581 delegate:self];
}

- (void)webSocketServer:(MBWebSocketServer *)webSocketServer didAcceptConnection:(GCDAsyncSocket *)connection {
    NSLog(@"Connected to a client, we accept multiple connections");
}

- (void)webSocketServer:(MBWebSocketServer *)webSocket didReceiveData:(NSData *)data fromConnection:(GCDAsyncSocket *) {
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

    [connection writeWebSocketFrame:@"Thanks for the data!"]; // you can write NSStrings or NSDatas
}

- (void)webSocketServer:(MBWebSocketServer *)webSocketServer clientDisconnected:(GCDAsyncSocket *)connection {
    NSLog(@"Disconnected from client: %@", connection);
}

- (void)webSocketServer:(MBWebSocketServer *)webSocketServer couldNotParseRawData:(NSData *)rawData fromConnection:(GCDAsyncSocket *)connection error:(NSError *)error {
    NSLog(@"MBWebSocketServer error: %@", error);
}

```


Author
------
I’m [Max Howell][mxcl] and I'm a splendid chap

[mxcl]:http://twitter.com/mxcl
