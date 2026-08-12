
package com.ganesh.IKR.controller;

import com.ganesh.IKR.entity.User;
import com.ganesh.IKR.repository.UserRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.Optional;

@RestController
public class TestController2 {

    private final UserRepository userRepository;

    public TestController2(UserRepository userRepository) {
        this.userRepository = userRepository;
    }


    @GetMapping("/test2/{username}")
    public Map<String, Object> test(@PathVariable String username) {

        Optional<User> user =
                userRepository.findByUsername(username);
                
        if (user.isPresent()) {
            User foundUser = user.get();

            return Map.of(
                    "status", "Success",
                    "id", foundUser.getId(),
                    "username", foundUser.getUsername(),
                    "firstName", foundUser.getFirstName(),
                    "lastName", foundUser.getLastName(),
                    "email", foundUser.getEmail()
            );
        }

         return Map.of(
                "status", "Not Found"
        );
    } 
}