module hunt.http.client.Http2ClientHandler;

import hunt.http.client.Http1ClientConnection;
import hunt.http.client.Http2ClientContext;
import hunt.http.client.Http2ClientConnection;

import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.AbstractHttpHandler;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.net.secure.SecureSession;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.Session;

import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.text.Common;

import hunt.collection.Map;

import hunt.logging;
import std.array;

class Http2ClientHandler : AbstractHttpHandler {

    private Map!(int, Http2ClientContext) http2ClientContext;

    this(HttpConfiguration config, Map!(int, Http2ClientContext) http2ClientContext) {
        super(config);
        this.http2ClientContext = http2ClientContext;
    }

    override
    void sessionOpened(Session session) {
        Http2ClientContext context = http2ClientContext.get(session.getSessionId());

        if (context is null) {
            errorf("http2 client can not get the client context of session %s", session.getSessionId());
            session.closeNow();
            return;
        }

        if (config.isSecureConnectionEnabled()) {
            SecureSessionFactory factory = config.getSecureSessionFactory();
            SecureSession secureSession = factory.create(session, true, delegate void (SecureSession sslSession) {

                string protocol = "http/1.1";
                string p = sslSession.getApplicationProtocol();
                if(p.empty)
                    warningf("The selected application protocol is empty. now use default: %s", protocol);
                else
                    protocol = p;

                infof("Client session %s SSL handshake finished. The app protocol is %s", session.getSessionId(), protocol);
                switch (protocol) {
                    case "http/1.1":
                        initializeHttp1ClientConnection(session, context, sslSession);
                        break;
                    case "h2":
                        initializeHttp2ClientConnection(session, context, sslSession);
                        break;
                    default:
                        throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " ~ protocol ~ " is not supported");
                }
            });

            session.attachObject(cast(Object)secureSession);
        } else {
            if (config.getProtocol().empty) {
                initializeHttp1ClientConnection(session, context, null);
            } else {
                HttpVersion httpVersion = HttpVersion.fromString(config.getProtocol());
                if (httpVersion == HttpVersion.Null) {
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
                if(httpVersion == HttpVersion.HTTP_1_1) {
                        initializeHttp1ClientConnection(session, context, null);
                } else if(httpVersion == HttpVersion.HTTP_2) {
                        initializeHttp2ClientConnection(session, context, null);
                } else {
                        throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
            }

        }
    }

    private void initializeHttp1ClientConnection(Session session, Http2ClientContext context,
                                                 SecureSession sslSession) {
        try {
            Http1ClientConnection http1ClientConnection = new Http1ClientConnection(config, session, sslSession);
            session.attachObject(http1ClientConnection);
            // context.getPromise().succeeded(http1ClientConnection);
            import hunt.http.client.HttpClientConnection;
            Promise!(HttpClientConnection) promise  = context.getPromise();
            infof("Promise id = %s", promise.id);
            promise.succeeded(http1ClientConnection);

        } catch (Exception t) {
            context.getPromise().failed(t);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    private void initializeHttp2ClientConnection(Session session, Http2ClientContext context,
                                                 SecureSession sslSession) {
        try {
            Http2ClientConnection connection = new Http2ClientConnection(config, session, sslSession, context.getListener());
            session.attachObject(connection);
            context.getListener().setConnection(connection);            
            // connection.initialize(config, cast(Promise!(Http2ClientConnection))context.getPromise(), context.getListener());
            connection.initialize(config, context.getPromise(), context.getListener());
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    override
    void sessionClosed(Session session) {
        try {
            super.sessionClosed(session);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    override
    void failedOpeningSession(int sessionId, Exception t) {

        auto c = http2ClientContext.remove(sessionId);
        if(c !is null)
        {
            auto promise = c.getPromise();
            if(promise !is null)
                promise.failed(t);
        }
        
        // Optional.ofNullable(http2ClientContext.remove(sessionId))
        //         .map(Http2ClientContext::getPromise)
        //         .ifPresent(promise => promise.failed(t));
    }

    override
    void exceptionCaught(Session session, Exception t) {
        try {
            super.exceptionCaught(session, t);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

}
