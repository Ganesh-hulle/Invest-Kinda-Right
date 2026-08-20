package com.ganesh.IKR.dto.kite;

import java.time.OffsetDateTime;

public record InstrumentSyncResponse(int instrumentCount, OffsetDateTime syncedAt) { }
