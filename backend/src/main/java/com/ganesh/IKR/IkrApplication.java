package com.ganesh.IKR;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import java.util.TimeZone;

//SpringBootApplication(exclude = {DataSourceAutoConfiguration.class})
@SpringBootApplication
public class IkrApplication {
	static {
		// Keep JDBC/Flyway and market-session calculations on the same canonical IANA zone.
		TimeZone.setDefault(TimeZone.getTimeZone("Asia/Kolkata"));
	}

	public static void main(String[] args) {
		SpringApplication.run(IkrApplication.class, args);
	}
}
