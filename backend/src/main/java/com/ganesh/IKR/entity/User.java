package com.ganesh.IKR.entity;

import jakarta.persistence.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(
            strategy = GenerationType.IDENTITY
    )
    private Long id;

    @Column(
            name = "username",
            nullable = false,
            unique = true,
            length = 50
    )
    private String username;

    @Column(
            name = "firstname",
            nullable = false,
            length = 50
    )
    private String firstName;

    @Column(
            name = "lastname",
            nullable = false,
            length = 50
    )
    private String lastName;

    @Column(
            name = "email",
            nullable = false,
            unique = true,
            length = 255
    )
    private String email;

    @Column(
            name = "password_hash",
            nullable = false,
            length = 255
    )
    private String passwordHash;

    @Column(
            name = "created_at",
            nullable = false,
            insertable = false,
            updatable = false
    )
    private OffsetDateTime createdAt;

    @Column(
            name = "updated_at",
            nullable = false,
            insertable = false
    )
    private OffsetDateTime updatedAt;

    // Add Getters and Setters for all fields

    public Long getId() {
            return id;
    }

    public void setId(Long id) {
            this.id = id;
    }

    public String getUsername() {
            return username;
    }

    public void setUsername(String username) {
            this.username = username;
    }

    public String getFirstName() {
            return firstName;
    }

    public void setFirstName(String firstName) {
            this.firstName = firstName;
    }

    public String getLastName() {
            return lastName;
    }

    public void setLastName(String lastName) {
            this.lastName = lastName;
    }

    public String getEmail() {
            return email;
    }

    public void setEmail(String email) {
            this.email = email;
    }

    public String getPasswordHash() {
            return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
            this.passwordHash = passwordHash;
    }

    public OffsetDateTime getCreatedAt() {
            return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
            this.createdAt = createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
            return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
            this.updatedAt = updatedAt;
    }


}