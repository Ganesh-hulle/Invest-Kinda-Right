package com.ganesh.IKR.dto.kite;

import java.util.List;
import java.util.Map;

public record KitePortfolioResponse(
        List<Map<String, Object>> holdings,
        List<Map<String, Object>> netPositions,
        List<Map<String, Object>> dayPositions
) {}
