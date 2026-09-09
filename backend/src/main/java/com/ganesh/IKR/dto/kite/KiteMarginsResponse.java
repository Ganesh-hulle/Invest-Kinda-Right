package com.ganesh.IKR.dto.kite;

import java.util.Map;

public record KiteMarginsResponse(
        Map<String, Object> equity,
        Map<String, Object> commodity
) {}
