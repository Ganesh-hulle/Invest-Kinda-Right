package com.ganesh.IKR.repository;

import com.ganesh.IKR.entity.KiteOAuthState;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface KiteOAuthStateRepository extends JpaRepository<KiteOAuthState, Long> {
    Optional<KiteOAuthState> findByState(String state);
}
