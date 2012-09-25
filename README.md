MBWebSocket
===========
A websocket *server implementation*, (you cannot instantiate an instance that
does not bind to a port).

NOTE! I have not tested it extensively and there are many old WS versions. So
you may well have to hack it to make it work. But! There is not much code.
And! I believe it is quite readable. I will help! Mail me!

Tested against recent Chrome, Safari and Firefox versions. Only tested on Mac.

If you want a client implementation, use Square’s SocketRocket.

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

- (void)webSocketServerDidConnect:(MBWebSocketServer *)webSocket {
    NSLog(@"Connected to a client (and we only work with one for now!)");
}

- (void)webSocketServer:(MBWebSocketServer *)webSocket didReceiveData:(NSData *)data
{
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    [webSocket send:@"Thanks!"];
}

- (void)webSocketServerDidDisconnect:(MBWebSocketServer *)webSocket {
    NSLog(@"Disconnected from client");
}

```

Author
------
I’m [Max Howell][mxcl] and I'm a splendid chap

[mxcl]:http://twitter.com/mxcl
