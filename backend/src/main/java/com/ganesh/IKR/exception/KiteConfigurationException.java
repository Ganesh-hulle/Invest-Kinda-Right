package com.ganesh.IKR.exception;

public class KiteConfigurationException extends RuntimeException {
    public KiteConfigurationException(String message) { super(message); }
    public KiteConfigurationException(String message, Throwable cause) { super(message, cause); }
}
