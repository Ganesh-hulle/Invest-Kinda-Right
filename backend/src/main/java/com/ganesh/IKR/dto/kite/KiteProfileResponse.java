package com.ganesh.IKR.dto.kite;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record KiteProfileResponse(
        @JsonProperty("user_id") String userId,
        @JsonProperty("user_name") String userName,
        @JsonProperty("user_shortname") String userShortname,
        String email,
        @JsonProperty("user_type") String userType,
        String broker,
        List<String> exchanges,
        List<String> products,
        @JsonProperty("order_types") List<String> orderTypes,
        @JsonProperty("avatar_url") String avatarUrl,
        @JsonProperty("login_time") String loginTime
) {}
