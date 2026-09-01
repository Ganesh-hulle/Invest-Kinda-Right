package com.ganesh.IKR.marketdata;

import jakarta.validation.constraints.NotEmpty;
import java.util.Set;

public record InstrumentTokensRequest(@NotEmpty Set<Long> instrumentTokens) { }
