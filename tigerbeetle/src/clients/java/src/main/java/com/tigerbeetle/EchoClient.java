package com.tigerbeetle;

import java.util.concurrent.CompletableFuture;

public final class EchoClient implements AutoCloseable {

    private final NativeClient nativeClient;

    public EchoClient(final byte[] clusterID, final String replicaAddresses) {
        this.nativeClient = NativeClient.initEcho(clusterID, replicaAddresses);
    }

    public AccountBatch echo(final AccountBatch batch) throws Exception {
        final var request = BlockingRequest.echo(this.nativeClient, batch);
        request.beginRequest();
        return request.waitForResult();
    }

    public TransferBatch echo(final TransferBatch batch) throws Exception {
        final var request = BlockingRequest.echo(this.nativeClient, batch);
        request.beginRequest();
        return request.waitForResult();
    }

    public CompletableFuture<AccountBatch> echoAsync(final AccountBatch batch) throws Exception {
        final var request = AsyncRequest.echo(this.nativeClient, batch);
        request.beginRequest();
        return request.getFuture();
    }

    public CompletableFuture<TransferBatch> echoAsync(final TransferBatch batch) throws Exception {
        final var request = AsyncRequest.echo(this.nativeClient, batch);
        request.beginRequest();
        return request.getFuture();
    }

    public void close() throws Exception {
        nativeClient.close();
    }
}
