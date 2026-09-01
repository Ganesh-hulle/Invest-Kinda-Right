package com.ganesh.IKR.strategy;

public interface Strategy {
    Signal evaluate(Candle candle);
}
