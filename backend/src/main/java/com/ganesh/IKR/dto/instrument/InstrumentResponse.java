package com.ganesh.IKR.dto.instrument;

import com.ganesh.IKR.entity.Instrument;

public record InstrumentResponse(Long instrumentToken, String exchange, String tradingsymbol,
                                 String name, String segment, String instrumentType) {
    public static InstrumentResponse from(Instrument instrument) {
        return new InstrumentResponse(instrument.getInstrumentToken(), instrument.getExchange(),
                instrument.getTradingsymbol(), instrument.getName(), instrument.getSegment(), instrument.getInstrumentType());
    }
}
