package com.ganesh.IKR.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.math.BigDecimal;

@ConfigurationProperties(prefix = "trading")
public class TradingProperties {
    private boolean liveEnabled;
    private BigDecimal paperStartingCapital = new BigDecimal("1000000");

    public boolean isLiveEnabled() { return liveEnabled; }
    public void setLiveEnabled(boolean liveEnabled) { this.liveEnabled = liveEnabled; }
    public BigDecimal getPaperStartingCapital() { return paperStartingCapital; }
    public void setPaperStartingCapital(BigDecimal paperStartingCapital) { this.paperStartingCapital = paperStartingCapital; }
}
