MBWebSocket
===========
So far just a *server implementation*, (you cannot instantiate an instance that does not bind to a port). Also, the server can only manage a single connection at a time.

So, seriously, you will probably have to do some work to this class to make it
work how you need it too. But it’s nice and simple so just get straight in.

Tested against Chrome 10/2011. Probably will only work against that.

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
