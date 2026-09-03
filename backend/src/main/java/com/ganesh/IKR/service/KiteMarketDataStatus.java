package com.ganesh.IKR.service;

import java.time.OffsetDateTime;
import java.util.Set;

public record KiteMarketDataStatus(
        String status,
        Set<Long> requestedInstrumentTokens,
        long binaryFrames,
        long heartbeats,
        long packetsReceived,
        long ticksAccepted,
        long ticksRejected,
        long unmatchedPackets,
        long malformedFrames,
        long shortPackets,
        Long lastPacketToken,
        Long lastUnmatchedToken,
        OffsetDateTime connectedAt,
        OffsetDateTime lastTickAt,
        OffsetDateTime closedAt,
        String lastError
) {
    public static KiteMarketDataStatus disconnected() {
        return new KiteMarketDataStatus("DISCONNECTED", Set.of(), 0, 0, 0, 0, 0, 0, 0, 0,
                null, null, null, null, null, null);
    }
}
