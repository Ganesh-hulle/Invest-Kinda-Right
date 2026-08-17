package com.ganesh.IKR.exception;

public class KiteApiException extends RuntimeException {
    public KiteApiException(String message) { super(message); }
    public KiteApiException(String message, Throwable cause) { super(message, cause); }
}
