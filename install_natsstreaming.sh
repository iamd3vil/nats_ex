#!/bin/bash

set -e

export DEFAULT_NATS_STREAMING_SERVER_VERSION=v0.16.2
export NATS_STREAMING_SERVER_VERSION="${NATS_STREAMING_SERVER_VERSION:=$DEFAULT_NATS_STREAMING_SERVER_VERSION}"

# check to see if gnatsd folder is empty
if [ ! "$(ls -A $HOME/nats-streaming-server)" ]; then
    (
	      mkdir -p $HOME/nats-streaming-server
	      cd $HOME/nats-streaming-server
	      wget https://github.com/nats-io/nats-streaming-server/releases/download/$NATS_STREAMING_SERVER_VERSION/nats-streaming-server-$NATS_STREAMING_SERVER_VERSION-linux-amd64.zip -O nats-streaming-server.zip
	      unzip nats-streaming-server.zip
	      cp nats-streaming-server-$NATS_STREAMING_SERVER_VERSION-linux-amd64/nats-streaming-server $HOME/nats-streaming-server/nats-streaming-server
        # start gnatsd server
        nohup $HOME/nats-streaming-server/nats-streaming-server -cid mycluster &
    )
else
    echo 'Using cached directory.';
fi
