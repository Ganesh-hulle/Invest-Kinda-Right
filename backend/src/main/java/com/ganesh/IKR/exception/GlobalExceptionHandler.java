package com.ganesh.IKR.exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(DuplicateUserException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateUser(
            DuplicateUserException exception,
            HttpServletRequest request
    ) {
        return errorResponse(
                HttpStatus.CONFLICT,
                "USER_ALREADY_EXISTS",
                exception.getMessage(),
                request
        );
    }

    @ExceptionHandler(InvalidCredentialsException.class)
    public ResponseEntity<ErrorResponse> handleInvalidCredentials(
            InvalidCredentialsException exception,
            HttpServletRequest request
    ) {
        return errorResponse(
                HttpStatus.UNAUTHORIZED,
                "INVALID_CREDENTIALS",
                exception.getMessage(),
                request
        );
    }

    @ExceptionHandler({KiteApiException.class, KiteConfigurationException.class})
    public ResponseEntity<ErrorResponse> handleKiteException(RuntimeException exception, HttpServletRequest request) {
        return errorResponse(HttpStatus.BAD_GATEWAY, "KITE_INTEGRATION_FAILED", exception.getMessage(), request);
    }

    @ExceptionHandler(RiskRejectedException.class)
    public ResponseEntity<ErrorResponse> handleRisk(RiskRejectedException exception, HttpServletRequest request) {
        return errorResponse(HttpStatus.UNPROCESSABLE_ENTITY, "RISK_REJECTED", exception.getMessage(), request);
    }

    @ExceptionHandler(LiveTradingDisabledException.class)
    public ResponseEntity<ErrorResponse> handleLiveDisabled(LiveTradingDisabledException exception, HttpServletRequest request) {
        return errorResponse(HttpStatus.CONFLICT, "LIVE_TRADING_DISABLED", exception.getMessage(), request);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleIllegalArgument(IllegalArgumentException exception, HttpServletRequest request) {
        return errorResponse(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", exception.getMessage(), request);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(
            MethodArgumentNotValidException exception,
            HttpServletRequest request
    ) {
        String message = exception.getBindingResult()
                .getFieldErrors()
                .stream()
                .findFirst()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .orElse("Request validation failed");

        return errorResponse(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_FAILED",
                message,
                request
        );
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ErrorResponse> handleConstraintViolation(
            ConstraintViolationException exception,
            HttpServletRequest request
    ) {
        return errorResponse(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_FAILED",
                exception.getMessage(),
                request
        );
    }

    private ResponseEntity<ErrorResponse> errorResponse(
            HttpStatus status,
            String error,
            String message,
            HttpServletRequest request
    ) {
        ErrorResponse response = new ErrorResponse(
                LocalDateTime.now(),
                status.value(),
                error,
                message,
                request.getRequestURI()
        );

        return ResponseEntity.status(status).body(response);
    }
}
